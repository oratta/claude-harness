#!/usr/bin/env bats
#
# Tests for change-5 capability: report-command-hygiene (daily-report side)
# Spec: openspec/changes/report-plugins-update/specs/report-command-hygiene/spec.md
#
# Covers verification-guide.md scenario S10 for change-5.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  dr_setup_paths
  COMMAND_FILE="${PLUGIN_DIR}/commands/daily-report.md"
}

# --- S10: allowed-tools に Agent が含まれる ---

@test "S10: daily-report.md frontmatter allowed-tools includes Agent" {
  line=$(grep -m1 '^allowed-tools:' "$COMMAND_FILE")
  echo "$line" | grep -Eq '(^|,\s*)Agent(,|\s*$)'
}
