#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "gate reading: file plans and real generated prompts stay inside byte budgets" {
  python3 -B "$ROOT/tests/gate_reading_budget.py" check "$ROOT"
}

@test "gate reading: boundaries, malformed plans, missing sources and prompt corruption fail closed" {
  python3 -B "$ROOT/tests/gate_reading_budget.py" fixtures "$ROOT"
}
