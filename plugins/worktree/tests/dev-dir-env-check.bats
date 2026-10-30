#!/usr/bin/env bats
#
# SessionStart hook scripts/dev-dir-env-check.sh (#1234)
# spec: worktree-dev-dir-env-warning

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
  CHECK_SH="${PLUGIN_DIR}/scripts/dev-dir-env-check.sh"
  HARNESS="$(wt_make_repo harness)"
  mkdir -p "$HARNESS/.claude-plugin"
  echo '{"name":"oratta-claude-harness","plugins":[]}' >"$HARNESS/.claude-plugin/marketplace.json"
  OTHER="$(wt_make_repo other)"
  mkdir -p "$OTHER/.claude-plugin"
  echo '{"name":"someone-else"}' >"$OTHER/.claude-plugin/marketplace.json"
}

run_in() { # $1=dir ; env passed by caller
  cd "$1" && run bash "$CHECK_SH" </dev/null
}

@test "unset in harness repo: one-line warning, exit 0" {
  unset CLAUDE_HARNESS_DEV_DIR
  run_in "$HARNESS"
  [ "$status" -eq 0 ]
  [[ "$output" == *CLAUDE_HARNESS_DEV_DIR* ]]
  [[ "$output" == *README* ]]
  python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert "\n" not in d["systemMessage"]' "$output"
}

@test "empty string counts as unset" {
  CLAUDE_HARNESS_DEV_DIR="" run_in "$HARNESS"
  [ "$status" -eq 0 ]
  [[ "$output" == *CLAUDE_HARNESS_DEV_DIR* ]]
}

@test "set (even to a nonexistent path): silent" {
  CLAUDE_HARNESS_DEV_DIR="/no/such/path" run_in "$HARNESS"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "other repo: silent" {
  unset CLAUDE_HARNESS_DEV_DIR
  run_in "$OTHER"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "outside git: silent" {
  unset CLAUDE_HARNESS_DEV_DIR
  run_in "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "broken marketplace.json: silent, exit 0" {
  unset CLAUDE_HARNESS_DEV_DIR
  echo '{broken' >"$HARNESS/.claude-plugin/marketplace.json"
  run_in "$HARNESS"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "works from a subdirectory of the harness repo" {
  unset CLAUDE_HARNESS_DEV_DIR
  mkdir -p "$HARNESS/sub"
  run_in "$HARNESS/sub"
  [[ "$output" == *CLAUDE_HARNESS_DEV_DIR* ]]
}

@test "script is executable, passes bash -n, and is wired in hooks.json" {
  [ -x "$CHECK_SH" ]
  run bash -n "$CHECK_SH"
  [ "$status" -eq 0 ]
  run grep -c 'dev-dir-env-check.sh' "$HOOKS_JSON"
  [ "$output" -ge 1 ]
}
