#!/usr/bin/env bats
setup() {
  unset DEVELOP_ROLE
  bats_require_minimum_version 1.5.0
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}
@test "claude-role-launch: fake CLI launch, validation and lifecycle contracts" {
  run python3 "$PLUGIN_DIR/tests/test_claude_role_launch.py"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
    return 1
  fi
}
