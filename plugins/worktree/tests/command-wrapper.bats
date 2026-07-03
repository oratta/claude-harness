#!/usr/bin/env bats
#
# Tests for change-4 (worktree-command-dedup) — command wrapper de-duplication.
# spec: worktree-command-wrapper (S1-S8, S11).
#
# Verifies:
#   - wt-clean.md / wt-setup.md are thin wrappers that Read the SKILL.md
#   - the diagnostic table / squash-detection body / setup step bodies were
#     removed from the command files (single source of truth = SKILL.md)
#   - frontmatter (allowed-tools / argument-hint) is preserved
#   - $ARGUMENTS is passed through to the SKILL.md execution

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

# --- S1: wt-clean command Reads SKILL.md and executes inline ---

@test "wt-clean: command instructs to Read skills/wt-clean/SKILL.md" {
  grep -q 'skills/wt-clean/SKILL.md' "$WT_CLEAN_CMD"
  grep -q 'Read' "$WT_CLEAN_CMD"
}

@test "wt-clean: command references CLAUDE_PLUGIN_ROOT for SKILL.md location" {
  grep -q 'CLAUDE_PLUGIN_ROOT' "$WT_CLEAN_CMD"
}

@test "wt-clean: command includes marketplace/installed fallback search" {
  grep -q 'marketplaces/\*/plugins/worktree/skills/wt-clean' "$WT_CLEAN_CMD"
  grep -q 'installed/\*/worktree/skills/wt-clean' "$WT_CLEAN_CMD"
}

# --- S2: no diagnostic-classification table duplicated into the command ---

@test "wt-clean: command has no diagnostic classification table (green safe)" {
  run grep -F '🟢 Safe' "$WT_CLEAN_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-clean: command has no diagnostic classification table (red active)" {
  run grep -F '🔴 Active' "$WT_CLEAN_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-clean: command has no recoverable classification body" {
  run grep -F '🟡 Recoverable' "$WT_CLEAN_CMD"
  [ "$status" -ne 0 ]
}

# --- S3: no squash-detection procedure duplicated into the command ---

@test "wt-clean: command has no TREE_DIFF squash procedure" {
  run grep -F 'TREE_DIFF' "$WT_CLEAN_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-clean: command has no SQUASHED squash procedure" {
  run grep -F 'SQUASHED' "$WT_CLEAN_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-clean: command has no git cherry squash procedure" {
  run grep -F 'git cherry' "$WT_CLEAN_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-clean: command has no kensho A/B/C verification body" {
  run grep -E '検証 ?A' "$WT_CLEAN_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-clean: command has no AHEAD_COUNT classification body" {
  run grep -F 'AHEAD_COUNT' "$WT_CLEAN_CMD"
  [ "$status" -ne 0 ]
}

# --- S4: wt-setup command Reads SKILL.md and executes inline ---

@test "wt-setup: command instructs to Read skills/wt-setup/SKILL.md" {
  grep -q 'skills/wt-setup/SKILL.md' "$WT_SETUP_CMD"
  grep -q 'Read' "$WT_SETUP_CMD"
}

@test "wt-setup: command references CLAUDE_PLUGIN_ROOT for SKILL.md location" {
  grep -q 'CLAUDE_PLUGIN_ROOT' "$WT_SETUP_CMD"
}

@test "wt-setup: command includes marketplace/installed fallback search" {
  grep -q 'marketplaces/\*/plugins/worktree/skills/wt-setup' "$WT_SETUP_CMD"
  grep -q 'installed/\*/worktree/skills/wt-setup' "$WT_SETUP_CMD"
}

# --- S5: no setup step bodies duplicated into the command ---

@test "wt-setup: command has no wt-setup.sh invocation block" {
  run grep -F 'wt-setup.sh' "$WT_SETUP_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-setup: command has no gh pr create --draft bootstrap procedure" {
  run grep -F 'gh pr create' "$WT_SETUP_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-setup: command has no .worktreeinclude generation body" {
  run grep -F '.worktreeinclude' "$WT_SETUP_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-setup: command has no NEEDS_NPM_INSTALL dependency-step body" {
  run grep -F 'NEEDS_NPM_INSTALL' "$WT_SETUP_CMD"
  [ "$status" -ne 0 ]
}

# --- S6: wt-clean frontmatter preserves allowed-tools ---

@test "wt-clean: frontmatter allowed-tools includes AskUserQuestion, Read, Bash" {
  fm="$(wt_frontmatter "$WT_CLEAN_CMD")"
  line="$(echo "$fm" | grep '^allowed-tools:')"
  echo "$line" | grep -q 'AskUserQuestion'
  echo "$line" | grep -q 'Read'
  echo "$line" | grep -q 'Bash'
}

# --- S7: wt-setup frontmatter preserves allowed-tools + argument-hint ---

@test "wt-setup: frontmatter preserves allowed-tools" {
  fm="$(wt_frontmatter "$WT_SETUP_CMD")"
  echo "$fm" | grep -q '^allowed-tools:'
}

@test "wt-setup: frontmatter preserves argument-hint with --with-pr" {
  fm="$(wt_frontmatter "$WT_SETUP_CMD")"
  line="$(echo "$fm" | grep '^argument-hint:')"
  [ -n "$line" ]
  echo "$line" | grep -q -- '--with-pr'
}

# --- S8: $ARGUMENTS is passed through to SKILL.md execution ---

@test "wt-clean: command passes \$ARGUMENTS through to SKILL.md" {
  grep -q 'ARGUMENTS' "$WT_CLEAN_CMD"
}

@test "wt-setup: command passes \$ARGUMENTS through to SKILL.md" {
  grep -q 'ARGUMENTS' "$WT_SETUP_CMD"
}

# --- S11: command has no independent flow definition (structural single-path) ---

@test "wt-clean: command does not redefine the Step 0/A/B/C flow" {
  # The full flow (Step 0 → A → B → C headings) must live only in SKILL.md.
  run grep -E '^### Step (0|A|B|C)' "$WT_CLEAN_CMD"
  [ "$status" -ne 0 ]
}

@test "wt-setup: command does not redefine the Step 1-6 flow" {
  run grep -E '^### Step [1-6]' "$WT_SETUP_CMD"
  [ "$status" -ne 0 ]
}
