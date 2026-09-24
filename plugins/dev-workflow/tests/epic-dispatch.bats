#!/usr/bin/env bats
# epic-dispatch.sh（エピックの子の経路判定・起動・待ち受け）の振る舞いを、
# orca / gh / git / sleep を PATH 上のスタブにして確かめる。あわせて develop の SKILL.md
# 「エピックの扱い」の回し方と「前提」表に、この経路の記述があることを確かめる。
#
# スタブは自分の名前と引数（printf '%q'）を共通のログ（${STUB_LOG}）に 1 行ずつ追記する。
# 返り値は $STUB_CFG の設定ファイルで切り替える:
#   orca: current_exit / current_json / list_exit / list_json / set_exit / create_fail_<N>
#         （create の --prompt の値は prompt_<N> に書き出す）
#   git : toplevel（rev-parse の出力）/ fetch_exit
#   gh  : gh_<N> に 1 呼び出し 1 行の返り値（open / closed / FAIL / 空行）。最後の行を繰り返す。
#         呼び出し回数は ghcount_<N>
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
    printf "%s" "$prompt" > "$STUB_CFG/prompt_$issue"
    echo "{\"ok\":true}"
    [ -e "$STUB_CFG/create_fail_$issue" ] && exit 1
    exit 0 ;;
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
[ "$val" = "FAIL" ] && exit 1
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
calls() { grep -c -- "$1" "$STUB_LOG" || true; }

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

# --- launch ---

@test "launch: call order is current, toplevel, fetch, set, list, then create per child" {
  make_stub orca
  run dispatch launch 400 11 12
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "launched 11" ]
  [ "${lines[1]}" = "launched 12" ]
  [ "${#lines[@]}" -eq 2 ]
  log=()
  while IFS= read -r l; do log+=("$l"); done < "$STUB_LOG"
  [ "${#log[@]}" -eq 7 ]
  [ "${log[0]}" = "orca worktree current --json" ]
  [ "${log[1]}" = "git rev-parse --show-toplevel" ]
  [ "${log[2]}" = "git fetch origin main" ]
  [ "${log[3]}" = "orca worktree set --worktree path:/work/parent --issue 400" ]
  [ "${log[4]}" = "orca worktree list --json" ]
  starts_with "${log[5]}" "orca worktree create --name issue-11 --issue 11 --base-branch origin/main --parent-worktree path:/work/parent --agent claude --prompt "
  starts_with "${log[6]}" "orca worktree create --name issue-12 --issue 12 --base-branch origin/main --parent-worktree path:/work/parent --agent claude --prompt "
  case "${log[5]}" in *' --json') ;; *) echo "create must end with --json" >&2; false ;; esac
}

@test "launch: prompt starts with /develop #N and names the epic" {
  make_stub orca
  run dispatch launch 400 11
  [ "$status" -eq 0 ]
  p="$(cat "$STUB_CFG/prompt_11")"
  starts_with "$p" "/develop #11 "
  printf '%s' "$p" | grep -qF '#400'
  printf '%s' "$p" | grep -qF '/work/parent'
}

@test "launch: --note text is appended to every child prompt" {
  make_stub orca
  run dispatch launch --note "do not touch the follow-up scope" 400 11 12
  [ "$status" -eq 0 ]
  grep -qF 'do not touch the follow-up scope' "$STUB_CFG/prompt_11"
  grep -qF 'do not touch the follow-up scope' "$STUB_CFG/prompt_12"
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

@test "launch: without orca on PATH nothing is called" {
  run dispatch launch 400 11 12
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
  printf '%s\n' "$r" | grep -qF -- '--dangerously-skip-permissions'
  printf '%s\n' "$r" | grep -qF 'pr-review-gate'
  printf '%s\n' "$r" | grep -qF '自動でマージしない'
}

@test "skill: prerequisites table has an orca row with the subagent fallback" {
  p="$(section '前提' | grep -F '**`orca`**')"
  [ -n "$p" ]
  printf '%s\n' "$p" | grep -qF 'Orca 管理外'
  printf '%s\n' "$p" | grep -qF 'サブエージェント方式'
}
