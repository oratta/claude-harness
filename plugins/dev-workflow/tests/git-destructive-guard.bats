#!/usr/bin/env bats
#
# git-destructive-guard.sh: PreToolUse（Bash）で破壊的 git 操作を ask / deny で止める。
# spec: destructive-git-hook（openspec/changes/destructive-git-hook。archive 後は openspec/specs/destructive-git-hook）
# 規範: rules/destructive-git-guard.md

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/git-destructive-guard.sh"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  unset DEV_WORKFLOW_GIT_GUARD DEV_WORKFLOW_GIT_GUARD_FORCE
}

# payload <command> [permission_mode] — Bash の payload を JSON で出力する。
# permission_mode に "-" を渡すとキー自体を省く。
payload() {
  python3 -c '
import json, sys
cmd, mode = sys.argv[1], sys.argv[2]
p = {"tool_name": "Bash", "tool_input": {"command": cmd}, "hook_event_name": "PreToolUse"}
if mode != "-":
    p["permission_mode"] = mode
print(json.dumps(p))' "$1" "${2:-default}"
}

# call <command> [permission_mode]
call() {
  local json
  json="$(payload "$1" "${2:-default}")"
  run "$SCRIPT" <<<"$json"
}

# decision — 出力の permissionDecision を出す（JSON でなければ空）
decision() {
  python3 -c '
import json, sys
try:
    print(json.loads(sys.stdin.read())["hookSpecificOutput"]["permissionDecision"])
except Exception:
    pass' <<<"$output"
}

reason() {
  python3 -c '
import json, sys
print(json.loads(sys.stdin.read())["hookSpecificOutput"]["permissionDecisionReason"])' <<<"$output"
}

# expect_stopped <command> — ask か deny が返ること
expect_stopped() {
  call "$1"
  [ "$status" -eq 0 ] || { echo "status=$status for: $1"; return 1; }
  local d
  d="$(decision)"
  [ "$d" = "ask" ] || [ "$d" = "deny" ] || { echo "not stopped: $1 -> [$output]"; return 1; }
}

# expect_silent <command> — 何も出さず exit 0
expect_silent() {
  call "$1"
  [ "$status" -eq 0 ] || { echo "status=$status for: $1"; return 1; }
  [ -z "$output" ] || { echo "unexpected output for: $1 -> [$output]"; return 1; }
}

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

# --- 対象 9 種 ---

@test "nine kinds: each listed command is stopped" {
  expect_stopped 'git checkout -- a.txt'
  expect_stopped 'git checkout .'
  expect_stopped 'git restore a.txt'
  expect_stopped 'git restore --worktree --staged a.txt'
  expect_stopped 'git reset --hard'
  expect_stopped 'git reset --hard origin/main'
  expect_stopped 'git clean -fd'
  expect_stopped 'git clean --force'
  expect_stopped 'git push origin main'
  expect_stopped 'git push upstream master'
  expect_stopped 'git push --force origin feature-x'
  expect_stopped 'git push --force-with-lease origin feature-x'
  expect_stopped 'git push --force-with-lease=feature-x:abc origin feature-x'
  expect_stopped 'git push origin +feature-x'
  expect_stopped 'git push -uf origin feature-x'
  expect_stopped 'git branch -D feature-x'
  expect_stopped 'git branch -df feature-x'
  expect_stopped 'git branch --delete --force feature-x'
  expect_stopped 'git commit --no-verify -m x'
  expect_stopped 'git push --no-verify origin feature-x'
  expect_stopped 'git commit --no-gpg-sign -m x'
}

@test "push to main: refspec variants are stopped" {
  expect_stopped 'git push origin +main'
  expect_stopped 'git push origin refs/heads/main'
  expect_stopped 'git push origin HEAD:main'
  expect_stopped 'git push origin feature-x:main'
  expect_stopped 'git push origin :main'
  expect_stopped 'git push origin --delete main'
  expect_stopped 'git push origin HEAD:refs/heads/master'
}

@test "compound: chained, substituted and wrapped forms are stopped" {
  expect_stopped 'cd x && git reset --hard'
  expect_stopped 'git status; git reset --hard'
  expect_stopped 'false || git clean -fdx'
  expect_stopped 'echo $(git reset --hard)'
  expect_stopped 'echo "$(git reset --hard)"'
  expect_stopped 'echo `git reset --hard`'
  expect_stopped "bash -c 'git push -f origin x'"
  expect_stopped "sh -c \"cd y && git reset --hard\""
  expect_stopped "eval 'git branch -D x'"
  expect_stopped 'git -C repo reset --hard'
  expect_stopped 'git -c core.x=y push origin HEAD:master'
  expect_stopped 'git --no-pager --git-dir=.git reset --hard'
  expect_stopped 'FOO=1 git clean -xdf'
  expect_stopped 'env FOO=1 git reset --hard'
  expect_stopped 'sudo git reset --hard'
  expect_stopped '/usr/bin/git reset --hard'
  expect_stopped $'ls\ngit reset --hard'
  expect_stopped '(cd x && git reset --hard)'
}

@test "commit -n: bundled short options are stopped" {
  expect_stopped 'git commit -n -m x'
  expect_stopped 'git commit -an'
  expect_stopped 'git commit -anm x'
}

@test "out of scope: nothing is printed" {
  expect_silent 'git status'
  expect_silent 'git push origin feature-x'
  expect_silent 'git push -u origin feature/x'
  expect_silent 'git push origin HEAD'
  expect_silent 'git push'
  expect_silent 'git push origin maintenance'
  expect_silent 'git push -n origin main'
  expect_silent 'git push --dry-run --force origin feature-x'
  expect_silent 'git checkout feature-x'
  expect_silent 'git checkout -b feature-y'
  expect_silent 'git restore --staged a.txt'
  expect_silent 'git restore -S a.txt'
  expect_silent 'git clean -n'
  expect_silent 'git clean -fn'
  expect_silent 'git branch -d feature-x'
  expect_silent 'git reset --soft HEAD~1'
  expect_silent 'git commit -mn'
  expect_silent 'git commit -m "--no-verify を外す"'
  expect_silent 'echo git reset --hard'
  expect_silent 'grep -r "git push --force" docs'
  expect_silent 'ls'
}

@test "out of scope: message bodies are not read as commands" {
  expect_silent $'git commit -m "$(cat <<\'EOF\'\nhook を足す\ngit reset --hard を止める\nEOF\n)"'
  expect_silent $'cat <<EOF > note.txt\ngit push --force origin main\nEOF'
  expect_silent $'git commit -m "first line\ngit branch -D x を止める"'
  expect_silent $'gh issue comment 1 --body "$(printf \'git reset --hard\\n\')"'
  expect_silent 'git push -o main origin feature-x'
  expect_silent 'git commit --author n -m x'
}

@test "heredoc: commands after the heredoc are still judged" {
  expect_stopped $'cat <<EOF > note.txt\nbody\nEOF\ngit reset --hard'
}

# --- ask / deny ---

@test "mode: default acceptEdits plan return ask" {
  call 'git reset --hard' default
  [ "$(decision)" = "ask" ]
  call 'git reset --hard' acceptEdits
  [ "$(decision)" = "ask" ]
  call 'git reset --hard' plan
  [ "$(decision)" = "ask" ]
}

@test "mode: bypassPermissions, missing and unknown return deny" {
  call 'git reset --hard' bypassPermissions
  [ "$(decision)" = "deny" ]
  call 'git reset --hard' -
  [ "$(decision)" = "deny" ]
  call 'git reset --hard' somethingNew
  [ "$(decision)" = "deny" ]
  call 'git reset --hard' dontAsk
  [ "$(decision)" = "deny" ]
  call 'git reset --hard' auto
  [ "$(decision)" = "deny" ]
}

@test "force env: overrides the mode" {
  local json
  json="$(payload 'git reset --hard' bypassPermissions)"
  run env DEV_WORKFLOW_GIT_GUARD_FORCE=ask "$SCRIPT" <<<"$json"
  [ "$(decision)" = "ask" ]
  json="$(payload 'git reset --hard' default)"
  run env DEV_WORKFLOW_GIT_GUARD_FORCE=deny "$SCRIPT" <<<"$json"
  [ "$(decision)" = "deny" ]
}

# --- 拒否理由 ---

@test "reason: deny explains how to get approval" {
  call 'git push origin main' bypassPermissions
  [ "$(decision)" = "deny" ]
  local r
  r="$(reason)"
  echo "$r" | grep -qF 'main / master'
  echo "$r" | grep -qF 'rules/destructive-git-guard.md'
  echo "$r" | grep -qF '主に承認を求め'
  echo "$r" | grep -qF '主が自分で実行'
  echo "$r" | grep -qF '言い換え'
  [[ "$r" != *DEV_WORKFLOW_GIT_GUARD* ]] || return 1
}

@test "reason: lists every matched kind" {
  call 'git reset --hard && git push --force origin x' bypassPermissions
  local r
  r="$(reason)"
  echo "$r" | grep -qF 'git reset --hard'
  echo "$r" | grep -qF 'force'
}

# --- 逃げ道と fail-open ---

@test "off: everything passes" {
  local json
  json="$(payload 'git reset --hard' bypassPermissions)"
  run env DEV_WORKFLOW_GIT_GUARD=off "$SCRIPT" <<<"$json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fail-open: unreadable input passes silently" {
  run "$SCRIPT" <<<''
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$SCRIPT" <<<'not json git'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$SCRIPT" <<<'{"tool_name":"Edit","tool_input":{"command":"git reset --hard"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$SCRIPT" <<<'{"tool_name":"Bash","tool_input":{"command":["git","reset","--hard"]}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$SCRIPT" <<<'["git"]'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "unbalanced quotes: still judged" {
  expect_stopped 'git reset --hard && echo "oops'
}

@test "unicode-escaped payload: still judged" {
  run "$SCRIPT" <<<'{"tool_name":"Bash","permission_mode":"default","tool_input":{"command":"git reset --hard"}}'
  [ "$(decision)" = "ask" ]
}

# --- hooks.json ---

@test "hooks.json: guard is the last PreToolUse entry on Bash without if" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
pre = d["hooks"]["PreToolUse"]
assert pre[0]["matcher"] == "Agent", pre[0]
e = pre[-1]
assert e["matcher"] == "Bash", e
assert "if" not in e, e
h = e["hooks"][0]
assert "if" not in h, h
assert h["type"] == "command"
assert h["command"] == '"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh"', h["command"]
PY
}
