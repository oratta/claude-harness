# Text checks concatenate the logical procedure after a move (#1687).
# Input: gate .md and related develop procedures. Catch strings missing globally.
# Unreachable text or an opposite instruction beside the required text can pass;
# links/conditions have separate tests, sizes have budgets, meaning needs review.
# Closing every semantic hole is not a completion condition.
gate_test_docs() {
  local helper
  helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-docs.py"
  python3 -B "$helper" "$PLUGIN_DIR" "$BATS_TEST_TMPDIR" > /dev/null
  ALL_GATE_DOCS="$BATS_TEST_TMPDIR/gate-docs/ALL.md"
  for name in GATE DECLARATIONS PREPARE TRIAGE PASS_STAGE HOLD; do
    if [ -n "${!name:-}" ]; then
      printf -v "$name" '%s' "$BATS_TEST_TMPDIR/gate-docs/$name.md"
    fi
  done
}
