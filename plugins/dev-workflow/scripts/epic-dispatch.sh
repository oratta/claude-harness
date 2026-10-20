#!/usr/bin/env bash
# エピックの子の経路判定・起動・待ち受けを LLM なしで行う。develop の本体（エピックの解決
# セッション）が SKILL.md「エピックの扱い」→「回し方」の手順どおりに呼ぶ。
#
#   epic-dispatch.sh route <child>...
#   epic-dispatch.sh launch [--note <text>] [--base <branch>] <epic> <child>...
#   epic-dispatch.sh reply [--relaunch] --as <parent|owner> <epic> <child> <text>
#   epic-dispatch.sh notify-closed [--relaunch] <epic> <child>
#   epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] [--watch-done <child>]... [--watch-stopped] [--resolve <epic>] [<child>...]
#   epic-dispatch.sh mark <done|waiting|stopped|resumed> <issue>
#   epic-dispatch.sh reap <child>...
#   epic-dispatch.sh pending-owner <child>...
#   epic-dispatch.sh adopt <epic> <child>...
#   epic-dispatch.sh clear <epic>
#   epic-dispatch.sh max-parallel
#
# Orca のコマンドを呼ぶのはこのスクリプトだけ（develop の手順書には orca のコマンドを書かない）。
# 子の状態の正本は状態の記録（${EPIC_STATE_ROOT:-~/.claude/epic-state}/<o>.<r>-<E>/<o>.<r>-<N>.json。
#   読み書き・排他・照合の関数は同じディレクトリの epic-state.sh）。Orca の画面の印（ボードの列・コメント欄）は、
#   記録を書いたあとに写すだけで、判定には使わない（写しの失敗は stderr に出して成功扱い）。
#   <child> は番号だけか <owner>/<repo>#<N>（エピックと同じリポジトリなら番号と同じ扱い。出力は受けた形のまま）。
#   エピックの <owner>/<repo> を origin から読むのは launch・adopt・clear だけ（GitHub の 3 つの形。読めなければ
#   stderr に `cannot read the epic repository from origin: <URL か no origin>` で exit 1）。親の見張りと子の側は
#   記録の epic・repo を使う。親の側は今のワークツリー（git rev-parse --show-toplevel）を parent_worktree に
#   持つ記録だけを見る（番号だけは number と epic のリポジトリ、<owner>/<repo>#<N> は child で当てる）。
#   子の側は今のワークツリーを worktree に持つ記録を自分の記録とする。
# route: 子の番号の検査のあと、子の件数によらず最初に「エピックの子のセッションか」を見る。
#   EPIC_DISPATCH_PARENT_EPIC が空でなければ（並列起動された子のセッション）orca を呼ばずに `nested`。
#   空でも、今のワークツリーを worktree に持つ記録があれば（子のワークツリーで起動し直したセッション）`nested`。
#   `nested` のときは stderr に `parent epic: <#E か o/r#E>`（環境変数の値か、記録の epic）。
#   jq が無い・記録が読めないときは子ではないとして進む。Orca の parentWorktreeId は見ない。
#   子でなければ、子が 1 件以上・`orca worktree current --json` が exit 0（今いるのが Orca 管理の
#   ワークツリー）なら stdout に `orca`、それ以外（子 0 件を含む）は `subagent`。どれも exit 0。current は 1 回だけ呼ぶ
# launch: `orca worktree current --json` → `git rev-parse --show-toplevel` → `git fetch origin <base>`
#   → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` →
#   子ごとに `orca worktree create`（同じ repoId・同じ linkedIssue・archive されていない
#   ワークツリーがあれば作らない。--agent も --prompt も渡さない。作る前に記録（status running・worktree 空）を
#   書き、作成に失敗したら消す。作れたら worktree・branch を書き足し、送信まで済めば session に端末のハンドルを書く。
#   作ったあとで端末・起動待ち・送信に失敗したら記録を残して launch_failed に terminal / ready / send、
#   create が path を返さなければ create を書く。記録があって worktree が空でなければ skipped、空なら上書きして作る。
#   自分の記録が読めなければ `failed <N> state-unreadable`、エピックと別のリポジトリの子は作らず
#   `failed <child> other-repo`（どちらも枠を使わない）。create は空のシェルの端末を 1 つ作るので、
#   `orca terminal list` でそれがちょうど 1 つならそこへ下の <起動コマンド> を `terminal send --enter` で打ち込み、
#   端末が Claude Code になるまで list で待つ。0 個のときだけ下の terminal create で作る。2 個以上・list 失敗は failed）→ --note があれば
#   `gh issue comment <N> --body <親エピックからの注意書き: #<epic>・空行・注意書き>`（失敗しても起動は
#   続け、stderr に `note not posted to #<N>` と手で投稿するコマンドを出す）→ `orca terminal create
#   --worktree path:<子> --command "EPIC_DISPATCH_PARENT_EPIC=<epic>
#   CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<tokens> <cmd> --model <model>"`
#   （<cmd> の既定は cld、EPIC_DISPATCH_CLAUDE_CMD で変える。<model> の既定は opus、
#   EPIC_DISPATCH_MODEL で変える。どちらも空なら使い方を出して exit 1。<tokens> は子の
#   待っている間の自動コンパクトの閾値で既定は 120000、EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS
#   で変える。空か数字でなければ使い方を出して exit 1（根拠は skills/develop/references/reply-after-idle.md）。
#   作れなければ、既存の端末が無いことの確認・作り直し・送信のコマンドを stderr に出す）→ `orca terminal wait --for tui-idle` →
#   `orca terminal send --text <指示> --enter --wait-submit <秒>`。stdout は子ごとに `launched <N>`
#   （send の stages に turn_started がある）/ `skipped <N>` / `failed <N>` / `deferred <N>`（上限で後回し）の 1 行。failed で
#   ハンドルが取れていれば送り直しのコマンドを stderr に出す。orca 自身の出力は stderr。
#   <base> の既定は main（EPIC_DISPATCH_BASE、--base が優先）。起動完了待ちの上限（ミリ秒）と
#   送信の観測時間（秒）の既定は 60000 / 30（EPIC_DISPATCH_READY_TIMEOUT_MS / EPIC_DISPATCH_SUBMIT_WAIT）
#   exit 0 = failed なし / 1 = failed あり、または orca・jq が無い・current / origin / fetch / set / list の
#   失敗（このときは子を 1 件も作らず、記録も書かない）。呼ぶ順は current → rev-parse → 子の判定 →
#   remote get-url origin → fetch → set → list
#   上限（max-parallel と同じ値）: list のあと、全エピックのディレクトリを横断して parent_worktree が今のワークツリーの
#   記録のうち、status が done でなく、stop が stopped / stopped-seen でなく、
#   `gh api <記録の repo の issues/<N>> --jq .state` が closed でないものを「枠を使っている子」と数える（gh の失敗・
#   open / closed 以外は数え、stderr にその子を出す。ほかの読めない記録も 1 枠に数える。記録の無い Orca の子は
#   数えない）。stderr に `max parallel <上限> (<出どころ>); in use <数>: #<N>...`（並びは置き場のディレクトリの順）。
#   空き枠 = max(0, 上限 − 使用中)。子ごとに skipped の判定のあと、空き枠が 0 なら create も注意書きも
#   行わずに `deferred <N>`（exit code に影響しない）。create に進んだ子は結果によらず空き枠を 1 減らす。
#   上限の値が誤っていれば引数の検査のあと orca も git も呼ばずに使い方を出して exit 1
#   EPIC_DISPATCH_PARENT_EPIC が空でなければ、引数の検査のあと orca も git も呼ばずに
#   stderr に理由を出して exit 1（子ワークツリーを作らない）。空でも、rev-parse の直後に route と
#   同じ記録の判定をし、子なら origin も fetch も set も create も呼ばずに exit 1
#   （どちらの理由も `child epics are not expanded here` を含む）
# wait: 子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` を見るポーリングを繰り返し、
#   stdout にちょうど 1 行を出して終わる。
#   `closed <N>...`（閉じていた子）exit 0 / `timeout <N>...`（閉じていない子）exit 2 /
#   `error gh <N>...`（失敗したポーリングが 3 回続いた。3 回目で失敗した子）exit 1
#   失敗したポーリング = 1 件以上の子が失敗（gh が非 0、または出力が open / closed 以外）し、
#   閉じた子が 1 件も無いポーリング。失敗の無いポーリングで数え直す。
#   間隔・上限は秒。既定 300 / 21600（EPIC_DISPATCH_INTERVAL / EPIC_DISPATCH_TIMEOUT、フラグが優先）。
#   ポーリングのあとで「経過 >= 上限」か「経過 + 間隔 > 上限」なら眠らずに timeout
#   （--timeout 0 は間隔によらず 1 回だけ確かめる）
#   子 issue の state は、記録の repo がエピックと同じ子と記録の無い子は repos/{owner}/{repo}、違う子は repos/<repo> で読む。
#   --watch-done <N> を 1 つ以上付けたときだけ、ポーリングごとに渡された子の記録を 1 回ずつ読み、
#   status が done なら「印が付いた」とする。閉じた子・印が付いた子がいれば `closed <N>...` と `done <N>...` を
#   この順に（1 行か 2 行）出して exit 0。読めない記録はそのポーリングを失敗したポーリングに数え、
#   3 回続いて gh の失敗が無ければ `error workspaces`。位置引数 0 件も可（timeout は `timeout` だけ）。
#   --watch-stopped（値なし）を付け、位置引数の子が 1 件以上あるときは、閉じていない位置引数の子のうち
#   記録の stop が stopped のものを排他つきで stopped-seen に書き換え（そのあと Orca の印へ写す）、書けたら
#   「止まった子」とする（書けなければ失敗したポーリングに数える）。出力は `closed <N>...`・
#   `done <N>...`・`stopped <N>...` を該当するものだけこの順に（1〜3 行）出して exit 0。
#   --watch-done も --watch-stopped（子 1 件以上）も無ければ記録を読まない。
#   --resolve <epic>（--watch-stopped と位置引数の子が 1 件以上あるときだけ働く）を付けると、止まった子ごとに
#   判断のコマンド（EPIC_DISPATCH_JUDGE。既定は同じディレクトリの stop-judge.sh）を `<epic> <child>` で 1 回呼ぶ。
#   `判断: 通す` で返事が空でなければ reply --as parent と同じ処理で送り、sent / relaunched ならエピックに
#   `親の判断: 子 #<N> 通した — <理由> <記録>` を投稿して出力から外す（投稿に失敗したら `unrecorded` に入れ、
#   stderr に投稿し直しのコマンド）。`判断: 主に上げる` は子 issue に `親の判断: 主に上げる`、判断の失敗・
#   形の崩れは `親の判断: 判断できなかった`、通すで送信の失敗は `親の判断: 通すが送れなかった` を、2 行目 `停止の記録: <URL か 不明>` 付きで投稿して
#   `stopped` に残す（投稿に失敗したら stderr に投稿し直しのコマンド）。出力は closed / done / stopped /
#   unrecorded の順の 1〜4 行。--resolve が無ければ判断を呼ばず、unrecorded も出さない。
#   --resolve の値が無い・数字でない、または返事の送り方の環境変数が誤っていれば使い方を出して exit 1
#   jq が無い・今のワークツリーを読めない（rev-parse の失敗）なら stdout に何も出さず exit 1
# reply: 今のワークツリーを parent_worktree に持つ <child> の記録が 1 件で（その worktree が子のワークツリー）、
#   端末があり（--relaunch なし）、子のセッションの端末（agentIdentity が claude の端末、無ければタイトルに
#   Claude Code を含む端末がちょうど 1 つ）が決まれば、頭（--as parent は `親エピック #<epic> の判断（主の承認ではない）: `、
#   owner は `主の返事（親エピック #<epic> 経由）: `）を付けた文を送り、ターンの開始まで確かめて `sent <child>`。
#   端末が 0 か --relaunch なら（--relaunch は先に端末を全部閉じて）launch と同じ起動コマンドで端末を作り、
#   `/develop #<child> （エピック #<epic> の子。返事を受けて起動し直し） <頭付きの文>` を送って `relaunched <child>`。
#   端末はあるが子のセッションの端末を決められない（シェルの端末だけも含む）
#   ときは `failed <child> ambiguous-terminal`。記録が 0 件は `failed <child> no-worktree`、2 件以上は
#   `failed <child> ambiguous-worktree`、読めない記録は `failed <child> state-unreadable`。送信 / 作成 / 閉じるの失敗は `failed <child> <段>` で exit 1
#   （送り直しか作り直しのコマンドを stderr に出す）。引数の誤りは orca を呼ばずに使い方を出して exit 1
# notify-closed: 子 issue の state が closed でなければ `skipped <child> not-closed`、state_reason が completed で
#   なければ `skipped <child> not-completed`（gh の失敗は `failed <child> issue`）。今のワークツリーを parent_worktree に
#   持つ <child> の記録が 0 件なら `skipped <child> no-worktree`、2 件以上は `failed <child> ambiguous-worktree`、
#   読めない記録は `failed <child> state-unreadable`。記録の status が done なら
#   `skipped <child> already-done`、stop が stopped / stopped-seen でなければ `skipped <child> not-stopped`。
#   条件を満たせば reply --as parent と同じ処理（--relaunch も同じ）で「記録先の issue #<child> は completed で
#   閉じた。完了報告を書き、mark done で終える（停止の記録: <URL>）」を送り（URL は OWNER / MEMBER / COLLABORATOR の
#   最新の `子の停止: 主の返事待ち` のコメント、無ければ子 issue の URL）、送れたらエピックに
#   `親の判断: 子 #<child> 通した — 記録先が completed で閉じたので、完了報告と mark done を促した <URL>` を投稿して
#   `notified <child>`（投稿に失敗したら `unrecorded <child>` と stderr に投稿し直しのコマンド）。skipped / notified /
#   unrecorded は exit 0、送信の失敗は `failed <child> <段>` で exit 1。skipped のときはどこにも投稿しない
# mark: 今のワークツリーを worktree に持つ自分の記録の number（<owner>/<repo>#<N> なら repo も）が <issue> の
#   ときだけ、排他つきで done / waiting は status を done / waiting に、stopped は stop を stopped に、resumed は
#   stop が stopped / stopped-seen のときだけ resumed に書き換え（それ以外は `skipped <issue> not-stopped`）、
#   書けたら Orca の印（--workspace-status completed / in-review、--comment epic-stopped / epic-resumed）へ写す。
#   stdout は `marked <issue> <kind>`（exit 0）/ `failed <issue>`（書けない・自分の記録が 2 件以上。exit 1）/
#   `skipped <issue> not-linked`（記録が別の子）/ `skipped <issue> no-workspace`（記録が無い・jq が無い。exit 0）。
#   EPIC_DISPATCH_PARENT_EPIC は見ない
# reap: 子ごとに、今のワークツリーを parent_worktree に持つ記録 1 件（無い・worktree のディレクトリが無いなら
#   `gone <N>`。後者は記録を消す。読めない記録は `kept <N> state-unreadable`）・status が done・git status がきれい・LLM/ が無い・ブランチ上・マージ済み PR の headRefOid と HEAD が一致
#   （`--head <ブランチ>` で一致しなければ、`--state merged --search <HEAD>` でブランチ名を問わず探す）、
#   （一致しなくても、そのブランチに PR が状態を問わず無く・issue が閉じていて・HEAD が
#   `git ls-remote origin refs/heads/${EPIC_DISPATCH_BASE:-main}` のリモートの今の先端に含まれる子は通す。
#   手元の追跡参照は使わない。理由は pr-lookup-failed / issue-lookup-failed / base-lookup-failed /
#   unmerged-commits / git-failed）、
#   の順に確かめ、全部通れば `orca terminal close --all`（失敗したら `orca terminal list` を stderr に出し
#   EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT 秒・既定 10 待って 1 回だけ閉じ直す。それでも失敗なら rm せず
#   `kept <N> close-failed` と stderr に主がする操作）→ `orca worktree rm`（--force なし・再試行なし。
#   stderr に `terminal sweep failed` を含む失敗は `kept <N> rm-failed-terminal-sweep`）→
#   残ったローカルブランチは先端が HEAD と同じときだけ、ワークツリーが `git worktree list` から外れるのを
#   上限つきで待って（EPIC_DISPATCH_REAP_DETACH_TIMEOUT 秒・既定 30、_INTERVAL 秒・既定 1）`git branch -D`。stdout は子ごとに
#   `reaped <N>` / `reaped <N> branch-kept` / `gone <N>` / `kept <N> <理由>` の 1 行で exit 0。reaped の子は記録を消す。
#   orca・jq が無い・今のワークツリーを読めなければ何も消さず stdout 空で exit 1。EPIC_DISPATCH_PARENT_EPIC は見ない
# pending-owner: 読み取り専用。子ごとに、今のワークツリーを parent_worktree に持つ記録の stop が stopped-seen
#   （親が受けたまま、子が mark resumed を付けていない）なら `pending <N>` を 1 行ずつ出して exit 0（記録も Orca の印も
#   書かない）。読めない記録の子は飛ばす。起動し直した親が、主の返事待ちの子を出し直す対象を集める。
#   jq が無い・今のワークツリーを読めなければ stdout 空で exit 1
# adopt: 記録の無い子ごとに、`orca worktree list --json` の、repoId が今のワークツリーと同じ・linkedIssue が子・
#   archive されていない・parentWorktreeId が今のワークツリーの id のワークツリーを探す。ちょうど 1 つなら path・
#   branch と、workspaceStatus（completed → done、in-review → waiting、ほか → running）と comment（epic-stopped →
#   stopped、epic-stopped-seen → stopped-seen、epic-resumed → resumed、ほか → 空）を写し、base を
#   EPIC_DISPATCH_BASE（空なら main）、launcher を orca、session と launch_failed を空にした記録を作って
#   `adopted <N>`。読める記録があれば `skipped <N>`、読めない記録なら `failed <N> state-unreadable`、該当が無ければ（別リポジトリの子を含む）`none <N>`、2 つ以上は
#   `failed <N> ambiguous`、記録を書けなければ `failed <N>`。orca・jq が無い・Orca 管理外・一覧を読めない・origin を読めなければ stdout 空で exit 1。
#   failed があれば exit 1
# clear: <epic>（^[0-9]+$）の状態ディレクトリ（EPIC_STATE_ROOT 直下の <o>.<r>-<E>）を、残っている記録の子を stderr に
#   出してから消して `cleared <epic>`、無ければ `none <epic>`（どちらも exit 0）。EPIC_STATE_ROOT が空・/ や $HOME
#   そのもの・名前が / か .. を含む・シンボリックリンク・origin を読めないときは何も消さずに exit 1
# max-parallel: 同時に枠を使う子の上限を stdout に数字 1 行で出して exit 0（orca / gh / git を呼ばない）。
#   EPIC_DISPATCH_MAX_PARALLEL（1 以上の整数。空・0・数字以外は使い方を出して exit 1）があればその値、
#   無ければ物理メモリの GiB（`sysctl -n hw.memsize` のバイト、読めなければ
#   EPIC_DISPATCH_MEMINFO_FILE（テスト用。既定 /proc/meminfo）の MemTotal の kB）を 4 で割って切り捨て、最小 1。
#   どちらも読めなければ 2 で、stderr に `physical memory not readable`。launch も同じ値を使う
# wait --resolve が通す返事は、送る前に references/reply-after-idle.md の表で起動し直すかを決める:
#   子のトランスクリプト（${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/<ワークツリーのパスの英数字以外を - にした名前>/*.jsonl、
#   ちょうど 1 本）の最後の assistant の timestamp が EPIC_DISPATCH_RELAUNCH_IDLE_SEC（既定 3600）秒以上前で、
#   その assistant より後に compact_boundary が無く、subagent-context.sh --file の context_tokens が
#   EPIC_DISPATCH_RELAUNCH_MIN_TOKENS（既定 150000）以上のときだけ --relaunch 相当。読めなければそのまま送る。
#   2 つの変数が空か数字でなければ wait は使い方を出して exit 1
# 引数の誤り（launch は epic か子が無い、wait は子も --watch-done も 0 件（--watch-stopped だけも含む）、
#   mark の種別（done / waiting / stopped / resumed 以外）・引数の数、
#   reap は子が 0 件、番号が数字でない、フラグ値の誤り）は
#   stderr に使い方を出して exit 1。route は子 0 件でも subagent（エピックの子のセッションなら nested）。
#
# 設計と守備範囲（引数を渡すのは本体で、人が手で打つことは想定しない）は
# openspec の dev-workflow-develop spec「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを
# LLM なしで行う」「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」
# 「エピックの子への注意書きと子であることを、起動し直したセッションにも引き継ぐ」
# 「端末を作れなかった子と指示が届かなかった子の案内は、二重起動を避ける確認を先に出す」
# 「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」
# 「epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける」
# 「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」
# 「Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る」
# 「epic-dispatch.sh は同時に枠を使う子の上限を環境変数か物理メモリから決める」
# 「epic-dispatch.sh launch は空いた枠の分だけ子を起動し、残りを deferred で出す」と、
# 状態の記録（置き場・項目・排他・adopt・clear・launch の書く順・枠の数え方）は openspec の
# dev-workflow-epic-state spec が正本。
set -uo pipefail

# 状態の記録の読み書き（置き場・排他・照合）は epic-state.sh に置く
# shellcheck source=epic-state.sh
. "${BASH_SOURCE[0]%/*}/epic-state.sh"

usage() {
  cat >&2 <<'EOF'
usage:
  epic-dispatch.sh route <child>...
  epic-dispatch.sh launch [--note <text>] [--base <branch>] <epic> <child>...
  epic-dispatch.sh reply [--relaunch] --as <parent|owner> <epic> <child> <text>
  epic-dispatch.sh notify-closed [--relaunch] <epic> <child>
  epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] [--watch-done <child>]... [--watch-stopped] [--resolve <epic>] [<child>...]
  epic-dispatch.sh mark <done|waiting|stopped|resumed> <issue>
  epic-dispatch.sh reap <child>...
  epic-dispatch.sh pending-owner <child>...
  epic-dispatch.sh adopt <epic> <child>...
  epic-dispatch.sh clear <epic>
  epic-dispatch.sh max-parallel
EOF
  exit 1
}

is_num() { [[ "$1" =~ ^[0-9]+$ ]]; }

# 子の引数がすべて番号だけか <owner>/<repo>#<N> であることを確かめる（1 件でも違えば使い方を出して exit 1）
check_children() {
  local n
  for n in "$@"; do
    es_valid_arg "$n" || { echo "not an issue number or <owner>/<repo>#<number>: $n" >&2; usage; }
  done
}

# エピックへのコメントに書く子の呼び方（番号だけは #N、<owner>/<repo>#<N> はそのまま）
child_label() { case "$1" in *"#"*) printf '%s' "$1" ;; *) printf '#%s' "$1" ;; esac; }

# gh issue comment に渡す子 issue の指し方（番号だけは番号、<owner>/<repo>#<N> は issue の URL）
child_ref() { case "$1" in *"#"*) printf 'https://github.com/%s/issues/%s' "${1%%#*}" "${1##*#}" ;; *) printf '%s' "$1" ;; esac; }

# 今のワークツリーの最上位のパス（読めなければ空で 1）
toplevel() { git rev-parse --show-toplevel 2>/dev/null; }

# 親の側: 子の引数に当たる記録を探す（<親のパス> <子の引数>）。ES_HIT にパス。戻り値は es_pick と同じ
# （0 = 1 件 / 1 = 0 件 / 2 = 2 件以上 / 3 = 読めない記録）
child_record() { es_pick "$(es_find_for_parent "$1" "$2")"; }

# 親の側の前提: jq と今のワークツリーの最上位のパス（PARENT_TOP に入れる）。無ければ stderr に理由を出して exit 1
PARENT_TOP=""
need_parent() {
  command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH" >&2; exit 1; }
  PARENT_TOP="$(toplevel)" && [ -n "$PARENT_TOP" ] \
    || { echo "not in a git worktree (git rev-parse --show-toplevel failed)" >&2; exit 1; }
}

# 子 issue を gh api で読むパス（<子の引数> <記録のパスか空>）。記録の repo がエピックと同じ子と、番号だけで渡した
# 記録の無い子は今のまま repos/{owner}/{repo}（gh が今のワークツリーのリポジトリに置き換える）。記録の repo が
# エピックと違う子は repos/<repo>、<owner>/<repo>#<N> で渡した記録の無い子は引数のリポジトリ
issue_api() {
  local n="$1" rec="${2-}" r="" e="" num
  num="${n##*#}"
  if [ -n "$rec" ]; then
    r="$(es_get "$rec" repo)"; e="$(es_get "$rec" epic)"
  fi
  if [ -n "$r" ] && [ -n "$e" ]; then
    if [ "$r" != "${e%%#*}" ]; then printf 'repos/%s/issues/%s' "$r" "$num"; return 0; fi
  elif [ "$n" != "$num" ]; then
    printf 'repos/%s/issues/%s' "$(es_lower "${n%%#*}")" "$num"; return 0
  fi
  printf 'repos/{owner}/{repo}/issues/%s' "$num"
}

# Orca の部品: 記録の launcher が orca で orca が PATH にあれば、記録を書いたあとに Orca の印へ写す
# （<記録のパス> <set の --worktree の値> <set の引数...>）。写せなくても成功扱いで、stderr に出す
mirror_orca() {
  local rec="$1" wt="$2"
  shift 2
  [ "$(es_get "$rec" launcher)" = orca ] || return 0
  command -v orca >/dev/null 2>&1 || return 0
  orca worktree set --worktree "$wt" "$@" >&2 \
    || echo "could not mirror the state to Orca (orca worktree set --worktree $wt $*); the state record is still written: $rec" >&2
  return 0
}

# 今のワークツリーが記録の worktree に当たる（親の launch / adopt が作った子）なら、記録の epic を
# 親エピックの呼び方（エピックが子と同じリポジトリなら #<E>、違えば <owner>/<repo>#<E>）で出す。
# 当たらなければ何も出さない。jq が無い・記録が読めないときは子ではないとして何も出さない
parent_from_state() {
  local top f e r
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "$ES_ROOT" ] || return 0
  top="$(toplevel)" || return 0
  f="$(es_find_by_worktree "$top" | head -n 1)"
  [ -n "$f" ] || return 0
  e="$(es_get "$f" epic)"; r="$(es_get "$f" repo)"
  [ -n "$e" ] || return 0
  if [ "${e%%#*}" = "$r" ]; then printf '#%s' "${e##*#}"; else printf '%s' "$e"; fi
}

cmd_route() {
  check_children "$@"
  # 並列起動された子のセッション（起動し直したものを含む）の中では、エピックをさらに展開しない。
  # 端末に付けた環境変数か、今のワークツリーを worktree に持つ状態の記録のどちらかで判定する
  local epic="" managed=0
  if [ -n "${EPIC_DISPATCH_PARENT_EPIC-}" ]; then
    case "$EPIC_DISPATCH_PARENT_EPIC" in *"#"*) epic="$EPIC_DISPATCH_PARENT_EPIC" ;; *) epic="#$EPIC_DISPATCH_PARENT_EPIC" ;; esac
  else
    epic="$(parent_from_state)"
  fi
  if [ -n "$epic" ]; then
    echo "parent epic: $epic" >&2
    echo nested
    return 0
  fi
  if command -v orca >/dev/null 2>&1 && orca worktree current --json >/dev/null 2>&1; then
    managed=1
  fi
  if [ "$#" -ge 1 ] && [ "$managed" -eq 1 ]; then
    echo orca
  else
    echo subagent
  fi
}

# シェルに貼れる形の単一引用符で囲む
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# 指示が届かなかった子の送り直しのコマンドを stderr に出す（<handle> <prompt> <submit> [<retry id>]）
resend_hint() {
  local cmd
  cmd="orca terminal send --terminal $(shq "$1") --text $(shq "$2") --enter --wait-submit $3 --json"
  [ -n "${4-}" ] && cmd="$cmd --retry-request $4"
  {
    echo "the first prompt may not have reached terminal $1."
    echo "check the input line and whether a turn started before resending: orca terminal read --terminal $(shq "$1")"
    echo "resend: $cmd"
  } >&2
}

# 端末を作れなかった子の、端末の作り直しと最初の指示の送信のコマンドを stderr に出す
# （<子のパス> <起動コマンド> <prompt> <submit>）
recreate_hint() {
  {
    echo "no agent terminal was started in $1 (relaunching launch skips this child)."
    echo "check that no terminal is already running claude there before creating one: orca terminal list --worktree path:$1 --json"
    echo "create: orca terminal create --worktree path:$1 --command $(shq "$2") --json"
    echo "then send: orca terminal send --terminal <handle from create> --text $(shq "$3") --enter --wait-submit $4 --json"
  } >&2
}

# 子のセッションの起動コマンドと、起動完了待ち・送信の観測時間を環境変数から組み立てる（launch と reply が共用）。
# 結果は ready / submit / agent_cmd に入れる。値が誤っていれば stderr に理由を出して 1 を返す（orca は呼ばない）
ready=""; submit=""; agent_cmd=""; agent_rest=""
agent_setup() {
  ready="${EPIC_DISPATCH_READY_TIMEOUT_MS:-60000}" submit="${EPIC_DISPATCH_SUBMIT_WAIT:-30}"
  is_num "$ready" || { echo "EPIC_DISPATCH_READY_TIMEOUT_MS must be a non-negative integer: $ready" >&2; return 1; }
  is_num "$submit" || { echo "EPIC_DISPATCH_SUBMIT_WAIT must be a non-negative integer: $submit" >&2; return 1; }
  local model="${EPIC_DISPATCH_MODEL-opus}"
  [ -n "$model" ] || { echo "EPIC_DISPATCH_MODEL must not be empty" >&2; return 1; }
  local claude_cmd="${EPIC_DISPATCH_CLAUDE_CMD-cld}"
  [ -n "$claude_cmd" ] || { echo "EPIC_DISPATCH_CLAUDE_CMD must not be empty" >&2; return 1; }
  local idle_compact="${EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS-120000}"
  is_num "$idle_compact" || { echo "EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS must be a non-negative integer: $idle_compact" >&2; return 1; }
  agent_rest="CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=$idle_compact $claude_cmd --model $(shq "$model")"
  agent_cmd="EPIC_DISPATCH_PARENT_EPIC=$1 $agent_rest"
}

# 起動コマンドの EPIC_DISPATCH_PARENT_EPIC の値を差し替える（別のリポジトリのエピックの子は <owner>/<repo>#<E>）。
# agent_setup を済ませてから呼ぶ
agent_cmd_for() { agent_cmd="EPIC_DISPATCH_PARENT_EPIC=$1 $agent_rest"; }

# 同時に枠を使う子の上限を決める（launch と max-parallel が共用）。結果は max_par（数）と max_par_src
# （出どころ）に入れる。EPIC_DISPATCH_MAX_PARALLEL の値が誤っていれば stderr に理由を出して 1 を返す。
# sysctl は PATH で引く（テストのスタブを効かせるため。絶対パスで呼ばない）
max_par=""; max_par_src=""
max_parallel_setup() {
  if [ -n "${EPIC_DISPATCH_MAX_PARALLEL+set}" ]; then
    max_par="$EPIC_DISPATCH_MAX_PARALLEL"
    if ! is_num "$max_par" || [ "$(( 10#$max_par ))" -lt 1 ]; then
      echo "EPIC_DISPATCH_MAX_PARALLEL must be an integer of 1 or more: $max_par" >&2
      return 1
    fi
    max_par="$(( 10#$max_par ))" max_par_src="EPIC_DISPATCH_MAX_PARALLEL"
    return 0
  fi
  local bytes kb gib=""
  bytes="$(sysctl -n hw.memsize 2>/dev/null)" || bytes=""
  if is_num "$bytes"; then
    gib=$(( bytes / 1073741824 ))
  else
    kb="$(awk '$1 == "MemTotal:" { print $2; exit }' "${EPIC_DISPATCH_MEMINFO_FILE:-/proc/meminfo}" 2>/dev/null)" || kb=""
    is_num "$kb" && gib=$(( kb / 1048576 ))
  fi
  if [ -z "$gib" ]; then
    echo "physical memory not readable (sysctl -n hw.memsize, ${EPIC_DISPATCH_MEMINFO_FILE:-/proc/meminfo}); max parallel defaults to 2" >&2
    max_par=2 max_par_src="default; physical memory not readable"
    return 0
  fi
  max_par=$(( gib / 4 ))
  [ "$max_par" -ge 1 ] || max_par=1
  max_par_src="physical memory ${gib} GiB"
}

cmd_max_parallel() {
  [ "$#" -eq 0 ] || usage
  max_parallel_setup || usage
  echo "$max_par"
}

# send の出力にターンの開始（stages の turn_started）があるか
turn_started() {
  printf '%s' "$1" | jq -e '[.. | objects | .stages? | arrays | .[]] | index("turn_started") != null' >/dev/null 2>&1
}

# send の出力から再試行の ID を取り出す（無ければ空）
retry_id() {
  printf '%s' "$1" | jq -r 'first(.. | objects | (.retryRequestId // .retryRequest) | strings) // empty' 2>/dev/null
}

# 端末の一覧の JSON から子のセッションの端末を 1 つ選ぶ。Orca は子のワークツリーにシェルの端末
# （Terminal 1）も作るので、agentIdentity が claude の端末、それが無ければタイトルに Claude Code を
# 含む端末（Claude Code はタイトルを書き換えるので agentIdentity を先に見る）がちょうど 1 つのときだけ
# そのハンドルを stdout に出す。決められなければ何も出さない
pick_session_term() {
  printf '%s' "$1" | jq -r '[.result.terminals[] | select(.agentIdentity == "claude")] as $a
    | (if ($a | length) > 0 then $a
       else [.result.terminals[] | select((.title // "") | tostring | contains("Claude Code"))] end)
    | [.[] | .handle // empty | strings | select(. != "")]
    | if length == 1 then .[0] else empty end' 2>/dev/null
  return 0
}

# launch 用: 子のワークツリーに worktree create が作った空のシェルの端末がちょうど 1 つあれば、そこへ起動
# コマンドを打ち込み、端末が Claude Code になる（agentIdentity か タイトル）まで待つ（<子のパス> <起動コマンド>）。
# 戻り値 0 = 起動した（SHELL_HANDLE にハンドル）/ 1 = 端末が 0 個（呼び出し側が terminal create で作る）/
# 3 = 失敗（理由と手で続けるコマンドを stderr に出した。端末を増やすと二重になるので作らない）
SHELL_HANDLE=""
shell_start() {
  local terms cnt h out tries i
  SHELL_HANDLE=""
  if ! terms="$(orca terminal list --worktree "path:$1" --json)" \
    || ! cnt="$(printf '%s' "$terms" | jq -e '.result.terminals | if type == "array" then length else error("x") end' 2>/dev/null)"; then
    echo "orca terminal list --worktree path:$1 --json is not readable" >&2
    echo "check the terminals before creating one: orca terminal list --worktree path:$1 --json" >&2
    return 3
  fi
  [ "$cnt" -eq 0 ] && return 1
  h="$(printf '%s' "$terms" | jq -r '.result.terminals | select(length == 1) | .[0].handle // empty' 2>/dev/null)"
  if [ -z "$h" ]; then
    echo "terminals in $1: $cnt (expected the one empty shell from worktree create); not starting a second one" >&2
    echo "check: orca terminal list --worktree path:$1 --json" >&2
    return 3
  fi
  if ! out="$(orca terminal send --terminal "$h" --text "$2" --enter --json)"; then
    printf '%s\n' "$out" >&2
    echo "could not type the start command into terminal $h. type it by hand: $2" >&2
    return 3
  fi
  tries=$(( ready / 1000 )); [ "$tries" -ge 1 ] || tries=1
  for (( i = 0; i < tries; i++ )); do
    if terms="$(orca terminal list --worktree "path:$1" --json)"; then
      cnt="$(printf '%s' "$terms" | jq -r '.result.terminals | if type == "array" then length else empty end' 2>/dev/null)"
      if [ -n "$cnt" ] && [ "$cnt" -ge 2 ]; then
        echo "terminals in $1: $cnt after typing the start command (expected 1); not sending the prompt" >&2
        echo "check: orca terminal list --worktree path:$1 --json" >&2
        return 3
      fi
      if [ "$(pick_session_term "$terms")" = "$h" ]; then
        SHELL_HANDLE="$h"; return 0
      fi
    fi
    sleep 1
  done
  echo "terminal $h did not become Claude Code within ${tries}s. check: orca terminal read --terminal $(shq "$h")" >&2
  return 3
}

# --- 別のリポジトリの子の clone・Orca のリポジトリ・書き込み権の解決（cmd_launch が使う） ---

# EPIC_DISPATCH_CLONES（<owner>/<repo>=<絶対パス> を改行か ; で区切る）から <repo> の候補のパスを 1 行 1 件で出す。
# 絶対パスでない項目は無かったことにして stderr に出す
clones_env_candidates() {
  local repo="$1" item left right
  printf '%s\n' "${EPIC_DISPATCH_CLONES-}" | tr ';' '\n' | while IFS= read -r item; do
    item="${item#"${item%%[![:space:]]*}"}"; item="${item%"${item##*[![:space:]]}"}"
    [ -n "$item" ] || continue
    case "$item" in *=*) ;; *) echo "EPIC_DISPATCH_CLONES: ignoring an item without '=': $item" >&2; continue ;; esac
    left="$(es_lower "${item%%=*}")"; right="${item#*=}"
    case "$right" in
      /*) ;;
      *) echo "EPIC_DISPATCH_CLONES: ignoring $left: the path is not absolute: $right" >&2; continue ;;
    esac
    [ "$left" = "$repo" ] && printf '%s\n' "$right"
  done
}

# 標準入力のパスのうち、origin が <repo> を指すものを重複なしで出す
clone_matches() {
  local want="$1" p url got seen="|"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ "$p" = / ] || p="${p%/}"
    case "$seen" in *"|$p|"*) continue ;; esac
    seen="$seen$p|"
    url="$(git -C "$p" remote get-url origin 2>/dev/null)" || continue
    got="$(es_repo_from_url "$url")" || continue
    [ "$got" = "$want" ] && printf '%s\n' "$p"
  done
  return 0
}

# orca repo list --json を 1 回だけ読む（ORCA_REPOS に入れる。読めなければ空）
ORCA_REPOS=""; ORCA_REPOS_READ=0
orca_repos_load() {
  [ "$ORCA_REPOS_READ" -eq 0 ] || return 0
  ORCA_REPOS_READ=1
  ORCA_REPOS="$(orca repo list --json 2>/dev/null)" || ORCA_REPOS=""
  printf '%s' "$ORCA_REPOS" | jq -e '.result.repos | type == "array"' >/dev/null 2>&1 || ORCA_REPOS=""
}

# 別のリポジトリ <repo>（小文字の <owner>/<repo>）の clone・Orca のリポジトリ・書き込み権・既定ブランチを解決する。
# 結果は XR_CODE（ok か失敗の理由: no-clone / ambiguous-clone / not-in-orca / permission-lookup-failed / no-push /
# base-lookup-failed）・XR_CLONE・XR_ID（Orca のリポジトリの id）・XR_BASE（既定ブランチ）に入れる。
# 1 回の launch の中で同じリポジトリは 1 回だけ解決する（結果と stderr の案内は最初の 1 回）
XR_CODE=""; XR_CLONE=""; XR_ID=""; XR_BASE=""
xrepo_resolve() {
  local repo="$1" key var cached found cnt resp acct
  key="$(printf '%s' "$repo" | tr -c 'a-z0-9' '_')"
  var="XRC_$key"
  cached="${!var-}"
  if [ -n "$cached" ]; then
    IFS='|' read -r XR_CODE XR_CLONE XR_ID XR_BASE <<EOF
$cached
EOF
    return 0
  fi
  XR_CODE=ok; XR_CLONE=""; XR_ID=""; XR_BASE=""
  found="$(clones_env_candidates "$repo" | clone_matches "$repo")"
  cnt="$(printf '%s' "$found" | grep -c .)"
  if [ "$cnt" -eq 0 ]; then
    orca_repos_load
    if [ -n "$ORCA_REPOS" ]; then
      found="$(printf '%s' "$ORCA_REPOS" | jq -r '.result.repos[] | .path // empty' | clone_matches "$repo")"
      cnt="$(printf '%s' "$found" | grep -c .)"
    fi
  fi
  if [ "$cnt" -ge 2 ]; then
    XR_CODE=ambiguous-clone
    echo "more than one clone of $repo matches (set EPIC_DISPATCH_CLONES to pick one):" >&2
    printf '%s\n' "$found" | sed 's/^/  /' >&2
  elif [ "$cnt" -eq 0 ]; then
    XR_CODE=no-clone
    {
      echo "no local clone of $repo was found. Tell launch where it is, once:"
      echo "  export EPIC_DISPATCH_CLONES='$repo=<absolute path of the clone>'"
      echo "If you have no clone yet:"
      echo "  git clone git@github.com:$repo.git <where you want it>"
    } >&2
  else
    XR_CLONE="$found"
    orca_repos_load
    XR_ID="$(printf '%s' "$ORCA_REPOS" | jq -r --arg p "$XR_CLONE" \
      '[.result.repos[]? | select(((.path // "") | rtrimstr("/")) == $p)] | .[0].id // empty' 2>/dev/null)"
    if [ -z "$XR_ID" ]; then
      XR_CODE=not-in-orca
      echo "$XR_CLONE is not registered in Orca. Add it (launch does not add repositories): orca repo add --path $XR_CLONE" >&2
    fi
  fi
  if [ "$XR_CODE" = ok ]; then
    if ! resp="$(gh api "repos/$repo" 2>/dev/null)" \
      || ! printf '%s' "$resp" | jq -e '.permissions | type == "object"' >/dev/null 2>&1; then
      XR_CODE=permission-lookup-failed
    elif [ "$(printf '%s' "$resp" | jq -r '.permissions.push // false')" != true ]; then
      XR_CODE=no-push
    else
      XR_BASE="$(printf '%s' "$resp" | jq -r '.default_branch // empty')"
      [ -n "$XR_BASE" ] || XR_CODE=base-lookup-failed
    fi
    if [ "$XR_CODE" != ok ]; then
      acct="$(gh api user --jq .login 2>/dev/null)" || acct="(unknown)"
      echo "$XR_CODE: gh api repos/$repo (authenticated as $acct)" >&2
    fi
  fi
  printf -v "$var" '%s|%s|%s|%s' "$XR_CODE" "$XR_CLONE" "$XR_ID" "$XR_BASE"
}

cmd_launch() {
  local note="" base_opt="${EPIC_DISPATCH_BASE:-}" base
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --note) [ "$#" -ge 2 ] || usage; note="$2"; shift 2 ;;
      --base) [ -n "${2-}" ] || usage; base_opt="$2"; shift 2 ;;
      --*) usage ;;
      *) break ;;
    esac
  done
  [ "$#" -ge 2 ] || usage
  base="${base_opt:-main}"
  local epic="$1"; shift
  is_num "$epic" || { echo "not an issue number: $epic" >&2; usage; }
  check_children "$@"
  agent_setup "$epic" || usage
  max_parallel_setup || usage
  if [ -n "${EPIC_DISPATCH_PARENT_EPIC-}" ]; then
    echo "this session is a child of epic #$EPIC_DISPATCH_PARENT_EPIC (EPIC_DISPATCH_PARENT_EPIC); child epics are not expanded here" >&2
    exit 1
  fi

  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH" >&2; exit 1; }

  local current repo parent list erepo
  current="$(orca worktree current --json)" || { echo "not in an Orca-managed worktree" >&2; exit 1; }
  repo="$(printf '%s' "$current" | jq -r '.result.worktree.repoId // empty')"
  [ -n "$repo" ] || { echo "orca worktree current --json has no repoId" >&2; exit 1; }
  parent="$(git rev-parse --show-toplevel)" && [ -n "$parent" ] || { echo "git rev-parse failed" >&2; exit 1; }
  # 起動し直した子のセッション（環境変数が無い）でも、子ワークツリーを作らず、今のワークツリーの issue も書き換えない。
  # 今のワークツリーを worktree に持つ記録があれば子（fetch と set より前のここで止まる）
  local own
  own="$(es_find_by_worktree "$parent" | head -n 1)"
  if [ -n "$own" ]; then
    echo "this session is a child of epic $(es_get "$own" epic) (state record $own); child epics are not expanded here" >&2
    exit 1
  fi
  # 記録を書く先のエピックのリポジトリ（origin が読めなければ何も作らない。set より前に読む）
  erepo="$(es_epic_repo)" || exit 1
  # 親の clone の fetch は、エピックと同じリポジトリの子が 1 件以上あるときだけ（別のリポジトリの子だけなら、
  # --base に親のリポジトリに無いブランチを指定しても launch 全体が失敗しない）
  local has_same=0 a
  for a in "$@"; do
    es_parse_arg "$a"
    if [ -z "$ES_ARG_REPO" ] || [ "$ES_ARG_REPO" = "$erepo" ]; then has_same=1; break; fi
  done
  if [ "$has_same" -eq 1 ]; then
    git fetch origin "$base" >&2 || { echo "git fetch origin $base failed" >&2; exit 1; }
  fi
  orca worktree set --worktree "path:$parent" --issue "$epic" >&2 \
    || { echo "orca worktree set failed" >&2; exit 1; }
  list="$(orca worktree list --json)" || { echo "orca worktree list failed" >&2; exit 1; }
  printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1 \
    || { echo "orca worktree list --json is not readable" >&2; exit 1; }

  # 枠を使っている子を状態の記録から数える。全エピックのディレクトリを横断し、parent_worktree が今のワークツリーの
  # 記録のうち、done・止まった印・閉じた子は数えない。state を読めない子と、ほかの読めない記録は 1 枠に数える
  local rf rec cst clabel in_use=0 in_use_list="" in_use_files=" " free
  for rf in "$ES_ROOT"/*/*.json; do
    [ -f "$rf" ] || continue
    if ! rec="$(es_read "$rf")"; then
      echo "unreadable state record (counted as in use): $rf" >&2
      in_use=$(( in_use + 1 )); in_use_list="$in_use_list $rf"; in_use_files="$in_use_files$rf "; continue
    fi
    printf '%s' "$rec" | jq -e --arg p "$parent" '.parent_worktree == $p and .status != "done"
      and .stop != "stopped" and .stop != "stopped-seen"' >/dev/null 2>&1 || continue
    clabel="$(printf '%s' "$rec" | jq -r 'if .repo == (.epic | split("#")[0]) then "#\(.number)" else .child end')"
    cst="$(gh api "$(issue_api "${clabel#\#}" "$rf")" --jq .state)" || cst=""
    [ "$cst" = closed ] && continue
    [ "$cst" = open ] || echo "could not read the state of $clabel; counting it as in use" >&2
    in_use=$(( in_use + 1 )); in_use_list="$in_use_list $clabel"; in_use_files="$in_use_files$rf "
  done
  echo "max parallel $max_par ($max_par_src); in use $in_use:$in_use_list" >&2
  free=$(( max_par - in_use )); [ "$free" -ge 0 ] || free=0

  local n num f cur prompt body out rc child cbranch handle sent retry failed=0 seen=" " stage shell_rc hit own
  local crepo xrepo cbase crid cclone
  for n in "$@"; do
    es_parse_arg "$n"; num="$ES_ARG_NUM"
    case "$seen" in
      *" ${ES_ARG_REPO:-$erepo}#$num "*) echo "skipped $n"; continue ;;
    esac
    seen="$seen${ES_ARG_REPO:-$erepo}#$num "
    crepo="${ES_ARG_REPO:-$erepo}"; xrepo=0
    [ "$crepo" = "$erepo" ] || xrepo=1
    f="$(es_path "$erepo" "$epic" "$crepo" "$num")"
    own=0
    if [ -e "$f" ]; then
      if ! cur="$(es_read "$f")"; then
        echo "unreadable state record: $f" >&2
        echo "failed $n state-unreadable"; failed=1; continue
      fi
      # 作ったワークツリーがある記録は起動済み。worktree が空の記録（書いたあとで殺された）は上書きして作る
      if [ -n "$(printf '%s' "$cur" | jq -r '.worktree')" ]; then
        echo "skipped $n"; continue
      fi
      # この記録は上の枠の数えで使用中に入っていることがある。その子自身は空き枠をもう 1 つ減らさない
      case "$in_use_files" in *" $f "*) own=1 ;; esac
    fi
    # 別のリポジトリの子は、clone・Orca のリポジトリ・書き込み権・既定ブランチを解決する（記録を書く前。
    # 失敗は記録も枠も使わない）。同じリポジトリの子は今のまま（起点は base、Orca のリポジトリは親と同じ）
    cbase="$base"; crid="$repo"; cclone=""
    if [ "$xrepo" -eq 1 ]; then
      xrepo_resolve "$crepo"
      if [ "$XR_CODE" != ok ]; then
        echo "failed $n $XR_CODE"; failed=1; continue
      fi
      cclone="$XR_CLONE"; crid="$XR_ID"; cbase="${base_opt:-$XR_BASE}"
    fi
    # 記録の無い Orca のワークツリー（この変更の前に起動した子）も起動済み。取り込みは adopt。
    # worktree が空の自分の記録があれば、一覧がちょうど 1 つのときに path と branch を書き足してから skipped にする
    if printf '%s' "$list" | jq -e --arg r "$crid" --arg n "$num" \
      'any(.result.worktrees[]; .repoId == $r and (.linkedIssue | tostring) == $n and .isArchived != true)' \
      >/dev/null 2>&1; then
      if [ -e "$f" ]; then
        hit="$(printf '%s' "$list" | jq -c --arg r "$crid" --arg n "$num" \
          '[.result.worktrees[] | select(.repoId == $r and (.linkedIssue | tostring) == $n and .isArchived != true)] | if length == 1 then .[0] else empty end' 2>/dev/null)"
        if [ -n "$hit" ]; then
          es_modify "$f" '.worktree = $w | .branch = $b' --arg w "$(printf '%s' "$hit" | jq -r '.path // empty')" \
            --arg b "$(printf '%s' "$hit" | jq -r '.branch // empty' | sed 's#^refs/heads/##')" >/dev/null \
            || echo "could not write the worktree to the state record: $f" >&2
        fi
      fi
      echo "skipped $n"
      continue
    fi
    # 空き枠が無ければ作らず注意書きも投稿しない。create に進む子は結果によらず 1 枠を使う
    # （worktree が空の自分の記録が既に枠に入っているときは、その 1 枠を使う）
    if [ "$own" -eq 0 ]; then
      if [ "$free" -le 0 ]; then
        echo "deferred $n"; continue
      fi
      free=$(( free - 1 ))
    fi
    # 子のワークツリーを作る前に記録を書く（作成に失敗したら消す）
    if ! es_write "$f" "$(es_new_record "$erepo" "$epic" "$crepo" "$num" orca "$parent" "" "" "$cbase" running "")"; then
      echo "could not write the state record: $f" >&2
      echo "failed $n"; failed=1; continue
    fi
    if [ "$xrepo" -eq 1 ]; then
      prompt="/develop #$num （エピック #$epic の子。エピックのリポジトリ ${erepo}。親ワークツリー $parent から Orca で起動）"
      agent_cmd_for "$erepo#$epic"
      # 子の clone の origin から起点を取る（失敗したら記録を消して作らない）
      if ! git -C "$cclone" fetch origin "$cbase" >&2; then
        echo "git -C $cclone fetch origin $cbase failed" >&2
        rm -f "$f"
        echo "failed $n"; failed=1; continue
      fi
      out="$(orca worktree create --repo "id:$crid" --name "issue-$num" --issue "$num" --base-branch "origin/$cbase" \
        --parent-worktree "path:$parent" --json)"
      rc=$?
    else
      prompt="/develop #$num （エピック #$epic の子。親ワークツリー $parent から Orca で起動）"
      out="$(orca worktree create --name "issue-$num" --issue "$num" --base-branch "origin/$cbase" \
        --parent-worktree "path:$parent" --json)"
      rc=$?
    fi
    [ -n "$note" ] && prompt="$prompt $note"
    printf '%s\n' "$out" >&2
    if [ "$rc" -ne 0 ]; then
      rm -f "$f"
      echo "failed $n"; failed=1; continue
    fi
    # 注意書きを子 issue に残す（起動し直したセッションにも届く）。このあとの失敗でワークツリーが
    # 残れば次の launch では skipped になるので、端末より前に投稿する。失敗しても起動は続ける
    if [ -n "$note" ]; then
      if [ "$xrepo" -eq 1 ]; then
        body="$(printf '親エピックからの注意書き: %s#%s\n\n%s' "$erepo" "$epic" "$note")"
        if ! gh issue comment "$num" -R "$crepo" --body "$body" >&2; then
          echo "note not posted to $crepo#$num. post it with the command below:" >&2
          echo "gh issue comment $num -R $crepo --body $(shq "$body")" >&2
        fi
      else
        body="$(printf '親エピックからの注意書き: #%s\n\n%s' "$epic" "$note")"
        if ! gh issue comment "$num" --body "$body" >&2; then
          echo "note not posted to #$num. post it with the command below:" >&2
          echo "gh issue comment $num --body $(shq "$body")" >&2
        fi
      fi
    fi
    child="$(printf '%s' "$out" | jq -r '.result.worktree.path // empty' 2>/dev/null)"
    if [ -z "$child" ]; then
      echo "no worktree path for #$num in orca worktree create --json" >&2
      es_modify "$f" '.launch_failed = "create"' >/dev/null || true
      echo "failed $n"; failed=1; continue
    fi
    cbranch="$(printf '%s' "$out" | jq -r '.result.worktree.branch // empty' 2>/dev/null)"
    es_modify "$f" '.worktree = $w | .branch = $b' --arg w "$child" --arg b "${cbranch#refs/heads/}" >/dev/null \
      || echo "could not write the worktree to the state record: $f" >&2
    # worktree create が空のシェルの端末を 1 つ作っていれば、新しい端末は作らずそこで起動する
    # （端末が 2 つになると reply が ambiguous-terminal で止まる）。0 個なら従来どおり作る
    handle=""; shell_rc=0; stage=""
    shell_start "$child" "$agent_cmd" || shell_rc=$?
    if [ "$shell_rc" -eq 0 ]; then
      handle="$SHELL_HANDLE"
    elif [ "$shell_rc" -eq 3 ]; then
      stage=terminal
    else
      out="$(orca terminal create --worktree "path:$child" --command "$agent_cmd" --json)"
      rc=$?
      printf '%s\n' "$out" >&2
      [ "$rc" -eq 0 ] && handle="$(printf '%s' "$out" | jq -r '.result.terminal.handle // empty' 2>/dev/null)"
      if [ -z "$handle" ]; then
        echo "no terminal handle for #$num from orca terminal create --json" >&2
        recreate_hint "$child" "$agent_cmd" "$prompt" "$submit"
        stage=terminal
      fi
    fi
    if [ -z "$stage" ] && ! orca terminal wait --terminal "$handle" --for tui-idle --timeout-ms "$ready" --json >&2; then
      resend_hint "$handle" "$prompt" "$submit"
      stage=ready
    fi
    if [ -z "$stage" ]; then
      sent="$(orca terminal send --terminal "$handle" --text "$prompt" --enter --wait-submit "$submit" --json)"
      rc=$?
      printf '%s\n' "$sent" >&2
      if [ "$rc" -eq 0 ] && turn_started "$sent"; then
        es_modify "$f" '.session = $s | .launch_failed = ""' --arg s "$handle" >/dev/null \
          || echo "could not write the session to the state record: $f" >&2
        echo "launched $n"; continue
      fi
      retry="$(retry_id "$sent")"
      resend_hint "$handle" "$prompt" "$submit" "$retry"
      stage=send
    fi
    # ワークツリーを作ったあとの失敗は記録を残し、段を書く（次の launch では skipped）
    es_modify "$f" '.launch_failed = $st | .session = $s' --arg st "$stage" --arg s "$handle" >/dev/null \
      || echo "could not write launch_failed to the state record: $f" >&2
    echo "failed $n"; failed=1
  done
  exit "$failed"
}

# 子の端末に、送り手を付けた返事を届ける（<relaunch 0|1> <parent|owner> <epic> <child> <text>）。
# 子のワークツリーは、親のワークツリー（PARENT_TOP）の記録の worktree から読む。need_parent と agent_setup を
# 済ませてから呼ぶ。stdout に `sent <child>` / `relaunched <child>` / `failed <child> <理由>` の
# 1 行を出し、failed なら 1 を返す。orca 自身の出力は stderr。reply・notify-closed・wait --resolve が共用する
deliver_reply() {
  local relaunch="$1" as="$2" epic="$3" n="$4" text="$5"
  local msg rec path terms tcount handle out rc sent prompt erefs=" " xrepo_epic=""
  child_record "$PARENT_TOP" "$n"
  case $? in
    0) ;;
    2) echo "failed $n ambiguous-worktree"; return 1 ;;
    3) echo "failed $n state-unreadable"; return 1 ;;
    *) echo "failed $n no-worktree"; return 1 ;;
  esac
  rec="$ES_HIT"
  path="$(es_get "$rec" worktree)"
  [ -n "$path" ] || { echo "failed $n no-worktree"; return 1; }
  # 記録の repo がエピックのリポジトリと違う子は、返事の頭・起動コマンド・起動し直しの指示にエピックのリポジトリを足す
  xrepo_epic="$(es_get "$rec" epic)"
  if [ -n "$xrepo_epic" ] && [ "$(es_get "$rec" repo)" != "${xrepo_epic%%#*}" ]; then
    erefs="（${xrepo_epic%%#*}）"
    agent_cmd_for "$xrepo_epic"
  else
    xrepo_epic=""
  fi
  case "$as" in
    parent) msg="親エピック #$epic${erefs}の判断（主の承認ではない）: $text" ;;
    *) msg="主の返事（親エピック #$epic${erefs}経由）: $text" ;;
  esac
  if ! terms="$(orca terminal list --worktree "path:$path" --json)" \
    || ! tcount="$(printf '%s' "$terms" \
      | jq -e '.result.terminals | if type == "array" then length else error("terminals is not an array") end' 2>/dev/null)"; then
    # terminals が欠落・null・配列以外なら 0 個と数えない（0 個として作り直すと、動いている子が二重に起動する）
    echo "orca terminal list --worktree path:$path --json is not readable" >&2
    echo "failed $n terminal-list"; return 1
  fi
  # 端末があれば、子のセッションの端末（Claude Code の端末 1 つ）に送る
  # （止まっている子の入力欄に打ち込み、ターンの開始まで確かめる）。Orca は子のワークツリーにシェルの
  # 端末も作るので、端末の数では決めない。決められなければ送らない（シェルの端末だけのときも、
  # それが子のセッションでないと一覧から言い切れないので起動し直さない。主の判断で --relaunch を使う）
  if [ "$relaunch" -eq 0 ] && [ "$tcount" -gt 0 ]; then
    handle="$(pick_session_term "$terms")"
    if [ -z "$handle" ]; then
      echo "terminals in $path: $tcount, but not exactly one is Claude Code (cannot tell which one runs the child session; use reply --relaunch to start it over)" >&2
      echo "failed $n ambiguous-terminal"; return 1
    fi
    sent="$(orca terminal send --terminal "$handle" --text "$msg" --enter --wait-submit "$submit" --json)"
    rc=$?
    printf '%s\n' "$sent" >&2
    if [ "$rc" -eq 0 ] && turn_started "$sent"; then
      echo "sent $n"; return 0
    fi
    resend_hint "$handle" "$msg" "$submit" "$(retry_id "$sent")"
    echo "failed $n send"; return 1
  fi
  # 端末が無いか --relaunch: 古いセッションを残したまま二重に起動しないよう、先に全部閉じてから作る
  if [ "$tcount" -gt 0 ]; then
    orca terminal close --worktree "path:$path" --all --json >&2 || { echo "failed $n close"; return 1; }
  fi
  if [ -n "$xrepo_epic" ]; then
    prompt="/develop #$(es_get "$rec" number) （エピック #$epic の子。エピックのリポジトリ ${xrepo_epic%%#*}。返事を受けて起動し直し） $msg"
  else
    prompt="/develop $(child_label "$n") （エピック #$epic の子。返事を受けて起動し直し） $msg"
  fi
  out="$(orca terminal create --worktree "path:$path" --command "$agent_cmd" --json)"
  rc=$?
  printf '%s\n' "$out" >&2
  handle=""
  [ "$rc" -eq 0 ] && handle="$(printf '%s' "$out" | jq -r '.result.terminal.handle // empty' 2>/dev/null)"
  if [ -z "$handle" ]; then
    recreate_hint "$path" "$agent_cmd" "$prompt" "$submit"
    echo "failed $n create"; return 1
  fi
  if ! orca terminal wait --terminal "$handle" --for tui-idle --timeout-ms "$ready" --json >&2; then
    resend_hint "$handle" "$prompt" "$submit"
    echo "failed $n ready"; return 1
  fi
  sent="$(orca terminal send --terminal "$handle" --text "$prompt" --enter --wait-submit "$submit" --json)"
  rc=$?
  printf '%s\n' "$sent" >&2
  if [ "$rc" -eq 0 ] && turn_started "$sent"; then
    # 起動し直した子のセッションの端末を記録に残す（見張りの判定には使わない。書けなくても送信は成功）
    es_modify "$rec" '.session = $s' --arg s "$handle" >/dev/null || echo "could not write the session to the state record: $rec" >&2
    echo "relaunched $n"; return 0
  fi
  resend_hint "$handle" "$prompt" "$submit" "$(retry_id "$sent")"
  echo "failed $n send"; return 1
}

cmd_reply() {
  local relaunch=0 as=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --relaunch) relaunch=1; shift ;;
      --as) [ "$#" -ge 2 ] || usage; as="$2"; shift 2 ;;
      --*) usage ;;
      *) break ;;
    esac
  done
  case "$as" in parent|owner) ;; *) echo "--as must be parent or owner" >&2; usage ;; esac
  [ "$#" -eq 3 ] || usage
  is_num "$1" || { echo "not an issue number: $1" >&2; usage; }
  check_children "$2"
  [ -n "$3" ] || { echo "the reply text must not be empty" >&2; usage; }
  agent_setup "$1" || usage
  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
  need_parent
  deliver_reply "$relaunch" "$as" "$1" "$2" "$3" || exit 1
  exit 0
}

# 止まった印のまま completed で閉じた子に、完了報告と mark done を促す返事を送り、エピックに 1 行残す。
# stdout に notified / unrecorded / skipped <理由> / failed <段> の 1 行
cmd_notify_closed() {
  local relaunch=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --relaunch) relaunch=1; shift ;;
      --*) usage ;;
      *) break ;;
    esac
  done
  [ "$#" -eq 2 ] || usage
  is_num "$1" || { echo "not an issue number: $1" >&2; usage; }
  check_children "$2"
  local epic="$1" n="$2"
  agent_setup "$epic" || usage
  need_parent
  local info state reason issue_url rec="" rrc api
  child_record "$PARENT_TOP" "$n"; rrc=$?
  [ "$rrc" -eq 0 ] && rec="$ES_HIT"
  api="$(issue_api "$n" "$rec")"
  if ! info="$(gh api "$api" --jq '[.state, (.state_reason // ""), .html_url] | join(" ")')"; then
    echo "could not read issue $(child_label "$n")" >&2
    echo "failed $n issue"; exit 1
  fi
  state="$(printf '%s' "$info" | awk '{print $1}')"
  reason="$(printf '%s' "$info" | awk 'NF == 3 {print $2}')"
  issue_url="$(printf '%s' "$info" | awk '{print $NF}')"
  case "$state" in
    closed) ;;
    open) echo "skipped $n not-closed"; exit 0 ;;
    *) echo "issue $(child_label "$n") state is not readable: $info" >&2; echo "failed $n issue"; exit 1 ;;
  esac
  [ "$reason" = completed ] || { echo "skipped $n not-completed"; exit 0; }
  case "$rrc" in
    0) ;;
    2) echo "failed $n ambiguous-worktree"; exit 1 ;;
    3) echo "failed $n state-unreadable"; exit 1 ;;
    *) echo "skipped $n no-worktree"; exit 0 ;;
  esac
  [ "$(es_get "$rec" status)" = "done" ] && { echo "skipped $n already-done"; exit 0; }
  case "$(es_get "$rec" stop)" in
    stopped|stopped-seen) ;;
    *) echo "skipped $n not-stopped"; exit 0 ;;
  esac
  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
  # 停止の記録は、信頼できる投稿者の最新の `子の停止: 主の返事待ち` のコメント（無ければ子 issue の URL）
  local url
  url="$(gh api "$api/comments" --paginate --jq \
    '.[] | select((.author_association == "OWNER" or .author_association == "MEMBER" or .author_association == "COLLABORATOR")
      and (((.body // "") | split("\n")[0] | rtrimstr("\r")) == "子の停止: 主の返事待ち")) | .html_url' 2>/dev/null \
    | awk 'NF { u = $0 } END { print u }')"
  [ -n "$url" ] || url="$issue_url"
  local text res line
  text="記録先の issue $(child_label "$n") は completed で閉じた。完了報告を書き、mark done で終える（停止の記録: ${url}）"
  res="$(deliver_reply "$relaunch" parent "$epic" "$n" "$text")"
  case "$res" in
    "sent $n"|"relaunched $n") ;;
    *) echo "$res"; exit 1 ;;
  esac
  # エピックへの記録は送れたあとに残す（送る前に残すと、送れなかったときに送っていない判断が残る）
  line="親の判断: 子 $(child_label "$n") 通した — 記録先が completed で閉じたので、完了報告と mark done を促した $url"
  if gh issue comment "$epic" --body "$line" >&2; then
    echo "notified $n"; exit 0
  fi
  repost_hint "$epic" "$line"
  echo "unrecorded $n"
  exit 0
}

# 今いるワークツリーを worktree に持つ自分の記録に印を付ける（done / waiting は status、stopped / resumed は stop）。
# 記録の number（<owner>/<repo>#<N> で渡したときは repo も）が引数と一致するときだけ書き、書けたら Orca の印へ写す
cmd_mark() {
  [ "$#" -eq 2 ] || usage
  local kind="$1" n="$2" filter set_args
  case "$kind" in
    done) filter='.status = "done"'; set_args="--workspace-status completed" ;;
    waiting) filter='.status = "waiting"'; set_args="--workspace-status in-review" ;;
    stopped) filter='.stop = "stopped"'; set_args="--comment epic-stopped" ;;
    resumed) filter='if .stop == "stopped" or .stop == "stopped-seen" then .stop = "resumed" else empty end'
      set_args="--comment epic-resumed" ;;
    *) usage ;;
  esac
  es_valid_arg "$n" || { echo "not an issue number or <owner>/<repo>#<number>: $n" >&2; usage; }
  local top found cnt f num repo rc
  if ! command -v jq >/dev/null 2>&1 || ! top="$(toplevel)" || [ -z "$top" ] || [ -z "$ES_ROOT" ]; then
    echo "skipped $n no-workspace"
    return 0
  fi
  found="$(es_find_by_worktree "$top")"
  if [ -z "$found" ]; then
    echo "skipped $n no-workspace"
    return 0
  fi
  cnt="$(printf '%s\n' "$found" | grep -c .)"
  if [ "$cnt" -gt 1 ]; then
    echo "more than one state record has this worktree ($top):" >&2
    printf '%s\n' "$found" >&2
    echo "failed $n"
    exit 1
  fi
  f="$found"
  es_parse_arg "$n"
  num="$(es_get "$f" number)"; repo="$(es_get "$f" repo)"
  if [ "$num" != "$ES_ARG_NUM" ] || { [ -n "$ES_ARG_REPO" ] && [ "$repo" != "$ES_ARG_REPO" ]; }; then
    echo "this worktree's state record is for ${repo}#${num}, not $n: $f" >&2
    echo "skipped $n not-linked"
    return 0
  fi
  es_modify "$f" "$filter" >/dev/null; rc=$?
  case "$rc" in
    0) ;;
    4) echo "skipped $n not-stopped"; return 0 ;;
    *) echo "failed $n"; exit 1 ;;
  esac
  # shellcheck disable=SC2086
  mirror_orca "$f" current $set_args
  echo "marked $n $kind"
  return 0
}

# 投稿に失敗したコメントの、投稿し直しのコマンドを stderr に出す（<issue> <本文>）
repost_hint() {
  echo "comment not posted to #$1. post it again: gh issue comment $1 --body $(shq "$2")" >&2
}

# 通す返事を起動し直して送るかを決める（<子のワークツリーのパス>）。起動し直すなら 1、そのまま送るなら 0 を出す。
# 事実を 1 つでも読めなければ 0（references/reply-after-idle.md の表の「扱いが揺れる子」と同じ）
decide_relaunch() {
  local path="$1" dir files count file facts last compacted now ctx
  local idle="${EPIC_DISPATCH_RELAUNCH_IDLE_SEC:-3600}" min="${EPIC_DISPATCH_RELAUNCH_MIN_TOKENS:-150000}"
  dir="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}/$(printf '%s' "$path" | sed 's/[^A-Za-z0-9]/-/g')"
  files="$(ls -1 "$dir"/*.jsonl 2>/dev/null)"
  [ -n "$files" ] || { echo 0; return 0; }
  count="$(printf '%s\n' "$files" | wc -l | tr -d ' ')"
  [ "$count" -eq 1 ] || { echo 0; return 0; }
  file="$files"
  command -v python3 >/dev/null 2>&1 || { echo 0; return 0; }
  facts="$(FILE="$file" python3 - <<'PY' 2>/dev/null
import json, os, datetime
last = None; idx_a = -1; idx_c = -1
with open(os.environ["FILE"], encoding="utf-8") as f:
    for i, line in enumerate(f):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if not isinstance(d, dict):
            continue
        if d.get("type") == "assistant" and isinstance(d.get("timestamp"), str):
            last = d["timestamp"]; idx_a = i
        elif d.get("subtype") == "compact_boundary":
            idx_c = i
if last is None:
    raise SystemExit(1)
t = datetime.datetime.fromisoformat(last.replace("Z", "+00:00")).timestamp()
print(int(t), 1 if idx_c > idx_a else 0)
PY
)" || { echo 0; return 0; }
  last="${facts%% *}"; compacted="${facts##* }"
  is_num "$last" || { echo 0; return 0; }
  [ "$compacted" = 0 ] || { echo 0; return 0; }
  now="$(date +%s)"
  [ $((now - last)) -ge "$idle" ] || { echo 0; return 0; }
  ctx="$("$(dirname "$0")/subagent-context.sh" --file "$file" --cap 2147483647 2>/dev/null | jq -r '.context_tokens // empty' 2>/dev/null)"
  is_num "$ctx" || { echo 0; return 0; }
  [ "$ctx" -ge "$min" ] && echo 1 || echo 0
}

# wait --resolve: 止まった子 1 件を判断のコマンドに渡し、結果どおりに送るか子 issue に残す
# （<epic> <child>）。need_parent と agent_setup を済ませてから呼ぶ。
# 戻り値 0 = 通して返事を送り、エピックに 1 行残した（出力から外す）/ 2 = 通して送ったが
# エピックに残せなかった（unrecorded）/ 1 = 主に上げる・判断できなかった（stopped に残す）
resolve_stopped() {
  local epic="$1" n="$2"
  local judge="${EPIC_DISPATCH_JUDGE:-$(dirname "$0")/stop-judge.sh}"
  local out rc l1 l2 l3 l4 reason="" reply="" url="" why="" res line body rl wpath
  local head1="親の判断: 判断できなかった"
  out="$("$judge" "$epic" "$n")"; rc=$?
  l1="$(printf '%s\n' "$out" | sed -n 1p)"
  l2="$(printf '%s\n' "$out" | sed -n 2p)"
  l3="$(printf '%s\n' "$out" | sed -n 3p)"
  l4="$(printf '%s\n' "$out" | sed -n 4p)"
  # 停止の記録の URL は、判断の出力から読めたときだけ使う
  case "$l4" in "記録: "?*) url="${l4#記録: }" ;; esac
  case "$l2" in "理由: "*) reason="${l2#理由: }" ;; *) l2="" ;; esac
  case "$l3" in "返事: "*) reply="${l3#返事: }" ;; "返事:") ;; *) l3="" ;; esac
  if [ "$rc" -ne 0 ]; then
    why="判断のコマンドが exit $rc で終わった"
  elif [ -z "$l2" ] || [ -z "$l3" ] || [ -z "$url" ]; then
    why="判断の出力を 4 行の形で読めなかった"
  elif [ "$l1" = "判断: 主に上げる" ]; then
    body="$(printf '親の判断: 主に上げる\n停止の記録: %s\n%s' "$url" "$reason")"
    gh issue comment "$(child_ref "$n")" --body "$body" >&2 || repost_hint "$(child_ref "$n")" "$body"
    return 1
  elif [ "$l1" != "判断: 通す" ]; then
    why="判断の出力の 1 行目が「判断: 通す」でも「判断: 主に上げる」でもない"
  elif [ -z "$reply" ]; then
    why="判断は通すだが、返事の行が空"
  else
    rl=0
    # 子のワークツリーのパスは記録の worktree から読む（読めなければそのまま送る）
    wpath=""
    if child_record "$PARENT_TOP" "$n"; then wpath="$(es_get "$ES_HIT" worktree)"; fi
    [ -z "$wpath" ] || rl="$(decide_relaunch "$wpath")"
    res="$(deliver_reply "$rl" parent "$epic" "$n" "$reply")"
    case "$res" in
      "sent $n"|"relaunched $n")
        # エピックへの記録は送れたあとに残す（送る前に残すと、送れなかったときに通していない判断が残る）
        line="親の判断: 子 $(child_label "$n") 通した — $reason $url"
        if gh issue comment "$epic" --body "$line" >&2; then
          return 0
        fi
        repost_hint "$epic" "$line"
        return 2 ;;
    esac
    why="$(printf '返事を送れなかった: %s\n送るはずだった返事: %s' "$res" "$reply")"
    head1="親の判断: 通すが送れなかった"
  fi
  # 判断の出力そのものは公開の子 issue に貼らない（モデルの入力には gitignore 済みの配役表も入るので、
  # 出力に引用されうる）。見たいときのために stderr にだけ出す
  [ -n "$out" ] && printf 'judge output for #%s:\n%s\n' "$n" "$out" >&2
  body="$(printf '%s\n停止の記録: %s\n%s' "$head1" "${url:-不明}" "$why")"
  gh issue comment "$(child_ref "$n")" --body "$body" >&2 || repost_hint "$(child_ref "$n")" "$body"
  return 1
}

cmd_wait() {
  local interval="${EPIC_DISPATCH_INTERVAL:-300}" timeout="${EPIC_DISPATCH_TIMEOUT:-21600}"
  # --watch-done の子（空白区切り。bash 3.2 の set -u で空の配列を展開できないので文字列で持つ）
  local watch="" watchstop=0 resolve=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --interval) [ "$#" -ge 2 ] || usage; interval="$2"; shift 2 ;;
      --timeout) [ "$#" -ge 2 ] || usage; timeout="$2"; shift 2 ;;
      --watch-done)
        [ "$#" -ge 2 ] || usage
        es_valid_arg "$2" || { echo "--watch-done needs an issue number or <owner>/<repo>#<number>: $2" >&2; usage; }
        case " $watch " in *" $2 "*) ;; *) watch="$watch $2" ;; esac
        shift 2 ;;
      --watch-stopped) watchstop=1; shift ;;
      --resolve)
        [ "$#" -ge 2 ] || usage
        is_num "$2" || { echo "--resolve needs an epic issue number: $2" >&2; usage; }
        resolve="$2"; shift 2 ;;
      --*) usage ;;
      *) break ;;
    esac
  done
  is_num "$interval" || { echo "--interval must be a non-negative integer: $interval" >&2; usage; }
  is_num "$timeout" || { echo "--timeout must be a non-negative integer: $timeout" >&2; usage; }
  [ "$#" -ge 1 ] || [ -n "$watch" ] || usage
  check_children "$@"
  # --watch-stopped は位置引数の子だけを見る（子が 0 件なら何も見ない）
  [ "$#" -ge 1 ] || watchstop=0
  # --resolve は --watch-stopped（子 1 件以上）のときだけ働く。返事の送り方の設定は待つ前に確かめる
  [ "$watchstop" -eq 1 ] || resolve=""
  if [ -n "$resolve" ]; then
    agent_setup "$resolve" || usage
    is_num "${EPIC_DISPATCH_RELAUNCH_IDLE_SEC-3600}" || { echo "EPIC_DISPATCH_RELAUNCH_IDLE_SEC must be a non-negative integer" >&2; usage; }
    is_num "${EPIC_DISPATCH_RELAUNCH_MIN_TOKENS-150000}" || { echo "EPIC_DISPATCH_RELAUNCH_MIN_TOKENS must be a non-negative integer" >&2; usage; }
  fi

  # 子の記録は親のワークツリー（今のワークツリー）で探す。印を見るときは jq と今のワークツリーが要る。
  # 印を見ないときも、jq と今のワークツリーが読めれば記録で gh の呼び先（別リポジトリの子）を決める
  if [ -n "$watch" ] || [ "$watchstop" -eq 1 ]; then
    need_parent
  elif command -v jq >/dev/null 2>&1; then
    PARENT_TOP="$(toplevel)" || PARENT_TOP=""
  fi

  local fails=0 n state closed failed marked stopped wsfail unrecorded still rec f
  local errf; errf="$(mktemp)"; trap 'rm -f "$errf"' EXIT
  SECONDS=0
  while :; do
    closed=""; failed=""; marked=""; stopped=""; unrecorded=""; wsfail=0; : > "$errf"
    for n in "$@"; do
      rec=""
      if [ -n "$PARENT_TOP" ] && child_record "$PARENT_TOP" "$n" 2>/dev/null; then rec="$ES_HIT"; fi
      if state="$(gh api "$(issue_api "$n" "$rec")" --jq .state 2>>"$errf")"; then
        case "$state" in
          closed) closed="$closed $n" ;;
          open) ;;
          *) failed="$failed $n" ;;
        esac
      else
        failed="$failed $n"
      fi
    done
    # 完了の印（status が done）と止まった印（stop が stopped）は、ポーリングごとに子の記録を読んで見る。
    # 読めない記録は失敗したポーリングに数え、同じ子の記録が 2 件以上なら印を見ない
    for n in $watch; do
      child_record "$PARENT_TOP" "$n"
      case $? in
        0) [ "$(es_get "$ES_HIT" status)" = "done" ] && marked="$marked $n" ;;
        3) wsfail=1 ;;
      esac
    done
    # 止まった印は、閉じていない位置引数の子だけを、排他つきで受けた印（stopped-seen）に書き換えてから数える
    if [ "$watchstop" -eq 1 ]; then
      for n in "$@"; do
        case " $closed $stopped " in *" $n "*) continue ;; esac
        child_record "$PARENT_TOP" "$n"
        case $? in
          0) ;;
          3) wsfail=1; continue ;;
          *) continue ;;
        esac
        f="$ES_HIT"
        [ "$(es_get "$f" stop)" = stopped ] || continue
        es_modify "$f" 'if .stop == "stopped" then .stop = "stopped-seen" else empty end' >/dev/null 2>>"$errf"
        case $? in
          0)
            mirror_orca "$f" "path:$(es_get "$f" worktree)" --comment epic-stopped-seen
            stopped="$stopped $n" ;;
          4) ;;
          *) wsfail=1 ;;
        esac
      done
    fi
    # --resolve: 止まった子ごとに判断し、通して記録できた子は出力から外す
    if [ -n "$resolve" ] && [ -n "$stopped" ]; then
      still=""
      for n in $stopped; do
        resolve_stopped "$resolve" "$n"
        case $? in
          0) ;;
          2) unrecorded="$unrecorded $n" ;;
          *) still="$still $n" ;;
        esac
      done
      stopped="$still"
    fi
    if [ -n "$closed" ] || [ -n "$marked" ] || [ -n "$stopped" ] || [ -n "$unrecorded" ]; then
      [ -n "$closed" ] && echo "closed${closed}"
      [ -n "$marked" ] && echo "done${marked}"
      [ -n "$stopped" ] && echo "stopped${stopped}"
      [ -n "$unrecorded" ] && echo "unrecorded${unrecorded}"
      exit 0
    fi
    if [ -n "$failed" ] || [ "$wsfail" -eq 1 ]; then
      fails=$((fails + 1))
      if [ "$fails" -ge 3 ]; then
        cat "$errf" >&2
        if [ -n "$failed" ]; then
          echo "error gh${failed}"
        else
          echo "error workspaces"
        fi
        exit 1
      fi
    else
      fails=0
    fi
    # 閉じた子がいないので、開いている子とこのポーリングで失敗した子は引数の全部。
    # 経過が上限に達していれば間隔 0 でも終わる（--timeout 0 を 1 回の確認で終わらせるため）
    if [ "$SECONDS" -ge "$timeout" ] || [ $((SECONDS + interval)) -gt "$timeout" ]; then
      if [ "$#" -gt 0 ]; then echo "timeout $*"; else echo "timeout"; fi
      exit 2
    fi
    sleep "$interval"
  done
}

# pending-owner: 記録の stop が受けた印（stopped-seen）のままの子を出す。読み取り専用。読めない記録の子は飛ばす
cmd_pending_owner() {
  [ "$#" -ge 1 ] || usage
  check_children "$@"
  need_parent
  local n
  for n in "$@"; do
    child_record "$PARENT_TOP" "$n" || continue
    [ "$(es_get "$ES_HIT" stop)" = stopped-seen ] && echo "pending $n"
  done
  exit 0
}

# 完了の印が付き、安全確認を全部通った子だけ、端末を閉じてワークツリーとローカルブランチを消す。
# 子ごとに stdout へ 1 行（reaped / reaped branch-kept / gone / kept <理由>）
# git を -C <dir> 付き（dir が空でなければ）か今のディレクトリで呼ぶ（<dir> <git の引数...>）
gitx() {
  local d="$1"
  shift
  if [ -n "$d" ]; then git -C "$d" "$@"; else git "$@"; fi
}

# gh pr list を -R <repo> 付き（repo が空でなければ）か今のリポジトリで呼ぶ（<repo> <gh pr list の引数...>）
ghpr() {
  local r="$1"
  shift
  if [ -n "$r" ]; then gh pr list -R "$r" "$@"; else gh pr list "$@"; fi
}

cmd_reap() {
  [ "$#" -ge 1 ] || usage
  check_children "$@"
  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
  need_parent

  local n f w path branch st head heads sheads rmerr tip seen=" "
  local legacy allprs istate lsout btip="" base="${EPIC_DISPATCH_BASE:-main}"
  local rr wd gd cbase bkey bvar fvar erec
  for n in "$@"; do
    case "$seen" in *" $n "*) continue ;; esac
    seen="$seen$n "
    # 子の記録は、親のワークツリー（今のワークツリー）の記録だけを見る。記録の無い子は片付け済み
    child_record "$PARENT_TOP" "$n"
    case $? in
      0) ;;
      2) echo "kept $n ambiguous"; continue ;;
      3) echo "kept $n state-unreadable"; continue ;;
      *) echo "gone $n"; continue ;;
    esac
    f="$ES_HIT"
    path="$(es_get "$f" worktree)"
    # 子のワークツリーがもう無ければ記録を消して gone
    if [ -z "$path" ] || [ ! -d "$path" ]; then
      rm -f "$f"; echo "gone $n"; continue
    fi
    [ "$(es_get "$f" status)" = "done" ] || { echo "kept $n not-done"; continue; }
    # 記録の repo がエピックのリポジトリと違う子は、PR の照会を子のリポジトリ（-R）に、base の照会を子のワークツリーの
    # origin に、base の名前を記録の base に向ける。同じリポジトリの子は今のまま
    rr=""; wd=""; gd=""; cbase="$base"
    erec="$(es_get "$f" epic)"
    if [ -n "$erec" ] && [ "$(es_get "$f" repo)" != "${erec%%#*}" ]; then
      rr="$(es_get "$f" repo)"; wd="$path"
      cbase="$(es_get "$f" base)"; [ -n "$cbase" ] || cbase="main"
    fi
    st="$(git -C "$path" status --porcelain)" || { echo "kept $n git-failed"; continue; }
    [ -z "$st" ] || { echo "kept $n dirty"; continue; }
    [ ! -e "$path/LLM" ] || { echo "kept $n llm-logs"; continue; }
    branch="$(es_get "$f" branch)"
    branch="${branch#refs/heads/}"
    [ -n "$branch" ] || { echo "kept $n no-branch"; continue; }
    head="$(git -C "$path" rev-parse HEAD)" || head=""
    heads="$(ghpr "$rr" --head "$branch" --state merged --json headRefOid --jq '.[].headRefOid')" \
      || { echo "kept $n pr-lookup-failed"; continue; }
    if [ -z "$head" ] || ! printf '%s\n' "$heads" | grep -qxF -- "$head"; then
      # squash マージでは別名のブランチの PR で入ることがある。HEAD を先端に持つマージ済み PR を
      # ブランチ名を問わず探す（最終判定は headRefOid と HEAD の完全一致のまま）
      sheads=""
      if [ -n "$head" ]; then
        sheads="$(ghpr "$rr" --state merged --search "$head" --json headRefOid --jq '.[].headRefOid')" \
          || { echo "kept $n pr-lookup-failed"; continue; }
      fi
      if [ -z "$head" ] || ! printf '%s\n' "$sheads" | grep -qxF -- "$head"; then
        legacy="head-mismatch"
        if [ -z "$heads" ] && [ -z "$sheads" ]; then legacy="no-merged-pr"; fi
        # PR が 1 件も無く issue が閉じた子（PR を伴わない記録先）は、HEAD がリモートの今の base に
        # 含まれるときだけ片付ける。判定の相手は手元の追跡参照ではなく ls-remote で取った今の先端
        [ -n "$head" ] || { echo "kept $n $legacy"; continue; }
        allprs="$(ghpr "$rr" --head "$branch" --state all --json number --jq '.[].number')" \
          || { echo "kept $n pr-lookup-failed"; continue; }
        [ -z "$allprs" ] || { echo "kept $n $legacy"; continue; }
        istate="$(gh api "$(issue_api "$n" "$f")" --jq .state)" \
          || { echo "kept $n issue-lookup-failed"; continue; }
        [ "$istate" = closed ] || { echo "kept $n $legacy"; continue; }
        # base の先端は、リポジトリと base の組ごとに 1 回だけ読む（別のリポジトリの子の先端を使い回さない）
        bkey="$(printf '%s_%s' "${rr:-same}" "$cbase" | tr -c 'A-Za-z0-9' '_')"
        bvar="REAPT_$bkey"; fvar="REAPF_$bkey"
        if [ -z "${!bvar-}" ]; then
          btip=""
          if lsout="$(gitx "$wd" ls-remote origin "refs/heads/$cbase")"; then
            btip="$(printf '%s\n' "$lsout" | awk 'NR==1{print $1}')"
            case "$btip" in
              *[!0-9a-f]*) btip="" ;;
              *) [ "${#btip}" -eq 40 ] || btip="" ;;
            esac
          fi
          printf -v "$bvar" '%s' "L$btip"
        fi
        btip="${!bvar}"; btip="${btip#L}"
        [ -n "$btip" ] || { echo "kept $n base-lookup-failed"; continue; }
        if ! gitx "$wd" cat-file -e "$btip^{commit}" >&2; then
          if [ -z "${!fvar-}" ]; then
            printf -v "$fvar" '%s' 1
            gitx "$wd" fetch origin "$cbase" >&2 || true
          fi
          gitx "$wd" cat-file -e "$btip^{commit}" >&2 || { echo "kept $n base-lookup-failed"; continue; }
        fi
        git -C "$path" merge-base --is-ancestor "$head" "$btip" >&2
        case "$?" in
          0) ;;
          1) echo "kept $n unmerged-commits"; continue ;;
          *) echo "kept $n git-failed"; continue ;;
        esac
      fi
    fi
    # 別のリポジトリの子のブランチの片付けは子の clone に向ける。ワークツリーが消える前（orca worktree rm の前）に
    # 共通の git ディレクトリを控える
    if [ -n "$wd" ]; then
      gd="$(git -C "$path" rev-parse --path-format=absolute --git-common-dir)" && [ -n "$gd" ] \
        || { echo "kept $n git-failed"; continue; }
    fi
    # 端末の閉じが失敗したら（子のターンが終わっておらず terminal_close_incomplete になることがある）、
    # 原因の手がかりに端末の一覧を stderr に出し、待ってから 1 回だけ閉じ直す。それでも駄目なら主の操作に回す
    if ! orca terminal close --worktree "path:$path" --all >&2; then
      cw="${EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT:-10}"
      case "$cw" in ''|*[!0-9]*) cw=10 ;; esac
      echo "terminal close was incomplete for #$n; listing terminals, waiting ${cw}s and retrying once" >&2
      orca terminal list --worktree "path:$path" --json >&2 || true
      sleep "$cw"
      if ! orca terminal close --worktree "path:$path" --all >&2; then
        echo "owner action for #$n: open the workspace $path in Orca, wait for the child's running turn to end or close its terminals by hand, then run: epic-dispatch.sh reap $n" >&2
        echo "kept $n close-failed"; continue
      fi
    fi
    # --force は付けない（確認のあとに増えた未コミットの変更があれば rm が止まる）
    # 端末の片付けの失敗（stderr に terminal sweep failed）は別の理由で返す。再試行もしない
    rmerr="$(mktemp)" || { echo "kept $n rm-failed"; continue; }
    if ! orca worktree rm --worktree "path:$path" 2>"$rmerr"; then
      cat "$rmerr" >&2
      if grep -qF -- 'terminal sweep failed' "$rmerr"; then
        echo "kept $n rm-failed-terminal-sweep"
      else
        echo "kept $n rm-failed"
      fi
      rm -f "$rmerr"; continue
    fi
    cat "$rmerr" >&2; rm -f "$rmerr"
    if tip="$(gitx "$gd" rev-parse --verify --quiet "refs/heads/$branch")"; then
      # Orca は rm の exit 0 のあともワークツリーを非同期で消すことがあり、git の一覧から外れるまで
      # そのブランチは消せない。先端が HEAD と同じときだけ、外れるのを上限つきで待つ
      # （git worktree list が失敗したら残っているものとして待つ。上限を超えたら branch-kept）
      attached=0
      if [ "$tip" = "$head" ]; then
        dt="${EPIC_DISPATCH_REAP_DETACH_TIMEOUT:-30}"; di="${EPIC_DISPATCH_REAP_DETACH_INTERVAL:-1}"
        case "$dt" in ''|*[!0-9]*) dt=30 ;; esac
        case "$di" in ''|*[!0-9]*|0) di=1 ;; esac
        tries=$(( dt / di + 1 ))
        started=$SECONDS
        while :; do
          if wtl="$(gitx "$gd" worktree list --porcelain)" && ! printf '%s\n' "$wtl" | grep -qxF -- "worktree $path"; then
            attached=0; break
          fi
          attached=1
          tries=$(( tries - 1 ))
          [ "$tries" -gt 0 ] || break
          [ $(( SECONDS - started )) -lt "$dt" ] || break
          echo "waiting for the worktree to leave git: $path" >&2
          sleep "$di"
        done
      fi
      # 待っている間に先端が進んだかもしれないので、消す直前に読み直して HEAD と比べる
      if [ "$tip" = "$head" ] && [ "$attached" -eq 0 ] \
        && tip2="$(gitx "$gd" rev-parse --verify --quiet "refs/heads/$branch")" && [ "$tip2" = "$head" ] \
        && gitx "$gd" branch -D "$branch" >&2; then
        rm -f "$f"; echo "reaped $n"
      else
        rm -f "$f"; echo "reaped $n branch-kept"
      fi
    else
      rm -f "$f"; echo "reaped $n"
    fi
  done
  exit 0
}

# 記録の無い Orca の子（この変更の前に起動した子）を記録に取り込む。親を起動し直したときに使う
cmd_adopt() {
  [ "$#" -ge 2 ] || usage
  local epic="$1"; shift
  is_num "$epic" || { echo "not an issue number: $epic" >&2; usage; }
  check_children "$@"
  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH" >&2; exit 1; }
  local base="${EPIC_DISPATCH_BASE:-main}" current repo cid parent erepo list
  current="$(orca worktree current --json)" || { echo "not in an Orca-managed worktree" >&2; exit 1; }
  repo="$(printf '%s' "$current" | jq -r '.result.worktree.repoId // empty' 2>/dev/null)"
  cid="$(printf '%s' "$current" | jq -r '.result.worktree.id // empty' 2>/dev/null)"
  [ -n "$repo" ] || { echo "orca worktree current --json has no repoId" >&2; exit 1; }
  parent="$(toplevel)" && [ -n "$parent" ] || { echo "git rev-parse failed" >&2; exit 1; }
  erepo="$(es_epic_repo)" || exit 1
  list="$(orca worktree list --json)" || { echo "orca worktree list failed" >&2; exit 1; }
  printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1 \
    || { echo "orca worktree list --json is not readable" >&2; exit 1; }
  [ -n "$cid" ] || echo "orca worktree current --json has no id; no child is found" >&2

  local n num crepo f hits cnt w b st sp failed=0
  for n in "$@"; do
    es_parse_arg "$n"; num="$ES_ARG_NUM"; crepo="${ES_ARG_REPO:-$erepo}"
    f="$(es_path "$erepo" "$epic" "$crepo" "$num")"
    if [ -e "$f" ]; then
      if es_read "$f" >/dev/null; then echo "skipped $n"
      else echo "unreadable state record: $f" >&2; echo "failed $n state-unreadable"; failed=1; fi
      continue
    fi
    # Orca の一覧は今のワークツリーと同じリポジトリのワークツリーだけを持つ
    if [ "$crepo" != "$erepo" ] || [ -z "$cid" ]; then echo "none $n"; continue; fi
    hits="$(printf '%s' "$list" | jq -c --arg r "$repo" --arg n "$num" --arg p "$cid" \
      '[.result.worktrees[] | select(.repoId == $r and (.linkedIssue | tostring) == $n
        and .isArchived != true and .parentWorktreeId == $p)]')"
    cnt="$(printf '%s' "$hits" | jq 'length')"
    if [ "$cnt" -eq 0 ]; then echo "none $n"; continue; fi
    if [ "$cnt" -gt 1 ]; then
      echo "two or more Orca worktrees for $n under this parent" >&2
      echo "failed $n ambiguous"; failed=1; continue
    fi
    w="$(printf '%s' "$hits" | jq -r '.[0].path // empty')"
    b="$(printf '%s' "$hits" | jq -r '.[0].branch // empty')"; b="${b#refs/heads/}"
    st="$(printf '%s' "$hits" | jq -r '.[0].workspaceStatus // "" |
      if . == "completed" then "done" elif . == "in-review" then "waiting" else "running" end')"
    sp="$(printf '%s' "$hits" | jq -r '.[0].comment // "" |
      if . == "epic-stopped" then "stopped" elif . == "epic-stopped-seen" then "stopped-seen"
      elif . == "epic-resumed" then "resumed" else "" end')"
    if ! es_write "$f" "$(es_new_record "$erepo" "$epic" "$crepo" "$num" orca "$parent" "$w" "$b" "$base" "$st" "$sp")"; then
      echo "could not write the state record: $f" >&2
      echo "failed $n"; failed=1; continue
    fi
    echo "adopted $n"
  done
  exit "$failed"
}

# エピックの状態ディレクトリ（EPIC_STATE_ROOT 直下の 1 つ）を消す。エピックの完了時に使う
cmd_clear() {
  [ "$#" -eq 1 ] || usage
  local epic="$1" home="${HOME%/}" erepo name d rf c
  [[ "$epic" =~ ^[0-9]+$ ]] || { echo "not an issue number: $epic" >&2; usage; }
  if [ "$ES_ROOT" = "/" ] || [ -z "$ES_ROOT" ] || { [ -n "$home" ] && [ "$ES_ROOT" = "$home" ]; }; then
    echo "refusing to clear under EPIC_STATE_ROOT=$ES_ROOT (the root or the home directory itself)" >&2; exit 1
  fi
  erepo="$(es_epic_repo)" || exit 1
  name="$(es_name "$erepo" "$epic")"
  case "$name" in
    */*|*..*) echo "refusing to clear an unexpected directory name: $name" >&2; exit 1 ;;
  esac
  d="$ES_ROOT/$name"
  if [ -L "$d" ]; then echo "refusing to clear a symbolic link: $d" >&2; exit 1; fi
  if [ ! -e "$d" ]; then echo "none $epic"; exit 0; fi
  [ -d "$d" ] || { echo "not a directory: $d" >&2; exit 1; }
  for rf in "$d"/*.json; do
    [ -f "$rf" ] || continue
    c="$(es_get "$rf" child)"
    echo "remaining state record: ${c:-unreadable} ($rf)" >&2
  done
  rm -rf -- "$d" || { echo "could not remove $d" >&2; exit 1; }
  echo "cleared $epic"
}

[ "$#" -ge 1 ] || usage
sub="$1"; shift
es_check_env || usage
es_root_init || { case "$sub" in route|mark|max-parallel) ;; *) exit 1 ;; esac; }
case "$sub" in
  route) cmd_route "$@" ;;
  launch) cmd_launch "$@" ;;
  reply) cmd_reply "$@" ;;
  notify-closed) cmd_notify_closed "$@" ;;
  wait) cmd_wait "$@" ;;
  mark) cmd_mark "$@" ;;
  reap) cmd_reap "$@" ;;
  pending-owner) cmd_pending_owner "$@" ;;
  adopt) cmd_adopt "$@" ;;
  clear) cmd_clear "$@" ;;
  max-parallel) cmd_max_parallel "$@" ;;
  *) usage ;;
esac
