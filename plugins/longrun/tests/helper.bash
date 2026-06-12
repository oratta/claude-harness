#!/usr/bin/env bash
#
# Shared bats helper for plugins/longrun/tests/*.bats
#
# Introduced by change-1 (openspec-degradation) as the first test directory
# for the longrun plugin. Subsequent changes (change-2 onward) can reuse this
# scaffolding.
#
# Conventions:
#   - PLUGIN_DIR  : absolute path to plugins/longrun
#   - PLUGIN_ROOT : repository root (git toplevel)
#   - FIXTURES_DIR: absolute path to plugins/longrun/tests/fixtures
#                   (directory may not yet exist; create on demand in tests)
#
# Usage:
#   load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"
#   setup() {
#     lr_setup_paths
#   }

# Resolve repo + plugin paths once. Idempotent.
lr_setup_paths() {
  PLUGIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  FIXTURES_DIR="${PLUGIN_DIR}/tests/fixtures"
  export PLUGIN_DIR PLUGIN_ROOT FIXTURES_DIR
}

# Create a per-test tmp dir. Caller must clean up via lr_teardown_tmpdir.
lr_make_tmpdir() {
  LR_TEST_TMPDIR="$(mktemp -d)"
  export LR_TEST_TMPDIR
}

lr_teardown_tmpdir() {
  if [ -n "${LR_TEST_TMPDIR:-}" ] && [ -d "${LR_TEST_TMPDIR}" ]; then
    rm -rf "${LR_TEST_TMPDIR}"
  fi
}

# Skip a test gracefully if the named file is missing. Used while changes
# land incrementally and a script is not yet present.
lr_require_file() {
  local path="$1"
  [ -f "$path" ] || skip "required file not yet present: $path"
}

# Create a fake git repo at $1 (so `git rev-parse --show-toplevel` resolves
# there). Used to test the openspec/ init-detection branch deterministically.
lr_make_git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
}
