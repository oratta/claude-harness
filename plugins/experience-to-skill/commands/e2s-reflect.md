---
name: e2s-reflect
description: verified タグ区間の commit 群と session jsonl を分析し、skill 候補を抽出して提示する（読み取り専用）。
allowed-tools: Read, Bash, Glob, Grep
---

# /e2s:reflect — 体験からの skill 候補抽出

指定区間（デフォルトは最新 `verified/*` タグから HEAD まで）の commit と、`Prompted-by` trailer で参照される session jsonl を突き合わせて分析し、再利用可能な skill 候補を番号付きで提示する。**git 状態を一切変更しない読み取り専用コマンド。**

## $ARGUMENTS

- 引数なし: 最新 verified タグ以降を分析（`<latest-verified>..HEAD`）
- 引数 `<tag-a>..<tag-b>`: 明示範囲を指定
- 引数 `<tag-a>`: `<tag-a>..HEAD` を分析
- 引数 `--last N`: 直近 N コミットを分析（tag 関係なし）

## 実行手順

### Step 1: 対象区間の決定

**引数なし:**

```bash
latest_verified=$(git tag --list "verified/*" --sort=-creatordate | head -1)
if [ -z "$latest_verified" ]; then
  # verified タグが存在しない → 直近20コミットを fallback
  range="HEAD~20..HEAD"
else
  range="${latest_verified}..HEAD"
fi
```

**`<a>..<b>` / `<a>` / `--last N`**: 引数を解析して `range` 変数にセット。

区間内に commit が0件の場合：

```
区間 <range> に commit がありません。範囲を広げるか、先にコミットを作ってください。
```

と報告して終了。

### Step 2: コミット情報の収集

```bash
# コミット一覧（SHA, subject, body 込み）
git log "$range" --format='%H%n%s%n%b%n-----COMMIT-END-----'

# ファイル変更統計
git log "$range" --name-only --format='%H'

# 差分サマリ
git log "$range" --stat --no-color
```

各コミットについて：
- SHA（short と full）
- subject / body
- 変更ファイル一覧
- `Prompted-by` trailer から session-id と turn 番号を抽出
- `Intent:` / `Result:` 行を抽出

### Step 3: Session jsonl の読み込み（可能な場合）

各 `Prompted-by: <session-id>#turn-<N>` について：

```bash
# jsonl を探す
jsonl_path=$(find ~/.claude/projects -name "${session_id}.jsonl" 2>/dev/null | head -1)

if [ -z "$jsonl_path" ]; then
  # セッション不在
  session_status="session-unavailable"
else
  # N ターン目前後の user / assistant メッセージを抽出
  # python -c "..." または jq を使って parse
  session_status="available"
fi
```

**jsonl が見つからない場合**: `session-unavailable` と記録し、分析は commit 情報のみで続行。エラーにしない。

**jsonl が見つかった場合**: ターン N 近辺の user メッセージと assistant の応答ダイジェストを抽出。ただし**プロンプト原文をそのまま出力に出さない**（Step 5 参照）。

### Step 4: パターン検出

コミット群から次のパターンを検出する：

1. **繰り返しパターン**: 似た subject や似たファイル変更が3回以上 → 定型作業の可能性
2. **ファイル共変更**: 特定のファイル群が常に一緒に変わっている → そのセットを扱うスキルの候補
3. **デバッグ→修正シーケンス**: `fix(...)` が数コミット続く → デバッグ手順のスキル化候補
4. **新規ファイル作成パターン**: 似た構造の新規ファイル（例: SKILL.md, route.ts）が作られている → scaffold スキル候補
5. **試行錯誤パターン**: 同一ファイルが何度も修正されている → 結論の procedure のみを抽出

### Step 5: Skill 候補の生成（sanitize 必須）

各候補について次を用意する：

```
候補 1: <kebab-case 名前、e2s- or distilled- prefix なし>

説明: <skill description に使う一行、session 原文は直接使わない>
trigger 条件: <ユーザー発話パターン、ファイル変更トリガー等を抽象化>
手順:
  1. <step>
  2. <step>
  3. <step>
根拠: <なぜこのパターンが浮上したか、繰り返し回数や典型例>
Source:
  - commit a1b2c3d (session <id>#turn-5)
  - commit d4e5f6a (session <id>#turn-12)
  - commit g7h8i9b (session-unavailable)
```

**絶対ルール:**

- session jsonl から読み取ったユーザープロンプト原文を**そのまま**出力しない
- 「ユーザーは〜という意図で〜を依頼した」の形に**抽象化**する
- PII や API key を含むと疑われる文字列は検出したら除外
- 複数 session 由来の情報は、発話者・具体名を除いて**一般化された文言**にする

### Step 6: ユーザーへの提示

```
区間 <range> を分析しました（<N>コミット、<M>セッション参照）。

skill 候補: <X> 件

候補 1: <name>
  説明: <desc>
  ...

候補 2: ...

候補の実体化には以下を実行:
  /e2s:distill 1    # 候補 1 を SKILL.md に落とす
  /e2s:distill 2    # 候補 2 を SKILL.md に落とす

候補が気に入らない場合:
  /e2s:reflect --last 50    # 範囲を広げて再分析
  /e2s:reflect verified/A..verified/B  # 特定区間
```

### Step 7: 候補リストの一時保存

次の `/e2s:distill <N>` 実行時に参照できるよう、候補リストを一時ファイルに保存する：

```bash
mkdir -p /tmp/e2s
cat > /tmp/e2s/reflect-candidates.json <<EOF
{
  "generated_at": "<ISO timestamp>",
  "range": "<range>",
  "candidates": [
    { "id": 1, "name": "...", "description": "...", "triggers": [...], "steps": [...], "sources": [...] },
    ...
  ]
}
EOF
```

`/e2s:distill` はこのファイルを読んで候補を特定する。

## Guardrails（読み取り専用保証）

以下の git 操作は絶対に実行しない：

- `git commit` / `git commit --amend`
- `git add`
- `git reset` / `git restore`
- `git rebase`
- `git tag` / `git tag -d`
- `git push`
- `git checkout <ref>` （HEAD 移動）
- 他コミットへの branch 作成・移動

使ってよいのは `git log`, `git show`, `git diff`, `git tag --list`, `git rev-parse`, `git cat-file` 等の**読み取り系**のみ。

## session jsonl が見つからない場合の挙動

- エラーで中断しない
- 該当 source に `session-unavailable` と明記
- commit 情報のみで分析を続行
- 最終報告時に「N 件の source が session-unavailable」と summary する

## Notes

- 候補が多すぎる場合（10件以上）は「代表的な候補 Top 5」に絞って提示し、「全候補を見る場合は〜」とヒントを添える
- 候補がゼロ件の場合は「パターン化できる繰り返しが検出されませんでした。範囲を広げてみてください」と報告する
