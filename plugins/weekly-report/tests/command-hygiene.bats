#!/usr/bin/env bats
#
# Tests for change-5 capability: report-command-hygiene (weekly-report side)
# Spec: openspec/changes/report-plugins-update/specs/report-command-hygiene/spec.md
#
# Covers verification-guide.md scenarios S8-S9 for change-5.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wr_setup_paths
}

# --- S8: 存在しない旧パスへの参照が無い ---

@test "S8: command does not reference nonexistent .claude/skills/weekly-report/SKILL.md" {
  ! grep -q '\.claude/skills/weekly-report/SKILL\.md' "$COMMAND_FILE"
}

# --- S9: plugin-relative パスで SKILL.md を参照している ---

@test "S9: command references plugin-relative skills/weekly-report/SKILL.md" {
  grep -q 'skills/weekly-report/SKILL\.md' "$COMMAND_FILE"
}
