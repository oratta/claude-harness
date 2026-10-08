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

# --- シェル構文の読み（#820 F1・F4〜F10） ---
# spec destructive-git-hook の要件「コマンド文字列をシェルと同じ単位で読む」。止まる入力と、同じ構文で通す入力を対にする。

@test "shell syntax: git inside an argument with newlines is judged (F1)" {
  expect_stopped $'bash -c \'\ngit reset --hard\n\''
  expect_stopped $'git -c core.x=\'first\nsecond\' reset --hard'
  expect_stopped $'eval "ls\ngit reset --hard"'
  # -c / eval の引数にならない引用文字列の改行より後ろは、引き続き読まない
  expect_silent $'git commit -m "1 行目\ngit branch -D x を止める"'
  expect_silent $'echo "a\ngit reset --hard"'
}

@test "shell syntax: a quoted ) inside \$(...) does not end the substitution (F4)" {
  expect_stopped 'echo "$(printf '"')'"'; git reset --hard)"'
  expect_stopped 'echo "$(echo "$(git reset --hard)")"'
  expect_stopped 'echo $(printf "(" ; git reset --hard)'
}

@test "shell syntax: quotes inside a comment do not hide the next line (F5)" {
  expect_stopped $'# It\'s cleanup\ngit reset --hard'
  expect_stopped $'ls # it\'s fine\ngit reset --hard'
  # コメントの中の git と、引用符の中・語の途中の # はコメントにしない
  expect_silent 'ls # git reset --hard'
  expect_silent 'echo "#"; git status'
  expect_silent 'echo a#b git reset --hard'
}

@test "shell syntax: a redirection does not split the simple command (F6)" {
  expect_stopped 'git reset >/dev/null --hard'
  expect_stopped 'git reset 2>&1 --hard'
  expect_stopped '>/dev/null git reset --hard'
  expect_stopped 'git reset --hard >/dev/null'
  expect_stopped 'git reset &>/dev/null --hard'
  expect_silent 'git status >/dev/null 2>&1'
}

@test "shell syntax: line continuations are joined (F7)" {
  expect_stopped $'git \\\nreset --hard'
  expect_stopped $'git reset \\\n  --hard'
  expect_stopped $'bash -c "git \\\nreset --hard"'
  # 単一引用符の中のバックスラッシュと改行は行継続にしない
  expect_silent $'echo \'a \\\ngit reset --hard\''
}

@test "shell syntax: quoted operators do not separate commands (F8)" {
  expect_silent "echo ';' git reset --hard"
  expect_silent 'echo "|" git reset --hard'
  expect_silent 'echo \& git reset --hard'
  expect_silent "echo '&&' git reset --hard"
  # 引用されていない演算子では引き続き区切る
  expect_stopped 'echo x; git reset --hard'
  expect_stopped 'echo x | git reset --hard'
  expect_stopped 'echo x & git reset --hard'
}

@test "shell syntax: whole heredoc delimiters and here-strings (F9)" {
  expect_stopped $'cat <<END-TAG\nbody\nEND-TAG\ngit reset --hard'
  expect_stopped $'cat <<-\'EOF\'\n\tbody\n\tEOF\ngit reset --hard'
  expect_stopped $'cat <<< EOF\ngit reset --hard'
  expect_stopped $'cat <<<"$(git reset --hard)"'
  # 区切り語の前半だけの行では本文を終わらせない
  expect_silent $'cat <<END-TAG\nEND\ngit reset --hard\nEND-TAG'
}

@test "shell syntax: substitutions in a quoted heredoc body are not judged (F10)" {
  expect_silent $'cat <<\'EOF\'\n$(git reset --hard)\nEOF'
  expect_silent $'cat <<"EOF"\n`git reset --hard`\nEOF'
  expect_silent $'cat <<\\EOF\n$(git reset --hard)\nEOF'
  # 引用されていない本文の置換はシェルが実行するので判定する
  expect_stopped $'cat <<EOF\n$(git reset --hard)\nEOF'
}

@test "shell syntax: reserved words at the head are still out of scope" {
  # spec の守備範囲で通ることを許す形。変更の後も止めない
  expect_silent 'for f in *; do git checkout -- "$f"; done'
  expect_silent 'if true; then git reset --hard; fi'
  expect_silent '{ git reset --hard; }'
  expect_silent '! git reset --hard'
}

@test "shell syntax: unclosed quotes still split on newlines and judge substitutions" {
  # 字句読みに置き換える前から止めていた形。閉じていない引用符で判定を諦めない
  expect_stopped $'ls\ngit reset --hard "x'
  expect_stopped 'echo "$(git reset --hard)'
  expect_stopped 'echo `git reset --hard` "x'
  # 閉じていない引用符の中の改行より後ろと、単一引用符の中の置換は読まない
  expect_silent $'git commit -m "a\ngit reset --hard'
  expect_silent 'echo '"'"'$(git reset --hard)'"'"' "x'
}

@test "shell syntax: deeply nested substitutions are still judged" {
  # 字句読みに置き換える前から止めていた形。置換の入れ子の深さで判定を諦めない
  # （9 は bash -c / eval の再帰の上限を超える深さ、500 以上は字句読みの再帰が尽きる深さ）
  local n k open close quoted
  for n in 9 50 500 2000; do
    open="$(printf '$(%.0s' $(seq "$n"))"
    close="$(printf ')%.0s' $(seq "$n"))"
    quoted='git reset --hard'
    for k in $(seq "$n"); do quoted="echo \"\$(${quoted})\""; done
    expect_stopped "echo ${open}git reset --hard${close}"
    expect_stopped "${quoted}"
    expect_stopped "echo ${open}git reset --hard"
    expect_stopped "echo ${open}true${close}; git reset --hard"
    expect_stopped "bash -c \"\$(echo ${open}git reset --hard${close})\""
    expect_stopped "echo ${open}bash -c 'git reset --hard'${close}"
    # 深い入れ子があっても、単一引用符の中の文字列は読まない
    expect_silent "echo ${open}true${close}; echo 'git reset --hard'"
  done
}

@test "shell syntax: quoted -c / eval arguments are kept at any nesting depth" {
  # 字句読みに置き換える前から止めていた形（PR #852 ゲート一周目 R-1）。入れ子が深くても、
  # bash -c / eval に渡した引用つきのコマンド文字列を空白で割って失わない
  local open close
  open="$(printf '$(%.0s' $(seq 6000))"
  close="$(printf ')%.0s' $(seq 6000))"
  expect_stopped "echo ${open}bash -c 'git reset --hard'${close}"
  expect_stopped "echo ${open}eval 'git reset --hard'${close}"
  expect_stopped "echo ${open}sh -c \"git reset --hard\"${close}"
  expect_stopped "echo ${open}eval \"git reset --hard\"${close}"
  # 深さによらず、単一引用符の中の文字列は読まない
  expect_silent "echo ${open}echo 'git reset --hard'${close}"
  # 20000 重でも、二重引用符つきの入れ子・閉じていない入れ子・括弧で同じ（異常終了で素通しにしない）
  local n=20000 qopen qclose popen pclose
  open="$(printf '$(%.0s' $(seq "$n"))"
  close="$(printf ')%.0s' $(seq "$n"))"
  qopen="$(printf 'echo "$(%.0s' $(seq "$n"))"
  qclose="$(printf ')"%.0s' $(seq "$n"))"
  popen="$(printf '(%.0s' $(seq "$n"))"
  expect_stopped "echo ${open}bash -c 'git reset --hard'${close}"
  expect_stopped "${qopen}eval 'git reset --hard'${qclose}"
  expect_stopped "${qopen}bash -c 'git reset --hard'"
  expect_stopped "echo ${open}git reset --hard"
  expect_stopped "${popen}bash -c 'git reset --hard'${close}"
  expect_silent "${qopen}echo 'git reset --hard'${qclose}"
}

@test "shell syntax: an unclosed \$( inside an unclosed quote keeps quoted -c / eval arguments" {
  # 字句読みに置き換える前から止めていた形。閉じていない $( の中身は、引用符が閉じていれば末尾まで字句読みで読む
  expect_stopped 'echo "$(bash -c '"'git reset --hard'"
  expect_stopped 'echo "$(eval "git reset --hard"'
  expect_stopped 'echo "$(true; git reset --hard'
  expect_stopped 'echo "$(echo "$(sh -c '"'git reset --hard'"
  # 閉じていない $( の中でも、単一引用符の中の文字列は読まない
  expect_silent 'echo "$(echo '"'git reset --hard'"
}

@test "shell syntax: chained bash -c / eval arguments are judged without repeating the work" {
  # bash -c "$(bash -c "$(...)")" を重ねた形。字句読みに置き換える前から止めていた。内側の引数を重ねた数の
  # 8 乗に比例する回数だけ判定し直すと、30 重ほどで hook の時間切れになり、素通しになる
  local k chain_git='git reset --hard' chain_true='true' eval_git='git reset --hard'
  for k in $(seq 40); do
    chain_git="bash -c \"\$(${chain_git})\""
    chain_true="bash -c \"\$(${chain_true})\""
    eval_git="eval \"\$(${eval_git})\""
  done
  expect_stopped "${chain_git}"
  expect_stopped "${eval_git}"
  expect_stopped "${chain_true}; git reset --hard"
  expect_silent "${chain_true}; git status"
}

# --- 引数を取るオプションの値（PR #794 ゲート一周目 F2・F11・F12） ---

@test "option values: a -n that is an option value does not make push or clean a dry-run" {
  expect_stopped 'git push -o -n origin main'
  expect_stopped 'git push -on origin main'
  expect_stopped 'git push -o -n --force origin feature-x'
  expect_stopped 'git push --push-option=x -o -n origin main'
  expect_stopped 'git clean -f -- -n'
  expect_stopped 'git clean -f -e -n'
  # 実オプションの -n / --dry-run は従来どおり dry-run
  expect_silent 'git push -o x -n origin main'
  expect_silent 'git push -no x origin main'
  expect_silent 'git push --dry-run -o x --force origin feature-x'
  expect_silent 'git clean -f -n -- a'
}

@test "option values: commit -n before an argument-taking short option is stopped" {
  expect_stopped 'git commit -nmfix123'
  expect_stopped 'git commit -anm"fix: typo"'
  expect_stopped 'git commit -nF msg.txt'
  # 引数を取る短いオプションより後ろはその値
  expect_silent 'git commit -mn'
  expect_silent 'git commit -m n'
  expect_silent 'git commit -am"no n here"'
  expect_silent 'git commit -m x -- -n'
}

@test "option values: --no-verify / --no-gpg-sign as an option value are not matched" {
  expect_silent "git commit -m '--no-verify'"
  expect_silent "git commit -m '--no-gpg-sign'"
  expect_silent 'git commit --message=--no-verify'
  expect_silent 'git commit -m--no-gpg-sign'
  expect_silent 'git push -o --no-verify origin feature-x'
  expect_silent 'git commit -m x -- --no-verify'
  # 実オプションとして別に付けたものは止まる
  expect_stopped "git commit -m '--no-verify' --no-verify"
  expect_stopped "git commit --no-gpg-sign -m '--no-gpg-sign'"
  expect_stopped 'git push -o x --no-verify origin feature-x'
}

@test "heredoc: commands after the heredoc are still judged" {
  expect_stopped $'cat <<EOF > note.txt\nbody\nEOF\ngit reset --hard'
}

# --- ask / deny ---

@test "mode: default acceptEdits plan bypassPermissions return ask" {
  call 'git reset --hard' default
  [ "$(decision)" = "ask" ]
  call 'git reset --hard' bypassPermissions
  [ "$(decision)" = "ask" ]
  call 'git reset --hard' acceptEdits
  [ "$(decision)" = "ask" ]
  call 'git reset --hard' plan
  [ "$(decision)" = "ask" ]
}

@test "mode: missing, unknown, dontAsk and auto return deny" {
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
  json="$(payload 'git reset --hard' auto)"
  run env DEV_WORKFLOW_GIT_GUARD_FORCE=ask "$SCRIPT" <<<"$json"
  [ "$(decision)" = "ask" ]
  json="$(payload 'git reset --hard' default)"
  run env DEV_WORKFLOW_GIT_GUARD_FORCE=deny "$SCRIPT" <<<"$json"
  [ "$(decision)" = "deny" ]
}

# --- 拒否理由 ---

@test "reason: deny explains how to get approval" {
  call 'git push origin main' auto
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

@test "reason: ask explains the confirmation and the no-screen case" {
  call 'git push origin main' bypassPermissions
  [ "$(decision)" = "ask" ]
  local r
  r="$(reason)"
  echo "$r" | grep -qF 'main / master'
  echo "$r" | grep -qF 'rules/destructive-git-guard.md'
  echo "$r" | grep -qF '確認画面'
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

# raw_command <JSON 文字列の中身> — \uXXXX を含む生の JSON を payload に埋めて実行する。
# payload() は json.dumps が非 ASCII を \u に直す程度で、エスケープの生入力にならないため使わない。
raw_command() {
  case "$1" in *'\u'*) ;; *) echo "no \u escape in: $1"; return 1 ;; esac
  run "$SCRIPT" <<<'{"tool_name":"Bash","permission_mode":"default","tool_input":{"command":"'"$1"'"}}'
  [ "$status" -eq 0 ] || { echo "status=$status for: $1"; return 1; }
}

@test "unicode escape: escaped hyphens in --hard are decoded and stopped" {
  raw_command 'git reset \u002d\u002dhard'
  [ "$(decision)" = "ask" ]
}

@test "unicode escape: escaped letter in git is decoded and stopped" {
  raw_command '\u0067it reset --hard'
  [ "$(decision)" = "ask" ]
}

@test "unicode escape: escaped newline separates lines and the second is stopped" {
  raw_command 'ls\u000agit reset --hard'
  [ "$(decision)" = "ask" ]
}

@test "unicode escape: surrogate pair before && does not hide the command" {
  raw_command 'echo \ud83d\ude00 && git reset --hard'
  [ "$(decision)" = "ask" ]
}

@test "unicode escape: escaped text inside quotes stays silent" {
  raw_command 'git commit -m \"\u65e5\u672c\u8a9e git reset --hard\"'
  [ -z "$output" ]
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
