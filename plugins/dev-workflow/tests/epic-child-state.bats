#!/usr/bin/env bats
# Child turn hooks: real git, isolated HOME/state/transcript; no terminal operations.
setup() {
  PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK="$PLUGIN_DIR/scripts/epic-child-state.sh"
  export HOME="$BATS_TEST_TMPDIR/home" EPIC_STATE_ROOT="$BATS_TEST_TMPDIR/state" EPIC_STATE_LOCK_TIMEOUT=0
  unset DEV_WORKFLOW_OWNER_NUMBER_CHECK
  mkdir -p "$HOME" "$EPIC_STATE_ROOT/o.r-1" "$BATS_TEST_TMPDIR/work"
  git init -q "$BATS_TEST_TMPDIR/work"
  WORK="$(cd "$BATS_TEST_TMPDIR/work" && pwd -P)"
  REC="$EPIC_STATE_ROOT/o.r-1/o.r-2.json"
  LOG="$BATS_TEST_TMPDIR/chat.jsonl"
  SID=s1
  source "$PLUGIN_DIR/scripts/epic-state.sh"
  es_new_record o/r 1 o/r 2 orca /parent "$WORK" child main running stopped > "$REC"
  jq '.opaque = {keep: true} | .stop_uuid = "parent-uuid" | .session = "terminal"' "$REC" > "$REC.tmp"
  mv "$REC.tmp" "$REC"
}
payload() {
  jq -cn --arg e "$1" --arg p "$2" --arg s "$SID" --arg w "$WORK" --arg l "$LOG" \
    '{hook_event_name:$e, prompt:$p, last_assistant_message:$p, session_id:$s,cwd:$w,transcript_path:$l,stop_hook_active:false}'
}
input() { payload UserPromptSubmit "$1" | "$HOOK"; }
register() { input '/develop #2 （エピック #1 の子。親ワークツリー /parent から Orca で起動）'; }
snapshot() {
  cp "$REC" "$BATS_TEST_TMPDIR/before.json"
  STAMP="$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$REC")"
}
unchanged() {
  cmp "$REC" "$BATS_TEST_TMPDIR/before.json"
  [ "$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$REC")" = "$STAMP" ]
}
append_row() {
  jq -cn --arg t "$1" --arg s "$SID" --arg text "$2" \
    '{type:$t,sessionId:$s,message:{role:$t,content:[{type:"text",text:$text}]}}' >> "$LOG"
}
stop() { append_row assistant "$1"; payload Stop "$1" | "$HOOK"; }
blocked() { [ "$status" -eq 0 ]; [[ "$output" == *'"decision": "block"'* || "$output" == *'"decision":"block"'* ]]; }

@test "input: first and consecutive inputs preserve parent fields and invalidate state" {
  register
  jq -e '.turn_input.generation == 1 and .turn_input.sender == "startup" and .turn_state == null and .opaque.keep and .stop_uuid == "parent-uuid" and .session == "terminal"' "$REC"
  stop '状態: 作業報告 — 意味は実作業と不一致でも形式を受理'
  register
  jq -e '.turn_input.generation == 2 and .turn_state == null and (.turn_input.received_at | test("^[0-9]{4}-.*Z$"))' "$REC"
  snapshot
  SID=s2; input direct
  unchanged
}
@test "input: startup, relaunch, cross repo, parent relay and quotes" {
  input '/develop #2 （エピック #1 の子。親ワークツリー /parent から Orca で起動）'
  [ "$(jq -r .turn_input.sender "$REC")" = startup ]
  input '/develop #2 （エピック #1 の子。親ワークツリー /parent から Orca で起動）'
  [ "$(jq -r .turn_input.sender "$REC")" = owner ]
  SID=s2
  input '/develop #2 （エピック #1 の子。エピックのリポジトリ o/r。返事を受けて起動し直し） 主の返事（親エピック #1 経由）: ok'
  [ "$(jq -r .turn_input.sender "$REC")" = startup ]
  for p in '親エピック #1（o/r）の判断: ok' '主の返事（親エピック #1 経由）: ok'; do
    input "$p"; [ "$(jq -r .turn_input.sender "$REC")" = parent ]
  done
  input '引用: 親エピック #1 の判断'
  [ "$(jq -r .turn_input.sender "$REC")" = owner ]
  snapshot
  SID=s3; input '/develop #99 （エピック #1 の子。返事を受けて起動し直し）'
  unchanged
}
@test "stop: three values, trimming, and retry in the same generation" {
  register
  for v in 主の返事待ち 作業報告 完了; do
    register
    run stop "状態: $v —   要約  "
    [ "$status" -eq 0 ]; [ -z "$output" ]
    jq -e --arg v "$v" '.turn_state.value == $v and .turn_state.summary == "要約" and .turn_state.generation == .turn_input.generation and .turn_state.session_id == .turn_input.session_id and (.turn_state.recorded_at | endswith("Z"))' "$REC"
  done
}
@test "stop: malformed lines block even on retry and clear previously published state" {
  register
  stop '状態: 完了 — done'
  for msg in '欠落' '状態: 不明 — x' '状態: 完了 - 済み' '状態: 停止 — 確認してください' '状態: 完了 —   ' '> 状態: 完了 — x' '- 状態: 完了 — x' $'```\n状態: 完了 — x\n```' $'~~~\n状態: 完了 — x' $'状態: 完了 — x\n後続文'; do
    append_row assistant "$msg"
    run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop "$msg" | jq '.stop_hook_active=true')" "$HOOK"
    blocked
    [[ "$output" == *'状態: <主の返事待ち|作業報告|完了> — <空でない中身>'* ]] || return 1
    [[ "$output" != *通常入力* ]] || return 1
    [ "$(jq -r .turn_state "$REC")" = null ]
  done
  run stop '状態: 完了 — 修正済み'; [ "$status" -eq 0 ]; [ -z "$output" ]
  [ "$(jq -r .turn_input.generation "$REC")" = 1 ]
  jq -e '.turn_state.value == "完了" and .turn_state.summary == "修正済み" and .turn_state.generation == 1' "$REC"
}
@test "stop-owner: real owner guard blocks publication and corrected retry saves" {
  register
  stop '状態: 作業報告 — old'
  run stop $'#1670 の対応を進めますか？\n状態: 主の返事待ち — 判断待ち'
  blocked
  [[ "$output" != *通常入力* ]] || return 1
  [ "$(jq -r .turn_state "$REC")" = null ]
  msg=$'対応を進めますか？\nhttps://github.com/o/r/issues/1670\n状態: 主の返事待ち — 判断待ち'
  append_row assistant "$msg"
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop "$msg" | jq '.stop_hook_active=true')" "$HOOK"
  [ "$status" -eq 0 ]; [ -z "$output" ]
  [ "$(jq -r .turn_state.generation "$REC")" = 1 ]
  jq -e '.turn_state.value == "主の返事待ち"' "$REC"
}
@test "scope: ordinary, subagent and unsupported launcher do not change record" {
  before="$(cat "$REC")"
  for p in "$(payload UserPromptSubmit hi | jq '.agent_id="sub"')" "$(payload UserPromptSubmit hi | jq '.cwd="/"')"; do
    run bash -c 'printf "%s" "$1" | "$2"' _ "$p" "$HOOK"
    [ "$status" -eq 0 ]; [ -z "$output" ]; [ "$(cat "$REC")" = "$before" ]
  done
}
@test "keepalive: exact reserved input and both responses preserve original turn" {
  register; stop '状態: 主の返事待ち — answer'
  before="$(cat "$REC")"
  reserved="$(python3 "$PLUGIN_DIR/scripts/child-log-read.py" --keepalive-text)"
  input "$reserved"; append_row user "$reserved"
  for msg in 'キャッシュ維持の応答' '逸脱した応答'; do
    run stop "$msg"; [ "$status" -eq 0 ]; [ -z "$output" ]
    [ "$(cat "$REC")" = "$before" ]
  done
  input "${reserved}x"
  [ "$(jq -r .turn_input.generation "$REC")" = 2 ]
}
@test "generation: old text before boundary, late sessions and later input cannot publish" {
  append_row assistant '状態: 完了 — old'
  register
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop '状態: 完了 — old')" "$HOOK"
  [ "$status" -eq 0 ]; [ "$(jq -r .turn_state "$REC")" = null ]
  SID=s2; register
  SID=s1; run stop '状態: 完了 — late'
  [ "$status" -eq 0 ]; [ "$(jq -r .turn_input.session_id "$REC")" = s2 ]; [ "$(jq -r .turn_state "$REC")" = null ]
  SID=s2; append_row assistant '状態: 完了 — old'
  input newer
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop '状態: 完了 — old')" "$HOOK"
  [ "$status" -eq 0 ]; [ "$(jq -r .turn_state "$REC")" = null ]
}
@test "failure: missing input, unreadable transcript, malformed extension, duplicate match and locks" {
  snapshot
  run stop '状態: 完了 — x'; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
  register
  rm -f "${LOG}"
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop '状態: 完了 — x')" "$HOOK"
  blocked
  input lock-case
  mkdir "$REC.lock"
  before="$(cat "$REC")"
  run input next; [ "$status" -eq 2 ]; [ -d "$REC.lock" ]; [ "$(cat "$REC")" = "$before" ]
  run stop '状態: 完了 — x'; blocked
  [[ "$output" == *保存または無効化に失敗* ]] || return 1
  [ "$(cat "$REC")" = "$before" ]; [ -d "$REC.lock" ]
  rmdir "$REC.lock"
  jq '.turn_input.generation="bad"' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  run input next; [ "$status" -eq 2 ]
  es_read "$REC" >/dev/null
  cp "$REC" "$EPIC_STATE_ROOT/o.r-1/duplicate.json"
  run input next; [ "$status" -eq 2 ]
  run stop '状態: 完了 — x'; blocked
}

@test "hooks: input and Stop use one shared entry with timeout and no other event" {
  jq -e '
    [.hooks.UserPromptSubmit[].hooks[] | select(.command | contains("epic-child-state.sh"))] | length == 1 and .[0].timeout == 30
  ' "$PLUGIN_DIR/hooks/hooks.json"
  jq -e '
    [.hooks.Stop[].hooks[]] | length == 1 and .[0].timeout == 30 and (.[0].command | contains("epic-child-state.sh"))
  ' "$PLUGIN_DIR/hooks/hooks.json"
  jq -e '[.hooks | to_entries[] | select(.key != "Stop" and .key != "UserPromptSubmit") | .value[].hooks[] | select(.command | contains("epic-child-state.sh"))] | length == 0' "$PLUGIN_DIR/hooks/hooks.json"
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR"
  cmd="$(jq -r '.hooks.UserPromptSubmit[].hooks[] | select(.command | contains("epic-child-state.sh")) | .command' "$PLUGIN_DIR/hooks/hooks.json")"
  payload UserPromptSubmit '/develop #2 （エピック #1 の子。起動）' | bash -c "$cmd"
  append_row assistant missing
  cmd="$(jq -r '.hooks.Stop[0].hooks[0].command' "$PLUGIN_DIR/hooks/hooks.json")"
  run bash -c 'printf "%s" "$1" | bash -c "$2"' _ "$(payload Stop missing)" "$cmd"
  blocked
}

@test "docs: every normal child turn declares state and input classification is not authorization" {
  doc="$PLUGIN_DIR/skills/develop/references/epic-child-stop.md"
  for term in '毎ターン' '状態: 作業報告 —' '状態: 主の返事待ち —' '状態: 完了 —' 'turn_input' '権限の証明ではない' '予約文' '時刻' 'session_id' '未登録' '送り直す' '認証' '別セッション'; do
    grep -qF "$term" "$doc"
  done
}

# Reuse the existing parent suite's fixtures without changing its expectations.
# Test bodies become inert function definitions; only helper functions run here.
parent_fixture() {
  sed -E 's/^@test .* \{$/unused_parent_test() {/' "$PLUGIN_DIR/tests/epic-dispatch.bats" > "$BATS_TEST_TMPDIR/parent-fixture.bash"
  source "$BATS_TEST_TMPDIR/parent-fixture.bash"
  setup
  log_resolve_ready
}

@test "dependency-wait: old and new marker tails keep stopped without judge or send" {
  parent_fixture
  marker='止まった理由: 依存待ち: https://github.com/o/r/issues/22'
  for text in "$marker" "$marker"$'\n状態: 作業報告 — 依存の完了待ち' "$marker"$'\r\n状態: 作業報告 — 依存の完了待ち  \r\n \r\n'; do
    printf 0 > "$STUB_CFG/ghcount_11"
    put_record 11
    put_chat 11 s1 "$(said d1 "$(ago 300)" "$text")" "$(turn_end "$(ago 300)")"
    run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11
    [ "$status" -eq 0 ]; [ "$output" = 'stopped 11' ]
    [ "$(rec_get 11 stop)" = stopped-seen ]
    [ "$(calls '^judge ')" -eq 0 ]; [ "$(calls '^orca terminal send')" -eq 0 ]
  done
}

@test "dependency-wait: ordinary, invalid, multiple and quoted statuses take the judge path" {
  parent_fixture
  marker='止まった理由: 依存待ち: https://github.com/o/r/issues/22'
  for text in '通常の報告' "$marker"$'\n後続の文章' "$marker"$'\n状態: 不明 — x' "$marker"$'\n状態: 完了 — x\n状態: 完了 — x' "$marker"$'\n> 状態: 完了 — x'; do
    log_resolve_ready
    printf 0 > "$STUB_CFG/ghcount_11"
    put_record 11
    put_chat 11 s1 "$(said d1 "$(ago 300)" "$text")" "$(turn_end "$(ago 300)")"
    judge_says judge_out 問いではない 完了の報告 '' なし
    run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
    [ "$status" -eq 0 ]; [ "$output" = 'closed 11' ]
    [ "$(rec_get 11 stop)" = resumed ]
    [ "$(calls '^orca terminal send')" -eq 0 ]
  done
  [ "$(calls '^judge ')" -eq 5 ]
}

# Inject a new prompt exactly when Stop acquires its final write lock.
race_at_lock() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  export REAL_MKDIR="${REAL_MKDIR:-$(command -v mkdir)}" RACE_PAYLOAD="$(payload UserPromptSubmit concurrent)" RACE_REC="$REC" RACE_HOOK="$HOOK"
  cat > "$BATS_TEST_TMPDIR/bin/mkdir" <<'SH'
#!/usr/bin/env bash
if [ "${1-}" = "$RACE_REC.lock" ] && [ "${INJECT_INPUT:-}" = yes ]; then
  export INJECT_INPUT=no
  printf '%s' "$RACE_PAYLOAD" | "$RACE_HOOK" || exit 99
fi
exec "$REAL_MKDIR" "$@"
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/mkdir"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH" INJECT_INPUT=yes
}

@test "generation: input between Stop inspection and save or rejection wins" {
  for msg in '状態: 完了 — old' $'#1670 の対応を進めますか？\n状態: 主の返事待ち — old'; do
    register
    before="$(jq -r .turn_input.generation "$REC")"
    race_at_lock
    run stop "$msg"
    [ "$status" -eq 0 ]
    jq -e --argjson gen "$before" '.turn_input.generation == ($gen + 1) and .turn_state == null and .stop_uuid == "parent-uuid"' "$REC"
    unset INJECT_INPUT
  done
}

@test "failure: failed atomic replacement refuses input and blocks Stop without changing record" {
  register
  stop '状態: 完了 — published'
  before="$(cat "$REC")"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  export REAL_MV="$(command -v mv)" FAIL_REC="$REC"
  cat > "$BATS_TEST_TMPDIR/bin/mv" <<'SH'
#!/usr/bin/env bash
if [ "${3-}" = "$FAIL_REC" ]; then exit 1; fi
exec "$REAL_MV" "$@"
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/mv"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  run input next
  [ "$status" -eq 2 ]; [[ "$output" == *保存できません* ]] || return 1
  [ "$(cat "$REC")" = "$before" ]; [ ! -d "$REC.lock" ]
  for msg in '状態: 完了 — new' $'#1670 の対応を進めますか？\n状態: 主の返事待ち — rejected'; do
    run stop "$msg"; blocked
    [[ "$output" == *保存または無効化に失敗* ]] || return 1
    [ "$(cat "$REC")" = "$before" ]; [ ! -d "$REC.lock" ]
  done
}

@test "stop-owner: ordinary sessions exactly preserve existing output and single-call exit code" {
  before="$(cat "$REC")"
  for mode in normal retry off malformed; do
    p="$(payload Stop '#1670 の対応を進めますか？' | jq '.cwd="/"')"
    unset DEV_WORKFLOW_OWNER_NUMBER_CHECK
    case "$mode" in
      retry) p="$(jq '.stop_hook_active=true' <<< "$p")" ;;
      off) export DEV_WORKFLOW_OWNER_NUMBER_CHECK=off ;;
      malformed) p="$(jq '.last_assistant_message={}' <<< "$p")" ;;
    esac
    expected="$(printf '%s' "$p" | "$PLUGIN_DIR/scripts/owner-message-number-check.sh")"
    run bash -c 'printf "%s" "$1" | "$2"' _ "$p" "$HOOK"
    [ "$status" -eq 0 ]; [ "$output" = "$expected" ]
    [ "$(cat "$REC")" = "$before" ]
  done
  # Isolated copy instruments the existing guard without changing the real script.
  mkdir -p "$BATS_TEST_TMPDIR/entry"
  cp "$HOOK" "$BATS_TEST_TMPDIR/entry/epic-child-state.sh"
  ln -s "$PLUGIN_DIR/scripts/epic-state.sh" "$BATS_TEST_TMPDIR/entry/epic-state.sh"
  export OWNER_CALLS="$BATS_TEST_TMPDIR/owner-calls"
  cat > "$BATS_TEST_TMPDIR/entry/owner-message-number-check.sh" <<'SH'
#!/usr/bin/env bash
cat > "$OWNER_CALLS.input"
printf 'called\n' >> "$OWNER_CALLS"
printf 'guard-output\n'
exit 7
SH
  chmod +x "$BATS_TEST_TMPDIR/entry/owner-message-number-check.sh"
  run bash -c 'printf "%s" "$1" | "$2"' _ "$p" "$BATS_TEST_TMPDIR/entry/epic-child-state.sh"
  [ "$status" -eq 7 ]; [ "$output" = guard-output ]
  [ "$(wc -l < "$OWNER_CALLS" | tr -d ' ')" = 1 ]
  [ "$(cat "$OWNER_CALLS.input")" = "$p" ]
}

@test "input: same-second generation, cross-repo mismatch, tmux and malformed optional fields" {
  register
  for _ in 1 2 3 4 5; do
    time="$(jq -r .turn_input.received_at "$REC")"
    gen="$(jq -r .turn_input.generation "$REC")"
    register
    [ "$(jq -r .turn_input.generation "$REC")" -eq "$((gen + 1))" ]
    [ "$(jq -r .turn_input.received_at "$REC")" != "$time" ] || break
  done
  [ "$(jq -r .turn_input.received_at "$REC")" = "$time" ]
  snapshot
  SID=s2
  input '/develop #2 （エピック #1 の子。エピックのリポジトリ other/repo。起動）'
  unchanged
  SID=s1
  jq '.launcher="tmux"' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  input '親エピック #1 の判断: ok'
  [ "$(jq -r .turn_input.sender "$REC")" = parent ]
  jq '.turn_state={generation:0}' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  before="$(cat "$REC")"
  run input bad; [ "$status" -eq 2 ]; [ "$(cat "$REC")" = "$before" ]
  run stop '状態: 完了 — bad'; blocked
  es_read "$REC" >/dev/null
}

@test "stop: unknown correspondence blocks while proven old messages remain ignored" {
  append_row assistant '状態: 完了 — old'
  register
  before="$(cat "$REC")"
  # Neither an old final row nor a current intermediate row proves the payload.
  for phase in before-boundary after-boundary; do
    [ "$phase" != after-boundary ] || append_row assistant '途中の発言'
    for msg in '調査が終わりました' '状態: 完了 — new'; do
      run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop "$msg")" "$HOOK"
      blocked
      [[ "$output" == *会話ログ*対応*"$REC"* ]] || return 1
      [ "$(jq -r .turn_state "$REC")" = null ]
    done
  done
  # A genuinely late Stop is still ignored even after a newer assistant row exists.
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop '状態: 完了 — old')" "$HOOK"
  [ "$status" -eq 0 ]; [ -z "$output" ]
  [ "$(jq -r .turn_input.generation "$REC")" = 1 ]
  [ "$(jq -r .turn_state "$REC")" = null ]
  # A user row following an old assistant also proves that its matching Stop is old.
  append_row assistant '状態: 完了 — previous'
  append_row user newer
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop '状態: 完了 — previous')" "$HOOK"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "scope: unregistered git sessions stay silent with invalid settings and unrelated broken records" {
  mkdir "$BATS_TEST_TMPDIR/ordinary"
  git init -q "$BATS_TEST_TMPDIR/ordinary"
  ordinary="$(cd "$BATS_TEST_TMPDIR/ordinary" && pwd -P)"
  before="$(cat "$REC")"; stamp="$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$REC")"
  printf '{"schema":1}\n' > "$EPIC_STATE_ROOT/o.r-1/bad.json"
  files="$(find "$EPIC_STATE_ROOT" -name '*.json' | sort)"
  export EPIC_DISPATCH_PARENT_EPIC=1
  for config in normal bad-timeout empty-root; do
    root="$EPIC_STATE_ROOT"
    case "$config" in
      bad-timeout) export EPIC_STATE_LOCK_TIMEOUT=abc ;;
      empty-root) export EPIC_STATE_ROOT= ;;
    esac
    for event in UserPromptSubmit Stop; do
      p="$(payload "$event" hi | jq --arg cwd "$ordinary" '.cwd=$cwd | .stop_hook_active=true')"
      run bash -c 'printf "%s" "$1" | "$2"' _ "$p" "$HOOK"
      [ "$status" -eq 0 ]; [ -z "$output" ]
      [ "$(cat "$REC")" = "$before" ]; [ "$(python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$REC")" = "$stamp" ]
    done
    export EPIC_STATE_ROOT="$root"
    [ "$(find "$EPIC_STATE_ROOT" -name '*.json' | sort)" = "$files" ]
  done
}

@test "stop-owner: missing jq preserves the original guard" {
  mkdir "$BATS_TEST_TMPDIR/no-jq"
  for tool in bash cat dirname grep python3; do
    ln -s "$(command -v "$tool")" "$BATS_TEST_TMPDIR/no-jq/$tool"
  done
  p="$(payload Stop 'PR #1712 を許容しますか？')"
  expected="$(printf '%s' "$p" | "$PLUGIN_DIR/scripts/owner-message-number-check.sh")"
  [[ "$expected" == *block* ]] || return 1
  run env PATH="$BATS_TEST_TMPDIR/no-jq" "$HOOK" <<< "$p"
  [ "$status" -eq 0 ]; [ "$output" = "$expected" ]
  p="$(payload UserPromptSubmit hello | jq 'del(.last_assistant_message)')"
  run env PATH="$BATS_TEST_TMPDIR/no-jq" "$HOOK" <<< "$p"
  [ "$status" -eq 0 ]; [ -z "$output" ]
}

@test "failure: hook lock waits are capped below its timeout and retain state" {
  register
  stop '状態: 完了 — published'
  before="$(cat "$REC")"
  mkdir "$REC.lock" "$BATS_TEST_TMPDIR/bin"
  export SLEEP_CALLS="$BATS_TEST_TMPDIR/sleeps"
  cat > "$BATS_TEST_TMPDIR/bin/sleep" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$SLEEP_CALLS"
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/sleep"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH" EPIC_STATE_LOCK_TIMEOUT=31
  for event in UserPromptSubmit Stop; do
    : > "$SLEEP_CALLS"
    p="$(payload "$event" '状態: 完了 — published')"
    run bash -c 'printf "%s" "$1" | "$2"' _ "$p" "$HOOK"
    if [ "$event" = UserPromptSubmit ]; then
      [ "$status" -eq 2 ]; [[ "$output" == *入力受付のロックに失敗* ]] || return 1
    else
      blocked; [[ "$output" == *保存または無効化に失敗* ]] || return 1
    fi
    [ "$(wc -l < "$SLEEP_CALLS" | tr -d ' ')" -eq 100 ]
    [ "$(cat "$REC")" = "$before" ]
    [ -d "$REC.lock" ]
  done
  rmdir "$REC.lock"
}

@test "dependency-wait: marker indentation retains the one-space contract" {
  for spaces in '' ' ' '  ' '   ' '    '; do
    p="$(jq -cn --arg t "${spaces}止まった理由: 依存待ち: https://x" '{text:$t}')"
    run "$HOOK" --dependency-wait <<< "$p"
    case "${#spaces}" in 0|1) [ "$status" -eq 0 ] ;; *) [ "$status" -eq 1 ] ;; esac
  done
}

@test "dependency-wait: full text determines fence context before the tail is cut" {
  parent_fixture
  marker='止まった理由: 依存待ち: https://github.com/o/r/issues/22'
  padding="$(python3 -c 'print("x" * 8500)')"
  text=$'```\n'"$padding"$'\n```\n'"$marker"$'\n状態: 作業報告 — 待機'
  put_record 11
  put_chat 11 s1 "$(said d1 "$(ago 300)" "$text")" "$(turn_end "$(ago 300)")"
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]; [ "$output" = 'stopped 11' ]
  [ "$(rec_get 11 stop)" = stopped-seen ]
  [ "$(calls '^judge ')" -eq 0 ]; [ "$(calls '^orca terminal send')" -eq 0 ]
  # The same tail inside an unclosed code example must still reach the judge.
  log_resolve_ready
  printf 0 > "$STUB_CFG/ghcount_11"
  text=$'```\n'"$padding"$'\n'"$marker"$'\n状態: 作業報告 — 例'
  put_record 11
  put_chat 11 s1 "$(said d2 "$(ago 300)" "$text")" "$(turn_end "$(ago 300)")"
  judge_says judge_out 問いではない 完了の報告 '' なし
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]; [ "$output" = 'closed 11' ]
  [ "$(rec_get 11 stop)" = resumed ]; [ "$(calls '^judge ')" -eq 1 ]
}

@test "session: unregistered ordinary inputs and Stop never claim the child" {
  snapshot
  reserved="$(python3 "$PLUGIN_DIR/scripts/child-log-read.py" --keepalive-text)"
  for p in hello '親エピック #1 の判断: ok' '主の返事（親エピック #1 経由）: ok' "$reserved"; do
    run input "$p"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
  done
  for msg in missing '状態: 完了 — x' '/develop #2 （エピック #1 の子。起動）'; do
    run stop "$msg"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
  done
  register
  jq -e '.turn_input.generation == 1 and .turn_input.sender == "startup" and .turn_input.session_id == "s1" and .turn_state == null' "$REC"
}

@test "session: registration and intentional switching require matching startup at the head" {
  for launcher in orca tmux; do
    jq --arg l "$launcher" 'del(.turn_input,.turn_state) | .launcher=$l | .epic="parent/repo#1"' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
    for phase in unregistered registered; do
      snapshot
      SID=other
      for p in '/develop #99 （エピック #1 の子。エピックのリポジトリ parent/repo。起動）' '/develop #2 （エピック #99 の子。エピックのリポジトリ parent/repo。起動）' '/develop #2 （エピック #1 の子。エピックのリポジトリ wrong/repo。起動）' '/develop #2 （エピック #1 の子。起動）' '引用: /develop #2 （エピック #1 の子。エピックのリポジトリ parent/repo。起動）'; do
        run input "$p"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
      done
      input '/develop #2 （エピック #1 の子。エピックのリポジトリ parent/repo。返事を受けて起動し直し） 主の返事（親エピック #1 経由）: ok'
      expected=1; [ "$phase" != registered ] || expected=3
      jq -e --argjson g "$expected" '.turn_input.generation == $g and .turn_input.sender == "startup" and .turn_input.session_id == "other" and .turn_state == null' "$REC"
      # The same shape deliberately sent to another session is accepted; it is not authentication.
      SID=target
      input '/develop #2 （エピック #1 の子。エピックのリポジトリ parent/repo。起動）'
      jq -e --argjson g "$expected" '.turn_input.generation == ($g + 1) and .turn_input.sender == "startup" and .turn_input.session_id == "target"' "$REC"
    done
  done
}

@test "session: qualified child startup registers an unregistered record" {
  input '/develop O/R#2 （エピック #1 の子。起動）'
  jq -e '.turn_input.generation == 1 and .turn_input.sender == "startup" and .turn_input.session_id == "s1" and .turn_state == null' "$REC"
}

@test "session: qualified child relaunch switches with a new generation" {
  register
  stop '状態: 主の返事待ち — original'
  SID=s2
  input '/develop o/r#2 （エピック #1 の子。返事を受けて起動し直し）'
  jq -e '.turn_input.generation == 2 and .turn_input.sender == "startup" and .turn_input.session_id == "s2" and .turn_state == null' "$REC"
  run stop missing; blocked
  run stop '状態: 完了 — relaunched'; [ "$status" -eq 0 ]; [ -z "$output" ]
  jq -e '.turn_state.generation == 2 and .turn_state.session_id == "s2" and .turn_state.value == "完了"' "$REC"
}

@test "session: qualified child startup rejects mismatched child or parent identity" {
  for phase in unregistered registered; do
    if [ "$phase" = registered ]; then
      SID=s1; register; stop '状態: 完了 — original'
    fi
    snapshot
    SID=s2
    for p in '/develop wrong/repo#2 （エピック #1 の子。起動）' '/develop o/r#99 （エピック #1 の子。起動）' '/develop o/r#2 （エピック #99 の子。起動）' '/develop o/r#2 （エピック #1 の子。エピックのリポジトリ wrong/repo。起動）'; do
      run input "$p"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
    done
  done
}

@test "session: S1 S2 S1 interleaving preserves bytes and timestamp then saves the real child" {
  register; stop '状態: 作業報告 — original'
  snapshot
  SID=s2
  for p in hello '親エピック #1 の判断: ok' '主の返事（親エピック #1 経由）: ok'; do
    run input "$p"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
  done
  for event in UserPromptSubmit Stop; do
    for variant in ordinary no-id empty-id bad-id no-log missing-log unreadable-log bad-prompt; do
      p="$(payload "$event" missing)"
      case "$variant" in
        no-id) p="$(jq 'del(.session_id)' <<< "$p")" ;;
        empty-id) p="$(jq '.session_id=""' <<< "$p")" ;;
        bad-id) p="$(jq '.session_id={}' <<< "$p")" ;;
        no-log) p="$(jq 'del(.transcript_path)' <<< "$p")" ;;
        missing-log) p="$(jq '.transcript_path="/nonexistent/transcript"' <<< "$p")" ;;
        unreadable-log) p="$(jq --arg l "$BATS_TEST_TMPDIR" '.transcript_path=$l' <<< "$p")" ;;
        bad-prompt) p="$(jq '.prompt={}' <<< "$p")" ;;
      esac
      run bash -c 'printf "%s" "$1" | "$2"' _ "$p" "$HOOK"
      [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
    done
  done
  SID=s1
  run stop '状態: 完了 — real'; [ "$status" -eq 0 ]; [ -z "$output" ]
  jq -e '.turn_state.summary == "real" and .turn_state.generation == 1' "$REC"
  input next; stop '状態: 作業報告 — next'
  jq -e '.turn_input.generation == 2 and .turn_state.summary == "next"' "$REC"
}

@test "session: unrelated events bypass broken extension details, bad settings and stale locks" {
  register; stop '状態: 完了 — original'
  jq '.turn_input.generation="bad" | .turn_state={bad:true}' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  snapshot
  mkdir "$REC.lock" "$BATS_TEST_TMPDIR/bin"
  # Any attempt to wait is a failure, even if it would eventually time out.
  printf '#!/bin/sh\nexit 99\n' > "$BATS_TEST_TMPDIR/bin/sleep"
  chmod +x "$BATS_TEST_TMPDIR/bin/sleep"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH" EPIC_STATE_LOCK_TIMEOUT=abc
  SID=s2
  for event in UserPromptSubmit Stop; do
    p="$(payload "$event" missing | jq 'del(.transcript_path) | .prompt={}')"
    run bash -c 'printf "%s" "$1" | "$2"' _ "$p" "$HOOK"
    [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
  done
  rmdir "$REC.lock"
  export EPIC_STATE_LOCK_TIMEOUT=0
  SID=s1
  run input next; [ "$status" -eq 2 ]; [[ "$output" == *型が不正* ]]; unchanged
  run stop missing; blocked; [[ "$output" == *型が不正* ]]
  jq '.turn_input.session_id={}' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  snapshot
  SID=s2
  run register; [ "$status" -eq 2 ]; [[ "$output" == *型が不正* ]]; unchanged
  run stop missing; blocked; [[ "$output" == *型が不正* ]]; unchanged
}

@test "session: unrelated Stop preserves direct guard output, exit code and one invocation" {
  register; stop '状態: 完了 — original'
  snapshot
  SID=s2
  for msg in missing '#1670 の対応を進めますか？'; do
    p="$(payload Stop "$msg" | jq 'del(.transcript_path)')"
    run "$PLUGIN_DIR/scripts/owner-message-number-check.sh" <<< "$p"
    expected="$output"; expected_rc="$status"
    run "$HOOK" <<< "$p"
    [ "$status" -eq "$expected_rc" ]; [ "$output" = "$expected" ]; unchanged
  done
  mkdir "$BATS_TEST_TMPDIR/entry"
  cp "$HOOK" "$BATS_TEST_TMPDIR/entry/epic-child-state.sh"
  ln -s "$PLUGIN_DIR/scripts/epic-state.sh" "$BATS_TEST_TMPDIR/entry/epic-state.sh"
  export OWNER_CALLS="$BATS_TEST_TMPDIR/owner-calls"
  cat > "$BATS_TEST_TMPDIR/entry/owner-message-number-check.sh" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
printf 'called\n' >> "$OWNER_CALLS"
printf 'guard-output\n'
exit 7
SH
  chmod +x "$BATS_TEST_TMPDIR/entry/owner-message-number-check.sh"
  run "$BATS_TEST_TMPDIR/entry/epic-child-state.sh" <<< "$p"
  [ "$status" -eq 7 ]; [ "$output" = guard-output ]; unchanged
  [ "$(wc -l < "$OWNER_CALLS" | tr -d ' ')" = 1 ]
}

@test "session: lock recheck rejects an old input after startup switches the session" {
  register; stop '状態: 完了 — original'
  old_payload="$(payload UserPromptSubmit old)"
  SID=s2
  race_at_lock
  export RACE_PAYLOAD="$(payload UserPromptSubmit '/develop #2 （エピック #1 の子。起動し直し）')"
  run "$HOOK" <<< "$old_payload"
  [ "$status" -eq 0 ]; [ -z "$output" ]
  jq -e '.turn_input.generation == 2 and .turn_input.session_id == "s2" and .turn_input.sender == "startup" and .turn_state == null' "$REC"
  unset INJECT_INPUT
  stop '状態: 完了 — new session'
  snapshot
  SID=s1
  run stop missing; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
}

@test "session: switching startup during old Stop save or rejection wins" {
  register
  for msg in '状態: 完了 — old' '#1670 の対応を進めますか？'; do
    SID=s1; register
    race_at_lock
    SID=s2
    export RACE_PAYLOAD="$(payload UserPromptSubmit '/develop #2 （エピック #1 の子。起動し直し）')"
    SID=s1
    run stop "$msg"
    [ "$status" -eq 0 ]
    jq -e '.turn_input.session_id == "s2" and .turn_input.sender == "startup" and .turn_state == null' "$REC"
    unset INJECT_INPUT
  done
}
