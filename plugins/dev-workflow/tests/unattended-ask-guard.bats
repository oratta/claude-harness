#!/usr/bin/env bats
#
# 無人の印のあるセッションで AskUserQuestion を拒否する PreToolUse hook（issue #1153）
#
#   scripts/unattended-ask-guard.sh   hook の本体（bash だけ。payload は判定に使わない）
#   hooks/hooks.json                  PreToolUse（matcher AskUserQuestion）への登録
#
# 印の読み方は git ガード（tests/git-destructive-guard.bats の DEV_WORKFLOW_UNATTENDED の値の表）と
# 同じ値の表で確かめ、2 つの実装の読み方が揃っていることを保つ。
#
# spec: unattended-ask-hook

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOK="${PLUGIN_DIR}/scripts/unattended-ask-guard.sh"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  unset DEV_WORKFLOW_UNATTENDED DEV_WORKFLOW_GIT_GUARD_NO_ASK DEV_WORKFLOW_GIT_GUARD || true
}

# payload <permission_mode> [agent_id]
payload() {
  local agent=""
  [ -n "${2-}" ] && agent=",\"agent_id\":\"$2\""
  printf '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"q","options":[{"label":"a"},{"label":"b"}]}]},"permission_mode":"%s"%s}' "$1" "$agent"
}

# call_env <VAR=値>... -- <permission_mode> [agent_id] — 環境を絞って hook を起動する
call_env() {
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  local p; p="$(payload "$@")"
  run env -u DEV_WORKFLOW_UNATTENDED -u DEV_WORKFLOW_GIT_GUARD_NO_ASK -u DEV_WORKFLOW_GIT_GUARD \
    ${envs[@]+"${envs[@]}"} bash -c 'printf "%s" "$1" | "$2"' _ "$p" "$HOOK"
}

# 出力が deny の JSON であることを確かめる
assert_deny() {
  [ "$status" -eq 0 ] || { echo "status=$status output=$output" >&2; return 1; }
  printf '%s' "$output" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
h = d["hookSpecificOutput"]
assert h["hookEventName"] == "PreToolUse", h
assert h["permissionDecision"] == "deny", h
assert isinstance(h["permissionDecisionReason"], str) and h["permissionDecisionReason"], h
' || { echo "deny の JSON でない: $output" >&2; return 1; }
}

assert_silent() {
  [ "$status" -eq 0 ] || { echo "status=$status" >&2; return 1; }
  [ -z "$output" ] || { echo "何か出力した: $output" >&2; return 1; }
}

@test "hooks.json registers exactly one PreToolUse AskUserQuestion entry for the guard" {
  run python3 -I - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
hits = [e for e in d["hooks"]["PreToolUse"] if e.get("matcher") == "AskUserQuestion"]
assert len(hits) == 1, hits
cmds = [h["command"] for h in hits[0]["hooks"]]
assert cmds == ['"${CLAUDE_PLUGIN_ROOT}/scripts/unattended-ask-guard.sh"'], cmds
assert "if" not in hits[0], hits[0]
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "hook script is executable and does not call python3" {
  [ -x "$HOOK" ]
  ! grep -v '^[[:space:]]*#' "$HOOK" | grep -q 'python3' || return 1
}

@test "marked session: deny for default and bypassPermissions, with and without agent_id" {
  local m a
  for m in default bypassPermissions; do
    for a in "" a1; do
      call_env DEV_WORKFLOW_UNATTENDED=1 -- "$m" $a
      assert_deny
    done
  done
}

@test "mark value is read the same way as the git guard" {
  local v
  # 未設定
  call_env -- default
  assert_silent
  for v in '' '   ' '0' ' 0 '; do
    call_env "DEV_WORKFLOW_UNATTENDED=$v" -- default
    assert_silent
  done
  for v in '1' ' true ' 'yes'; do
    call_env "DEV_WORKFLOW_UNATTENDED=$v" -- default
    assert_deny
  done
}

@test "git guard mark and escape hatch do not change the decision" {
  call_env DEV_WORKFLOW_GIT_GUARD_NO_ASK=1 -- default
  assert_silent
  call_env DEV_WORKFLOW_UNATTENDED=1 DEV_WORKFLOW_GIT_GUARD=off -- bypassPermissions
  assert_deny
}

@test "unreadable payload still follows the mark" {
  run env -u DEV_WORKFLOW_UNATTENDED DEV_WORKFLOW_UNATTENDED=1 bash -c 'printf "not json" | "$1"' _ "$HOOK"
  assert_deny
  run env -u DEV_WORKFLOW_UNATTENDED bash -c 'printf "not json" | "$1"' _ "$HOOK"
  assert_silent
}

@test "deny reason guides asking in the channel and ending the turn" {
  call_env DEV_WORKFLOW_UNATTENDED=1 -- default
  assert_deny
  local r
  r="$(printf '%s' "$output" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecisionReason"])')"
  [ "${r#\[dev-workflow unattended-ask-guard\]}" != "$r" ] || { echo "先頭の印が無い: $r" >&2; return 1; }
  local t
  for t in 'DEV_WORKFLOW_UNATTENDED' '打ち直さず' 'chat_id' '返信ツール' 'ターンを終える' 'needs-approval' '番号' 'communication-style' 'return'; do
    printf '%s' "$r" | grep -qF -- "$t" || { echo "理由文に無い: $t" >&2; return 1; }
  done
}
