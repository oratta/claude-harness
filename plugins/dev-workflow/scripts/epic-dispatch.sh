#!/usr/bin/env bash
# エピックの子の経路判定・起動・待ち受けを LLM なしで行う。develop の本体（エピックの解決
# セッション）が SKILL.md「エピックの扱い」→「回し方」の手順どおりに呼ぶ。
#
#   epic-dispatch.sh route <child>...
#   epic-dispatch.sh launch [--note <text>] [--base <branch>] <epic> <child>...
#   epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] <child>...
#
# route: 子が 2 件以上・`orca` が PATH にある・`orca worktree current` が exit 0（今いるのが
#   Orca 管理のワークツリー）のすべてが成り立てば stdout に `orca`、それ以外は `subagent`。exit 0
# launch: `orca worktree current --json` → `git rev-parse --show-toplevel` → `git fetch origin <base>`
#   → `orca worktree set --worktree path:<親> --issue <epic>` → `orca worktree list --json` →
#   子ごとに `orca worktree create`（同じ repoId・同じ linkedIssue・archive されていない
#   ワークツリーがあれば作らない。--agent も --prompt も渡さない）→ `orca terminal create
#   --worktree path:<子> --command "claude --model <model> --dangerously-skip-permissions"`
#   （<model> の既定は opus、EPIC_DISPATCH_MODEL で変える。空なら使い方を出して exit 1。
#   作れなければ作り直しと送信のコマンドを stderr に出す）→ `orca terminal wait --for tui-idle` →
#   `orca terminal send --text <指示> --enter --wait-submit <秒>`。stdout は子ごとに `launched <N>`
#   （send の stages に turn_started がある）/ `skipped <N>` / `failed <N>` の 1 行。failed で
#   ハンドルが取れていれば送り直しのコマンドを stderr に出す。orca 自身の出力は stderr。
#   <base> の既定は main（EPIC_DISPATCH_BASE、--base が優先）。起動完了待ちの上限（ミリ秒）と
#   送信の観測時間（秒）の既定は 60000 / 30（EPIC_DISPATCH_READY_TIMEOUT_MS / EPIC_DISPATCH_SUBMIT_WAIT）
#   exit 0 = failed なし / 1 = failed あり、または orca・jq が無い・current / fetch / set / list の
#   失敗（このときは子を 1 件も作らない）
# wait: 子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` を見るポーリングを繰り返し、
#   stdout にちょうど 1 行を出して終わる。
#   `closed <N>...`（閉じていた子）exit 0 / `timeout <N>...`（閉じていない子）exit 2 /
#   `error gh <N>...`（失敗したポーリングが 3 回続いた。3 回目で失敗した子）exit 1
#   失敗したポーリング = 1 件以上の子が失敗（gh が非 0、または出力が open / closed 以外）し、
#   閉じた子が 1 件も無いポーリング。失敗の無いポーリングで数え直す。
#   間隔・上限は秒。既定 300 / 21600（EPIC_DISPATCH_INTERVAL / EPIC_DISPATCH_TIMEOUT、フラグが優先）。
#   ポーリングのあとで「経過 >= 上限」か「経過 + 間隔 > 上限」なら眠らずに timeout
#   （--timeout 0 は間隔によらず 1 回だけ確かめる）
# 引数の誤り（子が 0 件・番号が数字でない・フラグ値の誤り）は stderr に使い方を出して exit 1。
#
# 設計と守備範囲（引数を渡すのは本体で、人が手で打つことは想定しない）は
# openspec の dev-workflow-develop spec「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを
# LLM なしで行う」が正本。
set -uo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  epic-dispatch.sh route <child>...
  epic-dispatch.sh launch [--note <text>] [--base <branch>] <epic> <child>...
  epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] <child>...
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
  local agent_cmd="claude --model $(shq "$model") --dangerously-skip-permissions"

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

  local n prompt out rc child handle sent retry failed=0
  for n in "$@"; do
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

cmd_wait() {
  local interval="${EPIC_DISPATCH_INTERVAL:-300}" timeout="${EPIC_DISPATCH_TIMEOUT:-21600}"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --interval) [ "$#" -ge 2 ] || usage; interval="$2"; shift 2 ;;
      --timeout) [ "$#" -ge 2 ] || usage; timeout="$2"; shift 2 ;;
      --*) usage ;;
      *) break ;;
    esac
  done
  is_num "$interval" || { echo "--interval must be a non-negative integer: $interval" >&2; usage; }
  is_num "$timeout" || { echo "--timeout must be a non-negative integer: $timeout" >&2; usage; }
  [ "$#" -ge 1 ] || usage
  check_children "$@"

  local fails=0 n state closed failed
  SECONDS=0
  while :; do
    closed=""; failed=""
    for n in "$@"; do
      if state="$(gh api "repos/{owner}/{repo}/issues/$n" --jq .state 2>/dev/null)"; then
        case "$state" in
          closed) closed="$closed $n" ;;
          open) ;;
          *) failed="$failed $n" ;;
        esac
      else
        failed="$failed $n"
      fi
    done
    if [ -n "$closed" ]; then
      echo "closed${closed}"
      exit 0
    fi
    if [ -n "$failed" ]; then
      fails=$((fails + 1))
      if [ "$fails" -ge 3 ]; then
        echo "error gh${failed}"
        exit 1
      fi
    else
      fails=0
    fi
    # 閉じた子がいないので、開いている子とこのポーリングで失敗した子は引数の全部。
    # 経過が上限に達していれば間隔 0 でも終わる（--timeout 0 を 1 回の確認で終わらせるため）
    if [ "$SECONDS" -ge "$timeout" ] || [ $((SECONDS + interval)) -gt "$timeout" ]; then
      echo "timeout $*"
      exit 2
    fi
    sleep "$interval"
  done
}

[ "$#" -ge 1 ] || usage
sub="$1"; shift
case "$sub" in
  route) cmd_route "$@" ;;
  launch) cmd_launch "$@" ;;
  wait) cmd_wait "$@" ;;
  *) usage ;;
esac
