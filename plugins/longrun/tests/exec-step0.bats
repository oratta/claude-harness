#!/usr/bin/env bats
#
# Structural tests for the exec Step 0 preflight/degraded-mode branch that
# lives inside plugins/longrun/commands/exec.md (change-1: openspec-degradation).
#
# The interactive AskUserQuestion part cannot be unit-tested, so we validate
# the documented control plane: that exec.md instructs running preflight,
# and that each preflight result maps to the correct AskUserQuestion options
# and the .degraded-mode marker creation.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  EXEC_MD="${PLUGIN_DIR}/commands/exec.md"
}

@test "exec.md: declares Step 0 preflight section" {
  grep -Eq '^### Step 0' "$EXEC_MD"
}

@test "exec.md: runs openspec-preflight.sh" {
  grep -q 'openspec-preflight.sh' "$EXEC_MD"
}

@test "exec.md: documents all three preflight outputs OK/NO_CLI/NO_INIT" {
  grep -q 'NO_CLI' "$EXEC_MD"
  grep -q 'NO_INIT' "$EXEC_MD"
  grep -Eq '`OK`' "$EXEC_MD"
}

@test "exec.md: OK path still offers a degraded-mode opt-out choice" {
  # The preflight-OK branch must include 縮退 as a non-default option.
  grep -Eq 'OpenSpec 不要|opt-out|縮退モード（OpenSpec を使わない）' "$EXEC_MD"
}

@test "exec.md: NO_CLI offers degraded-or-abort, NO_INIT offers init/degraded/abort" {
  grep -Eq '縮退モードで実行' "$EXEC_MD"
  grep -Eq '中断' "$EXEC_MD"
  grep -Eq 'openspec init して通常' "$EXEC_MD"
}

@test "exec.md: creates .degraded-mode marker on degraded selection" {
  grep -Eq '\.degraded-mode' "$EXEC_MD"
  grep -Eq 'touch .*\.degraded-mode' "$EXEC_MD"
}

@test "exec.md: normal mode must NOT create the marker" {
  grep -Eq 'マーカーは作成しない|マーカー）は作成しない' "$EXEC_MD"
}

@test "exec.md: records preflight result to checkpoint.md" {
  grep -Eq 'checkpoint.md' "$EXEC_MD"
}

@test "exec.md: points to verification doc as the source of truth" {
  grep -q 'openspec-cli-verification.md' "$EXEC_MD"
}

@test "exec.md: forbids guessing CLI availability without running the command" {
  grep -Eq '推測判断してはならない|推測で' "$EXEC_MD"
}
