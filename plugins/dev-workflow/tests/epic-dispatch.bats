#!/usr/bin/env bats
# epic-dispatch.sh（エピックの子の経路判定・起動・待ち受け）の振る舞いを、
# orca / gh / git / sleep を PATH 上のスタブにして確かめる。あわせて develop の SKILL.md
# 「エピックの扱い」の回し方と「前提」表に、この経路の記述があることを確かめる。
#
# スタブは自分の名前と引数（printf '%q'）を共通のログ（${STUB_LOG}）に 1 行ずつ追記する。
# 返り値は $STUB_CFG の設定ファイルで切り替える:
#   orca: current_exit / current_json / list_exit / list_json / set_exit / create_fail_<N>
#         / create_json_<N>（既定は result.worktree.path が /work/issue-<N> の JSON）
#         / tcreate_fail_<N> / tcreate_json_<N>（terminal create。<N> は --worktree の path の issue-<N>。
#         既定は result.terminal.handle が term-<N> の JSON。--command は tcmd_<N> に書き出す）
#         / wait_exit_<handle> / send_exit_<handle> / send_json_<handle>
#         （既定は stages に turn_started を含む JSON）。
#         create に --prompt が渡されたら prompt_<N> に、terminal send の --text は sent_<handle> に書き出す
#   git : toplevel（rev-parse の出力）/ fetch_exit
#   gh  : gh_<N> に 1 呼び出し 1 行の返り値（open / closed / FAIL / 空行）。最後の行を繰り返す。
#         呼び出し回数は ghcount_<N>。FAIL は stderr に "gh: mock failure for issue <N> (poll <count>)" も出す
# スクリプトは PATH="<スタブ置き場>:/usr/bin:/bin" で走らせる（jq は実物）。
# テストの途中に素の [[ ]] を置かない（bash 3.2 では偽でも素通りする）。
#
# spec: dev-workflow-develop（epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/epic-dispatch.sh"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  STUB_BIN="${BATS_TEST_TMPDIR}/bin"
  export STUB_CFG="${BATS_TEST_TMPDIR}/cfg"
  export STUB_LOG="${BATS_TEST_TMPDIR}/calls.log"
  mkdir -p "$STUB_BIN" "$STUB_CFG"
  : > "$STUB_LOG"
  printf '%s\n' '{"result":{"worktree":{"repoId":"repo-a","path":"/work/parent"}}}' > "$STUB_CFG/current_json"
  printf '%s\n' '{"result":{"worktrees":[]}}' > "$STUB_CFG/list_json"
  printf '%s\n' '/work/parent' > "$STUB_CFG/toplevel"
  make_stub gh
  make_stub git
  make_stub sleep
  # 外の環境（並列起動された子のセッション）の値をテストに漏らさない
  unset EPIC_DISPATCH_PARENT_EPIC
}

# 共通の前半（ログへの追記）と、名前ごとの返り値の処理を持つスタブを置く
make_stub() {
  local name="$1" body
  case "$name" in
    orca) body='
case "$1 $2" in
  "worktree current")
    rc=$(cat "$STUB_CFG/current_exit" 2>/dev/null || echo 0)
    [ "$rc" -eq 0 ] && cat "$STUB_CFG/current_json"
    exit "$rc" ;;
  "worktree list")
    rc=$(cat "$STUB_CFG/list_exit" 2>/dev/null || echo 0)
    [ "$rc" -eq 0 ] && cat "$STUB_CFG/list_json"
    exit "$rc" ;;
  "worktree set")
    echo "{\"ok\":true}"
    exit "$(cat "$STUB_CFG/set_exit" 2>/dev/null || echo 0)" ;;
  "worktree create")
    issue=""; prompt=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --issue) issue="$2"; shift ;;
        --prompt) prompt="$2"; shift ;;
      esac
      shift
    done
    [ -n "$prompt" ] && printf "%s" "$prompt" > "$STUB_CFG/prompt_$issue"
    if [ -e "$STUB_CFG/create_json_$issue" ]; then
      cat "$STUB_CFG/create_json_$issue"
    else
      echo "{\"ok\":true,\"result\":{\"worktree\":{\"path\":\"/work/issue-$issue\"}}}"
    fi
    [ -e "$STUB_CFG/create_fail_$issue" ] && exit 1
    exit 0 ;;
  "terminal create")
    issue=""; cmd=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --worktree) issue="${2##*issue-}"; shift ;;
        --command) cmd="$2"; shift ;;
      esac
      shift
    done
    printf "%s" "$cmd" > "$STUB_CFG/tcmd_$issue"
    if [ -e "$STUB_CFG/tcreate_json_$issue" ]; then
      cat "$STUB_CFG/tcreate_json_$issue"
    else
      echo "{\"ok\":true,\"result\":{\"terminal\":{\"handle\":\"term-$issue\"}}}"
    fi
    [ -e "$STUB_CFG/tcreate_fail_$issue" ] && exit 1
    exit 0 ;;
  "terminal wait"|"terminal send")
    sub="$2"; handle=""; text=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --terminal) handle="$2"; shift ;;
        --text) text="$2"; shift ;;
      esac
      shift
    done
    if [ "$sub" = wait ]; then
      echo "{\"ok\":true}"
      exit "$(cat "$STUB_CFG/wait_exit_$handle" 2>/dev/null || echo 0)"
    fi
    printf "%s" "$text" > "$STUB_CFG/sent_$handle"
    if [ -e "$STUB_CFG/send_json_$handle" ]; then
      cat "$STUB_CFG/send_json_$handle"
    else
      echo "{\"ok\":true,\"result\":{\"stages\":[\"input_accepted\",\"turn_started\"]}}"
    fi
    exit "$(cat "$STUB_CFG/send_exit_$handle" 2>/dev/null || echo 0)" ;;
esac
exit 0' ;;
    git) body='
case "$1" in
  rev-parse) cat "$STUB_CFG/toplevel"; exit 0 ;;
  fetch) exit "$(cat "$STUB_CFG/fetch_exit" 2>/dev/null || echo 0)" ;;
esac
exit 0' ;;
    gh) body='
n="${2##*/}"
count=$(( $(cat "$STUB_CFG/ghcount_$n" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$STUB_CFG/ghcount_$n"
total=$(wc -l < "$STUB_CFG/gh_$n" | tr -d " ")
[ "$count" -gt "$total" ] && count="$total"
val=$(sed -n "${count}p" "$STUB_CFG/gh_$n")
[ "$val" = "FAIL" ] && { echo "gh: mock failure for issue $n (poll $count)" >&2; exit 1; }
echo "$val"
exit 0' ;;
    sleep) body='exit 0' ;;
  esac
  {
    echo '#!/bin/bash'
    echo "{ printf '%s' '$name'; printf ' %q' \"\$@\"; echo; } >> \"\$STUB_LOG\""
    echo "$body"
  } > "$STUB_BIN/$name"
  chmod +x "$STUB_BIN/$name"
}

# stdout だけを $output に取る（stderr は別ファイル）
dispatch() { PATH="$STUB_BIN:/usr/bin:/bin" "$SCRIPT" "$@" 2>"$BATS_TEST_TMPDIR/stderr"; }

# 子 N の gh の返り値の並びを置く（1 引数 1 呼び出し）
gh_seq() { local n="$1"; shift; printf '%s\n' "$@" > "$STUB_CFG/gh_$n"; }

# ログの呼び出し回数（grep -c が 0 件で exit 1 になるのを吸収する）
calls() { LC_ALL=C grep -c -- "$1" "$STUB_LOG" || true; }

# 前方一致（失敗したら両方を出す）
starts_with() {
  case "$1" in
    "$2"*) return 0 ;;
  esac
  echo "expected prefix: $2" >&2
  echo "actual:          $1" >&2
  return 1
}

# SKILL.md の「## <見出し>」から次の「## 」まで
section() { awk -v h="## $1" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$SKILL"; }
# 「エピックの扱い」の「### 回し方」から次の「### 」まで
run_section() { section 'エピックの扱い' | awk '/^### 回し方/{f=1; print; next} /^### /{f=0} f'; }

# --- route ---

@test "route: without orca on PATH, two children go to subagent" {
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "subagent" ]
}

@test "route: orca present but not an Orca-managed worktree goes to subagent" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "subagent" ]
}

@test "route: one child under Orca goes to subagent" {
  make_stub orca
  run dispatch route 11
  [ "$status" -eq 0 ]
  [ "$output" = "subagent" ]
}

@test "route: two children under Orca go to orca" {
  make_stub orca
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree current')" -eq 1 ]
}

@test "route: a non-numeric child is rejected" {
  make_stub orca
  run dispatch route '#12' 13
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "route: EPIC_DISPATCH_PARENT_EPIC goes to nested without calling orca" {
  make_stub orca
  EPIC_DISPATCH_PARENT_EPIC=420 run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "route: EPIC_DISPATCH_PARENT_EPIC still rejects a non-numeric child" {
  make_stub orca
  EPIC_DISPATCH_PARENT_EPIC=420 run dispatch route '#11'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
}

# --- launch ---

@test "launch: call order is current, toplevel, fetch, set, list, then create, terminal create, wait and send per child" {
  make_stub orca
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
  log=()
  while IFS= read -r l; do log+=("$l"); done < "$STUB_LOG"
  [ "${#log[@]}" -eq 13 ]
  [ "${log[0]}" = "orca worktree current --json" ]
  [ "${log[1]}" = "git rev-parse --show-toplevel" ]
  [ "${log[2]}" = "git fetch origin main" ]
  [ "${log[3]}" = "orca worktree set --worktree path:/work/parent --issue 400" ]
  [ "${log[4]}" = "orca worktree list --json" ]
  [ "${log[5]}" = "orca worktree create --name issue-11 --issue 11 --base-branch origin/main --parent-worktree path:/work/parent --json" ]
  starts_with "${log[6]}" "orca terminal create --worktree path:/work/issue-11 --command "
  case "${log[6]}" in *' --json') ;; *) echo "terminal create must end with --json" >&2; false ;; esac
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 cld --model 'opus'" ]
  [ "${log[7]}" = "orca terminal wait --terminal term-11 --for tui-idle --timeout-ms 60000 --json" ]
  starts_with "${log[8]}" "orca terminal send --terminal term-11 --text "
  case "${log[8]}" in *' --enter --wait-submit 30 --json') ;; *) echo "send must end with --enter --wait-submit 30 --json" >&2; false ;; esac
  [ "${log[9]}" = "orca worktree create --name issue-12 --issue 12 --base-branch origin/main --parent-worktree path:/work/parent --json" ]
  starts_with "${log[10]}" "orca terminal create --worktree path:/work/issue-12 --command "
  [ "${log[11]}" = "orca terminal wait --terminal term-12 --for tui-idle --timeout-ms 60000 --json" ]
  starts_with "${log[12]}" "orca terminal send --terminal term-12 --text "
  [ "$(calls '--prompt')" -eq 0 ]
  [ "$(calls '--agent')" -eq 0 ]
}

@test "launch: EPIC_DISPATCH_MODEL changes the model passed to --model" {
  make_stub orca
  EPIC_DISPATCH_MODEL='opus[1m]' run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 cld --model 'opus[1m]'" ]
}

@test "launch: EPIC_DISPATCH_CLAUDE_CMD replaces the command as is" {
  make_stub orca
  EPIC_DISPATCH_CLAUDE_CMD='cld-account b' run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  [ "$(cat "$STUB_CFG/tcmd_11")" = "EPIC_DISPATCH_PARENT_EPIC=400 cld-account b --model 'opus'" ]
}

@test "launch: an empty EPIC_DISPATCH_CLAUDE_CMD creates nothing" {
  make_stub orca
  EPIC_DISPATCH_CLAUDE_CMD= run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: an empty EPIC_DISPATCH_MODEL creates nothing" {
  make_stub orca
  EPIC_DISPATCH_MODEL= run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: a failing terminal create is failed and prints the terminal create and send commands" {
  make_stub orca
  touch "$STUB_CFG/tcreate_fail_11"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(calls '^orca terminal wait ')" -eq 1 ]
  [ "$(calls '^orca terminal send ')" -eq 1 ]
  grep -F 'orca terminal create --worktree path:/work/issue-11' "$BATS_TEST_TMPDIR/stderr" | grep -qF 'cld --model'
  grep -F 'orca terminal send' "$BATS_TEST_TMPDIR/stderr" | grep -qF '/develop #11'
}

@test "launch: the recreate command carries the EPIC_DISPATCH_PARENT_EPIC prefix" {
  make_stub orca
  touch "$STUB_CFG/tcreate_fail_11"
  run dispatch launch 420 11
  [ "$status" -eq 1 ]
  grep -F 'orca terminal create --worktree path:/work/issue-11' "$BATS_TEST_TMPDIR/stderr" \
    | grep -qF -- "--command 'EPIC_DISPATCH_PARENT_EPIC=420 "
}

@test "launch: EPIC_DISPATCH_PARENT_EPIC creates nothing and calls neither orca nor git" {
  make_stub orca
  EPIC_DISPATCH_PARENT_EPIC=420 run dispatch launch 460 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca ')" -eq 0 ]
  [ "$(calls '^git ')" -eq 0 ]
  grep -qF '420' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: no worktree path in create means failed without terminal create" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{}}' > "$STUB_CFG/create_json_11"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(calls '^orca terminal create ')" -eq 0 ]
}

@test "launch: prompt starts with /develop #N and names the epic" {
  make_stub orca
  run dispatch launch 400 11
  [ "$status" -eq 0 ]
  p="$(cat "$STUB_CFG/sent_term-11")"
  starts_with "$p" "/develop #11 "
  printf '%s' "$p" | grep -qF '#400'
  printf '%s' "$p" | grep -qF '/work/parent'
}

@test "launch: --note text is appended to every child prompt" {
  make_stub orca
  run dispatch launch --note "do not touch the follow-up scope" 400 11 12
  [ "$status" -eq 0 ]
  grep -qF 'do not touch the follow-up scope' "$STUB_CFG/sent_term-11"
  grep -qF 'do not touch the follow-up scope' "$STUB_CFG/sent_term-12"
}

@test "launch: EPIC_DISPATCH_BASE changes the base for fetch and --base-branch" {
  make_stub orca
  EPIC_DISPATCH_BASE=develop run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^git fetch origin develop$')" -eq 1 ]
  [ "$(calls '--base-branch origin/develop ')" -eq 1 ]
}

@test "launch: --base wins over EPIC_DISPATCH_BASE" {
  make_stub orca
  EPIC_DISPATCH_BASE=develop run dispatch launch --base trunk 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^git fetch origin trunk$')" -eq 1 ]
  [ "$(calls '--base-branch origin/trunk ')" -eq 1 ]
  [ "$(calls 'origin develop')" -eq 0 ]
  [ "$(calls 'origin/develop')" -eq 0 ]
}

@test "launch: an existing worktree for the same repo and issue is skipped" {
  make_stub orca
  printf '%s\n' '{"result":{"worktrees":[{"repoId":"repo-a","path":"/w/issue-11","linkedIssue":11,"isArchived":false}]}}' > "$STUB_CFG/list_json"
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "skipped 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 0 ]
  [ "$(calls '^orca worktree create --name issue-12 ')" -eq 1 ]
}

@test "launch: a duplicate child number in the same call is skipped after the first" {
  make_stub orca
  run dispatch launch 420 11 11
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "skipped 11" ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 1 ]
}

@test "launch: list-based skipped and same-call duplicate skipped coexist" {
  make_stub orca
  printf '%s\n' '{"result":{"worktrees":[{"repoId":"repo-a","path":"/w/issue-12","linkedIssue":12,"isArchived":false}]}}' > "$STUB_CFG/list_json"
  run dispatch launch 420 11 12 11
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "skipped 12" ]
  [ "${lines[2]}" = "skipped 11" ]
  [ "${#lines[@]}" -eq 3 ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 1 ]
  [ "$(calls '^orca worktree create --name issue-12 ')" -eq 0 ]
}

@test "launch: a failed first attempt still skips a later duplicate of the same number" {
  make_stub orca
  touch "$STUB_CFG/create_fail_11"
  run dispatch launch 420 11 11
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "skipped 11" ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(calls '^orca worktree create --name issue-11 ')" -eq 1 ]
}

@test "launch: a worktree of another repo or an archived one does not count as launched" {
  make_stub orca
  printf '%s\n' '{"result":{"worktrees":[{"repoId":"repo-b","path":"/w/x","linkedIssue":11,"isArchived":false},{"repoId":"repo-a","path":"/w/y","linkedIssue":12,"isArchived":true}]}}' > "$STUB_CFG/list_json"
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "launched 12" ]
}

@test "launch: failing worktree current creates nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: failing fetch creates nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/fetch_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: failing set creates nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/set_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: failing list creates nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: one failed create still launches the rest and exits 1" {
  make_stub orca
  touch "$STUB_CFG/create_fail_11"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "launch: no terminal handle means failed without wait or send" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{}}' > "$STUB_CFG/tcreate_json_11"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "$(calls '^orca terminal wait --terminal term-12 ')" -eq 1 ]
  [ "$(calls '^orca terminal wait ')" -eq 1 ]
  [ "$(calls '^orca terminal send ')" -eq 1 ]
}

@test "launch: a failing send is failed and prints a resend command with a read hint" {
  make_stub orca
  echo 1 > "$STUB_CFG/send_exit_term-11"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "failed 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
  grep -F 'orca terminal send --terminal term-11 --text' "$BATS_TEST_TMPDIR/stderr" | grep -qF '/develop #11'
  grep -qF 'orca terminal read --terminal term-11' "$BATS_TEST_TMPDIR/stderr"
  [ "$(grep -c -- '--retry-request' "$BATS_TEST_TMPDIR/stderr" || true)" -eq 0 ]
}

@test "launch: a retry request id from send is added to the resend command" {
  make_stub orca
  echo 1 > "$STUB_CFG/send_exit_term-11"
  printf '%s\n' '{"ok":false,"result":{"retryRequestId":"rq-1","stages":["input_accepted"]}}' > "$STUB_CFG/send_json_term-11"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  grep -F 'orca terminal send --terminal term-11' "$BATS_TEST_TMPDIR/stderr" | grep -qF -- '--retry-request rq-1'
  grep -qF 'orca terminal read --terminal term-11' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: a send without turn_started is failed" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{"stages":["input_accepted"]}}' > "$STUB_CFG/send_json_term-11"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
}

@test "launch: turn_started in a nested stages array counts" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{"receipt":{"stages":["input_accepted","turn_started"]}}}' > "$STUB_CFG/send_json_term-11"
  run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
}

@test "launch: a failing tui-idle wait is failed without send" {
  make_stub orca
  echo 1 > "$STUB_CFG/wait_exit_term-11"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(calls '^orca terminal send ')" -eq 0 ]
}

@test "launch: EPIC_DISPATCH_READY_TIMEOUT_MS and EPIC_DISPATCH_SUBMIT_WAIT set the waits" {
  make_stub orca
  EPIC_DISPATCH_READY_TIMEOUT_MS=5000 EPIC_DISPATCH_SUBMIT_WAIT=7 run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$(calls '^orca terminal wait --terminal term-11 --for tui-idle --timeout-ms 5000 --json$')" -eq 1 ]
  [ "$(calls ' --enter --wait-submit 7 --json$')" -eq 1 ]
}

@test "launch: a non-numeric wait variable creates nothing" {
  make_stub orca
  EPIC_DISPATCH_SUBMIT_WAIT=abc run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
  EPIC_DISPATCH_READY_TIMEOUT_MS=1s run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$(calls 'worktree create')" -eq 0 ]
}

@test "launch: without orca on PATH nothing is called" {
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ ! -s "$STUB_LOG" ]
}

@test "launch: a non-numeric epic or child is rejected before anything is called" {
  make_stub orca
  run dispatch launch '#400' 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch launch 400 '#11'
  [ "$status" -eq 1 ]
  [ ! -s "$STUB_LOG" ]
}

@test "launch: orca output goes to stderr, stdout has only the per-child lines" {
  make_stub orca
  run dispatch launch 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  grep -q '"ok":true' "$BATS_TEST_TMPDIR/stderr"
}

# --- wait ---

@test "wait: a child closing on the second poll ends with closed" {
  gh_seq 11 open
  gh_seq 12 open closed
  run dispatch wait --interval 0 --timeout 60 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "closed 12" ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "wait: all open with --timeout 0 ends with timeout after one poll" {
  gh_seq 11 open
  gh_seq 12 open
  run dispatch wait --interval 0 --timeout 0 11 12
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "timeout 11 12" ]
  [ "${#lines[@]}" -eq 1 ]
  [ "$(calls '^gh ')" -eq 2 ]
  [ "$(calls '^sleep')" -eq 0 ]
}

@test "wait: the interval is passed to sleep" {
  gh_seq 11 open open closed
  run dispatch wait --interval 7 --timeout 100 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
  [ "$(calls '^sleep 7$')" -eq 2 ]
}

@test "wait: gh uses the REST issues endpoint with --jq .state" {
  gh_seq 11 closed
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  grep -q '^gh api repos/.*owner.*/.*repo.*/issues/11 --jq .state$' "$STUB_LOG"
}

@test "wait: EPIC_DISPATCH_TIMEOUT=0 alone times out" {
  gh_seq 11 open
  EPIC_DISPATCH_TIMEOUT=0 run dispatch wait --interval 0 11
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "timeout 11" ]
}

@test "wait: --timeout wins over EPIC_DISPATCH_TIMEOUT" {
  gh_seq 11 open closed
  EPIC_DISPATCH_TIMEOUT=0 run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
}

@test "wait: EPIC_DISPATCH_INTERVAL sets the default and --interval wins" {
  gh_seq 11 open closed
  EPIC_DISPATCH_INTERVAL=5 run dispatch wait --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$(calls '^sleep 5$')" -eq 1 ]
  : > "$STUB_LOG"; rm -f "$STUB_CFG/ghcount_11"
  EPIC_DISPATCH_INTERVAL=5 run dispatch wait --interval 3 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$(calls '^sleep 3$')" -eq 1 ]
  [ "$(calls '^sleep 5$')" -eq 0 ]
}

@test "wait: gh failing every poll ends with error after three polls" {
  gh_seq 11 FAIL
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 11" ]
  [ "${#lines[@]}" -eq 1 ]
  [ "$(calls '^gh ')" -eq 3 ]
}

@test "wait: gh's stderr is shown right before the error line" {
  gh_seq 11 FAIL
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 11" ]
  grep -qF 'gh: mock failure for issue 11' "$BATS_TEST_TMPDIR/stderr"
}

@test "wait: one child failing while another stays open still ends with error" {
  gh_seq 11 FAIL
  gh_seq 12 open
  run dispatch wait --interval 0 --timeout 60 11 12
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 11" ]
  [ "$(calls 'issues/11 ')" -eq 3 ]
}

@test "wait: an empty state counts as a failure" {
  gh_seq 11 ""
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 11" ]
}

@test "wait: a clean poll resets the failure count" {
  gh_seq 11 FAIL FAIL open FAIL FAIL closed
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
  [ "$(calls '^gh ')" -eq 6 ]
}

@test "wait: a closed child wins over another child's failure" {
  gh_seq 11 FAIL
  gh_seq 12 closed
  run dispatch wait --interval 0 --timeout 60 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "closed 12" ]
}

@test "wait: timeout lists children that failed on the last poll too" {
  gh_seq 11 FAIL
  gh_seq 12 open
  run dispatch wait --interval 0 --timeout 0 11 12
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "timeout 11 12" ]
}

@test "wait: no children, a non-numeric child, or a bad interval is rejected" {
  run dispatch wait --interval 0 --timeout 0
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval 0 --timeout 0 '#11'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval -1 --timeout 0 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval 1.5 --timeout 0 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval 0 --timeout abc 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^gh ')" -eq 0 ]
}

# --- SKILL.md ---

@test "skill: epic run section names route, launch, wait and background waiting" {
  r="$(run_section)"
  [ -n "$r" ]
  printf '%s\n' "$r" | grep -qF 'epic-dispatch.sh route'
  printf '%s\n' "$r" | grep -qF 'launch'
  printf '%s\n' "$r" | grep -qF 'wait'
  printf '%s\n' "$r" | grep -qF 'run_in_background'
}

@test "skill: epic run section's launch line documents --base and EPIC_DISPATCH_BASE" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF -- 'epic-dispatch.sh launch [--note <text>] [--base <branch>] <エピック番号> <子>...'
  printf '%s\n' "$r" | grep -qF -- '起点は `origin/main`'
  printf '%s\n' "$r" | grep -qF -- '--base <既定ブランチ>'
  printf '%s\n' "$r" | grep -qF -- 'EPIC_DISPATCH_BASE'
}

@test "skill: epic run section states the routing conditions and the subagent fallback" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF '2 件以上'
  printf '%s\n' "$r" | grep -qF '`orca`'
  printf '%s\n' "$r" | grep -qF 'Orca 管理のワークツリー'
  printf '%s\n' "$r" | grep -qF 'サブエージェント方式'
}

@test "skill: route is fixed at the first start, resumed from the comment, and unmanned uses subagents" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF '途中で変えない'
  printf '%s\n' "$r" | grep -qF '回し方:'
  printf '%s\n' "$r" | grep -F 'unmanned' | grep -qF 'サブエージェント方式'
}

@test "skill: Orca route reacts to closed, timeout and error" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF 'state_reason'
  printf '%s\n' "$r" | grep -qF '子 #N マージ → 残り k 件'
  printf '%s\n' "$r" | grep -qF '見送り'
  printf '%s\n' "$r" | grep -F 'timeout' | grep -qF '再び'
  printf '%s\n' "$r" | grep -qF '子のタブ'
  printf '%s\n' "$r" | grep -qF '検知できない'
  printf '%s\n' "$r" | grep -qF 'skipped'
  printf '%s\n' "$r" | grep -qF '親ワークツリーで開き直す'
}

@test "skill: child sessions skip permissions and the parent never merges" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -F -- '--dangerously-skip-permissions' | grep -qF 'cld'
  printf '%s\n' "$r" | grep -F 'EPIC_DISPATCH_CLAUDE_CMD' | grep -qF 'cld'
  printf '%s\n' "$r" | grep -F 'EPIC_DISPATCH_CLAUDE_CMD' | grep -qF '合わせて変える'
  printf '%s\n' "$r" | grep -qF 'EPIC_DISPATCH_MODEL'
  printf '%s\n' "$r" | grep -F 'EPIC_DISPATCH_MODEL' | grep -qF 'opus'
  printf '%s\n' "$r" | grep -qF 'pr-review-gate'
  printf '%s\n' "$r" | grep -qF '自動でマージしない'
}

@test "skill: prerequisites table has an orca row with the subagent fallback" {
  p="$(section '前提' | grep -F '**`orca`**')"
  [ -n "$p" ]
  printf '%s\n' "$p" | grep -qF 'Orca 管理外'
  printf '%s\n' "$p" | grep -qF 'サブエージェント方式'
}

@test "skill: child epics are held back, nested sessions stop, and the parent reports them" {
  e="$(section 'エピックの扱い')"
  printf '%s\n' "$e" | grep -qF 'sub_issues_summary'
  printf '%s\n' "$e" | grep -qF 'nested'
  printf '%s\n' "$e" | grep -F '後で別に起動するエピック:' | grep -qF '完了報告'
  printf '%s\n' "$e" | grep -F 'timeout' | grep -F 'closed' | grep -qF '後で別に起動するエピック:'
  printf '%s\n' "$e" | grep -F 'launch' | grep -F 'nested' | grep -qF '「親ワークツリーで開き直す」とは報告しない'
}

@test "skill: held-back child epics are recorded also when route is skipped (unmanned, resumed)" {
  e="$(section 'エピックの扱い' | grep -F 'sub_issues_summary')"
  printf '%s\n' "$e" | grep -F '後で別に起動するエピック:' | grep -F 'でないと確定' | grep -F 'unmanned' | grep -qF '回し方:'
}
