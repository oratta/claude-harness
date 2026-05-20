#!/usr/bin/env bash
#
# Shared bats helper for plugins/daily-report/tests/*.bats
#
# Initialized by change-0 (agent-mcp-spike) as common scaffolding so that
# change-2 (voice-compactor) and change-3 (llm-log-compactor) worktrees can
# both author bats tests without colliding on directory initialization.
#
# Conventions:
#   - PLUGIN_DIR  : absolute path to plugins/daily-report
#   - PLUGIN_ROOT : repository root (git toplevel)
#   - FIXTURES_DIR: absolute path to plugins/daily-report/tests/fixtures
#                   (directory may not yet exist; create on demand in tests)
#
# Usage:
#   load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"
#   setup() {
#     dr_setup_paths
#   }

# Resolve repo + plugin paths once. Idempotent.
dr_setup_paths() {
  PLUGIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  FIXTURES_DIR="${PLUGIN_DIR}/tests/fixtures"
  export PLUGIN_DIR PLUGIN_ROOT FIXTURES_DIR
}

# Create a per-test tmp dir. Caller is responsible for cleanup via
# dr_teardown_tmpdir in their teardown().
dr_make_tmpdir() {
  DR_TEST_TMPDIR="$(mktemp -d)"
  export DR_TEST_TMPDIR
}

dr_teardown_tmpdir() {
  if [ -n "${DR_TEST_TMPDIR:-}" ] && [ -d "${DR_TEST_TMPDIR}" ]; then
    rm -rf "${DR_TEST_TMPDIR}"
  fi
}

# Skip a test gracefully if the named file is missing. Used while changes
# land incrementally and a script/agent is not yet present.
dr_require_file() {
  local path="$1"
  [ -f "$path" ] || skip "required file not yet present: $path"
}
