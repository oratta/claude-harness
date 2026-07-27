---
name: wt-clean
description: Git worktree の安全なクリーンアップ（自動処理 → 判断バッチのみ対話の 2 パス）。`wt-clean [<path|branch>…] [--keep] [--no-sync]`、引数なしは全 worktree を対象。「worktree整理」「ワークツリークリーン」「worktree削除」「worktree再利用」「PRマージ後の整理」「プルリク後の片付け」「未マージworktreeのマージ」で起動。
version: 3.1.1
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# wt-clean — Worktree クリーンアップスキル

Git worktree を安全にクリーンアップするスキル。

**設計の核**: 「対話は判断が必要な分だけに絞り、走行中はブロックしない」。ユーザーとの対話は **Pass 2 の判断バッチ**（自動処理が全部終わった後）の 1 箇所だけに寄せる。**対象選択の質問はしない** ── 引数なしなら全 worktree を確認なしで対象にし、対象を絞りたいときだけ位置引数 `<path|branch>` を渡す。ほとんどのケース（🟢 Safe と LLM 退避だけで済む 🟡）は確認なしで自動処理されるため、「実行して放っておいたら作業が終わっている。判断が必要な分だけ最後に質問が残っている」という体験になる。最初に全件を診断（🟢🟡🔴 分類）せず、対象を確定してから 1 件ずつその場で診断する点は従来どおり。パス／ブランチ名引数は「対象を絞るショートカット」であり、引数あり／なしのどちらも `TARGETS を確定 → 2 パス処理` という共通パイプラインに合流する。

```
Step 0  Remote 同期（--no-sync で skip）
   │
Step A  TARGETS 確定（対話しない）
   ├ 位置引数あり <path|branch> … → 引数を解決して TARGETS に（リスト/選択はしない）
   └ 位置引数なし → 全 worktree をリストアップして表示 → そのまま全件を TARGETS に（質問なし）
   │
Step B  Pass 1: [i/N] 進捗で 1 個ずつ遅延診断 → ノンブロッキング自動処理
   │       🟢 → 根拠表示して即削除（--keep なら即再利用化）
   │       🟡 dirtyなし（LLMのみ）→ LLM退避 → 退避検証 → 即削除
   │       🔴 / dirtyあり → DEFERRED に積んで次へ（この時点では触らない）
   │
Step B  Pass 2: 判断バッチ（DEFERRED が空ならスキップ） ←― 唯一の対話ポイント
   │       状況をまとめて提示 → AskUserQuestion（1対象1問・最大4問/回）
   │       回答後の別ターンで マージ/スキップ/破棄 を逐次実行
Step C  完了レポート
```

## オプションと引数

- **位置引数 `<path|branch> …`**（任意・複数可）: 処理対象を絞る。指定した worktree のみを対象にし、他は完全に無視する。位置引数があると全件対象化をスキップして、その worktree だけを対象にする
- **位置引数なし（`--keep` / `--no-sync` のみ・完全無指定を含む）**: 全 worktree を確認なしで対象にする。対象選択の質問（全て/個別/キャンセル）はしない
- **オプションなし（デフォルト）**: 削除モード。🟢 Safe はディレクトリごと削除する
- **`--keep`**: 再利用モード。🟢 Safe はディレクトリを残し、worktree 内のブランチを main に戻して元ブランチを削除する（`node_modules` / `.env` / 未追跡ファイルは保持）。🟡 は削除、🔴 はマージ後通常削除へフォールバック
- **`--no-sync`**: Step 0 の Remote 同期をスキップする。`--keep` や位置引数と併用可能（例: `wt-clean --keep --no-sync ~/wt/foo`）

例:
- `wt-clean` → 全 worktree を確認なしで対象に診断・処理
- `wt-clean ~/wt/foo` → `foo` だけを対象に診断・処理
- `wt-clean feat-x` → `feat-x` をチェックアウト中の worktree を逆引きして対象に
- `wt-clean ~/wt/foo feat-y` → 2 件を対象に

## 前提条件

- メインリポのルートで実行すること（worktree 内ではなく）
- worktree 内で実行した場合: 「メインリポで実行してください」と案内

## 絶対禁則（最優先・データロス防止）

このスキルは `git worktree remove` / `git branch -D` という**取り消し不能な破壊操作**を含む。以下は他のどのルールよりも優先する。違反すると過去に「ユーザーが作業中の worktree（成果が LLM ログのみに残る設計議論セッション）を誤削除する」事故が発生している。

1. **破壊操作の実行条件を守る（最重要）**

   破壊操作は「自動実行してよいもの」と「AskUserQuestion 必須のもの」に区分される。この区分を勝手に拡大解釈してはならない。

   **自動実行してよい**（Step A で TARGETS に含めたことを承認とみなす）:
   - 🟢 Safe（マージ済み & dirty なし & LLM なし）の削除・再利用化
   - 🟡 で dirty なし（LLM のみ）の、**LLM 退避の実在検証成功後**の削除
   - いずれも削除直前に**診断根拠（マージ済み判定の根拠）を必ず表示**する。無音削除は禁止。

   **AskUserQuestion の回答後の別ターンでのみ実行してよい**（自動実行の絶対禁止）:
   - dirty な変更の破棄（🟡 dirty あり・🔴 dirty あり）
   - 🔴 Active の破棄削除（`git worktree remove --force` + `git branch -D`）
   - 🔴 Active の main へのマージ
   - AskUserQuestion ツール呼び出しと、これらを実行する Bash 呼び出しを**同一ターンの並列ツール呼び出しに含めてはならない**。並列にするとユーザーの回答が届く前に実行が走り、回答が「やめて」「対象が違う」でも手遅れになる。
   - 回答が届いたら、その回答が**どの worktree を指しているか**を文章で読み直し、対象を再確定してから実行する。曖昧な回答は「実行してよい」と解釈せず一度確認する。

   自動実行が許されるのは分類が厳格であることが前提である。禁則 2（LLM→🟡 強制）・禁則 3（実ブランチ名判定）・squash 3 重検証を省略した状態での自動削除は、この区分に違反する。

2. **「マージ済み & クリーン」でも LLM ログがある worktree は🟢 Safe にしない**
   - 独自 commit が無く working tree がクリーンでも、`LLM/` にログがある worktree は**現在進行中の作業セッション**の可能性が高い。Step B 診断で🟢 Safe に分類せず、必ず🟡 Recoverable 扱いとし、LLM を保全してから確認する（分類表を厳守）。
   - 設計議論・調査中心のセッションは git に commit が残らず、成果が `LLM/` ログにしか存在しないことがある。LLM ログの消失は復元困難なため保全を最優先する。

3. **削除判定は必ず実ブランチ名で行う（ディレクトリ名 ≠ ブランチ名）**
   - worktree のディレクトリ名と checkout 中ブランチ名は一致しないことがある（例: `setup-foo` ディレクトリで `ISSUE-129_xxx` ブランチを checkout）。マージ判定・`git branch -D` は `git worktree list` 由来の**実ブランチ名（`BRANCH_NAME`）**を使う。ディレクトリ名で判断しない。

4. **破壊操作の前に LLM 保全を済ませ、退避の実在を検証する**
   - `git worktree remove --force` は gitignore 対象（`LLM/`・`node_modules`・`.env`）も巻き込んで削除する。削除前に `LLM/` をメインリポへコピーする（Step B-🟡）。
   - **退避検証の成功が 🟡 自動削除の前提**。コピー後、退避先に元と同数のファイルが実在し空でないことを確認できるまで削除してはならない。検証に失敗したら削除せず HELD として保留する。
   - 万一保全前に削除してしまった場合、`~/.claude/projects/<worktree-path-slug>/<session>.jsonl` にセッション生ログが残っていれば LLM ログを再生成できる。worktree とブランチは `git worktree add <path> -b <branch> <last-sha>` で復旧できる。

加えて、本スキル固有の SHALL NOT:

- 引数の曖昧マッチ（複数件ヒット）を**自動選択しない**。必ず候補提示して中断する（Step A-1）
- 競合発生時に `git merge --abort` を**自動実行しない**（Step B Pass 2）
- Step B 再利用化（worktree 内）で `git reset --hard` / `git clean -fd` / worktree 内 `git pull` / `git fetch` を**実行しない**

## 実行フロー

### Step 0: Remote 同期（Sync）

GitHub 側で PR がマージされた feature ブランチを後段のマージ済み判定（`git branch --merged`）で正しく Safe 判定するため、対象選択・診断に先立ってローカル `<main>` を `origin/<main>` に同期する。`--no-sync` 指定時はこの Step を完全にスキップする。**位置引数で対象を指定した場合も Step 0 は実行される**（単一対象のマージ済み判定を正確にするため。`--no-sync` で停止可能）。

> ⚠️ **この同期で救えるのは普通の merge / ff だけ**。**squash マージ**は元ブランチの SHA が main に残らないため、同期しても `git branch --merged` / `git log main..branch` は未マージと誤判定する。squash の検出は Step B の遅延診断（後述の「squash マージの罠」）で行う。Step 0 同期を怠ると squash 以前に**普通の merge すら**未マージ誤判定するので、`--no-sync` は「直前に手動同期済み」など確信がある場合のみ使う。

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

#### Step A-2: 位置引数なし → 全 worktree を確認なしで TARGETS に

位置引数がない場合（`--keep` / `--no-sync` のみ、または完全無指定）は、**対象選択の質問をせず全 worktree を `TARGETS` にする**。以前は「全て/個別/キャンセル」を AskUserQuestion で聞いていたが、これは廃止した（対象選択で処理が止まる／途中で終わる事故を防ぐため）。対象を絞りたいときは位置引数 `<path|branch>` を渡す。

> ℹ️ ここで対象選択のために `AskUserQuestion` を呼んではならない（SHALL NOT）。破壊判断が必要な 🔴 / dirty は Pass 2 で確認されるため、全件を対象にしても🟢/🟡 の安全な自動処理と 🔴/dirty の Pass 2 対話に正しく振り分けられる。

**リストアップ（遅延診断: 色を出さない・表示のみ）**

`git worktree list` を並べるだけにする。この時点で 🟢🟡🔴 のマージ済み判定・dirty スキャン・LLM 検出・未マージコミット数算出は**行わない**（SHALL NOT）。表示する情報は git 軽量コマンドで即取れるものに限定する。表示は「これから全件を対象に処理する」ことの通知であり、選択を求めるものではない:

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
Worktree 一覧（全件を対象に処理します）:
  /Users/oratta/wt/foo  (feat-x, 2日前)
  /Users/oratta/wt/bar  (fix-y, 3週間前)
  /Users/oratta/wt/baz  (wip-z, 今日)
```

リストアップした全 worktree（メインリポ自身を除く）を `TARGETS` に格納し、そのまま Step B へ進む。worktree が 0 件なら「対象の worktree がありません」と表示して終了する。

### Step B: 2 パス処理（Pass 1 自動処理 → Pass 2 判断バッチ）

確定した `TARGETS` を `git worktree list` の順に 1 件ずつ、`[i/N]` 進捗表示付きで遅延診断する。診断結果に応じて **Pass 1 で自動処理できるものは確認なしで処理**し、判断が必要なもの（🔴 / dirty）は `DEFERRED` に積んで **Pass 2 でまとめて対話**する。Pass 1 の走行中に AskUserQuestion を呼んではならない（SHALL NOT — ブロックすると「実行して放置」ができなくなる）。

> ⚠️ **絶対禁則 1 の再掲**: 🟢 と 🟡（LLM 退避検証済み・dirty なし）の削除は Step A の対象確定を承認として自動実行してよいが、診断根拠の表示を省略しない。dirty 破棄・🔴 破棄削除・🔴 マージは Pass 2 の AskUserQuestion 回答を**受け取った後の別ターン**でのみ実行する。AskUserQuestion ツール呼び出しとこれらの Bash を**同一ターンの並列ツール呼び出しに含めてはならない**。回答が届いたら対象を読み直して再確定してから実行する。

```bash
# 競合中断などで先行処理済みを確定扱いするためのカウンタ
PROCESSED=()   # 削除/再利用化が完了したもの
SKIPPED=()     # スキップ
HELD=()        # サニティ FAIL / 競合 / 退避検証失敗で保留・未処理
DEFERRED=()    # 🔴 / dirty あり → Pass 2 の判断バッチへ
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
# 1. マージ済みか（SHA ベース。普通の merge / ff のみ検出できる）
MERGED=$(git branch --merged "$MAIN_BRANCH" | grep -E "[[:space:]]$BRANCH_NAME$" || true)
# 2. 未マージコミット数（SHA ベース）
AHEAD_COUNT=$(git log --oneline "$MAIN_BRANCH".."$BRANCH_NAME" 2>/dev/null | wc -l | tr -d ' ')
# 3. dirty
DIRTY=$(git -C "$WT" status --porcelain)
# 4. LLM/
LLM=$(ls "$WT/LLM/" 2>/dev/null)
```

**⚠️ squash マージの罠（最重要・必読）**: `git branch --merged` も `git log main..branch` も**コミット SHA の到達可能性**で判定する。**squash マージ**（GitHub の "Squash and merge"）では PR の全コミットが main 上で 1 個の**新しい SHA** に潰れるため、元ブランチの SHA はどれも main の祖先にならず、**実際にはマージ済みでも `AHEAD_COUNT > 0`（= 🔴 Active）と誤判定する**。Step 0 の remote 同期で救えるのは**普通の merge / ff だけ**で、squash は救えない。squash 運用のプロジェクト（PR を Squash merge で取り込む）ではほぼ全 PR がこの罠に該当する。

過去に同一セッションで 3 連続「マージ済みブランチを未マージ誤判定 → ユーザーに『ほんとに？マージ済みだと思ってる。ちゃんと確認して』と指摘される」事故が発生している。

そこで **`AHEAD_COUNT > 0` のときは即 🔴 と判定せず、squash マージ済みでないかを必ず追加検証する**:

```bash
SQUASHED=""   # squash マージ済みと判定できたら理由を入れる
if [ "$AHEAD_COUNT" != "0" ]; then
  # 検証A: tracked source の実ツリー差分が空か（最も信頼できる。main が先行していても
  #        branch 固有の追加が無ければ空になる）。LLM/ など gitignore 対象は元から無視される。
  TREE_DIFF=$(git diff "$MAIN_BRANCH" "$BRANCH_NAME" --stat -- 'src/**' 'app/**' 'lib/**' 'tests/**' 'e2e/**' '*.ts' '*.tsx' '*.js' '*.jsx' 2>/dev/null)
  # 検証B: cherry の全行が "-"（patch-equivalent が upstream 済み）か
  CHERRY_PLUS=$(git cherry "$MAIN_BRANCH" "$BRANCH_NAME" 2>/dev/null | grep -c '^+' || true)
  # 検証C: gh で当該ブランチ発の PR が MERGED か（リポジトリに gh がある場合のみ）
  PR_MERGED=$(gh pr list --head "$BRANCH_NAME" --state merged --limit 1 --json number 2>/dev/null | grep -c '"number"' || true)

  if [ -z "$TREE_DIFF" ] || [ "$CHERRY_PLUS" = "0" ] || [ "$PR_MERGED" != "0" ]; then
    SQUASHED="squash済み (tree_diff空=$([ -z \"$TREE_DIFF\" ] && echo yes || echo no), cherry+=$CHERRY_PLUS, pr_merged=$PR_MERGED)"
  fi
fi
```

- **`cherry` の `+` 判定だけを信じてはいけない**: squash マージは diff 内容を 1 commit にまとめ patch-id が変わるため、`git cherry` が `+`（= 未 upstream）を返すことがある。**最も信頼できるのは検証A（tracked source の実ツリー差分が空）**。3 検証のいずれかが「マージ済み」を示せば squash 済みと扱う。判断が割れたら**実ツリー差分（検証A）を優先**する。
- gh が無い / PR 運用でないプロジェクトでは検証A・Bだけで判定する。

分類（color は対象ごとにその場で決める）:

| カテゴリ | 条件 |
|---|---|
| 🟢 Safe | マージ済み（`MERGED` or `SQUASHED`）& dirty なし & LLM なし |
| 🟡 Recoverable | マージ済み（`MERGED` or `SQUASHED`）だが LLM あり or dirty あり |
| 🔴 Active | `AHEAD_COUNT > 0` **かつ** `SQUASHED` が空（squash でも普通 merge でもなく、本当に未マージの固有コミットがある） |

**squash 済み（`SQUASHED` が非空）の worktree は 🟢/🟡 として扱う**。`AHEAD_COUNT > 0` でも 🔴 にしない。ブランチ削除は元 SHA が main の祖先にならないため `git branch -D`（大文字）を使う。

Pass 1 では、カテゴリに応じて以下へ分岐する:

- 🟢 Safe → **Step B-🟢**（確認なしで自動削除／`--keep` 時は自動再利用化）
- 🟡 で dirty なし（LLM のみ）→ **Step B-🟡**（LLM 退避 → 検証 → 確認なしで自動削除）
- 🟡 で dirty あり／🔴 Active → **破壊操作はその場では一切行わない**。判断材料（dirty stat・未マージコミット一覧・LLM 有無）をこの時点で収集・表示し、LLM があれば非破壊の退避（コピー + 検証）だけ済ませて `DEFERRED+=("$WT")` し、次の対象へ進む。Pass 1 完了後に **Step B Pass 2** でまとめて対話する

#### Step B-🟢: Safe → 確認なしで削除（`--keep` 時は再利用化）

AskUserQuestion は行わない。Step A で TARGETS に含めたことを承認とみなし、**診断根拠を 1 行表示してから**自動実行する（無音削除の禁止）。

**削除モード（デフォルト）**:

```bash
echo "  🟢 Safe: merged=${MERGED:+branch--merged}${SQUASHED:+$SQUASHED} / clean / LLMなし → 削除します"
git worktree remove "$WT" --force
git branch -d "$BRANCH_NAME"    # SQUASHED のときは -D（元 SHA が main の祖先にならないため）
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

#### Step B-🟡: Recoverable（dirty なし・LLM のみ）→ LLM 退避 → 検証 → 確認なしで削除

dirty がある 🟡 はここに来ない（Pass 1 の分岐で `DEFERRED` 行き）。

```bash
# LLM ファイルをメインリポに退避（ファイル名にセッションIDが含まれ衝突しない）
mkdir -p "$MAIN_REPO/LLM"
cp "$WT/LLM/"* "$MAIN_REPO/LLM/" 2>/dev/null

# 退避検証（絶対禁則 4）: 元と同数のファイルが退避先に実在し、空でないこと
SRC_COUNT=$(ls "$WT/LLM/" | wc -l | tr -d ' ')
OK_COUNT=0
for f in "$WT/LLM/"*; do
  dst="$MAIN_REPO/LLM/$(basename "$f")"
  [ -s "$dst" ] && OK_COUNT=$((OK_COUNT+1))
done
```

- **検証成功（`OK_COUNT == SRC_COUNT`）** → 診断根拠と退避結果を表示して確認なしで削除:
  ```bash
  echo "  🟡 Recoverable: merged / clean / LLM ${SRC_COUNT}files → 退避検証OK → 削除します"
  git worktree remove "$WT" --force   # LLM/ は gitignore 対象のため --force が必要
  git branch -d "$BRANCH_NAME"        # SQUASHED のときは -D
  PROCESSED+=("$BRANCH_NAME (🟡 LLM退避→削除)")
  ```
- **検証失敗** → 削除しない。`HELD+=("$BRANCH_NAME (LLM退避検証失敗)")` として次の対象へ

#### Step B Pass 2: 判断バッチ（🔴 Active / dirty あり 🟡）

Pass 1 が全対象を処理し終えた後にのみ実行する。`DEFERRED` が空なら対話せず Step C へ。

非空なら、各対象の状況を**まとめて**表示する:

```
自動処理が完了しました（削除 3 / 保留 0）。残り 2 件は判断が必要です:

[1] baz (wip-z) — 🔴 未マージ
  未マージコミット: 3件
    abc1234 feat: ユーザー登録フォームの追加
    def5678 fix: バリデーションエラー
    ghi9012 chore: テスト整備
  Dirty: なし / LLM: なし

[2] qux (fix-q) — 🟡 dirty あり
  マージ済みだが未コミット変更あり:
    src/foo.ts | 12 ++++++++----
  LLM: あり（退避済み）
```

続けて AskUserQuestion で **1 対象 1 問**として選択させる。1 回の呼び出しは最大 4 問なので、`DEFERRED` が 4 件を超える場合は複数回に分け、各回の提示範囲を明示する（無音での打ち切りを行わない）。

選択肢の出し分け（対象ごと）:

- **🔴 通常（Dirty なし & ブランチ名あり）**: 「1) main にマージ (推奨) / 2) スキップ / 3) 破棄削除 (force)」の 3 択
- **🔴 Dirty 同時**: マージ選択肢を**除外**し「1) スキップ / 2) 破棄削除 (force)」の 2 択。理由明示「⚠️ Dirty な変更があるため main にマージできません（merge は clean working tree が前提）」
- **🔴 detached HEAD（`BRANCH_NAME` 空）**: マージ選択肢を除外し同 2 択。理由明示「⚠️ detached HEAD のためマージできません（マージ対象のブランチ名がありません）」
- Dirty と detached が両方該当する場合も 2 択を提示し、両方の理由を併記する
- **🟡 dirty あり**: 「1) 変更を破棄して削除 / 2) スキップ」の 2 択（LLM は Pass 1 で退避・検証済みであることを前提とし、未退避なら実行前に退避する）

回答を受け取ったら、**別ターンで**回答がどの worktree を指すか読み直して再確定し、選択ごとに逐次実行する（絶対禁則 1）。

**選択ごとの分岐**:

- **スキップ** → 状態維持。`SKIPPED+=("$BRANCH_NAME")`
- **破棄削除 (force)**（🔴） →
  ```bash
  git worktree remove --force "$WT"
  git branch -D "$BRANCH_NAME"
  PROCESSED+=("$BRANCH_NAME (🔴 破棄削除)")
  ```
- **変更を破棄して削除**（🟡 dirty あり） →
  ```bash
  git worktree remove --force "$WT"
  git branch -d "$BRANCH_NAME"    # SQUASHED のときは -D
  PROCESSED+=("$BRANCH_NAME (🟡 dirty破棄→削除)")
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
  - 競合より前に処理が完了したもの（Pass 1 の自動処理分と、Pass 2 で先に処理した分。いずれも `PROCESSED`）は**確定済みとして扱い巻き戻さない**
  - 競合した worktree（`HELD`）以降の未処理 `DEFERRED` は処理しない
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

続けて `PROCESSED` / `SKIPPED` / `HELD` と残存 worktree 件数を区別表示する。自動処理分（Pass 1）と判断バッチ分（Pass 2）が区別できるよう表示する。

```
wt-clean 完了:
  Remote 同期: ✅ pulled 3 commits (origin/main → main)
  対象: 4 worktrees（全件・確認なし）
  自動処理（確認なし）: feat-x (🟢 削除), bar (🟡 LLM退避→削除)
  再利用化: -
  判断バッチ: wip-z (🔴 マージ→削除, 3 commits merged)
  サニティチェック: ✅ PASS (npm test, npm run build)
  スキップ: fix-q (🟡 dirty, ユーザー選択)
  LLMコピー: 2 files → LLM/（退避検証 OK）
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

Step B Pass 2 で「破棄削除 (force)」を選んだ場合のみ:

1. 未マージコミットのログ・未コミット変更の diff は判断バッチの提示時点で表示済みであること（未表示なら実行前に表示する）
2. LLM ファイルがあればコピーし、退避検証（絶対禁則 4）を行う
3. `git worktree remove --force` + `git branch -D`（大文字 D = 強制削除）

判断バッチでの「破棄削除」回答がユーザーの最終確認である。追加の「本当に削除しますか？」は挟まない（判断材料は回答前に提示済みであることが前提）。ただし回答が曖昧（どの対象か特定できない・選択肢外の自由入力）な場合は実行せず確認し直す。

## エッジケース

- メインリポ自体が worktree の場合: スキップ（削除対象外）
- detached HEAD の worktree: ブランチ削除はスキップ。🔴 判定時はマージ選択肢を除外（Step B Pass 2）
- worktree のパスが存在しない（既に手動削除済み）: `git worktree prune` で整理
- Superset 作成の worktree: 削除後「Superset UI 上でも not found になるので UI から削除してください」と案内

## 自己検証

完了宣言の前に成果物の evidence を確認する（原則: `plugins/loops/references/self-verification.md`、詳細手順: `plugins/worktree/references/wt-clean-verification.md`）。

- 削除した worktree が `git worktree list` に現れないことを確認する。
- 🟡 判定で LLM 退避を行った場合、退避先ファイルが実在し空でないことを**削除前に**検証済みであることを確認する（検証失敗のまま削除していないこと）。
- 🟢/🟡 の自動削除について、削除直前に診断根拠を表示したことを確認する（無音削除をしていないこと）。
- dirty 破棄・🔴 破棄削除・🔴 マージを行った場合、それぞれ Pass 2 の AskUserQuestion 回答後の別ターンで実行したことを確認する。
