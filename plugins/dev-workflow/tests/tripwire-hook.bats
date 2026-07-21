#!/usr/bin/env bats
#
# dev-workflow-tripwire-session-hook: SessionStart hook によるトリップワイヤー常駐注入
#
# spec: dev-workflow-escalation-tripwires（SessionStart hook 要件）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/session-tripwires.sh"
  TEMPLATE="${PLUGIN_DIR}/templates/escalation-tripwires.md"
  TMPDIR_EMPTY="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_EMPTY"
}

@test "hooks.json: exists and parses" {
  [ -f "$HOOKS_JSON" ]
  python3 -c "import json;json.load(open('$HOOKS_JSON'))"
}

@test "hooks.json: has SessionStart entry with matcher and CLAUDE_PLUGIN_ROOT command" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
entries = d["hooks"]["SessionStart"]
e = entries[0]
assert e["matcher"] == "startup|clear|compact", e.get("matcher")
cmd = e["hooks"][0]["command"]
assert e["hooks"][0]["type"] == "command"
assert "${CLAUDE_PLUGIN_ROOT}" in cmd, cmd
assert "session-tripwires.sh" in cmd, cmd
PY
}

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "script: outputs valid JSON additionalContext containing the tripwire section" {
  run env CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" "$SCRIPT"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
ctx = d["additionalContext"]
for kw in ("昇格トリップワイヤー", "規模超過", "失敗ループ", "仕様の発明"):
    assert kw in ctx, kw
PY
}

@test "script: fail-soft when template is missing (exit 0, no output)" {
  run env CLAUDE_PLUGIN_ROOT="$TMPDIR_EMPTY" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "template: intro documents hook-based default and optional manual copy" {
  grep -q 'SessionStart' "$TEMPLATE"
  grep -Eq 'オプション|プラグイン未導入' "$TEMPLATE"
}
