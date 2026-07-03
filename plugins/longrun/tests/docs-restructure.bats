#!/usr/bin/env bats
#
# Tests for change-3 (longrun-v5-cleanup), capability longrun-docs-restructure.
# spec: openspec/changes/longrun-v5-cleanup/specs/longrun-docs-restructure/spec.md
#       (S19-S28 in the run's verification-guide).
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
  README="${PLUGIN_DIR}/README.md"
  CHANGELOG="${PLUGIN_DIR}/CHANGELOG.md"
  EXEC_MD="${PLUGIN_DIR}/commands/exec.md"
  LONGRUN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  LR_JSON="${LR_DIR}/.claude-plugin/plugin.json"
}

# --- S19: CHANGELOG.md exists with full historical record ---

@test "docs: CHANGELOG.md exists" {
  [ -f "$CHANGELOG" ]
}

@test "docs: CHANGELOG.md contains v4.0 through v6.2 entries" {
  grep -qE '## v4\.0' "$CHANGELOG"
  grep -qE '## v5\.0' "$CHANGELOG"
  grep -qE '## v5\.1' "$CHANGELOG"
  grep -qE '## v5\.2' "$CHANGELOG"
  grep -qE '## v5\.3' "$CHANGELOG"
  grep -qE '## v6\.0' "$CHANGELOG"
  grep -qE '## v6\.1' "$CHANGELOG"
  grep -qE '## v6\.2' "$CHANGELOG"
}

# --- S20: README.md no longer has version-history headings ---

@test "docs: README.md has zero version-history headings" {
  run grep -qE '^## v[0-9]+\.[0-9]+ 変更点' "$README"
  [ "$status" -ne 0 ]
}

# --- S21: README.md links to CHANGELOG.md ---

@test "docs: README.md references CHANGELOG.md near the top" {
  head -20 "$README" | grep -q 'CHANGELOG.md'
}

# --- S22: current-feature sections survive unchanged in substance ---

@test "docs: README.md retains command table, architecture, naming rules sections" {
  grep -qE '^## コマンド' "$README"
  grep -qE '^## アーキテクチャ' "$README"
  grep -qE '^## 命名規則' "$README"
  grep -qE '^## MVP プランモード' "$README"
  grep -qE '^## OpenSpec 縮退モード' "$README"
}

@test "docs: README.md command table rows are unchanged" {
  grep -qE '`/longrun:plan`.*`/lr:p`' "$README"
  grep -qE '`/longrun:exec`.*`/lr:e`' "$README"
  grep -qE '`/longrun:archive`.*`/lr:a`' "$README"
  grep -qE '`/longrun:feedback`.*`/lr:f`' "$README"
}

# --- S23: deprecation subsection removed from README's current MVP section ---

@test "docs: README.md has no --mode=mvp deprecation subsection" {
  run grep -qE '^### .?--mode=mvp' "$README"
  [ "$status" -ne 0 ]
}

@test "docs: README.md MVP section (between its heading and the next H2) has zero mode=mvp mentions" {
  awk '/^## MVP プランモード/{flag=1; next} /^## /{flag=0} flag' "$README" > /tmp/orphan-cleanup-mvp-section.$$.txt
  run grep -q 'mode=mvp' /tmp/orphan-cleanup-mvp-section.$$.txt
  rm -f /tmp/orphan-cleanup-mvp-section.$$.txt
  [ "$status" -ne 0 ]
}

# --- S24: longrun plugin.json description is compressed ---

@test "docs: longrun plugin.json description is compressed and still mentions autonomous execution" {
  d="$(jq -r '.description' "$LONGRUN_JSON")"
  periods="$(echo "$d" | grep -o '。' | wc -l | tr -d ' ')"
  [ "$periods" -le 2 ]
  len="$(echo -n "$d" | wc -m | tr -d ' ')"
  [ "$len" -le 200 ]
  echo "$d" | grep -qE '自律実行|autonomous'
}

# --- S25: lr plugin.json description is compressed, keeps /lr:m ---

@test "docs: lr plugin.json description is compressed and still mentions /lr:m" {
  d="$(jq -r '.description' "$LR_JSON")"
  periods="$(echo "$d" | grep -o '。' | wc -l | tr -d ' ')"
  [ "$periods" -le 2 ]
  len="$(echo -n "$d" | wc -m | tr -d ' ')"
  [ "$len" -le 200 ]
  echo "$d" | grep -q '/lr:m'
}

# --- S26: checkpoint.md reframed as optional/foldable ---

@test "docs: exec.md checkpoint.md section frames it as optional and foldable into decisions.md" {
  grep -qE '任意' "$EXEC_MD"
  grep -qE 'decisions\.md.*統合' "$EXEC_MD"
}

# --- S27: no-machine-parse prohibition preserved ---

@test "docs: exec.md still forbids machine-parsing checkpoint.md for control flow" {
  grep -Eq 'checkpoint.md を grep/sed|パースして制御フロー' "$EXEC_MD"
}

# --- S28: workflow-runs.jsonl / resumeFromRunId flow untouched ---

@test "docs: exec.md Step 4 runId recording section is present and untouched in substance" {
  grep -q 'workflow-runs.jsonl' "$EXEC_MD"
  grep -q 'runId 記録' "$EXEC_MD"
}

@test "docs: exec.md Step 5 resumeFromRunId section is present and untouched in substance" {
  grep -q 'resumeFromRunId' "$EXEC_MD"
  grep -qE '中断.*再開' "$EXEC_MD"
}

# --- syntax: touched JSON parses ---

@test "docs: touched JSON files parse (jq)" {
  jq empty "$LONGRUN_JSON"
  jq empty "$LR_JSON"
}
