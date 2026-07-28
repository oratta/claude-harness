#!/usr/bin/env bats
#
# Tests for the worktree auto-setup hooks.
#
#   WorktreeCreate -> scripts/wt-create-hook.sh   (worktree 作成を置き換え、wt-setup まで済ませる)
#   SessionStart   -> scripts/wt-setup-guard.sh   (手動作成 worktree の取りこぼしを初回だけ拾う)
#
# 最重要の不変条件:
#   - wt-create-hook は stdout に worktree の絶対パスだけを出す（他の出力は stderr へ）
#   - wt-setup-guard は「未セットアップ worktree の初回」以外では完全に無出力
#   - どちらも異常時にセッション/worktree 作成を巻き添えにしない

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

# --- 配線 ---

@test "hooks.json: registers both WorktreeCreate and SessionStart" {
  [ -f "$HOOKS_JSON" ]
  run python3 -c "
import json
d = json.load(open('${HOOKS_JSON}'))['hooks']
assert 'WorktreeCreate' in d, 'WorktreeCreate missing'
assert 'SessionStart' in d, 'SessionStart missing'
"
  [ "$status" -eq 0 ]
}

@test "hooks.json: references hook scripts via CLAUDE_PLUGIN_ROOT" {
  # 絶対パス直書きだと marketplace / installed のどちらに展開されても壊れる。
  run grep -c 'CLAUDE_PLUGIN_ROOT' "$HOOKS_JSON"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
}

@test "hooks: both scripts exist, are executable and pass bash -n" {
  [ -x "$WT_CREATE_HOOK_SH" ]
  [ -x "$WT_SETUP_GUARD_SH" ]
  run bash -n "$WT_CREATE_HOOK_SH"
  [ "$status" -eq 0 ]
  run bash -n "$WT_SETUP_GUARD_SH"
  [ "$status" -eq 0 ]
}

# --- wt-create-hook: 正常系 ---

@test "wt-create-hook: creates the worktree and prints only its path on stdout" {
  local repo
  repo="$(wt_make_repo create-ok)"
  run bash -c "echo '{\"cwd\":\"${repo}\",\"name\":\"feat\"}' | '${WT_CREATE_HOOK_SH}' 2>/dev/null"
  [ "$status" -eq 0 ]
  # stdout は 1 行の絶対パスのみ
  [ "$output" = "${repo}/.claude/worktrees/feat" ]
  [ -d "$output" ]
}

@test "wt-create-hook: follows the default layout (.claude/worktrees/NAME, branch worktree-NAME)" {
  # Claude Code のフック無し既定動作と一致させる。ずれると本体側の後片付けと食い違う。
  local repo
  repo="$(wt_make_repo create-default)"
  run bash -c "echo '{\"cwd\":\"${repo}\",\"name\":\"abc\"}' | '${WT_CREATE_HOOK_SH}' 2>/dev/null"
  [ "$status" -eq 0 ]
  run git -C "$repo" worktree list
  [[ "$output" == *".claude/worktrees/abc"* ]]
  [[ "$output" == *"worktree-abc"* ]]
}

@test "wt-create-hook: copies .worktreeinclude targets into the worktree" {
  local repo
  repo="$(wt_make_repo create-env)"
  printf '.env\n' >"${repo}/.gitignore"
  printf '.env\n' >"${repo}/.worktreeinclude"
  printf 'SECRET=main\n' >"${repo}/.env"
  git -C "$repo" add -A
  git -C "$repo" commit -qm add-include

  run bash -c "echo '{\"cwd\":\"${repo}\",\"name\":\"withenv\"}' | '${WT_CREATE_HOOK_SH}' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -f "${repo}/.claude/worktrees/withenv/.env" ]
  run cat "${repo}/.claude/worktrees/withenv/.env"
  [ "$output" = "SECRET=main" ]
}

@test "wt-create-hook: is idempotent and preserves existing worktree contents" {
  local repo first second
  repo="$(wt_make_repo create-idem)"
  first="$(echo "{\"cwd\":\"${repo}\",\"name\":\"same\"}" | bash "$WT_CREATE_HOOK_SH" 2>/dev/null)"
  echo "marker" >"${first}/user-work.txt"
  second="$(echo "{\"cwd\":\"${repo}\",\"name\":\"same\"}" | bash "$WT_CREATE_HOOK_SH" 2>/dev/null)"
  [ "$first" = "$second" ]
  # 作業中のファイルが消えていないこと
  [ -f "${first}/user-work.txt" ]
}

@test "wt-create-hook: writes the done marker so the guard does not rerun setup" {
  local repo wt gitdir
  repo="$(wt_make_repo create-marker)"
  wt="$(echo "{\"cwd\":\"${repo}\",\"name\":\"marked\"}" | bash "$WT_CREATE_HOOK_SH" 2>/dev/null)"
  gitdir="$(git -C "$wt" rev-parse --git-dir)"
  [ -f "${gitdir}/wt-setup-done" ]
}

# --- wt-create-hook: 異常系 ---

@test "wt-create-hook: fails non-zero and prints no path when name is missing" {
  local repo
  repo="$(wt_make_repo create-noname)"
  run bash -c "echo '{\"cwd\":\"${repo}\"}' | '${WT_CREATE_HOOK_SH}' 2>/dev/null"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "wt-create-hook: rejects a name containing path separators or .." {
  local repo
  repo="$(wt_make_repo create-traversal)"
  run bash -c "echo '{\"cwd\":\"${repo}\",\"name\":\"../evil\"}' | '${WT_CREATE_HOOK_SH}' 2>/dev/null"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [ ! -d "${repo}/../evil" ]
}

# --- wt-setup-guard: 無出力であるべきケース ---

@test "wt-setup-guard: stays silent and exits 0 in the main repository" {
  local repo
  repo="$(wt_make_repo guard-main)"
  run bash -c "cd '${repo}' && echo '{}' | '${WT_SETUP_GUARD_SH}' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "wt-setup-guard: stays silent and exits 0 outside any git repository" {
  run bash -c "cd '${BATS_TEST_TMPDIR}' && echo '{}' | '${WT_SETUP_GUARD_SH}' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "wt-setup-guard: stays silent on subsequent sessions" {
  local repo wt
  repo="$(wt_make_repo guard-twice)"
  wt="${BATS_TEST_TMPDIR}/guard-twice-wt"
  git -C "$repo" worktree add -q "$wt" -b twice

  # 1 回目: 出力あり
  run bash -c "cd '${wt}' && echo '{}' | '${WT_SETUP_GUARD_SH}' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  # 2 回目: 無出力
  run bash -c "cd '${wt}' && echo '{}' | '${WT_SETUP_GUARD_SH}' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- wt-setup-guard: 発火すべきケース ---

@test "wt-setup-guard: emits SessionStart JSON for an unset-up worktree" {
  local repo wt
  repo="$(wt_make_repo guard-fire)"
  wt="${BATS_TEST_TMPDIR}/guard-fire-wt"
  git -C "$repo" worktree add -q "$wt" -b fire

  # マーカーで 2 回目は黙るため、検証は 1 回目の出力に対して行う。
  run bash -c "cd '${wt}' && echo '{}' | '${WT_SETUP_GUARD_SH}' 2>/dev/null | python3 -c \"
import json,sys
d = json.load(sys.stdin)['hookSpecificOutput']
assert d['hookEventName'] == 'SessionStart', d
assert 'wt-setup' in d['additionalContext']
print('ok')
\""
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "wt-setup-guard: reports a missing .worktreeinclude as remaining work" {
  local repo wt
  repo="$(wt_make_repo guard-notes)"
  wt="${BATS_TEST_TMPDIR}/guard-notes-wt"
  git -C "$repo" worktree add -q "$wt" -b notes

  run bash -c "cd '${wt}' && echo '{}' | '${WT_SETUP_GUARD_SH}' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *".worktreeinclude"* ]]
}

@test "wt-setup-guard: symlinks .claude subdirectories into the worktree" {
  local repo wt
  repo="$(wt_make_repo guard-symlink)"
  printf '.claude/\n' >"${repo}/.gitignore"
  git -C "$repo" add -A
  git -C "$repo" commit -qm ignore-claude
  mkdir -p "${repo}/.claude/skills"
  echo x >"${repo}/.claude/skills/s.md"
  wt="${BATS_TEST_TMPDIR}/guard-symlink-wt"
  git -C "$repo" worktree add -q "$wt" -b symlink

  run bash -c "cd '${wt}' && echo '{}' | '${WT_SETUP_GUARD_SH}' >/dev/null 2>&1; test -L '${wt}/.claude/skills'"
  [ "$status" -eq 0 ]
}
