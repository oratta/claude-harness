#!/usr/bin/env bats
#
# Tests for change-3 (longrun-v5-cleanup), capability longrun-orphan-cleanup.
# spec: openspec/changes/longrun-v5-cleanup/specs/longrun-orphan-cleanup/spec.md
#       (S1-S9, S16-S18 in the run's verification-guide).
#
# Structural / grep-based verifications, following the convention established
# by mvp-plan-split.bats and legacy-removal.bats.
#
# NOTE: macOS ships /bin/bash 3.2, which has a long-standing bug where using
# bare `!`-negated commands disables errexit-style status propagation for
# subsequent statements in the same test body. To stay reliable under that
# shell, every negative assertion here uses `run` + an explicit status check
# instead of a bare `! command`.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  LR_DIR="${PLUGIN_ROOT}/plugins/lr"
  VERIFIER_MD="${PLUGIN_DIR}/agents/longrun-verifier.md"
  BROWSER_VERIFIER_MD="${PLUGIN_DIR}/agents/longrun-browser-verifier.md"
  BUILDER_MD="${PLUGIN_DIR}/agents/longrun-builder.md"
  EXEC_MD="${PLUGIN_DIR}/commands/exec.md"
  UPDATE_CHECKPOINT_SH="${PLUGIN_DIR}/scripts/update-checkpoint.sh"
}

# --- S1: longrun-verifier context restoration step ---

@test "orphan: longrun-verifier context restoration starts from plan.md and decisions.md" {
  grep -q '{longrun-dir}/plan.md' "$VERIFIER_MD"
  grep -q '{longrun-dir}/decisions.md' "$VERIFIER_MD"
  run grep -qE 'checkpoint\.md.*から現在状態を把握|checkpoint\.md.*把握' "$VERIFIER_MD"
  [ "$status" -ne 0 ]
}

# --- S2: longrun-verifier FAIL escalation step ---

@test "orphan: longrun-verifier FAIL step does not escalate to orchestrator" {
  run grep -q 'orchestratorに修正を依頼' "$VERIFIER_MD"
  [ "$status" -ne 0 ]
  grep -qE 'Workflow.*builder|builder.*再?呼び出し' "$VERIFIER_MD"
}

# --- S3: longrun-browser-verifier context restoration step ---

@test "orphan: longrun-browser-verifier context restoration starts from plan.md and decisions.md" {
  grep -q '{longrun-dir}/plan.md' "$BROWSER_VERIFIER_MD"
  grep -q '{longrun-dir}/decisions.md' "$BROWSER_VERIFIER_MD"
  run grep -qE 'checkpoint\.md.*から現在状態を把握|checkpoint\.md.*把握' "$BROWSER_VERIFIER_MD"
  [ "$status" -ne 0 ]
}

# --- S4: longrun-browser-verifier verification-guide.md provenance note ---

@test "orphan: verification-guide.md provenance note attributes Build phase / longrun-builder, not orchestrator" {
  run grep -qE 'orchestrator.*生成|orchestrator の Build' "$BROWSER_VERIFIER_MD"
  [ "$status" -ne 0 ]
  grep -qE 'Build ?フェーズ|longrun-builder' "$BROWSER_VERIFIER_MD"
}

# --- S5: longrun-browser-verifier FAIL escalation step ---

@test "orphan: longrun-browser-verifier FAIL step does not escalate to orchestrator" {
  run grep -q 'orchestratorに修正を依頼' "$BROWSER_VERIFIER_MD"
  [ "$status" -ne 0 ]
  grep -qE 'Workflow.*builder|builder.*再?呼び出し' "$BROWSER_VERIFIER_MD"
}

# --- S6: longrun-builder description accuracy ---

@test "orphan: longrun-builder description does not claim checkpoint.md update as completion action" {
  desc="$(grep -E '^description:' "$BUILDER_MD" | head -1)"
  run bash -c "echo '$desc' | grep -q 'checkpoint.mdを更新する'"
  [ "$status" -ne 0 ]
  echo "$desc" | grep -qE 'builder-report|完了レポート'
}

# --- S7: exec.md historical note without literal compound ---

@test "orphan: exec.md contains zero occurrences of longrun-orchestrator" {
  run grep -q 'longrun-orchestrator' "$EXEC_MD"
  [ "$status" -ne 0 ]
}

@test "orphan: exec.md historical note still describes what v6.0.0 removed" {
  grep -qE 'v6\.0\.0.*BREAKING' "$EXEC_MD"
  grep -qE 'インライン展開' "$EXEC_MD"
  grep -qE 'checkpoint\.md の散文パース' "$EXEC_MD"
}

# --- S8 / S9: dead script removed, no orphaned call sites ---

@test "orphan: scripts/update-checkpoint.sh does not exist" {
  [ ! -f "$UPDATE_CHECKPOINT_SH" ]
}

@test "orphan: no residual references to update-checkpoint.sh in plugins/ (outside this self-referential test)" {
  # Excludes plugins/longrun/tests/ because this very test file necessarily
  # embeds the literal filename as its own search pattern (same self-reference
  # allowance as the longrun-orchestrator / mode=mvp scoped-zero checks below).
  run bash -c "grep -rln 'update-checkpoint.sh' '${PLUGIN_ROOT}/plugins' | grep -v '/tests/' || true"
  [ -z "$output" ]
}

# --- S16 / S17: scoped-zero residual checks ---

@test "orphan: scoped-zero for longrun-orchestrator outside tests/" {
  run bash -c "grep -rln 'longrun-orchestrator' '${PLUGIN_ROOT}/plugins' | grep -v '/tests/' || true"
  [ -z "$output" ]
}

@test "orphan: scoped-zero for mode=mvp outside tests/ (longrun + lr)" {
  run bash -c "grep -rln 'mode=mvp' '${PLUGIN_DIR}' '${LR_DIR}' | grep -v '/tests/' || true"
  [ -z "$output" ]
}

# --- S18 note ---
# S18 ("residual test-file occurrences are documented in decisions.md") is
# verified manually against the run's decisions.md, which lives in the
# longrun run directory outside this repo's plugins/ tree (not a portable,
# bundlable test fixture) — see the run's decisions.md directly.
