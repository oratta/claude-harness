#!/usr/bin/env bash
# エピックの子の経路判定・起動・待ち受けを LLM なしで行う。develop の本体（エピックの解決
# セッション）が SKILL.md「エピックの扱い」→「回し方」の手順どおりに呼ぶ。
#
#   epic-dispatch.sh route <child>...
#   epic-dispatch.sh launch [--note <text>] [--base <branch>] <epic> <child>...
#   epic-dispatch.sh reply [--relaunch] --as <parent|owner> <epic> <child> <text>
#   epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] [--watch-done <child>]... [--watch-stopped] [--resolve <epic>] [<child>...]
#   epic-dispatch.sh mark <done|waiting|stopped|resumed> <issue>
#   epic-dispatch.sh reap <child>...
#
# Orca のコマンドを呼ぶのはこのスクリプトだけ（develop の手順書には orca のコマンドを書かない）。
# route: 子の番号の検査のあと、子の件数によらず最初に「エピックの子のセッションか」を見る。
#   EPIC_DISPATCH_PARENT_EPIC が空でなければ（並列起動された子のセッション）orca を呼ばずに `nested`。
#   空でも、`orca worktree current --json` の parentWorktreeId があり、`orca worktree list --json` の
#   そのワークツリーに linkedIssue があれば（子のワークツリーで起動し直したセッション）`nested`。
#   `nested` のときは stderr に `parent epic: #<N>`（環境変数の値か、親の linkedIssue）。
#   jq が無い・一覧を読めないときは子ではないとして進み、stderr に `could not read the parent worktree`。
#   子でなければ、子が 1 件以上・`orca worktree current --json` が exit 0（今いるのが Orca 管理の
#   ワークツリー）なら stdout に `orca`、それ以外（子 0 件を含む）は `subagent`。どれも exit 0。current は 1 回だけ呼ぶ
# launch: `orca worktree current --json` → `git rev-parse --show-toplevel` → `git fetch origin <base>`
#   → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` →
#   子ごとに `orca worktree create`（同じ repoId・同じ linkedIssue・archive されていない
#   ワークツリーがあれば作らない。--agent も --prompt も渡さない。create は空のシェルの端末を 1 つ作るので、
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
#   （send の stages に turn_started がある）/ `skipped <N>` / `failed <N>` の 1 行。failed で
#   ハンドルが取れていれば送り直しのコマンドを stderr に出す。orca 自身の出力は stderr。
#   <base> の既定は main（EPIC_DISPATCH_BASE、--base が優先）。起動完了待ちの上限（ミリ秒）と
#   送信の観測時間（秒）の既定は 60000 / 30（EPIC_DISPATCH_READY_TIMEOUT_MS / EPIC_DISPATCH_SUBMIT_WAIT）
#   exit 0 = failed なし / 1 = failed あり、または orca・jq が無い・current / fetch / set / list の
#   失敗（このときは子を 1 件も作らない）
#   EPIC_DISPATCH_PARENT_EPIC が空でなければ、引数の検査のあと orca も git も呼ばずに
#   stderr に理由を出して exit 1（子ワークツリーを作らない）。空でも、current --json の直後に route と
#   同じ親子関係の判定をし、子なら git も set も create も呼ばずに exit 1
#   （どちらの理由も `child epics are not expanded here` を含む）。parentWorktreeId があるのに一覧を
#   読めないときも、git も set も create も呼ばずに exit 1（stderr に `could not read the parent worktree`）
# wait: 子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` を見るポーリングを繰り返し、
#   stdout にちょうど 1 行を出して終わる。
#   `closed <N>...`（閉じていた子）exit 0 / `timeout <N>...`（閉じていない子）exit 2 /
#   `error gh <N>...`（失敗したポーリングが 3 回続いた。3 回目で失敗した子）exit 1
#   失敗したポーリング = 1 件以上の子が失敗（gh が非 0、または出力が open / closed 以外）し、
#   閉じた子が 1 件も無いポーリング。失敗の無いポーリングで数え直す。
#   間隔・上限は秒。既定 300 / 21600（EPIC_DISPATCH_INTERVAL / EPIC_DISPATCH_TIMEOUT、フラグが優先）。
#   ポーリングのあとで「経過 >= 上限」か「経過 + 間隔 > 上限」なら眠らずに timeout
#   （--timeout 0 は間隔によらず 1 回だけ確かめる）
#   --watch-done <N> を 1 つ以上付けたときだけ、ポーリングごとに `orca worktree list --json` を 1 回呼び、
#   同じ repoId・linkedIssue が <N>・archive されていない・workspaceStatus が completed のワークツリーが
#   あれば「印が付いた」とする。閉じた子・印が付いた子がいれば `closed <N>...` と `done <N>...` を
#   この順に（1 行か 2 行）出して exit 0。一覧を読めないポーリングも失敗したポーリングに数え、
#   3 回続いて gh の失敗が無ければ `error workspaces`。位置引数 0 件も可（timeout は `timeout` だけ）。
#   --watch-stopped（値なし）を付け、位置引数の子が 1 件以上あるときは、同じ一覧で、閉じていない位置引数の
#   子のうち同じ repoId・linkedIssue が <N>・archive されていない・comment が epic-stopped のワークツリー
#   全部に `orca worktree set --worktree path:<パス> --comment epic-stopped-seen` を呼び、全部 exit 0 なら
#   「止まった子」とする（1 つでも失敗すれば失敗したポーリングに数える）。出力は `closed <N>...`・
#   `done <N>...`・`stopped <N>...` を該当するものだけこの順に（1〜3 行）出して exit 0。
#   --watch-done も --watch-stopped（子 1 件以上）も無ければ orca を呼ばず、コメント欄も見ない。
#   --resolve <epic>（--watch-stopped と位置引数の子が 1 件以上あるときだけ働く）を付けると、止まった子ごとに
#   判断のコマンド（EPIC_DISPATCH_JUDGE。既定は同じディレクトリの stop-judge.sh）を `<epic> <child>` で 1 回呼ぶ。
#   `判断: 通す` で返事が空でなければ reply --as parent と同じ処理で送り、sent / relaunched ならエピックに
#   `親の判断: 子 #<N> 通した — <理由> <記録>` を投稿して出力から外す（投稿に失敗したら `unrecorded` に入れ、
#   stderr に投稿し直しのコマンド）。`判断: 主に上げる` は子 issue に `親の判断: 主に上げる`、判断の失敗・
#   形の崩れは `親の判断: 判断できなかった`、通すで送信の失敗は `親の判断: 通すが送れなかった` を、2 行目 `停止の記録: <URL か 不明>` 付きで投稿して
#   `stopped` に残す（投稿に失敗したら stderr に投稿し直しのコマンド）。出力は closed / done / stopped /
#   unrecorded の順の 1〜4 行。--resolve が無ければ判断を呼ばず、unrecorded も出さない。
#   --resolve の値が無い・数字でない、または返事の送り方の環境変数が誤っていれば使い方を出して exit 1
#   orca / jq が無い・`orca worktree current` が失敗したら stdout に何も出さず exit 1
# reply: 今のワークツリーと同じ repoId・linkedIssue が <child>・archive されていない子のワークツリーが 1 件で、
#   端末があり（--relaunch なし）、子のセッションの端末（agentIdentity が claude の端末、無ければタイトルに
#   Claude Code を含む端末がちょうど 1 つ）が決まれば、頭（--as parent は `親エピック #<epic> の判断（主の承認ではない）: `、
#   owner は `主の返事（親エピック #<epic> 経由）: `）を付けた文を送り、ターンの開始まで確かめて `sent <child>`。
#   端末が 0 か --relaunch なら（--relaunch は先に端末を全部閉じて）launch と同じ起動コマンドで端末を作り、
#   `/develop #<child> （エピック #<epic> の子。返事を受けて起動し直し） <頭付きの文>` を送って `relaunched <child>`。
#   端末はあるが子のセッションの端末を決められない（シェルの端末だけも含む）
#   ときは `failed <child> ambiguous-terminal`。ワークツリーが 0 件か 2 件以上・送信 / 作成 / 閉じるの失敗は `failed <child> <段>` で exit 1
#   （送り直しか作り直しのコマンドを stderr に出す）。引数の誤りは orca を呼ばずに使い方を出して exit 1
# mark: 今のワークスペースの linkedIssue が <issue> のときだけ `orca worktree set --worktree current
#   --workspace-status <completed|in-review>`（done / waiting）。stdout は `marked <issue> <kind>`（exit 0）
#   / `failed <issue>`（exit 1）/ `skipped <issue> not-linked` / `skipped <issue> no-workspace`
#   （orca が無いか Orca 管理外。exit 0）。EPIC_DISPATCH_PARENT_EPIC は見ない。
#   stopped / resumed は列に触れず `orca worktree set --worktree current --comment <epic-stopped|epic-resumed>`
#   を 1 回呼ぶ。resumed は今の comment が epic-stopped / epic-stopped-seen のときだけ付け、
#   それ以外は set を呼ばずに `skipped <issue> not-stopped`（exit 0）
# reap: 子ごとに、一覧の候補 1 件・親の launch が作った（parentWorktreeId が今のワークツリーの id）・
#   completed・git status がきれい・LLM/ が無い・ブランチ上・マージ済み PR の headRefOid と HEAD が一致
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
#   `reaped <N>` / `reaped <N> branch-kept` / `gone <N>` / `kept <N> <理由>` の 1 行で exit 0。
#   current / list を読めなければ何も消さず stdout 空で exit 1。EPIC_DISPATCH_PARENT_EPIC は見ない
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
# 「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」が正本。
set -uo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  epic-dispatch.sh route <child>...
  epic-dispatch.sh launch [--note <text>] [--base <branch>] <epic> <child>...
  epic-dispatch.sh reply [--relaunch] --as <parent|owner> <epic> <child> <text>
  epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] [--watch-done <child>]... [--watch-stopped] [--resolve <epic>] [<child>...]
  epic-dispatch.sh mark <done|waiting|stopped|resumed> <issue>
  epic-dispatch.sh reap <child>...
EOF
  exit 1
}

is_num() { [[ "$1" =~ ^[0-9]+$ ]]; }

# 子の番号がすべて数字であることを確かめる（1 件でも違えば使い方を出して exit 1）
check_children() {
  local n
  for n in "$@"; do
    is_num "$n" || { echo "not an issue number: $n" >&2; usage; }
  done
}

# 今のワークツリーが、issue の付いた親ワークツリーを持つ（親の launch が作った子）なら、
# 親の linkedIssue を stdout に出す。そうでなければ何も出さない
# （<orca worktree current --json の出力>）。親を読めないときは stderr に理由を出し、何も出さない。
# 一覧は親があるときだけ読む。親があるのに一覧を読めなかったときだけ exit 1 を返す
# （route は戻り値を見ずに子ではないとして進み、launch は止まる）
parent_from_worktree() {
  local pid list
  command -v jq >/dev/null 2>&1 || { echo "could not read the parent worktree (jq is not on PATH)" >&2; return 0; }
  pid="$(printf '%s' "$1" | jq -r '.result.worktree.parentWorktreeId // empty' 2>/dev/null)"
  [ -n "$pid" ] || return 0
  if ! list="$(orca worktree list --json)" \
    || ! printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1; then
    echo "could not read the parent worktree (orca worktree list --json)" >&2
    return 1
  fi
  printf '%s' "$list" | jq -r --arg p "$pid" \
    '[.result.worktrees[] | select(.id == $p) | .linkedIssue | select(. != null)][0] // empty'
}

cmd_route() {
  check_children "$@"
  # 並列起動された子のセッション（起動し直したものを含む）の中では、エピックをさらに展開しない。
  # 端末に付けた環境変数か、ワークツリーの親子関係のどちらかで判定する
  local epic="${EPIC_DISPATCH_PARENT_EPIC-}" current managed=0
  if [ -z "$epic" ] && command -v orca >/dev/null 2>&1 \
    && current="$(orca worktree current --json 2>/dev/null)"; then
    managed=1
    epic="$(parent_from_worktree "$current")"
  fi
  if [ -n "$epic" ]; then
    echo "parent epic: #$epic" >&2
    echo nested
    return 0
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
ready=""; submit=""; agent_cmd=""
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
  agent_cmd="EPIC_DISPATCH_PARENT_EPIC=$1 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=$idle_compact $claude_cmd --model $(shq "$model")"
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

cmd_launch() {
  local note="" base="${EPIC_DISPATCH_BASE:-main}"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --note) [ "$#" -ge 2 ] || usage; note="$2"; shift 2 ;;
      --base) [ -n "${2-}" ] || usage; base="$2"; shift 2 ;;
      --*) usage ;;
      *) break ;;
    esac
  done
  [ "$#" -ge 2 ] || usage
  local epic="$1"; shift
  is_num "$epic" || { echo "not an issue number: $epic" >&2; usage; }
  check_children "$@"
  agent_setup "$epic" || usage
  if [ -n "${EPIC_DISPATCH_PARENT_EPIC-}" ]; then
    echo "this session is a child of epic #$EPIC_DISPATCH_PARENT_EPIC (EPIC_DISPATCH_PARENT_EPIC); child epics are not expanded here" >&2
    exit 1
  fi

  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH" >&2; exit 1; }

  local current repo parent list
  current="$(orca worktree current --json)" || { echo "not in an Orca-managed worktree" >&2; exit 1; }
  repo="$(printf '%s' "$current" | jq -r '.result.worktree.repoId // empty')"
  [ -n "$repo" ] || { echo "orca worktree current --json has no repoId" >&2; exit 1; }
  # 起動し直した子のセッション（環境変数が無い）でも、子ワークツリーを作らず、今のワークツリーの issue も書き換えない。
  # 親があるのに一覧を読めないときは子かどうかを決められないので、fetch と set より前のここで止まる
  # （先へ進むと、子のワークツリーの issue をエピック番号で書き換えてから止まることになる）
  local parent_epic
  parent_epic="$(parent_from_worktree "$current")" || exit 1
  if [ -n "$parent_epic" ]; then
    echo "this session is a child of epic #$parent_epic (parent worktree); child epics are not expanded here" >&2
    exit 1
  fi
  parent="$(git rev-parse --show-toplevel)" || { echo "git rev-parse failed" >&2; exit 1; }
  git fetch origin "$base" >&2 || { echo "git fetch origin $base failed" >&2; exit 1; }
  orca worktree set --worktree "path:$parent" --issue "$epic" >&2 \
    || { echo "orca worktree set failed" >&2; exit 1; }
  list="$(orca worktree list --json)" || { echo "orca worktree list failed" >&2; exit 1; }
  printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1 \
    || { echo "orca worktree list --json is not readable" >&2; exit 1; }

  local n prompt body out rc child handle sent retry failed=0 seen=" "
  for n in "$@"; do
    case "$seen" in
      *" $n "*) echo "skipped $n"; continue ;;
    esac
    seen="$seen$n "
    if printf '%s' "$list" | jq -e --arg r "$repo" --arg n "$n" \
      'any(.result.worktrees[]; .repoId == $r and (.linkedIssue | tostring) == $n and .isArchived != true)' \
      >/dev/null 2>&1; then
      echo "skipped $n"
      continue
    fi
    prompt="/develop #$n （エピック #$epic の子。親ワークツリー $parent から Orca で起動）"
    [ -n "$note" ] && prompt="$prompt $note"
    out="$(orca worktree create --name "issue-$n" --issue "$n" --base-branch "origin/$base" \
      --parent-worktree "path:$parent" --json)"
    rc=$?
    printf '%s\n' "$out" >&2
    if [ "$rc" -ne 0 ]; then
      echo "failed $n"; failed=1; continue
    fi
    # 注意書きを子 issue に残す（起動し直したセッションにも届く）。このあとの失敗でワークツリーが
    # 残れば次の launch では skipped になるので、端末より前に投稿する。失敗しても起動は続ける
    if [ -n "$note" ]; then
      body="$(printf '親エピックからの注意書き: #%s\n\n%s' "$epic" "$note")"
      if ! gh issue comment "$n" --body "$body" >&2; then
        echo "note not posted to #$n. post it with the command below:" >&2
        echo "gh issue comment $n --body $(shq "$body")" >&2
      fi
    fi
    child="$(printf '%s' "$out" | jq -r '.result.worktree.path // empty' 2>/dev/null)"
    if [ -z "$child" ]; then
      echo "no worktree path for #$n in orca worktree create --json" >&2
      echo "failed $n"; failed=1; continue
    fi
    # worktree create が空のシェルの端末を 1 つ作っていれば、新しい端末は作らずそこで起動する
    # （端末が 2 つになると reply が ambiguous-terminal で止まる）。0 個なら従来どおり作る
    handle=""; shell_rc=0
    shell_start "$child" "$agent_cmd" || shell_rc=$?
    if [ "$shell_rc" -eq 0 ]; then
      handle="$SHELL_HANDLE"
    elif [ "$shell_rc" -eq 3 ]; then
      echo "failed $n"; failed=1; continue
    else
      out="$(orca terminal create --worktree "path:$child" --command "$agent_cmd" --json)"
      rc=$?
      printf '%s\n' "$out" >&2
      [ "$rc" -eq 0 ] && handle="$(printf '%s' "$out" | jq -r '.result.terminal.handle // empty' 2>/dev/null)"
    fi
    if [ -z "$handle" ]; then
      echo "no terminal handle for #$n from orca terminal create --json" >&2
      recreate_hint "$child" "$agent_cmd" "$prompt" "$submit"
      echo "failed $n"; failed=1; continue
    fi
    if ! orca terminal wait --terminal "$handle" --for tui-idle --timeout-ms "$ready" --json >&2; then
      resend_hint "$handle" "$prompt" "$submit"
      echo "failed $n"; failed=1; continue
    fi
    sent="$(orca terminal send --terminal "$handle" --text "$prompt" --enter --wait-submit "$submit" --json)"
    rc=$?
    printf '%s\n' "$sent" >&2
    if [ "$rc" -eq 0 ] && turn_started "$sent"; then
      echo "launched $n"
    else
      retry="$(retry_id "$sent")"
      resend_hint "$handle" "$prompt" "$submit" "$retry"
      echo "failed $n"; failed=1
    fi
  done
  exit "$failed"
}

# 子の端末に、送り手を付けた返事を届ける（<relaunch 0|1> <parent|owner> <epic> <child> <text> <repoId>）。
# agent_setup を済ませてから呼ぶ。stdout に `sent <child>` / `relaunched <child>` / `failed <child> <理由>` の
# 1 行を出し、failed なら 1 を返す。orca 自身の出力は stderr。reply と wait --resolve が共用する
deliver_reply() {
  local relaunch="$1" as="$2" epic="$3" n="$4" text="$5" repo="$6"
  local msg list cands count path terms tcount handle out rc sent prompt
  case "$as" in
    parent) msg="親エピック #$epic の判断（主の承認ではない）: $text" ;;
    *) msg="主の返事（親エピック #$epic 経由）: $text" ;;
  esac
  if ! list="$(orca worktree list --json)" \
    || ! printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1; then
    echo "orca worktree list --json is not readable" >&2
    echo "failed $n list"; return 1
  fi
  cands="$(printf '%s' "$list" | jq -c --arg r "$repo" --arg n "$n" \
    '[.result.worktrees[] | select(.repoId == $r and (.linkedIssue | tostring) == $n and .isArchived != true)]')"
  count="$(printf '%s' "$cands" | jq 'length')"
  [ "$count" -eq 0 ] && { echo "failed $n no-worktree"; return 1; }
  [ "$count" -gt 1 ] && { echo "failed $n ambiguous-worktree"; return 1; }
  path="$(printf '%s' "$cands" | jq -r '.[0].path // empty')"
  [ -n "$path" ] || { echo "failed $n no-worktree"; return 1; }
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
  prompt="/develop #$n （エピック #$epic の子。返事を受けて起動し直し） $msg"
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
  is_num "$2" || { echo "not an issue number: $2" >&2; usage; }
  [ -n "$3" ] || { echo "the reply text must not be empty" >&2; usage; }
  agent_setup "$1" || usage
  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH" >&2; exit 1; }
  local current repo
  current="$(orca worktree current --json)" || { echo "not in an Orca-managed worktree" >&2; exit 1; }
  repo="$(printf '%s' "$current" | jq -r '.result.worktree.repoId // empty' 2>/dev/null)"
  [ -n "$repo" ] || { echo "orca worktree current --json has no repoId" >&2; exit 1; }
  deliver_reply "$relaunch" "$as" "$1" "$2" "$3" "$repo" || exit 1
  exit 0
}

# 今いるワークスペースに印を付ける（done = completed / waiting = in-review は列、
# stopped = epic-stopped / resumed = epic-resumed はコメント欄）。
# 今のワークスペースの linkedIssue が <issue> と一致するときだけ付ける
cmd_mark() {
  [ "$#" -eq 2 ] || usage
  local kind="$1" n="$2" status="" comment=""
  case "$kind" in
    done) status=completed ;;
    waiting) status=in-review ;;
    stopped) comment="epic-stopped" ;;
    resumed) comment="epic-resumed" ;;
    *) usage ;;
  esac
  is_num "$n" || { echo "not an issue number: $n" >&2; usage; }
  local current linked
  if ! command -v orca >/dev/null 2>&1 || ! current="$(orca worktree current --json)"; then
    echo "skipped $n no-workspace"
    return 0
  fi
  linked="$(printf '%s' "$current" | jq -r '.result.worktree.linkedIssue // empty | tostring' 2>/dev/null)"
  if [ "$linked" != "$n" ]; then
    echo "this workspace is linked to '${linked}', not #$n" >&2
    echo "skipped $n not-linked"
    return 0
  fi
  # 再開の印は、止まった印（受けた印を含む）があるときだけ付ける
  if [ "$kind" = resumed ]; then
    case "$(printf '%s' "$current" | jq -r '.result.worktree.comment // empty' 2>/dev/null)" in
      epic-stopped|epic-stopped-seen) ;;
      *) echo "skipped $n not-stopped"; return 0 ;;
    esac
  fi
  local rc
  if [ -n "$comment" ]; then
    orca worktree set --worktree current --comment "$comment" >&2; rc=$?
  else
    orca worktree set --worktree current --workspace-status "$status" >&2; rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    echo "marked $n $kind"
    return 0
  fi
  echo "failed $n"
  exit 1
}

# 投稿に失敗したコメントの、投稿し直しのコマンドを stderr に出す（<issue> <本文>）
repost_hint() {
  echo "comment not posted to #$1. post it again: gh issue comment $1 --body $(shq "$2")" >&2
}

# wait --resolve: 止まった子 1 件を判断のコマンドに渡し、結果どおりに送るか子 issue に残す
# （<epic> <child> <repoId>）。agent_setup を済ませてから呼ぶ。
# 戻り値 0 = 通して返事を送り、エピックに 1 行残した（出力から外す）/ 2 = 通して送ったが
# エピックに残せなかった（unrecorded）/ 1 = 主に上げる・判断できなかった（stopped に残す）
resolve_stopped() {
  local epic="$1" n="$2" repo="$3"
  local judge="${EPIC_DISPATCH_JUDGE:-$(dirname "$0")/stop-judge.sh}"
  local out rc l1 l2 l3 l4 reason="" reply="" url="" why="" res line body
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
    gh issue comment "$n" --body "$body" >&2 || repost_hint "$n" "$body"
    return 1
  elif [ "$l1" != "判断: 通す" ]; then
    why="判断の出力の 1 行目が「判断: 通す」でも「判断: 主に上げる」でもない"
  elif [ -z "$reply" ]; then
    why="判断は通すだが、返事の行が空"
  else
    res="$(deliver_reply 0 parent "$epic" "$n" "$reply" "$repo")"
    case "$res" in
      "sent $n"|"relaunched $n")
        # エピックへの記録は送れたあとに残す（送る前に残すと、送れなかったときに通していない判断が残る）
        line="親の判断: 子 #$n 通した — $reason $url"
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
  gh issue comment "$n" --body "$body" >&2 || repost_hint "$n" "$body"
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
        is_num "$2" || { echo "--watch-done needs an issue number: $2" >&2; usage; }
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
  if [ -n "$resolve" ]; then agent_setup "$resolve" || usage; fi

  local repo="" current list
  if [ -n "$watch" ] || [ "$watchstop" -eq 1 ]; then
    command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH (needed by --watch-done / --watch-stopped)" >&2; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH (needed by --watch-done / --watch-stopped)" >&2; exit 1; }
    current="$(orca worktree current --json)" || { echo "not in an Orca-managed worktree" >&2; exit 1; }
    repo="$(printf '%s' "$current" | jq -r '.result.worktree.repoId // empty' 2>/dev/null)"
    [ -n "$repo" ] || { echo "orca worktree current --json has no repoId" >&2; exit 1; }
  fi

  local fails=0 n state closed failed marked stopped wsfail paths p ok unrecorded still
  local errf; errf="$(mktemp)"; trap 'rm -f "$errf"' EXIT
  SECONDS=0
  while :; do
    closed=""; failed=""; marked=""; stopped=""; unrecorded=""; wsfail=0; : > "$errf"
    for n in "$@"; do
      if state="$(gh api "repos/{owner}/{repo}/issues/$n" --jq .state 2>>"$errf")"; then
        case "$state" in
          closed) closed="$closed $n" ;;
          open) ;;
          *) failed="$failed $n" ;;
        esac
      else
        failed="$failed $n"
      fi
    done
    # 完了の印と止まった印は、ポーリングごとに 1 回の一覧で全部の子を見る
    if [ -n "$watch" ] || [ "$watchstop" -eq 1 ]; then
      if list="$(orca worktree list --json 2>>"$errf")" \
        && printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1; then
        for n in $watch; do
          if printf '%s' "$list" | jq -e --arg r "$repo" --arg n "$n" \
            'any(.result.worktrees[]; .repoId == $r and (.linkedIssue | tostring) == $n
              and .isArchived != true and .workspaceStatus == "completed")' >/dev/null 2>&1; then
            marked="$marked $n"
          fi
        done
        # 止まった印（epic-stopped）は、閉じていない位置引数の子だけを、受けた印に書き換えてから数える
        if [ "$watchstop" -eq 1 ]; then
          for n in "$@"; do
            case " $closed $stopped " in *" $n "*) continue ;; esac
            paths="$(printf '%s' "$list" | jq -r --arg r "$repo" --arg n "$n" \
              '.result.worktrees[] | select(.repoId == $r and (.linkedIssue | tostring) == $n
                and .isArchived != true and .comment == "epic-stopped") | .path' 2>/dev/null)"
            [ -n "$paths" ] || continue
            ok=1
            while IFS= read -r p; do
              [ -n "$p" ] || continue
              orca worktree set --worktree "path:$p" --comment epic-stopped-seen >&2 || ok=0
            done <<EOF_PATHS
$paths
EOF_PATHS
            if [ "$ok" -eq 1 ]; then
              stopped="$stopped $n"
            else
              wsfail=1
            fi
          done
        fi
      else
        wsfail=1
      fi
    fi
    # --resolve: 止まった子ごとに判断し、通して記録できた子は出力から外す
    if [ -n "$resolve" ] && [ -n "$stopped" ]; then
      still=""
      for n in $stopped; do
        resolve_stopped "$resolve" "$n" "$repo"
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

# 完了の印が付き、安全確認を全部通った子だけ、端末を閉じてワークツリーとローカルブランチを消す。
# 子ごとに stdout へ 1 行（reaped / reaped branch-kept / gone / kept <理由>）
cmd_reap() {
  [ "$#" -ge 1 ] || usage
  check_children "$@"
  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH" >&2; exit 1; }
  local current repo self list
  current="$(orca worktree current --json)" || { echo "not in an Orca-managed worktree" >&2; exit 1; }
  repo="$(printf '%s' "$current" | jq -r '.result.worktree.repoId // empty' 2>/dev/null)"
  self="$(printf '%s' "$current" | jq -r '.result.worktree.id // empty' 2>/dev/null)"
  [ -n "$repo" ] && [ -n "$self" ] || { echo "orca worktree current --json has no repoId or id" >&2; exit 1; }
  list="$(orca worktree list --json)" || { echo "orca worktree list failed" >&2; exit 1; }
  printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1 \
    || { echo "orca worktree list --json is not readable" >&2; exit 1; }

  local n cands count w path ref branch st head heads sheads rmerr tip seen=" "
  local legacy allprs istate lsout btip="" base_looked=0 base_fetched=0 base="${EPIC_DISPATCH_BASE:-main}"
  for n in "$@"; do
    case "$seen" in *" $n "*) continue ;; esac
    seen="$seen$n "
    cands="$(printf '%s' "$list" | jq -c --arg r "$repo" --arg n "$n" \
      '[.result.worktrees[] | select(.repoId == $r and (.linkedIssue | tostring) == $n and .isArchived != true)]')"
    count="$(printf '%s' "$cands" | jq 'length')"
    [ "$count" -eq 0 ] && { echo "gone $n"; continue; }
    [ "$count" -gt 1 ] && { echo "kept $n ambiguous"; continue; }
    w="$(printf '%s' "$cands" | jq -c '.[0]')"
    if ! printf '%s' "$w" | jq -e --arg p "$self" '.isMainWorktree != true and .parentWorktreeId == $p' >/dev/null 2>&1; then
      echo "kept $n not-child"; continue
    fi
    if ! printf '%s' "$w" | jq -e '.workspaceStatus == "completed"' >/dev/null 2>&1; then
      echo "kept $n not-done"; continue
    fi
    path="$(printf '%s' "$w" | jq -r '.path // empty')"
    [ -n "$path" ] || { echo "kept $n git-failed"; continue; }
    st="$(git -C "$path" status --porcelain)" || { echo "kept $n git-failed"; continue; }
    [ -z "$st" ] || { echo "kept $n dirty"; continue; }
    [ ! -e "$path/LLM" ] || { echo "kept $n llm-logs"; continue; }
    ref="$(printf '%s' "$w" | jq -r '.branch // empty')"
    case "$ref" in
      refs/heads/?*) branch="${ref#refs/heads/}" ;;
      *) echo "kept $n no-branch"; continue ;;
    esac
    head="$(git -C "$path" rev-parse HEAD)" || head=""
    heads="$(gh pr list --head "$branch" --state merged --json headRefOid --jq '.[].headRefOid')" \
      || { echo "kept $n pr-lookup-failed"; continue; }
    if [ -z "$head" ] || ! printf '%s\n' "$heads" | grep -qxF -- "$head"; then
      # squash マージでは別名のブランチの PR で入ることがある。HEAD を先端に持つマージ済み PR を
      # ブランチ名を問わず探す（最終判定は headRefOid と HEAD の完全一致のまま）
      sheads=""
      if [ -n "$head" ]; then
        sheads="$(gh pr list --state merged --search "$head" --json headRefOid --jq '.[].headRefOid')" \
          || { echo "kept $n pr-lookup-failed"; continue; }
      fi
      if [ -z "$head" ] || ! printf '%s\n' "$sheads" | grep -qxF -- "$head"; then
        legacy="head-mismatch"
        if [ -z "$heads" ] && [ -z "$sheads" ]; then legacy="no-merged-pr"; fi
        # PR が 1 件も無く issue が閉じた子（PR を伴わない記録先）は、HEAD がリモートの今の base に
        # 含まれるときだけ片付ける。判定の相手は手元の追跡参照ではなく ls-remote で取った今の先端
        [ -n "$head" ] || { echo "kept $n $legacy"; continue; }
        allprs="$(gh pr list --head "$branch" --state all --json number --jq '.[].number')" \
          || { echo "kept $n pr-lookup-failed"; continue; }
        [ -z "$allprs" ] || { echo "kept $n $legacy"; continue; }
        istate="$(gh api "repos/{owner}/{repo}/issues/$n" --jq .state)" \
          || { echo "kept $n issue-lookup-failed"; continue; }
        [ "$istate" = closed ] || { echo "kept $n $legacy"; continue; }
        if [ "$base_looked" -eq 0 ]; then
          base_looked=1
          if lsout="$(git ls-remote origin "refs/heads/$base")"; then
            btip="$(printf '%s\n' "$lsout" | awk 'NR==1{print $1}')"
            case "$btip" in
              *[!0-9a-f]*) btip="" ;;
              *) [ "${#btip}" -eq 40 ] || btip="" ;;
            esac
          fi
        fi
        [ -n "$btip" ] || { echo "kept $n base-lookup-failed"; continue; }
        if ! git cat-file -e "$btip^{commit}" >&2; then
          if [ "$base_fetched" -eq 0 ]; then
            base_fetched=1
            git fetch origin "$base" >&2 || true
          fi
          git cat-file -e "$btip^{commit}" >&2 || { echo "kept $n base-lookup-failed"; continue; }
        fi
        git -C "$path" merge-base --is-ancestor "$head" "$btip" >&2
        case "$?" in
          0) ;;
          1) echo "kept $n unmerged-commits"; continue ;;
          *) echo "kept $n git-failed"; continue ;;
        esac
      fi
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
    if tip="$(git rev-parse --verify --quiet "refs/heads/$branch")"; then
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
          if wtl="$(git worktree list --porcelain)" && ! printf '%s\n' "$wtl" | grep -qxF -- "worktree $path"; then
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
        && tip2="$(git rev-parse --verify --quiet "refs/heads/$branch")" && [ "$tip2" = "$head" ] \
        && git branch -D "$branch" >&2; then
        echo "reaped $n"
      else
        echo "reaped $n branch-kept"
      fi
    else
      echo "reaped $n"
    fi
  done
  exit 0
}

[ "$#" -ge 1 ] || usage
sub="$1"; shift
case "$sub" in
  route) cmd_route "$@" ;;
  launch) cmd_launch "$@" ;;
  reply) cmd_reply "$@" ;;
  wait) cmd_wait "$@" ;;
  mark) cmd_mark "$@" ;;
  reap) cmd_reap "$@" ;;
  *) usage ;;
esac
