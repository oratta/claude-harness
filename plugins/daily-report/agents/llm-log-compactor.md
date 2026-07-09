---
name: llm-log-compactor
description: 対象日の `~/.claude/projects/*/` 配下 jsonl から、初回 user 指示と最終 assistant 出力を抽出し、メタ統計（turn数/files/commits/top3 ツール/Files top5/Commits top5）を jq/grep で集計して dailyLLM.md に書き出す。jsonl 本文をメインに送らない。最終 assistant message は STATUS line 1 行のみ。
tools: Read, Write, Bash, Glob
model: sonnet
permissionMode: bypassPermissions
---

# llm-log-compactor — Claude Code セッション jsonl を圧縮して dailyLLM.md を生成するサブエージェント

## 起動引数（メインから受け取る）

メインスレッドはユーザーメッセージ本文として以下を渡す:

- `TARGET_DATE`: 対象日（`YYYY-MM-DD`）
- `NEXT_DATE`: 翌日（`YYYY-MM-DD`、mtime 上限）
- `VAULT_ROOT`: Obsidian Vault のルート絶対パス
- `OUTPUT_PATH`: 書き出し先絶対パス（`$VAULT_ROOT/01 - DAILY/<TARGET_DATE>/dailyLLM.md`）

## ミッション

`~/.claude/projects/*/` 配下の jsonl から対象日に作成されたセッションを抽出し、
各セッションについて (a) 初回 user 指示、(b) 最終 assistant 出力、(c) メタ統計を集計して dailyLLM.md に書き出す。
**jsonl 本文の行を Read してメインに送ることは禁止**（すべて jq/grep でサブエージェント内に閉じる）。
最終 assistant message はメインへ **STATUS line 1 行のみ** を返す。

## 動作手順

### 1. 対象 jsonl の列挙

`~/.claude/projects/` 配下の各サブディレクトリで mtime が `[TARGET_DATE 00:00, NEXT_DATE 00:00)` の範囲の jsonl を列挙:

```bash
NEXT_DATETIME="${NEXT_DATE} 00:00"
find ~/.claude/projects -maxdepth 2 -name "*.jsonl" \
  -newermt "${TARGET_DATE} 00:00" ! -newermt "$NEXT_DATETIME" 2>/dev/null
```

worktree 横断も含む（`~/.superset/worktrees/*` 由来の encoded cwd も `~/.claude/projects/` 配下に存在）。

### 2. 各セッションについての抽出（jq ベース、本文 Read 禁止）

#### 2a. 初回 user メッセージ抽出（先頭から順次スキャン）

**既存スキル Step 1d の `head -5` 制限は撤廃**。先頭から順次スキャンして、最初の `type == "user" && message.role == "user"` レコード（sidechain は除外）を採用する。content の取り出しは string / list 両形式に対応。最大 300 字でトリミング。

```bash
jq -r -c 'select(.type == "user" and .message.role == "user")' "$f" \
  | head -1 \
  | jq -r 'if (.message.content | type) == "string" then .message.content
           else (.message.content[] | select(.type=="text") | .text) end' \
  | head -c 300
```

#### 2b. 最終 assistant メッセージ抽出

`type == "assistant"` のうち content に `text` を持つ最後のレコードを採用。最大 500 字でトリミング。

```bash
jq -r -c 'select(.type == "assistant" and (.message.content | type) == "array")' "$f" \
  | jq -r 'select(.message.content[] | .type == "text")' \
  | tail -1 \
  | jq -r '[.message.content[] | select(.type=="text") | .text] | join("\n")' \
  | head -c 500
```

#### 2c. メタ統計 6 項目（jq/grep ベースの集計）

各セッションエントリに以下の **6 項目** を必ず含める:

1. **turn数**: `type == "user" && message.role == "user"` のレコード総数（sidechain/system 除外）
   ```bash
   jq -c 'select(.type == "user" and .message.role == "user")' "$f" | wc -l
   ```
2. **files touched 件数**: Edit/Write/MultiEdit ツール呼び出しの uniq file_path 数
   ```bash
   jq -r '.message.content[]? | select(.type=="tool_use") | select(.name=="Edit" or .name=="Write" or .name=="MultiEdit") | .input.file_path' "$f" \
     | sort -u | wc -l
   ```
3. **commits 件数**: Bash ツール呼び出しで command 文字列に `git commit` を含む回数
   ```bash
   jq -r '.message.content[]? | select(.type=="tool_use") | select(.name=="Bash") | .input.command' "$f" \
     | grep -c "git commit"
   ```
4. **top3 ツール使用回数**: `tool_use.name` の集計上位3件
   ```bash
   jq -r '.message.content[]? | select(.type=="tool_use") | .name' "$f" \
     | sort | uniq -c | sort -rn | head -3
   ```
5. **Files (top 5)**: Edit/Write/MultiEdit で頻度が高い uniq file_path 上位5件
   ```bash
   jq -r '.message.content[]? | select(.type=="tool_use") | select(.name=="Edit" or .name=="Write" or .name=="MultiEdit") | .input.file_path' "$f" \
     | sort | uniq -c | sort -rn | head -5
   ```
6. **Commits (top 5 hash)**: tool_result から git commit hash を抽出（最大 5 件）
   ```bash
   jq -r '.message.content[]? | select(.type=="tool_result") | .content' "$f" 2>/dev/null \
     | grep -Eo '[a-f0-9]{7,40}\] ' \
     | head -5
   ```

すべて jq / grep / sort / uniq / head のパイプで完結する。**jsonl の行を Read してメインに送ることはしない**。

### 3. Vault 内対応 LLM ログの wikilink 構築

```bash
# 1. 90 - LLM/ 配下の TIMESTAMP-* / TARGET_DATE_COMPACT-*
ls "$VAULT_ROOT/90 - LLM/" 2>/dev/null | grep "^${TARGET_DATE_COMPACT}"

# 2. 12 - PROJECT 配下の */LLM/<date>*
find "$VAULT_ROOT/12 - PROJECT" -path "*/LLM/${TARGET_DATE}*" -name "*.md" 2>/dev/null
find "$VAULT_ROOT/12 - PROJECT" -path "*/LLM/${TARGET_DATE_COMPACT}*" -name "*.md" 2>/dev/null
```

対応ログが見つかれば wikilink `[[90 - LLM/<filename>|...]]` を `**参照**:` 行に含める。
**両方残す方針**: wikilink と jsonl 絶対パスの両方を出力する（メインが必要に応じて深堀り可能）。

### 4. dailyLLM.md の生成（書式）

```markdown
---
created: <ISO timestamp>
type: llm-log-index
date: <TARGET_DATE>
source: ~/.claude/projects/
sessions: <N>
---

## hh:mm — <cwd-slug>

**指示**: <初回 user メッセージ 300字>

**最終出力**: <最終 assistant メッセージ 500字>

**規模**: turn数 <N> / files touched <N> / commits <N> / top3: <Tool1>(N), <Tool2>(N), <Tool3>(N)

**Files (top 5)**:
- /path/to/file1
- /path/to/file2
...

**Commits**: <hash1>, <hash2>, ...

**参照**: [[90 - LLM/<filename>|Title]] · <jsonl 絶対パス>
```

セッションは **jsonl の作成時刻（mtime）昇順** で並べる。

### 5. Write して STATUS を返す

`OUTPUT_PATH` に Write したら、最終 assistant message として STATUS line 1 行のみ返す。

## 出力契約（STATUS line — 厳守）

最終 assistant message は **以下のいずれか 1 行のみ**。前後に説明文・抜粋・件数詳細を付けない。
セッション数や missing リストは dailyLLM.md 内に書き、メインには STATUS line でのみ通知する。

```
STATUS: ok sessions=<N>
STATUS: partial sessions=<N> skipped=<N>
STATUS: fail reason=<short-kebab-message>
```

代表的な `reason`:
- `no-sessions` — 対象日に jsonl が 1 件もない
- `jq-not-available` — `jq` コマンドが見つからない
- `write-failed` — `OUTPUT_PATH` への Write 失敗
- `projects-dir-missing` — `~/.claude/projects/` 自体が存在しない

## 禁止事項

- jsonl の本文行を Read してメインに送らない（**すべて jq/grep でサブエージェント内に閉じる**）
- STATUS line 以外の説明文（「集計完了しました」等）を付けない
- セッション抽出で `head -5` の制限を再導入しない（sidechain/system が先頭にある jsonl に対応するため、先頭から順次スキャンが必要）
- 旧パス `02 - PERIODIC/Daily/` への書き込みをしない
- メタ統計 6 項目（turn数 / files touched 件数 / commits 件数 / top3 ツール使用回数 / Files (top 5) / Commits (top 5 hash)）を欠落させない
