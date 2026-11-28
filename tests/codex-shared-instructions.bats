#!/usr/bin/env bats
# scripts/codex-shared-instructions.py and scripts/sync.sh regression tests.
setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}
@test "codex shared generation and stale artifact detection" {
  python3 -B "$ROOT/tests/test_codex_shared_instructions.py" Shared.test_generation
}
@test "codex explicit sync preserves home bytes and settings" {
  python3 -B "$ROOT/tests/test_codex_shared_instructions.py" Shared.test_sync
}
@test "codex account table rejects invalid input" {
  python3 -B "$ROOT/tests/test_codex_shared_instructions.py" Shared.test_accounts
}
@test "codex unsafe homes fail without overwriting" {
  python3 -B "$ROOT/tests/test_codex_shared_instructions.py" Shared.test_unsafe
}
@test "codex overlays follow permission and revocation" {
  python3 -B "$ROOT/tests/test_codex_shared_instructions.py" Shared.test_overlays
}
@test "codex UTF8 capacity fixed fixture and local discovery" {
  python3 -B "$ROOT/tests/test_codex_shared_instructions.py" Shared.test_capacity
}
