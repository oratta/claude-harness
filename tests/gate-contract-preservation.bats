#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "gate contracts: every original fenced command, declaration and return survives verbatim" {
  python3 -B "$ROOT/tests/gate_contracts.py" contracts "$ROOT"
}

@test "gate contracts: conditional details remain reachable from their stage" {
  python3 -B "$ROOT/tests/gate_contracts.py" links "$ROOT"
}

@test "gate wording: relocation passes, global deletion fails, unreachable and contradictory prose are outside scope" {
  python3 -B "$ROOT/tests/gate_contracts.py" fixtures "$ROOT"
}
