#!/usr/bin/env bats
#
# Tests for change-4 (worktree-command-dedup) — SKILL.md safety preservation.
# spec: worktree-command-wrapper (S9, S10).
#
# The SKILL.md is the single source of truth. These tests guard that the
# safety-critical wording (squash detection A/B/C, "prefer the real tree diff",
# SQUASHED handling, and the AskUserQuestion separate-turn absolute prohibition)
# is preserved verbatim and not lost by this change.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

# --- S9: squash detection A/B/C stays in SKILL.md verbatim ---

@test "skill: wt-clean SKILL.md keeps kensho A tree-diff verification" {
  grep -q '検証A' "$WT_CLEAN_SKILL"
  grep -q 'TREE_DIFF' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md keeps kensho B git cherry verification" {
  grep -q '検証B' "$WT_CLEAN_SKILL"
  grep -q 'git cherry' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md keeps kensho C gh pr MERGED verification" {
  grep -q '検証C' "$WT_CLEAN_SKILL"
  grep -q 'gh pr list' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md prefers the real tree diff when verdicts differ" {
  grep -q '実ツリー差分（検証A）を優先' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md keeps SQUASHED not-red rule" {
  grep -q 'SQUASHED' "$WT_CLEAN_SKILL"
  # squash 済み（SQUASHED 非空）は AHEAD_COUNT>0 でも 🔴 にしない
  grep -q 'AHEAD_COUNT > 0.*でも 🔴 にしない' "$WT_CLEAN_SKILL"
}

# --- S10: AskUserQuestion separate-turn absolute prohibition stays in SKILL.md ---

@test "skill: wt-clean SKILL.md keeps AskUserQuestion same-turn parallel prohibition" {
  grep -q '同一ターンの並列ツール呼び出しに含めてはならない' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md keeps 'execute in a separate turn after answer'" {
  grep -q '回答を受け取った後の、別のアシスタントターンで' "$WT_CLEAN_SKILL"
}

# --- wt-setup SKILL.md keeps Step 1-6 (the source of truth for setup) ---

@test "skill: wt-setup SKILL.md keeps the setup script invocation" {
  grep -q 'wt-setup.sh' "$WT_SETUP_SKILL"
}

@test "skill: wt-setup SKILL.md keeps the Draft PR bootstrap" {
  grep -q 'gh pr create' "$WT_SETUP_SKILL"
}
