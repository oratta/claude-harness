#!/usr/bin/env bats

load helpers

setup() {
  setup_fake_repo
}

@test "run-fallback.sh routes to fallback when --simulate-codex-down is given" {
  run bash "$FAKE_LONGRUN/scripts/run-fallback.sh" --simulate-codex-down
  [ "$status" -eq 0 ]
  [[ "$output" == *"fallback"* ]] || {
    echo "actual output: $output" >&2
    false
  }
}

@test "run-fallback.sh emits Opus path log entry on fallback" {
  run bash "$FAKE_LONGRUN/scripts/run-fallback.sh" --simulate-codex-down
  [ "$status" -eq 0 ]
  # Either stdout or evaluation.md should reference the Opus fallback path.
  if [[ "$output" == *"Opus"* ]]; then
    :
  else
    grep -q "Opus" "$FAKE_LONGRUN/evaluation.md"
  fi
}

@test "run-fallback.sh records opus wall-clock in evaluation.md" {
  run bash "$FAKE_LONGRUN/scripts/run-fallback.sh" --simulate-codex-down
  [ "$status" -eq 0 ]
  grep -Eq "Opus wall-clock: [0-9]+s" "$FAKE_LONGRUN/evaluation.md"
}
