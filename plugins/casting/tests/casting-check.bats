#!/usr/bin/env bats
#
# casting-catalog / casting-project-files: casting-check.sh の4検出項目
# spec: openspec/changes/casting-plugin/specs/casting-project-files/spec.md
#   Requirement: casting-check.sh の検出項目

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/casting-check.sh"
  CATALOG="${PLUGIN_DIR}/catalog/catalog.md"
  FIXTURES="${PLUGIN_DIR}/tests/fixtures"
}

# --- Scenario: 問題のないフィクスチャで exit 0 ---

@test "ok fixture: exits 0 with no findings" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [ "$status" -eq 0 ]
}

# --- Scenario: 4種の検出がそれぞれ報告される ---

@test "unknown-vocab fixture: reports the unknown perspective name and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/unknown-vocab"
  [ "$status" -eq 1 ]
  [[ "$output" == *"謎の観点"* ]]
  [[ "$output" == *"project.md"* ]]
}

@test "catalog-external-precedent fixture: reports the out-of-catalog precedent and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/catalog-external-precedent"
  [ "$status" -eq 1 ]
  [[ "$output" == *"カタログ外"* ]]
  [[ "$output" == *"precedents.md"* ]]
}

@test "repeated-not-issue fixture: reports the perspective repeated as not-an-issue and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/repeated-not-issue"
  [ "$status" -eq 1 ]
  [[ "$output" == *"信用・レピュテーション"* ]]
  [[ "$output" == *"論点じゃなかった"* ]]
}

@test "version-mismatch fixture: reports the catalog_version mismatch and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/version-mismatch"
  [ "$status" -eq 1 ]
  [[ "$output" == *"catalog_version"* ]]
  [[ "$output" == *"project.md"* ]]
}

# --- 補足: 未知語彙のフィクスチャは version 不一致など他項目を誤検出しない ---

@test "unknown-vocab fixture: does not also report a version mismatch" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/unknown-vocab"
  [[ "$output" != *"version-mismatch"* ]]
}

@test "ok fixture: catalog_version matches so no version-mismatch finding" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [[ "$output" != *"version-mismatch"* ]]
}
