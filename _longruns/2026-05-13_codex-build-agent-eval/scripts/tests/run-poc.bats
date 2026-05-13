#!/usr/bin/env bats

load helpers

setup() {
  setup_fake_repo
}

@test "run-poc.sh exits non-zero when working tree is dirty" {
  # Introduce an unrelated dirty change at repo root.
  echo "dirty" > "$FAKE_REPO/_unrelated_file.txt"

  run env CODEX_DRY_RUN=1 bash "$FAKE_LONGRUN/scripts/run-poc.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"working tree is dirty"* ]] || {
    echo "actual output: $output" >&2
    false
  }
}

@test "run-poc.sh detects sandbox-outside writes and restores them" {
  # Simulate Codex going rogue: produce both a sandbox-internal change AND a
  # sandbox-outside change by injecting them via CODEX_FAKE_WRITES.
  # The script's post-guard must (a) restore the outside path via `git checkout --`
  # and (b) exit non-zero.

  run env CODEX_DRY_RUN=1 \
    CODEX_FAKE_WRITES="outside:plugins/longrun/agents/rogue.md;inside:sandbox-edit" \
    bash "$FAKE_LONGRUN/scripts/run-poc.sh"

  [ "$status" -ne 0 ]
  [[ "$output" == *"sandbox 外"* ]] || {
    echo "actual output: $output" >&2
    false
  }
  # The rogue file must have been restored (i.e. removed, because it was untracked).
  [ ! -f "$FAKE_REPO/plugins/longrun/agents/rogue.md" ]
}

@test "run-poc.sh records used model id in evaluation.md" {
  run env CODEX_DRY_RUN=1 CODEX_MODEL=test-model-x \
    bash "$FAKE_LONGRUN/scripts/run-poc.sh"

  [ "$status" -eq 0 ]
  grep -q "test-model-x" "$FAKE_LONGRUN/evaluation.md"
}

@test "run-poc.sh records wall-clock duration in evaluation.md" {
  run env CODEX_DRY_RUN=1 CODEX_MODEL=test-model-x \
    bash "$FAKE_LONGRUN/scripts/run-poc.sh"

  [ "$status" -eq 0 ]
  # Look for a line like "Codex wall-clock: <N>s"
  grep -Eq "Codex wall-clock: [0-9]+s" "$FAKE_LONGRUN/evaluation.md"
}
