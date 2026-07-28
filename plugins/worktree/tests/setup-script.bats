#!/usr/bin/env bats
#
# Tests for change-4 (worktree-command-dedup) — wt-setup.sh integrity.
# spec: worktree-setup-script-integrity (S12, S13, S14) + version sync.
#
# Verifies:
#   - the find -path glob behaviour is documented with an intent comment
#   - the settings.local.json symlink rationale is documented
#   - `bash -n` syntax check passes
#   - plugin.json version is bumped to 2.2.0 and parses

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

# --- S12: find -path glob behaviour is documented ---

@test "script: wt-setup.sh documents the find -path glob behaviour" {
  # A comment near the .worktreeinclude copy loop must explain that patterns are
  # treated as single-level path globs matching repo-root files (not subdirs).
  grep -q 'find -path' "$WT_SETUP_SH"
  grep -Eq 'グロブ|直下|1 ?階層|サブディレクトリ' "$WT_SETUP_SH"
}

# --- S13: settings.local.json symlink rationale is documented ---

@test "script: wt-setup.sh documents the settings.local.json symlink rationale" {
  grep -q 'settings.local.json' "$WT_SETUP_SH"
  # A rationale comment (same machine / same user shared permissions) must exist.
  grep -Eq '権限|同一マシン|同一ユーザー|permission' "$WT_SETUP_SH"
}

# --- S14: script syntax check passes ---

@test "script: bash -n wt-setup.sh passes" {
  run bash -n "$WT_SETUP_SH"
  [ "$status" -eq 0 ]
}

# --- version sync (task 6.x): plugin.json version is bumped and JSON parses ---

@test "version: worktree plugin.json version is semver and not below the 2.2.1 baseline" {
  # 元は "2.2.1 と等しい" 固定アサーションだったが、plugin.json を上げるたびに落ちる
  # 陳腐化テストになっていた（実際 2.4.1 の時点で失敗したまま放置されていた）。
  # 意図は「バージョンが退行していないこと」なので、semver 形式 + baseline 以上に変更する。
  # baseline 2.2.1 = loops-integration (change-5) の自己検証節追加時点。decisions.md D-5b。
  v="$(jq -r '.version' "$PLUGIN_JSON")"
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  run bash -c "printf '%s\n%s\n' '2.2.1' '$v' | sort -V | head -1"
  [ "$output" = "2.2.1" ]
}

@test "version: worktree plugin.json parses (jq)" {
  jq empty "$PLUGIN_JSON"
}
