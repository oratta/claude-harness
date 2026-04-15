---
name: e2s-ok
description: 現在の HEAD に verified タグを付与する。動作確認済みコミットを安全な巻き戻し先として記録する。
allowed-tools: Read, Bash
---

# /e2s:ok — verified タグ付与

ユーザーが動作確認 OK と判断したコミットに `verified/YYYYMMDD-HHMMSS-<label>` 形式のタグを付与する。このタグは `/e2s:rewind` の巻き戻し先、`/e2s:reflect` の分析区間境界として機能する。

## $ARGUMENTS

- 引数なし: LLM が最近のコミット群から label を推定して提案 → ユーザー確認後に作成
- 引数 `<label>`: kebab-case のラベル（例: `infra-phase5-complete`）を明示指定。そのまま使用
- `--list`: 既存の verified タグ一覧を表示（読み取り専用）

## 実行手順

### Step 1: 前提条件チェック

```bash
# HEAD がコミットを指しているか
git rev-parse --verify HEAD

# 未コミットの変更がないか
git diff --cached --quiet && git diff --quiet
```

**未コミット変更がある場合:**

```
❌ 未コミットの変更があります：
<git status の概要>

先に /e2s:commit でコミットしてから /e2s:ok を実行してください。
```

と報告して終了する。

### Step 2: ラベルの決定

- 引数 `<label>` が渡された場合: kebab-case バリデーション（`^[a-z][a-z0-9-]{1,39}$`）を行い、違反していればユーザーに訂正を促す。バリデーション通ったら採用
- 引数なしの場合: LLM が直近コミットの subject / body、セッション context から 2-40 文字の kebab-case ラベルを生成し、ユーザーに提示して確認を取る

ラベル例:
- `infra-phase5-complete`
- `skill-distillation-mvp`
- `fix-secret-filter-false-positive`
- `v01-release-ready`

### Step 3: タグ名の確定と衝突回避

```bash
timestamp=$(date -u +%Y%m%d-%H%M%S)
tag_name="verified/${timestamp}-${label}"

# 同名タグがないか確認
if git tag --list "$tag_name" | grep -q .; then
  # 衝突時: -2, -3 ... を追加
  for i in 2 3 4 5; do
    candidate="${tag_name}-${i}"
    if ! git tag --list "$candidate" | grep -q .; then
      tag_name="$candidate"
      break
    fi
  done
fi
```

### Step 4: HEAD に既に verified タグがあるか確認

```bash
git tag --points-at HEAD | grep "^verified/" || true
```

既存の verified タグが HEAD にあれば：

```
⚠️ HEAD には既に verified タグが付与されています:
- verified/20260414-1500-<prev-label>

追加で別ラベルのタグを付けますか？
  (y) 追加する / (n) スキップする
```

ユーザーが `n` なら終了。`y` なら続行。

### Step 5: タグ作成（lightweight tag）

```bash
git tag "$tag_name"
```

**annotated tag (`-a`, `-m`) ではなく lightweight tag を使う。**push 軽量化とログの見やすさのため。

### Step 6: 結果報告

```
✅ verified タグ作成完了

タグ名: verified/20260414-1530-infra-phase5-complete
コミット: a1b2c3d <subject>

次のアクション:
- この状態から離れて作業続行 → 自由に編集。問題が出たら /e2s:rewind で戻れます
- このタグまでの経緯から skill 抽出 → /e2s:reflect
- タグ一覧確認 → /e2s:ok --list
```

## --list モード

引数が `--list` の場合：

```bash
git tag --list "verified/*" --sort=-creatordate --format='%(refname:short) %(creatordate:short) %(objectname:short) %(contents:subject)'
```

の結果を整形してユーザーに提示。タグ作成は行わない。

## Guardrails

- `git tag --force` で既存タグを上書きしない
- `git tag -d` で既存タグを削除しない（削除は `/e2s:rewind` の文脈外では行わない）
- `git push --tags` で自動 push しない（ローカル専用）
- annotated tag (`-a`) を使わない（lightweight tag で統一）
