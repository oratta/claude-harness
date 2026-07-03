#!/usr/bin/env bash
#
# Shared bats helper for plugins/weekly-report/tests/*.bats
#
# Modeled on plugins/daily-report/tests/helper.bash (change-5:
# report-plugins-update). Kept intentionally minimal — weekly-report tests
# are static grep/structure checks against SKILL.md / commands, not
# behavioral simulations of the (non-deterministic) sub-agent flow.
#
# Conventions:
#   - PLUGIN_DIR  : absolute path to plugins/weekly-report
#   - PLUGIN_ROOT : repository root (git toplevel)
#
# Usage:
#   load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"
#   setup() {
#     wr_setup_paths
#   }

# Resolve repo + plugin paths once. Idempotent.
wr_setup_paths() {
  PLUGIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL_FILE="${PLUGIN_DIR}/skills/weekly-report/SKILL.md"
  COMMAND_FILE="${PLUGIN_DIR}/commands/weekly-report.md"
  export PLUGIN_DIR PLUGIN_ROOT SKILL_FILE COMMAND_FILE
}

# Create a per-test tmp dir. Caller is responsible for cleanup via
# wr_teardown_tmpdir in their teardown().
wr_make_tmpdir() {
  WR_TEST_TMPDIR="$(mktemp -d)"
  export WR_TEST_TMPDIR
}

wr_teardown_tmpdir() {
  if [ -n "${WR_TEST_TMPDIR:-}" ] && [ -d "${WR_TEST_TMPDIR}" ]; then
    rm -rf "${WR_TEST_TMPDIR}"
  fi
}
