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

# --- issue #55: backup files, .vercel opt-in, production-value guard ---
#
# `.env.*` also matches backups such as `.env.local.bak-stripe-migration`, so a
# pre-rotation production secret got burned into every worktree (observed in
# Uranai). `.vercel/.env.production.local` distributes a whole production env.

# A main repo whose .worktreeinclude is the shipped default template, carrying
# a clean env file, two backups, a .vercel dir and two production-looking files.
# Echoes the worktree path; script output lands in $BATS_TEST_TMPDIR/out55.txt.
wt_run_setup_issue55() {
  local main wt jwt
  jwt="eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3MDAwMDAwMDB9.sig"
  main="$(wt_make_repo main55)"
  (
    cd "$main" || exit 1
    printf '.env*\n.vercel/\n' >.gitignore
    bash "$WT_SETUP_SH" --print-default-worktreeinclude >.worktreeinclude
    git add -A .gitignore .worktreeinclude
    git commit -qm "add default worktreeinclude"
    printf 'SECRET=dev-only\n' >.env.local
    printf 'STRIPE_SECRET_KEY=sk_live_ABCDEFGH12345678\n' >.env.local.bak-stripe-migration
    printf 'OLDER=1\n' >.env.local.old
    printf 'STRIPE_SECRET_KEY=sk_live_ZYXWVUTS87654321\n' >.env.stripe
    printf 'SUPA_KEY=%s\n' "$jwt" >.env.production
    mkdir -p .vercel
    printf 'PROD_DB=postgres://u:p@db.abcdefghijklmnopqrst.supabase.co:5432/postgres\n' \
      >.vercel/.env.production.local
    git worktree add -q -b wt55 "$main-wt" HEAD
  ) >/dev/null 2>&1
  wt="$main-wt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/out55.txt" 2>&1
  echo "$wt"
}

@test "script: a .bak backup matching the glob is not distributed" {
  local wt out
  wt="$(wt_run_setup_issue55)"
  out="$(cat "${BATS_TEST_TMPDIR}/out55.txt")"
  [[ "$out" == *"skipped (excluded): ./.env.local.bak-stripe-migration"* ]]
  [ ! -e "$wt/.env.local.bak-stripe-migration" ]
  # editor/backup residue with other suffixes is excluded too
  [[ "$out" == *"skipped (excluded): ./.env.local.old"* ]]
  [ ! -e "$wt/.env.local.old" ]
}

@test "script: a legitimate env file is still copied alongside the excluded backups" {
  local wt
  wt="$(wt_run_setup_issue55)"
  [ "$(cat "$wt/.env.local")" = "SECRET=dev-only" ]
  grep -q 'skipped (excluded)' "${BATS_TEST_TMPDIR}/out55.txt"
}

@test "script: .vercel is not distributed by the default .worktreeinclude" {
  local wt
  wt="$(wt_run_setup_issue55)"
  [ ! -e "$wt/.vercel/.env.production.local" ]
}

@test "script: the default .worktreeinclude has no active .vercel pattern" {
  run bash "$WT_SETUP_SH" --print-default-worktreeinclude
  [ "$status" -eq 0 ]
  # every line mentioning .vercel must be a comment (opt-in, not a default)
  run bash -c "bash '$WT_SETUP_SH' --print-default-worktreeinclude | grep -v '^#' | grep -c '\\.vercel' || true"
  [ "$output" = "0" ]
}

@test "script: the default .worktreeinclude documents the .vercel opt-in" {
  run bash "$WT_SETUP_SH" --print-default-worktreeinclude
  [[ "$output" == *".vercel"* ]]
  [[ "$output" == *"オプトイン"* ]]
}

@test "script: production-looking values raise a warning" {
  wt_run_setup_issue55 >/dev/null
  local out
  out="$(cat "${BATS_TEST_TMPDIR}/out55.txt")"
  [[ "$out" == *"WARNING: 本番値の疑い: ./.env.stripe"* ]]
  [[ "$out" == *"Stripe"* ]]
  # a service_role JWT is detected from its base64 payload, not just the var name
  [[ "$out" == *"WARNING: 本番値の疑い: ./.env.production"* ]]
  [[ "$out" == *"service_role"* ]]
}

@test "script: the warning does not print the detected secret value" {
  wt_run_setup_issue55 >/dev/null
  local out
  out="$(cat "${BATS_TEST_TMPDIR}/out55.txt")"
  [[ "$out" != *"sk_live_ZYXWVUTS87654321"* ]]
  [[ "$out" != *"eyJpc3MiOiJzdXBhYmFzZSI"* ]]
}

@test "script: a warned file is still copied (warn and continue)" {
  local wt
  wt="$(wt_run_setup_issue55)"
  [ -e "$wt/.env.stripe" ]
  [ -e "$wt/.env.production" ]
}

@test "script: the summary counts excluded files and warnings" {
  wt_run_setup_issue55 >/dev/null
  # 3 copied (.env.local/.env.stripe/.env.production), 2 excluded (.bak-*/.old),
  # 2 warnings (Stripe key + service_role JWT). The counters must survive the
  # nested read loops.
  grep -Eq 'total: 3 files copied, [0-9]+ skipped \(tracked\), 2 skipped \(excluded\), 2 warnings' \
    "${BATS_TEST_TMPDIR}/out55.txt"
  grep -q 'NOTE: 本番値の疑いがあるファイルもコピー済み' "${BATS_TEST_TMPDIR}/out55.txt"
}

@test "script: a repo-specific ! line excludes a file from distribution" {
  local main wt
  main="$(wt_make_repo main55x)"
  (
    cd "$main" || exit 1
    printf '.env*\n' >.gitignore
    printf '.env.*\n!.env.production\n' >.worktreeinclude
    git add -A .gitignore .worktreeinclude
    git commit -qm "add worktreeinclude with exclude"
    printf 'SECRET=dev\n' >.env.local
    printf 'PROD=1\n' >.env.production
    git worktree add -q -b wt55x "$main-wt" HEAD
  ) >/dev/null 2>&1
  wt="$main-wt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/out55x.txt" 2>&1
  [ -e "$wt/.env.local" ]
  [ ! -e "$wt/.env.production" ]
  grep -q 'skipped (excluded): ./.env.production' "${BATS_TEST_TMPDIR}/out55x.txt"
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

# --- flatmate#320: nested-worktree recursion / self-replication ---
#
# `find -path "./$pattern"` lets `*` match `/` too, so `*.local.json` recursed
# over the whole repo — including nested worktree debris under
# */.claude/worktrees/ and the worktree being created itself — timing out the
# WorktreeCreate hook and self-replicating copies. Patterns without `/` must
# match repo-root files only; patterns with `/` must prune nested worktrees
# and the destination worktree.

# Main repo with root-level env/local files, a subdir file no pattern reaches,
# a workspace file matched by a slash pattern, and nested worktree debris.
# The worktree is created at .claude/worktrees/wt320 like the real hook does.
wt_run_setup_issue320() {
  local main wt
  main="$(wt_make_repo main320)"
  (
    cd "$main" || exit 1
    printf '.env.*\n*.local.json\nworkspace/\n' >.gitignore
    printf '.env.*\n*.local.json\nworkspace/**/*.local.json\n' >.worktreeinclude
    git add -A .gitignore .worktreeinclude
    git commit -qm "add worktreeinclude"
    printf 'ROOT=1\n' >.env.local
    printf '{}\n' >app.local.json
    mkdir -p sub
    printf '{}\n' >sub/other.local.json
    mkdir -p workspace/gene
    printf '{}\n' >workspace/gene/data.local.json
    mkdir -p workspace/gene/.claude/worktrees/agent-old
    printf '{}\n' >workspace/gene/.claude/worktrees/agent-old/leftover.local.json
    git worktree add -q -b wt320 .claude/worktrees/wt320 HEAD
  ) >/dev/null 2>&1
  wt="$main/.claude/worktrees/wt320"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/out320.txt" 2>&1
  echo "$wt"
}

@test "script: repo-root files still copy with the default-style patterns" {
  local wt
  wt="$(wt_run_setup_issue320)"
  [ -e "$wt/.env.local" ]
  [ -e "$wt/app.local.json" ]
  grep -q 'copied: ./.env.local' "${BATS_TEST_TMPDIR}/out320.txt"
}

@test "script: a slash-less pattern no longer recurses into subdirectories" {
  local wt
  wt="$(wt_run_setup_issue320)"
  [ ! -e "$wt/sub/other.local.json" ]
}

@test "script: nested worktree debris under */.claude/worktrees is never copied" {
  local wt
  wt="$(wt_run_setup_issue320)"
  # the slash pattern still reaches legitimate workspace files...
  [ -e "$wt/workspace/gene/data.local.json" ]
  # ...but prunes nested worktrees at any depth
  [ ! -e "$wt/workspace/gene/.claude/worktrees" ]
}

@test "script: the created worktree does not contain a copy of itself" {
  local wt
  wt="$(wt_run_setup_issue320)"
  [ ! -e "$wt/.claude/worktrees" ]
}

@test "script: the destination worktree is pruned even outside .claude/worktrees" {
  local main wt
  main="$(wt_make_repo main320s)"
  (
    cd "$main" || exit 1
    printf '*.local.json\ninner-wt/\n' >.gitignore
    printf '**/*.local.json\n' >.worktreeinclude
    git add -A .gitignore .worktreeinclude
    git commit -qm "add worktreeinclude"
    mkdir -p sub
    printf '{}\n' >sub/deep.local.json
    git worktree add -q -b wt320s inner-wt HEAD
    # pre-seed a matching file inside the destination worktree: without the
    # self-prune this would be re-copied into $wt/inner-wt/ (self-replication)
    printf '{}\n' >inner-wt/seed.local.json
  ) >/dev/null 2>&1
  wt="$main/inner-wt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/out320s.txt" 2>&1
  [ -e "$wt/sub/deep.local.json" ]
  [ ! -e "$wt/inner-wt" ]
}

@test "script: a sibling worktree inside the main repo is pruned too" {
  local main wt
  main="$(wt_make_repo main320sib)"
  (
    cd "$main" || exit 1
    printf '*.local.json\ndest-wt/\nsibling-wt/\n' >.gitignore
    printf '**/*.local.json\n' >.worktreeinclude
    git add -A .gitignore .worktreeinclude
    git commit -qm "add worktreeinclude"
    mkdir -p sub
    printf '{}\n' >sub/deep.local.json
    git worktree add -q -b wt320sib-a sibling-wt HEAD
    git worktree add -q -b wt320sib-b dest-wt HEAD
    # a gitignored match living inside the *sibling* worktree: pruning only
    # `.git` lets find descend into it and replicate another worktree's files
    printf '{}\n' >sibling-wt/leaked.local.json
  ) >/dev/null 2>&1
  wt="$main/dest-wt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/out320sib.txt" 2>&1
  # legitimate main-repo matches still copy
  [ -e "$wt/sub/deep.local.json" ]
  # neither the sibling worktree nor the destination itself is reproduced
  [ ! -e "$wt/sibling-wt" ]
  [ ! -e "$wt/dest-wt" ]
}

# --- kg-recruit#126: a tracked .githooks/ becomes the repo-local hooks path ---
#
# git runs hooks from the single directory core.hooksPath resolves to. With a
# global core.hooksPath (push-guard-setup), a repo's tracked .githooks/pre-push
# never runs in a clone that lacks `core.hooksPath .githooks` in its local
# config. wt-setup.sh sets it once per clone (worktrees share the clone config),
# never overwrites an existing local value, and ignores untracked .githooks/.

# Isolate the tests from this PC's global/system git config (a real global
# core.hooksPath would change the scope wt-setup.sh sees). $1 (optional) = a
# global core.hooksPath value to put in the isolated global config.
wt_isolate_git_config() {
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="${BATS_TEST_TMPDIR}/gitconfig-global"
  : >"$GIT_CONFIG_GLOBAL"
  if [ -n "${1:-}" ]; then
    git config --global core.hooksPath "$1"
  fi
}

# $1 = repo name, $2 = "tracked" | "untracked" | "none". Echoes the worktree path.
wt_make_hooks_repo() {
  local main
  main="$(wt_make_repo "$1")"
  (
    cd "$main" || exit 1
    printf 'wt/\n' >.gitignore
    git add .gitignore
    if [ "$2" = "tracked" ]; then
      mkdir -p .githooks
      printf '#!/bin/sh\nexit 0\n' >.githooks/pre-push
      git add .githooks/pre-push
    fi
    git commit -qm "setup"
    git worktree add -q -b "wt-$1" wt HEAD
    if [ "$2" = "untracked" ]; then
      mkdir -p wt/.githooks
      printf '#!/bin/sh\nexit 0\n' >wt/.githooks/pre-push
    fi
  ) >/dev/null 2>&1
  echo "$main/wt"
}

@test "githooks: a tracked .githooks is enabled and visible from the main checkout" {
  local wt main out
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-set tracked)"
  main="$(dirname "$wt")"
  out="${BATS_TEST_TMPDIR}/hk-set.txt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"$out" 2>&1
  [ "$(git -C "$wt" config --local --get core.hooksPath)" = ".githooks" ]
  [ "$(git -C "$main" config --local --get core.hooksPath)" = ".githooks" ]
  grep -q '^=== git フック: core.hooksPath を .githooks に設定' "$out"
  # no global value: the hooks that stop running are the clone's .git/hooks/
  grep -q 'これまで実行されていたフック（.git/hooks/）' "$out"
  ! grep -q '~/.githooks' "$out"
}

@test "githooks: with a global core.hooksPath, the notice names that value and push-guard-setup" {
  local wt out
  wt_isolate_git_config "${BATS_TEST_TMPDIR}/global-hooks-dir"
  wt="$(wt_make_hooks_repo hk-global tracked)"
  out="${BATS_TEST_TMPDIR}/hk-global.txt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"$out" 2>&1
  [ "$(git -C "$wt" config --local --get core.hooksPath)" = ".githooks" ]
  grep -q '^=== git フック: core.hooksPath を .githooks に設定' "$out"
  grep -qF "これまで実行されていたフック（${BATS_TEST_TMPDIR}/global-hooks-dir）" "$out"
  grep -q 'push-guard-setup' "$out"
  ! grep -q '~/.githooks' "$out"
}

@test "githooks: a value in config.worktree (extensions.worktreeConfig) is left as is" {
  local wt main out
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-wtcfg tracked)"
  main="$(dirname "$wt")"
  git -C "$main" config extensions.worktreeConfig true
  git -C "$wt" config --worktree core.hooksPath wt-own-hooks
  out="${BATS_TEST_TMPDIR}/hk-wtcfg.txt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"$out" 2>&1
  # nothing written to the clone's shared config, the worktree value still wins
  run git -C "$main" config --local --get core.hooksPath
  [ "$status" -eq 1 ]
  [ "$(git -C "$wt" config --get core.hooksPath)" = "wt-own-hooks" ]
  ! grep -q 'git フック' "$out"
}

@test "githooks: a local value reached through include.path is left as is" {
  local wt main out
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-include tracked)"
  main="$(dirname "$wt")"
  printf '[core]\n\thooksPath = included-hooks\n' >"${BATS_TEST_TMPDIR}/included.conf"
  git -C "$main" config --local include.path "${BATS_TEST_TMPDIR}/included.conf"
  out="${BATS_TEST_TMPDIR}/hk-include.txt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"$out" 2>&1
  [ -z "$(git -C "$main" config --local --no-includes --get-all core.hooksPath)" ]
  [ "$(git -C "$wt" config --get core.hooksPath)" = "included-hooks" ]
  ! grep -q 'git フック' "$out"
}

@test "githooks: existing non-sample hooks in .git/hooks/ block the switch with one notice line" {
  local wt main out
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-direct tracked)"
  main="$(dirname "$wt")"
  mkdir -p "$main/.git/hooks"
  printf '#!/bin/sh\ngit lfs pre-push "$@"\n' >"$main/.git/hooks/pre-push"
  chmod +x "$main/.git/hooks/pre-push"
  out="${BATS_TEST_TMPDIR}/hk-direct.txt"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"$out" 2>&1
  run git -C "$main" config --local --get core.hooksPath
  [ "$status" -eq 1 ]
  [ "$(grep -c '^=== git フック:' "$out")" -eq 1 ]
  grep -q '^=== git フック: .githooks を追跡しているが .git/hooks/ に既存のフックがあるため自動では有効化しなかった' "$out"
}

@test "githooks: only .sample files in .git/hooks/ do not block the switch" {
  local wt main
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-sample tracked)"
  main="$(dirname "$wt")"
  mkdir -p "$main/.git/hooks"
  : >"$main/.git/hooks/pre-push.sample"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >/dev/null 2>&1
  [ "$(git -C "$main" config --local --get core.hooksPath)" = ".githooks" ]
}

# A git stub on PATH that delegates to the real git, except for the call named
# by $1: "write" fails `config --local core.hooksPath .githooks`, "read" makes
# `config --show-scope --get core.hooksPath` exit 128.
wt_git_stub() {
  local real stubdir
  real="$(command -v git)"
  stubdir="${BATS_TEST_TMPDIR}/gitstub"
  mkdir -p "$stubdir"
  cat >"$stubdir/git" <<STUB
#!/bin/bash
case "\$*" in
  *"config --local core.hooksPath .githooks"*) [ "$1" = write ] && exit 255 ;;
  *"config --show-scope --get core.hooksPath"*) [ "$1" = read ] && exit 128 ;;
esac
exec "$real" "\$@"
STUB
  chmod +x "$stubdir/git"
  echo "$stubdir"
}

@test "githooks: a failed write prints one WARNING line and the rest of wt-setup.sh still runs" {
  local wt main out stubdir
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-wfail tracked)"
  main="$(dirname "$wt")"
  stubdir="$(wt_git_stub write)"
  out="${BATS_TEST_TMPDIR}/hk-wfail.txt"
  ( cd "$wt" && PATH="$stubdir:$PATH" bash "$WT_SETUP_SH" ) >"$out" 2>&1
  [ "$(grep -c 'WARNING: git config --local core.hooksPath .githooks に失敗' "$out")" -eq 1 ]
  ! grep -q '^=== git フック:' "$out"
  grep -q '=== 依存状況 ===' "$out"
  run git -C "$main" config --local --get core.hooksPath
  [ "$status" -eq 1 ]
}

@test "githooks: a read that exits other than 0/1 leaves the config untouched" {
  local wt main out stubdir
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-rfail tracked)"
  main="$(dirname "$wt")"
  stubdir="$(wt_git_stub read)"
  out="${BATS_TEST_TMPDIR}/hk-rfail.txt"
  ( cd "$wt" && PATH="$stubdir:$PATH" bash "$WT_SETUP_SH" ) >"$out" 2>&1
  run git -C "$main" config --local --get core.hooksPath
  [ "$status" -eq 1 ]
  ! grep -q 'git フック' "$out"
  ! grep -q 'WARNING: git config --local core.hooksPath' "$out"
  grep -q '=== 依存状況 ===' "$out"
}

@test "githooks: an existing .githooks value is left as is without output" {
  local wt
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-same tracked)"
  git -C "$wt" config --local core.hooksPath .githooks
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/hk-same.txt" 2>&1
  [ "$(git -C "$wt" config --local --get core.hooksPath)" = ".githooks" ]
  ! grep -q 'core.hooksPath' "${BATS_TEST_TMPDIR}/hk-same.txt"
}

@test "githooks: a different local value is never overwritten" {
  local wt
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-other tracked)"
  git -C "$wt" config --local core.hooksPath .husky/_
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/hk-other.txt" 2>&1
  [ "$(git -C "$wt" config --local --get core.hooksPath)" = ".husky/_" ]
  ! grep -q 'core.hooksPath' "${BATS_TEST_TMPDIR}/hk-other.txt"
}

@test "githooks: a repo without .githooks is left untouched" {
  local wt
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-none none)"
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/hk-none.txt" 2>&1
  run git -C "$wt" config --local --get core.hooksPath
  [ "$status" -eq 1 ]
  ! grep -q 'core.hooksPath' "${BATS_TEST_TMPDIR}/hk-none.txt"
}

@test "githooks: an untracked .githooks alone is not enabled" {
  local wt
  wt_isolate_git_config
  wt="$(wt_make_hooks_repo hk-untracked untracked)"
  [ -f "$wt/.githooks/pre-push" ]
  ( cd "$wt" && bash "$WT_SETUP_SH" ) >"${BATS_TEST_TMPDIR}/hk-untracked.txt" 2>&1
  run git -C "$wt" config --local --get core.hooksPath
  [ "$status" -eq 1 ]
  ! grep -q 'core.hooksPath' "${BATS_TEST_TMPDIR}/hk-untracked.txt"
}
