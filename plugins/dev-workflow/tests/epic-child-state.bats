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
append_row() {
  jq -cn --arg t "$1" --arg s "$SID" --arg text "$2" \
    '{type:$t,sessionId:$s,message:{role:$t,content:[{type:"text",text:$text}]}}' >> "$LOG"
}
stop() { append_row assistant "$1"; payload Stop "$1" | "$HOOK"; }
blocked() { [ "$status" -eq 0 ]; [[ "$output" == *'"decision": "block"'* || "$output" == *'"decision":"block"'* ]]; }

@test "input: first and consecutive inputs preserve parent fields and invalidate state" {
  input hello
  jq -e '.turn_input.generation == 1 and .turn_input.sender == "owner" and .turn_state == null and .opaque.keep and .stop_uuid == "parent-uuid" and .session == "terminal"' "$REC"
  stop '状態: 作業報告 — 意味は実作業と不一致でも形式を受理'
  input next
  jq -e '.turn_input.generation == 2 and .turn_state == null and (.turn_input.received_at | test("^[0-9]{4}-.*Z$"))' "$REC"
  SID=s2; input direct
  jq -e '.turn_input.generation == 3 and .turn_input.session_id == "s2" and .turn_input.sender == "owner"' "$REC"
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
  SID=s3; input '/develop #99 （エピック #1 の子。返事を受けて起動し直し）'
  [ "$(jq -r .turn_input.sender "$REC")" = owner ]
}
@test "stop: three values, trimming, and retry in the same generation" {
  for v in 主の返事待ち 作業報告 完了; do
    input next
    run stop "状態: $v —   要約  "
    [ "$status" -eq 0 ]; [ -z "$output" ]
    jq -e --arg v "$v" '.turn_state.value == $v and .turn_state.summary == "要約" and .turn_state.generation == .turn_input.generation and .turn_state.session_id == .turn_input.session_id and (.turn_state.recorded_at | endswith("Z"))' "$REC"
  done
}
@test "stop: malformed lines block even on retry and clear previously published state" {
  input next
  stop '状態: 完了 — done'
  for msg in '欠落' '状態: 不明 — x' '状態: 完了 —   ' '> 状態: 完了 — x' '- 状態: 完了 — x' $'```\n状態: 完了 — x\n```' $'~~~\n状態: 完了 — x' $'状態: 完了 — x\n後続文'; do
    append_row assistant "$msg"
    run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop "$msg" | jq '.stop_hook_active=true')" "$HOOK"
    blocked
    [ "$(jq -r .turn_state "$REC")" = null ]
  done
  run stop '状態: 完了 — 修正済み'; [ "$status" -eq 0 ]; [ -z "$output" ]
  [ "$(jq -r .turn_input.generation "$REC")" = 1 ]
}
@test "stop-owner: real owner guard blocks publication and corrected retry saves" {
  input next
  stop '状態: 作業報告 — old'
  run stop $'#1670 の対応を進めますか？\n状態: 主の返事待ち — 判断待ち'
  blocked
  [ "$(jq -r .turn_state "$REC")" = null ]
  run stop $'対応を進めますか？\nhttps://github.com/o/r/issues/1670\n状態: 主の返事待ち — 判断待ち'
  [ "$status" -eq 0 ]; [ -z "$output" ]
  [ "$(jq -r .turn_state.generation "$REC")" = 1 ]
}
@test "scope: ordinary, subagent and unsupported launcher do not change record" {
  before="$(cat "$REC")"
  for p in "$(payload UserPromptSubmit hi | jq '.agent_id="sub"')" "$(payload UserPromptSubmit hi | jq '.cwd="/"')"; do
    run bash -c 'printf "%s" "$1" | "$2"' _ "$p" "$HOOK"
    [ "$status" -eq 0 ]; [ -z "$output" ]; [ "$(cat "$REC")" = "$before" ]
  done
}
@test "keepalive: exact reserved input and both responses preserve original turn" {
  input hello; stop '状態: 主の返事待ち — answer'
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
  input next
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop '状態: 完了 — old')" "$HOOK"
  [ "$status" -eq 0 ]; [ "$(jq -r .turn_state "$REC")" = null ]
  SID=s2; input new
  SID=s1; run stop '状態: 完了 — late'
  [ "$status" -eq 0 ]; [ "$(jq -r .turn_input.session_id "$REC")" = s2 ]; [ "$(jq -r .turn_state "$REC")" = null ]
  SID=s2; append_row assistant '状態: 完了 — old'
  input newer
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop '状態: 完了 — old')" "$HOOK"
  [ "$status" -eq 0 ]; [ "$(jq -r .turn_state "$REC")" = null ]
}
@test "failure: missing input, unreadable transcript, malformed extension, duplicate match and locks" {
  run stop '状態: 完了 — x'; blocked; [[ "$output" == *通常入力* ]]
  input next
  rm -f "$LOG"
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop '状態: 完了 — x')" "$HOOK"
  blocked
  mkdir "$REC.lock"
  before="$(cat "$REC")"
  run input next; [ "$status" -eq 2 ]; [ -d "$REC.lock" ]; [ "$(cat "$REC")" = "$before" ]
  run stop '状態: 完了 — x'; blocked
  rmdir "$REC.lock"
  jq '.turn_input.generation="bad"' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  run input next; [ "$status" -eq 2 ]
  es_read "$REC" >/dev/null
  cp "$REC" "$EPIC_STATE_ROOT/o.r-1/duplicate.json"
  run input next; [ "$status" -eq 2 ]
  run stop '状態: 完了 — x'; blocked
}
