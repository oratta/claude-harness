#!/usr/bin/env bats
#
# Tests for change-2 task 4.x — legacy command removal & orchestrator dismantle.
# spec: legacy-command-removal (S21 / S22 / S23 / S25).
#
# Verifies:
#   - the 4 command files no longer exist
#   - no residual /longrun:status /longrun:decisions /lr:s /lr:d functional refs in
#     the scoped surface (plugin.json / README / commands/*.md / marketplace.json)
#   - orchestrator skill dir is gone and removed from plugin.json skills[]
#   - longrun version is 6.2.0 (bumped by change-4); lr stays 6.1.0 across the 2 sync locations

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  LR_DIR="${PLUGIN_ROOT}/plugins/lr"
  LONGRUN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  LR_JSON="${LR_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE_JSON="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
  README="${PLUGIN_DIR}/README.md"
}

# --- S21: command files removed ---

@test "legacy: status.md / decisions.md / s.md / d.md do not exist" {
  [ ! -f "${PLUGIN_DIR}/commands/status.md" ]
  [ ! -f "${PLUGIN_DIR}/commands/decisions.md" ]
  [ ! -f "${LR_DIR}/commands/s.md" ]
  [ ! -f "${LR_DIR}/commands/d.md" ]
}

# --- S22: grep zero residual functional refs in scoped JSON/command surface ---
# We assert on the machine-consumed registration fields (commands[] arrays and
# description strings), not on README prose that documents the removal.

@test "legacy: lr plugin.json commands[] has no s.md / d.md" {
  run jq -r '.commands[]' "$LR_JSON"
  ! echo "$output" | grep -qE '/s\.md|/d\.md'
}

@test "legacy: longrun plugin.json commands[] has no status.md / decisions.md" {
  run jq -r '.commands[]' "$LONGRUN_JSON"
  ! echo "$output" | grep -qE 'status\.md|decisions\.md'
}

@test "legacy: lr plugin.json description has no /lr:s /lr:d" {
  d="$(jq -r '.description' "$LR_JSON")"
  ! echo "$d" | grep -qE '/lr:s|/lr:d'
}

@test "legacy: longrun plugin.json description has no orchestrator / status / decisions refs" {
  d="$(jq -r '.description' "$LONGRUN_JSON")"
  ! echo "$d" | grep -qE 'orchestrator|/longrun:status|/longrun:decisions|--mode=mvp|v5\.2|SKILL.md インライン'
}

@test "legacy: marketplace.json lr description has no /lr:s /lr:d" {
  d="$(jq -r '.plugins[] | select(.name=="lr") | .description' "$MARKETPLACE_JSON")"
  ! echo "$d" | grep -qE '/lr:s|/lr:d'
}

@test "legacy: marketplace.json longrun description has no status/decisions/orchestrator refs" {
  d="$(jq -r '.plugins[] | select(.name=="longrun") | .description' "$MARKETPLACE_JSON")"
  ! echo "$d" | grep -qE '/longrun:status|/longrun:decisions|orchestrator'
}

@test "legacy: README command table has no status/decisions/s/d rows" {
  # The command table rows (lines starting with | `/longrun:...`) must not list
  # the removed commands. Prose mentioning the removal is allowed elsewhere.
  ! grep -E '^\| `/longrun:(status|decisions)`' "$README"
  ! grep -E '^\| .*`/lr:s`.*\| 進捗' "$README"
}

@test "legacy: exec.md has no progress-check section pointing to /longrun:status or openspec list" {
  # The old 末尾「実行中の進捗確認」section pointed at /longrun:status + openspec list.
  ! grep -Eq '実行中の進捗確認' "${PLUGIN_DIR}/commands/exec.md"
  ! grep -Eq '`/longrun:status` コマンドで現在の状態' "${PLUGIN_DIR}/commands/exec.md"
}

# --- S23: orchestrator skill dismantled ---

@test "legacy: orchestrator skill directory does not exist" {
  [ ! -d "${PLUGIN_DIR}/skills/longrun-orchestrator" ]
}

@test "legacy: longrun plugin.json skills[] has no orchestrator" {
  run jq -r '.skills[]' "$LONGRUN_JSON"
  ! echo "$output" | grep -q 'orchestrator'
}

# --- S25: version sync ---
# NOTE (change-3 / longrun-v5-cleanup, design.md D6): plugin.json versions are
# bumped by this change (longrun 6.3.0 / lr 6.2.0), but marketplace.json sync
# is deferred to change-7 per plan.md's dependency note. Assertions below only
# check plugin.json's own value and that marketplace.json still has entries.

@test "legacy: longrun plugin.json version is 6.4.1" {
  # merged: main took 6.4.0 (PR #10), this branch adds a patch on top -> 6.4.1 for the self-verification
  # section added to longrun-plan/SKILL.md. See decisions.md D-5b.
  a="$(jq -r '.version' "$LONGRUN_JSON")"
  [ "$a" = "6.4.1" ]
}

@test "legacy: lr plugin.json version is 6.2.0" {
  a="$(jq -r '.version' "$LR_JSON")"
  [ "$a" = "6.2.0" ]
}

@test "legacy: marketplace.json still has longrun and lr entries (version sync deferred to change-7)" {
  bl="$(jq -r '.plugins[] | select(.name=="longrun") | .version' "$MARKETPLACE_JSON")"
  br="$(jq -r '.plugins[] | select(.name=="lr") | .version' "$MARKETPLACE_JSON")"
  [ -n "$bl" ]
  [ -n "$br" ]
}

@test "legacy: all touched JSON parses (jq)" {
  jq empty "$LONGRUN_JSON"
  jq empty "$LR_JSON"
  jq empty "$MARKETPLACE_JSON"
}
