#!/usr/bin/env bats
#
# Tests for plugins/experience-to-skill/scripts/sanitize.sh
#
# Verifies the Layer 1 regex-based secret/PII redaction logic that
# powers the jsonl distillation pipeline.

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SANITIZE_SH="$SCRIPT_DIR/scripts/sanitize.sh"
  [ -f "$SANITIZE_SH" ] || skip "sanitize.sh not yet present"
  # shellcheck source=/dev/null
  source "$SANITIZE_SH"
  export -f e2s_sanitize
}

@test "e2s_sanitize redacts OpenAI API key" {
  run bash -c "printf 'My key is sk-abcdefghijklmnopqrstuvwxyz1234' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED:openai_key]"* ]]
  [[ "$output" != *"sk-abcdefghijklmnopqrstuvwxyz1234"* ]]
}

@test "e2s_sanitize redacts Anthropic API key" {
  run bash -c "printf 'token: sk-ant-api03-abcdefghijklmnopqrstuvwxyz' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED:anthropic_key]"* ]]
  [[ "$output" != *"sk-ant-api03-abcdefghijklmnopqrstuvwxyz"* ]]
}

@test "e2s_sanitize redacts AWS access key" {
  run bash -c "printf 'AWS: AKIAIOSFODNN7EXAMPLE' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED:aws_access_key]"* ]]
  [[ "$output" != *"AKIAIOSFODNN7EXAMPLE"* ]]
}

@test "e2s_sanitize redacts GitHub token" {
  run bash -c "printf 'token=ghp_abcdefghijklmnopqrstuvwxyz0123456789' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED:github_token]"* ]]
}

@test "e2s_sanitize redacts GitHub PAT" {
  pat="github_pat_$(printf 'a%.0s' {1..82})"
  run bash -c "printf '%s' '$pat' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED:github_pat]"* ]]
}

@test "e2s_sanitize redacts JWT" {
  run bash -c "printf 'auth: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED:jwt]"* ]]
}

@test "e2s_sanitize redacts PEM private key marker" {
  run bash -c "printf '%s' '-----BEGIN RSA PRIVATE KEY-----' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED:pem_private_key]"* ]]
}

@test "e2s_sanitize redacts email address" {
  run bash -c "printf 'Contact: foo@example.com for info' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED:email]"* ]]
  [[ "$output" != *"foo@example.com"* ]]
}

@test "e2s_sanitize preserves benign text" {
  input="Hello world, this is a normal log line."
  run bash -c "printf '%s' \"$input\" | e2s_sanitize"
  [ "$status" -eq 0 ]
  [ "$output" = "$input" ]
}

@test "e2s_sanitize redacts multiple secrets in one pass" {
  run bash -c "printf 'k1=sk-aaaaaaaaaaaaaaaaaaaaaaa k2=ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[REDACTED:openai_key]"* ]]
  [[ "$output" == *"[REDACTED:github_token]"* ]]
}

@test "e2s_sanitize is idempotent on already-sanitized text" {
  sanitized="key=[REDACTED:openai_key] mail=[REDACTED:email]"
  run bash -c "printf '%s' '$sanitized' | e2s_sanitize"
  [ "$status" -eq 0 ]
  [ "$output" = "$sanitized" ]
}

@test "fixture sample-session.jsonl is already clean (sanitize-idempotent)" {
  fixture="$SCRIPT_DIR/tests/fixtures/sample-session.jsonl"
  [ -f "$fixture" ]
  original="$(cat "$fixture")"
  sanitized="$(e2s_sanitize < "$fixture")"
  [ "$original" = "$sanitized" ]
}
