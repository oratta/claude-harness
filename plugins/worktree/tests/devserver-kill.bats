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

# --- zsh compatibility (issue #66) ---
#
# The Bash tool runs zsh on macOS, and this skill is executed by reading SKILL.md
# and running its snippets inline. `pid="${entry%%(*}"` was a zsh parse error
# (`bad pattern: (*`) that killed the whole shell *after* SIGTERM was sent and
# *before* the SIGKILL fallback and `git worktree remove` — i.e. the #39 guard
# died in exactly the situation it exists for.

@test "skill: kill_devserver_under never uses a pattern metachar as a field separator" {
  # `(` `)` `[` `]` `#` `~` inside ${var%%...} / ${var##...} are patterns in zsh.
  # Comment lines are stripped first: the fix deliberately quotes the broken form
  # in a warning comment, and that must not satisfy (or trip) this assertion.
  local snippet="${BATS_TEST_TMPDIR}/kill-sep.sh"
  awk '/^kill_devserver_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" \
    | grep -v '^[[:space:]]*#' >"$snippet"
  [ -s "$snippet" ]
  run grep -Eq '\$\{entry(%%|##)[^}]*[][()~]' "$snippet"
  [ "$status" -ne 0 ]
  grep -q 'killed+=("$pid|$comm")' "$snippet"
  grep -q 'pid="${entry%%|\*}"' "$snippet"
  grep -q 'comm="${entry##\*|}"' "$snippet"
}

@test "skill: kill_devserver_under declares comm once, not inside the loop" {
  # zsh prints `comm=<previous value>` on every re-declaration of an existing
  # local, injecting garbage lines into the stop report. bash stays silent.
  local snippet="${BATS_TEST_TMPDIR}/kill-local.sh"
  awk '/^kill_devserver_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >"$snippet"
  run grep -Eq '^[[:space:]]+local comm$' "$snippet"
  [ "$status" -ne 0 ]
  grep -q 'local killed=() skipped=() comm' "$snippet"
}

@test "skill: documents that the embedded snippets must also run under zsh" {
  grep -q 'zsh' "$WT_CLEAN_SKILL"
  grep -Eq 'bad pattern|zsh 前提|zsh も含む' "$WT_CLEAN_SKILL"
}

wt_run_kill_snippet() {
  # $1 = shell, $2 = work dir. Echoes the combined output of a run of
  # kill_devserver_under over a directory holding two live processes:
  # one ordinary (dies on SIGTERM) and one that ignores SIGTERM.
  local shell="$1" dir="$2"
  local snippet="${BATS_TEST_TMPDIR}/kill-run.sh" driver="${BATS_TEST_TMPDIR}/kill-driver.sh"
  # kill_devserver_under depends on abs_path (defined in Step -1).
  awk '/^abs_path\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >"$snippet"
  awk '/^kill_devserver_under\(\) \{/,/^}$/' "$WT_CLEAN_SKILL" >>"$snippet"
  mkdir -p "$dir"
  cat >"$driver" <<'DRIVER'
. "$1"
DIR="$2"
( cd "$DIR" && exec sleep 300 ) &
PID_NORMAL=$!
# perl, not a shell: shells are on kill_devserver_under's exclusion list.
( cd "$DIR" && exec perl -e '$SIG{TERM}="IGNORE"; sleep 300' ) &
PID_STUBBORN=$!
sleep 1
kill_devserver_under "$DIR"
echo "REACHED_END"
sleep 1
kill -0 "$PID_NORMAL"   2>/dev/null && echo "ALIVE_NORMAL"   || echo "DEAD_NORMAL"
kill -0 "$PID_STUBBORN" 2>/dev/null && echo "ALIVE_STUBBORN" || echo "DEAD_STUBBORN"
kill -KILL "$PID_NORMAL" "$PID_STUBBORN" 2>/dev/null
exit 0
DRIVER
  "$shell" "$driver" "$snippet" "$dir" 2>&1
}

@test "kill_devserver_under: runs to completion under zsh when processes are killed" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  command -v zsh  >/dev/null 2>&1 || skip "zsh unavailable"
  command -v perl >/dev/null 2>&1 || skip "perl unavailable"
  local out
  out="$(wt_run_kill_snippet zsh "${BATS_TEST_TMPDIR}/zsh-kill")"
  # 1. the function returned instead of aborting the shell (issue #66)
  [[ "$out" == *"REACHED_END"* ]]
  [[ "$out" != *"bad pattern"* ]]
  # 2. the SIGKILL fallback was reached for the SIGTERM-ignoring process
  [[ "$out" == *"SIGKILL で停止しました"* ]]
  # 3. both processes are actually gone
  [[ "$out" == *"DEAD_NORMAL"* ]]
  [[ "$out" == *"DEAD_STUBBORN"* ]]
  # 4. no stray `comm=...` line from a zsh local re-declaration
  run grep -Eq '^comm=' <<<"$out"
  [ "$status" -ne 0 ]
}

@test "kill_devserver_under: bash and zsh report the same PIDs and commands" {
  command -v lsof >/dev/null 2>&1 || skip "lsof unavailable"
  command -v zsh  >/dev/null 2>&1 || skip "zsh unavailable"
  command -v perl >/dev/null 2>&1 || skip "perl unavailable"
  local out_bash out_zsh norm_bash norm_zsh
  out_bash="$(wt_run_kill_snippet bash "${BATS_TEST_TMPDIR}/b-kill")"
  out_zsh="$(wt_run_kill_snippet zsh  "${BATS_TEST_TMPDIR}/z-kill")"
  # Keep only the 🔪 lines and blank out the PIDs (they differ per run).
  norm_bash="$(grep '🔪' <<<"$out_bash" | sed -E 's/[0-9]+//g')"
  norm_zsh="$(grep  '🔪' <<<"$out_zsh"  | sed -E 's/[0-9]+//g')"
  [ -n "$norm_bash" ]
  [ "$norm_bash" = "$norm_zsh" ]
}

# --- verification checklist ---

@test "reference: wt-clean-verification.md adds a process-residue check" {
  grep -q 'プロセス残留' "$WT_CLEAN_VERIFICATION"
}

@test "skill: self-verification section references the process-residue check" {
  awk '/## 自己検証/,0' "$WT_CLEAN_SKILL" | grep -q 'プロセス'
}
