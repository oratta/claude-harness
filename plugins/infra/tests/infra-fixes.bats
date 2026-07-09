#!/usr/bin/env bats
#
# Tests for change-1 (infra-fixes).
# specs: infra-env-file-scheme / infra-secrets-consistency / infra-actions-freshness / infra-doc-integrity
# plan.md 付録 A findings 1-9, 受け入れ条件 5-6, 15.
#
# These tests grep/parse the Markdown agent instructions and workflow templates
# directly (there is no runtime for this plugin outside an actual Claude Code
# session), matching the "参照ゼロ検証" style already used by plan.md 受け入れ条件.

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
  P5="${PLUGIN_DIR}/agents/infra-phase-5-finalize.md"
  P4="${PLUGIN_DIR}/agents/infra-phase-4-github-actions.md"
  P3="${PLUGIN_DIR}/agents/infra-phase-3-vercel.md"
  P2="${PLUGIN_DIR}/agents/infra-phase-2-supabase.md"
  P1="${PLUGIN_DIR}/agents/infra-phase-1-hearing.md"
  SKILL="${PLUGIN_DIR}/skills/infra-setup/SKILL.md"
  README="${PLUGIN_DIR}/README.md"
  PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  WORKFLOWS_DIR="${PLUGIN_DIR}/templates/workflows"
  TEMPLATES_DIR="${PLUGIN_DIR}/templates"
}

# --- infra-env-file-scheme (S1-S5) ---

@test "S1/S5: no comment-based prod value expectation remains in Phase 5" {
  run grep -n "コメントアウト" "$P5"
  [ "$status" -ne 0 ]
}

@test "S2: Step 2 explicitly checks .env.production.local" {
  grep -q '\.env\.production\.local' "$P5"
}

@test "S3: goal description no longer says prod side is commented out" {
  ! grep -q 'prod 側はコメントアウト状態' "$P5"
  grep -q '\.env\.production\.local' "$P5"
}

@test "S4: cautions section reflects two-file scheme" {
  ! grep -q 'prod系がコメントアウトで保存されている前提' "$P5"
  grep -q '\.env\.production\.local.*に prod 値が分離保存されている前提' "$P5"
}

# --- infra-secrets-consistency (S6-S12) ---

@test "S6: every active templates secrets.* (except GITHUB_TOKEN) has a gh secret set line in Phase 4" {
  # Exclude commented-out lines (design.md D2: SUPABASE_SERVICE_ROLE_KEY only appears
  # in ci.yml.template's commented-out E2E block, which is inactive and out of scope).
  names="$(grep -rhoE '^[^#]*secrets\.[A-Z_]*' "$TEMPLATES_DIR" | grep -o 'secrets\.[A-Z_]*' | sort -u | sed 's/^secrets\.//')"
  for name in $names; do
    [ "$name" = "GITHUB_TOKEN" ] && continue
    if ! grep -q "gh secret set ${name}" "$P4"; then
      echo "missing gh secret set for: $name" >&2
      return 1
    fi
  done
}

@test "S7: EDGE_CONFIG_ID documented as optional with example command" {
  grep -q 'EDGE_CONFIG_ID' "$P4"
  grep -q 'メンテナンスモードを使う場合のみ必要' "$P4"
  grep -q 'gh secret set EDGE_CONFIG_ID' "$P4"
}

@test "S8: Phase 2 extracts service_role key alongside anon" {
  grep -q 'anon' "$P2"
  grep -q 'service_role' "$P2"
}

@test "S9: service_role key written only to .env.production.local, not .env.local" {
  # Extract the Step 11 (.env.local) and Step 11.5 (.env.production.local) blocks
  step11="$(awk '/### Step 11: /{flag=1} /### Step 11\.5:/{flag=0} flag' "$P2")"
  step115="$(awk '/### Step 11\.5:/{flag=1} /### Step 12:/{flag=0} flag' "$P2")"
  echo "$step115" | grep -qi 'service_role'
  ! echo "$step11" | grep -qi 'service_role'
}

@test "S10: state file write step does not record the raw service_role key value" {
  step13="$(awk '/### Step 13: /{flag=1} /### Step 14:/{flag=0} flag' "$P2")"
  ! echo "$step13" | grep -qiE 'service_role_key: \{|service_role: \{[A-Za-z_]*_KEY\}'
}

@test "S11: Phase 4 reads PROD_SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY from .env.production.local" {
  step6="$(awk '/### Step 6: /{flag=1} /### Step 7:/{flag=0} flag' "$P4")"
  echo "$step6" | grep -q 'PROD_SUPABASE_URL'
  echo "$step6" | grep -q 'PROD_SUPABASE_ANON_KEY'
  echo "$step6" | grep -q 'PROD_SUPABASE_SERVICE_ROLE_KEY'
  echo "$step6" | grep -q '\.env\.production\.local'
}

@test "S12: Phase 4 reads NEXT_PUBLIC_SUPABASE_URL/ANON_KEY from .env.local" {
  step6="$(awk '/### Step 6: /{flag=1} /### Step 7:/{flag=0} flag' "$P4")"
  echo "$step6" | grep -q 'NEXT_PUBLIC_SUPABASE_URL'
  echo "$step6" | grep -q 'NEXT_PUBLIC_SUPABASE_ANON_KEY'
  echo "$step6" | grep -qE '\.env\.local[^.]'
}

# --- infra-actions-freshness (S13-S20) ---

@test "S13: no stale v4 pins for checkout/setup-node" {
  run grep -rn "actions/checkout@v4\|actions/setup-node@v4" "$WORKFLOWS_DIR"
  [ "$status" -ne 0 ]
}

@test "S14: no stale v4 pin for upload-artifact" {
  run grep -rn "actions/upload-artifact@v4" "$WORKFLOWS_DIR"
  [ "$status" -ne 0 ]
}

@test "S15: no stale v7 pin for github-script" {
  run grep -rn "actions/github-script@v7" "$WORKFLOWS_DIR"
  [ "$status" -ne 0 ]
}

@test "S16: no stale v1 pin for supabase/setup-cli" {
  run grep -rn "supabase/setup-cli@v1" "$WORKFLOWS_DIR"
  [ "$status" -ne 0 ]
}

@test "S17: all five workflow templates parse as YAML" {
  for f in "$WORKFLOWS_DIR"/*.yml.template; do
    ruby -ryaml -e "YAML.load_file('$f')" || return 1
  done
}

@test "S18: Vercel Token CLI investigation note present in Phase 4" {
  grep -q 'tokens' "$P4"
  grep -qE 'CLI 化|CLI 不可|CLI 化不可' "$P4"
}

@test "S19: Vercel Token CLI investigation note present in SKILL.md" {
  grep -qE 'CLI 化|CLI 不可|CLI 化不可' "$SKILL"
}

@test "S20: Step 5 fallback logic keeps the 2-branch structure (auto/manual)" {
  grep -q '自動モード（Playwright MCP 利用可）' "$P4"
  grep -q '手動モード' "$P4"
}

# --- infra-doc-integrity (S21-S31) ---

@test "S21: SKILL.md and Phase 5 document preview as label opt-in" {
  grep -q 'preview` ラベル' "$SKILL"
  grep -q 'preview` ラベル' "$P5"
  # 「Ready for review にすると Preview deploy が走る」旧仕様の記述が残っていないこと
  run grep -n 'Ready for review にすると Preview deploy\|Ready for review で Preview deploy' "$SKILL" "$P5" "$README"
  [ "$status" -ne 0 ]
}

@test "S22: SKILL.md keeps Draft-skip/Ready-for-review CI wording; Phase 5 states label add/remove steps" {
  grep -q 'Draft 中は' "$SKILL"
  grep -q 'Ready for review' "$SKILL"
  grep -q '剥がし' "$P5"
  grep -q '貼っ' "$P5"
}

@test "S23: README.md documents the preview label opt-in" {
  grep -q 'preview` ラベル' "$README"
  grep -q 'opt-in' "$README"
}

@test "S23a: deploy-preview template triggers on labeled/synchronize only" {
  local tpl="${WORKFLOWS_DIR}/deploy-preview.yml.template"
  grep -qE '^\s+types: \[labeled, synchronize\]' "$tpl"
  # 旧仕様のトリガーが残っていないこと
  run grep -nE '^\s+types:.*(opened|ready_for_review)' "$tpl"
  [ "$status" -ne 0 ]
}

@test "S23b: deploy-preview gates on the 'preview' label, not on draft state" {
  local tpl="${WORKFLOWS_DIR}/deploy-preview.yml.template"
  grep -q "github.event.label.name == 'preview'" "$tpl"
  grep -q "contains(github.event.pull_request.labels.\*.name, 'preview')" "$tpl"
  # draft ガードは撤去済み（Draft のままでもラベルで発火させるため）
  run grep -n 'pull_request.draft == false' "$tpl"
  [ "$status" -ne 0 ]
}

@test "S23c: Phase 4 creates the 'preview' label so users can apply it" {
  grep -q 'gh label create preview' "$P4"
}

@test "S24: Phase 1 references correct Phase 2 step numbers (11 / 11.5)" {
  grep -q 'Step 11' "$P1"
  grep -q 'Step 11\.5' "$P1"
}

@test "S25: no stale step-number references remain in Phase 1" {
  run grep -n "Step 10\.5\|の Step 10）" "$P1"
  [ "$status" -ne 0 ]
}

@test "S26: vercel link troubleshooting note is scoped to the re-link case" {
  grep -q '既存プロジェクトへの再リンク時のみ' "$P3"
}

@test "S27: Step 3 and troubleshooting vercel link text no longer conflict unqualified" {
  grep -q '既存プロジェクトへの再リンク時のみ' "$P3"
  grep -q '新規作成には使えない' "$P3"
}

@test "S28: architecture diagram Phase 4 line mentions deploy-preview" {
  grep -E 'infra-phase-4-github-actions.*deploy-preview' "$SKILL"
}

@test "S29: SKILL.md frontmatter version matches plugin.json version" {
  skill_version="$(grep -m1 '^version:' "$SKILL" | sed 's/^version: *//')"
  plugin_version="$(grep -m1 '"version"' "$PLUGIN_JSON" | sed -E 's/.*"version": *"([^"]+)".*/\1/')"
  [ -n "$skill_version" ]
  [ -n "$plugin_version" ]
  [ "$skill_version" = "$plugin_version" ]
}

@test "S30: no personal Dropbox path remains" {
  run grep -rn "/Users/oratta" "$PLUGIN_DIR" --exclude-dir=tests
  [ "$status" -ne 0 ]
}

@test "S31: plugin.json version is bumped above 0.2.0" {
  plugin_version="$(grep -m1 '"version"' "$PLUGIN_JSON" | sed -E 's/.*"version": *"([^"]+)".*/\1/')"
  [ "$plugin_version" != "0.2.0" ]
  # crude semver compare: split into major.minor.patch and compare numerically
  IFS='.' read -r a b c <<< "$plugin_version"
  [ "$a" -gt 0 ] || { [ "$a" -eq 0 ] && { [ "$b" -gt 2 ] || { [ "$b" -eq 2 ] && [ "$c" -gt 0 ]; }; }; }
}

@test "all touched JSON parses (jq)" {
  jq empty "$PLUGIN_JSON"
}
