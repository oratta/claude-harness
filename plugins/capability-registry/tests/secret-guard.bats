#!/usr/bin/env bats
#
# capability-registry-secret-guard: シークレットが transcript に出る形を止める PreToolUse hook
#
# spec: capability-registry-secret-guard
#
# 守備範囲の正本は spec の要件「検査の守備範囲」。ここで固定するのは、止める形・止めない形・
# 守備範囲の外の形・既知の止めすぎ・壊れたときの素通り・無効化・固有記述の不在で、判定の改善はしない。
# spec の次の 2 シナリオは実機の確認が要るので、ここでは固定しない。「settings.json に配線が無い環境で止まる」は
# PR の検証ログの claude -p の確認、「手で配線した hook と同時に走っても壊れない」は PR の動作確認ポイントで見る。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/secret-guard.sh"
  BODY="${PLUGIN_DIR}/scripts/secret-guard.py"
  WORK="$(mktemp -d)"
  unset CAPABILITY_REGISTRY_SECRET_GUARD
}

teardown() {
  rm -rf "$WORK"
}

# payload <Bash|Read|ツール名> <コマンドかパス> — hook の stdin に渡す JSON を出す
payload() {
  python3 -I -c '
import json, sys
key = {"Read": "file_path", "Grep": "pattern"}.get(sys.argv[1], "command")
print(json.dumps({"tool_name": sys.argv[1], "tool_input": {key: sys.argv[2]}}))
' "$1" "$2"
}

# run_guard <ツール名> <コマンドかパス> — hook を実行し、stdout を output に、stderr を ${WORK}/stderr に残す
run_guard() {
  payload "$1" "$2" >"${WORK}/payload.json"
  run bash -c "'$SCRIPT' <'${WORK}/payload.json' 2>'${WORK}/stderr'"
}

# assert_denied <ツール名> <コマンドかパス>
assert_denied() {
  run_guard "$1" "$2"
  [ "$status" -eq 0 ] || { echo "status=$status: $2"; return 1; }
  python3 -I - "$output" <<'PY' || { echo "deny にならない: $2 / 出力: $output"; return 1; }
import json, sys
h = json.loads(sys.argv[1])["hookSpecificOutput"]
assert h["hookEventName"] == "PreToolUse"
assert h["permissionDecision"] == "deny"
assert "[secret-guard]" in h["permissionDecisionReason"]
PY
}

# assert_passed <ツール名> <コマンドかパス>
assert_passed() {
  run_guard "$1" "$2"
  [ "$status" -eq 0 ] || { echo "status=$status: $2"; return 1; }
  [ -z "$output" ] || { echo "何か出力した: $2 / 出力: $output"; return 1; }
  [ ! -s "${WORK}/stderr" ] || { echo "検査が落ちて素通りした: $2"; cat "${WORK}/stderr"; return 1; }
}

# deny_reason <ツール名> <コマンドかパス> — 拒否の理由の本文を output に入れる
deny_reason() {
  run_guard "$1" "$2"
  [ "$status" -eq 0 ] || return 1
  run python3 -I -c 'import json, sys; print(json.loads(sys.argv[1])["hookSpecificOutput"]["permissionDecisionReason"])' "$output"
  [ "$status" -eq 0 ]
}

@test "hooks.json: secret-guard is wired to Bash and Read only, quoted under CLAUDE_PLUGIN_ROOT" {
  run python3 -I - "$HOOKS_JSON" <<'PY'
import json, re, sys
entries = json.load(open(sys.argv[1], encoding="utf-8"))["hooks"]["PreToolUse"]
found = [e for e in entries if any("secret-guard" in h["command"] for h in e["hooks"])]
assert len(found) == 1, found
e = found[0]
assert re.fullmatch(e["matcher"], "Bash"), e["matcher"]
assert re.fullmatch(e["matcher"], "Read"), e["matcher"]
assert not re.fullmatch(e["matcher"], "Grep"), e["matcher"]
assert not re.fullmatch(e["matcher"], "mcp__claude-in-chrome__navigate"), e["matcher"]
assert e["matcher"] == "Bash|Read", e["matcher"]
h = e["hooks"][0]
assert h["type"] == "command"
assert h["command"] == '"${CLAUDE_PLUGIN_ROOT}/scripts/secret-guard.sh"', h["command"]
assert h["timeout"] == 10
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "hooks.json: browser-guard stays first and unchanged" {
  run python3 -I - "$HOOKS_JSON" <<'PY'
import json, sys
first = json.load(open(sys.argv[1], encoding="utf-8"))["hooks"]["PreToolUse"][0]
assert first["matcher"] == "mcp__claude-in-chrome__.*|mcp__playwright__.*", first
assert first["hooks"] == [{"type": "command", "command": '"${CLAUDE_PLUGIN_ROOT}/scripts/browser-guard.sh"'}], first
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "script: finds the body when started by file name alone" {
  payload Read /x/.env >"${WORK}/payload.json"
  run bash -c "cd '${PLUGIN_DIR}/scripts' && bash secret-guard.sh <'${WORK}/payload.json'"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]] || return 1
}

@test "deny: Bash forms that put a secret value on screen" {
  local c
  while IFS= read -r c; do
    assert_denied Bash "$c"
  done <<'EOF'
echo "$GH_TOKEN"
printf %s ${MY_API_KEY}
printenv
printenv | wc -l
env
cat .env
cat ~/.npmrc
op read op://v/i/f
op item get x --fields password
op item get x --reveal
security find-generic-password -s x -w
security find-generic-password -s x -g
security find-internet-password -s x -w
EOF
}

@test "deny: Read of a secret file" {
  assert_denied Read /x/.env
  assert_denied Read /x/.env.local
}

@test "pass: command substitution into a variable" {
  assert_passed Bash 'GH_TOKEN="$(get-token github)" gh api /user'
  assert_passed Bash 'GH_TOKEN="$(op read op://v/i/f)" gh api /user'
  # && で区分が割れて op read が先頭になる形。コマンド置換の中という判定はこの入力でだけ通る
  assert_passed Bash 'TOKEN="$(cd /tmp && op read op://v/i/f)" gh api /user'
}

@test "pass: checks that do not print the value, and template files" {
  local c
  while IFS= read -r c; do
    assert_passed Bash "$c"
  done <<'EOF'
echo "${GH_TOKEN:+SET}"
echo "${#GH_TOKEN}"
cat .env.example
env FOO=1 ls
echo "--- .env:"
echo hi > .env
cat notes > .env
[ "$CAPABILITY_REGISTRY_SECRET_GUARD" = off ] && echo disabled
ls
EOF
  assert_passed Read /x/.env.example
  assert_passed Read /x/README.md
}

@test "pass: the personal-tool check is not carried over" {
  assert_passed Bash "fmt""oken.sh github"
}

@test "scope: inputs outside the scope pass" {
  assert_passed Bash 'ssh host cat .env'
  assert_passed Bash 'bash show.sh'
  assert_passed Bash 'echo "$MY_VALUE"'
  assert_passed Bash 'cat "$F"'
  assert_passed Grep '.env'
  assert_passed Read /x/config/credentials/production.key
  assert_passed Read /x/service-account/prod.json
}

@test "read: only the file name decides, a parent directory name does not" {
  assert_passed Read /x/credentials-service/src/index.ts
  assert_passed Read /x/.env/lib/site.py
  assert_denied Read /x/.env
  assert_denied Read /x/credentials.json
  assert_denied Read /x/a.token
  assert_denied Read /x/.env/
  assert_denied Read /x/credentials.json/
  assert_denied Read /x/foo.template/.env
}

@test "read: the path is normalized lexically before the file name is taken" {
  assert_denied Read /x/.env/.
  assert_denied Read /x/.env/./
  assert_denied Read /x/.env/foo/..
  assert_denied Read /x/credentials.json/.
  assert_denied Read /x/a.token/foo/..
  assert_denied Read /x/ok/../.env
  assert_passed Read /x/.env/../site.py
  assert_passed Read /
  assert_passed Read ''
}

@test "scope: the known over-blocking stays as it was" {
  assert_denied Bash 'cat <<EOF
echo "$GH_TOKEN"
EOF'
  assert_denied Read /x/credentials.ts
  assert_denied Read /x/docs/credential-guide.md
  assert_denied Read /x/process.env.ts
}

@test "fail-open: unreadable stdin passes" {
  run bash -c "'$SCRIPT' </dev/null 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run bash -c "printf 'not json' | '$SCRIPT' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fail-open: no python3 on PATH passes" {
  mkdir "${WORK}/empty"
  payload Bash 'echo "$GH_TOKEN"' >"${WORK}/payload.json"
  run bash -c "PATH='${WORK}/empty' /bin/bash '$SCRIPT' <'${WORK}/payload.json' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fail-open: a missing body never exits 2 (exit 2 would block the tool call)" {
  mkdir "${WORK}/copy"
  cp "$SCRIPT" "${WORK}/copy/secret-guard.sh"
  payload Bash 'echo "$GH_TOKEN"' >"${WORK}/payload.json"
  run bash -c "'${WORK}/copy/secret-guard.sh' <'${WORK}/payload.json' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fail-open: a crash inside the check passes and reports on stderr" {
  # tool_input が文字列だと ti.get で例外になる
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":\"x\"}' | '$SCRIPT' 2>'${WORK}/err'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -s "${WORK}/err" ]
}

@test "switch: off in the hook process environment skips the check" {
  export CAPABILITY_REGISTRY_SECRET_GUARD=off
  assert_passed Bash 'echo "$GH_TOKEN"'
  assert_passed Read /x/credentials.ts
}

@test "switch: unset or any other value keeps the check on" {
  assert_denied Bash 'echo "$GH_TOKEN"'
  export CAPABILITY_REGISTRY_SECRET_GUARD=on
  assert_denied Bash 'echo "$GH_TOKEN"'
}

@test "switch: a prefix inside the command does not disable the check" {
  assert_denied Bash 'CAPABILITY_REGISTRY_SECRET_GUARD=off echo "$GH_TOKEN"'
}

@test "personal terms: absent from the script bodies" {
  run grep -n -i -E 'fmt''oken|op-sa' "$SCRIPT" "$BODY"
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}

@test "deny reason: fixed guidance names no personal tool and shows the alternatives" {
  deny_reason Bash 'echo "$GH_TOKEN"'
  [[ "$output" != *"fmt""oken"* ]] || return 1
  [[ "$output" != *"op-sa"* ]] || return 1
  [[ "$output" == *'VAR="$('* ]] || return 1
  [[ "$output" == *'${VAR:+SET}'* ]] || return 1
}

@test "deny reason: quotes the input path, and the fixed guidance stays free of it" {
  deny_reason Read /x/op-sa/a.token
  [[ "$output" == *"/x/op-sa/a.token"* ]] || return 1
  local rest="${output//\/x\/op-sa\/a.token/}"
  [[ "$rest" != *"op-sa"* ]] || return 1
}

@test "deny reason: a Read names the switch, and the env reason asserts nothing about the environment" {
  deny_reason Read /x/credentials.ts
  [[ "$output" == *"CAPABILITY_REGISTRY_SECRET_GUARD=off"* ]] || return 1
  deny_reason Bash env
  [[ "$output" != *"トークンが env に入っています"* ]] || return 1
}

@test "docs: injection.md points to the plugin hook" {
  local doc="${REPO_ROOT}/plugins/casting/catalog/injection.md"
  run grep -n -F 'secret-guard' "$doc"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ] || return 1
  local line
  for line in "${lines[@]}"; do
    [[ "$line" == *"plugins/capability-registry/"* ]] || return 1
  done
  [[ "$output" != *"~/.claude/hooks/secret-guard.py"* ]] || return 1
  [[ "$output" != *"settings.json"* ]] || return 1
}

@test "docs: README says capability-registry brings the guard" {
  run grep -n -F 'capability-registry' "${REPO_ROOT}/README.md"
  [[ "$output" == *"secret-guard"* ]] || return 1
}

@test "docs: the change record says how and when to remove a hand-wired hook" {
  local rec="${PLUGIN_DIR}/changes/1233.md"
  grep -q -F '`PreToolUse` から secret-guard のエントリを外し' "$rec"
  grep -q -F '代替の検査' "$rec"
  grep -q -F '本人の判断' "$rec"
  grep -q -F '動作確認' "$rec"
  # 手の配線が残ったセッションでは、止まってもプラグインの hook の確認にならない
  grep -q -F -- '--setting-sources project' "$rec"
}
