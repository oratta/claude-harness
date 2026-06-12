#!/usr/bin/env bats
#
# Tests for change-2 task 3.x / 5.x — Workflow スクリプトテンプレートの静的検証.
#
# テンプレート（plugins/longrun/templates/workflow/*.workflow.js）を fixture params で
# レンダリングし、生成後スクリプトが Workflow ツール制約を遵守することを静的に検証する:
#   - 禁止 API（Date.now / Math.random / 引数なし new Date）不使用
#   - meta がピュアリテラル（meta 定義内に変数参照・関数呼び出しが無い）
#   - Verify ループ上限が 3（コードの条件式に現れる）+ budget null ガード
#   - schema が外部 schema ファイル由来でインライン化されている
#   - workflow() ネスト 1 段（テンプレート内で子 workflow を起動しない）
#   - 生成後スクリプトが node --check（構文検証）を通る
#
# spec: workflow-exec「生成スクリプトが Workflow ツールの制約を遵守する」(S5)
#       workflow-run-control「上限 3 周」(S15) / budget 枯渇 (S16)

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  TPL_DIR="${PLUGIN_DIR}/templates/workflow"
  SCHEMA_DIR="${PLUGIN_DIR}/schemas"
  RENDER="${PLUGIN_DIR}/scripts/render-workflow.mjs"
  REVIEW_TPL="${TPL_DIR}/review.workflow.js"
  BV_TPL="${TPL_DIR}/build-verify.workflow.js"
  lr_make_tmpdir
}

teardown() {
  lr_teardown_tmpdir
}

# Render review template into $LR_TEST_TMPDIR/review.out.js
render_review() {
  node -e '
    const fs=require("fs");
    const schema=fs.readFileSync(process.argv[1],"utf8");
    const params={
      PLAN_PATH:"/abs/_longruns/run/plan.md",
      PROJECT_ROOT:"/abs",
      REVIEWER_SCHEMA: JSON.stringify(JSON.parse(schema)),
      REVIEWER_AGENT_TYPE:"longrun:longrun-reviewer"
    };
    fs.writeFileSync(process.argv[2], JSON.stringify(params));
  ' "${SCHEMA_DIR}/reviewer-verdict.schema.json" "${LR_TEST_TMPDIR}/rp.json"
  node "$RENDER" "$REVIEW_TPL" "${LR_TEST_TMPDIR}/rp.json" > "${LR_TEST_TMPDIR}/review.out.js"
}

# Render build-verify template into $LR_TEST_TMPDIR/bv.out.js
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
      BUILDER_SCHEMA: JSON.stringify(JSON.parse(bs)),
      VERIFIER_SCHEMA: JSON.stringify(JSON.parse(vs))
    };
    fs.writeFileSync(process.argv[3], JSON.stringify(params));
  ' "${SCHEMA_DIR}/builder-report.schema.json" "${SCHEMA_DIR}/verifier-score.schema.json" "${LR_TEST_TMPDIR}/bp.json"
  node "$RENDER" "$BV_TPL" "${LR_TEST_TMPDIR}/bp.json" > "${LR_TEST_TMPDIR}/bv.out.js"
}

# --- template files exist ---

@test "template: review and build-verify templates exist" {
  [ -f "$REVIEW_TPL" ]
  [ -f "$BV_TPL" ]
}

# --- rendering succeeds with no leftover placeholders ---

@test "template: review renders with no leftover __NAME__ placeholders" {
  render_review
  run grep -o '__[A-Z][A-Z0-9_]*__' "${LR_TEST_TMPDIR}/review.out.js"
  [ "$status" -ne 0 ]   # grep finds nothing
}

@test "template: build-verify renders with no leftover __NAME__ placeholders" {
  render_bv
  run grep -o '__[A-Z][A-Z0-9_]*__' "${LR_TEST_TMPDIR}/bv.out.js"
  [ "$status" -ne 0 ]
}

@test "template: render-workflow errors on missing param" {
  echo '{}' > "${LR_TEST_TMPDIR}/empty.json"
  run node "$RENDER" "$REVIEW_TPL" "${LR_TEST_TMPDIR}/empty.json"
  [ "$status" -ne 0 ]
}

# --- generated scripts parse as JavaScript ---

@test "template: rendered review passes node --check" {
  render_review
  node --check "${LR_TEST_TMPDIR}/review.out.js"
}

@test "template: rendered build-verify passes node --check" {
  render_bv
  node --check "${LR_TEST_TMPDIR}/bv.out.js"
}

# --- forbidden API checks (executable code only; comments may mention them) ---

# Strip // line comments and /* */ block comments, then print remaining code.
strip_comments() {
  node -e '
    const fs=require("fs");
    let s=fs.readFileSync(process.argv[1],"utf8");
    s=s.replace(/\/\*[\s\S]*?\*\//g,"");        // block comments
    s=s.split("\n").map(l=>l.replace(/\/\/.*$/,"")).join("\n"); // line comments
    process.stdout.write(s);
  ' "$1"
}

@test "template: rendered scripts contain no Date.now() in code" {
  render_review
  render_bv
  ! strip_comments "${LR_TEST_TMPDIR}/review.out.js" | grep -q 'Date\.now'
  ! strip_comments "${LR_TEST_TMPDIR}/bv.out.js" | grep -q 'Date\.now'
}

@test "template: rendered scripts contain no Math.random() in code" {
  render_review
  render_bv
  ! strip_comments "${LR_TEST_TMPDIR}/review.out.js" | grep -q 'Math\.random'
  ! strip_comments "${LR_TEST_TMPDIR}/bv.out.js" | grep -q 'Math\.random'
}

@test "template: rendered scripts contain no argless new Date() in code" {
  render_review
  render_bv
  # new Date() with empty parens is forbidden; new Date(args.x) is fine.
  ! strip_comments "${LR_TEST_TMPDIR}/review.out.js" | grep -qE 'new Date\([[:space:]]*\)'
  ! strip_comments "${LR_TEST_TMPDIR}/bv.out.js" | grep -qE 'new Date\([[:space:]]*\)'
}

@test "template: source templates avoid forbidden APIs in code" {
  ! strip_comments "$REVIEW_TPL" | grep -qE 'Date\.now|Math\.random|new Date\([[:space:]]*\)'
  ! strip_comments "$BV_TPL" | grep -qE 'Date\.now|Math\.random|new Date\([[:space:]]*\)'
}

# --- timestamp comes from args (not generated at runtime) ---

@test "template: timestamp is sourced from args.timestamp" {
  render_bv
  grep -q 'args\.timestamp' "${LR_TEST_TMPDIR}/bv.out.js"
}

# --- meta pure-literal (no interpolation / calls inside meta block) ---

@test "template: meta blocks are pure literals (no \${} interpolation)" {
  # Extract the meta object literal and assert it has no template interpolation
  # or function calls inside it.
  for tpl in "$REVIEW_TPL" "$BV_TPL"; do
    meta_block="$(awk '/export const meta = \{/{f=1} f{print} /^\};/{if(f)exit}' "$tpl")"
    [ -n "$meta_block" ]
    echo "$meta_block" | grep -q '\${' && return 1
    # no function-call syntax like foo( inside meta
    echo "$meta_block" | grep -qE '[a-zA-Z_]\(' && return 1
  done
  return 0
}

# --- Verify loop cap = 3 in code ---

@test "template: Verify loop max rounds is 3 in the code" {
  grep -q 'VERIFY_MAX_ROUNDS = 3' "$BV_TPL"
  grep -q 'round < VERIFY_MAX_ROUNDS' "$BV_TPL"
}

@test "template: Verify loop has budget null-guard" {
  # `budget.total && budget.remaining()` guard must be present (null-guard).
  grep -qE 'budget\.total[[:space:]]*&&[[:space:]]*budget\.remaining' "$BV_TPL"
}

@test "template: budget exhaustion is a distinct stop reason" {
  grep -q 'BUDGET_EXHAUSTED' "$BV_TPL"
  grep -q 'MAX_ROUNDS_REACHED' "$BV_TPL"
}

# --- schema is referenced from external schema files (inlined object literal) ---

@test "template: builder/verifier/reviewer schemas are inlined from external files" {
  render_review
  render_bv
  # reviewer schema title appears inlined in review output
  grep -q 'reviewer-verdict' "${LR_TEST_TMPDIR}/review.out.js"
  # builder + verifier schema titles appear inlined in build-verify output
  grep -q 'builder-report' "${LR_TEST_TMPDIR}/bv.out.js"
  grep -q 'verifier-score' "${LR_TEST_TMPDIR}/bv.out.js"
}

@test "template: agent calls pass schema opt" {
  grep -q 'schema: reviewerSchema' "$REVIEW_TPL"
  grep -q 'schema: builderSchema' "$BV_TPL"
  grep -q 'schema: verifierSchema' "$BV_TPL"
}

# --- builder agentType is parameterized, default longrun:longrun-builder (D6 / S12) ---

@test "template: builder agentType is parameterized" {
  grep -q 'BUILDER_AGENT_TYPE' "$BV_TPL"
}

@test "template: rendered build defaults to longrun:longrun-builder" {
  render_bv
  grep -q "agentType: 'longrun:longrun-builder'" "${LR_TEST_TMPDIR}/bv.out.js"
}

# --- workflow nesting depth 1 (no nested workflow() inside templates) ---

@test "template: templates do not nest workflow() calls in code" {
  ! strip_comments "$REVIEW_TPL" | grep -qE '(^|[^.A-Za-z])workflow\('
  ! strip_comments "$BV_TPL" | grep -qE '(^|[^.A-Za-z])workflow\('
}
