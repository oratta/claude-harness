#!/usr/bin/env bats
#
# Tests for change-2 task 5.3 / 5.4 — Verify loop termination & resume.
# spec: workflow-run-control S15 (cap 3 stop) / S16 (budget exhaustion) / S17 (resume skip).
#
# The Verify loop logic in build-verify.workflow.js cannot be run inside the real
# Workflow runtime here (no agent()/budget globals available to a subagent). We
# extract the *pure* loop structure and exercise it with a stubbed agent that
# always FAILs, plus a stubbed budget, to prove: (a) it stops at exactly 3 rounds
# (never a 4th), (b) it stops early when budget is exhausted. The actual schema
# enforcement / agentType resolution is verified statically (workflow-template.bats)
# and by the orchestrator at run time.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  BV_TPL="${PLUGIN_DIR}/templates/workflow/build-verify.workflow.js"
  lr_make_tmpdir
  HARNESS="${LR_TEST_TMPDIR}/loop.mjs"
}

teardown() {
  lr_teardown_tmpdir
}

# A standalone harness mirroring the template's Verify loop *structure*
# (same constants, same while condition, same null-guard). Asserting on this
# proves the termination semantics; workflow-template.bats proves the template
# literally contains this structure (VERIFY_MAX_ROUNDS=3 + null-guard).
write_harness() {
  cat > "$HARNESS" <<'JS'
const VERIFY_MAX_ROUNDS = 3;
const VERIFY_ROUND_COST = 50000;

function runLoop({ verdictSeq, budgetTotal, budgetRemainingSeq }) {
  const budget = {
    total: budgetTotal,
    _i: 0,
    remaining() {
      if (this.total === null || this.total === undefined) return Infinity;
      const v = budgetRemainingSeq[this._i] ?? budgetRemainingSeq[budgetRemainingSeq.length - 1];
      this._i++;
      return v;
    },
  };
  let round = 0;
  let stopReason = null;
  let verifierCalls = 0;
  while (round < VERIFY_MAX_ROUNDS) {
    if (budget.total && budget.remaining() <= VERIFY_ROUND_COST) {
      stopReason = 'BUDGET_EXHAUSTED';
      break;
    }
    round++;
    const verdict = verdictSeq[round - 1] ?? 'FAIL';
    verifierCalls++;
    if (verdict === 'PASS') { stopReason = 'PASS'; break; }
  }
  if (!stopReason) stopReason = 'MAX_ROUNDS_REACHED';
  return { round, stopReason, verifierCalls };
}

const out = {
  allFail: runLoop({ verdictSeq: ['FAIL','FAIL','FAIL','FAIL'], budgetTotal: null, budgetRemainingSeq: [Infinity] }),
  passRound2: runLoop({ verdictSeq: ['FAIL','PASS'], budgetTotal: null, budgetRemainingSeq: [Infinity] }),
  budgetExhausted: runLoop({ verdictSeq: ['FAIL','FAIL','FAIL'], budgetTotal: 1000000, budgetRemainingSeq: [40000] }),
  budgetOkNullTotal: runLoop({ verdictSeq: ['FAIL','FAIL','FAIL'], budgetTotal: null, budgetRemainingSeq: [10] }),
};
process.stdout.write(JSON.stringify(out));
JS
}

@test "verify-loop: all-FAIL stops at exactly 3 rounds (no 4th)" {
  write_harness
  run node "$HARNESS"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.allFail.round == 3' >/dev/null
  echo "$output" | jq -e '.allFail.verifierCalls == 3' >/dev/null
  echo "$output" | jq -e '.allFail.stopReason == "MAX_ROUNDS_REACHED"' >/dev/null
}

@test "verify-loop: PASS in round 2 stops early with PASS" {
  write_harness
  run node "$HARNESS"
  echo "$output" | jq -e '.passRound2.round == 2' >/dev/null
  echo "$output" | jq -e '.passRound2.stopReason == "PASS"' >/dev/null
}

@test "verify-loop: budget exhaustion stops before round cap" {
  write_harness
  run node "$HARNESS"
  echo "$output" | jq -e '.budgetExhausted.stopReason == "BUDGET_EXHAUSTED"' >/dev/null
  echo "$output" | jq -e '.budgetExhausted.round < 3' >/dev/null
}

@test "verify-loop: null budget.total bypasses budget guard (runs to cap)" {
  write_harness
  run node "$HARNESS"
  # Even with a tiny remaining value, null total means remaining()=Infinity so
  # the budget guard never fires; loop runs to the 3-round cap.
  echo "$output" | jq -e '.budgetOkNullTotal.round == 3' >/dev/null
  echo "$output" | jq -e '.budgetOkNullTotal.stopReason == "MAX_ROUNDS_REACHED"' >/dev/null
}

# --- task 5.4: resume skip is documented and runId record is the source ---

@test "verify-loop: resume relies on resumeFromRunId + recorded runId" {
  grep -q 'resumeFromRunId' "${PLUGIN_DIR}/commands/exec.md"
  grep -q 'workflow-runs.jsonl' "${PLUGIN_DIR}/commands/exec.md"
  # build-verify returns structured state (not parsed from checkpoint.md) so that
  # resume is driven by the Workflow runtime cache, not prose.
  grep -q 'return {' "$BV_TPL"
  grep -q 'stopReason' "$BV_TPL"
}
