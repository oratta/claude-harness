#!/usr/bin/env bats
#
# casting-project-files: resolve による有効な配役表の合成表示
# spec: openspec/changes/casting-row-level-inheritance/specs/casting-project-files/spec.md
#   Requirement: resolve による有効な配役表の合成表示

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/casting-check.sh"
  CATALOG="${PLUGIN_DIR}/catalog/catalog.md"
  FIXTURES="${PLUGIN_DIR}/tests/fixtures"
}

# --- Scenario: 上書きと継承が由来つきで合成される ---

@test "catalog-only fixture: all 14 perspectives resolve to catalog default" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/resolve-catalog-only"
  [ "$status" -eq 0 ]
  [[ "$output" == *"由来"* ]]
  [ "$(echo "$output" | grep -cF 'カタログ既定')" -eq 14 ]
  [[ "$output" == *"財務・コスト"* ]]
}

@test "project-override fixture: the overridden perspective resolves from project" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/resolve-project-override"
  [ "$status" -eq 0 ]
  row="$(echo "$output" | grep -F '| 財務・コスト |')"
  [[ "$row" == *"エージェント（予算方針文を整備済み）"* ]]
  [[ "$row" == *"| project |" ]]
  [ "$(echo "$output" | grep -cF 'カタログ既定')" -eq 13 ]
}

@test "local-override fixture: project and local perspectives resolve from their own layer" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/resolve-local-override"
  [ "$status" -eq 0 ]
  project_row="$(echo "$output" | grep -F '| 財務・コスト |')"
  local_row="$(echo "$output" | grep -F '| 技術設計・品質 |')"
  [[ "$project_row" == *"| project |" ]]
  [[ "$local_row" == *"| local |" ]]
  [ "$(echo "$output" | grep -cF 'カタログ既定')" -eq 12 ]
}

# --- 補足: resolve サブコマンド追加後も既定の check 動作は壊れない ---

@test "default check subcommand still works on a diff-style project.md with zero rows" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/resolve-catalog-only"
  [ "$status" -eq 0 ]
}

# --- 回帰: 2周目レビューの blocking 指摘 ---

@test "template project.md: comment example is not treated as an override" {
  REPO="${BATS_TEST_TMPDIR}/template-repo"
  mkdir -p "${REPO}/.claude/casting"
  cp "$(dirname "$BATS_TEST_FILENAME")/../templates/project.md" "${REPO}/.claude/casting/project.md"
  run "$SCRIPT" resolve --catalog "$CATALOG" "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" != *"| project |"* ]]
  row="$(echo "$output" | grep -F '| 財務・コスト |')"
  [[ "$row" == *"カタログ既定 |" ]]
  [ "$(echo "$output" | grep -cF 'カタログ既定')" -eq 14 ]
}

# --- Scenario: 検証を通らない配役表では合成表を出さない（fail-closed / #117） ---

@test "malformed-row fixture: resolve refuses with exit 1, empty stdout, reason on stderr" {
  run --separate-stderr "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/malformed-row"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"malformed-row"* ]]
  [[ "$stderr" == *"project.md"* ]]
  [[ "$stderr" == *"5列未満"* ]]
}

@test "unknown-vocab fixture: resolve refuses and names the unknown perspective on stderr" {
  run --separate-stderr "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/unknown-vocab"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"unknown-vocab"* ]]
  [[ "$stderr" == *"project.md"* ]]
  [[ "$stderr" == *"謎の観点"* ]]
}

@test "version-mismatch fixture: resolve refuses and shows both versions on stderr" {
  run --separate-stderr "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/version-mismatch"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"version-mismatch"* ]]
  [[ "$stderr" == *"catalog_version=2"* ]]
  [[ "$stderr" == *"version=1"* ]]
}

@test "missing-version fixture: resolve refuses when catalog_version is absent" {
  run --separate-stderr "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/missing-version"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"catalog_version が front matter に無い"* ]]
  [[ "$stderr" == *"project.md"* ]]
}

@test "no-front-matter fixture: resolve treats it as missing catalog_version and refuses" {
  run --separate-stderr "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/no-front-matter"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"catalog_version が front matter に無い"* ]]
  [[ "$stderr" == *"project.md"* ]]
}

# --- Scenario: 起案シグナルだけの repo は今までどおり合成できる（過剰な fail-closed をしない） ---

@test "catalog-external-precedent fixture: resolve still emits the table (proposal signals do not block)" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/catalog-external-precedent"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -cF 'カタログ既定')" -eq 14 ]
}

@test "repeated-not-issue fixture: resolve still emits the table (proposal signals do not block)" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/repeated-not-issue"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -cF 'カタログ既定')" -eq 14 ]
}
