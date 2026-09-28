#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "worker and gate-runner have exact restricted frontmatter" {
  for role in worker gate-runner; do
    file="$ROOT/agents/$role.md"
    [ -f "$file" ]
    grep -qx "name: $role" "$file"
    grep -qx 'model: sonnet' "$file"
    [ "$(grep '^tools:' "$file")" = "$( [ "$role" = worker ] && echo 'tools: Read, Edit, Write, Bash, Grep, Glob, TaskStop' || echo 'tools: Read, Bash, Grep, Glob, TaskStop' )" ]
    ! grep -q '^model: inherit$' "$file" || return 1
    if grep '^tools:' "$file" | grep -qE 'mcp__|WebFetch|WebSearch|Skill|Agent|NotebookEdit'; then return 1; fi
    grep -q "skills/develop/references/roles/$role.md" "$file"
  done
  if grep '^tools:' "$ROOT/agents/gate-runner.md" | grep -qE 'Edit|Write'; then return 1; fi
}

@test "plugin manifest registers all three role types" {
  run python3 - "$ROOT/.claude-plugin/plugin.json" <<'PY'
import json, sys
agents = json.load(open(sys.argv[1]))['agents']
assert agents == ['./agents/decider.md', './agents/worker.md', './agents/gate-runner.md']
PY
  [ "$status" -eq 0 ]
}
