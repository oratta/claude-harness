#!/usr/bin/env bats
#
# git-guard-base-write-guard.sh: PreToolUse（Write|Edit|NotebookEdit）で、子が git ガードの置き場所
# （${TMPDIR:-/tmp}/dev-workflow-git-guard）に書くのを止める。
# spec: destructive-git-hook「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」
#       「置き場所への書き込みを止める hook の配線と逃げ道」「許可の置き場所への書き込みの拒否は親に返すよう案内する」

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/git-guard-base-write-guard.sh"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  unset DEV_WORKFLOW_GIT_GUARD
  # 本物の置き場所に触らないよう、テストごとの空のディレクトリに向ける
  export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  mkdir -p "$TMPDIR"
  T="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$TMPDIR")"
}

# write_payload <tool_name> <path> [agent_id(JSON か "-")] [cwd]
write_payload() {
  python3 -c '
import json, sys
tool, path, agent, cwd = sys.argv[1:5]
field = "notebook_path" if tool == "NotebookEdit" else "file_path"
p = {"tool_name": tool, "tool_input": {field: path, "content": "{}"}, "hook_event_name": "PreToolUse",
     "session_id": "s1"}
if agent != "-":
    p["agent_id"] = json.loads(agent)
if cwd != "-":
    p["cwd"] = cwd
print(json.dumps(p))' "$1" "$2" "${3:--}" "${4:--}"
}

# call_write <tool_name> <path> [agent_id] [cwd]
call_write() {
  local json
  json="$(write_payload "$1" "$2" "${3:--}" "${4:--}")"
  run "$SCRIPT" <<<"$json"
}

decision() {
  python3 -c '
import json, sys
try:
    print(json.loads(sys.stdin.read())["hookSpecificOutput"]["permissionDecision"])
except Exception:
    pass' <<<"$output"
}

reason() {
  python3 -c '
import json, sys
print(json.loads(sys.stdin.read())["hookSpecificOutput"]["permissionDecisionReason"])' <<<"$output"
}

has_continue() {
  python3 -c '
import json, sys
sys.exit(0 if "continue" in json.loads(sys.stdin.read()) else 1)' <<<"$output"
}

expect_deny() {
  [ "$status" -eq 0 ] || { echo "status=$status"; return 1; }
  [ "$(decision)" = "deny" ] || { echo "not denied: [$output]"; return 1; }
}

expect_silent() {
  [ "$status" -eq 0 ] || { echo "status=$status"; return 1; }
  [ -z "$output" ] || { echo "unexpected output: [$output]"; return 1; }
}

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "write: Write, Edit and NotebookEdit into the base are denied and nothing is created" {
  call_write Write "$T/dev-workflow-git-guard/permits/k.json" '"a1"'
  expect_deny
  ! has_continue || return 1
  call_write Edit "$T/dev-workflow-git-guard/$(printf 'x%.0s' {1..64})" '"a1"'
  expect_deny
  ! has_continue || return 1
  call_write NotebookEdit "$T/dev-workflow-git-guard/x.ipynb" '"a1"'
  expect_deny
  ! has_continue || return 1
  [ -z "$(ls -A "$T")" ] || { ls -la "$T"; return 1; }
}

@test "write: other spellings of the base path are denied" {
  call_write Write "$T/Dev-Workflow-Git-Guard/permits/k.json" '"a1"'
  expect_deny
  call_write Write "$T/x/../dev-workflow-git-guard/permits/k.json" '"a1"'
  expect_deny
  call_write Write "dev-workflow-git-guard/permits/k.json" '"a1"' "$T"
  expect_deny
  mkdir -p "$T/dev-workflow-git-guard"
  ln -s "$T/dev-workflow-git-guard" "$T/link"
  call_write Write "$T/link/permits/k.json" '"a1"'
  expect_deny
  # 相対パスは cwd を前に付けてから symlink を辿る（付けなければ名前の出ない書き先を見逃す）
  call_write Write "link/permits/k.json" '"a1"' "$T"
  expect_deny
}

@test "write: the main session and writes outside the base are not stopped" {
  call_write Write "$T/dev-workflow-git-guard/permits/k.json"
  expect_silent
  call_write Write "$T/dev-workflow-git-guard/permits/k.json" '""'
  expect_silent
  call_write Write "$T/dev-workflow-git-guard/permits/k.json" '7'
  expect_silent
  call_write Write "plugins/dev-workflow/tests/git-destructive-guard.bats" '"a1"' "$PLUGIN_DIR/../.."
  expect_silent
  call_write Write "$T/notes/dev-workflow-git-guard.md" '"a1"'
  expect_silent
  local json
  json="$(write_payload Write "$T/dev-workflow-git-guard/permits/k.json" '"a1"')"
  DEV_WORKFLOW_GIT_GUARD=off run "$SCRIPT" <<<"$json"
  expect_silent
  run "$SCRIPT" <<<'{"tool_name":"Bash","tool_input":{"command":"x dev-workflow-git-guard"},"agent_id":"a1"}'
  expect_silent
  run "$SCRIPT" <<<'not json agent_id dev-workflow-git-guard'
  expect_silent
  run "$SCRIPT" <<<'["agent_id"]'
  expect_silent
  run "$SCRIPT" <<<'{"tool_name":"Write","tool_input":{"file_path":7},"agent_id":"a1"}'
  expect_silent
  [ -z "$(ls -A "$T")" ] || { ls -la "$T"; return 1; }
}

@test "write: a name written with \\u escapes is still seen" {
  # 名前と agent_id の両方を \u で書き、早期判定の \u00 の枝だけが本体を起こす形にする
  run "$SCRIPT" <<<'{"tool_name":"Write","tool_input":{"file_path":"/x/\u0064ev-workflow-git-guard/k.json"},"\u0061gent_id":"a1"}'
  expect_deny
}

@test "write: the reason sends the child back and does not list both names" {
  call_write Write "$T/dev-workflow-git-guard/permits/k.json" '"a1"'
  local r
  r="$(reason)"
  [[ "$r" == *'許可の置き場所'* ]] || { echo "$r"; return 1; }
  [[ "$r" == *'親に返す'* ]] || { echo "$r"; return 1; }
  [[ "$r" == *'打ち直さず'* ]] || { echo "$r"; return 1; }
  [[ "$r" != *dev-workflow-git-guard* || "$r" != *permits* ]] || { echo "$r"; return 1; }
}

@test "write: the base name matches BASE_NAME in the shared git-guard file" {
  local shared
  shared="$(python3 -I -c '
import sys
ns = {"__name__": "x"}
exec(compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec"), ns)
print(ns["BASE_NAME"])' "${PLUGIN_DIR}/scripts/git-guard-scratchpad.py")"
  [ "$shared" = "dev-workflow-git-guard" ]
  grep -q "^BASE_NAME = \"${shared}\"$" "$SCRIPT"
  grep -q "\*${shared}\*)" "$SCRIPT"
}

@test "hooks.json: the write guard is registered on Write|Edit|NotebookEdit without if, before the git guard" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
pre = json.load(open(sys.argv[1]))["hooks"]["PreToolUse"]
cmd = '"${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-base-write-guard.sh"'
idx = [i for i, e in enumerate(pre) if any(h.get("command") == cmd for h in e.get("hooks", []))]
assert len(idx) == 1, idx
e = pre[idx[0]]
assert e["matcher"] == "Write|Edit|NotebookEdit", e
assert "if" not in e, e
for h in e["hooks"]:
    assert h["type"] == "command" and "if" not in h, h
last = pre[-1]
assert last["matcher"] == "Bash", last
assert last["hooks"][0]["command"] == '"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh"', last
assert idx[0] < len(pre) - 1
PY
}
