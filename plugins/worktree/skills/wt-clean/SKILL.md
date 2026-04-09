---
name: wt-clean
description: Git worktreeの安全なクリーンアップ。診断（マージ状態・未コミット変更・LLMファイル）→ LLM保全 → マージ → 削除。「worktree整理」「ワークツリークリーン」「worktree削除」で起動。
version: 1.0.0
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# wt-clean — Worktree クリーンアップスキル

Git worktreeを安全にクリーンアップするスキル。
診断 → LLM保全 → マージ → 削除の順で、データロスなく整理する。

## 前提条件

- メインリポのルートで実行すること（worktree内ではなく）
- worktree内で実行した場合: 「メインリポで実行してください」と案内

## 実行フロー

### Step 1: 診断（Diagnose）

```bash
git worktree list
```

各worktreeに対して以下を調査:

```bash
WORKTREE_PATH="..."
BRANCH_NAME="..."

# 1. マージ済みか
git branch --merged master | grep "$BRANCH_NAME"  # or main

# 2. 未マージのコミット数
git log --oneline master.."$BRANCH_NAME" | wc -l

# 3. 未コミットの変更
git -C "$WORKTREE_PATH" status --porcelain

# 4. LLM/ ディレクトリの有無
ls "$WORKTREE_PATH/LLM/" 2>/dev/null

# 5. 最終コミット日時
git log -1 --format='%ci' "$BRANCH_NAME"

# 6. 作成元の判定（Superset or Agent or 手動）
#    - パスが .superset/worktrees/ 配下 → Superset
#    - パスが /tmp/ や .claude/worktrees/ 配下 → Agent
#    - それ以外 → 手動
```

### Step 2: 分類（Classify）

各worktreeを以下の3カテゴリに分類:

| カテゴリ | 条件 | アクション |
|---|---|---|
| Safe (緑) | マージ済み & dirty なし & LLM なし | 即削除可能 |
| Recoverable (黄) | マージ済み だが LLM あり or dirty あり | LLMコピー → 確認後削除 |
| Active (赤) | 未マージのコミットあり | スキップ（明示指示なければ） |

### Step 3: レポート表示

AskUserQuestion でレポートを表示し、ユーザーに確認:

```
Worktree診断結果:

| Worktree | Branch | 状態 | 未マージ | Dirty | LLM | 推奨 |
|----------|--------|------|----------|-------|-----|------|
| /path/a  | feat-x | 🟢 Safe | 0 | No | No | 削除 |
| /path/b  | fix-y  | 🟡 Recover | 0 | No | 2files | LLMコピー→削除 |
| /path/c  | wip-z  | 🔴 Active | 3 | Yes | No | スキップ |
```

選択肢:
- 「🟢🟡を処理する」（推奨）
- 「🟢のみ処理する」
- 「全て処理する（🔴含む — 危険）」
- 「キャンセル」

### Step 4: LLM保全

🟡 Recoverable のworktreeに対して:

```bash
# LLMファイルをメインリポにコピー
MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')
mkdir -p "$MAIN_REPO/LLM"
cp "$WORKTREE_PATH/LLM/"* "$MAIN_REPO/LLM/" 2>/dev/null
```

ファイル名にセッションIDが含まれるので衝突しない。

### Step 5: マージ確認

🟡 Recoverable で未コミット変更がある場合:

```bash
# 差分を表示
git -C "$WORKTREE_PATH" diff --stat
```

AskUserQuestion で確認:
- 「変更を破棄して削除」
- 「スキップ（あとで手動対応）」

### Step 6: 削除実行

```bash
# git worktree remove
git worktree remove "$WORKTREE_PATH" --force  # 🟢の場合
git worktree remove "$WORKTREE_PATH"           # 🟡で確認済みの場合

# ブランチ削除（マージ済みのみ）
git branch -d "$BRANCH_NAME"
```

**Superset作成のworktreeの場合**:
- `git worktree remove` + `git branch -d` を実行
- 「Superset UI上でもnot foundになるので、UIから削除してください」と案内

### Step 7: 完了レポート

```
wt-clean 完了:
  処理: 2 worktrees
  削除: feat-x (🟢), fix-y (🟡)
  LLMコピー: 2 files → LLM/
  スキップ: wip-z (🔴 active)
  残存worktrees: 1
```

## 🔴 Active worktreeの強制処理

ユーザーが「全て処理する」を選んだ場合のみ:

1. 未マージコミットのログを表示
2. 未コミット変更のdiffを表示
3. 「本当に削除しますか？この操作は取り消せません」と最終確認
4. LLMファイルをコピー
5. `git worktree remove --force` + `git branch -D`（大文字D = 強制削除）

## エッジケース

- メインリポ自体がworktreeの場合: スキップ（削除対象外）
- detached HEAD のworktree: ブランチ削除はスキップ
- worktreeのパスが存在しない（既に手動削除済み）: `git worktree prune` で整理
