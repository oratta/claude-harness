---
name: wt-clean
description: Git worktreeの安全なクリーンアップ。対象を「選んでから」1個ずつ遅延診断＆対話処理する選択ベースフロー。`wt-clean <path|branch>` でその worktree だけにスコープ（複数可）、引数なしなら worktree をリストアップして対象を選ぶ（「全て」あり）。選択後に各対象を i/N 進捗付きで診断（🟢🟡🔴）し、🟢→削除/再利用・🟡→LLM退避→削除・🔴→マージ/スキップ/破棄 を対話。Step 0で `origin/<main>` を同期。`--keep` で 🟢 を再利用可能化、`--no-sync` で同期スキップ。「worktree整理」「ワークツリークリーン」「worktree削除」「worktree再利用」「PRマージ後の整理」「プルリク後の片付け」「特定worktreeだけ片付け」「未マージworktreeのマージ」で起動。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# wt-clean — Worktree クリーンアップスキル

Git worktree を安全にクリーンアップするスキル。

**設計の核**: 「対象を選ぶ → 選んだものだけ 1 個ずつ遅延診断＆対話処理」。最初に全件を診断（🟢🟡🔴 分類）せず、対象を確定してから 1 件ずつその場で診断する。パス／ブランチ名引数は「対象選択を引数で前倒ししたショートカット」であり、引数あり／なしのどちらも `TARGETS を確定 → 1 個ずつ処理` という共通パイプラインに合流する。

```
Step 0  Remote 同期（--no-sync で skip）
   │
Step A  TARGETS 確定
   ├ 引数あり <path|branch> … → 引数を解決して TARGETS に（リスト/選択はしない）
   └ 引数なし → リストアップ（診断しない）→ 対象選択（全て/個別/キャンセル）
   │
Step B  TARGETS を [i/N] 進捗で 1 個ずつ:  遅延診断 → カテゴリ別対話
   │       🟢 削除（--keep なら再利用化） / 🟡 LLM退避→削除 / 🔴 マージ/スキップ/破棄
Step C  完了レポート
```

## オプションと引数

- **位置引数 `<path|branch> …`**（任意・複数可）: 処理対象を絞る。指定した worktree のみを対象にし、他は完全に無視する。引数があるとリストアップ・対象選択をスキップする
- **オプションなし（デフォルト）**: 削除モード。🟢 Safe はディレクトリごと削除する
- **`--keep`**: 再利用モード。🟢 Safe はディレクトリを残し、worktree 内のブランチを main に戻して元ブランチを削除する（`node_modules` / `.env` / 未追跡ファイルは保持）。🟡 は削除、🔴 はマージ後通常削除へフォールバック
- **`--no-sync`**: Step 0 の Remote 同期をスキップする。`--keep` や位置引数と併用可能（例: `wt-clean --keep --no-sync ~/wt/foo`）

例:
- `wt-clean` → 全 worktree をリストアップして対象を選ぶ
- `wt-clean ~/wt/foo` → `foo` だけを対象に診断・処理
- `wt-clean feat-x` → `feat-x` をチェックアウト中の worktree を逆引きして対象に
- `wt-clean ~/wt/foo feat-y` → 2 件を対象に

## 前提条件

- メインリポのルートで実行すること（worktree 内ではなく）
- worktree 内で実行した場合: 「メインリポで実行してください」と案内

## 絶対禁則（最優先・データロス防止）

このスキルは `git worktree remove` / `git branch -D` という**取り消し不能な破壊操作**を含む。以下は他のどのルールよりも優先する。違反すると過去に「ユーザーが作業中の worktree（成果が LLM ログのみに残る設計議論セッション）を誤削除する」事故が発生している。

1. **AskUserQuestion の回答を待たずに破壊操作を実行してはならない（最重要）**
   - `git worktree remove` / `git branch -d` / `git branch -D` は、対象を確定する AskUserQuestion の**回答を受け取った後の、別のアシスタントターンで**実行する。
   - AskUserQuestion ツール呼び出しと、削除を実行する Bash 呼び出しを**同一ターンの並列ツール呼び出しに含めてはならない**。並列にするとユーザーの回答が届く前に削除が走り、回答が「やめて」「対象が違う」でも手遅れになる。
   - 回答が届いたら、その回答が**どの worktree を指しているか**を文章で読み直し、対象を再確定してから実行する。曖昧な回答は「削除してよい」と解釈せず一度確認する。
   - これは Step A-2 の対象選択、Step B の各カテゴリ削除対話の両方に適用する。

2. **「マージ済み & クリーン」でも LLM ログがある worktree は🟢 Safe にしない**
   - 独自 commit が無く working tree がクリーンでも、`LLM/` にログがある worktree は**現在進行中の作業セッション**の可能性が高い。Step B 診断で🟢 Safe に分類せず、必ず🟡 Recoverable 扱いとし、LLM を保全してから確認する（分類表を厳守）。
   - 設計議論・調査中心のセッションは git に commit が残らず、成果が `LLM/` ログにしか存在しないことがある。LLM ログの消失は復元困難なため保全を最優先する。

3. **削除判定は必ず実ブランチ名で行う（ディレクトリ名 ≠ ブランチ名）**
   - worktree のディレクトリ名と checkout 中ブランチ名は一致しないことがある（例: `setup-foo` ディレクトリで `ISSUE-129_xxx` ブランチを checkout）。マージ判定・`git branch -D` は `git worktree list` 由来の**実ブランチ名（`BRANCH_NAME`）**を使う。ディレクトリ名で判断しない。

4. **破壊操作の前に LLM 保全を済ませる**
   - `git worktree remove --force` は gitignore 対象（`LLM/`・`node_modules`・`.env`）も巻き込んで削除する。削除前に `LLM/` をメインリポへコピーする（Step B-🟡）。
   - 万一保全前に削除してしまった場合、`~/.claude/projects/<worktree-path-slug>/<session>.jsonl` にセッション生ログが残っていれば LLM ログを再生成できる。worktree とブランチは `git worktree add <path> -b <branch> <last-sha>` で復旧できる。

加えて、本スキル固有の SHALL NOT:

- 引数の曖昧マッチ（複数件ヒット）を**自動選択しない**。必ず候補提示して中断する（Step A-1）
- 競合発生時に `git merge --abort` を**自動実行しない**（Step B-🔴）
- Step B 再利用化（worktree 内）で `git reset --hard` / `git clean -fd` / worktree 内 `git pull` / `git fetch` を**実行しない**

## 実行フロー

### Step 0: Remote 同期（Sync）

GitHub 側で PR がマージされた feature ブランチを後段のマージ済み判定（`git branch --merged`）で正しく Safe 判定するため、対象選択・診断に先立ってローカル `<main>` を `origin/<main>` に同期する。`--no-sync` 指定時はこの Step を完全にスキップする。**位置引数で対象を指定した場合も Step 0 は実行される**（単一対象のマージ済み判定を正確にするため。`--no-sync` で停止可能）。

```bash
# --no-sync 指定時は即座にスキップ
if [ "$NO_SYNC" = "1" ]; then
  echo "Remote 同期: -- skipped (--no-sync)"
  # Step A へ進む
fi

# origin remote の存在確認
if ! git remote get-url origin >/dev/null 2>&1; then
  echo "Remote 同期: -- skipped (no origin remote)"
  # Step A へ進む
fi

# main / master 検出
MAIN_BRANCH="main"
git show-ref --verify --quiet refs/heads/master && MAIN_BRANCH="master" || true

# fetch
git fetch origin   # 失敗時はエラー中断、後続 Step に進まない

# 進行差を測定（左=ローカル独自, 右=remote 独自）
read AHEAD BEHIND < <(git rev-list --left-right --count "$MAIN_BRANCH"...origin/"$MAIN_BRANCH" | awk '{print $1, $2}')

if [ "$BEHIND" = "0" ]; then
  echo "Remote 同期: ✅ already up-to-date"
elif [ "$AHEAD" = "0" ]; then
  git pull --ff-only origin "$MAIN_BRANCH"   # 失敗時はエラー中断
  echo "Remote 同期: ✅ pulled $BEHIND commits (origin/$MAIN_BRANCH → $MAIN_BRANCH)"
else
  echo "⚠️ ローカル $MAIN_BRANCH が origin/$MAIN_BRANCH と diverge しています"
  echo "  AHEAD=$AHEAD, BEHIND=$BEHIND"
  echo "  git status / git log で状態を確認し、解消後に再実行してください"
  echo "  （または --no-sync で同期をスキップして実行）"
  exit 1
fi
```

**失敗時の扱い**:
- `git fetch origin` 失敗（ネットワーク到達不能等）→ エラー中断。再実行 or `--no-sync` を案内
- `git pull --ff-only` 失敗（diverge / force-push）→ エラー中断。`git status` で状態確認するよう案内
- 中断時、Step C 完了レポートは表示しない

**禁則**: 本 Step では `git pull --ff-only` 以外の pull 戦略（merge / rebase）を使ってはならない。

### Step A: TARGETS 確定

#### Step A-1: 位置引数あり → 引数を解決

位置引数（パス／ブランチ名）が 1 個以上ある場合、リストアップ・対象選択を**行わず**、各引数トークンを解決して `TARGETS` に格納する。

```bash
# 解決ロジック（各トークンごと）
MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')

resolve_token() {
  local token="$1"
  # 1. realpath 正規化 → worktree list の絶対パスと完全一致
  local abs
  abs=$(realpath -m "$token" 2>/dev/null)
  local matches
  matches=$(git worktree list --porcelain | awk '/^worktree /{print $2}' | grep -Fx "$abs")

  # 2. パス一致しなければブランチ名として逆引き
  if [ -z "$matches" ]; then
    matches=$(git worktree list --porcelain | awk '
      /^worktree /{wt=$2}
      /^branch /{sub("refs/heads/","",$2); if($2=="'"$token"'") print wt}
    ')
  fi

  echo "$matches"
}
```

各トークンの解決結果に応じて分岐:

- **マッチ 1 件かつメインリポでない** → `TARGETS` に追加
- **マッチ 0 件** → エラー: 「`<token>` に一致する worktree がありません」+ 現存 worktree 一覧を提示して**中断**（処理しない）
- **マッチ複数件** → 候補一覧を提示し、絶対パスでの再指定を促して**中断**（自動選択しない）
- **メインリポ自身を指す** → 「メインリポは削除対象外です」と表示して**中断**

```
❌ 'foo' に一致する worktree がありません。
現存 worktree:
  /Users/oratta/wt/bar  (fix-y, 3週間前)
  /Users/oratta/wt/baz  (wip-z, 今日)
絶対パスまたは正確なブランチ名で再指定してください。
```

全トークンの解決に成功したら Step B へ。

#### Step A-2: 位置引数なし → リストアップ → 対象選択

**リストアップ（遅延診断: 色を出さない）**

`git worktree list` を並べるだけにする。この時点で 🟢🟡🔴 のマージ済み判定・dirty スキャン・LLM 検出・未マージコミット数算出は**行わない**（SHALL NOT）。表示する情報は git 軽量コマンドで即取れるものに限定する:

```bash
# メインリポ自身は対象外。各 worktree のブランチ名と最終コミット日（相対）を表示
git worktree list --porcelain | awk '
  /^worktree /{wt=$2}
  /^branch /{sub("refs/heads/","",$2); print wt"\t"$2}
  /^detached/{print wt"\t(detached HEAD)"}
' | while IFS=$'\t' read -r WT BR; do
  [ "$WT" = "$MAIN_REPO" ] && continue
  LAST=$(git -C "$WT" log -1 --format='%cr' 2>/dev/null)
  echo "  $WT  ($BR, $LAST)"
done
```

```
Worktree 一覧（診断前 / どれに wt-clean を適用するか選んでください）:
  /Users/oratta/wt/foo  (feat-x, 2日前)
  /Users/oratta/wt/bar  (fix-y, 3週間前)
  /Users/oratta/wt/baz  (wip-z, 今日)
```

**対象選択 UI（AskUserQuestion の 4 択制約に対応した 2 段構成）**

1. **入口（single-select, 3 択）** を AskUserQuestion で提示:
   - 「全て」→ 全 worktree を `TARGETS` に
   - 「個別に選ぶ」→ 続く multiSelect へ
   - 「キャンセル」→ 何も処理せず終了

2. 「個別に選ぶ」が選ばれたら、worktree を **4 件ずつのバッチ** に分けた multiSelect 質問で対象を選ばせる。1 回の AskUserQuestion 呼び出しは最大 4 問なので、1 回で最大 4 問 × 4 件 = 16 件まで提示できる。worktree が 16 件を超える場合は AskUserQuestion を複数回に分け、各回の提示範囲を `log`（例: 「17〜32 件目を提示中」）で明示する（無音での打ち切りを行わない）。

選択された worktree が `TARGETS`。0 件なら「対象が選択されませんでした」と表示して終了。

### Step B: 逐次処理ループ（遅延診断 + カテゴリ別対話）

確定した `TARGETS` を `git worktree list` の順に 1 件ずつ、`[i/N]` 進捗表示付きで処理する。

> ⚠️ **絶対禁則 1 の再掲**: 各対象の削除／破棄／再利用化は、その対象の AskUserQuestion 回答を**受け取った後の別ターン**で実行する。AskUserQuestion ツール呼び出しと削除 Bash を**同一ターンの並列ツール呼び出しに含めてはならない**。回答が届いたら対象を読み直して再確定してから削除する。

```bash
# 競合中断などで先行処理済みを確定扱いするためのカウンタ
PROCESSED=()   # 削除/再利用化が完了したもの
SKIPPED=()     # スキップ
HELD=()        # サニティ FAIL / 競合で保留・未処理
N=${#TARGETS[@]}
i=0
```

各 `WT`（`BRANCH_NAME` は `git worktree list` 由来のチェックアウト中ブランチ名）について:

```bash
i=$((i+1))
echo "[$i/$N] $WT をチェック中…"
```

**遅延診断**（この対象についてのみ実行）:

```bash
# 1. マージ済みか
MERGED=$(git branch --merged "$MAIN_BRANCH" | grep -E "[[:space:]]$BRANCH_NAME$" || true)
# 2. 未マージコミット数
AHEAD_COUNT=$(git log --oneline "$MAIN_BRANCH".."$BRANCH_NAME" 2>/dev/null | wc -l | tr -d ' ')
# 3. dirty
DIRTY=$(git -C "$WT" status --porcelain)
# 4. LLM/
LLM=$(ls "$WT/LLM/" 2>/dev/null)
```

分類（color は対象ごとにその場で決める）:

| カテゴリ | 条件 |
|---|---|
| 🟢 Safe | マージ済み & dirty なし & LLM なし |
| 🟡 Recoverable | マージ済み だが LLM あり or dirty あり |
| 🔴 Active | 未マージのコミットあり（`AHEAD_COUNT > 0`） |

カテゴリに応じて以下へ分岐する。

#### Step B-🟢: Safe → 削除（`--keep` 時は再利用化）

AskUserQuestion で確認（「削除」/「スキップ」、`--keep` 時は「再利用化」/「スキップ」）。

**削除モード（デフォルト）**:

```bash
git worktree remove "$WT" --force
git branch -d "$BRANCH_NAME"
PROCESSED+=("$BRANCH_NAME (🟢 削除)")
```

**再利用モード（`--keep`、🟢 のみ）**: 処理前に main/master の重複チェックアウト競合を検査する。

```bash
# 他の worktree が既に MAIN_BRANCH をチェックアウトしているか
OTHER_CHECKOUT=$(git worktree list | awk -v b="[$MAIN_BRANCH]" '$NF==b {print $1}' | grep -v "^$MAIN_REPO$" | head -1)

if [ -n "$OTHER_CHECKOUT" ]; then
  echo "⚠️ $MAIN_BRANCH は $OTHER_CHECKOUT で既にチェックアウト中 → $WT の再利用化をスキップ"
  HELD+=("$BRANCH_NAME (再利用化スキップ: main 使用中)")
else
  git -C "$WT" checkout "$MAIN_BRANCH"
  git branch -d "$BRANCH_NAME"
  PROCESSED+=("$BRANCH_NAME (🟢 再利用化)")
  # worktree ディレクトリは残す。node_modules / .env / untracked は全て保持
fi
```

**禁則（worktree 内, SHALL NOT）**: `git -C "$WT" reset --hard` / `git -C "$WT" clean -fd` / `git -C "$WT" pull` / `git -C "$WT" fetch`。`<main>` の最新化は Step 0 がメインリポで実行済み。

マージを伴わない 🟢 再利用化・🟡 削除では**サニティチェックを走らせない**（既に main にマージ済みのため）。

#### Step B-🟡: Recoverable → LLM 退避 → 削除

```bash
# LLM ファイルをメインリポに退避（ファイル名にセッションIDが含まれ衝突しない）
mkdir -p "$MAIN_REPO/LLM"
cp "$WT/LLM/"* "$MAIN_REPO/LLM/" 2>/dev/null
```

dirty がある場合は `git -C "$WT" diff --stat` を表示し、AskUserQuestion で「変更を破棄して削除」/「スキップ」を確認。削除する場合:

```bash
git worktree remove "$WT"        # 確認済み（dirty 破棄時は --force）
git branch -d "$BRANCH_NAME"
PROCESSED+=("$BRANCH_NAME (🟡 LLM退避→削除)")
```

#### Step B-🔴: Active → マージ / スキップ / 破棄

未マージコミット一覧・Dirty 状態・LLM 有無を表示し、AskUserQuestion で確認する。**独立した一括ルートは経由しない**（その場で対話）。

```
[i/N] baz の処理:
  Branch: wip-z
  未マージコミット: 3件
    abc1234 feat: ユーザー登録フォームの追加
    def5678 fix: バリデーションエラー
    ghi9012 chore: テスト整備
  Dirty: なし
  LLM: なし
```

選択肢の出し分け:

- **通常（Dirty なし & ブランチ名あり）**: 「1) main にマージ (推奨) / 2) スキップ / 3) 破棄削除 (force)」の 3 択
- **Dirty 同時**: マージ選択肢を**除外**し「1) スキップ / 2) 破棄削除 (force)」の 2 択。理由明示「⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）」
- **detached HEAD（`BRANCH_NAME` 空）**: マージ選択肢を除外し同 2 択。理由明示「⚠️ detached HEAD のためマージできません（マージ対象のブランチ名がありません）」
- Dirty と detached が両方該当する場合も 2 択を提示し、両方の理由を併記する

**選択ごとの分岐**:

- **スキップ** → 状態維持。`SKIPPED+=("$BRANCH_NAME")`
- **破棄削除 (force)** →
  ```bash
  git worktree remove --force "$WT"
  git branch -D "$BRANCH_NAME"
  PROCESSED+=("$BRANCH_NAME (🔴 破棄削除)")
  ```
- **マージ** → 下記マージ実行へ

**マージ実行**（メインリポで `MAIN_BRANCH` チェックアウト下、`--no-ff` 必須）:

事前確認（いずれか該当ならマージ処理を中断し案内）:

```bash
CURRENT_BRANCH=$(git -C "$MAIN_REPO" branch --show-current)
if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
  echo "⚠️ メインリポが $MAIN_BRANCH 以外をチェックアウト中（現在: $CURRENT_BRANCH）。マージ処理を中断します。"
  echo "  対応: cd $MAIN_REPO && git checkout $MAIN_BRANCH してから wt-clean を再実行してください。"
  # この対象は HELD、ループ中断
fi
if [ -f "$MAIN_REPO/.git/MERGE_HEAD" ]; then
  echo "⚠️ メインリポで前回のマージが進行中（.git/MERGE_HEAD 検出）。マージ処理を中断します。"
  echo "  対応: cd $MAIN_REPO で git status を確認し、競合解決→commit、または git merge --abort してから再実行してください。"
  # この対象は HELD、ループ中断
fi
```

マージ:

```bash
git -C "$MAIN_REPO" merge "$BRANCH_NAME" --no-ff \
  -m "merge: integrate $BRANCH_NAME (wt-clean active merge)"
```

- **成功** → そのまま Step B-サニティ（マージ都度）へ
- **競合（exit 非 0）** → `git merge --abort` は**自動実行しない**（SHALL NOT）。`.git/MERGE_HEAD` を保持したまま中断する。
  - 競合より前に処理（削除/再利用化）が完了した先行 `TARGETS`（`PROCESSED`）は**確定済みとして扱い巻き戻さない**
  - 競合した worktree（`HELD`）以降の未処理 `TARGETS` は処理しない
  - ループを抜けて Step C（競合中断レポート）へ

```
⚠️ マージで競合が発生しました:
  Branch: wip-z → main
  Conflict files:
    src/foo.ts
対応手順:
  1. cd <main-repo>
  2. 競合を解決して `git add` + `git commit`
  3. wt-clean を再実行
※ wip-z worktree は削除されていません（競合状態を保持）。
※ 以降の未処理対象も処理を中断しました。
※ `git merge --abort` で main を戻したい場合は手動で実行してください（自動 abort はしません）。
```

**Step B-サニティ（マージ都度）**:

マージ成功直後に、そのマージ分についてメインリポでテスト/ビルドを実行する。

```bash
cd "$MAIN_REPO"
# テストコマンド自動検出（最初に見つかったスタックを使用）
# Node.js : package.json の scripts から test/lint/typecheck/build
#   例: npm test, npm run lint, npm run typecheck, npm run build
# Rust    : Cargo.toml → cargo test, cargo clippy, cargo build
# Python  : pyproject.toml / setup.py → pytest
# Go      : go.mod → go test ./..., go vet ./...
# 見つからなければスキップして削除へ
```

- **全 PASS（またはテスト未検出）** → 通常削除（`--keep` 指定でもマージを伴うため**通常削除**にフォールバック）:
  ```bash
  git worktree remove "$WT" --force
  git branch -d "$BRANCH_NAME"
  PROCESSED+=("$BRANCH_NAME (🔴 マージ→削除, N commits)")
  ```
- **FAIL** → 当該 worktree は削除せず保留:
  ```
  ⚠️ マージ後チェックで問題が検出されました:
    失敗コマンド: npm test
    エラー出力: [抜粋]
    このマージ（wip-z）が原因の可能性があります。
  → この worktree は削除せず保持します。
  ```
  `HELD+=("$BRANCH_NAME (サニティ FAIL 保留)")`。FAIL 後は安全側に倒し、ユーザーに「以降の処理を続けるか中断するか」を AskUserQuestion で確認する。

### Step C: 完了レポート

先頭に Step 0 の同期結果を 1 行で表示する:
- `Remote 同期: ✅ pulled N commits (origin/<main> → <main>)`
- `Remote 同期: ✅ already up-to-date`
- `Remote 同期: -- skipped (--no-sync)`
- `Remote 同期: -- skipped (no origin remote)`

続けて `PROCESSED` / `SKIPPED` / `HELD` と残存 worktree 件数を区別表示する。

```
wt-clean 完了:
  Remote 同期: ✅ pulled 3 commits (origin/main → main)
  対象: 4 worktrees（選択: 全て）
  削除: feat-x (🟢), bar (🟡 LLM退避→削除)
  再利用化: -
  🔴 マージ→削除: wip-z (3 commits merged)
  サニティチェック: ✅ PASS (npm test, npm run build)
  スキップ: -
  LLMコピー: 2 files → LLM/
  残存worktrees: 1
```

**再利用モード（`--keep`）** のレポートには、再利用化した worktree ごとにディレクトリパスと次作業コマンドを含める:

```
  再利用化: feat-x
    ディレクトリ: /Users/oratta/repo/.worktrees/feat-x
    現在ブランチ: main（元 feat-x は削除済み）
    次の作業: cd /Users/oratta/repo/.worktrees/feat-x && git checkout -b <new-branch>
注意:
  - package.json / Gemfile 等が更新されていれば、再作業前に依存を再インストールしてください
  - 必ず git checkout -b <new-branch> で新ブランチを切ってから作業を開始してください
```

**サニティ FAIL 保留時**:
```
  ⚠️ チェック失敗で保留: fix-y — npm test FAIL
      → 削除も再利用化も行われていません
```

**競合中断時**:
```
wt-clean 中断:
  Remote 同期: ✅ already up-to-date
  対象: 3 worktrees（中断）
  削除確定: feat-a (🔴 マージ→削除, 確定済み)
  ⚠️ マージ競合で中断: feat-b (src/foo.ts)
      → 競合解決後に wt-clean を再実行してください
  未処理: feat-c
  残存worktrees: 2
```

## 🔴 Active worktree の強制破棄（破棄削除選択時）

Step B-🔴 で「破棄削除 (force)」を選んだ場合のみ:

1. 未マージコミットのログを表示
2. 未コミット変更の diff を表示
3. 「本当に削除しますか？この操作は取り消せません」と最終確認
4. LLM ファイルがあればコピー
5. `git worktree remove --force` + `git branch -D`（大文字 D = 強制削除）

## エッジケース

- メインリポ自体が worktree の場合: スキップ（削除対象外）
- detached HEAD の worktree: ブランチ削除はスキップ。🔴 判定時はマージ選択肢を除外（Step B-🔴）
- worktree のパスが存在しない（既に手動削除済み）: `git worktree prune` で整理
- Superset 作成の worktree: 削除後「Superset UI 上でも not found になるので UI から削除してください」と案内
