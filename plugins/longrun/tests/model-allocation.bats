#!/usr/bin/env bats
#
# Tests for change-4 (model-allocation) tasks 1.3 / 2.2 / 3.4 / 4.4.
#
# 検証対象:
#   - references/model-tiers.md がティア→opts.model 渡し値を 1 箇所で定義する (S4)
#   - plan-template.md に「モデル割り当て」セクション + 表ヘッダ、モデル ID ハードコード無し (S1/S2/S3)
#   - longrun-plan SKILL.md に 3 ヒューリスティクス・迷ったら inherit・Validation 項目 (S12/S13/S15/S16)
#   - exec のモデル割り当て消費（resolve-model-allocation.mjs）が fixture 5 系で
#     opts.model 有無・値を仕様どおり解決する (S6〜S10)
#   - plan-template.md / SKILL.md / exec.md / workflow テンプレートにモデル ID 散在が無い (S5)
#
# spec: longrun-model-allocation, longrun-plan-skill

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  TIERS_MD="${PLUGIN_DIR}/references/model-tiers.md"
  PLAN_TPL="${PLUGIN_DIR}/templates/plan-template.md"
  PLAN_SKILL="${PLUGIN_DIR}/skills/longrun-plan/SKILL.md"
  EXEC_MD="${PLUGIN_DIR}/commands/exec.md"
  RESOLVE="${PLUGIN_DIR}/scripts/resolve-model-allocation.mjs"
  MA_FIXTURES="${FIXTURES_DIR}/model-allocation"
  lr_make_tmpdir
}

teardown() {
  lr_teardown_tmpdir
}

# Run the resolver against a fixture plan.md, capture JSON on stdout.
# Usage: resolve <fixture-plan-basename>
resolve() {
  node "$RESOLVE" "${MA_FIXTURES}/$1" "$TIERS_MD"
}

# Query a resolved entry's model via node/jq-style filter.
# Usage: model_of <json> <change> <role>  → prints model or "INHERIT" if absent/null
model_of() {
  node -e '
    const all = JSON.parse(process.argv[1]);
    const e = (all.allocations || []).find(a => a.change === process.argv[2] && a.role === process.argv[3]);
    if (!e) { process.stdout.write("MISSING"); process.exit(0); }
    process.stdout.write(("model" in e && e.model !== null) ? String(e.model) : "INHERIT");
  ' "$1" "$2" "$3"
}

# ===========================================================================
# Task 1.3 — references/model-tiers.md
# ===========================================================================

@test "model-tiers: reference file exists" {
  [ -f "$TIERS_MD" ]
}

@test "model-tiers: defines haiku / sonnet / inherit tiers" {
  lr_require_file "$TIERS_MD"
  grep -qi 'haiku' "$TIERS_MD"
  grep -qi 'sonnet' "$TIERS_MD"
  grep -qi 'inherit' "$TIERS_MD"
}

@test "model-tiers: inherit means opts.model is not emitted" {
  lr_require_file "$TIERS_MD"
  grep -Eq 'opts\.model.*(渡さない|出力しない|省略)' "$TIERS_MD"
}

# ===========================================================================
# Task 2.2 — plan-template.md model allocation section
# ===========================================================================

@test "plan-template: has model allocation section" {
  grep -Eq '^##+ .*モデル割り当て' "$PLAN_TPL"
}

@test "plan-template: has the model allocation table header" {
  grep -q '| change | ロール | ティア(haiku/sonnet/fable/inherit) | 理由 | 上書き |' "$PLAN_TPL"
}

@test "plan-template: documents user-editable / override-priority semantics" {
  # S2: 直接編集して上書きできる + 上書き欄がティア欄より優先
  grep -Eq '編集' "$PLAN_TPL"
  grep -Eq '上書き.*優先|優先.*上書き' "$PLAN_TPL"
}

@test "plan-template: no hardcoded claude- model IDs" {
  ! grep -q 'claude-' "$PLAN_TPL"
}

# ===========================================================================
# Task 3.4 — longrun-plan SKILL.md heuristics + validation
# ===========================================================================

@test "plan-skill: states the three heuristics" {
  # 判断が集中する場所（アーキレビュー・verify 最終判定）→ fable
  grep -Eq '判断が集中.*fable|fable.*判断' "$PLAN_SKILL"
  # builder は sonnet を出発点
  grep -Eq 'builder は sonnet を出発点' "$PLAN_SKILL"
  # 定型検証・要約 → haiku
  grep -Eq '(定型|要約).*haiku|haiku.*(定型|要約)' "$PLAN_SKILL"
  # リサーチ・ブラウザ・中規模 → sonnet
  grep -Eq '(リサーチ|ブラウザ|中規模).*sonnet|sonnet.*(リサーチ|ブラウザ|中規模)' "$PLAN_SKILL"
}

@test "plan-skill: states the conservative inherit default" {
  grep -Eq '迷ったら *inherit|確信度.*低.*inherit|inherit.*保守' "$PLAN_SKILL"
}

@test "plan-skill: references model-tiers.md instead of model IDs" {
  grep -q 'references/model-tiers.md' "$PLAN_SKILL"
}

@test "plan-skill: Validation checklist includes model allocation" {
  # Step 6 のセクション存在チェックに「モデル割り当て」が含まれる
  grep -Eq 'モデル割り当て.*セクション|「モデル割り当て」' "$PLAN_SKILL"
}

@test "plan-skill: no hardcoded claude- model IDs" {
  ! grep -q 'claude-' "$PLAN_SKILL"
}

# ===========================================================================
# Task 4.4 — exec consumption: resolve-model-allocation.mjs (5 fixtures)
# ===========================================================================

@test "resolve: script exists" {
  [ -f "$RESOLVE" ]
}

@test "resolve: fixtures dir exists with 5 plans" {
  [ -f "${MA_FIXTURES}/sonnet.plan.md" ]
  [ -f "${MA_FIXTURES}/inherit.plan.md" ]
  [ -f "${MA_FIXTURES}/override.plan.md" ]
  [ -f "${MA_FIXTURES}/unknown-tier.plan.md" ]
  [ -f "${MA_FIXTURES}/no-section.plan.md" ]
}

# S6: sonnet tier → opts.model 'sonnet'
@test "resolve: sonnet tier resolves to model 'sonnet'" {
  lr_require_file "$RESOLVE"
  run resolve "sonnet.plan.md"
  [ "$status" -eq 0 ]
  [ "$(model_of "$output" "feature-x" "verifier")" = "sonnet" ]
}

# S7: inherit tier → no opts.model (null)
@test "resolve: inherit tier omits opts.model" {
  lr_require_file "$RESOLVE"
  run resolve "inherit.plan.md"
  [ "$status" -eq 0 ]
  [ "$(model_of "$output" "feature-x" "builder")" = "INHERIT" ]
}

# S8: override column > tier column
@test "resolve: override column takes precedence over tier column" {
  lr_require_file "$RESOLVE"
  run resolve "override.plan.md"
  [ "$status" -eq 0 ]
  # tier=haiku but override=sonnet → resolves to sonnet
  [ "$(model_of "$output" "feature-x" "builder")" = "sonnet" ]
}

# S9: unknown tier → inherit + warning
@test "resolve: unknown tier falls back to inherit with warning" {
  lr_require_file "$RESOLVE"
  run resolve "unknown-tier.plan.md"
  [ "$status" -eq 0 ]
  [ "$(model_of "$output" "feature-x" "verifier")" = "INHERIT" ]
  # warning present in JSON output
  echo "$output" | node -e '
    const s=require("fs").readFileSync(0,"utf8");
    const o=JSON.parse(s);
    if (!(o.warnings && o.warnings.length > 0)) process.exit(1);
    if (!o.warnings.some(w => /opus-max|未知|unknown/i.test(w))) process.exit(1);
  '
}

# S10: no section → all inherit, no error, no warning escalation
@test "resolve: no model-allocation section yields all inherit" {
  lr_require_file "$RESOLVE"
  run resolve "no-section.plan.md"
  [ "$status" -eq 0 ]
  echo "$output" | node -e '
    const s=require("fs").readFileSync(0,"utf8");
    const o=JSON.parse(s);
    // every allocation (if any) must be inherit; and hasSection=false
    if (o.hasSection !== false) process.exit(1);
    const bad = (o.allocations||[]).filter(a => "model" in a && a.model !== null);
    if (bad.length) process.exit(1);
  '
}

# S5: model IDs do not leak into exec.md or workflow templates
@test "no-id-leak: exec.md has no hardcoded claude- model IDs" {
  ! grep -q 'claude-' "$EXEC_MD"
}

@test "no-id-leak: workflow templates have no hardcoded claude- model IDs" {
  ! grep -q 'claude-' "${PLUGIN_DIR}/templates/workflow/build-verify.workflow.js"
  ! grep -q 'claude-' "${PLUGIN_DIR}/templates/workflow/review.workflow.js"
}

@test "no-id-leak: S5 in-scope files have no model IDs (only model-tiers.md may)" {
  # S5: plan-template.md / longrun-plan SKILL.md / exec.md / workflow テンプレートのいずれにも
  # モデル ID（claude-haiku/sonnet/opus 系）がヒットしない。解決は references/model-tiers.md に集約。
  for f in "$PLAN_TPL" "$PLAN_SKILL" "$EXEC_MD" \
           "${PLUGIN_DIR}/templates/workflow/build-verify.workflow.js" \
           "${PLUGIN_DIR}/templates/workflow/review.workflow.js"; do
    ! grep -qE 'claude-(haiku|sonnet|opus|[0-9])' "$f"
    ! grep -q 'claude-' "$f"
  done
}

# ===========================================================================
# exec.md documents the model-allocation consumption step
# ===========================================================================

@test "exec.md: documents model allocation table consumption" {
  grep -Eq 'モデル割り当て' "$EXEC_MD"
  grep -q 'resolve-model-allocation.mjs' "$EXEC_MD"
  grep -q 'opts.model' "$EXEC_MD"
}

@test "exec.md: documents inherit / fail-soft fallback for model allocation" {
  grep -Eq 'inherit' "$EXEC_MD"
  grep -Eq '上書き' "$EXEC_MD"
}

# ===========================================================================
# render integration: MODEL placeholders produce opts.model or omit it
# ===========================================================================

# Render build-verify with builder model=sonnet, verifier model=null(inherit)
@test "render: builder model 'sonnet' emits model in agent opts" {
  RENDER="${PLUGIN_DIR}/scripts/render-workflow.mjs"
  BV_TPL="${PLUGIN_DIR}/templates/workflow/build-verify.workflow.js"
  SCHEMA_DIR="${PLUGIN_DIR}/schemas"
  node -e '
    const fs=require("fs");
    const bs=fs.readFileSync(process.argv[1],"utf8");
    const vs=fs.readFileSync(process.argv[2],"utf8");
    const params={
      RUN_DIR:"/abs/_longruns/run", PROJECT_ROOT:"/abs",
      CHANGES_JSON: JSON.stringify([{name:"c1",worktree:"_w/c1",dependsOn:[]}]),
      BUILDER_AGENT_TYPE:"longrun:longrun-builder",
      VERIFIER_AGENT_TYPE:"longrun:longrun-verifier",
      BROWSER_VERIFIER_AGENT_TYPE:"longrun:longrun-browser-verifier",
      BUILDER_SCHEMA: JSON.stringify(JSON.parse(bs)),
      VERIFIER_SCHEMA: JSON.stringify(JSON.parse(vs)),
      BUILDER_MODEL: "'"'"'sonnet'"'"'",
      VERIFIER_MODEL: "null"
    };
    fs.writeFileSync(process.argv[3], JSON.stringify(params));
  ' "${SCHEMA_DIR}/builder-report.schema.json" "${SCHEMA_DIR}/verifier-score.schema.json" "${LR_TEST_TMPDIR}/bp.json"
  node "$RENDER" "$BV_TPL" "${LR_TEST_TMPDIR}/bp.json" > "${LR_TEST_TMPDIR}/bv.out.js"
  node --check "${LR_TEST_TMPDIR}/bv.out.js"
  # builderModel resolves to 'sonnet'; conditional spread emits model when truthy
  grep -q "const builderModel = 'sonnet'" "${LR_TEST_TMPDIR}/bv.out.js"
  grep -q 'const verifierModel = null' "${LR_TEST_TMPDIR}/bv.out.js"
  grep -qE 'builderModel \? \{ model: builderModel \}' "${LR_TEST_TMPDIR}/bv.out.js"
}

@test "render: review template emits reviewer model conditionally" {
  RENDER="${PLUGIN_DIR}/scripts/render-workflow.mjs"
  REVIEW_TPL="${PLUGIN_DIR}/templates/workflow/review.workflow.js"
  SCHEMA_DIR="${PLUGIN_DIR}/schemas"
  node -e '
    const fs=require("fs");
    const schema=fs.readFileSync(process.argv[1],"utf8");
    const params={
      PLAN_PATH:"/abs/plan.md", PROJECT_ROOT:"/abs",
      REVIEWER_SCHEMA: JSON.stringify(JSON.parse(schema)),
      REVIEWER_AGENT_TYPE:"longrun:longrun-reviewer",
      REVIEWER_MODEL: "null"
    };
    fs.writeFileSync(process.argv[2], JSON.stringify(params));
  ' "${SCHEMA_DIR}/reviewer-verdict.schema.json" "${LR_TEST_TMPDIR}/rp.json"
  node "$RENDER" "$REVIEW_TPL" "${LR_TEST_TMPDIR}/rp.json" > "${LR_TEST_TMPDIR}/review.out.js"
  node --check "${LR_TEST_TMPDIR}/review.out.js"
  grep -q 'const reviewerModel = null' "${LR_TEST_TMPDIR}/review.out.js"
  grep -qE 'reviewerModel \? \{ model: reviewerModel \}' "${LR_TEST_TMPDIR}/review.out.js"
}

# ===========================================================================
# change longrun-exec-model-allocation — fable tier + reserve downgrade (#26)
# ===========================================================================

@test "model-tiers: defines fable tier with opts.model value" {
  lr_require_file "$TIERS_MD"
  grep -qE "fable.*\`'fable'\`" "$TIERS_MD"
}

@test "model-tiers: documents reserve downgrade rule" {
  grep -q 'FABLE_BUDGET_MODE' "$TIERS_MD"
  grep -q 'LONGRUN_AUTOMATED' "$TIERS_MD"
}

@test "plan-template: header uses 4-tier vocabulary" {
  grep -q 'ティア(haiku/sonnet/fable/inherit)' "$PLAN_TPL"
}

@test "plan-skill: heuristics mention fable for judgment-dense roles" {
  grep -q 'fable' "$PLAN_SKILL"
}

@test "resolve: fable tier resolves to model 'fable'" {
  json="$(env -u FABLE_BUDGET_MODE -u LONGRUN_AUTOMATED node "$RESOLVE" "${MA_FIXTURES}/fable.plan.md" "$TIERS_MD")"
  [ "$(model_of "$json" feature-x reviewer)" = "fable" ]
}

@test "resolve: reserve + automated downgrades fable to opus with warning" {
  json="$(env FABLE_BUDGET_MODE=reserve LONGRUN_AUTOMATED=1 node "$RESOLVE" "${MA_FIXTURES}/fable.plan.md" "$TIERS_MD")"
  [ "$(model_of "$json" feature-x reviewer)" = "opus" ]
  node -e 'const j=JSON.parse(process.argv[1]); process.exit((j.warnings||[]).some(w=>/reserve/.test(w))?0:1)' "$json"
}

@test "resolve: reserve without automated keeps fable" {
  json="$(env -u LONGRUN_AUTOMATED FABLE_BUDGET_MODE=reserve node "$RESOLVE" "${MA_FIXTURES}/fable.plan.md" "$TIERS_MD")"
  [ "$(model_of "$json" feature-x reviewer)" = "fable" ]
}

@test "resolve: reserve does not affect other tiers" {
  json="$(env FABLE_BUDGET_MODE=reserve LONGRUN_AUTOMATED=1 node "$RESOLVE" "${MA_FIXTURES}/fable.plan.md" "$TIERS_MD")"
  [ "$(model_of "$json" feature-x builder)" = "sonnet" ]
  [ "$(model_of "$json" feature-x verifier)" = "haiku" ]
  [ "$(model_of "$json" feature-x browser-verifier)" = "INHERIT" ]
}
