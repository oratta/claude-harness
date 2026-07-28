#!/usr/bin/env bats
# work-issue command の fail-soft 縮退手順が承認判断 2 節を含むことの検証（issue #47）
#
# spec: dev-workflow-issue-entry (MODIFIED), loops-pr-body-format

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CMD="$PLUGIN_DIR/commands/work-issue.md"
  MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
}

@test "fail-soft: minimal draft includes what-changes section" {
  grep -q 'これで何が変わるか' "$CMD"
}

@test "fail-soft: minimal draft includes cost-of-inaction section" {
  grep -q 'やらないとどうなるか' "$CMD"
}

@test "fail-soft: existing minimal sections remain" {
  grep -q '測定可能な受け入れ条件' "$CMD"
}

@test "manifest: dev-workflow version is greater than 1.5.0" {
  python3 - "$MANIFEST" <<'PY'
import json, sys
v = json.load(open(sys.argv[1]))["version"]
assert tuple(map(int, v.split("."))) > (1, 5, 0), v
PY
}
