# Text checks concatenate the logical procedure after a move (#1687).
# Input: gate .md and related develop procedures. Catch strings missing globally.
# Unreachable text or an opposite instruction beside the required text can pass;
# links/conditions have separate tests, sizes have budgets, meaning needs review.
# Closing every semantic hole is not a completion condition.
gate_test_docs() {
  local helper
  helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-docs.py"
  python3 -B "$helper" "$PLUGIN_DIR" "$BATS_TEST_TMPDIR" > /dev/null
  GATE_SCOPE_DOCS="$BATS_TEST_TMPDIR/gate-docs/GATE_SCOPE.md"
  # shellcheck disable=SC2034 # Consumed by gate_all in the caller tests sourcing this library.
  ALL_GATE_DOCS="$BATS_TEST_TMPDIR/gate-docs/ALL.md"
  # Replace a variable only when it names the original file the joined copy stands in for.
  # A variable pointing elsewhere (e.g. GATE at pr-review-gate/SKILL.md) keeps the real file.
  local name original
  for name in GATE DECLARATIONS PREPARE TRIAGE PASS_STAGE HOLD; do
    case "$name" in
      GATE) original="skills/develop/references/roles/gate-runner.md" ;;
      DECLARATIONS) original="skills/pr-review-gate/declarations.md" ;;
      PREPARE) original="skills/pr-review-gate/stages/prepare.md" ;;
      TRIAGE) original="skills/pr-review-gate/stages/triage.md" ;;
      PASS_STAGE) original="skills/pr-review-gate/stages/pass.md" ;;
      HOLD) original="skills/pr-review-gate/stages/hold.md" ;;
    esac
    if [ -n "${!name:-}" ] && [ "${!name}" -ef "$PLUGIN_DIR/$original" ]; then
      printf -v "$name" '%s' "$BATS_TEST_TMPDIR/gate-docs/$name.md"
    fi
  done
}

# Negative rules addressed specifically to G retain their original complete scope.
gate_scope() { cat "$GATE_SCOPE_DOCS"; }
