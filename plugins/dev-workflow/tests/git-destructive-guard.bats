#!/usr/bin/env bats
#
# git-destructive-guard.sh: PreToolUse（Bash）で破壊的 git 操作を ask / deny で止める。
# spec: destructive-git-hook（openspec/changes/destructive-git-hook。archive 後は openspec/specs/destructive-git-hook）
# 規範: rules/destructive-git-guard.md

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/git-destructive-guard.sh"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  unset DEV_WORKFLOW_GIT_GUARD DEV_WORKFLOW_GIT_GUARD_FORCE DEV_WORKFLOW_UNATTENDED
  # cd と git の行き先・設定を変える環境変数があると一時領域の判定を満たさないので、実行する人の環境から外す
  unset CDPATH GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
    GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM
  local v
  for v in $(env | sed -n 's/^\(GIT_CONFIG[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done
  # 子への拒否の回数は TMPDIR の下に数える。テストごとの空のディレクトリに向けて隔離する
  export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  mkdir -p "$TMPDIR"
}

# payload <command> [permission_mode] [agent_id] [session_id] — Bash の payload を JSON で出力する。
# permission_mode に "-" を渡すとキー自体を省く。agent_id は JSON の値で渡す（'"a1"' / '""' / '7'）。
# agent_id と session_id は省くか "-" を渡すとキー自体を省く（主の呼び出し）。
# コマンド文字列は長くなりうる（深い入れ子で数十万字）。Linux は引数 1 つの長さに上限（128 KiB）があるので、
# 引数や環境変数ではなく、シェル組み込みの printf から標準入力で渡す。
payload() {
  printf '%s' "$1" | python3 -c '
import json, sys
cmd, mode, agent, session = sys.stdin.read(), sys.argv[1], sys.argv[2], sys.argv[3]
p = {"tool_name": "Bash", "tool_input": {"command": cmd}, "hook_event_name": "PreToolUse"}
if mode != "-":
    p["permission_mode"] = mode
if agent != "-":
    p["agent_id"] = json.loads(agent)
if session != "-":
    p["session_id"] = session
print(json.dumps(p))' "${2:-default}" "${3:--}" "${4:--}"
}

# call <command> [permission_mode] [agent_id] [session_id]
call() {
  local json
  json="$(payload "$1" "${2:-default}" "${3:--}" "${4:--}")"
  run "$SCRIPT" <<<"$json"
}

# has_continue — 出力のトップレベルに continue のキーがあれば真
has_continue() {
  python3 -c '
import json, sys
sys.exit(0 if "continue" in json.loads(sys.stdin.read()) else 1)' <<<"$output"
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

# count_files — 回数のファイル（dev-workflow-git-guard/ の直下のファイル）の名前を出す。
# 同じ場所に denied/ と permits/ のディレクトリもできるので、ファイルだけを数える
count_files() {
  find "$TMPDIR/dev-workflow-git-guard" -mindepth 1 -maxdepth 1 -type f ! -name '*.jsonl' -exec basename {} \;
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

# 対象 9 種の代表のコマンド（spec の Scenario「対象 9 種が止まる」。無人のセッションの判定でも同じ一覧を使う）
NINE_KINDS=(
  'git checkout -- a.txt'
  'git checkout .'
  'git restore a.txt'
  'git restore --worktree --staged a.txt'
  'git reset --hard'
  'git reset --hard origin/main'
  'git clean -fd'
  'git clean --force'
  'git push origin main'
  'git push upstream master'
  'git push --force origin feature-x'
  'git push --force-with-lease origin feature-x'
  'git push --force-with-lease=feature-x:abc origin feature-x'
  'git push origin +feature-x'
  'git push -uf origin feature-x'
  'git branch -D feature-x'
  'git branch -df feature-x'
  'git branch --delete --force feature-x'
  'git commit --no-verify -m x'
  'git push --no-verify origin feature-x'
  'git commit --no-gpg-sign -m x'
)

@test "nine kinds: each listed command is stopped" {
  local c
  [ "${#NINE_KINDS[@]}" -ge 9 ] || { echo "NINE_KINDS is empty"; return 1; }
  for c in "${NINE_KINDS[@]}"; do
    expect_stopped "$c"
  done
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

@test "shell syntax: arithmetic << and an escaped quote in dollar-quote do not hide later commands (#981)" {
  expect_stopped $'(( x << 2 ))\ngit reset --hard'
  expect_stopped $'let y=1<<2\ngit reset --hard'
  expect_stopped "echo \$'it\\'s'; git reset --hard"
  # 区切り語の行がある本物のヒアドキュメントの本文は今までどおり止めない
  expect_silent $'cat <<EOF\ngit reset --hard\nEOF'
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

# chained_within <秒> <重ねる数> <頭> <中心のコマンド> [後ろに続けるコマンド]
# — <頭> "$(...)" を重ねたコマンドを hook に渡し、上限の秒数のうちに返った結果を 1 語で出す
# （ask / deny / silent / timeout / error）。hook の時間切れは何も止めないのと同じ結果になるので、時間も検査する。
chained_within() {
  python3 - "$SCRIPT" "$@" <<'PY'
import json, subprocess, sys
script, limit, n, head, cmd = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5]
for _ in range(n):
    cmd = '%s "$(%s)"' % (head, cmd)
if len(sys.argv) > 6:
    cmd += "; " + sys.argv[6]
p = json.dumps({"tool_name": "Bash", "permission_mode": "default", "tool_input": {"command": cmd}})
try:
    r = subprocess.run([script], input=p, capture_output=True, text=True, timeout=limit)
except subprocess.TimeoutExpired:
    print("timeout")
    sys.exit(0)
if r.returncode != 0 or r.stderr:
    print("error")
elif not r.stdout.strip():
    print("silent")
else:
    print(json.loads(r.stdout)["hookSpecificOutput"]["permissionDecision"])
PY
}

@test "shell syntax: thousands of chained bash -c / eval arguments are judged in time" {
  # 字句読みに置き換える前は 3000 重でも 1 秒かからずに止めていた形。重ねた数だけ内側の引数を読み直すと、
  # 1000 重で 30 秒を超えて hook の時間切れになり、素通しになる
  local n
  for n in 1000 3000; do
    [ "$(chained_within 10 "$n" 'bash -c' 'git reset --hard')" = ask ]
    [ "$(chained_within 10 "$n" 'eval' 'git reset --hard')" = ask ]
    [ "$(chained_within 10 "$n" 'sh -c' "bash -c 'git reset --hard'")" = ask ]
    [ "$(chained_within 10 "$n" 'bash -c' 'true' 'git reset --hard')" = ask ]
    [ "$(chained_within 10 "$n" 'eval' 'true' 'git reset --hard')" = ask ]
    # 重ねた形の奥や後ろに破壊的操作が無ければ、深くても何も出さない
    [ "$(chained_within 10 "$n" 'bash -c' 'true' 'git status')" = silent ]
    [ "$(chained_within 10 "$n" 'eval' "echo 'git reset --hard'")" = silent ]
  done
}

@test "shell syntax: a command that cannot be judged within the work limit is stopped, not passed" {
  # ヒアドキュメントを含む置換を bash -c の引数に重ねた形は、内側の引数の読み直しが残る。判定の仕事量が
  # 上限を超えたら、時間切れ（＝素通し）になる前に打ち切って止める
  local k deep='git status' shallow='git status'
  for k in $(seq 1000); do
    deep="bash -c \"\$(cat <<EOF
x
EOF
${deep}
)\""
  done
  # 深い入れ子の文字列は引数にも環境変数にも乗せず、ファイル経由で渡す（Linux の引数 1 つの上限 128 KiB を避ける）
  printf '%s' "$deep" >|"${BATS_TEST_TMPDIR}/deep.txt"
  [ "$(python3 - "$SCRIPT" "${BATS_TEST_TMPDIR}/deep.txt" <<'PY'
import json, subprocess, sys
p = json.dumps({"tool_name": "Bash", "permission_mode": "default",
                "tool_input": {"command": open(sys.argv[2]).read()}})
try:
    r = subprocess.run([sys.argv[1]], input=p, capture_output=True, text=True, timeout=10)
    o = json.loads(r.stdout)["hookSpecificOutput"]
    print(o["permissionDecision"], "判定しきれなかった" in o["permissionDecisionReason"])
except Exception as e:
    print(type(e).__name__)
PY
  )" = "ask True" ]
  # 手で書く程度の重なり（10 重）は上限に届かず、破壊的操作が無ければ何も出さない
  for k in $(seq 10); do
    shallow="bash -c \"\$(cat <<EOF
x
EOF
${shallow}
)\""
  done
  expect_silent "$shallow"
  expect_stopped "${shallow/git status/git reset --hard}"
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

# --- git と同じオプションの読み方（issue #821） ---

@test "option parsing: env options that take a value do not hide the git command" {
  expect_stopped 'env -u FOO git reset --hard'
  expect_stopped 'env -uFOO git reset --hard'
  expect_stopped 'env --unset=FOO git reset --hard'
  expect_stopped 'env --unset FOO git reset --hard'
  expect_stopped 'env -iu FOO git reset --hard'
  expect_stopped 'env -C dir -u FOO BAR=1 git reset --hard'
}

@test "option parsing: a later --no-dry-run cancels the dry-run" {
  expect_stopped 'git push -n --no-dry-run origin main'
  expect_stopped 'git clean -n --no-dry-run -f'
  expect_stopped 'git push --dry-run --no-dry-run --force origin main'
  expect_stopped 'git push -n --no-dry origin main'
}

@test "option parsing: an abbreviated long option still takes its value" {
  expect_stopped 'git push --push-opt -n origin main'
  expect_stopped 'git clean --excl -n -f'
}

@test "option parsing: --end-of-options ends the options like --" {
  expect_stopped 'git push --end-of-options -n origin main'
}

# 実装前から止まる入力。env の -S を値を取るオプションとして読んだり、commit の -n（--no-verify）を
# --no-dry-run で打ち消したりすると落ちる。
@test "option parsing: env -S and commit -n stay stopped" {
  expect_stopped 'env -S git reset --hard'
  expect_stopped 'env -iS git reset --hard'
  expect_stopped 'env --split-string git reset --hard'
  expect_stopped 'git commit -n --no-dry-run -m x'
}

@test "option parsing: a real dry-run and harmless env commands stay silent" {
  expect_silent 'git push --no-dry-run -n origin main'
  expect_silent 'git clean -f --no-dry-run -n'
  expect_silent 'git push --dry-run --no-dry-run --dry-run --force origin main'
  expect_silent 'git push --push-option=x -n origin main'
  expect_silent 'env -u FOO git status'
  expect_silent 'env -i -u FOO git push origin feature-x'
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

# --- 無人のセッション（DEV_WORKFLOW_UNATTENDED の印） ---

# call_env <env assignments...> -- <command> [permission_mode] [agent_id] [session_id]
call_env() {
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  local json
  json="$(payload "$1" "${2:-default}" "${3:--}" "${4:--}")"
  run env "${envs[@]}" "$SCRIPT" <<<"$json"
}

@test "unattended: every one of the nine kinds is denied in bypassPermissions" {
  local c
  [ "${#NINE_KINDS[@]}" -ge 9 ] || { echo "NINE_KINDS is empty"; return 1; }
  for c in "${NINE_KINDS[@]}"; do
    call_env DEV_WORKFLOW_UNATTENDED=1 -- "$c" bypassPermissions
    [ "$status" -eq 0 ] || { echo "status=$status for: $c"; return 1; }
    [ "$(decision)" = "deny" ] || { echo "not denied: $c -> [$output]"; return 1; }
  done
}

@test "unattended: modes that show the screen and force env ask still deny" {
  local m
  for m in default acceptEdits plan; do
    call_env DEV_WORKFLOW_UNATTENDED=1 -- 'git reset --hard' "$m"
    [ "$(decision)" = "deny" ] || { echo "not denied in $m"; return 1; }
  done
  call_env DEV_WORKFLOW_UNATTENDED=1 DEV_WORKFLOW_GIT_GUARD_FORCE=ask -- 'git reset --hard' bypassPermissions
  [ "$(decision)" = "deny" ]
}

@test "unattended: how the mark value is read" {
  call 'git reset --hard' bypassPermissions
  [ "$(decision)" = "ask" ]
  local v
  for v in '' 0 ' 0 '; do
    call_env "DEV_WORKFLOW_UNATTENDED=$v" -- 'git reset --hard' bypassPermissions
    [ "$(decision)" = "ask" ] || { echo "not ask for [$v]"; return 1; }
  done
  for v in true yes 1; do
    call_env "DEV_WORKFLOW_UNATTENDED=$v" -- 'git reset --hard' bypassPermissions
    [ "$(decision)" = "deny" ] || { echo "not deny for [$v]"; return 1; }
  done
}

@test "unattended: without the mark the nine kinds stay ask in bypassPermissions" {
  local c
  [ "${#NINE_KINDS[@]}" -ge 9 ] || { echo "NINE_KINDS is empty"; return 1; }
  for c in "${NINE_KINDS[@]}"; do
    call "$c" bypassPermissions
    [ "$(decision)" = "ask" ] || { echo "not ask: $c -> [$output]"; return 1; }
  done
}

@test "unattended: a child in an unattended session follows the child rule" {
  call_env DEV_WORKFLOW_UNATTENDED=1 -- 'git checkout -- a' bypassPermissions '"a1"' s1
  [ "$(decision)" = "deny" ]
  local r
  r="$(reason)"
  echo "$r" | grep -qF '打ち直さず'
  echo "$r" | grep -qF '親に返す'
  [[ "$r" != *チャンネル* ]] || return 1
}

@test "unattended: off still lets everything pass" {
  call_env DEV_WORKFLOW_GIT_GUARD=off DEV_WORKFLOW_UNATTENDED=1 -- 'git reset --hard' bypassPermissions
  [ "$status" -eq 0 ]
  [ -z "$output" ]
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

@test "reason: unattended deny asks the owner through the channel" {
  call_env DEV_WORKFLOW_UNATTENDED=1 -- 'git push origin main' bypassPermissions
  [ "$(decision)" = "deny" ]
  local r
  r="$(reason)"
  echo "$r" | grep -qF 'main / master'
  echo "$r" | grep -qF 'rules/destructive-git-guard.md'
  echo "$r" | grep -qF '実行していない'
  echo "$r" | grep -qF 'チャンネル'
  echo "$r" | grep -qF 'オーナー'
  echo "$r" | grep -qF 'オーナーが自分で実行'
  echo "$r" | grep -qF '言い換え'
  [[ "$r" != *確認画面* ]] || return 1
  [[ "$r" != *DEV_WORKFLOW_GIT_GUARD* ]] || return 1
}

@test "reason: lists every matched kind" {
  call 'git reset --hard && git push --force origin x' bypassPermissions
  local r
  r="$(reason)"
  echo "$r" | grep -qF 'git reset --hard'
  echo "$r" | grep -qF 'force'
}

# --- 子（サブエージェント）からの呼び出し ---

@test "child: deny even in modes that show the confirmation screen" {
  call 'git checkout -- a' default '"a1"' s1
  [ "$(decision)" = "deny" ]
  call 'git checkout -- a' bypassPermissions '"a2"' s1
  [ "$(decision)" = "deny" ]
}

@test "child: force env ask does not apply" {
  local json
  json="$(payload 'git checkout -- a' default '"a1"' s1)"
  run env DEV_WORKFLOW_GIT_GUARD_FORCE=ask "$SCRIPT" <<<"$json"
  [ "$(decision)" = "deny" ]
}

@test "child: empty or non-string agent_id is treated as the main session" {
  call 'git checkout -- a' default '""' s1
  [ "$(decision)" = "ask" ]
  call 'git checkout -- a' default '7' s1
  [ "$(decision)" = "ask" ]
}

@test "child: off still lets everything pass" {
  local json
  json="$(payload 'git reset --hard' default '"a1"' s1)"
  run env DEV_WORKFLOW_GIT_GUARD=off "$SCRIPT" <<<"$json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "child reason: tells the child to return to the parent" {
  call 'git checkout -- a' default '"a1"' s1
  [ "$(decision)" = "deny" ]
  local r
  r="$(reason)"
  echo "$r" | grep -qF '作業の破棄'
  echo "$r" | grep -qF 'rules/destructive-git-guard.md'
  echo "$r" | grep -qF '実行されない'
  echo "$r" | grep -qF '打ち直さず'
  echo "$r" | grep -qF 'scratchpad'
  echo "$r" | grep -qF '作り直す'
  echo "$r" | grep -qF 'コマンドの全文'
  echo "$r" | grep -qF '対象のパス'
  echo "$r" | grep -qF '自分で作った'
  echo "$r" | grep -qF 'なぜ'
  echo "$r" | grep -qF '親に返す'
  [[ "$r" != *確認画面* ]] || return 1
  [[ "$r" != *'! を付けて'* ]] || return 1
  [[ "$r" != *DEV_WORKFLOW_GIT_GUARD* ]] || return 1
  # 許可を書くのは親の役目なので、子への理由にスクリプトの名前を書かない。拒否の記録のパスは載せる
  [[ "$r" != *git-guard-permit.sh* ]] || return 1
  local rec
  rec="$(ls "$TMPDIR"/dev-workflow-git-guard/denied/*.json)"
  [[ "$r" == *"$rec"* ]] || { echo "record path not in reason: $rec"; return 1; }
}

@test "child reason: undecidable nesting keeps the head and uses the child tail" {
  # 判定の仕事量の上限を超える形（"shell syntax: a command that cannot be judged ..." と同じ組み立て）
  local k deep='git status'
  for k in $(seq 1000); do
    deep="bash -c \"\$(cat <<EOF
x
EOF
${deep}
)\""
  done
  printf '%s' "$deep" >|"${BATS_TEST_TMPDIR}/deep.txt"
  run python3 - "$SCRIPT" "${BATS_TEST_TMPDIR}/deep.txt" <<'PY'
import json, subprocess, sys
p = json.dumps({"tool_name": "Bash", "permission_mode": "default", "agent_id": "a1", "session_id": "s1",
                "tool_input": {"command": open(sys.argv[2]).read()}})
r = subprocess.run([sys.argv[1]], input=p, capture_output=True, text=True, timeout=10)
print(r.stdout)
PY
  [ "$(decision)" = "deny" ]
  local r
  r="$(reason)"
  echo "$r" | grep -qF '判定しきれなかった'
  echo "$r" | grep -qF '親に返す'
  [[ "$r" != *確認画面* ]] || return 1
}

@test "child count: first deny does not cut the child off" {
  call 'git checkout -- a' default '"a1"' s1
  [ "$(decision)" = "deny" ]
  ! has_continue || return 1
  [[ "$(reason)" != *直ちに作業を終えて親に返す* ]] || return 1
}

@test "child count: second deny for the same child returns a stronger reason" {
  call 'git checkout -- a' default '"a1"' s1
  [ "$(decision)" = "deny" ]
  call 'git checkout -- b' default '"a1"' s1
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" == *直ちに作業を終えて親に返す* ]] || return 1
  # 実機確認で、子の中の continue: false は子だけを終わらせ、親は続けると確かめた（design.md「実機確認の結果」）
  python3 -c '
import json, sys
o = json.loads(sys.stdin.read())
assert o["continue"] is False, o
assert isinstance(o.get("stopReason"), str) and o["stopReason"], o' <<<"$output"
}

@test "child count: another child counts from one" {
  call 'git checkout -- a' default '"a1"' s1
  call 'git checkout -- a' default '"a2"' s1
  [ "$(decision)" = "deny" ]
  ! has_continue || return 1
  [[ "$(reason)" != *直ちに作業を終えて親に返す* ]] || return 1
}

@test "child count: same agent_id in another session counts from one" {
  call 'git checkout -- a' default '"a1"' s1
  call 'git checkout -- a' default '"a1"' s2
  [[ "$(reason)" != *直ちに作業を終えて親に返す* ]] || return 1
}

@test "child count: file name is a hash, not the raw ids" {
  call 'git checkout -- a' default '"../x"' s1
  [ "$(decision)" = "deny" ]
  local f
  f="$(count_files)"
  [[ "$f" =~ ^[0-9a-f]{64}$ ]] || { echo "name=$f"; return 1; }
  [ "$(cat "$TMPDIR/dev-workflow-git-guard/$f")" = "1" ]
}

@test "child count: still denies when the count cannot be written" {
  chmod 500 "$TMPDIR"
  call 'git checkout -- a' default '"a1"' s1
  local d1="$(decision)" r1="$(reason)"
  call 'git checkout -- a' default '"a1"' s1
  local d2="$(decision)" r2="$(reason)"
  chmod 700 "$TMPDIR"
  [ "$d1" = "deny" ]
  [ "$d2" = "deny" ]
  [[ "$r2" != *直ちに作業を終えて親に返す* ]] || return 1
  [ ! -e "$TMPDIR/dev-workflow-git-guard" ]
}

@test "child count: a broken count file is treated as the first deny" {
  call 'git checkout -- a' default '"a1"' s1
  local f
  f="$(count_files)"
  printf 'x' >| "$TMPDIR/dev-workflow-git-guard/$f"
  call 'git checkout -- a' default '"a1"' s1
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" != *直ちに作業を終えて親に返す* ]] || return 1
}

@test "child count: unset or empty TMPDIR falls back to /tmp, not to tempfile's search" {
  # 実際の /tmp には書かずに、置き場所の決め方だけを本文で確かめる
  grep -qF 'os.environ.get("TMPDIR") or "/tmp"' "$SCRIPT"
  ! grep -qF 'gettempdir(' "$SCRIPT" || return 1
}

@test "child count: the main session is not counted" {
  local i
  for i in 1 2; do
    call 'git reset --hard' auto
    [ "$(decision)" = "deny" ]
    ! has_continue || return 1
    call 'git reset --hard' auto '""'
    [ "$(decision)" = "deny" ]
    ! has_continue || return 1
  done
  [ ! -e "$TMPDIR/dev-workflow-git-guard" ]
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

# --- エージェント定義と規則（spec: 子の定義に検証用 repo の戻し方を書く／ルール本文と hook の分担） ---

@test "agents: reviewer, worker and gate-runner say to rebuild scratchpad repos instead of git" {
  local f body
  for f in reviewer worker gate-runner; do
    body="$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2' "${PLUGIN_DIR}/agents/${f}.md")"
    printf '%s' "$body" | grep -F 'scratchpad' | grep -F '作り直す' | grep -qF 'git の破壊的操作' \
      || { echo "missing in ${f}.md"; return 1; }
    # 拒否されたら報告に書く 4 項目（spec: 子の定義に検証用 repo の戻し方を書く）
    for t in 'コマンドの全文' '対象のパス' '自分で作った'; do
      printf '%s' "$body" | grep -qF "$t" || { echo "missing '$t' in ${f}.md"; return 1; }
    done
  done
}

@test "rules: destructive-git-guard.md says subagents and unattended sessions are denied without a screen" {
  local rule="${PLUGIN_DIR}/../../rules/destructive-git-guard.md"
  local sec
  sec="$(awk '/^## hook との分担/{f=1; next} /^## /{f=0} f' "$rule")"
  printf '%s' "$sec" | grep -F 'サブエージェント' | grep -F '確認画面を出さず' | grep -F '打ち直さず' | grep -qF '親に返る'
  printf '%s' "$sec" | grep -F '画面を見ている人のいないセッション' | grep -F 'チャンネル' | grep -qF '主に承認を求める'
  ! grep -qF 'DEV_WORKFLOW_GIT_GUARD_FORCE' "$rule" || return 1
  printf '%s' "$sec" | grep -qF '入っていれば'
  printf '%s' "$sec" | grep -F 'hook' | grep -qF 'このルールだけが'
  ! grep -qF 'rules-archive' "$rule" || return 1
}

@test "rules: README row for destructive-git-guard.md mentions subagents and unattended sessions" {
  grep -F '| `destructive-git-guard.md` |' "${PLUGIN_DIR}/../../rules/README.md" \
    | grep -F 'サブエージェント' | grep -F '確認画面を出さず' | grep -F '親に返る' \
    | grep -F '画面を見ている人のいないセッション' | grep -F 'チャンネル' | grep -qF '主に承認を求める'
}

# --- 親が書く許可（spec: 子への拒否を記録し、親が 1 回だけ通せるようにする／許可を書くスクリプトは
#     一時領域の中に収まるコマンドだけを許可する／子は許可を書くスクリプトを呼べない／許可を書いたこと・
#     使ったことを記録する） ---

PERMIT_SID="0a1b2c3d-sid1"

# scratch_dir <session_id> [一時フォルダ] — Claude Code の scratchpad と同じ形のディレクトリを作り、realpath を出す。
# claude-<uid> は一時フォルダの置き場所（既定は TMPDIR）の直下に置く（判定は置き場所も見る）
scratch_dir() {
  local d="${2:-$TMPDIR}/claude-$(id -u)/slug/$1/scratchpad"
  mkdir -p "$d"
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$d"
}

# mk_repo <dir> — <dir> に 1 コミットの git repo を作り、realpath を出す
mk_repo() {
  mkdir -p "$1"
  git -C "$1" init -q
  printf 'a\n' >|"$1/a"
  git -C "$1" add a
  git -C "$1" -c user.name=t -c user.email=t@t commit -qm init
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

# call_cwd <command> <agent_id(JSON か "-")> <session_id> <cwd> [permission_mode]
call_cwd() {
  local json
  json="$(printf '%s' "$1" | python3 -c '
import json, sys
p = {"tool_name": "Bash", "tool_input": {"command": sys.stdin.read()}, "hook_event_name": "PreToolUse",
     "permission_mode": sys.argv[4], "session_id": sys.argv[2], "cwd": sys.argv[3]}
if sys.argv[1] != "-":
    p["agent_id"] = json.loads(sys.argv[1])
print(json.dumps(p))' "$2" "$3" "$4" "${5:-default}")"
  run "$SCRIPT" <<<"$json"
}

GUARD_BASE() { printf '%s' "$TMPDIR/dev-workflow-git-guard"; }

# only_record — denied/ の記録が 1 つだけあることを確かめ、そのパスを出す
only_record() {
  local fs
  fs=("$(GUARD_BASE)"/denied/*.json)
  [ "${#fs[@]}" -eq 1 ] && [ -f "${fs[0]}" ] || { echo "records: ${fs[*]}" >&2; return 1; }
  printf '%s' "${fs[0]}"
}

# key_of <session_id> <agent_id> <cwd> <command> — hook と同じ規則の key
key_of() {
  printf '%s' "$4" | python3 -c '
import hashlib, sys
print(hashlib.sha256("\0".join([sys.argv[1], sys.argv[2], sys.argv[3], sys.stdin.read()]).encode()).hexdigest())' "$1" "$2" "$3"
}

# mk_record <base> <session_id> <agent_id> <cwd> <command> — 拒否の記録を hook を通さずに書き、パスを出す
# （hook が拒否しないコマンド、たとえば git init の記録を作るため）
mk_record() {
  local k
  k="$(key_of "$2" "$3" "$4" "$5")"
  mkdir -p "$1/denied"
  printf '%s' "$5" | python3 -c '
import json, sys
json.dump({"session_id": sys.argv[1], "agent_id": sys.argv[2], "cwd": sys.argv[3], "command": sys.stdin.read(),
           "kinds": ["test"], "time": 0}, open(sys.argv[4], "w"))' "$2" "$3" "$4" "$1/denied/$k.json"
  printf '%s' "$1/denied/$k.json"
}

permits_empty() {
  local d="${1:-$(GUARD_BASE)}/permits"
  [ ! -d "$d" ] || [ -z "$(ls -A "$d")" ] || { ls -la "$d"; return 1; }
}

# deny_then_permit <command> <cwd> — 子 a1 の拒否を作り、その記録で許可を書く
deny_then_permit() {
  call_cwd "$1" '"a1"' "$PERMIT_SID" "$2"
  [ "$(decision)" = "deny" ] || { echo "first call: $output"; return 1; }
  local rec
  rec="$(only_record)" || return 1
  run "$PERMIT" "$rec" "検証用 repo を戻すだけ"
  [ "$status" -eq 0 ] || { echo "permit failed: $output"; return 1; }
}

setup_permit() {
  PERMIT="${PLUGIN_DIR}/scripts/git-guard-permit.sh"
  SP="$(scratch_dir "$PERMIT_SID")"
  REPO="$(mk_repo "$SP/repo")"
  OUT="$(mk_repo "${BATS_TEST_TMPDIR}/outside/repo")"
}

@test "permit: a matching permit allows the call exactly once" {
  setup_permit
  deny_then_permit 'git checkout -- .' "$REPO"
  [[ "$output" == *"$SP"* ]] || { echo "no scratchpad in stdout: $output"; return 1; }
  [ "$(ls "$(GUARD_BASE)/permits" | wc -l | tr -d ' ')" = "1" ]
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "allow" ] || { echo "$output"; return 1; }
  [[ "$(reason)" == *'この 1 回だけ'* ]] || return 1
  ! has_continue || return 1
  permits_empty
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "deny" ]
}

@test "permit: the log has permit then use" {
  setup_permit
  deny_then_permit 'git checkout -- .' "$REPO"
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "allow" ]
  python3 - "$(GUARD_BASE)/permit-log.jsonl" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
ev = [r["event"] for r in rows]
assert ev == ["permit", "use"], ev
p = rows[0]
assert p["reason"] == "検証用 repo を戻すだけ", p
assert p["command"] == "git checkout -- .", p
for k in ("session_id", "agent_id", "cwd", "scratchpad", "repos", "expires_at"):
    assert k in p, (k, p)
PY
}

@test "permit: calls that do not match do not use the permit" {
  setup_permit
  deny_then_permit 'git checkout -- .' "$REPO"
  call_cwd 'git checkout -- . ' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "deny" ]
  call_cwd 'git checkout -- .' '"a2"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "deny" ]
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$SP"
  [ "$(decision)" = "deny" ]
  call_cwd 'git checkout -- .' '"a1"' 0a1b2c3d-sid9 "$REPO"
  [ "$(decision)" = "deny" ]
  # continue の有無は見ない（同じ子への拒否が続くので 2 件目以降は打ち切りになる）
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "allow" ]
}

@test "permit: an expired permit is not used and is removed" {
  setup_permit
  deny_then_permit 'git checkout -- .' "$REPO"
  local f
  f="$(ls "$(GUARD_BASE)"/permits/*.json)"
  python3 - "$f" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["expires_at"] = 1
json.dump(d, open(sys.argv[1], "w"))
PY
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "deny" ]
  permits_empty
  grep -qF '"expired"' "$(GUARD_BASE)/permit-log.jsonl"
}

@test "permit: the main session does not look at permits" {
  setup_permit
  deny_then_permit 'git checkout -- .' "$REPO"
  call_cwd 'git checkout -- .' - "$PERMIT_SID" "$REPO" default
  [ "$(decision)" = "ask" ]
  [ "$(ls "$(GUARD_BASE)/permits" | wc -l | tr -d ' ')" = "1" ]
}

@test "permit: in an unattended session the main call stays deny and the child still uses its permit" {
  setup_permit
  export DEV_WORKFLOW_UNATTENDED=1
  deny_then_permit 'git checkout -- .' "$REPO"
  call_cwd 'git checkout -- .' - "$PERMIT_SID" "$REPO" bypassPermissions
  [ "$(decision)" = "deny" ] || { echo "$output"; return 1; }
  [[ "$(reason)" == *'チャンネル'* ]] || return 1
  [ "$(ls "$(GUARD_BASE)/permits" | wc -l | tr -d ' ')" = "1" ]
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "allow" ] || { echo "$output"; return 1; }
  permits_empty
}

@test "permit: if .git is swapped to point outside after the permit, the hook denies" {
  setup_permit
  deny_then_permit 'git checkout -- .' "$REPO"
  rm -rf "$REPO/.git"
  ln -s "$OUT/.git" "$REPO/.git"
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" == *'許可はあるが行き先を確かめられない'* ]] || { reason; return 1; }
  permits_empty
  grep -qF '"rejected"' "$(GUARD_BASE)/permit-log.jsonl"
}

@test "permit: a permit written directly for an outside cwd is denied" {
  setup_permit
  local k now
  k="$(key_of "$PERMIT_SID" a1 "$OUT" 'git checkout -- .')"
  mkdir -p "$(GUARD_BASE)/permits"
  python3 - "$(GUARD_BASE)/permits/$k.json" "$PERMIT_SID" "$OUT" <<'PY'
import json, sys, time
json.dump({"session_id": sys.argv[2], "agent_id": "a1", "cwd": sys.argv[3], "command": "git checkout -- .",
           "created_at": int(time.time()), "expires_at": int(time.time()) + 600}, open(sys.argv[1], "w"))
PY
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$OUT"
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" == *'許可はあるが行き先を確かめられない'* ]] || { reason; return 1; }
  permits_empty
}

@test "permit: after a permit the next deny counts from one" {
  setup_permit
  deny_then_permit 'git checkout -- .' "$REPO"
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "allow" ]
  call_cwd 'git reset --hard' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "deny" ]
  ! has_continue || return 1
  [[ "$(reason)" != *直ちに作業を終えて親に返す* ]] || return 1
}

@test "permit: the deny record has the ids, cwd and the full command" {
  setup_permit
  call_cwd 'git checkout -- a' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "deny" ]
  local rec
  rec="$(only_record)"
  [[ "$(reason)" == *"$rec"* ]] || return 1
  [ "$(basename "$rec" .json)" = "$(key_of "$PERMIT_SID" a1 "$REPO" 'git checkout -- a')" ]
  python3 - "$rec" "$PERMIT_SID" "$REPO" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["session_id"] == sys.argv[2] and d["agent_id"] == "a1" and d["cwd"] == sys.argv[3], d
assert d["command"] == "git checkout -- a", d
assert d["kinds"] and "time" in d, d
PY
}

@test "permit: the script writes the permit next to the record, not under its own TMPDIR" {
  setup_permit
  # 親の TMPDIR（b）が hook の TMPDIR と違っても、hook の TMPDIR の下に書かれた記録の隣に許可を書き、hook が使える
  local rec b="${BATS_TEST_TMPDIR}/tmp-b"
  mkdir -p "$b"
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  rec="$(only_record)"
  run env TMPDIR="$b" "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(ls "$(GUARD_BASE)/permits" | wc -l | tr -d ' ')" = "1" ]
  [ ! -e "$b/dev-workflow-git-guard" ]
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "allow" ] || { echo "$output"; return 1; }
}

@test "permit: the script judges temp folders as the hook does, not by its own TMPDIR" {
  setup_permit
  # scratchpad が親の TMPDIR（b）の下にだけあると hook は scratchpad に数えないので、スクリプトも許可を書かない
  local rec b="${BATS_TEST_TMPDIR}/tmp-b" repo_b
  mkdir -p "$b"
  repo_b="$(mk_repo "$(scratch_dir "$PERMIT_SID" "$b")/repo")"
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$repo_b"
  rec="$(only_record)"
  run env TMPDIR="$b" "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -ne 0 ] || { echo "permitted: $output"; return 1; }
  permits_empty
}

@test "permit: the real scratchpad places /tmp and /private/tmp are temp folder candidates" {
  python3 -I - "$PLUGIN_DIR/scripts/git-guard-scratchpad.py" <<'PY'
import os, sys
ns = {}
exec(compile(open(sys.argv[1]).read(), sys.argv[1], "exec"), ns)
for kw in ({}, {"temp_dir": os.environ["TMPDIR"]}):
    r = ns["_temp_roots"](**kw)
    for c in ("/tmp", "/private/tmp"):
        assert os.path.realpath(c) in r, (kw, c, r)
    assert os.path.realpath(os.environ["TMPDIR"]) in r, (kw, r)
PY
}

# write_permit <cwd> <command> — スクリプトを使わずに、子 a1 の一致する許可を permits/ に直接書く
write_permit() {
  local k
  k="$(key_of "$PERMIT_SID" a1 "$1" "$2")"
  mkdir -p "$(GUARD_BASE)/permits"
  printf '%s' "$2" | python3 -c '
import json, sys, time
json.dump({"session_id": sys.argv[2], "agent_id": "a1", "cwd": sys.argv[3], "command": sys.stdin.read(),
           "created_at": int(time.time()), "expires_at": int(time.time()) + 600}, open(sys.argv[1], "w"))' \
    "$(GUARD_BASE)/permits/$k.json" "$PERMIT_SID" "$1"
}

@test "permit: a scratchpad-shaped folder outside the temp folders is not a scratchpad" {
  setup_permit
  # 作業ツリーの中などに同じ形のフォルダを作っても、claude-<uid> の親が一時フォルダの置き場所でなければ外
  local fake rec
  fake="$(mk_repo "${BATS_TEST_TMPDIR}/work/claude-$(id -u)/slug/$PERMIT_SID/scratchpad/repo")"
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$fake"
  [ "$(decision)" = "deny" ]
  rec="$(only_record)"
  run "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -ne 0 ] || { echo "$output"; return 1; }
  permits_empty
  # 直接書いた許可も hook は使わない
  write_permit "$fake" 'git checkout -- .'
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$fake"
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" == *'許可はあるが行き先を確かめられない'* ]] || { reason; return 1; }
  permits_empty
}

@test "permit: a claude-<uid> folder that others can write to is not a scratchpad" {
  setup_permit
  local rec
  chmod g+w "$TMPDIR/claude-$(id -u)"
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  rec="$(only_record)"
  run "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -ne 0 ] || { echo "$output"; return 1; }
  permits_empty
}

@test "permit: the script writes no permit when git or cd is redirected by the environment" {
  setup_permit
  local rec v
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  rec="$(only_record)"
  for v in "GIT_DIR=$OUT/.git" "GIT_WORK_TREE=$OUT" "GIT_COMMON_DIR=$OUT/.git" "GIT_INDEX_FILE=$OUT/.git/index" \
           "GIT_OBJECT_DIRECTORY=$OUT/.git/objects" "GIT_CONFIG_GLOBAL=$OUT/cfg" "GIT_CONFIG_COUNT=1" \
           "GIT_CEILING_DIRECTORIES=$SP" "GIT_DISCOVERY_ACROSS_FILESYSTEM=1" "CDPATH=$OUT"; do
    run env "$v" "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -eq 1 ] || { echo "$v: status=$status $output"; return 1; }
    [[ "$output" == *"${v%%=*}"* ]] || { echo "$v: $output"; return 1; }
    permits_empty
  done
}

@test "permit: the harmless GIT_CONFIG set Claude Code injects does not block the permit or its use" {
  setup_permit
  local rec
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "deny" ]
  rec="$(only_record)"
  run env GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=credential.interactive GIT_CONFIG_VALUE_0=false \
    GIT_CONFIG_KEY_1=credential.guiPrompt GIT_CONFIG_VALUE_1=false "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=credential.interactive GIT_CONFIG_VALUE_0=false \
    GIT_CONFIG_KEY_1=credential.guiPrompt GIT_CONFIG_VALUE_1=false
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  unset GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 GIT_CONFIG_KEY_1 GIT_CONFIG_VALUE_1
  [ "$(decision)" = "allow" ] || { echo "$output"; return 1; }
}

@test "permit: any other GIT_CONFIG key or a broken set still blocks the permit" {
  setup_permit
  local rec
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  rec="$(only_record)"
  local sets=(
    "GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=credential.interactive GIT_CONFIG_VALUE_0=false GIT_CONFIG_KEY_1=core.worktree GIT_CONFIG_VALUE_1=$OUT"
    "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=$OUT"
    "GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=credential.interactive GIT_CONFIG_VALUE_0=false"
    "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.interactive GIT_CONFIG_VALUE_0=false GIT_CONFIG_KEY_1=credential.guiPrompt GIT_CONFIG_VALUE_1=false"
    "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.interactive GIT_CONFIG_VALUE_0=false GIT_CONFIG_GLOBAL=$OUT/cfg"
    "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.interactive GIT_CONFIG_VALUE_0=false GIT_CONFIG_PARAMETERS='core.worktree=x'"
    "GIT_CONFIG_COUNT=abc GIT_CONFIG_KEY_0=credential.interactive GIT_CONFIG_VALUE_0=false"
    "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=Credential.Interactive GIT_CONFIG_VALUE_0=false"
    "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=credential.interactive"
  )
  local s
  for s in "${sets[@]}"; do
    eval "run env $s \"\$PERMIT\" \"\$rec\" 戻すだけ"
    [ "$status" -eq 1 ] || { echo "$s: status=$status $output"; return 1; }
    [[ "$output" == *GIT_CONFIG* ]] || { echo "$s: $output"; return 1; }
    permits_empty
  done
}

@test "permit: a complete harmless GIT_CONFIG set of 1000 pairs is accepted, and a huge COUNT without the pairs is refused fast" {
  setup_permit
  local rec i vars=()
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  rec="$(only_record)"
  vars=(GIT_CONFIG_COUNT=1000)
  for ((i = 0; i < 1000; i++)); do
    vars+=("GIT_CONFIG_KEY_$i=credential.interactive" "GIT_CONFIG_VALUE_$i=false")
  done
  run env "${vars[@]}" "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -eq 0 ] || { echo "$output" | cut -c1-300; return 1; }
  rm -f "$TMPDIR"/dev-workflow-git-guard/permits/*.json
  run env GIT_CONFIG_COUNT=999999999 GIT_CONFIG_KEY_0=credential.interactive GIT_CONFIG_VALUE_0=false "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  run env GIT_CONFIG_COUNT=99999999999999999999999 "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
  permits_empty
}

@test "child reason: names a way to get the parent's permit (real path, single command, no variable)" {
  call 'git checkout -- a' default '"a1"' s1
  [ "$(decision)" = "deny" ]
  local r
  r="$(reason)"
  [[ "$r" == *'実パスで単独のコマンド'* && "$r" == *'変数'* ]] || { echo "$r"; return 1; }
  [[ "$r" == *'打ち直さず'* ]] || return 1
}

@test "permit: the hook denies a permit when GIT_DIR points outside" {
  setup_permit
  deny_then_permit 'git checkout -- .' "$REPO"
  export GIT_DIR="$OUT/.git"
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  unset GIT_DIR
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" == *'許可はあるが行き先を確かめられない'* ]] || { reason; return 1; }
  permits_empty
}

@test "permit: other commands inside the scratchpad are permitted" {
  setup_permit
  local base rec cmd
  base="$(GUARD_BASE)"
  # cd で中に移る・-C を重ねる・scratchpad そのものが repo
  # git が 2 つ以上でも、-C を付けず作業ツリーの最上位で走らせる形は受け付ける
  for cmd in "cd ./repo && git reset --hard" "cd $REPO && cd .. && cd ./repo/. && git status" \
             "git -C repo -C . clean -fdx" "git -C $REPO checkout -- a" \
             "cd ./repo && git reset --hard && git clean -fdx"; do
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$SP" "$cmd")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -eq 0 ] || { echo "refused: $cmd: $output"; return 1; }
  done
  local sp2
  sp2="$(scratch_dir 0a1b2c3d-sid2)"
  mk_repo "$sp2" >/dev/null
  rec="$(mk_record "$base" 0a1b2c3d-sid2 a1 "$sp2" "git reset --hard")"
  run "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -eq 0 ] || { echo "refused scratchpad root: $output"; return 1; }
}

# mk_evil_repo <dir> — main で sub/f を追跡し、ブランチ evil では sub が $OUT への symlink になる repo を作る。
# 未追跡のディレクトリ build も置く（git clean -fdx で消える）。main を checkout した状態で返す
mk_evil_repo() {
  mk_repo "$1" >/dev/null
  mkdir -p "$1/sub" "$1/build"
  printf 'f\n' >|"$1/sub/f"
  git -C "$1" add sub/f
  git -C "$1" -c user.name=t -c user.email=t@t commit -qm sub
  git -C "$1" checkout -qb evil
  git -C "$1" rm -rq sub
  ln -s "$OUT" "$1/sub"
  git -C "$1" add sub
  git -C "$1" -c user.name=t -c user.email=t@t commit -qm evil
  git -C "$1" checkout -q -
}

# cd が失敗すると（実行権限の無いディレクトリなど）、; や改行の後ろの git は元の cwd（外の作業ツリー）で走る。
# cd を含むコマンドは区切りを && だけにする。スクリプトは許可を書かず、直接書いた許可も hook は使わない
@test "permit: a cd that may fail is refused unless every separator is &&" {
  setup_permit
  local base rec cmd st
  base="$(GUARD_BASE)"
  mkdir -p "$REPO/locked"
  chmod 000 "$REPO/locked"
  local -a cmds=("cd $REPO/locked ; git reset --hard" "cd $REPO/locked"$'\n'"git reset --hard")
  local -a bad=()
  for cmd in "${cmds[@]}"; do
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$OUT" "$cmd")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -ne 0 ] || bad+=("permitted: $cmd")
    permits_empty || bad+=("permit written: $cmd")
  done
  write_permit "$OUT" "cd $REPO/locked ; git reset --hard"
  call_cwd "cd $REPO/locked ; git reset --hard" '"a1"' "$PERMIT_SID" "$OUT"
  st="$(decision)"
  [[ "$(reason)" == *'許可はあるが行き先を確かめられない'* ]] || bad+=("reason: $(reason)")
  chmod 755 "$REPO/locked"
  [ "${#bad[@]}" -eq 0 ] || { printf '%s\n' "${bad[@]}"; return 1; }
  [ "$st" = "deny" ]
  permits_empty
}

@test "permit: the script refuses targets outside the scratchpad" {
  setup_permit
  local base rec cmd cwd
  base="$(GUARD_BASE)"
  # .git ファイルが外の git ディレクトリを指す repo
  mkdir -p "$SP/linked"
  printf 'gitdir: %s/.git\n' "$OUT" >|"$SP/linked/.git"
  # 共通の git ディレクトリの config に大文字混じりの worktree
  local cfg
  cfg="$(mk_repo "$SP/cfg")"
  printf '[Core]\n\tWorkTree = %s\n' "$OUT" >>"$cfg/.git/config"
  local inc
  inc="$(mk_repo "$SP/inc")"
  printf '[IncludeIf "gitdir:x"]\n\tpath = /x\n' >>"$inc/.git/config"
  # 別のセッションの scratchpad の repo
  local other
  other="$(mk_repo "$(scratch_dir 0a1b2c3d-other)/repo")"
  mk_evil_repo "$SP/evil"
  local -a cases=(
    "$OUT|git checkout -- ."
    "$REPO|cd $OUT && git reset --hard"
    "$REPO|git -C $OUT clean -fd"
    "$SP/linked|git checkout -- ."
    "$other|git reset --hard"
    "$cfg|git checkout -- ."
    "$inc|git checkout -- ."
    "$SP|git status"
    "$SP|cd repo"
    # 前の cd や git が失敗する・ファイルの配置を書き換えると行き先が変わるもの（記録の cwd は外の作業ツリー）
    "$OUT|git -C $SP/evil clean -fdx ; cd $SP/evil/build ; git reset --hard"
    "$OUT|cd $SP/evil && git checkout evil && cd ./sub && git reset --hard"
    "$OUT|git -C $SP/evil checkout evil && git -C $SP/evil/sub reset --hard"
    "$OUT|cd $SP/evil/sub && git checkout evil && git reset --hard"
    "$REPO|cd $REPO; git reset --hard"
    "$REPO|git status && cd $REPO && git reset --hard"
  )
  for c in "${cases[@]}"; do
    cwd="${c%%|*}"; cmd="${c#*|}"
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$cwd" "$cmd")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -ne 0 ] || { echo "permitted: $cwd | $cmd"; return 1; }
    permits_empty
  done
}

# git が受け入れない .git（中身の無いディレクトリ・CR 付きの commondir の先が git ディレクトリでないもの）は、
# git が上の階層へ探しに行くので拒む
@test "permit: the script refuses .git that git would not accept" {
  setup_permit
  local base rec r
  base="$(GUARD_BASE)"
  mkdir -p "$SP/empty/.git"
  r="$(mk_repo "$SP/cr")"
  printf '..\r\n' >|"$r/.git/commondir"
  local -a cases=("$SP/empty" "$r")
  for cwd in "${cases[@]}"; do
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$cwd" "git checkout -- .")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -ne 0 ] || { echo "permitted: $cwd"; return 1; }
    permits_empty
  done
}

# git は .git ファイルと commondir をファイル全体で読み、末尾の CR と LF だけを落とす。行の途中に改行が残ると、
# 判定が 1 行目で見た場所と git の使う場所が割れるので拒む。1 行だけのもの（CRLF を含む）は今までどおり通す
@test "permit: the script refuses .git files and commondir with more than one line" {
  setup_permit
  local base rec r
  base="$(GUARD_BASE)"
  local -a bad=() good=()
  r="$(mk_repo "$SP/gf2")"
  mv "$r/.git" "$r/realgit"
  printf 'gitdir: realgit\nextra\n' >|"$r/.git"
  bad+=("$r")
  r="$(mk_repo "$SP/gfcr")"
  mv "$r/.git" "$r/realgit"
  printf 'gitdir: realgit\rx\n' >|"$r/.git"
  bad+=("$r")
  r="$(mk_repo "$SP/cd2")"
  printf '.\nextra\n' >|"$r/.git/commondir"
  bad+=("$r")
  r="$(mk_repo "$SP/gf1")"
  mv "$r/.git" "$r/realgit"
  printf 'gitdir: realgit\r\n' >|"$r/.git"
  good+=("$r")
  r="$(mk_repo "$SP/cd1")"
  printf '.\n' >|"$r/.git/commondir"
  good+=("$r")
  local cwd
  for cwd in "${bad[@]}"; do
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$cwd" "git checkout -- .")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -ne 0 ] || { echo "permitted: $cwd"; return 1; }
    permits_empty
  done
  for cwd in "${good[@]}"; do
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$cwd" "git checkout -- .")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -eq 0 ] || { echo "refused: $cwd: $output"; return 1; }
  done
}

# git の is_git_directory は objects と refs に入れるか（実行権限）も見る。入れない git ディレクトリを git は飛ばし、
# 上の階層の repo を使う。判定も同じに拒み、作業ツリーより上の階層に別の .git や git ディレクトリがある形も拒む
@test "permit: the script refuses git directories git cannot enter and repos with another repo above" {
  setup_permit
  local base rec r n
  base="$(GUARD_BASE)"
  local -a bad=() locked=()
  for n in objects refs; do
    r="$(mk_repo "$SP/nox-$n")"
    chmod a-x "$r/.git/$n"
    locked+=("$r/.git/$n")
    bad+=("$r")
  done
  r="$(mk_repo "$SP/outer")"
  mk_repo "$r/inner" >/dev/null
  bad+=("$r/inner")
  local sp2
  sp2="$(scratch_dir 0a1b2c3d-above)"
  mk_repo "$sp2/repo" >/dev/null
  printf 'gitdir: %s\n' "$OUT/.git" >|"$(dirname "$sp2")/.git"
  local cwd
  for cwd in "${bad[@]}"; do
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$cwd" "git checkout -- .")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -ne 0 ] || { echo "permitted: $cwd"; chmod a+x "${locked[@]}"; return 1; }
    permits_empty || { chmod a+x "${locked[@]}"; return 1; }
  done
  chmod a+x "${locked[@]}"
  rec="$(mk_record "$base" 0a1b2c3d-above a1 "$sp2/repo" "git checkout -- .")"
  run "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -ne 0 ] || { echo "permitted with .git above the scratchpad"; return 1; }
  permits_empty
}

# git ディレクトリの中の symlink（refs・index・packed-refs・HEAD・objects・その下の refs/heads など）と、
# サブモジュール（.git/modules・.gitmodules・config の submodule の節）は、git が scratchpad の外を触りうるので拒む
@test "permit: the script refuses symlinks in the git directory and submodules" {
  setup_permit
  local base rec r n i=0
  base="$(GUARD_BASE)"
  git -C "$OUT" branch keepme
  local -a cwds=()
  for n in refs index packed-refs HEAD objects refs/heads logs; do
    i=$((i + 1))
    r="$(mk_repo "$SP/lnk$i")"
    git -C "$r" pack-refs --all
    rm -rf "${r:?}/.git/$n"
    ln -s "$OUT/.git/$n" "$r/.git/$n"
    cwds+=("$r|git branch -D keepme")
  done
  r="$(mk_repo "$SP/mod")"
  mkdir -p "$r/.git/modules"
  ln -s "$OUT/.git" "$r/.git/modules/sub"
  cwds+=("$r|git reset --hard --recurse-submodules")
  r="$(mk_repo "$SP/gm")"
  printf '[submodule "sub"]\n\tpath = sub\n\turl = %s\n' "$OUT" >|"$r/.gitmodules"
  cwds+=("$r|git reset --hard")
  r="$(mk_repo "$SP/subcfg")"
  printf '[Submodule "sub"]\n\tactive = true\n' >>"$r/.git/config"
  cwds+=("$r|git reset --hard")
  local c cwd cmd
  for c in "${cwds[@]}"; do
    cwd="${c%%|*}"; cmd="${c#*|}"
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$cwd" "$cmd")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -ne 0 ] || { echo "permitted: $cwd | $cmd"; return 1; }
    permits_empty
  done
  git -C "$OUT" rev-parse --verify -q refs/heads/keepme >/dev/null
}

@test "permit: the script refuses a bare git directory under a scratchpad repo" {
  setup_permit
  local sp2 base rec
  base="$(GUARD_BASE)"
  sp2="$(scratch_dir 0a1b2c3d-bare)"
  mk_repo "$sp2" >/dev/null
  # scratchpad の直下が repo で、その中に作業ツリーを外に向けた bare の git ディレクトリを置く
  git init -q --bare "$sp2/evil"
  printf '[core]\n\tbare = false\n' >>"$sp2/evil/config"
  rec="$(mk_record "$base" 0a1b2c3d-bare a1 "$sp2" "git -C evil checkout -- .")"
  run "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -ne 0 ] || { echo "permitted bare"; return 1; }
  permits_empty
}

@test "permit: the script refuses commands whose targets cannot be fixed" {
  setup_permit
  local base rec cmd
  base="$(GUARD_BASE)"
  local -a cmds=(
    'cd "$D" && git checkout -- .'
    'git reset --hard && rm -rf x'
    'git push --force origin main'
    'GIT_DIR=x git reset --hard'
    'git checkout -- . > out'
    'git init /x/outside'
    "git checkout -- .$(printf '\r')"
    'git -c core.worktree=/x checkout -- .'
    'git --git-dir=/x checkout -- .'
    'cd - && git reset --hard'
    'git reset --hard & git status'
    'git checkout -- *'
    'cd ~ && git reset --hard'
    'git reset --hard | cat'
  )
  for cmd in "${cmds[@]}"; do
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$REPO" "$cmd")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -ne 0 ] || { echo "permitted: $cmd"; return 1; }
    permits_empty
  done
}

# cd の移り先は / ・ ./ ・ ../ で始まるか . ・ .. だけ。シェルはそれ以外を、オプション（-P・--）・ディレクトリ
# スタック（+1・-1）・= 展開（zsh の =git）・CDPATH や zsh の cdpath の探索として読み、判定と別の所に移りうる
@test "permit: the script refuses cd targets the shell may read as options, stack entries or search paths" {
  setup_permit
  local base rec cmd n
  base="$(GUARD_BASE)"
  # 作業ツリー側（scratchpad の外）の cwd に、scratchpad の repo を指す紛らわしい名前のリンクを置く
  for n in -Z -P -L -- +1 -1 =git repo; do
    ln -s "$REPO" "$OUT/$n"
  done
  local -a cmds=(
    'cd -Z; git reset --hard'
    'cd -P && git status'
    'cd -L && git reset --hard'
    'cd -- && git reset --hard'
    'cd +1; git reset --hard'
    'cd -1; git reset --hard'
    'cd =git; git reset --hard'
    'cd repo && git reset --hard'
  )
  for cmd in "${cmds[@]}"; do
    rec="$(mk_record "$base" "$PERMIT_SID" a1 "$OUT" "$cmd")"
    run "$PERMIT" "$rec" "戻すだけ"
    [ "$status" -ne 0 ] || { echo "permitted: $cmd"; return 1; }
    [[ "$output" == *'./'* ]] || { echo "reason: $output"; return 1; }
    permits_empty
  done
  # 直書きの許可でも、使う時点の判定で通さない
  write_permit "$OUT" 'cd -Z; git reset --hard'
  call_cwd 'cd -Z; git reset --hard' '"a1"' "$PERMIT_SID" "$OUT"
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" == *'許可はあるが行き先を確かめられない'* ]] || { reason; return 1; }
  permits_empty
}

@test "permit: the script refuses records in the wrong place, rewritten, or without a reason" {
  setup_permit
  call_cwd 'git checkout -- .' '"a1"' "$PERMIT_SID" "$REPO"
  local rec k
  rec="$(only_record)"
  k="$(basename "$rec")"
  # denied/ の外に写したもの
  mkdir -p "${BATS_TEST_TMPDIR}/elsewhere/dev-workflow-git-guard/x"
  cp "$rec" "${BATS_TEST_TMPDIR}/elsewhere/dev-workflow-git-guard/x/$k"
  run "$PERMIT" "${BATS_TEST_TMPDIR}/elsewhere/dev-workflow-git-guard/x/$k" "戻すだけ"
  [ "$status" -ne 0 ]
  permits_empty "${BATS_TEST_TMPDIR}/elsewhere/dev-workflow-git-guard"
  # dev-workflow-git-guard でない名前の下の denied/
  mkdir -p "${BATS_TEST_TMPDIR}/other-name/denied"
  cp "$rec" "${BATS_TEST_TMPDIR}/other-name/denied/$k"
  run "$PERMIT" "${BATS_TEST_TMPDIR}/other-name/denied/$k" "戻すだけ"
  [ "$status" -ne 0 ]
  permits_empty "${BATS_TEST_TMPDIR}/other-name"
  # 理由が空
  run "$PERMIT" "$rec" ""
  [ "$status" -ne 0 ]
  permits_empty
  # 引数の数が違う
  run "$PERMIT" "$rec"
  [ "$status" -eq 2 ]
  # 中身のコマンドを書き換えたもの
  python3 - "$rec" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["command"] = "git checkout -- a"
json.dump(d, open(sys.argv[1], "w"))
PY
  run "$PERMIT" "$rec" "戻すだけ"
  [ "$status" -ne 0 ]
  permits_empty
}

@test "permit: a child calling the permit script is denied" {
  call 'git-guard-permit.sh /y/denied/k.json ok' default '"a1"' s1
  [ "$(decision)" = "deny" ]
  call '/x/scripts/git-guard-permit.sh /y/denied/k.json ok' default '"a1"' s1
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" != *git-guard-permit.sh* ]] || return 1
  [[ "$(reason)" == *許可を書くスクリプト* ]] || return 1
  local sh
  for sh in bash sh zsh dash ksh source .; do
    call "$sh /x/scripts/git-guard-permit.sh /y/denied/k.json ok" default '"a1"' s1
    [ "$(decision)" = "deny" ] || { echo "not denied: $sh"; return 1; }
  done
  # 値を取るオプション（-o・+o・-O・+O・--rcfile）・+ で始まるオプション・スクリプトより後ろの -c を取り違えない
  local c
  for c in 'bash -x /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'bash -o errexit /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'bash -eo pipefail /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'bash +x /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'bash +o posix /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'bash -O extglob /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'bash --rcfile /x/rc /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'bash -- /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'sh /x/scripts/git-guard-permit.sh /y/denied/k.json -c' \
           'bash /x/scripts/git-guard-permit.sh /y/denied/k.json -fcleanup'; do
    call "$c" default '"a1"' s1
    [ "$(decision)" = "deny" ] || { echo "not denied: $c"; return 1; }
  done
  # オプションの読み方に頼らない: 起動オプションの値（--rcfile・--init-file）としてのスクリプト、zsh の値を取らない
  # -O・値をつなげた -o の後ろのスクリプト、BASH_ENV= / ENV= の代入（前置き・env・export）も拾う
  for c in 'bash --rcfile /x/scripts/git-guard-permit.sh -i' \
           'bash --init-file /x/scripts/git-guard-permit.sh -i -c true' \
           'zsh -O /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'zsh -oerrexit /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'zsh -ocshnullglob /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'BASH_ENV=/x/scripts/git-guard-permit.sh bash -c true' \
           'ENV=/x/scripts/git-guard-permit.sh sh -i' \
           'env BASH_ENV=/x/scripts/git-guard-permit.sh bash /x/y.sh' \
           'export BASH_ENV=/x/scripts/git-guard-permit.sh; bash /x/y.sh'; do
    call "$c" default '"a1"' s1
    [ "$(decision)" = "deny" ] || { echo "not denied: $c"; return 1; }
  done
  # 書き方を読み分けない: コマンド文字列のどこかに名前があれば、-c の文字列の中・配列や += の代入・
  # declare / typeset / printf -v / read 経由の設定・読むだけの cat も止める
  for c in "bash -c '/x/scripts/git-guard-permit.sh /y/denied/k.json ok'" \
           'bash -c "echo /x/scripts/git-guard-permit.sh"' \
           'BASH_ENV[0]=/x/scripts/git-guard-permit.sh bash /x/y.sh' \
           'BASH_ENV+=/x/scripts/git-guard-permit.sh bash /x/y.sh' \
           'declare -x BASH_ENV=/x/scripts/git-guard-permit.sh; bash /x/y.sh' \
           'typeset -x ENV=/x/scripts/git-guard-permit.sh; sh -i' \
           'printf -v BASH_ENV %s /x/scripts/git-guard-permit.sh; export BASH_ENV; bash /x/y.sh' \
           'read BASH_ENV <<< /x/scripts/git-guard-permit.sh; export BASH_ENV; bash /x/y.sh' \
           'cat /x/scripts/git-guard-permit.sh'; do
    call "$c" default '"a1"' s1
    [ "$(decision)" = "deny" ] || { echo "not denied: $c"; return 1; }
  done
}

@test "permit: the main session is not stopped for any mention of the permit script" {
  local c
  for c in '/x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'bash /x/scripts/git-guard-permit.sh /y/denied/k.json ok' \
           'BASH_ENV=/x/scripts/git-guard-permit.sh bash -c true' \
           'cat /x/scripts/git-guard-permit.sh'; do
    call "$c" default
    [ "$status" -eq 0 ] || { echo "status: $c"; return 1; }
    [ -z "$output" ] || { echo "output for $c: $output"; return 1; }
  done
}

@test "permit: a self-permit call does not use a permit" {
  setup_permit
  local cmd="$PERMIT /y/denied/k.json ok"
  local k
  k="$(key_of "$PERMIT_SID" a1 "$REPO" "$cmd")"
  mkdir -p "$(GUARD_BASE)/permits"
  python3 - "$(GUARD_BASE)/permits/$k.json" "$PERMIT_SID" "$REPO" "$cmd" <<'PY'
import json, sys, time
json.dump({"session_id": sys.argv[2], "agent_id": "a1", "cwd": sys.argv[3], "command": sys.argv[4],
           "expires_at": int(time.time()) + 600}, open(sys.argv[1], "w"))
PY
  call_cwd "$cmd" '"a1"' "$PERMIT_SID" "$REPO"
  [ "$(decision)" = "deny" ]
  # 許可は使われずに残る（使ったうえで使う時点の判定で拒否された、ではない）
  [ -f "$(GUARD_BASE)/permits/$k.json" ]
}

@test "permit: without the shared file the hook still denies and writes no record" {
  local d="${BATS_TEST_TMPDIR}/lonely"
  mkdir -p "$d"
  cp "$SCRIPT" "$d/git-destructive-guard.sh"
  local json
  json="$(payload 'git checkout -- a' default '"a1"' s1)"
  # 一致する許可を置いても、key を出せないので探さない（許可は残り、期限で切れる）
  local k
  k="$(key_of s1 a1 "" 'git checkout -- a')"
  mkdir -p "$(GUARD_BASE)/permits"
  printf '{}' >|"$(GUARD_BASE)/permits/$k.json"
  run "$d/git-destructive-guard.sh" <<<"$json"
  [ "$(decision)" = "deny" ]
  [[ "$(reason)" != *'許可はあるが行き先を確かめられない'* ]] || return 1
  [ ! -e "$(GUARD_BASE)/denied" ]
  [ -f "$(GUARD_BASE)/permits/$k.json" ]
}
