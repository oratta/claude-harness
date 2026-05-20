---
name: wt-clean
description: Worktreeのクリーンアップ（診断・LLM保全・マージ・削除）
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# wt-clean — Worktree クリーンアップスキル

Git worktreeを安全にクリーンアップするスキル。
診断 → LLM保全 → マージ → 削除 or 再利用化 の順で、データロスなく整理する。

## オプション

- オプションなし（デフォルト）: 削除モード。マージ済み worktree をディレクトリごと削除する。実行前にローカル `<main>` を `origin/<main>` に同期する（Step 0）
- `--keep`: 再利用モード。🟢 Safe worktree はディレクトリを残し、worktree内のブランチをmainに戻して元ブランチを削除する。`node_modules` / `.env` / 未追跡ファイルは保持されるため、次作業時のセットアップコストがゼロになる。🟡 Recoverable は従来通り削除、🔴 Active はスキップ
- `--no-sync`: Step 0 の Remote 同期をスキップする。オフライン作業や、意図的に古い `<main>` のまま診断したい場合に使用。`--keep` と併用可能（例: `wt-clean --keep --no-sync`）

## 前提条件

- メインリポのルートで実行すること（worktree内ではなく）
- worktree内で実行した場合: 「メインリポで実行してください」と案内

## 実行フロー

### Step 0: Remote 同期（Sync）

GitHub 側で PR がマージされた feature ブランチを Step 1 の `git branch --merged` で正しく Safe 判定するため、ローカル `<main>` を `origin/<main>` に同期する。`--no-sync` 指定時はこの Step を完全にスキップする。

```bash
# --no-sync 指定時は即座にスキップ
if [ "$NO_SYNC" = "1" ]; then
  echo "Remote 同期: -- skipped (--no-sync)"
  # Step 1 へ進む
fi

# origin remote の存在確認
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Remote 同期: -- skipped (no origin remote)"
  # Step 1 へ進む
fi

# main / master 検出（Step 7b と同じロジック）
MAIN_BRANCH="main"
git show-ref --verify --quiet refs/heads/master && MAIN_BRANCH="master" || true

# fetch
git fetch origin   # 失敗時はエラー中断、後続 Step に進まない

# 進行差を測定（左=ローカル独自, 右=remote 独自）
read AHEAD BEHIND < <(git rev-list --left-right --count "$MAIN_BRANCH"...origin/"$MAIN_BRANCH" | awk '{print $1, $2}')

if [ "$BEHIND" = "0" ]; then
  echo "Remote 同期: ✅ already up-to-date"
elif [ "$AHEAD" = "0" ]; then
  # fast-forward 可能 → pull
  git pull --ff-only origin "$MAIN_BRANCH"   # 失敗時はエラー中断、後続 Step に進まない
  echo "Remote 同期: ✅ pulled $BEHIND commits (origin/$MAIN_BRANCH → $MAIN_BRANCH)"
else
  # ローカルが diverge している → ff-only で失敗するので中断
  echo "⚠️ ローカル $MAIN_BRANCH が origin/$MAIN_BRANCH と diverge しています"
  echo "  AHEAD=$AHEAD, BEHIND=$BEHIND"
  echo "  git status / git log で状態を確認し、解消後に再実行してください"
  echo "  （または --no-sync で同期をスキップして実行）"
  exit 1
fi
```

**失敗時の扱い**:
- `git fetch origin` 失敗（ネットワーク到達不能等）→ エラー中断。後続 Step に進まない。再実行 or `--no-sync` を案内
- `git pull --ff-only` 失敗（diverge / force-push）→ エラー中断。`git status` で状態確認するよう案内
- 中断時、Step 8 完了レポートは表示しない（処理が走っていないため）

**禁則**:
- 本 Step では `git pull --ff-only` 以外の pull 戦略（merge / rebase）を使ってはならない。`<main>` 履歴の意図せぬ改変を避けるため

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

AskUserQuestion でレポートを表示し、ユーザーに確認。冒頭に現在のモードを明示する。

```
Worktree診断結果 (モード: 削除 / --keep で再利用):

| Worktree | Branch | 状態 | 未マージ | Dirty | LLM | 推奨 |
|----------|--------|------|----------|-------|-----|------|
| /path/a  | feat-x | 🟢 Safe | 0 | No | No | 削除 (または再利用) |
| /path/b  | fix-y  | 🟡 Recover | 0 | No | 2files | LLMコピー→削除 |
| /path/c  | wip-z  | 🔴 Active | 3 | Yes | No | スキップ |
```

`--keep` 指定時のレポート冒頭:
```
Worktree診断結果 (モード: 再利用 [--keep]):
...
推奨列の 🟢 Safe は「再利用可能化（main切替＋元ブランチ削除）」となる。🟡/🔴 は削除/スキップで変化なし。
```

選択肢:

**🔴 Active worktree が 1 件以上ある場合（5 択、新選択肢を先頭に挿入）**:

- 1) 「🔴 を main にマージしてから処理 (推奨・安全)」 ← New（最頻パスを先頭推奨）
- 2) 「🟢🟡 のみ処理する」
- 3) 「🟢 のみ処理する」
- 4) 「全て処理する（🔴含む — 破棄ルート、危険）」
- 5) 「キャンセル」

**🔴 Active worktree が 0 件の場合（従来 4 択、既存挙動を完全維持）**:

- 「🟢🟡を処理する」（推奨）
- 「🟢のみ処理する」
- 「全て処理する（🔴含む — 危険）」
- 「キャンセル」

選択肢 1)「🔴 を main にマージしてから処理」は新ルート（Step 5a / 5b → Step 6 → Step 7a）に分岐する。
選択肢 2)〜5) は既存ルートと完全に同じ動作（回帰防止のため動作変更しない）。

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

### Step 5a: 🔴 個別マージ確認（新ルート選択時のみ）

Step 3 で選択肢 1)「🔴 を main にマージしてから処理 (推奨・安全)」が選ばれた場合のみ実行する。
🔴 worktree を `git worktree list` の順（作成順）に 1 つずつ AskUserQuestion で確認する。

**事前案内: 全 🔴 が Dirty の場合（per-worktree ループ前）**

per-worktree ループに入る前に、🔴 worktree の Dirty 状態を一括スキャンする。**全件が Dirty を持つ場合のみ**、ループ開始前に以下の案内を 1 度だけ表示してから個別確認に進む（エラー中断はしない）:

```bash
# 🔴 worktree のうち Dirty を持つものの件数をカウント
ACTIVE_TOTAL=${#ACTIVE_WORKTREES[@]}
ACTIVE_DIRTY=0
for WT in "${ACTIVE_WORKTREES[@]}"; do
  if [ -n "$(git -C "$WT" status --porcelain)" ]; then
    ACTIVE_DIRTY=$((ACTIVE_DIRTY + 1))
  fi
done

if [ "$ACTIVE_TOTAL" -gt 0 ] && [ "$ACTIVE_DIRTY" -eq "$ACTIVE_TOTAL" ]; then
  echo "ℹ️ マージ可能な 🔴 が 0 件です（全件 Dirty）。"
  echo "  先にコミットしてから wt-clean を再実行するか、個別にスキップ/破棄削除を選んでください。"
fi
# その後、通常通り per-worktree ループに入る（各 🔴 で Dirty 2 択 AskUserQuestion を提示）
```

各 🔴 worktree に対し、表示には以下を含める:

- Branch 名（`BRANCH_NAME`）
- 未マージコミット一覧: `git log --oneline "$MAIN_BRANCH".."$BRANCH_NAME"`
- Dirty 状態（`git -C "$WORKTREE_PATH" status --porcelain` の有無）
- LLM ファイル状況（Step 1 と同じ検出）

```
🔴 wip-z の処理:
  Branch: feat-wip
  未マージコミット: 3件
    abc1234 feat: ユーザー登録フォームの追加
    def5678 fix: バリデーションエラー
    ghi9012 chore: テスト整備
  Dirty: なし
  LLM: なし

選択肢:
  1) main にマージ (推奨)
  2) スキップ
  3) 破棄削除 (force)
```

**Dirty 同時 🔴 の場合**: 「1) main にマージ」を**選択肢から除外**し、表示文言で理由を明示する（merge は clean working tree が前提）。

```
🔴 wip-z の処理:
  Branch: feat-wip
  未マージコミット: 3件
  Dirty: 2 files (uncommitted changes)
  LLM: なし

⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）。

選択肢:
  1) スキップ
  2) 破棄削除 (force)
```

**detached HEAD の 🔴 の場合**: `BRANCH_NAME` が空（`git worktree list --porcelain` の `branch` 行が無く `detached` 状態）の 🔴 worktree も、マージできないためマージ選択肢を除外し、Dirty 同時時と同じく **「1) スキップ / 2) 破棄削除 (force)」の 2 択** を提示する。表示文言で理由を明示する（detached HEAD のためマージ対象のブランチ名が無い）。

```
🔴 (detached HEAD) の処理:
  Branch: (detached HEAD)
  未マージコミット: 3件
  Dirty: なし
  LLM: なし

⚠️ detached HEAD のためマージできません（マージ対象のブランチ名がありません）。

選択肢:
  1) スキップ
  2) 破棄削除 (force)
```

Dirty と detached HEAD が両方該当する場合も同じ 2 択を提示し、表示文言には両方の理由を併記する。

ユーザーの選択ごとの分岐:

- 「マージ」 → Step 5b へ進み、当該 worktree を順次マージ実行
- 「スキップ」 → 状態維持（worktree も main も触らない）
- 「破棄削除 (force)」 → `git worktree remove --force "$WORKTREE_PATH"` + `git branch -D "$BRANCH_NAME"`（既存「全て処理する（🔴破棄）」と同じ操作）

### Step 5b: マージ実行とエラーハンドリング（新ルート選択時のみ）

Step 5a で「マージ」を選ばれた worktree について、マージは必ず **メインリポで `MAIN_BRANCH` をチェックアウトした状態で** `git merge --no-ff` で実行する。fast-forward は許可しない（履歴トレーサビリティ確保）。

#### 5b-1. セッション内状態管理

```bash
# 新ルートで実際にマージ成功したブランチ名を順次蓄積する配列（push 順 = マージ順）
# Step 6d のチェック対象判定 / Step 8 完了レポートの両方で参照する
MERGED_BRANCHES=()
```

#### 5b-2. 事前確認: メインリポが MAIN_BRANCH をチェックアウト中か / merge in progress でないか

```bash
# Step 0 / Step 7b と同じ MAIN_BRANCH 検出ロジック
MAIN_BRANCH="main"
git show-ref --verify --quiet refs/heads/master && MAIN_BRANCH="master" || true

MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')
CURRENT_BRANCH=$(git -C "$MAIN_REPO" branch --show-current)

if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
  echo "⚠️ メインリポが $MAIN_BRANCH 以外をチェックアウト中（現在: $CURRENT_BRANCH）。新ルートを中断します。"
  echo "  対応: cd $MAIN_REPO && git checkout $MAIN_BRANCH してから wt-clean を再実行してください。"
  exit 1   # 新ルート全体を中断（既マージ分があれば後述の通り全保留扱い）
fi

# メインリポで前回のマージが進行中（.git/MERGE_HEAD 存在）でないかを検出
# 進行中の場合、新たな merge を重ねると履歴が複雑化するため新ルート全体を中断する
if [ -f "$MAIN_REPO/.git/MERGE_HEAD" ]; then
  echo "⚠️ メインリポで前回のマージが進行中（.git/MERGE_HEAD 検出）。新ルートを中断します。"
  echo "  対応: cd $MAIN_REPO で git status を確認し、競合解決→commit、または git merge --abort してから wt-clean を再実行してください。"
  exit 1   # 新ルート全体を中断
fi
```

#### 5b-3. マージ実行

```bash
cd "$MAIN_REPO"
# MAIN_BRANCH チェックアウト確認済み（5b-2）

# 当該 worktree のブランチをマージ。fast-forward は禁止 → --no-ff 必須
git -C "$MAIN_REPO" merge "$BRANCH_NAME" --no-ff \
  -m "merge: integrate $BRANCH_NAME (wt-clean active merge)"

if [ $? -eq 0 ]; then
  # マージ成功 → MERGED_BRANCHES に追記
  MERGED_BRANCHES+=("$BRANCH_NAME")
  echo "  ✅ マージ成功（${BRANCH_NAME}）→ Step 6 サニティチェック対象に追加"
else
  # 競合発生 → 5b-4 へ
  :
fi
```

成功時の表示:

```
🔴 wip-z を main にマージ中:
  cd <main-repo> && git checkout main && git merge feat-wip --no-ff -m "merge: integrate feat-wip (wt-clean active merge)"
  ✅ マージ成功（3 commits, 5 files changed）

→ Step 6 サニティチェック対象に追加（MERGED_BRANCHES に記録）
```

#### 5b-4. 競合時のエラーハンドリング

`git merge` が exit code 非 0（competing 変更で競合）を返した場合:

- `git merge --abort` は **自動実行しない**（SHALL NOT）。`MAIN_BRANCH` は merge 進行中状態（`.git/MERGE_HEAD` 存在）のまま保持する。
- すでにマージ成功した worktree（`MERGED_BRANCHES` に記録されたもの）も含めて **Step 6 サニティチェック以降を実行せず**、全て削除保留する（中途半端な状態を避けるため安全側に倒す）。
- 残りの 🔴 worktree（未処理分）も処理せず、未処理として完了レポートに表示する。
- 完了レポート（Step 8）の「競合保留時」表示に分岐する。

```
⚠️ マージで競合が発生しました:
  Branch: feat-wip → main
  Conflict files:
    src/foo.ts
    src/bar.ts

対応手順:
  1. cd <main-repo>
  2. 競合を解決して `git add` + `git commit`
  3. wt-clean を再実行

※ feat-wip worktree は削除されていません（競合状態を保持しています）。
※ 他の 🔴 worktree の処理も中断しました（順序依存を避けるため）。
※ すでに今回 wt-clean でマージ成功した 🔴 worktree（MERGED_BRANCHES に記録されたもの）も Step 6 サニティチェック以降を実行せず、削除を全て保留します（中途半端な状態を避けるため安全側に倒す）。
※ `git merge --abort` で main を元に戻したい場合は手動で実行してください（自動 abort はしません）。
```

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

**重要**: チェック失敗時、該当worktreeだけでなく、そのworktreeのマージ以降にマージされたworktreeも全て削除を保留する（マージ順序が影響するため）。`--keep` 指定時も同様に、FAIL した worktree およびそれ以降の worktree は**削除も再利用化も保留**する（安全側に倒す）。

#### 6d. チェック対象の範囲

新ルート（Step 5a / 5b）でマージ昇格した worktree もサニティチェック対象に含めるため、判定ロジックは以下の OR で記述する:

- 🟢 Safe かつ「今回の wt-clean で新たにマージした」worktree（既存判定） → チェック対象
- **または** ブランチ名が `MERGED_BRANCHES` 配列に含まれる worktree（新ルートでマージ昇格した 🔴 → 🟢 相当） → チェック対象
- 🟢 Safe で「以前からマージ済み」の worktree → チェック不要（既にメインに統合済み）
- 🟡 Recoverable → チェック対象（LLMコピー後、削除前に）

```bash
# 擬似コード: チェック対象判定
for WT in "${ALL_WORKTREES[@]}"; do
  BRANCH=$(get_branch "$WT")
  if is_freshly_merged_safe "$WT" || array_contains "$BRANCH" "${MERGED_BRANCHES[@]}" || is_recoverable "$WT"; then
    CHECK_TARGETS+=("$WT")
  fi
done
```

チェックは**バッチ実行**する。個別のworktreeごとではなく、全マージ完了後に1回だけ実行する（テスト実行コストを最小化）。

**競合発生で中断した場合の特例**: Step 5b で `git merge` 競合が発生して中断した場合、`MERGED_BRANCHES` に既に記録されている worktree も含めて Step 6 自体を実行しない。全 worktree を削除せず保留する（既存 Step 6c「FAIL したマージ以降を保留」と同じ思想で、安全側に倒す）。

### Step 7: 削除 / 再利用 実行

**Step 6 でチェックPASSしたworktreeのみ処理する。**

モードに応じて分岐する:
- オプションなし（デフォルト） → **Step 7a: 削除モード**
- `--keep` 指定 → **Step 7b: 再利用モード**（🟢 Safe のみ対象）

いずれのモードでも、🟡 Recoverable は **Step 7a（削除）** で処理する（未コミット変更を main に戻す際の事故リスクを避けるため）。🔴 Active は明示指示がない限り常にスキップ。

#### Step 7a: 削除モード

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

#### Step 7b: 再利用モード（`--keep` 指定時、🟢 Safe のみ）

🟢 Safe worktree に対してのみ実行する。処理前に main/master の重複チェックアウト競合を検査する。

```bash
# main or master を自動検出（Step 1 と同じロジック）
MAIN_BRANCH="main"
git show-ref --verify --quiet refs/heads/master && MAIN_BRANCH="master" || true

# 他の worktree が既に MAIN_BRANCH をチェックアウトしているか確認
# `git worktree list` の末尾カラムは `[branch-name]` 形式
OTHER_CHECKOUT=$(git worktree list | awk -v b="[$MAIN_BRANCH]" '$NF==b {print $1}' | grep -v "^$MAIN_REPO$" | head -1)

if [ -n "$OTHER_CHECKOUT" ]; then
  echo "⚠️ $MAIN_BRANCH は $OTHER_CHECKOUT で既にチェックアウト中"
  echo "  $WORKTREE_PATH の再利用化をスキップ（競合のため）"
  # このworktreeは再利用化対象から除外、次のworktreeへ
else
  # 再利用化実行
  git -C "$WORKTREE_PATH" checkout "$MAIN_BRANCH"
  git branch -d "$BRANCH_NAME"
  # worktree ディレクトリは残す。node_modules / .env / untracked は全て保持される
fi
```

**メインリポ自体が main をチェックアウトしている状態は競合ではない**（通常運用）。`grep -v "^$MAIN_REPO$"` で除外する。

**Step 7b 内（worktree 内）で実行してはならない操作** (SHALL NOT):
- `git -C "$WORKTREE_PATH" reset --hard` — 万一 tracked 変更が残っていた場合に破壊する
- `git -C "$WORKTREE_PATH" clean -fd` — `node_modules` / `.env` / 作業中ファイルを消してしまう
- `git -C "$WORKTREE_PATH" pull` / `git -C "$WORKTREE_PATH" fetch` — worktree 内での remote 操作は tracked 変更を巻き込むリスク。`<main>` の最新化は Step 0 がメインリポで実行済み

**🟢 Safe が 0 件の場合**: 「再利用化対象なし（🟢 Safe worktree がありません）」とレポートに明示し、🟡/🔴 に対する従来処理を継続する。`--keep` 指定だけでエラーにはしない。

### Step 8: 完了レポート

完了レポートの先頭に Step 0 の同期結果を 1 行で表示する。表記は以下のいずれか:

- `Remote 同期: ✅ pulled N commits (origin/<main> → <main>)` — fast-forward pull 実行時
- `Remote 同期: ✅ already up-to-date` — pull 不要時
- `Remote 同期: -- skipped (--no-sync)` — `--no-sync` 指定時
- `Remote 同期: -- skipped (no origin remote)` — origin remote 不在時

#### 削除モード（デフォルト）

```
wt-clean 完了:
  Remote 同期: ✅ pulled 3 commits (origin/main → main)
  処理: 2 worktrees
  削除: feat-x (🟢), fix-y (🟡)
  LLMコピー: 2 files → LLM/
  サニティチェック: ✅ PASS (npm test, npm run build)
  スキップ: wip-z (🔴 active)
  残存worktrees: 1
```

#### 再利用モード（`--keep` 指定）

```
wt-clean --keep 完了:
  Remote 同期: ✅ already up-to-date
  処理: 2 worktrees
  再利用可能化: feat-x (🟢)
    ディレクトリ: /Users/oratta/repo/.worktrees/feat-x
    現在ブランチ: main（元 feat-x は削除済み）
    次の作業: cd /Users/oratta/repo/.worktrees/feat-x && git checkout -b <new-branch>
  削除: fix-y (🟡)
  LLMコピー: 1 file → LLM/
  サニティチェック: ✅ PASS (npm test)
  スキップ: wip-z (🔴 active)
  残存worktrees: 2

注意:
  - package.json / Gemfile 等が更新されていれば、再作業前に依存を再インストールしてください
  - 必ず `git checkout -b <new-branch>` で新ブランチを切ってから作業を開始してください（main で直接作業しない）
```

再利用化がスキップされた場合（競合・0件）も明示する:
```
  再利用可能化: なし (🟢 Safe が 0 件)
```
または
```
  再利用可能化スキップ: feat-x — main が別worktreeで使用中のため
```

#### --no-sync 指定時

```
wt-clean --no-sync 完了:
  Remote 同期: -- skipped (--no-sync)
  処理: 1 worktree
  削除: feat-x (🟢)
  ...
```

#### チェック失敗時（削除モード・再利用モード共通）

```
wt-clean 完了:
  Remote 同期: ✅ pulled 3 commits (origin/main → main)
  処理: 1 worktree
  削除: feat-x (🟢)
  ⚠️ チェック失敗で保留: fix-y (🟡) — npm test FAIL
      → 削除も再利用化も行われていません
  スキップ: wip-z (🔴 active)
  残存worktrees: 2
```

#### 新ルート（🔴 マージ確認）成功時

```
wt-clean 完了:
  Remote 同期: ✅ pulled 0 commits (already up-to-date)
  処理: 2 worktrees
  🔴 マージ→削除: wip-z (3 commits merged)
  削除: feat-x (🟢)
  サニティチェック: ✅ PASS (npm test, npm run build)
  スキップ: なし
  残存worktrees: 0
```

#### 新ルート × `--keep` 指定時（マージ後は通常削除にフォールバック）

```
wt-clean --keep 完了:
  Remote 同期: ✅ already up-to-date
  処理: 1 worktree
  🔴 マージ→削除（--keep 指定だが新ルートのため通常削除）: wip-z (3 commits merged)
    理由: マージ後はブランチが削除済みで「再利用化＝main切替」が実質ノーオペのため
  サニティチェック: ✅ PASS
  残存worktrees: 0
```

#### 新ルート × 競合保留時（複数 🔴 を順次処理中に競合発生 → 既マージ成功分も全保留）

```
wt-clean 中断:
  Remote 同期: ✅ already up-to-date
  処理: 3 worktrees (中断)
  🔴 マージ成功・削除保留: wip-z (3 commits merged, awaiting conflict resolution)
      → 競合解決後の wt-clean 再実行時に Step 6 サニティチェック以降を実行します
  ⚠️ マージ競合で中断: wip-y (src/foo.ts, src/bar.ts)
      → 競合解決後に wt-clean を再実行してください
  未処理: wip-x (🔴)
  残存worktrees: 3
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
