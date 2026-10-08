#!/usr/bin/env bats
# epic-dispatch.sh（エピックの子の経路判定・起動・待ち受け）の振る舞いを、
# orca / gh / git / sleep を PATH 上のスタブにして確かめる。あわせて develop の SKILL.md
# 「エピックの扱い」の回し方と「前提」表に、この経路の記述があることを確かめる。
#
# スタブは自分の名前と引数（printf '%q'）を共通のログ（${STUB_LOG}）に 1 行ずつ追記する。
# 返り値は $STUB_CFG の設定ファイルで切り替える:
#   orca: current_exit / current_json / list_exit / list_json（list_json_<回数> があればその回だけ
#         それを返す。回数は listcount）/ set_exit / close_exit / rm_exit / create_fail_<N>
#         / create_json_<N>（既定は result.worktree.path が /work/issue-<N> の JSON）
#         / tcreate_fail_<N> / tcreate_json_<N>（terminal create。<N> は --worktree の path の issue-<N>。
#         既定は result.terminal.handle が term-<N> の JSON。--command は tcmd_<N> に書き出す）
#         / wait_exit_<handle> / send_exit_<handle> / send_json_<handle>
#         （既定は stages に turn_started を含む JSON）。
#         create に --prompt が渡されたら prompt_<N> に、terminal send の --text は sent_<handle> に書き出す
#   git : toplevel（rev-parse --show-toplevel の出力）/ fetch_exit / status_exit / status_out
#         （-C <パス> status --porcelain）/ head（-C <パス> rev-parse HEAD。既定 aaa111）/ branch_tip
#         （rev-parse --verify --quiet refs/heads/<b> の出力。無ければ exit 1）/ branchd_exit（branch -D）
#   gh  : issue comment <N> --body <本文> は本文を comment_<N> に追記し（1 件ごとに "---" の行で区切る）、
#         comment_exit で終わる（既定 0）。pr list は pr_out を出して pr_exit で終わる（既定は空・0）。それ以外は gh_<N> に 1 呼び出し 1 行の返り値（open / closed / FAIL / 空行）。最後の行を繰り返す。
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
    lc=$(( $(cat "$STUB_CFG/listcount" 2>/dev/null || echo 0) + 1 ))
    echo "$lc" > "$STUB_CFG/listcount"
    rc=$(cat "$STUB_CFG/list_exit" 2>/dev/null || echo 0)
    if [ "$rc" -eq 0 ]; then
      if [ -e "$STUB_CFG/list_json_$lc" ]; then cat "$STUB_CFG/list_json_$lc"; else cat "$STUB_CFG/list_json"; fi
    fi
    exit "$rc" ;;
  "worktree rm")
    exit "$(cat "$STUB_CFG/rm_exit" 2>/dev/null || echo 0)" ;;
  "terminal close")
    exit "$(cat "$STUB_CFG/close_exit" 2>/dev/null || echo 0)" ;;
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
if [ "$1" = "-C" ]; then
  shift 2
  case "$1 ${2-}" in
    "status --porcelain")
      cat "$STUB_CFG/status_out" 2>/dev/null
      exit "$(cat "$STUB_CFG/status_exit" 2>/dev/null || echo 0)" ;;
    "rev-parse HEAD") cat "$STUB_CFG/head" 2>/dev/null || echo aaa111; exit 0 ;;
  esac
  exit 0
fi
case "$1 ${2-}" in
  "rev-parse --verify")
    [ -e "$STUB_CFG/branch_tip" ] || exit 1
    cat "$STUB_CFG/branch_tip"; exit 0 ;;
  "branch -D") exit "$(cat "$STUB_CFG/branchd_exit" 2>/dev/null || echo 0)" ;;
esac
case "$1" in
  rev-parse) cat "$STUB_CFG/toplevel"; exit 0 ;;
  fetch) exit "$(cat "$STUB_CFG/fetch_exit" 2>/dev/null || echo 0)" ;;
esac
exit 0' ;;
    gh) body='
if [ "$1 $2" = "issue comment" ]; then
  printf "%s\n---\n" "$5" >> "$STUB_CFG/comment_$3"
  exit "$(cat "$STUB_CFG/comment_exit" 2>/dev/null || echo 0)"
fi
if [ "$1 $2" = "pr list" ]; then
  cat "$STUB_CFG/pr_out" 2>/dev/null
  exit "$(cat "$STUB_CFG/pr_exit" 2>/dev/null || echo 0)"
fi
n="${2##*/}"
count=$(( $(cat "$STUB_CFG/ghcount_$n" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$STUB_CFG/ghcount_$n"
total=$(wc -l < "$STUB_CFG/gh_$n" | tr -d " ")
idx="$count"
[ "$idx" -gt "$total" ] && idx="$total"
val=$(sed -n "${idx}p" "$STUB_CFG/gh_$n")
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

# jq の無い PATH で走らせる（スタブのほかは bash と cat だけ）
dispatch_nojq() {
  local d="$BATS_TEST_TMPDIR/nojq"
  mkdir -p "$d"
  ln -sf "$(command -v bash)" "$d/bash"
  ln -sf "$(command -v cat)" "$d/cat"
  PATH="$STUB_BIN:$d" "$SCRIPT" "$@" 2>"$BATS_TEST_TMPDIR/stderr"
}

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

# 一覧の 1 件（<N> <workspaceStatus> [parentWorktreeId] [repoId] [isArchived]）。パスは実在のディレクトリ
wt_entry() {
  local n="$1" st="$2" par="${3-repo-a::/work/parent}" repo="${4-repo-a}" arch="${5-false}"
  local p="$BATS_TEST_TMPDIR/work/issue-$n"
  mkdir -p "$p"
  printf '{"id":"%s::%s","repoId":"%s","path":"%s","branch":"refs/heads/oratta/issue-%s","linkedIssue":%s,"isArchived":%s,"isMainWorktree":false,"workspaceStatus":"%s","parentWorktreeId":"%s"}' \
    "$repo" "$p" "$repo" "$p" "$n" "$n" "$arch" "$st" "$par"
}

# 一覧を置く（引数は wt_entry の出力。<file> の既定は list_json）
set_list() { local f="$1"; shift; local IFS=,; printf '{"result":{"worktrees":[%s]}}\n' "$*" > "$STUB_CFG/$f"; }

# 今のワークツリー（id と linkedIssue を持つ）
set_current() {
  printf '{"result":{"worktree":{"id":"repo-a::/work/parent","repoId":"repo-a","path":"/work/parent","linkedIssue":%s}}}\n' "$1" > "$STUB_CFG/current_json"
}

# 今のワークツリーを、親ワークツリー（linkedIssue が <1>。null も可）を持つ子にする
set_child_of() {
  printf '%s\n' '{"result":{"worktree":{"id":"repo-a::/work/issue-460","repoId":"repo-a","path":"/work/issue-460","linkedIssue":460,"parentWorktreeId":"repo-a::/work/parent"}}}' > "$STUB_CFG/current_json"
  printf '{"result":{"worktrees":[{"id":"repo-a::/work/parent","repoId":"repo-a","path":"/work/parent","linkedIssue":%s,"isArchived":false,"parentWorktreeId":null}]}}\n' "$1" > "$STUB_CFG/list_json"
}

# ログで最初に一致した行の番号
first_line() { LC_ALL=C awk -v re="$1" '$0 ~ re { print NR; exit }' "$STUB_LOG"; }

# reap の条件をすべて満たす子 11 の環境
reap_ready() {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 completed)"
  echo aaa111 > "$STUB_CFG/pr_out"
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

@test "route: EPIC_DISPATCH_PARENT_EPIC prints the parent epic on stderr" {
  make_stub orca
  EPIC_DISPATCH_PARENT_EPIC=420 run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  grep -qxF 'parent epic: #420' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca ')" -eq 0 ]
}

@test "route: a parent worktree with a linked issue goes to nested without the variable" {
  make_stub orca
  set_child_of 420
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  grep -qxF 'parent epic: #420' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree current')" -eq 1 ]
}

@test "route: one child or none is nested too when the parent worktree has a linked issue" {
  make_stub orca
  set_child_of 420
  run dispatch route 11
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
  run dispatch route
  [ "$status" -eq 0 ]
  [ "$output" = "nested" ]
}

@test "route: a parent worktree without a linked issue routes as before" {
  make_stub orca
  set_child_of null
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  [ "$(grep -c 'parent epic' "$BATS_TEST_TMPDIR/stderr" || true)" -eq 0 ]
}

@test "route: a parent worktree missing from the list routes as before" {
  make_stub orca
  set_child_of 420
  printf '%s\n' '{"result":{"worktrees":[]}}' > "$STUB_CFG/list_json"
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
}

@test "route: no parent worktree and no variable routes as before without reading the list" {
  make_stub orca
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree current')" -eq 1 ]
  run dispatch route 11
  [ "$status" -eq 0 ]
  [ "$output" = "subagent" ]
  [ "$(calls '^orca worktree current')" -eq 2 ]
  printf '%s\n' '{"result":{"worktree":{"id":"repo-a::/work/parent","repoId":"repo-a","path":"/work/parent","parentWorktreeId":null}}}' > "$STUB_CFG/current_json"
  run dispatch route 11 12
  [ "$output" = "orca" ]
  [ "$(calls '^orca worktree list')" -eq 0 ]
}

@test "route: an unreadable list means not a child, with a warning" {
  make_stub orca
  set_child_of 420
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
  rm "$STUB_CFG/list_exit"
  printf '%s\n' '{"result":{}}' > "$STUB_CFG/list_json"
  run dispatch route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
}

@test "route: without jq the parent is not read and the route is as before, with a warning" {
  make_stub orca
  set_child_of 420
  run dispatch_nojq route 11 12
  [ "$status" -eq 0 ]
  [ "$output" = "orca" ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
  [ "$(calls '^orca worktree list')" -eq 0 ]
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
  grep -qF -- '--terminal <handle from create>' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: the recreate hint first tells to check for a terminal already running there" {
  make_stub orca
  touch "$STUB_CFG/tcreate_fail_11"
  run dispatch launch 420 11
  [ "$status" -eq 1 ]
  chk="$(grep -nF 'orca terminal list --worktree path:/work/issue-11 --json' "$BATS_TEST_TMPDIR/stderr" | head -1 | cut -d: -f1)"
  mk="$(grep -nF 'create: orca terminal create --worktree' "$BATS_TEST_TMPDIR/stderr" | head -1 | cut -d: -f1)"
  [ -n "$chk" ]
  [ -n "$mk" ]
  [ "$chk" -lt "$mk" ]
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
  grep -qF 'child epics are not expanded here' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: a parent worktree with a linked issue creates nothing, before git and set" {
  make_stub orca
  set_child_of 420
  run dispatch launch 460 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^git ')" -eq 0 ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  grep -F '420' "$BATS_TEST_TMPDIR/stderr" | grep -qF 'child epics are not expanded here'
}

@test "launch: an unreadable list under a parent worktree stops before git and set" {
  make_stub orca
  set_child_of 420
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch launch 460 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^git ')" -eq 0 ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  [ "$(calls '^orca worktree list')" -eq 1 ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
  rm "$STUB_CFG/list_exit"
  : > "$STUB_LOG"
  printf '%s\n' '{"result":{}}' > "$STUB_CFG/list_json"
  run dispatch launch 460 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^git ')" -eq 0 ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  [ "$(calls '^orca worktree create')" -eq 0 ]
  grep -qF 'could not read the parent worktree' "$BATS_TEST_TMPDIR/stderr"
}

@test "launch: without a parent worktree a failing list still comes after fetch and set" {
  make_stub orca
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch launch 400 11 12
  [ "$status" -eq 1 ]
  [ "$(calls '^git fetch ')" -eq 1 ]
  [ "$(calls '^orca worktree set')" -eq 1 ]
  [ "$(calls '^orca worktree list')" -eq 1 ]
  [ "$(first_line '^orca worktree set')" -lt "$(first_line '^orca worktree list')" ]
}

@test "launch: a parent worktree without a linked issue launches as before" {
  make_stub orca
  set_child_of null
  run dispatch launch 460 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
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

@test "launch: --note is posted once per child as an issue comment, before the terminal is created" {
  make_stub orca
  run dispatch launch --note "後続の範囲に手を出さない" 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "$(calls '^gh issue comment 11 --body ')" -eq 1 ]
  [ "$(calls '^gh issue comment 12 --body ')" -eq 1 ]
  [ "$(calls '^gh issue comment ')" -eq 2 ]
  for n in 11 12; do
    [ "$(sed -n 1p "$STUB_CFG/comment_$n")" = "親エピックからの注意書き: #400" ]
    [ -z "$(sed -n 2p "$STUB_CFG/comment_$n")" ]
    [ "$(sed -n 3p "$STUB_CFG/comment_$n")" = "後続の範囲に手を出さない" ]
    [ "$(first_line "^gh issue comment $n ")" -lt "$(first_line "^orca terminal create --worktree path:/work/issue-$n ")" ]
    [ "$(first_line "^gh issue comment $n ")" -gt "$(first_line "^orca worktree create --name issue-$n ")" ]
  done
}

@test "launch: without --note no comment is posted" {
  make_stub orca
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "launch: skipped children and children whose worktree create failed get no comment" {
  make_stub orca
  printf '%s\n' '{"result":{"worktrees":[{"repoId":"repo-a","linkedIssue":11,"isArchived":false}]}}' > "$STUB_CFG/list_json"
  touch "$STUB_CFG/create_fail_12"
  run dispatch launch --note "x" 400 11 12 13 13
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "skipped 11" ]
  [ "${lines[1]}" = "failed 12" ]
  [ "${lines[2]}" = "launched 13" ]
  [ "${lines[3]}" = "skipped 13" ]
  [ "$(calls '^gh issue comment ')" -eq 1 ]
  [ "$(calls '^gh issue comment 13 ')" -eq 1 ]
}

@test "launch: a child whose terminal could not be created still gets the comment" {
  make_stub orca
  touch "$STUB_CFG/tcreate_fail_11"
  run dispatch launch --note "x" 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(calls '^gh issue comment 11 ')" -eq 1 ]
}

@test "launch: a child with no worktree path in create still gets the comment" {
  make_stub orca
  printf '%s\n' '{"ok":true,"result":{}}' > "$STUB_CFG/create_json_11"
  run dispatch launch --note "x" 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  [ "$(calls '^gh issue comment 11 ')" -eq 1 ]
}

@test "launch: a failing comment does not change the result and prints the command to post it" {
  make_stub orca
  echo 1 > "$STUB_CFG/comment_exit"
  run dispatch launch --note "don't touch" 400 11
  [ "$status" -eq 0 ]
  [ "$output" = "launched 11" ]
  grep -qF 'note not posted to #11' "$BATS_TEST_TMPDIR/stderr"
  grep -qF "gh issue comment 11 --body '親エピックからの注意書き: #400" "$BATS_TEST_TMPDIR/stderr"
  grep -qF "don'\\''t touch'" "$BATS_TEST_TMPDIR/stderr"
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
  grep -F "orca terminal send --terminal 'term-11' --text" "$BATS_TEST_TMPDIR/stderr" | grep -qF '/develop #11'
  grep -qF "orca terminal read --terminal 'term-11'" "$BATS_TEST_TMPDIR/stderr"
  [ "$(grep -c -- '--retry-request' "$BATS_TEST_TMPDIR/stderr" || true)" -eq 0 ]
}

@test "launch: a retry request id from send is added to the resend command" {
  make_stub orca
  echo 1 > "$STUB_CFG/send_exit_term-11"
  printf '%s\n' '{"ok":false,"result":{"retryRequestId":"rq-1","stages":["input_accepted"]}}' > "$STUB_CFG/send_json_term-11"
  run dispatch launch 400 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
  grep -F "orca terminal send --terminal 'term-11'" "$BATS_TEST_TMPDIR/stderr" | grep -qF -- '--retry-request rq-1'
  grep -qF "orca terminal read --terminal 'term-11'" "$BATS_TEST_TMPDIR/stderr"
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

# --- mark ---

@test "mark: done on the linked workspace sets completed" {
  make_stub orca
  set_current 11
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 done" ]
  [ "$(calls '^orca worktree set --worktree current --workspace-status completed$')" -eq 1 ]
}

@test "mark: waiting sets in-review" {
  make_stub orca
  set_current 11
  run dispatch mark waiting 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 waiting" ]
  [ "$(calls '^orca worktree set --worktree current --workspace-status in-review$')" -eq 1 ]
}

@test "mark: another issue's workspace is not marked" {
  make_stub orca
  set_current 400
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 not-linked" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "mark: a workspace without a linked issue is not marked" {
  make_stub orca
  set_current null
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 not-linked" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
}

@test "mark: outside Orca and without orca it does nothing" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 no-workspace" ]
  [ "$(calls '^orca worktree set')" -eq 0 ]
  rm -f "$STUB_BIN/orca"; : > "$STUB_LOG"
  run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "skipped 11 no-workspace" ]
  [ ! -s "$STUB_LOG" ]
}

@test "mark: EPIC_DISPATCH_PARENT_EPIC does not change it" {
  make_stub orca
  set_current 11
  EPIC_DISPATCH_PARENT_EPIC=400 run dispatch mark done 11
  [ "$status" -eq 0 ]
  [ "$output" = "marked 11 done" ]
  [ "$(calls '^orca worktree set --worktree current --workspace-status completed$')" -eq 1 ]
}

@test "mark: a failing set ends with failed" {
  make_stub orca
  set_current 11
  echo 1 > "$STUB_CFG/set_exit"
  run dispatch mark done 11
  [ "$status" -eq 1 ]
  [ "$output" = "failed 11" ]
}

@test "mark: orca's own output goes to stderr" {
  make_stub orca
  set_current 11
  run dispatch mark done 11
  [ "${#lines[@]}" -eq 1 ]
  grep -qF '"ok":true' "$BATS_TEST_TMPDIR/stderr"
}

@test "mark: bad arguments are rejected without calling orca" {
  make_stub orca
  set_current 11
  run dispatch mark completed 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch mark done
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch mark done '#11'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch mark done 11 12
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca')" -eq 0 ]
  grep -qF 'usage:' "$BATS_TEST_TMPDIR/stderr"
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
  grep -qF '(poll 3)' "$BATS_TEST_TMPDIR/stderr"
  [ "$(grep -c 'mock failure' "$BATS_TEST_TMPDIR/stderr")" -eq 1 ]
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

@test "wait: --watch-done ends with done when the mark appears while the issue stays open" {
  make_stub orca
  set_current 400
  gh_seq 11 open
  set_list list_json_1 "$(wt_entry 11 in-review)"
  set_list list_json "$(wt_entry 11 completed)"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "done 11" ]
  [ "$(calls '^gh ')" -eq 2 ]
  [ "$(calls '^orca worktree list --json$')" -eq 2 ]
}

@test "wait: closed and done in the same poll print two lines, closed first" {
  make_stub orca
  set_current 400
  gh_seq 12 closed
  set_list list_json "$(wt_entry 11 completed)" "$(wt_entry 12 in-review)"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 --watch-done 12 12
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "closed 12" ]
  [ "${lines[1]}" = "done 11" ]
}

@test "wait: --watch-done alone waits without gh and times out with a bare timeout" {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 in-review)"
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "timeout" ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "wait: without --watch-done orca is never called" {
  make_stub orca
  gh_seq 11 closed
  run dispatch wait --interval 0 --timeout 60 11
  [ "$status" -eq 0 ]
  [ "$output" = "closed 11" ]
  [ "$(calls '^orca')" -eq 0 ]
}

@test "wait: marks on another repo or on archived worktrees do not count" {
  make_stub orca
  set_current 400
  set_list list_json "$(wt_entry 11 completed repo-b::/x repo-b)" "$(wt_entry 11 completed repo-a::/work/parent repo-a true)"
  run dispatch wait --interval 0 --timeout 0 --watch-done 11
  [ "$status" -eq 2 ]
  [ "$output" = "timeout" ]
}

@test "wait: three polls without a readable list end with error workspaces" {
  make_stub orca
  set_current 400
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 1 ]
  [ "$output" = "error workspaces" ]
  [ "$(calls '^orca worktree list')" -eq 3 ]
}

@test "wait: an unreadable list with a failing gh child ends with error gh" {
  make_stub orca
  set_current 400
  echo 1 > "$STUB_CFG/list_exit"
  gh_seq 12 FAIL
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 12
  [ "$status" -eq 1 ]
  [ "$output" = "error gh 12" ]
}

@test "wait: --watch-done fails with no stdout when the current worktree cannot be read" {
  make_stub orca
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^gh ')" -eq 0 ]
  rm -f "$STUB_BIN/orca"
  run dispatch wait --interval 0 --timeout 60 --watch-done 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "wait: a non-numeric --watch-done is rejected" {
  make_stub orca
  run dispatch wait --interval 0 --timeout 0 --watch-done '#11' 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch wait --interval 0 --timeout 0 --watch-done
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca')" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
}

# --- reap ---

@test "reap: a child meeting every condition is closed then removed, without --force" {
  reap_ready
  run dispatch reap 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$STUB_LOG"; false; }
  [ "$output" = "reaped 11" ]
  p="$BATS_TEST_TMPDIR/work/issue-11"
  close_line="$(grep -n "^orca terminal close --worktree path:$p --all$" "$STUB_LOG" | cut -d: -f1)"
  rm_line="$(grep -n "^orca worktree rm --worktree path:$p$" "$STUB_LOG" | cut -d: -f1)"
  [ -n "$close_line" ] && [ -n "$rm_line" ]
  [ "$close_line" -lt "$rm_line" ]
  [ "$(calls '^orca terminal close')" -eq 1 ]
  [ "$(calls '^orca worktree rm')" -eq 1 ]
  [ "$(calls '^orca .*--force')" -eq 0 ]
  grep -qF -- 'gh pr list --head oratta/issue-11 --state merged --json headRefOid' "$STUB_LOG"
}

@test "reap: a child off by one condition is kept with the reason" {
  p="$BATS_TEST_TMPDIR/work/issue-11"
  for c in not-done head-mismatch dirty llm-logs not-child; do
    rm -rf "$STUB_CFG" "$p"; mkdir -p "$STUB_CFG"; : > "$STUB_LOG"
    printf '%s\n' '/work/parent' > "$STUB_CFG/toplevel"
    reap_ready
    case "$c" in
      not-done) set_list list_json "$(wt_entry 11 in-review)" ;;
      head-mismatch) echo bbb222 > "$STUB_CFG/head" ;;
      dirty) echo ' M a.txt' > "$STUB_CFG/status_out" ;;
      llm-logs) mkdir -p "$p/LLM" ;;
      not-child) set_list list_json "$(wt_entry 11 completed repo-a::/work/other)" ;;
    esac
    echo aaa111 > "$STUB_CFG/branch_tip"
    run dispatch reap 11
    [ "$status" -eq 0 ] || { echo "$c: status=$status"; false; }
    [ "$output" = "kept 11 $c" ] || { echo "$c: output=$output"; false; }
    [ "$(calls '^orca terminal close')" -eq 0 ]
    [ "$(calls '^orca worktree rm')" -eq 0 ]
    [ "$(calls '^git branch -D')" -eq 0 ]
  done
}

@test "reap: a main worktree, a failing git status, and a detached HEAD are kept" {
  reap_ready
  p="$BATS_TEST_TMPDIR/work/issue-11"
  set_list list_json "$(wt_entry 11 completed | sed 's/"isMainWorktree":false/"isMainWorktree":true/')"
  run dispatch reap 11
  [ "$output" = "kept 11 not-child" ]
  set_list list_json "$(wt_entry 11 completed)"
  echo 128 > "$STUB_CFG/status_exit"
  run dispatch reap 11
  [ "$output" = "kept 11 git-failed" ]
  rm -f "$STUB_CFG/status_exit"
  set_list list_json "$(wt_entry 11 completed | sed 's#"branch":"refs/heads/oratta/issue-11"#"branch":""#')"
  run dispatch reap 11
  [ "$output" = "kept 11 no-branch" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

@test "reap: no merged PR or a failing PR lookup keeps the child" {
  reap_ready
  : > "$STUB_CFG/pr_out"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 no-merged-pr" ]
  echo 1 > "$STUB_CFG/pr_exit"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 pr-lookup-failed" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
}

@test "reap: any of several merged PR heads may match" {
  reap_ready
  printf '%s\n' ccc333 aaa111 > "$STUB_CFG/pr_out"
  run dispatch reap 11
  [ "$output" = "reaped 11" ]
}

@test "reap: a child with no worktree is gone, two candidates are ambiguous" {
  reap_ready
  set_list list_json
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "gone 11" ]
  [ "$(calls '^git ')" -eq 0 ]
  [ "$(calls '^gh ')" -eq 0 ]
  set_list list_json "$(wt_entry 11 completed)" "$(wt_entry 11 completed)"
  run dispatch reap 11
  [ "$output" = "kept 11 ambiguous" ]
}

@test "reap: a branch left behind is deleted only when its tip is the PR head" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11" ]
  [ "$(calls '^git branch -D oratta/issue-11$')" -eq 1 ]
  : > "$STUB_LOG"
  echo bbb222 > "$STUB_CFG/branch_tip"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11 branch-kept" ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: a failing branch -D is reported as branch-kept" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/branchd_exit"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "reaped 11 branch-kept" ]
}

@test "reap: no branch left means no git branch -D" {
  reap_ready
  run dispatch reap 11
  [ "$output" = "reaped 11" ]
  [ "$(calls '^git rev-parse --verify --quiet refs/heads/oratta/issue-11$')" -eq 1 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: a failing terminal close keeps the worktree" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/close_exit"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 close-failed" ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: a failing worktree rm keeps the branch" {
  reap_ready
  echo aaa111 > "$STUB_CFG/branch_tip"
  echo 1 > "$STUB_CFG/rm_exit"
  run dispatch reap 11
  [ "$status" -eq 0 ]
  [ "$output" = "kept 11 rm-failed" ]
  [ "$(calls '^git branch -D')" -eq 0 ]
}

@test "reap: several children are judged one by one, duplicates once" {
  reap_ready
  set_list list_json "$(wt_entry 11 completed)" "$(wt_entry 12 in-review)"
  run dispatch reap 11 12 11
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "reaped 11" ]
  [ "${lines[1]}" = "kept 12 not-done" ]
  [ "$(calls '^orca worktree rm')" -eq 1 ]
  [ "$(calls "^orca worktree rm --worktree path:$BATS_TEST_TMPDIR/work/issue-11$")" -eq 1 ]
  [ "$(calls '^orca worktree list')" -eq 1 ]
}

@test "reap: EPIC_DISPATCH_PARENT_EPIC does not change it" {
  reap_ready
  EPIC_DISPATCH_PARENT_EPIC=400 run dispatch reap 11
  [ "$output" = "reaped 11" ]
}

@test "reap: an unreadable list or current worktree removes nothing and prints nothing" {
  reap_ready
  echo 1 > "$STUB_CFG/list_exit"
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  rm -f "$STUB_CFG/list_exit"
  echo '{"result":{}}' > "$STUB_CFG/list_json"
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  echo 1 > "$STUB_CFG/current_exit"
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca terminal close')" -eq 0 ]
  [ "$(calls '^orca worktree rm')" -eq 0 ]
  rm -f "$STUB_BIN/orca"
  run dispatch reap 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "reap: no children or a non-numeric child is rejected" {
  reap_ready
  run dispatch reap
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run dispatch reap '#11'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^orca')" -eq 0 ]
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

@test "skill: the parent's note is a comment every restarted child session follows and hands on" {
  e="$(section 'エピックの扱い')"
  printf '%s\n' "$e" | grep -F '親エピックからの注意書き:' | grep -F '起動し直したセッション' | grep -qF 'W・R1・G'
  printf '%s\n' "$e" | grep -F 'note not posted to' | grep -qF '投稿'
}

@test "skill: the parent's note is followed only when its author is an owner, member or collaborator" {
  l="$(section 'エピックの扱い' | grep -F '親エピックからの注意書き:' | grep -F 'author_association')"
  [ -n "$l" ]
  printf '%s\n' "$l" | grep -F 'OWNER' | grep -F 'MEMBER' | grep -qF 'COLLABORATOR'
  printf '%s\n' "$l" | grep -F 'それ以外' | grep -F '従わず' | grep -F '渡さず' | grep -qF 'ユーザーに報告'
}

@test "skill: a restarted child session is nested and reads the parent epic from stderr" {
  e="$(section 'エピックの扱い')"
  printf '%s\n' "$e" | grep -F '起動し直したセッション' | grep -qF 'nested'
  printf '%s\n' "$e" | grep -qF 'parent epic: #'
  printf '%s\n' "$e" | grep -qF 'child epics are not expanded here'
  printf '%s\n' "$e" | grep -F 'parent epic:' | grep -F 'EPIC_DISPATCH_PARENT_EPIC' | grep -qF '親を持たないワークツリー'
}

@test "skill: a child whose terminal was not created is checked, recreated and sent before resuming" {
  e="$(section 'エピックの扱い')"
  printf '%s\n' "$e" | grep -F '端末を作れなかった' | grep -F '既存の端末が無いこと' | grep -F '作り直し' | grep -qF '動き出したのを確かめてから再開'
}

@test "skill: held-back child epics are recorded also when route is skipped (unmanned, resumed)" {
  e="$(section 'エピックの扱い' | grep -F 'sub_issues_summary')"
  printf '%s\n' "$e" | grep -F '後で別に起動するエピック:' | grep -F 'でないと確定' | grep -F 'unmanned' | grep -qF '回し方:'
}

@test "skill: the end of a loop never asks about worktree cleanup and marks the workspace last" {
  e="$(section 'ループの終わり')"
  [ -n "$e" ]
  printf '%s\n' "$e" | grep -F 'worktree の片付けを提案も質問もしない' | grep -qF '完了報告'
  printf '%s\n' "$e" | grep -qF '/wt-clean'
  printf '%s\n' "$e" | grep -qF '親セッション'
  printf '%s\n' "$e" | grep -F 'epic-dispatch.sh mark <done|waiting>' | grep -qF '最後のツール呼び出し'
  printf '%s\n' "$e" | grep -F '`waiting`' | grep -qF '動作確認'
  printf '%s\n' "$e" | grep -F '`done` で呼び直す' | grep -qF '済んだ'
  printf '%s\n' "$e" | grep -F '呼ばない' | grep -F 'マージされていない' | grep -qF 'Draft PR'
  printf '%s\n' "$e" | grep -qF '端末を閉じて'
  grep -n "worktree" "$SKILL" | grep -qF 'worktree の片付けを提案も質問もしない'
}

@test "skill: Orca route watches for done marks and reaps marked children" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -qF -- '--watch-done'
  printf '%s\n' "$r" | grep -qF 'epic-dispatch.sh reap <N>...'
  printf '%s\n' "$r" | grep -qF '子 #N のワークツリーを残した（<理由>）'
  printf '%s\n' "$r" | grep -qF '子 #N のローカルブランチを残した'
  printf '%s\n' "$r" | grep -F 'not-done' | grep -qF '待ちを続ける'
  printf '%s\n' "$r" | grep -F '手で消し直さない' | grep -qF 'wt-clean は呼ばず'
  printf '%s\n' "$r" | grep -F '開いている子が無くなったら' | grep -qF '待ちをやめる'
  printf '%s\n' "$r" | grep -F '再開したら' | grep -qF '`launch` の前に'
  printf '%s\n' "$r" | grep -qF 'error workspaces'
  printf '%s\n' "$r" | grep -F -- '--watch-done' | grep -qF '親ワークツリーで開き直す'
}

@test "skill: Orca route drops reaped and gone children from the done-watch set" {
  r="$(run_section)"
  printf '%s\n' "$r" | grep -F '片付け待ちの子は' | grep -F '`reaped <N>`' | grep -F '`gone <N>`' | grep -qF '除いた'
  printf '%s\n' "$r" | grep -F '片付け待ちの子は' | grep -F 'branch-kept' | grep -qF '`launched <N>`'
  printf '%s\n' "$r" | grep -F '`reaped <N>` と `gone <N>`' | grep -qF '片付け待ちから外す'
  printf '%s\n' "$r" | grep -F '開いている子が無くなったら' | grep -F '0 件' | grep -qF '`wait` を呼ばず'
  printf '%s\n' "$r" | grep -F '開いている子が無くなったら' | grep -F '`kept <N> not-done` の子だけ' | grep -qF -- '--watch-done'
  printf '%s\n' "$r" | grep -F '再開したら' | grep -qF '片付け待ちから外す'
}

@test "skill: develop's docs run no orca subcommand and only epic-dispatch.sh calls orca" {
  run grep -rnE 'orca [a-z]+' "$PLUGIN_DIR/skills/develop"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run grep -rlw orca "$PLUGIN_DIR" --include='*.sh'
  [ "$status" -eq 0 ]
  [ "$output" = "$PLUGIN_DIR/scripts/epic-dispatch.sh" ]
}
