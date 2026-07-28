#!/usr/bin/env bats
#
# Tests for change wt-clean-devserver-kill.
# spec: wt-clean-devserver-cleanup.
#
# Guards that `git worktree remove` is never called without first stopping
# any dev-server process left running under the worktree path (issue #39:
# a `next dev` process tree survived 2+ days after `wt-clean` removed its
# worktree, causing a rebuild loop that exhausted CPU/RAM).

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

# --- detection ---

@test "skill: wt-clean SKILL.md defines the kill_devserver_under helper" {
  grep -q 'kill_devserver_under' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md detects processes via lsof +D" {
  grep -q 'lsof +D' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md falls back to pgrep -f when lsof is unavailable" {
  grep -q 'pgrep -f' "$WT_CLEAN_SKILL"
  grep -q 'command -v lsof' "$WT_CLEAN_SKILL"
}

# --- signal escalation ---

@test "skill: wt-clean SKILL.md sends SIGTERM before SIGKILL" {
  grep -q 'kill -TERM' "$WT_CLEAN_SKILL"
  grep -q 'kill -KILL' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md re-checks liveness before escalating to SIGKILL" {
  grep -q 'kill -0' "$WT_CLEAN_SKILL"
}

# --- silent-kill prohibition ---

@test "skill: wt-clean SKILL.md logs stopped PIDs (no silent kill)" {
  grep -q '🔪' "$WT_CLEAN_SKILL"
}

@test "skill: wt-clean SKILL.md logs when no process is found" {
  grep -q 'プロセス残留チェック' "$WT_CLEAN_SKILL"
}

# --- scope guard: don't kill shells/editors or other worktrees ---

@test "skill: wt-clean SKILL.md excludes interactive shells/editors from kill" {
  grep -q 'bash|zsh|sh|fish' "$WT_CLEAN_SKILL"
  grep -q 'シェル/エディタと判定してスキップ' "$WT_CLEAN_SKILL"
}

# --- applied at every git worktree remove call site ---

@test "skill: kill_devserver_under is called at least once per git worktree remove site" {
  local removes calls
  removes=$(grep -c 'git worktree remove' "$WT_CLEAN_SKILL")
  calls=$(grep -c 'kill_devserver_under "\$WT"' "$WT_CLEAN_SKILL")
  # 1 definition site + 1 call per removal call site (5 removal call sites)
  [ "$calls" -ge 5 ]
  [ "$removes" -ge 5 ]
}

@test "skill: 🔴 forced-remove section documents the process-stop step" {
  awk '/## 🔴 Active worktree の強制破棄/,0' "$WT_CLEAN_SKILL" | grep -q 'kill_devserver_under\|プロセス'
}

# --- verification checklist ---

@test "reference: wt-clean-verification.md adds a process-residue check" {
  grep -q 'プロセス残留' "$WT_CLEAN_VERIFICATION"
}

@test "skill: self-verification section references the process-residue check" {
  awk '/## 自己検証/,0' "$WT_CLEAN_SKILL" | grep -q 'プロセス'
}
