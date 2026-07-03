#!/usr/bin/env bats
#
# Tests for change-6 (plugin-retirement), capability: retirement-handoff-docs
# spec: openspec/changes/plugin-retirement/specs/retirement-handoff-docs/spec.md (S20-S24)

setup() {
  RUN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "$RUN_DIR/../.." && pwd)"
  BACKLOG="${REPO_ROOT}/openspec/backlog.md"
  POST_MERGE="${RUN_DIR}/post-merge-steps.md"
}

# --- S20: Section is resolved, not left dangling ---

@test "S20: backlog.md Skill naming-refactor section is absent or reduced to a single generic note" {
  if grep -q "^## Skill 命名規則リファクタリング$" "$BACKLOG"; then
    # if the heading remains, none of the nine retired skill names may be
    # spelled out individually below it (up to the next H2 / separator)
    block="$(awk '/^## Skill 命名規則リファクタリング/{flag=1; next} /^## /{if (flag) exit} flag' "$BACKLOG")"
    ! grep -qE "session-logger|context-reader|research-workflow|pre-task-orchestrator|task-analyzer|skill-inventory|skill-finder|execution-tracker|skill-proposer" <<< "$block"
  fi
}

# --- S21: No orphaned rename-target table remains ---

@test "S21: backlog.md has no rename-target table mapping retired skills to new names" {
  run grep -n "提案リネーム" "$BACKLOG"
  [ "$status" -ne 0 ]
}

# --- S22: Uninstall and reload commands present ---

@test "S22: post-merge-steps.md contains both /plugin uninstall commands and /reload-plugins" {
  [ -f "$POST_MERGE" ]
  grep -qF "/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness" "$POST_MERGE"
  grep -qF "/plugin uninstall skill-aware-workflow@oratta-claude-harness" "$POST_MERGE"
  grep -qF "/reload-plugins" "$POST_MERGE"
}

# --- S23: enabledPlugins cleanup guidance present ---

@test "S23: post-merge-steps.md instructs removing both keys from settings.local.json enabledPlugins" {
  [ -f "$POST_MERGE" ]
  grep -qF "enabledPlugins" "$POST_MERGE"
  grep -qF "obsidian-llm-session-rules@oratta-claude-harness" "$POST_MERGE"
  grep -qF "skill-aware-workflow@oratta-claude-harness" "$POST_MERGE"
}

# --- S24: Evacuation report and uninstall instructions share one file ---

@test "S24: post-merge-steps.md contains both uninstall instructions and the LLM/ evacuation report" {
  [ -f "$POST_MERGE" ]
  grep -qF "/plugin uninstall" "$POST_MERGE"
  grep -qiE "衝突|collision" "$POST_MERGE"
}
