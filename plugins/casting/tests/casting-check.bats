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

# --- 回帰: 1周目レビューの blocking 指摘（シェル堅牢性） ---

@test "missing-version fixture: reports the missing catalog_version instead of dying silently" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/missing-version"
  [ "$status" -eq 1 ]
  [[ "$output" == *"catalog_version が front matter に無い"* ]]
}

@test "no-front-matter fixture: treated as missing catalog_version without misparsing the body" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/no-front-matter"
  [ "$status" -eq 1 ]
  [[ "$output" == *"catalog_version が front matter に無い"* ]]
  [[ "$output" != *"unknown-vocab"* ]]
}

@test "tight-pipes fixture: rows without a space after the pipe are still linted" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/tight-pipes"
  [ "$status" -eq 1 ]
  [[ "$output" == *"謎のタイト観点"* ]]
  [[ "$output" != *"財務・コスト"* ]]
}

@test "trailing-space fixture: trailing spaces do not cause a false unknown-vocab" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/trailing-space"
  [ "$status" -eq 0 ]
}

@test "multi-perspective fixture: comma-separated perspectives are each validated" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/multi-perspective"
  [ "$status" -eq 0 ]
}

@test "malformed-row fixture: a row with fewer than 5 columns is reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/malformed-row"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed-row"* ]]
  [[ "$output" == *"5列未満"* ]]
}

# --- 回帰: #139（check モードでも同じ経路を検出する） ---

@test "over-column fixture: a row that splits into more than 5 columns is reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/over-column"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed-row"* ]]
  [[ "$output" == *"6列以上"* ]]
}

@test "unclosed-comment fixture: an unbalanced HTML comment is reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/unclosed-comment"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unclosed-comment"* ]]
  [[ "$output" == *"project.md"* ]]
}

@test "local-malformed fixture: a broken local.md is reported with its own path" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/local-malformed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed-row"* ]]
  [[ "$output" == *"local.md"* ]]
}

@test "ok fixture: a balanced HTML comment is not reported as unclosed" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [[ "$output" != *"unclosed-comment"* ]]
}

@test "template project.md: the commented-out example is balanced and not reported" {
  REPO="${BATS_TEST_TMPDIR}/template-repo"
  mkdir -p "${REPO}/.claude/casting"
  cp "${PLUGIN_DIR}/templates/project.md" "${REPO}/.claude/casting/project.md"
  run "$SCRIPT" --catalog "$CATALOG" "$REPO"
  [ "$status" -eq 0 ]
}
