#!/usr/bin/env bats
#
# capability-registry-browser-guard: ブラウザツール PreToolUse hook
#
# spec: capability-registry-browser-guard

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/browser-guard.sh"
  WORK="$(mktemp -d)"
  export TMPDIR="$WORK"
}

teardown() {
  rm -rf "$WORK"
}

hook_input() {
  printf '{"session_id":"%s","tool_name":"%s","tool_input":{}}' "$1" "$2"
}

@test "hooks.json: exists and parses" {
  [ -f "$HOOKS_JSON" ]
  python3 -c "import json;json.load(open('$HOOKS_JSON'))"
}

@test "hooks.json: PreToolUse matcher targets browser MCP tools only" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
e = d["hooks"]["PreToolUse"][0]
matcher = e["matcher"]
assert re.fullmatch(matcher, "mcp__claude-in-chrome__navigate"), matcher
assert re.fullmatch(matcher, "mcp__playwright__browser_click"), matcher
assert not re.fullmatch(matcher, "Bash"), matcher
assert not re.fullmatch(matcher, "Read"), matcher
cmd = e["hooks"][0]["command"]
assert e["hooks"][0]["type"] == "command"
assert "${CLAUDE_PLUGIN_ROOT}" in cmd, cmd
assert "browser-guard.sh" in cmd, cmd
PY
}

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "first call: allow + additionalContext warning injected" {
  run bash -c "hook_input() { printf '{\"session_id\":\"%s\",\"tool_name\":\"%s\"}' \"\$1\" \"\$2\"; }; hook_input sess-first mcp__claude-in-chrome__navigate | '$SCRIPT'"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
h = d["hookSpecificOutput"]
assert h["hookEventName"] == "PreToolUse"
assert h["permissionDecision"] == "allow"
ctx = h["additionalContext"]
for kw in ("CLI", "fmtoken", "capability-registry"):
    assert kw in ctx, kw
PY
}

@test "same session second call: no output, exit 0 (dedup)" {
  hook_input sess-dup mcp__claude-in-chrome__navigate | "$SCRIPT" >/dev/null
  run bash -c "printf '{\"session_id\":\"sess-dup\",\"tool_name\":\"mcp__claude-in-chrome__computer\"}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "different session: warning appears again" {
  hook_input sess-a mcp__claude-in-chrome__navigate | "$SCRIPT" >/dev/null
  run bash -c "printf '{\"session_id\":\"sess-b\",\"tool_name\":\"mcp__claude-in-chrome__navigate\"}' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "fail-soft: empty stdin still exits 0" {
  run bash -c "printf '' | '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "fail-soft: unwritable marker dir still exits 0 (never blocks)" {
  run bash -c "printf '{\"session_id\":\"sess-x\",\"tool_name\":\"mcp__claude-in-chrome__navigate\"}' | TMPDIR=/nonexistent-dir-xyz '$SCRIPT'"
  [ "$status" -eq 0 ]
}
