#!/usr/bin/env bats
#
# Tests for change-2 task 3.x — exec.md / e.md Workflow control-plane docs.
# spec: workflow-exec (S13 opt-in / S14 /lr:e delegation / S12 builder default)
#       workflow-run-control (S18 runId record / S20 no checkpoint machine-parse).
#
# The interactive Workflow launch and AskUserQuestion gates cannot be unit-tested,
# so we validate the documented control plane in the command markdown.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  EXEC_MD="${PLUGIN_DIR}/commands/exec.md"
  LR_E_MD="${PLUGIN_ROOT}/plugins/lr/commands/e.md"
}

# --- exec writes Workflow, not orchestrator inline ---

@test "exec.md: allowed-tools includes Workflow" {
  # frontmatter must grant the Workflow tool.
  head -10 "$EXEC_MD" | grep -Eq 'allowed-tools:.*Workflow'
}

@test "exec.md: no longer references longrun-orchestrator skills path" {
  ! grep -q 'skills/longrun-orchestrator/SKILL.md' "$EXEC_MD"
}

@test "exec.md: references the workflow templates" {
  grep -q 'templates/workflow/review.workflow.js' "$EXEC_MD"
  grep -q 'templates/workflow/build-verify.workflow.js' "$EXEC_MD"
}

@test "exec.md: references the three external schemas" {
  grep -q 'schemas/builder-report.schema.json' "$EXEC_MD"
  grep -q 'schemas/verifier-score.schema.json' "$EXEC_MD"
  grep -q 'schemas/reviewer-verdict.schema.json' "$EXEC_MD"
}

# --- S8/S9: permission mode check ---

@test "exec.md: Step 0 checks permission mode (acceptEdits)" {
  grep -Eq '権限モード' "$EXEC_MD"
  grep -q 'acceptEdits' "$EXEC_MD"
}

# --- S13: opt-in note ---

@test "exec.md: documents Workflow launch opt-in (no extra confirmation for slash command)" {
  grep -Eq 'opt-in' "$EXEC_MD"
  grep -Eq '追加確認は?不要|追加の確認.*不要' "$EXEC_MD"
  grep -Eq 'ユーザーが起動した slash command' "$EXEC_MD"
}

# --- S10/S11: approval gates split the workflow ---

@test "exec.md: splits workflow at Build Contract approval gate" {
  grep -Eq 'Build Contract.*承認' "$EXEC_MD"
  grep -Eq 'メインループに戻' "$EXEC_MD"
  grep -q 'AskUserQuestion' "$EXEC_MD"
}

@test "exec.md: documents Feedback Tier confirmation back in the main loop" {
  grep -Eq 'Feedback Tier' "$EXEC_MD"
}

# --- S12: builder agentType default ---

@test "exec.md: builder agentType defaults to longrun:longrun-builder" {
  grep -q 'longrun:longrun-builder' "$EXEC_MD"
  grep -Eq 'BUILDER_AGENT_TYPE' "$EXEC_MD"
}

# --- S18: runId recording ---

@test "exec.md: records runId into the run directory" {
  grep -Eq 'workflow-runs.jsonl' "$EXEC_MD"
  grep -Eq 'runId' "$EXEC_MD"
}

@test "exec.md: resume uses resumeFromRunId as primary means" {
  grep -q 'resumeFromRunId' "$EXEC_MD"
}

# --- S20 / D4: checkpoint.md is human-only, no machine parse ---

@test "exec.md: forbids machine-parsing checkpoint.md for control flow" {
  grep -Eq 'checkpoint.md を grep/sed|パースして制御フロー' "$EXEC_MD"
}

@test "exec.md: contains no grep/sed of checkpoint.md as a code step" {
  # No actual checkpoint.md parsing command (grep/sed targeting checkpoint.md).
  ! grep -Eq '(grep|sed)[^\n]*checkpoint\.md' "$EXEC_MD"
}

# --- timestamp injected via args (Date.now forbidden) ---

@test "exec.md: injects timestamp through args" {
  grep -Eq 'args.*timestamp|timestamp.*args' "$EXEC_MD"
}

# --- S14: /lr:e simple delegation, no orchestrator ---

@test "e.md: delegates to exec.md" {
  grep -q 'exec.md' "$LR_E_MD"
}

@test "e.md: contains no longrun-orchestrator reference" {
  ! grep -q 'orchestrator' "$LR_E_MD"
}

@test "e.md: allowed-tools includes Workflow" {
  head -10 "$LR_E_MD" | grep -Eq 'allowed-tools:.*Workflow'
}
