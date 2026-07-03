#!/usr/bin/env bats
#
# Tests for change-5 capability: report-noninteractive-mode (weekly-report side)
# Spec: openspec/changes/report-plugins-update/specs/report-noninteractive-mode/spec.md
#
# Covers verification-guide.md scenarios S12-S15 (weekly-report portion) for change-5.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wr_setup_paths
}

# --- S12: weekly-report SKILL.md に非対話モード節が存在する ---

@test "S12: SKILL.md has a non-interactive mode section" {
  grep -Eq '非対話' "$SKILL_FILE"
}

@test "S12: non-interactive section documents default target week is last week" {
  grep -q '先週' "$SKILL_FILE"
}

# --- S13: AskUserQuestion 不可時はデフォルト値で続行する ---

@test "S13: SKILL.md documents skipping AskUserQuestion when unavailable" {
  grep -q 'AskUserQuestion' "$SKILL_FILE"
}

# --- S14: 対話依存ステップがファイル出力に代替される ---

@test "S14: SKILL.md documents substituting interactive steps with file output" {
  grep -Eq '(ファイル出力|プレースホルダー)' "$SKILL_FILE"
}

# --- S15: 判断ログが出力に残る ---

@test "S15: SKILL.md documents recording a decision log in the generated output" {
  grep -q '判断ログ' "$SKILL_FILE"
}
