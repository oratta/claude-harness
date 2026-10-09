#!/usr/bin/env bats
#
# hook スクリプトが python3 を呼ぶ形の検査（issue #869）。
#
# #869: Python 本体を fd 3 のヒアドキュメントに付けて /dev/fd/3 として python3 に読ませる形は、Python 3.9
#       （macOS 標準の /usr/bin/python3 は 3.9.6）で複数行の本体が実行されず rc=0・無出力で終わる。hook は
#       何も判定しないまま通す。本体は変数に読んで `python3 -I -c` で渡す。
#
# 3.9 が無い環境でも検査が空にならないよう、版に依らない検査（/dev/fd を使っていないこと・python3 に
# 渡る引数の形・本体の大きさ）を常に走らせ、3.9 での実行だけを 3.9 がある環境に限る。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SCRIPTS="${PLUGIN_DIR}/scripts"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "${WORK}/home" "${WORK}/shim"
  # 実環境の ~/.claude と実行中セッションのアカウントを読ませない
  export HOME="${WORK}/home"
  export USAGE_SNAPSHOT="${WORK}/none.json"
  export CLAUDE_ACCOUNTS_FILE="${WORK}/accounts.json"
  export USAGE_SESSIONS_DIR="${WORK}/.usage-sessions"
  export USAGE_PROBE_STATE="${WORK}/.usage-probe-state"
  export USAGE_PROBE_LOCK="${WORK}/.usage-probe.lock"
  unset CLAUDE_SECURESTORAGE_CONFIG_DIR DEV_WORKFLOW_GIT_GUARD DEV_WORKFLOW_GIT_GUARD_FORCE \
    DEV_WORKFLOW_MODEL_GUARD DEV_WORKFLOW_CONTEXT_TRIPWIRE || true
  GIT_PAYLOAD='{"tool_name":"Bash","tool_input":{"command":"git reset --hard"},"hook_event_name":"PreToolUse","permission_mode":"default"}'
  AGENT_PAYLOAD='{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}'
}

# Python 本体を -c で渡す 5 本と、python3 の起動まで進む最小の payload
BODY_HOOKS="git-destructive-guard agent-model-guard context-tripwire subagent-stop-guard model-switch-recache-notice"

payload_for() {
  case "$1" in
    git-destructive-guard) printf '%s' "$GIT_PAYLOAD" ;;
    agent-model-guard) printf '%s' "$AGENT_PAYLOAD" ;;
    context-tripwire) printf '%s' '{"agent_id":"x","hook_event_name":"PostToolUse"}' ;;
    subagent-stop-guard) printf '%s' '{"agent_id":"x","hook_event_name":"SubagentStop"}' ;;
    model-switch-recache-notice) printf '%s' '{"hook_event_name":"PreModelSwitch"}' ;;
  esac
}

# python39 — Python 3.9 の実行ファイルのパスを出す（無ければ何も出さない）
python39() {
  local c p
  for c in /usr/bin/python3 python3.9 python3; do
    p="$(command -v "$c" 2>/dev/null)" || continue
    [ -n "$p" ] || continue
    if [ "$("$p" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)" = "3.9" ]; then
      printf '%s' "$p"
      return 0
    fi
  done
  return 0
}

# install_shim <実体の python3> — 引数の数と各引数を控えてから実体を起動する python3 を PATH の先頭に置く
install_shim() {
  cat >|"${WORK}/shim/python3" <<SH
#!/bin/bash
printf '%s' "\$#" >|"${WORK}/argc"
printf '%s' "\${1-}" >|"${WORK}/arg1"
printf '%s' "\${2-}" >|"${WORK}/arg2"
printf '%s' "\${3-}" >|"${WORK}/arg3"
exec "$1" "\$@"
SH
  chmod +x "${WORK}/shim/python3"
}

@test "#869: no hook script feeds a Python body to python3 through /dev/fd" {
  cd "$ROOT"
  run bash -c 'git ls-files "plugins/*/scripts/*.sh" "plugins/*/hooks/*.sh" "scripts/*.sh" \
    | xargs grep -nE "^[^#]*python3[^#|;]*/dev/fd/"'
  echo "$output"
  [ -z "$output" ]
}

@test "#869: the five hooks hand python3 a non-empty body as -I -c <body>" {
  local real h first
  real="$(command -v python3)"
  install_shim "$real"
  for h in $BODY_HOOKS; do
    rm -f "${WORK}/argc" "${WORK}/arg1" "${WORK}/arg2" "${WORK}/arg3"
    payload_for "$h" | PATH="${WORK}/shim:${PATH}" /bin/bash "${SCRIPTS}/${h}.sh" >/dev/null 2>&1 || true
    [ -f "${WORK}/argc" ] || { echo "$h: python3 was not started"; return 1; }
    [ "$(cat "${WORK}/argc")" = 3 ] || { echo "$h: argc=$(cat "${WORK}/argc")"; return 1; }
    [ "$(cat "${WORK}/arg1")" = "-I" ] || { echo "$h: arg1=$(cat "${WORK}/arg1")"; return 1; }
    [ "$(cat "${WORK}/arg2")" = "-c" ] || { echo "$h: arg2=$(cat "${WORK}/arg2")"; return 1; }
    # 本体は、スクリプトのヒアドキュメントの 1 行目（import 文）から始まる
    first="$(head -n 1 "${WORK}/arg3")"
    [ "${first#import }" != "$first" ] || { echo "$h: body starts with [$first]"; return 1; }
    # スクリプトに書いたヒアドキュメントの本文と 1 バイトも違わない（多バイト文字を含む本文を read が欠かさない）
    awk '/<<.PY. \|\| true$/{f=1;next} /^PY$/{f=0} f' "${SCRIPTS}/${h}.sh" >|"${WORK}/expected"
    cmp "${WORK}/expected" "${WORK}/arg3" || { echo "$h: body differs from the heredoc"; return 1; }
    # Linux は引数 1 つの長さに上限（128 KiB）がある。本体がそれに近づいたら渡し方を見直す
    [ "$(wc -c <"${WORK}/arg3")" -lt 100000 ] || { echo "$h: body is too large for one argument"; return 1; }
  done
}

@test "#869: the bodies of the five hooks compile on Python 3.9" {
  local py h
  py="$(python39)"
  [ -n "$py" ] || skip "Python 3.9 が無い（/usr/bin/python3・python3.9・python3 のどれも 3.9 でない）"
  for h in $BODY_HOOKS; do
    awk '/<<.PY. \|\| true$/{f=1;next} /^PY$/{f=0} f' "${SCRIPTS}/${h}.sh" >|"${WORK}/body.py"
    [ -s "${WORK}/body.py" ] || { echo "$h: empty body"; return 1; }
    "$py" -I -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' \
      "${WORK}/body.py" || { echo "$h: does not compile on 3.9"; return 1; }
  done
}

@test "#869: git-destructive-guard asks for git reset --hard when python3 is Python 3.9" {
  local py
  py="$(python39)"
  [ -n "$py" ] || skip "Python 3.9 が無い（/usr/bin/python3・python3.9・python3 のどれも 3.9 でない）"
  ln -s "$py" "${WORK}/shim/python3"
  run env PATH="${WORK}/shim:/usr/bin:/bin" /bin/bash "${SCRIPTS}/git-destructive-guard.sh" <<<"$GIT_PAYLOAD"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"permissionDecision": "ask"'
  echo "$output" | grep -q 'git reset --hard'
}

@test "#869: agent-model-guard denies a model-less Agent call when python3 is Python 3.9" {
  local py
  py="$(python39)"
  [ -n "$py" ] || skip "Python 3.9 が無い（/usr/bin/python3・python3.9・python3 のどれも 3.9 でない）"
  ln -s "$py" "${WORK}/shim/python3"
  run env PATH="${WORK}/shim:/usr/bin:/bin" /bin/bash "${SCRIPTS}/agent-model-guard.sh" <<<"$AGENT_PAYLOAD"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"permissionDecision": "deny"'
}

@test "#869: the same payload gives the same output on Python 3.9 and on the default python3" {
  local py h
  py="$(python39)"
  [ -n "$py" ] || skip "Python 3.9 が無い（/usr/bin/python3・python3.9・python3 のどれも 3.9 でない）"
  mkdir -p "${WORK}/bin39"
  ln -s "$py" "${WORK}/bin39/python3"
  for h in git-destructive-guard agent-model-guard; do
    payload_for "$h" | PATH="${WORK}/bin39:${PATH}" /bin/bash "${SCRIPTS}/${h}.sh" >|"${WORK}/out39" 2>&1
    payload_for "$h" | /bin/bash "${SCRIPTS}/${h}.sh" >|"${WORK}/outdef" 2>&1
    [ -s "${WORK}/out39" ] || { echo "$h: no output on 3.9"; return 1; }
    cmp "${WORK}/out39" "${WORK}/outdef" || { echo "$h: output differs between 3.9 and the default"; return 1; }
  done
}

# body_less_copy <hook> <empty|unreadable> — 本体を読めなかった場合を再現する複製を作り、そのパスを出す。
#   empty:      ヒアドキュメントの中身を空にする（read は成功するが変数が空）
#   unreadable: ヒアドキュメントを、存在しないファイルからのリダイレクトに置き換える（リダイレクト自体が失敗し、
#               read が実行されない。ヒアドキュメントの一時ファイルを作れないときと同じ経路）
body_less_copy() {
  local dst="${WORK}/$1.$2.sh"
  mkdir -p "${WORK}/no-such-dir-parent"
  if [ "$2" = empty ]; then
    awk '/<<.PY. \|\| true$/{print;f=1;next} /^PY$/{f=0} !f' "${SCRIPTS}/$1.sh" >|"$dst"
  else
    awk -v src="${WORK}/no-such-dir-parent/missing/body" \
      '/<<.PY. \|\| true$/{sub(/<<.PY. \|\| true$/, "<\"" src "\" || true");print;f=1;next} /^PY$/{f=0;next} !f' \
      "${SCRIPTS}/$1.sh" >|"$dst"
  fi
  grep -q 'PY_SRC' "$dst" || return 1
  printf '%s' "$dst"
}

@test "#869: model-switch-recache-notice stays silent with exit 0 when its body is empty or unreadable" {
  local mode copy
  for mode in empty unreadable; do
    copy="$(body_less_copy model-switch-recache-notice "$mode")"
    run /bin/bash "$copy" <<<"$(payload_for model-switch-recache-notice)"
    [ "$status" -eq 0 ] || { echo "$mode: status=$status"; return 1; }
    [ -z "$output" ] || { echo "$mode: output=$output"; return 1; }
  done
}

@test "#869: the four judging hooks report an empty or unreadable body on stderr and exit 1 without a verdict" {
  local h mode copy rc
  for h in git-destructive-guard agent-model-guard context-tripwire subagent-stop-guard; do
    for mode in empty unreadable; do
      copy="$(body_less_copy "$h" "$mode")"
      rc=0
      payload_for "$h" | /bin/bash "$copy" >|"${WORK}/stdout" 2>|"${WORK}/stderr" || rc=$?
      [ "$rc" -eq 1 ] || { echo "$h $mode: exit=$rc"; return 1; }
      [ ! -s "${WORK}/stdout" ] || { echo "$h $mode: stdout is not empty"; return 1; }
      grep -q "^${h}: 判定の本体を読めなかったため、判定していない\$" "${WORK}/stderr" \
        || { echo "$h $mode: message missing"; cat "${WORK}/stderr"; return 1; }
      grep -q 'unbound variable' "${WORK}/stderr" && { echo "$h $mode: unbound variable"; return 1; }
    done
  done
  return 0
}
