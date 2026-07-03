#!/usr/bin/env bats
#
# Tests for change-5 capability: weekly-report-jsonl-direct
# Spec: openspec/changes/report-plugins-update/specs/weekly-report-jsonl-direct/spec.md
#
# Covers verification-guide.md scenarios S1-S7 for change-5.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wr_setup_paths
}

# --- S1: Step 3b が LLM/*.md への参照を持たない ---

@test "S1: SKILL.md does not reference {source_path}/LLM" {
  ! grep -q '{source_path}/LLM' "$SKILL_FILE"
}

# --- S2: Step 3b が native jsonl を参照する ---

@test "S2: SKILL.md references ~/.claude/projects" {
  grep -q '~/.claude/projects' "$SKILL_FILE"
}

@test "S2: SKILL.md documents jq-based session extraction" {
  grep -q 'jq' "$SKILL_FILE"
}

# --- S3: llm-log-compactor のロジックを流用している旨が明記されている ---

@test "S3: SKILL.md credits daily-report agents/llm-log-compactor.md as source" {
  grep -q 'plugins/daily-report/agents/llm-log-compactor.md' "$SKILL_FILE"
}

# --- S4: 個人パスのハードコードが無い ---

@test "S4: SKILL.md does not hardcode /Users/oratta/Dropbox/WorkSpace" {
  ! grep -q '/Users/oratta/Dropbox/WorkSpace' "$SKILL_FILE"
}

# --- S5: 環境変数未設定時にフェイルソフトする ---

@test "S5: SKILL.md documents WORKSPACE_ROOT fail-soft (subsection omitted when unset)" {
  grep -q 'WORKSPACE_ROOT' "$SKILL_FILE"
  # Must document the fail-soft behavior (skip/omit), not a hard error/prompt
  grep -Eq '(未設定.*(省略|スキップ)|省略.*未設定)' "$SKILL_FILE"
}

# --- S6: 1h-cooking 言及が残っていない ---

@test "S6: SKILL.md has no 1h-cooking mention (case-insensitive)" {
  ! grep -iq '1h-cooking' "$SKILL_FILE"
}

# --- S7: harvest の実態に沿った検索パターンが記載されている ---

@test "S7: SKILL.md documents data/sessions/<slug>.jsonl search pattern" {
  grep -q 'data/sessions/' "$SKILL_FILE"
  grep -q '\.jsonl' "$SKILL_FILE"
}
