#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_DIR="$REPO_ROOT/plugins/dev-workflow"
  CHECK="$REPO_ROOT/tests/develop_startup_contract.py"
  BUDGET="$REPO_ROOT/tests/develop-orchestrator-reference-budget.txt"
}

fixture() {
  ROOT="$BATS_TEST_TMPDIR/plugin"
  mkdir -p "$ROOT/skills/develop" "$ROOT/commands" "$ROOT/references"
  cp -R "$PLUGIN_DIR/skills/develop/." "$ROOT/skills/develop/"
  cp "$PLUGIN_DIR/commands/develop.md" "$ROOT/commands/"
  cp "$PLUGIN_DIR/references/codex-develop.md" "$ROOT/references/"
}

@test "real: orchestrator references have tight per-file budgets" {
  run python3 -B "$CHECK" "$PLUGIN_DIR" budget "$BUDGET"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "real: rules exist across the develop procedures" {
  run python3 -B "$CHECK" "$PLUGIN_DIR" content
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "real: mandatory entries skeleton status routes and resolver ownership" {
  run python3 -B "$CHECK" "$PLUGIN_DIR" structure
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "regress: moving a procedure passes but removing it fails" {
  fixture
  mv "$ROOT/skills/develop/references/worker-recovery.md" "$ROOT/skills/develop/references/moved.md"
  run python3 -B "$CHECK" "$ROOT" content
  [ "$status" -eq 0 ]
  # Empty the procedure in the disposable tree, without touching the repository.
  : > "$ROOT/skills/develop/references/moved.md"
  run python3 -B "$CHECK" "$ROOT" content
  [ "$status" -ne 0 ]
}

@test "regress: missing normal-return mandatory entry fails" {
  fixture
  sed '/通常 return.*worker-recovery.md/d' "$ROOT/skills/develop/SKILL.md" > "$ROOT/skill.tmp"
  mv "$ROOT/skill.tmp" "$ROOT/skills/develop/SKILL.md"
  run python3 -B "$CHECK" "$ROOT" structure
  [ "$status" -ne 0 ]
}

@test "regress: skeleton pushed beyond first 5000 bytes fails" {
  fixture
  { head -c 5001 /dev/zero | tr '\0' x; cat "$ROOT/skills/develop/SKILL.md"; } > "$ROOT/skill.tmp"
  mv "$ROOT/skill.tmp" "$ROOT/skills/develop/SKILL.md"
  run python3 -B "$CHECK" "$ROOT" structure
  [ "$status" -ne 0 ]
}

@test "regress: each reference rejects over budget and excessive slack" {
  fixture
  local path cap
  while read -r path cap; do
    cp "$ROOT/$path" "$ROOT/original"
    head -c $((cap + 1)) /dev/zero > "$ROOT/$path"
    run python3 -B "$CHECK" "$ROOT" budget "$BUDGET"
    [ "$status" -ne 0 ]
    head -c $((cap * 10 / 11 - 1)) /dev/zero > "$ROOT/$path"
    run python3 -B "$CHECK" "$ROOT" budget "$BUDGET"
    [ "$status" -ne 0 ]
    mv "$ROOT/original" "$ROOT/$path"
  done < "$BUDGET"
}

@test "regress: equal-size swaps may pass content entry and budget checks" {
  fixture
  # Different scenes, equal UTF-8 character and byte counts; accepted residual.
  python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path
r = Path(sys.argv[1]) / 'skills/develop/references'
a, b = r / 'pr-token-budget.md', r / 'worker-recovery.md'
for p, paragraph in [(a, '\n場面甲\n'), (b, '\n場面乙\n')]:
    p.write_text(p.read_text() + paragraph)
before = [(len(p.read_text()), len(p.read_bytes())) for p in [a, b]]
a.write_text(a.read_text().replace('場面甲', '場面乙'))
b.write_text(b.read_text().replace('場面乙', '場面甲'))
assert before == [(len(p.read_text()), len(p.read_bytes())) for p in [a, b]]
budget = Path(sys.argv[1]) / 'budget.txt'
budget.write_text(''.join(f'{p.relative_to(Path(sys.argv[1]))} {p.stat().st_size}\n' for p in sorted(r.glob('*.md')) if p.name in ['pr-token-budget.md', 'worker-recovery.md', 'gate-result.md']))
PY
  run python3 -B "$CHECK" "$ROOT" content
  [ "$status" -eq 0 ]
  run python3 -B "$CHECK" "$ROOT" structure
  [ "$status" -eq 0 ]
  run python3 -B "$CHECK" "$ROOT" budget "$ROOT/budget.txt"
  [ "$status" -eq 0 ]
}
