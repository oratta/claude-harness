#!/usr/bin/env bash
# Shared helpers for Bats tests in this PoC harness.
#
# Strategy: instead of mutating the real worktree, every test spins up a
# disposable git repo under BATS_TEST_TMPDIR that mirrors the directory layout
# the production scripts expect ($REPO_ROOT/_longruns/.../{sandbox,scripts,evaluation.md}).
# The scripts under test are copied (not symlinked, to avoid `git rev-parse`
# resolving outside the fake repo).

LONGRUN_REL="_longruns/2026-05-13_codex-build-agent-eval"

# Source path (real harness) — discovered via Bats' own location.
HARNESS_DIR_REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LONGRUN_DIR_REAL="$(cd "$HARNESS_DIR_REAL/.." && pwd)"

setup_fake_repo() {
  FAKE_REPO="$BATS_TEST_TMPDIR/fakerepo"
  mkdir -p "$FAKE_REPO/$LONGRUN_REL/scripts/tests"
  mkdir -p "$FAKE_REPO/$LONGRUN_REL/sandbox/src"
  mkdir -p "$FAKE_REPO/$LONGRUN_REL/sandbox/tests"

  # Copy the production scripts so $REPO_ROOT resolves to the fake repo.
  cp "$HARNESS_DIR_REAL"/*.sh "$FAKE_REPO/$LONGRUN_REL/scripts/"

  # Provide a minimal evaluation.md skeleton with placeholders the scripts edit.
  cp "$LONGRUN_DIR_REAL/evaluation.md" "$FAKE_REPO/$LONGRUN_REL/evaluation.md" 2>/dev/null || \
    printf '# evaluation\n\n## Environment\n- Codex model: TBD\n\n## Results\n- Codex wall-clock: TBD\n- Opus wall-clock: TBD\n\n## TDD Fidelity\n- no-test-rate: TBD\n' > "$FAKE_REPO/$LONGRUN_REL/evaluation.md"

  # Seed sandbox with a representative file so tests can simulate diffs.
  printf 'export function greet(_n: string): string { throw new Error("x"); }\n' \
    > "$FAKE_REPO/$LONGRUN_REL/sandbox/src/greet.ts"

  git -C "$FAKE_REPO" init -q -b main
  git -C "$FAKE_REPO" config user.email "test@example.com"
  git -C "$FAKE_REPO" config user.name "Test"
  git -C "$FAKE_REPO" add -A
  git -C "$FAKE_REPO" commit -q -m "init"

  export FAKE_REPO
  export FAKE_LONGRUN="$FAKE_REPO/$LONGRUN_REL"
}
