---
name: e2s-rewind
description: verified タグへの安全な巻き戻し。必ず backup タグを事前作成してから git reset --hard する。
allowed-tools: Read, Bash, AskUserQuestion
---

# /e2s:rewind — verified タグへの安全な巻き戻し

`verified/*` タグのいずれかに HEAD を戻す。必ず事前に `backup/YYYYMMDD-HHMMSS-before-rewind` を作成してから `git reset --hard` するので、巻き戻し後も元の状態に復元可能。

## $ARGUMENTS

- 引数なし: 既存 verified タグ一覧を表示 → ユーザーに選択させる → 選ばれたタグに rewind
- 引数 `<verified-tag-name>`: そのタグに直接 rewind（確認プロンプトは出す）
- 引数 `--list`: タグ一覧を表示するのみ。巻き戻しは行わない（読み取り専用）

## 実行手順

### --list モード（$ARGUMENTS が `--list`）

```bash
git tag --list "verified/*" --sort=-creatordate \
  --format='%(refname:short)|%(creatordate:short)|%(objectname:short)|%(contents:subject)'
```

出力を整形してユーザーに提示。それ以上のアクションは取らない。

### 通常モード

#### Step 1: 対象タグの決定

**引数なしの場合:**

1. `git tag --list "verified/*" --sort=-creatordate` でタグ一覧を取得
2. 各タグと現在の HEAD との関係（`git rev-list --count HEAD..<tag>` と `<tag>..HEAD` で前後何コミットか）を計算
3. AskUserQuestion で「どのタグに戻しますか？」と質問（最新5件程度を選択肢として提示）

**引数として tag 名が渡された場合:**

1. `git rev-parse --verify "$tag"` でタグの存在確認。存在しなければエラー終了
2. タグ名が `verified/` で始まらない場合は警告（独自タグに reset するのは想定外）

#### Step 2: 未コミット変更のチェックと警告

```bash
git diff --cached --quiet && git diff --quiet
```

未コミット変更がある場合：

```
⚠️ 以下の未コミット変更があります。reset --hard で失われます：

<git status の出力>

続行すると上記の変更はすべて失われます。
続行しますか？ (yes/no) → "yes" の場合のみ続行
```

AskUserQuestion で明示的な `yes` 確認を取る。`yes` 以外（`y`, `はい`, 空欄）は全て中止扱いとする。

#### Step 3: backup タグ作成

```bash
backup_tag="backup/$(date -u +%Y%m%d-%H%M%S)-before-rewind"

# 衝突回避（同じ秒に複数回 rewind する場合）
i=0
while git tag --list "$backup_tag" | grep -q .; do
  i=$((i+1))
  backup_tag="backup/$(date -u +%Y%m%d-%H%M%S)-before-rewind-${i}"
done

# 作成（lightweight tag）
git tag "$backup_tag"

# 作成成功確認
git rev-parse --verify "$backup_tag" || {
  echo "❌ backup タグ作成に失敗しました。rewind を中止します。"
  exit 1
}
```

**backup タグ作成に失敗した場合は絶対に reset を実行しない。** ディスク容量、権限、git 破損など原因を報告してユーザーに委ねる。

#### Step 4: 巻き戻し実行

```bash
git reset --hard "$target_tag"
```

#### Step 5: 結果報告

```
✅ 巻き戻し完了

HEAD を verified/20260414-1530-infra-phase5-complete に戻しました
(commit: a1b2c3d)

⚠️ 復元用 backup タグ: backup/20260414-1600-before-rewind

元に戻したい場合:
  git reset --hard backup/20260414-1600-before-rewind

次のアクション:
- このまま作業継続
- 別のタグに再 rewind → /e2s:rewind
```

## Guardrails

- **backup タグ作成の前に reset を絶対に実行しない**
- 未コミット変更がある場合、明示 `yes` 確認なしに reset しない
- `--no-verify` 相当のフラグは使わない
- `git push --force` で remote に反映することは決して自動実行しない
- 巻き戻し後、作業者が自分で `git push --force-with-lease` する判断はユーザーに委ねる
- verified タグや backup タグを `git tag -d` で削除することは**本コマンドの範囲外**
