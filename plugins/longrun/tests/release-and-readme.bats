#!/usr/bin/env bats
#
# Tests for change-1 release artifacts (tasks 5.x):
#   - README documents the degraded mode (発動条件 / 成果物パス / 既知の制限)
#   - README states /longrun:status has no degraded branch
#   - version 3-way sync: plugin.json == marketplace.json plugins[] longrun == 5.3.0
#   - marketplace top-level version was bumped strictly above the prior 2.5.1
#   - all touched JSON parses (jq syntax)

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  README="${PLUGIN_DIR}/README.md"
  PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE_JSON="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

# --- README (task 5.1) ---

@test "README: has an OpenSpec degraded-mode section" {
  grep -Eq '縮退モード' "$README"
}

@test "README: documents activation conditions (NO_CLI/NO_INIT/OK)" {
  grep -q 'NO_CLI' "$README"
  grep -q 'NO_INIT' "$README"
}

@test "README: documents self-contained artifact paths under run dir" {
  grep -Eq '_longruns/<run>/' "$README"
  grep -Eq '\.degraded-mode' "$README"
}

@test "README: states /longrun:status is NOT degraded-aware (known limitation)" {
  grep -Eq '/longrun:status.*非対応|status.*縮退.*非対応|status.*縮退モードに非対応' "$README"
}

@test "README: states change-2 will retire status" {
  grep -Eq 'change-2.*廃止|廃止予定' "$README"
}

@test "README: states no regression for normal-mode repos" {
  grep -Eq '回帰|regression' "$README"
}

# --- version sync (task 5.2 / S of plan acceptance 19) ---

@test "plugin.json: longrun version is 5.3.0" {
  v="$(jq -r '.version' "$PLUGIN_JSON")"
  [ "$v" = "5.3.0" ]
}

@test "marketplace.json: longrun plugins[] entry is 5.3.0" {
  v="$(jq -r '.plugins[] | select(.name=="longrun") | .version' "$MARKETPLACE_JSON")"
  [ "$v" = "5.3.0" ]
}

@test "version 3-way sync: plugin.json == marketplace plugins[] longrun" {
  a="$(jq -r '.version' "$PLUGIN_JSON")"
  b="$(jq -r '.plugins[] | select(.name=="longrun") | .version' "$MARKETPLACE_JSON")"
  [ "$a" = "$b" ]
}

@test "marketplace top-level version bumped above 2.5.1" {
  v="$(jq -r '.version' "$MARKETPLACE_JSON")"
  # strictly greater than the prior 2.5.1 (we set 2.6.0)
  [ "$v" != "2.5.1" ]
  # sort -V puts 2.5.1 strictly before the new value
  lowest="$(printf '%s\n%s\n' "$v" "2.5.1" | sort -V | head -1)"
  [ "$lowest" = "2.5.1" ]
}

# --- JSON syntax (build-equivalent) ---

@test "plugin.json: valid JSON (jq)" {
  jq empty "$PLUGIN_JSON"
}

@test "marketplace.json: valid JSON (jq)" {
  jq empty "$MARKETPLACE_JSON"
}
