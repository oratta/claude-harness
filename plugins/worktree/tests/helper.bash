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
  export PLUGIN_DIR PLUGIN_ROOT WT_CLEAN_CMD WT_SETUP_CMD \
    WT_CLEAN_SKILL WT_SETUP_SKILL WT_SETUP_SH WT_CREATE_HOOK_SH \
    WT_SETUP_GUARD_SH HOOKS_JSON PLUGIN_JSON WT_CLEAN_VERIFICATION
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

# Extract only the YAML frontmatter (between the first two `---` lines).
wt_frontmatter() {
  awk 'NR==1 && $0=="---"{infm=1; next} infm && $0=="---"{exit} infm{print}' "$1"
}
