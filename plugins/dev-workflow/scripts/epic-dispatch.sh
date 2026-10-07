#!/usr/bin/env bash
# エピックの子の経路判定・起動・待ち受けを LLM なしで行う。develop の本体（エピックの解決
# セッション）が SKILL.md「エピックの扱い」→「回し方」の手順どおりに呼ぶ。
#
#   epic-dispatch.sh route <child>...
#   epic-dispatch.sh launch [--note <text>] [--base <branch>] <epic> <child>...
#   epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] [--watch-done <child>]... [<child>...]
#   epic-dispatch.sh mark <done|waiting> <issue>
#   epic-dispatch.sh reap <child>...
#
# Orca のコマンドを呼ぶのはこのスクリプトだけ（develop の手順書には orca のコマンドを書かない）。
# route: 子が 2 件以上・`orca` が PATH にある・`orca worktree current` が exit 0（今いるのが
#   Orca 管理のワークツリー）のすべてが成り立てば stdout に `orca`、それ以外は `subagent`。exit 0
#   EPIC_DISPATCH_PARENT_EPIC が空でなければ（並列起動された子のセッション）、子の番号の検査のあと
#   orca を呼ばずに `nested`。exit 0
# launch: `orca worktree current --json` → `git rev-parse --show-toplevel` → `git fetch origin <base>`
#   → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` →
#   子ごとに `orca worktree create`（同じ repoId・同じ linkedIssue・archive されていない
#   ワークツリーがあれば作らない。--agent も --prompt も渡さない）→ `orca terminal create
#   --worktree path:<子> --command "EPIC_DISPATCH_PARENT_EPIC=<epic> <cmd> --model <model>"`
#   （<cmd> の既定は cld、EPIC_DISPATCH_CLAUDE_CMD で変える。<model> の既定は opus、
#   EPIC_DISPATCH_MODEL で変える。どちらも空なら使い方を出して exit 1。
#   作れなければ作り直しと送信のコマンドを stderr に出す）→ `orca terminal wait --for tui-idle` →
#   `orca terminal send --text <指示> --enter --wait-submit <秒>`。stdout は子ごとに `launched <N>`
#   （send の stages に turn_started がある）/ `skipped <N>` / `failed <N>` の 1 行。failed で
#   ハンドルが取れていれば送り直しのコマンドを stderr に出す。orca 自身の出力は stderr。
#   <base> の既定は main（EPIC_DISPATCH_BASE、--base が優先）。起動完了待ちの上限（ミリ秒）と
#   送信の観測時間（秒）の既定は 60000 / 30（EPIC_DISPATCH_READY_TIMEOUT_MS / EPIC_DISPATCH_SUBMIT_WAIT）
#   exit 0 = failed なし / 1 = failed あり、または orca・jq が無い・current / fetch / set / list の
#   失敗（このときは子を 1 件も作らない）
#   EPIC_DISPATCH_PARENT_EPIC が空でなければ、引数の検査のあと orca も git も呼ばずに
#   stderr に理由を出して exit 1（子ワークツリーを作らない）
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
#   orca / jq が無い・`orca worktree current` が失敗したら stdout に何も出さず exit 1
# mark: 今のワークスペースの linkedIssue が <issue> のときだけ `orca worktree set --worktree current
#   --workspace-status <completed|in-review>`（done / waiting）。stdout は `marked <issue> <kind>`（exit 0）
#   / `failed <issue>`（exit 1）/ `skipped <issue> not-linked` / `skipped <issue> no-workspace`
#   （orca が無いか Orca 管理外。exit 0）。EPIC_DISPATCH_PARENT_EPIC は見ない
# reap: 子ごとに、一覧の候補 1 件・親の launch が作った（parentWorktreeId が今のワークツリーの id）・
#   completed・git status がきれい・LLM/ が無い・ブランチ上・マージ済み PR の headRefOid と HEAD が一致、
#   の順に確かめ、全部通れば `orca terminal close --all` → `orca worktree rm`（--force なし）→
#   残ったローカルブランチは先端が HEAD と同じときだけ `git branch -D`。stdout は子ごとに
#   `reaped <N>` / `reaped <N> branch-kept` / `gone <N>` / `kept <N> <理由>` の 1 行で exit 0。
#   current / list を読めなければ何も消さず stdout 空で exit 1。EPIC_DISPATCH_PARENT_EPIC は見ない
# 引数の誤り（launch は epic か子が無い、wait は子も --watch-done も 0 件、mark の種別・引数の数、
#   reap は子が 0 件、番号が数字でない、フラグ値の誤り）は
#   stderr に使い方を出して exit 1。route は子 0 件でも subagent。
#
# 設計と守備範囲（引数を渡すのは本体で、人が手で打つことは想定しない）は
# openspec の dev-workflow-develop spec「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを
# LLM なしで行う」と「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」が正本。
set -uo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  epic-dispatch.sh route <child>...
  epic-dispatch.sh launch [--note <text>] [--base <branch>] <epic> <child>...
  epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] [--watch-done <child>]... [<child>...]
  epic-dispatch.sh mark <done|waiting> <issue>
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

cmd_route() {
  check_children "$@"
  # 並列起動された子のセッションの中では、エピックをさらに展開しない
  if [ -n "${EPIC_DISPATCH_PARENT_EPIC-}" ]; then
    echo nested
    return 0
  fi
  if [ "$#" -ge 2 ] && command -v orca >/dev/null 2>&1 \
    && orca worktree current >/dev/null 2>&1; then
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
  cmd="orca terminal send --terminal $1 --text $(shq "$2") --enter --wait-submit $3 --json"
  [ -n "${4-}" ] && cmd="$cmd --retry-request $4"
  {
    echo "the first prompt may not have reached terminal $1."
    echo "check the input line and whether a turn started before resending: orca terminal read --terminal $1"
    echo "resend: $cmd"
  } >&2
}

# 端末を作れなかった子の、端末の作り直しと最初の指示の送信のコマンドを stderr に出す
# （<子のパス> <起動コマンド> <prompt> <submit>）
recreate_hint() {
  {
    echo "no agent terminal was started in $1 (relaunching launch skips this child)."
    echo "create: orca terminal create --worktree path:$1 --command $(shq "$2") --json"
    echo "then send: orca terminal send --terminal <handle from create> --text $(shq "$3") --enter --wait-submit $4 --json"
  } >&2
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
  local ready="${EPIC_DISPATCH_READY_TIMEOUT_MS:-60000}" submit="${EPIC_DISPATCH_SUBMIT_WAIT:-30}"
  is_num "$ready" || { echo "EPIC_DISPATCH_READY_TIMEOUT_MS must be a non-negative integer: $ready" >&2; usage; }
  is_num "$submit" || { echo "EPIC_DISPATCH_SUBMIT_WAIT must be a non-negative integer: $submit" >&2; usage; }
  local model="${EPIC_DISPATCH_MODEL-opus}"
  [ -n "$model" ] || { echo "EPIC_DISPATCH_MODEL must not be empty" >&2; usage; }
  local claude_cmd="${EPIC_DISPATCH_CLAUDE_CMD-cld}"
  [ -n "$claude_cmd" ] || { echo "EPIC_DISPATCH_CLAUDE_CMD must not be empty" >&2; usage; }
  if [ -n "${EPIC_DISPATCH_PARENT_EPIC-}" ]; then
    echo "this session is a child of epic #$EPIC_DISPATCH_PARENT_EPIC (EPIC_DISPATCH_PARENT_EPIC); child epics are not expanded here" >&2
    exit 1
  fi
  local agent_cmd
  agent_cmd="EPIC_DISPATCH_PARENT_EPIC=$epic $claude_cmd --model $(shq "$model")"

  command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH" >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH" >&2; exit 1; }

  local current repo parent list
  current="$(orca worktree current --json)" || { echo "not in an Orca-managed worktree" >&2; exit 1; }
  repo="$(printf '%s' "$current" | jq -r '.result.worktree.repoId // empty')"
  [ -n "$repo" ] || { echo "orca worktree current --json has no repoId" >&2; exit 1; }
  parent="$(git rev-parse --show-toplevel)" || { echo "git rev-parse failed" >&2; exit 1; }
  git fetch origin "$base" >&2 || { echo "git fetch origin $base failed" >&2; exit 1; }
  orca worktree set --worktree "path:$parent" --issue "$epic" >&2 \
    || { echo "orca worktree set failed" >&2; exit 1; }
  list="$(orca worktree list --json)" || { echo "orca worktree list failed" >&2; exit 1; }
  printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1 \
    || { echo "orca worktree list --json is not readable" >&2; exit 1; }

  local n prompt out rc child handle sent retry failed=0 seen=" "
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
    child="$(printf '%s' "$out" | jq -r '.result.worktree.path // empty' 2>/dev/null)"
    if [ -z "$child" ]; then
      echo "no worktree path for #$n in orca worktree create --json" >&2
      echo "failed $n"; failed=1; continue
    fi
    out="$(orca terminal create --worktree "path:$child" --command "$agent_cmd" --json)"
    rc=$?
    printf '%s\n' "$out" >&2
    handle=""
    [ "$rc" -eq 0 ] && handle="$(printf '%s' "$out" | jq -r '.result.terminal.handle // empty' 2>/dev/null)"
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
    if [ "$rc" -eq 0 ] && printf '%s' "$sent" \
      | jq -e '[.. | objects | .stages? | arrays | .[]] | index("turn_started") != null' >/dev/null 2>&1; then
      echo "launched $n"
    else
      retry="$(printf '%s' "$sent" \
        | jq -r 'first(.. | objects | (.retryRequestId // .retryRequest) | strings) // empty' 2>/dev/null)"
      resend_hint "$handle" "$prompt" "$submit" "$retry"
      echo "failed $n"; failed=1
    fi
  done
  exit "$failed"
}

# 今いるワークスペースに印を付ける（done = completed / waiting = in-review）。
# 今のワークスペースの linkedIssue が <issue> と一致するときだけ付ける
cmd_mark() {
  [ "$#" -eq 2 ] || usage
  local kind="$1" n="$2" status
  case "$kind" in
    done) status=completed ;;
    waiting) status=in-review ;;
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
  if orca worktree set --worktree current --workspace-status "$status" >&2; then
    echo "marked $n $kind"
    return 0
  fi
  echo "failed $n"
  exit 1
}

cmd_wait() {
  local interval="${EPIC_DISPATCH_INTERVAL:-300}" timeout="${EPIC_DISPATCH_TIMEOUT:-21600}"
  # --watch-done の子（空白区切り。bash 3.2 の set -u で空の配列を展開できないので文字列で持つ）
  local watch=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --interval) [ "$#" -ge 2 ] || usage; interval="$2"; shift 2 ;;
      --timeout) [ "$#" -ge 2 ] || usage; timeout="$2"; shift 2 ;;
      --watch-done)
        [ "$#" -ge 2 ] || usage
        is_num "$2" || { echo "--watch-done needs an issue number: $2" >&2; usage; }
        case " $watch " in *" $2 "*) ;; *) watch="$watch $2" ;; esac
        shift 2 ;;
      --*) usage ;;
      *) break ;;
    esac
  done
  is_num "$interval" || { echo "--interval must be a non-negative integer: $interval" >&2; usage; }
  is_num "$timeout" || { echo "--timeout must be a non-negative integer: $timeout" >&2; usage; }
  [ "$#" -ge 1 ] || [ -n "$watch" ] || usage
  check_children "$@"

  local repo="" current list
  if [ -n "$watch" ]; then
    command -v orca >/dev/null 2>&1 || { echo "orca is not on PATH (needed by --watch-done)" >&2; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "jq is not on PATH (needed by --watch-done)" >&2; exit 1; }
    current="$(orca worktree current --json)" || { echo "not in an Orca-managed worktree" >&2; exit 1; }
    repo="$(printf '%s' "$current" | jq -r '.result.worktree.repoId // empty' 2>/dev/null)"
    [ -n "$repo" ] || { echo "orca worktree current --json has no repoId" >&2; exit 1; }
  fi

  local fails=0 n state closed failed marked wsfail
  local errf; errf="$(mktemp)"; trap 'rm -f "$errf"' EXIT
  SECONDS=0
  while :; do
    closed=""; failed=""; marked=""; wsfail=0; : > "$errf"
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
    # 完了の印は、ポーリングごとに 1 回の一覧で全部の --watch-done の子を見る
    if [ -n "$watch" ]; then
      if list="$(orca worktree list --json 2>>"$errf")" \
        && printf '%s' "$list" | jq -e '.result.worktrees | type == "array"' >/dev/null 2>&1; then
        for n in $watch; do
          if printf '%s' "$list" | jq -e --arg r "$repo" --arg n "$n" \
            'any(.result.worktrees[]; .repoId == $r and (.linkedIssue | tostring) == $n
              and .isArchived != true and .workspaceStatus == "completed")' >/dev/null 2>&1; then
            marked="$marked $n"
          fi
        done
      else
        wsfail=1
      fi
    fi
    if [ -n "$closed" ] || [ -n "$marked" ]; then
      [ -n "$closed" ] && echo "closed${closed}"
      [ -n "$marked" ] && echo "done${marked}"
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

  local n cands count w path ref branch st head heads tip seen=" "
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
    heads="$(gh pr list --head "$branch" --state merged --json headRefOid --jq '.[].headRefOid')" \
      || { echo "kept $n pr-lookup-failed"; continue; }
    [ -n "$heads" ] || { echo "kept $n no-merged-pr"; continue; }
    head="$(git -C "$path" rev-parse HEAD)" || head=""
    if [ -z "$head" ] || ! printf '%s\n' "$heads" | grep -qxF -- "$head"; then
      echo "kept $n head-mismatch"; continue
    fi
    orca terminal close --worktree "path:$path" --all >&2 || { echo "kept $n close-failed"; continue; }
    # --force は付けない（確認のあとに増えた未コミットの変更があれば rm が止まる）
    orca worktree rm --worktree "path:$path" >&2 || { echo "kept $n rm-failed"; continue; }
    if tip="$(git rev-parse --verify --quiet "refs/heads/$branch")"; then
      if [ "$tip" = "$head" ] && git branch -D "$branch" >&2; then
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
  wait) cmd_wait "$@" ;;
  mark) cmd_mark "$@" ;;
  reap) cmd_reap "$@" ;;
  *) usage ;;
esac
