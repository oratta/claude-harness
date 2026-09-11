#!/usr/bin/env bash
#
# Shared bats helper for plugins/worktree/tests/*.bats
#
# Introduced by change-4 (worktree-command-dedup) as the first test directory
# for the worktree plugin.
#
# Conventions:
#   - PLUGIN_DIR  : absolute path to plugins/worktree
#   - PLUGIN_ROOT : repository root (git toplevel)
#
# Negative assertions use `run <cmd>; [ "$status" -ne 0 ]` form rather than
# bare `! <cmd>` because macOS /bin/bash 3.2 does not propagate the failure of a
# second bare-negated command under errexit (see _longruns decisions.md
# D-change3-3).
#
# Usage:
#   load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"
#   setup() { wt_setup_paths; }

wt_setup_paths() {
  PLUGIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  WT_CLEAN_CMD="${PLUGIN_DIR}/commands/wt-clean.md"
  WT_SETUP_CMD="${PLUGIN_DIR}/commands/wt-setup.md"
  WT_CLEAN_SKILL="${PLUGIN_DIR}/skills/wt-clean/SKILL.md"
  WT_SETUP_SKILL="${PLUGIN_DIR}/skills/wt-setup/SKILL.md"
  WT_SETUP_SH="${PLUGIN_DIR}/scripts/wt-setup.sh"
  WT_CREATE_HOOK_SH="${PLUGIN_DIR}/scripts/wt-create-hook.sh"
  WT_SETUP_GUARD_SH="${PLUGIN_DIR}/scripts/wt-setup-guard.sh"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  WT_CLEAN_VERIFICATION="${PLUGIN_DIR}/references/wt-clean-verification.md"
  WT_CLEAN_ORPHAN_REF="${PLUGIN_DIR}/references/wt-clean-orphan-detection.md"
  export PLUGIN_DIR PLUGIN_ROOT WT_CLEAN_CMD WT_SETUP_CMD \
    WT_CLEAN_SKILL WT_SETUP_SKILL WT_SETUP_SH WT_CREATE_HOOK_SH \
    WT_SETUP_GUARD_SH HOOKS_JSON PLUGIN_JSON WT_CLEAN_VERIFICATION \
    WT_CLEAN_ORPHAN_REF
}

# Create a throwaway git repo under BATS_TEST_TMPDIR and echo its path.
# $1 (optional): extra setup, evaluated inside the repo.
wt_make_repo() {
  local repo="${BATS_TEST_TMPDIR}/${1:-repo}"
  mkdir -p "$repo"
  (
    cd "$repo" || exit 1
    git init -q
    git config user.email test@example.com
    git config user.name test
    echo hi >README.md
    git add -A
    git commit -qm init
  ) >/dev/null 2>&1
  echo "$repo"
}

# --- 背景プロセスを起動するテストの約束事（issue #215） ---
#
# bats は TAP 出力パイプを fd 3 に複製し（bats-exec-test の `exec 3<&1`）、さらに
# 別番号の fd にも同じパイプが残る（macOS の bats 1.13.0 では fd 12）。テストから
# 起動した背景プロセスがこれを握ったまま生き残ると、bats の formatter がパイプの
# EOF を待ち続け、全件実行が「TAP は最後まで出るのに終了しない」形で止まる。
# `3>&-` だけでは足りない（fd 12 が残る）ので、背景プロセスは必ず
# wt_close_inherited_fds を通して 3 以上の fd を全部閉じてから exec する。
#
#   ( cd "$dir" && wt_close_inherited_fds && exec sleep 30 ) &
#   pid=$!; wt_track_pid "$pid"
#
# 起動した PID は wt_track_pid でファイルに残し、各スイートの teardown で
# wt_kill_tracked_pids が回収する（$( ) の中で起動すると変数では親に戻らない）。

# 現在のシェルが継承している fd のうち 3 以上を全部閉じる（subshell の中で使う）。
wt_close_inherited_fds() {
  local f
  for f in /dev/fd/*; do
    f=${f##*/}
    [ "$f" -gt 2 ] 2>/dev/null || continue
    eval "exec $f>&-" 2>/dev/null || true
  done
  return 0
}

# teardown で回収する PID を記録する（$( ) の中からでも親に届く）。
wt_track_pid() {
  echo "$1" >>"${BATS_TEST_TMPDIR}/wt-spawned.pids"
}

# wt_track_pid で記録した PID を全部 SIGKILL する。各スイートの teardown から呼ぶ。
wt_kill_tracked_pids() {
  local f="${BATS_TEST_TMPDIR}/wt-spawned.pids" p
  [ -s "$f" ] || return 0
  while read -r p; do
    [ -n "$p" ] && kill -9 "$p" 2>/dev/null || true
  done <"$f"
  return 0
}

# Extract only the YAML frontmatter (between the first two `---` lines).
wt_frontmatter() {
  awk 'NR==1 && $0=="---"{infm=1; next} infm && $0=="---"{exit} infm{print}' "$1"
}
