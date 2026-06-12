#!/usr/bin/env bats
#
# Test for change-2 task 4.8 — backlog naming-refactor entry consumed.
# spec: legacy-command-removal S24 "命名規則リファクタが backlog から消化される".

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  BACKLOG="${PLUGIN_ROOT}/openspec/backlog.md"
}

@test "backlog: exists" {
  [ -f "$BACKLOG" ]
}

@test "backlog: orchestrator naming-refactor row is removed from the active table" {
  # The active rename target table must no longer list a longrun-orchestrator rename row.
  ! grep -Eq '^\| `longrun-orchestrator` \| `longrun-orchestration`' "$BACKLOG"
}

@test "backlog: records that orchestrator was consumed by change-2" {
  grep -Eq 'change-2.*消化|消化済み.*orchestrator|orchestrator.*消化' "$BACKLOG"
}
