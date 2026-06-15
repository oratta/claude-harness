#!/usr/bin/env bats
#
# Tests for change-2 task 5.5 — schema 検証層が不正形式の成果物を機構的に拒否する.
#
# Workflow ツールの agent(prompt, {schema}) は内部で StructuredOutput を検証し、不適合は
# モデルにリトライさせる（散文の無言受理を起こさない）。本テストは同等の検証ロジック
# (scripts/validate-against-schema.mjs) で、conformant fixture は受理され non-conformant
# fixture は拒否されることを検証する。受け入れ条件 8a / spec workflow-exec
# 「不正形式の成果物が機構的に拒否される」(S7) の自動検証。

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  SCHEMA_DIR="${PLUGIN_DIR}/schemas"
  ART="${FIXTURES_DIR}/artifacts"
  VALIDATE="${PLUGIN_DIR}/scripts/validate-against-schema.mjs"
}

valid_for() {  # <schema-basename> <fixture>
  run node "$VALIDATE" "${SCHEMA_DIR}/$1" "${ART}/$2"
  [ "$status" -eq 0 ]
}

invalid_for() {  # <schema-basename> <fixture>
  run node "$VALIDATE" "${SCHEMA_DIR}/$1" "${ART}/$2"
  [ "$status" -eq 1 ]
}

# --- validator exists ---

@test "schema-rejection: validator script exists" {
  [ -f "$VALIDATE" ]
}

# --- conformant artifacts are accepted ---

@test "schema-rejection: valid builder report is accepted" {
  valid_for builder-report.schema.json builder-valid.json
}

@test "schema-rejection: valid verifier score is accepted" {
  valid_for verifier-score.schema.json verifier-valid.json
}

@test "schema-rejection: valid reviewer verdict is accepted" {
  valid_for reviewer-verdict.schema.json reviewer-valid.json
}

# --- builder report: bad enum / extra prop / missing required are rejected ---

@test "schema-rejection: builder report with wrong status enum is rejected" {
  invalid_for builder-report.schema.json builder-invalid-enum.json
}

@test "schema-rejection: builder report with extra (smuggled) property is rejected" {
  invalid_for builder-report.schema.json builder-invalid-extra.json
}

@test "schema-rejection: builder report missing tests block is rejected" {
  invalid_for builder-report.schema.json builder-invalid-missing.json
}

# --- verifier score: out-of-range / bad verdict are rejected ---

@test "schema-rejection: verifier score with axis > 100 is rejected" {
  invalid_for verifier-score.schema.json verifier-invalid-range.json
}

@test "schema-rejection: verifier score with unknown verdict is rejected" {
  invalid_for verifier-score.schema.json verifier-invalid-verdict.json
}

# --- reviewer verdict: bad severity / bad status are rejected ---

@test "schema-rejection: reviewer verdict with unknown severity is rejected" {
  invalid_for reviewer-verdict.schema.json reviewer-invalid-severity.json
}

@test "schema-rejection: reviewer verdict with unknown status is rejected" {
  invalid_for reviewer-verdict.schema.json reviewer-invalid-status.json
}
