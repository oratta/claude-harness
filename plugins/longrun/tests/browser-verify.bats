#!/usr/bin/env bats
#
# Tests for change-2 (longrun-browser-verify-restore) — Verify フェーズへの
# longrun-browser-verifier 復帰と静的/ブラウザ 2+2 軸分担.
#
# spec: longrun-browser-verify-step S1-S9
#   S1  Verify フェーズが静的とブラウザの両 verifier を起動する
#   S2  総合 verdict は両 verifier の論理積である
#   S3  workflow のしきい値が schema の description と一致する
#   S4  schema が外部ファイルを唯一のソースとする GATE が維持される
#   S5  BROWSER_VERIFIER_MODEL 未指定でも render が落ちない
#   S6  BROWSER_VERIFIER_MODEL が null のとき model キーを出力しない
#   S7  exec.md の params 表に browser-verifier 埋め込みポイントが記載されている
#   S8  レンダリング済み build-verify workflow が node --check PASS する
#   S9  4 軸が漏れなく重複なく 2 verifier に割り当てられている

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  TPL_DIR="${PLUGIN_DIR}/templates/workflow"
  SCHEMA_DIR="${PLUGIN_DIR}/schemas"
  RENDER="${PLUGIN_DIR}/scripts/render-workflow.mjs"
  BV_TPL="${TPL_DIR}/build-verify.workflow.js"
  EXEC="${PLUGIN_DIR}/commands/exec.md"
  VERIFIER_MD="${PLUGIN_DIR}/agents/longrun-verifier.md"
  BROWSER_MD="${PLUGIN_DIR}/agents/longrun-browser-verifier.md"
  SCHEMA="${SCHEMA_DIR}/verifier-score.schema.json"
  lr_make_tmpdir
}

teardown() {
  lr_teardown_tmpdir
}

# Render build-verify WITHOUT any *_MODEL param (exercises the null default for
# BROWSER_VERIFIER_MODEL). BROWSER_VERIFIER_AGENT_TYPE is supplied (not a _MODEL
# placeholder, so render would die if omitted).
render_bv() {
  node -e '
    const fs=require("fs");
    const bs=fs.readFileSync(process.argv[1],"utf8");
    const vs=fs.readFileSync(process.argv[2],"utf8");
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
    fs.writeFileSync(process.argv[3], JSON.stringify(params));
  ' "${SCHEMA_DIR}/builder-report.schema.json" "$SCHEMA" "${LR_TEST_TMPDIR}/bp.json"
  node "$RENDER" "$BV_TPL" "${LR_TEST_TMPDIR}/bp.json" > "${LR_TEST_TMPDIR}/bv.out.js"
}

# --- S1: both static and browser verifier are invoked in the Verify phase ---

@test "S1: rendered build-verify calls the static verifier agentType" {
  render_bv
  grep -q "agentType: 'longrun:longrun-verifier'" "${LR_TEST_TMPDIR}/bv.out.js"
}

@test "S1: rendered build-verify calls the browser verifier agentType" {
  render_bv
  grep -q "agentType: 'longrun:longrun-browser-verifier'" "${LR_TEST_TMPDIR}/bv.out.js"
}

@test "S1: browser verifier agentType is a parameterized placeholder in the template" {
  grep -q '__BROWSER_VERIFIER_AGENT_TYPE__' "$BV_TPL"
}

# --- S2: combined verdict is the logical AND of the two verdicts ---

write_verdict_harness() {
  cat > "${LR_TEST_TMPDIR}/verdict.mjs" <<'JS'
// Mirrors build-verify.workflow.js: combined verdict = static PASS AND browser PASS.
function combined(staticV, browserV) {
  const bothPass = staticV === 'PASS' && browserV === 'PASS';
  return bothPass ? 'PASS' : 'FAIL';
}
const out = {
  pp: combined('PASS', 'PASS'),
  pf: combined('PASS', 'FAIL'),
  fp: combined('FAIL', 'PASS'),
  ff: combined('FAIL', 'FAIL'),
};
process.stdout.write(JSON.stringify(out));
JS
}

@test "S2: combined verdict is PASS only when both verifiers PASS" {
  write_verdict_harness
  run node "${LR_TEST_TMPDIR}/verdict.mjs"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.pp == "PASS"' >/dev/null
  echo "$output" | jq -e '.pf == "FAIL"' >/dev/null
  echo "$output" | jq -e '.fp == "FAIL"' >/dev/null
  echo "$output" | jq -e '.ff == "FAIL"' >/dev/null
}

@test "S2: template computes combined verdict as logical AND of both verdicts" {
  grep -q 'bothPass' "$BV_TPL"
  grep -q "staticScore.verdict === 'PASS'" "$BV_TPL"
  grep -q "browserScore.verdict === 'PASS'" "$BV_TPL"
  # PASS stopReason is set from the combined verdict path.
  grep -q "stopReason = 'PASS'" "$BV_TPL"
}

# --- S3: workflow thresholds match verifier-score schema descriptions ---

@test "S3: static verifier prompt thresholds match schema (quality=100, completeness>=80)" {
  grep -q 'quality=100' "$BV_TPL"
  grep -q 'completeness>=80' "$BV_TPL"
  # schema descriptions carry the same hard thresholds
  jq -r '.properties.quality.description' "$SCHEMA" | grep -q '100'
  jq -r '.properties.completeness.description' "$SCHEMA" | grep -q '80'
}

@test "S3: browser verifier prompt thresholds match schema (functionality=100, ux>=70)" {
  grep -q 'functionality=100' "$BV_TPL"
  grep -q 'ux>=70' "$BV_TPL"
  jq -r '.properties.functionality.description' "$SCHEMA" | grep -q '100'
  jq -r '.properties.ux.description' "$SCHEMA" | grep -q '70'
}

# --- S4: schema is injected via placeholder, not inlined into the template ---

@test "S4: verifier schema is injected via __VERIFIER_SCHEMA__ placeholder" {
  grep -q '__VERIFIER_SCHEMA__' "$BV_TPL"
  grep -q 'const verifierSchema = __VERIFIER_SCHEMA__' "$BV_TPL"
}

@test "S4: schema property body is NOT hardcoded in the template" {
  # a raw schema property (e.g. "maximum": 100) must not appear directly in the
  # template — it only exists inside the external schema file.
  ! grep -q '"maximum": 100' "$BV_TPL"
  ! grep -q '"additionalProperties": false' "$BV_TPL"
}

@test "S4: both verifiers share the single verifier-score schema (candidate 1)" {
  # candidate 1 = 1 schema partial return; no second browser schema file introduced
  [ ! -f "${SCHEMA_DIR}/browser-verifier-score.schema.json" ]
  [ ! -f "${SCHEMA_DIR}/static-verifier-score.schema.json" ]
  # required relaxed to verdict-only so a 2-axis partial return validates
  run jq -e '.required == ["verdict"]' "$SCHEMA"
  [ "$status" -eq 0 ]
}

# --- S5: render does not fail when BROWSER_VERIFIER_MODEL is unspecified ---

@test "S5: render succeeds and defaults __BROWSER_VERIFIER_MODEL__ to null" {
  render_bv
  # no leftover placeholder remains
  run grep -o '__[A-Z][A-Z0-9_]*__' "${LR_TEST_TMPDIR}/bv.out.js"
  [ "$status" -ne 0 ]
  # browserVerifierModel const resolves to null
  grep -q 'const browserVerifierModel = null' "${LR_TEST_TMPDIR}/bv.out.js"
}

# --- S6: null model => model key is omitted via conditional spread ---

@test "S6: browser model uses conditional spread so null omits the model key" {
  grep -q '...(browserVerifierModel ? { model: browserVerifierModel } : {})' "$BV_TPL"
}

# --- S7: exec.md params table documents the browser-verifier embed points ---

@test "S7: exec.md params table lists BROWSER_VERIFIER_AGENT_TYPE with default" {
  grep -q 'BROWSER_VERIFIER_AGENT_TYPE' "$EXEC"
  grep -q 'longrun:longrun-browser-verifier' "$EXEC"
}

@test "S7: exec.md params table lists BROWSER_VERIFIER_MODEL" {
  grep -q 'BROWSER_VERIFIER_MODEL' "$EXEC"
}

# --- S8: rendered build-verify passes node --check ---

@test "S8: rendered build-verify passes node --check" {
  render_bv
  node --check "${LR_TEST_TMPDIR}/bv.out.js"
}

# --- S9: 4 axes assigned to exactly one verifier each (no overlap, no gap) ---

@test "S9: longrun-verifier declares static 2 axes (quality/completeness)" {
  grep -q '品質' "$VERIFIER_MD"
  grep -q '完成度' "$VERIFIER_MD"
}

@test "S9: longrun-browser-verifier declares browser 2 axes (functionality/ux)" {
  grep -q '機能性' "$BROWSER_MD"
  grep -q 'UX' "$BROWSER_MD"
}

@test "S9: static verifier prompt scores exactly quality + completeness" {
  grep -q 'quality / completeness を各 0-100 で採点' "$BV_TPL"
}

@test "S9: browser verifier prompt scores exactly functionality + ux" {
  grep -q 'functionality / ux を各 0-100 で採点' "$BV_TPL"
}
