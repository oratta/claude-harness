#!/usr/bin/env bats
#
# Deterministic tests for the 2-phase pipeline control logic that lives
# inside plugins/daily-report/skills/daily-report/SKILL.md.
#
# Tests cover:
#   (c) STATUS line parser regex
#   (d) intermediate-file existence check
#   (e) Phase 1 sanity check (line-count lower-bound)
#
# These tests exercise the canonical bash snippets that the SKILL.md
# documents. We do NOT spawn agents (impossible in unit tests) — we only
# validate the surrounding control plane.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  dr_setup_paths
  dr_make_tmpdir
  SKILL_FILE="${PLUGIN_DIR}/skills/daily-report/SKILL.md"
}

teardown() {
  dr_teardown_tmpdir
}

# --- Skill-level structural checks ---

@test "skill: declares Phase 1 and Phase 2 sections" {
  grep -Eq '^## ?Phase ?1' "$SKILL_FILE"
  grep -Eq '^## ?Phase ?2' "$SKILL_FILE"
}

@test "skill: documents --force-rebuild flag" {
  grep -q "force-rebuild" "$SKILL_FILE"
}

@test "skill: documents parallel agent launch (single message, 2 tool_use)" {
  # Either Japanese or English wording is acceptable
  grep -Eq '(単一メッセージ.*2 ?つ|並列起動|parallel.*tool_use)' "$SKILL_FILE"
}

@test "skill: removes ToolSearch Notion loading from main" {
  ! grep -Eq 'ToolSearch.*Notion' "$SKILL_FILE"
}

@test "skill: does not Read jsonl body directly from main" {
  # The previous head -5 / python3 jsonl parser block must be gone
  ! grep -Eq "head -5 .*\.jsonl|head -5 \"\\\$f\"" "$SKILL_FILE"
}

@test "skill: sanity check threshold (<50 lines warning) is documented" {
  grep -Eq '(< ?50 ?行|less than 50 lines|50 ?lines)' "$SKILL_FILE"
}

# --- Rule (c): STATUS line parser ---
#
# The skill must parse sub-agent STATUS lines via regex anchored at "^STATUS: ".
# We validate the canonical parser snippet works for all 3 STATUS variants
# plus the special "fail reason=notion-mcp-unavailable" branch.

@test "STATUS parser: matches 'STATUS: ok'" {
  line="STATUS: ok pages=12"
  echo "$line" | grep -Eq '^STATUS: (ok|partial|fail)\b'
  echo "$line" | grep -Eq '^STATUS: ok\b'
}

@test "STATUS parser: matches 'STATUS: partial pages=N missing=[..]'" {
  line="STATUS: partial pages=10 missing=[20:00,21:00]"
  echo "$line" | grep -Eq '^STATUS: partial\b'
  # Captures pages number
  pages=$(echo "$line" | sed -nE 's/^STATUS: partial pages=([0-9]+).*/\1/p')
  [ "$pages" = "10" ]
}

@test "STATUS parser: matches 'STATUS: fail reason=<msg>'" {
  line="STATUS: fail reason=notion-mcp-unavailable"
  echo "$line" | grep -Eq '^STATUS: fail reason=[a-z0-9-]+'
  reason=$(echo "$line" | sed -nE 's/^STATUS: fail reason=([a-z0-9-]+).*/\1/p')
  [ "$reason" = "notion-mcp-unavailable" ]
}

@test "STATUS parser: distinguishes notion-mcp-unavailable from other fails" {
  # voice-compactor fail with this reason = fallback to dailyLLM.md only
  line1="STATUS: fail reason=notion-mcp-unavailable"
  line2="STATUS: fail reason=database-not-found"
  reason1=$(echo "$line1" | sed -nE 's/^STATUS: fail reason=([a-z0-9-]+).*/\1/p')
  reason2=$(echo "$line2" | sed -nE 's/^STATUS: fail reason=([a-z0-9-]+).*/\1/p')
  [ "$reason1" = "notion-mcp-unavailable" ]
  [ "$reason2" != "notion-mcp-unavailable" ]
}

@test "STATUS parser: rejects malformed lines" {
  ! echo "status: ok" | grep -Eq '^STATUS: (ok|partial|fail)\b'
  ! echo "STATUS ok" | grep -Eq '^STATUS: (ok|partial|fail)\b'
  ! echo " STATUS: ok" | grep -Eq '^STATUS: (ok|partial|fail)\b'
}

# --- Rule (d): intermediate-file existence check ---
#
# Phase 1 must be skipped when BOTH voice.md AND dailyLLM.md exist
# AND --force-rebuild is NOT set.

skip_phase1() {
  local diary_dir="$1" force_rebuild="$2"
  if [ -f "${diary_dir}/voice.md" ] && [ -f "${diary_dir}/dailyLLM.md" ] && [ "$force_rebuild" != "true" ]; then
    return 0  # skip
  fi
  return 1  # run
}

@test "phase1 skip: both intermediate files exist + no force-rebuild -> skip" {
  diary_dir="${DR_TEST_TMPDIR}/dir"
  mkdir -p "$diary_dir"
  : > "${diary_dir}/voice.md"
  : > "${diary_dir}/dailyLLM.md"
  skip_phase1 "$diary_dir" "false"
}

@test "phase1 skip: --force-rebuild = true -> always run" {
  diary_dir="${DR_TEST_TMPDIR}/dir"
  mkdir -p "$diary_dir"
  : > "${diary_dir}/voice.md"
  : > "${diary_dir}/dailyLLM.md"
  ! skip_phase1 "$diary_dir" "true"
}

@test "phase1 skip: only voice.md exists -> run Phase 1" {
  diary_dir="${DR_TEST_TMPDIR}/dir"
  mkdir -p "$diary_dir"
  : > "${diary_dir}/voice.md"
  ! skip_phase1 "$diary_dir" "false"
}

@test "phase1 skip: only dailyLLM.md exists -> run Phase 1" {
  diary_dir="${DR_TEST_TMPDIR}/dir"
  mkdir -p "$diary_dir"
  : > "${diary_dir}/dailyLLM.md"
  ! skip_phase1 "$diary_dir" "false"
}

@test "phase1 skip: no intermediates -> run Phase 1" {
  diary_dir="${DR_TEST_TMPDIR}/dir"
  mkdir -p "$diary_dir"
  ! skip_phase1 "$diary_dir" "false"
}

# --- Rule (e): Phase 1 sanity check (line count lower bound) ---
#
# After Phase 1, main reads the top 40 lines of voice.md / dailyLLM.md
# and warns if either is < 50 lines total.

sanity_check_warn() {
  # Returns 0 (true) if file is "too short" (< 50 lines) — i.e. WARN
  local path="$1"
  if [ ! -f "$path" ]; then return 0; fi
  local count
  count=$(wc -l < "$path" | tr -d ' ')
  if [ "$count" -lt 50 ]; then
    return 0  # warn
  fi
  return 1  # ok
}

@test "sanity check: empty file -> warn" {
  : > "${DR_TEST_TMPDIR}/voice.md"
  sanity_check_warn "${DR_TEST_TMPDIR}/voice.md"
}

@test "sanity check: 49 lines -> warn" {
  for i in $(seq 1 49); do echo "line $i"; done > "${DR_TEST_TMPDIR}/voice.md"
  sanity_check_warn "${DR_TEST_TMPDIR}/voice.md"
}

@test "sanity check: 50 lines -> ok (no warn)" {
  for i in $(seq 1 50); do echo "line $i"; done > "${DR_TEST_TMPDIR}/voice.md"
  ! sanity_check_warn "${DR_TEST_TMPDIR}/voice.md"
}

@test "sanity check: 100 lines -> ok (no warn)" {
  for i in $(seq 1 100); do echo "line $i"; done > "${DR_TEST_TMPDIR}/voice.md"
  ! sanity_check_warn "${DR_TEST_TMPDIR}/voice.md"
}

@test "sanity check: missing file -> warn" {
  sanity_check_warn "${DR_TEST_TMPDIR}/nonexistent.md"
}

# --- plugin.json ASCII sort order verification ---

@test "plugin.json: agents array is ASCII-sorted" {
  plugin_json="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  agents=$(python3 -c "import json; print('\n'.join(json.load(open('$plugin_json'))['agents']))")
  sorted=$(echo "$agents" | sort)
  [ "$agents" = "$sorted" ]
}

@test "plugin.json: spike agent is removed (post-change-4)" {
  plugin_json="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  ! grep -q "_spike-notion-mcp" "$plugin_json"
}

@test "plugin.json: voice-compactor and llm-log-compactor are registered" {
  plugin_json="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  grep -q "voice-compactor" "$plugin_json"
  grep -q "llm-log-compactor" "$plugin_json"
}
