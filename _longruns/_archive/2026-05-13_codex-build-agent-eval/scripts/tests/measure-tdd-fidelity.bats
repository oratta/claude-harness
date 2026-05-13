#!/usr/bin/env bats

load helpers

setup() {
  setup_fake_repo

  # Build a synthetic commit history that exercises all four categories.
  cd "$FAKE_REPO"

  # Category: tests only.
  mkdir -p "$LONGRUN_REL/sandbox/tests"
  printf 'test1\n' > "$LONGRUN_REL/sandbox/tests/a.test.ts"
  git add -A && git commit -q -m "test: add a.test.ts"

  # Category: production only.
  printf 'export const x = 1;\n' > "$LONGRUN_REL/sandbox/src/a.ts"
  git add -A && git commit -q -m "feat: add a.ts (production only)"

  # Category: both.
  printf 'export const y = 2;\n' > "$LONGRUN_REL/sandbox/src/b.ts"
  printf 'test2\n' > "$LONGRUN_REL/sandbox/tests/b.test.ts"
  git add -A && git commit -q -m "feat: add b with test"

  # Category: neither (docs).
  printf '# notes\n' > "$LONGRUN_REL/notes.md"
  git add -A && git commit -q -m "docs: notes"
}

@test "measure-tdd-fidelity.sh classifies commits into 4 categories" {
  run bash "$FAKE_LONGRUN/scripts/measure-tdd-fidelity.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tests-only"* ]]
  [[ "$output" == *"production-only"* ]]
  [[ "$output" == *"both"* ]]
  [[ "$output" == *"neither"* ]]
}

@test "measure-tdd-fidelity.sh outputs no-test-rate as percentage" {
  run bash "$FAKE_LONGRUN/scripts/measure-tdd-fidelity.sh"
  [ "$status" -eq 0 ]
  # Expect a line like "no-test-rate: 20%" or similar percent.
  [[ "$output" =~ no-test-rate:[[:space:]]*[0-9]+(\.[0-9]+)?% ]] || {
    echo "actual output: $output" >&2
    false
  }
}

@test "measure-tdd-fidelity.sh appends summary to evaluation.md" {
  run bash "$FAKE_LONGRUN/scripts/measure-tdd-fidelity.sh"
  [ "$status" -eq 0 ]
  grep -q "no-test-rate" "$FAKE_LONGRUN/evaluation.md"
}
