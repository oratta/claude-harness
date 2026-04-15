---
name: e2s-status
description: experience-to-skill の診断情報を表示する。未コミット差分・自編集ファイル・最新 verified タグ・session 情報を一括確認（読み取り専用）。
allowed-tools: Read, Bash, Glob
---

# /e2s:status — 診断表示

現在のセッション・リポジトリ状態を experience-to-skill の観点から可視化する。コミット実行前の確認や、トラブルシューティングに使う。

## 実行

以下の情報を収集して表示する：

### 1. git 状態

```bash
# 現在のブランチと HEAD
git branch --show-current
git log -1 --format='%h %s (%cr)'

# 未コミット差分の概要
git status --short
git diff --shortstat
git diff --cached --shortstat
```

### 2. 自セッションで編集したファイル（LLM 判断）

context から Edit/Write/MultiEdit/Bash (mv/rm/mkdir/cp) 呼び出し履歴を確認し、本セッションで触ったファイルのリストを作る。

`git status` の結果と照合し：
- ✅ 両方に出現 = 自セッションのコミット対象
- ⚪ git status のみに出現 = 他セッション or ユーザー手動編集（**コミット対象外**）
- ⚠️ 自リストのみに出現 = 既にコミット済み or 削除された

### 3. Verified タグ状況

```bash
# 最新 verified タグとそこからの距離
latest_verified=$(git tag --list "verified/*" --sort=-creatordate | head -1)
if [ -n "$latest_verified" ]; then
  ahead=$(git rev-list --count "${latest_verified}..HEAD")
  echo "最新 verified: $latest_verified (HEAD は +$ahead コミット先行)"
fi

# 直近5件の verified タグ
git tag --list "verified/*" --sort=-creatordate \
  --format='%(refname:short) %(creatordate:short) %(objectname:short) %(contents:subject)' \
  | head -5

# backup タグも最新2件だけ
git tag --list "backup/*" --sort=-creatordate | head -2
```

### 4. Session 情報

```bash
# session-id（フォールバック階段の結果を1つ表示）
session_id="${CLAUDE_SESSION_ID:-$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1 | xargs -I{} basename {} .jsonl)}"
echo "session-id: ${session_id:-不明}"

# session jsonl の場所
if [ -n "$session_id" ]; then
  find ~/.claude/projects -name "${session_id}.jsonl" 2>/dev/null | head -1
fi
```

### 5. Reflect 候補の残存

```bash
if [ -f /tmp/e2s/reflect-candidates.json ]; then
  # 前回の /e2s:reflect 結果が残っている
  generated_at=$(python3 -c "import json; print(json.load(open('/tmp/e2s/reflect-candidates.json'))['generated_at'])" 2>/dev/null)
  echo "前回 reflect: $generated_at"
fi
```

## 出力フォーマット

```
╭──────────────────────────────────────────────────────
│ experience-to-skill status
├──────────────────────────────────────────────────────
│
│ 📦 Git
│   Branch: main
│   HEAD:   a1b2c3d feat(foo): add bar (2 hours ago)
│
│ 📝 未コミット差分
│   2 files modified, +45 -3 (working)
│   0 files staged
│
│ 👤 自セッション編集ファイル
│   ✅ plugins/experience-to-skill/SKILL.md         (コミット対象)
│   ✅ plugins/experience-to-skill/commands/foo.md  (コミット対象)
│   ⚪ docs/unrelated.md                             (他セッション or 手動編集 — 除外)
│
│ 🏷️  Verified タグ
│   最新: verified/20260414-1500-skill-distill-mvp (HEAD は +2 先行)
│
│   直近5件:
│     verified/20260414-1500-skill-distill-mvp  20260414  a1b2c3d feat: ...
│     verified/20260413-1200-infra-v01-release   20260413  d4e5f6a chore: ...
│     ...
│
│ 🗂️  Session
│   session-id: 4e74e264-fc15-4af0-90a2-b8c53523eeaa
│   jsonl:      ~/.claude/projects/-Users-.../4e74e264...jsonl (1.2 MB)
│
│ 🔍 Reflect 候補
│   前回生成: 2026-04-14T14:30:00Z (range: verified/...)
│
├──────────────────────────────────────────────────────
│ 推奨アクション:
│   - 現在の差分をコミット → /e2s:commit
│   - 最新コミットに verified タグ → /e2s:ok
│   - 最新タグ以降を分析 → /e2s:reflect
╰──────────────────────────────────────────────────────
```

## Guardrails

- 読み取り専用。git 状態を変更する操作は一切実行しない
- `git status` / `git log` / `git tag --list` / `git rev-parse` / `git diff` のみ使用
- ファイルシステムも `ls`, `find`, `cat` で読むだけ（書き込みなし）
