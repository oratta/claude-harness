#!/usr/bin/env bats
#
# Tests for degraded-mode artifacts (change-1: openspec-degradation, tasks 3.x).
#
# Covers:
#   - archive mode-detection logic: .degraded-mode (file) takes priority over
#     <!-- mvp-mode --> (plan.md comment); both -> degraded; neither -> full
#     (the documented control plane in commands/archive.md)
#   - archive degraded branch moves ONLY the run dir and does NOT touch
#     openspec/changes/ (acceptance condition 5/S11)
#   - orchestrator/archive markdown document the degraded branch and forbid
#     writing into openspec/ (S8/S9 structural)
#
# The full Setup->Archive E2E is a manual check (design.md). Here we unit-test
# the deterministic control plane around the .degraded-mode marker.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  lr_make_tmpdir
  # change-2: orchestrator SKILL.md was dismantled; the degraded-mode branch
  # moved to commands/exec.md (付録: 縮退モードの spec 類自己完結生成).
  DEGRADED_MD="${PLUGIN_DIR}/commands/exec.md"
  ARCHIVE_MD="${PLUGIN_DIR}/commands/archive.md"
}

teardown() {
  lr_teardown_tmpdir
}

# Canonical archive-mode resolver mirroring commands/archive.md step 2.
# Priority: .degraded-mode file > <!-- mvp-mode --> plan.md comment > full.
resolve_archive_mode() {
  local run_dir="$1"
  if [ -f "${run_dir}/.degraded-mode" ]; then
    echo "DEGRADED"; return 0
  fi
  if [ -f "${run_dir}/plan.md" ] && head -5 "${run_dir}/plan.md" | grep -q '<!-- mvp-mode -->'; then
    echo "MVP"; return 0
  fi
  echo "FULL"
}

# --- mode resolution ---

@test "archive mode: .degraded-mode marker -> DEGRADED" {
  run_dir="${LR_TEST_TMPDIR}/run"
  mkdir -p "$run_dir"
  : > "${run_dir}/.degraded-mode"
  [ "$(resolve_archive_mode "$run_dir")" = "DEGRADED" ]
}

@test "archive mode: mvp-mode comment in plan.md -> MVP" {
  run_dir="${LR_TEST_TMPDIR}/run"
  mkdir -p "$run_dir"
  printf '<!-- mvp-mode -->\n# Plan\n' > "${run_dir}/plan.md"
  [ "$(resolve_archive_mode "$run_dir")" = "MVP" ]
}

@test "archive mode: both markers -> DEGRADED wins (priority)" {
  run_dir="${LR_TEST_TMPDIR}/run"
  mkdir -p "$run_dir"
  : > "${run_dir}/.degraded-mode"
  printf '<!-- mvp-mode -->\n# Plan\n' > "${run_dir}/plan.md"
  [ "$(resolve_archive_mode "$run_dir")" = "DEGRADED" ]
}

@test "archive mode: no markers -> FULL" {
  run_dir="${LR_TEST_TMPDIR}/run"
  mkdir -p "$run_dir"
  printf '# Plan (no markers)\n' > "${run_dir}/plan.md"
  [ "$(resolve_archive_mode "$run_dir")" = "FULL" ]
}

# --- degraded archive: only run dir moved, openspec/changes untouched (S11) ---

# Minimal degraded-archive routine matching commands/archive.md "縮退モードアーカイブ".
degraded_archive() {
  local repo="$1" run_dir="$2"
  # MUST NOT touch openspec/changes/
  mkdir -p "${repo}/_longruns/_archive"
  mv "$run_dir" "${repo}/_longruns/_archive/"
}

@test "degraded archive: moves run dir into _archive" {
  repo="${LR_TEST_TMPDIR}/repo"
  mkdir -p "${repo}/_longruns/2026-06-12_x/specs/change-a"
  : > "${repo}/_longruns/2026-06-12_x/.degraded-mode"
  : > "${repo}/_longruns/2026-06-12_x/specs/change-a/proposal.md"
  degraded_archive "$repo" "${repo}/_longruns/2026-06-12_x"
  [ -d "${repo}/_longruns/_archive/2026-06-12_x" ]
  [ -f "${repo}/_longruns/_archive/2026-06-12_x/specs/change-a/proposal.md" ]
  [ ! -d "${repo}/_longruns/2026-06-12_x" ]
}

@test "degraded archive: does NOT create or move openspec/changes/archive" {
  repo="${LR_TEST_TMPDIR}/repo"
  mkdir -p "${repo}/_longruns/2026-06-12_x"
  : > "${repo}/_longruns/2026-06-12_x/.degraded-mode"
  degraded_archive "$repo" "${repo}/_longruns/2026-06-12_x"
  # No openspec/ writes happened
  [ ! -d "${repo}/openspec" ]
}

# --- degraded artifact paths self-contained under run dir (S8/S9) ---

@test "degraded artifacts: specs live under run dir, not openspec/" {
  repo="${LR_TEST_TMPDIR}/repo"
  run_dir="${repo}/_longruns/2026-06-12_x"
  # Simulate the orchestrator degraded branch output layout.
  mkdir -p "${run_dir}/specs/change-a"
  : > "${run_dir}/.degraded-mode"
  printf '# Proposal\n' > "${run_dir}/specs/change-a/proposal.md"
  printf '## 1. Group\n- [ ] 1.1 task\n' > "${run_dir}/specs/change-a/tasks.md"
  printf '# Verification Guide\n' > "${run_dir}/verification-guide.md"
  [ -f "${run_dir}/specs/change-a/proposal.md" ]
  [ -f "${run_dir}/specs/change-a/tasks.md" ]
  [ -f "${run_dir}/verification-guide.md" ]
  grep -Eq '^- \[ \] 1\.1' "${run_dir}/specs/change-a/tasks.md"   # checkbox format
  [ ! -d "${repo}/openspec" ]
}

# --- structural: docs describe the degraded branch correctly (now in exec.md) ---

@test "exec: documents degraded-mode branch" {
  grep -q '\.degraded-mode' "$DEGRADED_MD"
  grep -Eq '縮退モード' "$DEGRADED_MD"
}

@test "exec: degraded branch writes specs under run dir" {
  grep -Eq '\{longrun-dir\}/specs/<change-name>/' "$DEGRADED_MD"
}

@test "exec: forbids writing openspec/ in degraded mode" {
  grep -Eq 'openspec/.*一切.*書き込|書き込.*禁止|openspec/` 配下にも.*一切|openspec/` 配下にも\*\*一切\*\*書き込' "$DEGRADED_MD"
}

@test "exec: degraded archive skips openspec change move" {
  grep -Eq '\.degraded-mode.*マーカーを見て|OpenSpec change の移動をスキップ' "$DEGRADED_MD"
}

@test "archive.md: documents degraded branch with priority over mvp" {
  grep -q '\.degraded-mode' "$ARCHIVE_MD"
  grep -Eq '縮退モードアーカイブ' "$ARCHIVE_MD"
  grep -Eq '優先' "$ARCHIVE_MD"
}

@test "archive.md: degraded branch does not touch openspec/changes" {
  grep -Eq 'openspec/changes/.*一切触らない|openspec/changes/ 配下を一切触らない' "$ARCHIVE_MD"
}
