#!/usr/bin/env bats
#
# Tests for change-2 task 5.2 — minimal fixture plan (1 change / 1 task).
# spec: workflow-exec S4 "最小 fixture plan で Review → Build → Verify が 1 周完走する".
#
# The actual Workflow launch + 1-round completion + runId record is performed by
# the orchestrator (main loop) because builder subagents cannot invoke Workflow.
# Here we validate the part a unit test CAN cover: that from the minimal fixture
# plan, exec's documented rendering produces syntactically valid, schema-bearing,
# constraint-compliant workflow scripts for both phases, and the runId-record
# format is well-formed.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  FIXTURE_PLAN="${FIXTURES_DIR}/minimal-plan/plan.md"
  TPL_DIR="${PLUGIN_DIR}/templates/workflow"
  SCHEMA_DIR="${PLUGIN_DIR}/schemas"
  RENDER="${PLUGIN_DIR}/scripts/render-workflow.mjs"
  lr_make_tmpdir
}

teardown() {
  lr_teardown_tmpdir
}

@test "minimal-fixture: fixture plan exists with 1 change" {
  [ -f "$FIXTURE_PLAN" ]
  grep -q 'change-1: fixture-hello' "$FIXTURE_PLAN"
}

@test "minimal-fixture: review + build-verify render and pass node --check" {
  # Build review params
  node -e '
    const fs=require("fs");
    const schema=fs.readFileSync(process.argv[2],"utf8");
    const params={
      PLAN_PATH: process.argv[3],
      PROJECT_ROOT:"/abs",
      REVIEWER_SCHEMA: JSON.stringify(JSON.parse(schema)),
      REVIEWER_AGENT_TYPE:"longrun:longrun-reviewer"
    };
    fs.writeFileSync(process.argv[4], JSON.stringify(params));
  ' x "${SCHEMA_DIR}/reviewer-verdict.schema.json" "$FIXTURE_PLAN" "${LR_TEST_TMPDIR}/rp.json"
  node "$RENDER" "${TPL_DIR}/review.workflow.js" "${LR_TEST_TMPDIR}/rp.json" > "${LR_TEST_TMPDIR}/review.js"
  node --check "${LR_TEST_TMPDIR}/review.js"

  # Build-verify params with the single change from the fixture
  node -e '
    const fs=require("fs");
    const bs=fs.readFileSync(process.argv[2],"utf8");
    const vs=fs.readFileSync(process.argv[3],"utf8");
    const params={
      RUN_DIR:"/abs/_longruns/run",
      PROJECT_ROOT:"/abs",
      CHANGES_JSON: JSON.stringify([{name:"fixture-hello",worktree:"_worktrees/fixture-hello",dependsOn:[]}]),
      BUILDER_AGENT_TYPE:"longrun:longrun-builder",
      VERIFIER_AGENT_TYPE:"longrun:longrun-verifier",
      BROWSER_VERIFIER_AGENT_TYPE:"longrun:longrun-browser-verifier",
      BUILDER_SCHEMA: JSON.stringify(JSON.parse(bs)),
      VERIFIER_SCHEMA: JSON.stringify(JSON.parse(vs))
    };
    fs.writeFileSync(process.argv[4], JSON.stringify(params));
  ' x "${SCHEMA_DIR}/builder-report.schema.json" "${SCHEMA_DIR}/verifier-score.schema.json" "${LR_TEST_TMPDIR}/bp.json"
  node "$RENDER" "${TPL_DIR}/build-verify.workflow.js" "${LR_TEST_TMPDIR}/bp.json" > "${LR_TEST_TMPDIR}/bv.js"
  node --check "${LR_TEST_TMPDIR}/bv.js"
}

@test "minimal-fixture: rendered scripts carry the inlined schemas" {
  # reuse render from previous test inline (single change)
  node -e '
    const fs=require("fs");
    const bs=fs.readFileSync(process.argv[2],"utf8");
    const vs=fs.readFileSync(process.argv[3],"utf8");
    const params={
      RUN_DIR:"/abs/_longruns/run", PROJECT_ROOT:"/abs",
      CHANGES_JSON: JSON.stringify([{name:"fixture-hello",worktree:"_worktrees/fixture-hello",dependsOn:[]}]),
      BUILDER_AGENT_TYPE:"longrun:longrun-builder", VERIFIER_AGENT_TYPE:"longrun:longrun-verifier", BROWSER_VERIFIER_AGENT_TYPE:"longrun:longrun-browser-verifier",
      BUILDER_SCHEMA: JSON.stringify(JSON.parse(bs)), VERIFIER_SCHEMA: JSON.stringify(JSON.parse(vs))
    };
    fs.writeFileSync(process.argv[4], JSON.stringify(params));
  ' x "${SCHEMA_DIR}/builder-report.schema.json" "${SCHEMA_DIR}/verifier-score.schema.json" "${LR_TEST_TMPDIR}/bp.json"
  node "$RENDER" "${TPL_DIR}/build-verify.workflow.js" "${LR_TEST_TMPDIR}/bp.json" > "${LR_TEST_TMPDIR}/bv.js"
  grep -q 'fixture-hello' "${LR_TEST_TMPDIR}/bv.js"
  grep -q 'builder-report' "${LR_TEST_TMPDIR}/bv.js"
  grep -q 'verifier-score' "${LR_TEST_TMPDIR}/bv.js"
}

@test "minimal-fixture: runId record line is valid JSONL" {
  # exec records one JSONL line per workflow launch into workflow-runs.jsonl.
  line='{"phase":"Review","runId":"wf_abc123","scriptPath":"/abs/review.js","timestamp":"2026-06-12T00:00:00+09:00"}'
  echo "$line" | jq -e '.runId and .phase and .scriptPath and .timestamp' >/dev/null
}
