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

# --- issue #80: only gitignored files may be copied ---
#
# `.worktreeinclude` promises "gitignored files worth copying into the worktree",
# but its globs (`.env.*` by default) also match *tracked* files such as
# `.env.local.example`. When the main repo's checkout is stale, that stale copy
# overwrote the worktree's tracked file and produced a diff nobody made.

@test "script: wt-setup.sh checks gitignore status before copying" {
  grep -q 'check-ignore' "$WT_SETUP_SH"
  grep -q 'skipped (tracked)' "$WT_SETUP_SH"
}

# Build a main repo + worktree where the .worktreeinclude glob matches both a
# tracked file and an ignored one, then run the real script inside the worktree.
# Echoes the worktree path; the script output lands in $BATS_TEST_TMPDIR/out.txt.
wt_run_setup_with_include() {
  local main wt
  main="$(wt_make_repo main80)"
  (
    cd "$main" || exit 1
    printf '.env.local\n' >.gitignore
    printf 'PUBLIC=committed\n' >.env.local.example   # tracked, matches .env.*
    printf 'SECRET=s3cret\n' >.env.local              # ignored, matches .env.*
    printf '.env.*\n' >.worktreeinclude
    git add -A .gitignore .env.local.example .worktreeinclude
    git commit -qm "add env example"
    # Simulate a stale main checkout: the working copy loses a line that the
    # worktree's committed version still has.
    printf 'PUBLIC=stale\n' >.env.local.example
    git worktree add -q -b wt80 "$main-wt" HEAD
  ) >/dev/null 2>&1
  wt="$main-wt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/out.txt" 2>&1
  echo "$wt"
}

@test "script: a tracked file matching the glob is skipped, not copied" {
  local wt out
  wt="$(wt_run_setup_with_include)"
  out="$(cat "${BATS_TEST_TMPDIR}/out.txt")"
  [[ "$out" == *"skipped (tracked): ./.env.local.example"* ]]
  # the worktree's tracked file still holds the committed content
  [ "$(cat "$wt/.env.local.example")" = "PUBLIC=committed" ]
}

@test "script: a gitignored file matching the same glob is still copied" {
  local wt out
  wt="$(wt_run_setup_with_include)"
  out="$(cat "${BATS_TEST_TMPDIR}/out.txt")"
  [[ "$out" == *"copied: ./.env.local"* ]]
  [ "$(cat "$wt/.env.local")" = "SECRET=s3cret" ]
}

@test "script: the copy summary reports both copied and skipped counts" {
  wt_run_setup_with_include >/dev/null
  grep -q 'total: 1 files copied, 1 skipped (tracked)' "${BATS_TEST_TMPDIR}/out.txt"
}

@test "script: skipping a tracked file leaves the worktree git-clean" {
  # The whole point of #80: no phantom diff appears just from running wt-setup.
  local wt
  wt="$(wt_run_setup_with_include)"
  run git -C "$wt" status --porcelain -- .env.local.example
  [ "$status" -eq 0 ]
  [ -z "$output" ]
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
