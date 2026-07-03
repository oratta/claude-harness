#!/usr/bin/env bats
#
# Tests for change-6 (plugin-retirement), capability: plugin-retirement-cleanup
# spec: openspec/changes/plugin-retirement/specs/plugin-retirement-cleanup/spec.md (S9-S19)

setup() {
  RUN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "$RUN_DIR/../.." && pwd)"
  MARKETPLACE_JSON="${REPO_ROOT}/.claude-plugin/marketplace.json"
  README="${REPO_ROOT}/README.md"
  CONTRIBUTING="${REPO_ROOT}/CONTRIBUTING.md"
}

# --- S9: Plugin directories are absent ---

@test "S9: plugins/obsidian-llm-session-rules and plugins/skill-aware-workflow do not exist" {
  [ ! -d "${REPO_ROOT}/plugins/obsidian-llm-session-rules" ]
  [ ! -d "${REPO_ROOT}/plugins/skill-aware-workflow" ]
}

# --- S10: Deletion is git-tracked ---

@test "S10: deletion of both plugin directories appears as tracked commits" {
  cd "$REPO_ROOT"
  run git log --diff-filter=D -- plugins/obsidian-llm-session-rules plugins/skill-aware-workflow
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

# --- S11: plugins[] array excludes both entries ---

@test "S11: marketplace.json plugins[] excludes both retired plugin names" {
  run jq -e '[.plugins[].name] | index("obsidian-llm-session-rules")' "$MARKETPLACE_JSON"
  [ "$output" = "null" ]
  run jq -e '[.plugins[].name] | index("skill-aware-workflow")' "$MARKETPLACE_JSON"
  [ "$output" = "null" ]
}

# --- S12: "all" bundle no longer lists retired plugins ---

@test "S12: bundles[] 'all' plugins[] excludes both retired plugin names" {
  run jq -e '(.bundles[] | select(.name == "all") | .plugins) | index("obsidian-llm-session-rules")' "$MARKETPLACE_JSON"
  [ "$output" = "null" ]
  run jq -e '(.bundles[] | select(.name == "all") | .plugins) | index("skill-aware-workflow")' "$MARKETPLACE_JSON"
  [ "$output" = "null" ]
}

# --- S13: Only entry removal appears in the diff (structural check: valid JSON, other plugin fields present) ---

@test "S13: marketplace.json is valid JSON and remaining plugins keep version/description fields" {
  run jq -e '.' "$MARKETPLACE_JSON"
  [ "$status" -eq 0 ]
  # spot-check a handful of surviving plugin entries still have version+description
  run jq -e '.plugins[] | select(.name=="longrun") | .version and .description' "$MARKETPLACE_JSON"
  [ "$status" -eq 0 ]
  run jq -e '.plugins[] | select(.name=="worktree") | .version and .description' "$MARKETPLACE_JSON"
  [ "$status" -eq 0 ]
}

# --- S14: Zero plugin-name references outside archive/_longruns ---

@test "S14: zero references to retired plugin names outside plugins/, README.md, docs/" {
  cd "$REPO_ROOT"
  run grep -rln "obsidian-llm-session-rules\|skill-aware-workflow" plugins/ README.md docs/
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# --- S15: Zero skill-name references outside archive/_longruns/this-change ---

@test "S15: zero references to the nine retired skill names outside archive/_longruns/this-change" {
  cd "$REPO_ROOT"
  run bash -c 'grep -rlnE "session-logger|context-reader|research-workflow|pre-task-orchestrator|task-analyzer|skill-inventory|skill-finder|execution-tracker|skill-proposer" . \
    | grep -vE "^(\./)?openspec/changes/archive/" \
    | grep -vE "^(\./)?_longruns/" \
    | grep -vE "^(\./)?openspec/changes/plugin-retirement/"'
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# --- S16: Illustrative examples use generic names ---

@test "S16: CONTRIBUTING.md NG-pattern examples use generic names, not retired skill names" {
  run grep -nE "session-logger|context-reader|research-workflow|pre-task-orchestrator|task-analyzer|skill-inventory|skill-finder|execution-tracker|skill-proposer" "$CONTRIBUTING"
  [ "$status" -ne 0 ]
}

# --- S17: Quickstart install commands cleaned ---

@test "S17: README.md quickstart section has no install commands for retired plugins" {
  run bash -c "awk '/^## クイックスタート/,/^## /' \"$README\" | grep -c '^## '"
  # extract just the quickstart block (from its heading to the next heading)
  block="$(awk '/^## クイックスタート/{flag=1; next} /^## /{if (flag) exit} flag' "$README")"
  ! grep -q "skill-aware-workflow@oratta-claude-harness" <<< "$block"
  ! grep -q "obsidian-llm-session-rules@oratta-claude-harness" <<< "$block"
}

# --- S18: Plugin catalog sections removed ---

@test "S18: README.md has no ### skill-aware-workflow or ### obsidian-llm-session-rules subsection" {
  run grep -n "^### skill-aware-workflow$" "$README"
  [ "$status" -ne 0 ]
  run grep -n "^### obsidian-llm-session-rules$" "$README"
  [ "$status" -ne 0 ]
}

# --- S19: Local development examples cleaned ---

@test "S19: README.md local-dev section has no /plugin add for retired plugins" {
  block="$(awk '/^## ローカル開発/{flag=1; next} /^## /{if (flag) exit} flag' "$README")"
  ! grep -q "/plugin add ./plugins/skill-aware-workflow" <<< "$block"
  ! grep -q "/plugin add ./plugins/obsidian-llm-session-rules" <<< "$block"
}
