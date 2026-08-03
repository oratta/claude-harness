#!/usr/bin/env bats
#
# Tests for capability: loops-plugin-structure
# Spec: openspec/changes/loops-plugin/specs/loops-plugin-structure/spec.md
# Covers verification-guide.md scenarios S21-S25.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
}

# --- S21: plugin.json が妥当な JSON である ---
@test "S21: plugin.json parses, name is loops, version is semver" {
  local pj="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  [ -f "$pj" ]
  run jq . "$pj"
  [ "$status" -eq 0 ]
  [ "$(jq -r .name "$pj")" = "loops" ]
  jq -r .version "$pj" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
}

# --- S22: 必須ファイル一式が存在する ---
@test "S22: required files exist" {
  [ -f "${PLUGIN_DIR}/skills/loops-design/SKILL.md" ]
  [ -f "${PLUGIN_DIR}/skills/loops-goalify/SKILL.md" ]
  [ -f "${PLUGIN_DIR}/references/loop-types.md" ]
  [ -f "${PLUGIN_DIR}/references/recipe-format.md" ]
  [ -f "${PLUGIN_DIR}/templates/recipe-template.md" ]
  [ -f "${PLUGIN_DIR}/templates/state-template.md" ]
}

# --- S23: 実行スクリプトが存在しない ---
@test "S23: no runtime scripts (*.sh/*.js/*.py excluding *.bats)" {
  # 許可されるのは helper.bash の LOOPS_SCRIPT_ALLOWLIST に明示された具体ファイルだけ
  # （理由と運用は integration.bats の S124 と同一。allowlist は helper.bash が正本）。
  run loops_unlisted_scripts
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- S24: ループ定義 schema が存在しない ---
@test "S24: no *.schema.json under plugin" {
  run bash -c "find '${PLUGIN_DIR}' -type f -name '*.schema.json' || true"
  [ -z "$output" ]
}

# --- S25: モデル ID の grep が 0 件である ---
@test "S25: no hardcoded model IDs" {
  run grep -rE 'claude-(opus|sonnet|haiku|[0-9])' "${PLUGIN_DIR}"
  [ "$status" -ne 0 ]
}
