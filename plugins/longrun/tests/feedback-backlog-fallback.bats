#!/usr/bin/env bats
#
# Tests for feedback Tier 3 backlog fallback (change-1: openspec-degradation,
# tasks 4.x). Covers S12/S13:
#   - DEGRADED run (.degraded-mode present): Tier 3 -> _longruns/<run>/backlog.md,
#     openspec/backlog.md untouched, openspec/ NOT created
#   - NORMAL run (no marker): Tier 3 -> openspec/backlog.md (no regression)
#
# We unit-test the deterministic record-destination resolver that mirrors
# longrun-feedback SKILL.md Step 0/Step 7, plus structural checks on the SKILL.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  lr_make_tmpdir
  FEEDBACK_MD="${PLUGIN_DIR}/skills/longrun-feedback/SKILL.md"
}

teardown() {
  lr_teardown_tmpdir
}

# Canonical backlog-path resolver mirroring SKILL.md Step 0.3.
resolve_backlog_path() {
  local repo="$1" run_dir="$2"
  if [ -f "${run_dir}/.degraded-mode" ]; then
    echo "${run_dir}/backlog.md"
  else
    echo "${repo}/openspec/backlog.md"
  fi
}

# Append a Tier 3 item to the resolved backlog (mirrors Step 7).
record_tier3() {
  local backlog_path="$1" item="$2"
  mkdir -p "$(dirname "$backlog_path")"
  printf -- '- [ ] %s\n' "$item" >> "$backlog_path"
}

# --- resolver ---

@test "resolver: DEGRADED run resolves to run-dir backlog" {
  repo="${LR_TEST_TMPDIR}/repo"
  run_dir="${repo}/_longruns/2026-06-12_x"
  mkdir -p "$run_dir"
  : > "${run_dir}/.degraded-mode"
  [ "$(resolve_backlog_path "$repo" "$run_dir")" = "${run_dir}/backlog.md" ]
}

@test "resolver: NORMAL run resolves to openspec backlog" {
  repo="${LR_TEST_TMPDIR}/repo"
  run_dir="${repo}/_longruns/2026-06-12_x"
  mkdir -p "$run_dir"
  [ "$(resolve_backlog_path "$repo" "$run_dir")" = "${repo}/openspec/backlog.md" ]
}

# --- S12: DEGRADED writes to run dir, openspec/ untouched ---

@test "S12: DEGRADED Tier 3 appends to run-dir backlog and does NOT create openspec/" {
  repo="${LR_TEST_TMPDIR}/repo"
  run_dir="${repo}/_longruns/2026-06-12_x"
  mkdir -p "$run_dir"
  : > "${run_dir}/.degraded-mode"
  path="$(resolve_backlog_path "$repo" "$run_dir")"
  record_tier3 "$path" "通知機能も欲しい"
  [ -f "${run_dir}/backlog.md" ]
  grep -q "通知機能も欲しい" "${run_dir}/backlog.md"
  [ ! -d "${repo}/openspec" ]
  [ ! -f "${repo}/openspec/backlog.md" ]
}

# --- S13: NORMAL writes to openspec backlog (regression guard) ---

@test "S13: NORMAL Tier 3 appends to openspec/backlog.md" {
  repo="${LR_TEST_TMPDIR}/repo"
  run_dir="${repo}/_longruns/2026-06-12_x"
  mkdir -p "${repo}/openspec" "$run_dir"
  path="$(resolve_backlog_path "$repo" "$run_dir")"
  record_tier3 "$path" "管理画面を追加して"
  [ -f "${repo}/openspec/backlog.md" ]
  grep -q "管理画面を追加して" "${repo}/openspec/backlog.md"
  [ ! -f "${run_dir}/backlog.md" ]
}

@test "S13: NORMAL run does not write run-dir backlog (no degraded leakage)" {
  repo="${LR_TEST_TMPDIR}/repo"
  run_dir="${repo}/_longruns/2026-06-12_x"
  mkdir -p "${repo}/openspec" "$run_dir"
  path="$(resolve_backlog_path "$repo" "$run_dir")"
  [ "$path" = "${repo}/openspec/backlog.md" ]
}

# --- structural checks on SKILL.md ---

@test "feedback SKILL: documents degraded-mode marker detection" {
  grep -q '\.degraded-mode' "$FEEDBACK_MD"
}

@test "feedback SKILL: documents run-dir backlog fallback path" {
  grep -Eq '\{longrun-dir\}/backlog.md' "$FEEDBACK_MD"
}

@test "feedback SKILL: forbids openspec/ creation in degraded mode" {
  grep -Eq 'openspec/.*作成しない|openspec/ ディレクトリは作成しない|openspec/` は作成しない' "$FEEDBACK_MD"
}

@test "feedback SKILL: NORMAL run still uses openspec/backlog.md" {
  grep -q 'openspec/backlog.md' "$FEEDBACK_MD"
}

@test "feedback SKILL: presents record destination to the user" {
  grep -Eq '記録先' "$FEEDBACK_MD"
}
