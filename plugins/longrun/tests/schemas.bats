#!/usr/bin/env bats
#
# Tests for change-2 task 2.x — JSON Schema 外部化.
# Verifies that the three subagent contract schemas exist, parse as JSON (jq),
# and declare the fields the spec requires (builder report / verifier 4-axis
# score / reviewer verdict). These schemas are the StructuredOutput contract
# the generated Workflow script enforces via agent(prompt, {schema}).
#
# Acceptance condition 8a / spec "schema 群が外部ファイルとして存在し構文検証を通る".

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  SCHEMA_DIR="${PLUGIN_DIR}/schemas"
  BUILDER="${SCHEMA_DIR}/builder-report.schema.json"
  VERIFIER="${SCHEMA_DIR}/verifier-score.schema.json"
  REVIEWER="${SCHEMA_DIR}/reviewer-verdict.schema.json"
}

# --- existence ---

@test "schemas: builder-report.schema.json exists" {
  [ -f "$BUILDER" ]
}

@test "schemas: verifier-score.schema.json exists" {
  [ -f "$VERIFIER" ]
}

@test "schemas: reviewer-verdict.schema.json exists" {
  [ -f "$REVIEWER" ]
}

# --- jq syntax validation (build-equivalent) ---

@test "schemas: all *.schema.json parse with jq" {
  for f in "$SCHEMA_DIR"/*.schema.json; do
    jq empty "$f"
  done
}

# --- builder report required fields ---

@test "schemas: builder report enforces commits / tasks / tests" {
  run jq -e '.required | index("commits")' "$BUILDER"
  [ "$status" -eq 0 ]
  run jq -e '.required | index("tasks")' "$BUILDER"
  [ "$status" -eq 0 ]
  run jq -e '.required | index("tests")' "$BUILDER"
  [ "$status" -eq 0 ]
}

@test "schemas: builder report forbids extra properties" {
  v="$(jq -r '.additionalProperties' "$BUILDER")"
  [ "$v" = "false" ]
}

# --- verifier 4-axis fields ---

@test "schemas: verifier score has the 4 axes" {
  for axis in functionality quality completeness ux; do
    run jq -e --arg a "$axis" '.properties[$a]' "$VERIFIER"
    [ "$status" -eq 0 ]
  done
}

@test "schemas: verifier axes are bounded 0..100" {
  for axis in functionality quality completeness ux; do
    lo="$(jq -r --arg a "$axis" '.properties[$a].minimum' "$VERIFIER")"
    hi="$(jq -r --arg a "$axis" '.properties[$a].maximum' "$VERIFIER")"
    [ "$lo" = "0" ]
    [ "$hi" = "100" ]
  done
}

# --- reviewer verdict enum ---

@test "schemas: reviewer verdict status enum is APPROVE|REQUEST_CHANGES" {
  enum="$(jq -rc '.properties.status.enum | sort | join(",")' "$REVIEWER")"
  [ "$enum" = "APPROVE,REQUEST_CHANGES" ]
}

@test "schemas: reviewer verdict requires findings array" {
  run jq -e '.required | index("findings")' "$REVIEWER"
  [ "$status" -eq 0 ]
  t="$(jq -r '.properties.findings.type' "$REVIEWER")"
  [ "$t" = "array" ]
}
