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
# NOTE (change-3 / longrun-v5-cleanup, design.md D6): this change bumps
# plugin.json's version but does not touch marketplace.json (deferred to
# change-7). The marketplace-parity assertions below are therefore relaxed to
# not require plugin.json == marketplace.json mid-change; they only assert
# marketplace.json still parses and still has a longrun entry.

@test "plugin.json: longrun version is 6.4.1" {
  # merged: main 6.4.0 (PR #10) + this branch patch -> 6.4.1. See decisions.md D-5b/D-5d.
  v="$(jq -r '.version' "$PLUGIN_JSON")"
  [ "$v" = "6.4.1" ]
}

@test "marketplace.json: still contains a longrun plugins[] entry (version sync deferred to change-7)" {
  v="$(jq -r '.plugins[] | select(.name=="longrun") | .version' "$MARKETPLACE_JSON")"
  [ -n "$v" ]
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
