#!/usr/bin/env bash
#
# Shared bats helper for plugins/loops/tests/*.bats
#
# Conventions:
#   - PLUGIN_DIR  : absolute path to plugins/loops
#   - PLUGIN_ROOT : repository root
#
# Usage:
#   load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"
#   setup() { loops_setup_paths; }

loops_setup_paths() {
  PLUGIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  export PLUGIN_DIR PLUGIN_ROOT
}
