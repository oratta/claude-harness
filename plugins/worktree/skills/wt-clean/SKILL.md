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

### Step 6: マージ後サニティチェック（Post-Merge Verify）

マージ済みworktreeの削除前に、メインブランチでテスト・ビルドが壊れていないことを確認する。
**チェックに失敗したworktreeは削除しない。**

#### 6a. テストコマンドの自動検出

メインリポのルートで以下を順に確認し、最初に見つかったものを使用:

```bash
MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')

# Node.js
if [ -f "$MAIN_REPO/package.json" ]; then
  # package.json の scripts から test/lint/typecheck/build を検出
  # 例: npm test, npm run lint, npm run typecheck, npm run build

# Rust
elif [ -f "$MAIN_REPO/Cargo.toml" ]; then
  # cargo test, cargo clippy, cargo build

# Python
elif [ -f "$MAIN_REPO/pyproject.toml" ] || [ -f "$MAIN_REPO/setup.py" ]; then
  # pytest, python -m pytest

# Go
elif [ -f "$MAIN_REPO/go.mod" ]; then
  # go test ./..., go vet ./...
fi
```

テストコマンドが見つからない場合はこのステップをスキップし、Step 7 に進む。

#### 6b. チェック実行

検出したコマンドを実行する。実行するのはメインリポのルート（worktree内ではない）。

```bash
cd "$MAIN_REPO"

# 検出したコマンドを順に実行（例: Node.js の場合）
npm test          # テスト
npm run lint      # lint（scripts に存在すれば）
npm run typecheck # 型チェック（scripts に存在すれば）
npm run build     # ビルド（scripts に存在すれば）
```

#### 6c. 結果判定

- **全PASS** → Step 7（削除実行）に進む
- **1つでもFAIL** → 以下を表示して**そのworktreeの削除を中止**:

```
⚠️ マージ後チェックで問題が検出されました:

失敗コマンド: npm test
エラー出力: [抜粋]

以下のworktreeブランチのマージが原因の可能性があります:
  - feat-x (直前にマージ)

対応オプション:
  1. git revert でマージを取り消して調査する
  2. このまま進めて手動で修正する

このworktreeは削除せず保持します。
```

**重要**: チェック失敗時、該当worktreeだけでなく、そのworktreeのマージ以降にマージされたworktreeも全て削除を保留する（マージ順序が影響するため）。

#### 6d. チェック対象の範囲

- 🟢 Safe かつ「今回の wt-clean で新たにマージした」worktree → チェック対象
- 🟢 Safe で「以前からマージ済み」のworktree → チェック不要（既にメインに統合済み）
- 🟡 Recoverable → チェック対象（LLMコピー後、削除前に）

チェックは**バッチ実行**する。個別のworktreeごとではなく、全マージ完了後に1回だけ実行する（テスト実行コストを最小化）。

### Step 7: 削除実行

**Step 6 でチェックPASSしたworktreeのみ削除する。**

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

### Step 8: 完了レポート

```
wt-clean 完了:
  処理: 2 worktrees
  削除: feat-x (🟢), fix-y (🟡)
  LLMコピー: 2 files → LLM/
  サニティチェック: ✅ PASS (npm test, npm run build)
  スキップ: wip-z (🔴 active)
  残存worktrees: 1
```

チェック失敗時:
```
wt-clean 完了:
  処理: 1 worktree
  削除: feat-x (🟢)
  ⚠️ チェック失敗で保留: fix-y (🟡) — npm test FAIL
  スキップ: wip-z (🔴 active)
  残存worktrees: 2
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
