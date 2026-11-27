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
notified() {
  [ "$status" -eq 0 ]
  jq -e --arg path "$REC" --arg child "$(jq -r '.repo + "#" + (.number|tostring)' "$REC")" --arg epic "$(jq -r .epic "$REC")" '.hookSpecificOutput | .hookEventName == "UserPromptSubmit" and (.additionalContext | contains($path) and contains($child) and contains($epic) and contains("子セッションは未登録") and contains("入力記録・状態行検査は適用されていない") and contains("本来の子") and contains("送り直して登録を確認") and contains("別用途なら対応不要"))' <<< "$output"
}
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
@test "stop: inherited non-JSON RESERVED does not prevent ordinary state publication" {
  register
  export RESERVED='not json'
  run stop '状態: 作業報告 — 通常の状態を保存'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  jq -e '.turn_state.value == "作業報告" and .turn_state.summary == "通常の状態を保存" and .turn_state.generation == .turn_input.generation and .turn_state.session_id == .turn_input.session_id' "$REC"
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

@test "docs: dependency wait hands the Stop-saved boolean to the parent without changing the status line" {
  doc="$PLUGIN_DIR/skills/develop/references/epic-child-stop.md"
  for term in '状態: 作業報告 — <依存先と再開条件の短い要約>' 'dependency_wait: true' '停止の印を付ける操作は不要'; do
    grep -qF "$term" "$doc"
  done
  ! sed -n '/## 依存待ちで終了する/,/## エピックの子が/p' "$doc" | grep -qF '親が会話ログから検知する' || return 1
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
    put_turn 11
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
    put_turn 11
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
  for event in UserPromptSubmit Stop retry; do
    : > "$SLEEP_CALLS"
    p="$(payload "$event" '状態: 完了 — published')"
    if [ "$event" = retry ]; then
      p="$(jq '.hook_event_name="Stop" | .stop_hook_active=true' <<< "$p")"
    fi
    run_stop_payload "$p"
    if [ "$event" = UserPromptSubmit ]; then
      [ "$status" -eq 2 ]; [[ "$stderr" == *入力受付のロックに失敗* ]] || return 1
    elif [ "$event" = retry ]; then
      [ "$status" -eq 0 ]; [ -z "$output" ]
      [[ "$stderr" == *保存または無効化に失敗*"$REC"* ]] || return 1
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
  put_turn 11
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
  put_turn 11
  put_chat 11 s1 "$(said d2 "$(ago 300)" "$text")" "$(turn_end "$(ago 300)")"
  judge_says judge_out 問いではない 完了の報告 '' なし
  run dispatch wait --interval 0 --timeout 60 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]; [ "$output" = 'closed 11' ]
  [ "$(rec_get 11 stop)" = resumed ]; [ "$(calls '^judge ')" -eq 1 ]
}

@test "dependency-wait: markers cannot promote missing owner or reporting state" {
  parent_fixture
  marker='止まった理由: 依存待ち: https://github.com/o/r/issues/22'
  for pair in missing 'owner 主の返事待ち' 'parent 作業報告'; do
    printf 0 > "$STUB_CFG/ghcount_11"
    put_record 11
    [ "$pair" = missing ] || put_turn 11 $pair
    put_chat 11 s1 "$(said d1 "$(ago 300)" "$marker")" "$(turn_end "$(ago 300)")"
    run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11
    [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
    [ "$(calls '^judge ')" -eq 0 ]; [ "$(calls '^orca terminal send')" -eq 0 ]
  done
}

@test "session: unregistered ordinary inputs and Stop never claim the child" {
  snapshot
  reserved="$(python3 "$PLUGIN_DIR/scripts/child-log-read.py" --keepalive-text)"
  for p in hello '親エピック #1 の判断: ok' '主の返事（親エピック #1 経由）: ok'; do
    run input "$p"; notified; unchanged
  done
  run input "$reserved"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
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
        run input "$p"; [ "$status" -eq 0 ]; if [ "$phase" = unregistered ]; then notified; else [ -z "$output" ]; fi; unchanged
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
      run input "$p"; [ "$status" -eq 0 ]; if [ "$phase" = unregistered ]; then notified; else [ -z "$output" ]; fi; unchanged
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
  for phase in unregistered registered; do
  if [ "$phase" = registered ]; then SID=s1; register; stop '状態: 完了 — original'; fi
  snapshot
  SID=s2
  for msg in missing '#1670 の対応を進めますか？'; do
    p="$(payload Stop "$msg" | jq 'del(.transcript_path)')"
    run "$PLUGIN_DIR/scripts/owner-message-number-check.sh" <<< "$p"
    expected="$output"; expected_rc="$status"
    run "$HOOK" <<< "$p"
    [ "$status" -eq "$expected_rc" ]; [ "$output" = "$expected" ]; unchanged
  done
  mkdir -p "$BATS_TEST_TMPDIR/entry"
  cp "$HOOK" "$BATS_TEST_TMPDIR/entry/epic-child-state.sh"
  ln -sf "$PLUGIN_DIR/scripts/epic-state.sh" "$BATS_TEST_TMPDIR/entry/epic-state.sh"
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
  rm -f "${OWNER_CALLS}"
  done
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

@test "migration: mixed repo case registers and relaunches without rewriting identity" {
  for launcher in orca tmux; do
    for parent in O/R Parent/Repo; do
      jq --arg l "$launcher" --arg e "$parent#1" 'del(.turn_input,.turn_state) | .launcher=$l | .repo="O/r" | .epic=$e' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
      SID=s1
      input "/develop o/R#2 （エピック #1 の子。エピックのリポジトリ $(printf '%s' "$parent" | tr '[:upper:]' '[:lower:]')。起動）"
      jq -e --arg e "$parent#1" '.repo == "O/r" and .epic == $e and .turn_input.generation == 1 and .turn_input.sender == "startup"' "$REC"
      SID=s2
      input "/develop O/R#2 （エピック #1 の子。エピックのリポジトリ ${parent}。再起動）"
      jq -e '.turn_input.generation == 2 and .turn_input.session_id == "s2" and .turn_input.sender == "startup"' "$REC"
      snapshot
      SID=s3
      for p in '/develop other/repo#2 （エピック #1 の子。エピックのリポジトリ parent/repo。起動）' '/develop o/r#2 （エピック #1 の子。エピックのリポジトリ other/repo。起動）'; do
        run input "$p"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
      done
      if [ "$parent" = O/R ]; then
        register
        jq -e '.turn_input.generation == 3 and .turn_input.sender == "startup"' "$REC"
      fi
    done
  done
}

@test "input: cross-repo relaunch with the repository on the child number is startup; another epic repository is ignored" {
  jq 'del(.turn_input,.turn_state) | .repo="genetta-inc/flatmate" | .number=892 | .epic="oratta/claude-harness#1810"' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  input '/develop genetta-inc/flatmate#892 （エピック #1810 の子。エピックのリポジトリ oratta/claude-harness。返事を受けて起動し直し） 主の返事（親エピック #1810（oratta/claude-harness）経由）: ok'
  jq -e '.turn_input.sender == "startup" and .turn_input.session_id == "s1" and .turn_input.generation == 1' "$REC"
  snapshot
  SID=s2
  run input '/develop genetta-inc/flatmate#892 （エピック #1810 の子。エピックのリポジトリ other/repo。返事を受けて起動し直し） 主の返事（親エピック #1810（other/repo）経由）: ok'
  [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
}

@test "migration: unmatched inputs notify without locks or logs then resend activates Stop" {
  for launcher in orca tmux; do
    jq --arg l "$launcher" 'del(.turn_input,.turn_state) | .launcher=$l' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
    snapshot
    mkdir "$REC.lock"
    export EPIC_STATE_LOCK_TIMEOUT=abc
    for prompt in hello '/develop wrong/repo#2 （エピック #1 の子。起動）'; do
      # A directory cannot be read as a transcript; notification must not inspect it.
      p="$(payload UserPromptSubmit "$prompt" | jq --arg l "$BATS_TEST_TMPDIR" '.transcript_path=$l')"
      run "$HOOK" <<< "$p"; notified; unchanged
    done
    reserved="$(python3 "$PLUGIN_DIR/scripts/child-log-read.py" --keepalive-text)"
    run input "$reserved"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
    for v in 'null' '""' '{}'; do
      p="$(payload UserPromptSubmit hello | jq --argjson v "$v" '.session_id=$v')"
      run "$HOOK" <<< "$p"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
    done
    rmdir "$REC.lock"
    export EPIC_STATE_LOCK_TIMEOUT=0
    register
    jq -e '.turn_input.session_id == "s1" and .turn_input.sender == "startup" and .turn_input.generation == 1' "$REC"
    run stop missing; blocked
  done
}
# Capture streams independently: allowing Stop must not emit a block on stdout.
run_stop_payload() {
  bats_require_minimum_version 1.5.0
  run --separate-stderr "$HOOK" <<< "$1"
}
processing_failure_pair() {
  local msg="$1" reason="$2" path="${3:-$REC}" flag
  for flag in missing false string; do
    p="$(payload Stop "$msg")"
    case "$flag" in
      missing) p="$(jq 'del(.stop_hook_active)' <<< "$p")" ;;
      string) p="$(jq '.stop_hook_active="true"' <<< "$p")" ;;
    esac
    run_stop_payload "$p"
    blocked
    [[ "$(jq -r .reason <<< "$output")" == *"$reason"*"$path"* ]] || return 1
  done
  for _ in 1 2; do
    run_stop_payload "$(payload Stop "$msg" | jq '.stop_hook_active=true')"
    [ "$status" -eq 0 ]; [ -z "$output" ]
    [[ "$stderr" == *"$reason"*"$path"* ]] || return 1
  done
}

@test "processing-retry: preparation failures block first and repeatedly allow only boolean true" {
  # Keep each failure independent, including failures before a single record is chosen.
  original="$(cat "$REC")"
  msg='状態: 完了 — x'
  mkdir "$BATS_TEST_TMPDIR/entry"
  cp "$HOOK" "$BATS_TEST_TMPDIR/entry/epic-child-state.sh"
  for script in epic-state.sh owner-message-number-check.sh; do
    ln -s "$PLUGIN_DIR/scripts/$script" "$BATS_TEST_TMPDIR/entry/$script"
  done
  for failure in extension missing-log invalid-json correspondence duplicate config reserved; do
    printf '%s\n' "$original" > "$REC"
    unset EPIC_STATE_LOCK_TIMEOUT
    export EPIC_STATE_LOCK_TIMEOUT=0
    register
    append_row assistant "$msg"
    path="$REC"; reason=''
    case "$failure" in
      extension) jq '.turn_input.generation="bad"' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"; reason='型が不正' ;;
      missing-log) rm -f "$LOG"; reason='No such file' ;;
      invalid-json) printf 'invalid json\n' > "$LOG"; reason='Expecting value' ;;
      correspondence) append_row assistant other; reason='対応しません' ;;
      duplicate) cp "$REC" "$EPIC_STATE_ROOT/o.r-1/duplicate.json"; path="$EPIC_STATE_ROOT"; reason='複数' ;;
      config) export EPIC_STATE_LOCK_TIMEOUT=invalid; reason='設定が不正' ;;
      reserved) real_hook="$HOOK"; HOOK="$BATS_TEST_TMPDIR/entry/epic-child-state.sh"; reason='予約文を読めません' ;;
    esac
    before="$(jq 'del(.updated_at)' "$REC")"
    processing_failure_pair "$msg" "$reason" "$path"
    # Invalidating an existing turn is permitted; no new valid state is published.
    [ "$(jq 'del(.updated_at)' "$REC")" = "$before" ]
    [ "$(jq -r '.turn_state // null' "$REC")" = null ]
    if [ "$failure" = duplicate ]; then
      [ "$(jq 'del(.updated_at)' "$EPIC_STATE_ROOT/o.r-1/duplicate.json")" = "$before" ]
      rm -f "$EPIC_STATE_ROOT/o.r-1/duplicate.json"
      run input next; [ "$status" -eq 0 ]
    fi
    [ "$failure" != reserved ] || HOOK="$real_hook"
    rm -f "$LOG"
  done
}

@test "processing-retry: save and invalidation failures preserve JSON and recover in the same generation" {
  mkdir "$BATS_TEST_TMPDIR/bin"
  export REAL_MV="$(command -v mv)" FAIL_REC="$REC"
  cat > "$BATS_TEST_TMPDIR/bin/mv" <<'SH'
#!/usr/bin/env bash
if [ "${3-}" = "$FAIL_REC" ] && [ "${FAIL_REPLACE:-}" = yes ]; then exit 1; fi
exec "$REAL_MV" "$@"
SH
  chmod +x "$BATS_TEST_TMPDIR/bin/mv"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  for failure in lock replace; do
    for msg in '状態: 完了 — new' '欠落' '状態: 不明 — invalid'; do
      register
      stop '状態: 作業報告 — previously published'
      generation="$(jq -r .turn_input.generation "$REC")"
      before="$(cat "$REC")"
      append_row assistant "$msg"
      case "$failure" in
        lock) mkdir "$REC.lock" ;;
        replace) export FAIL_REPLACE=yes ;;
      esac
      processing_failure_pair "$msg" '保存または無効化に失敗'
      [ "$(cat "$REC")" = "$before" ]
      if [ "$failure" = lock ]; then
        [ -d "$REC.lock" ]; rmdir "$REC.lock"
      else
        [ ! -d "$REC.lock" ]; unset FAIL_REPLACE
      fi
      # A recovered retry still validates and clears malformed state before saving.
      if [ "$msg" != '状態: 完了 — new' ]; then
        run_stop_payload "$(payload Stop "$msg" | jq '.stop_hook_active=true')"
        blocked
        [ "$(jq -r .turn_state "$REC")" = null ]
      fi
      msg_fixed='状態: 完了 — recovered'
      append_row assistant "$msg_fixed"
      run_stop_payload "$(payload Stop "$msg_fixed" | jq '.stop_hook_active=true')"
      [ "$status" -eq 0 ]; [ -z "$output" ]; [ -z "$stderr" ]
      jq -e --argjson g "$generation" '.turn_input.generation == $g and .turn_state.generation == $g and .turn_state.summary == "recovered" and .opaque.keep and .stop_uuid == "parent-uuid" and .session == "terminal"' "$REC"
    done
  done
}

@test "processing-retry: new input wins over retry save and invalidation" {
  for msg in '状態: 完了 — old' '欠落'; do
    register
    append_row assistant "$msg"
    generation="$(jq -r .turn_input.generation "$REC")"
    race_at_lock
    run_stop_payload "$(payload Stop "$msg" | jq '.stop_hook_active=true')"
    [ "$status" -eq 0 ]; [ -z "$output" ]; [ -z "$stderr" ]
    jq -e --argjson g "$generation" '.turn_input.generation == ($g + 1) and .turn_state == null and .stop_uuid == "parent-uuid" and .opaque.keep' "$REC"
    unset INJECT_INPUT
  done
}

@test "processing-retry: unregistered Stop never registers or fails on any retry flag" {
  snapshot
  for flag in false true '"true"'; do
    run_stop_payload "$(payload Stop missing | jq --argjson f "$flag" '.stop_hook_active=$f')"
    [ "$status" -eq 0 ]; [ -z "$output" ]; [ -z "$stderr" ]; unchanged
  done
}

@test "processing-retry: malformed session identity is a failure without registration" {
  register
  jq '.turn_input.session_id={}' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  snapshot
  processing_failure_pair missing '型が不正'
  unchanged
}

@test "processing-retry: existing Stop output and exit survive waived processing failures" {
  register
  mkdir "$BATS_TEST_TMPDIR/entry"
  cp "$HOOK" "$BATS_TEST_TMPDIR/entry/epic-child-state.sh"
  ln -s "$PLUGIN_DIR/scripts/epic-state.sh" "$BATS_TEST_TMPDIR/entry/epic-state.sh"
  export GUARD_RC=0 GUARD_OUTPUT='{"decision":"block","reason":"existing guard"}' OWNER_CALLS="$BATS_TEST_TMPDIR/owner-calls"
  cat > "$BATS_TEST_TMPDIR/entry/owner-message-number-check.sh" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
printf 'called\n' >> "$OWNER_CALLS"
printf '%s\n' "$GUARD_OUTPUT"
exit "$GUARD_RC"
SH
  chmod +x "$BATS_TEST_TMPDIR/entry/owner-message-number-check.sh"
  HOOK="$BATS_TEST_TMPDIR/entry/epic-child-state.sh"
  snapshot
  for GUARD_RC in 0 7; do
    export GUARD_RC
    run_stop_payload "$(payload Stop missing | jq '.stop_hook_active=true')"
    [ "$status" -eq "$GUARD_RC" ]; [ "$output" = "$GUARD_OUTPUT" ]
    [[ "$stderr" == *予約文を読めません*"$REC"* ]]; unchanged
  done
  [ "$(wc -l < "$OWNER_CALLS" | tr -d ' ')" = 2 ]
}

dep_marker='止まった理由: 依存待ち: https://github.com/o/r/issues/22'
dep_of() { jq -r 'if (.turn_state|type)=="object" and (.turn_state|has("dependency_wait")) then (.turn_state.dependency_wait|tojson) else "absent" end' "$REC"; }

@test "dependency_wait: saved only for a checked dependency-wait work report" {
  register
  run stop "$dep_marker"$'\n状態: 作業報告 — 前提の完了後に再開'; [ "$status" -eq 0 ]; [ -z "$output" ]
  jq -e '.turn_state.value == "作業報告" and .turn_state.dependency_wait == true and .turn_state.generation == 1 and .turn_state.summary == "前提の完了後に再開" and .opaque.keep' "$REC"
  # CRLF, trailing blank lines and one leading space keep the existing grammar
  for msg in "$dep_marker"$'\r\n状態: 作業報告 — a\r\n \r\n' " $dep_marker"$'\n\n状態: 作業報告 — a'; do
    input next; stop "$msg"
    [ "$(dep_of)" = true ]
  done
  # two leading spaces, ordinary report, separating prose, other values, quoting
  for msg in "  $dep_marker"$'\n状態: 作業報告 — a' '通常の報告
状態: 作業報告 — a' "$dep_marker"$'\n後続\n状態: 作業報告 — a' "$dep_marker"$'\n状態: 主の返事待ち — a' "$dep_marker"$'\n状態: 完了 — a' "> $dep_marker"$'\n状態: 作業報告 — a' $'```\n'"$dep_marker"$'\n```\n状態: 作業報告 — a'; do
    input next; stop "$msg"
    jq -e '.turn_state != null' "$REC"
    [ "$(dep_of)" = absent ]
  done
  # long body, unclosed fence, missing status line
  input next
  run stop "$(printf 'x%.0s' {1..20000})"$'\n'"$dep_marker"$'\n状態: 作業報告 — long'; [ "$status" -eq 0 ]
  [ "$(dep_of)" = true ]
  input next
  run stop $'```\n'"$dep_marker"$'\n状態: 作業報告 — a'; blocked
  [ "$(jq -r .turn_state "$REC")" = null ]
  input next
  run stop "$dep_marker"; blocked
  [ "$(jq -r .turn_state "$REC")" = null ]
}

@test "dependency_wait: owner-guard rejection and rewrite do not carry the mark" {
  register
  stop "$dep_marker"$'\n状態: 作業報告 — a'
  [ "$(dep_of)" = true ]
  run stop '通常の報告
状態: 作業報告 — b'
  [ "$status" -eq 0 ]; [ "$(dep_of)" = absent ]
  [ "$(jq -r .turn_state.summary "$REC")" = b ]
  stop "$dep_marker"$'\n状態: 作業報告 — a'
  run stop $'#1670 の対応を進めますか？\n状態: 主の返事待ち — c'
  blocked
  [ "$(jq -r .turn_state "$REC")" = null ]
}

@test "dependency_wait: next input of every sender clears it and keeps parent fields" {
  # Inputs only reach the registered session; the startup sender is a relaunch from another session.
  for p in hello '親エピック #1（o/r）の判断: ok' '/develop #2 （エピック #1 の子。親ワークツリー /parent から Orca で起動）'; do
    SID=s1; register
    stop "$dep_marker"$'\n状態: 作業報告 — a'
    [ "$(dep_of)" = true ]
    case "$p" in /develop*) SID=s9; sender=startup ;; 親*) sender=parent ;; *) sender=owner ;; esac
    input "$p"
    jq -e --arg s "$sender" --arg sid "$SID" '.turn_state == null and .turn_input.sender == $s and .turn_input.session_id == $sid and .stop_uuid == "parent-uuid" and .opaque.keep' "$REC"
  done
  # reserved text keeps the mark
  SID=s1; register; stop "$dep_marker"$'\n状態: 作業報告 — a'
  before="$(cat "$REC")"
  reserved="$(python3 "$PLUGIN_DIR/scripts/child-log-read.py" --keepalive-text)"
  input "$reserved"; append_row user "$reserved"
  run stop 'キャッシュ維持の応答'; [ "$status" -eq 0 ]
  [ "$(cat "$REC")" = "$before" ]
}

@test "dependency_wait: only boolean passes the type check; old records stay readable" {
  register
  stop "$dep_marker"$'\n状態: 作業報告 — a'
  for v in true false; do
    jq --argjson v "$v" '.turn_state.dependency_wait=$v' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
    es_read "$REC" >/dev/null
    run input again; [ "$status" -eq 0 ]
    stop "$dep_marker"$'\n状態: 作業報告 — a'
  done
  jq 'del(.turn_state.dependency_wait)' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  run input again; [ "$status" -eq 0 ]
  for bad in '"true"' 1 null '[]' '{}'; do
    input next; stop "$dep_marker"$'\n状態: 作業報告 — a'
    jq --argjson v "$bad" '.turn_state.dependency_wait=$v' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
    before="$(cat "$REC")"
    run input again; [ "$status" -eq 2 ]
    [ "$(cat "$REC")" = "$before" ]
    jq 'del(.turn_state.dependency_wait)' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  done
  # record without turn fields: first input and Stop work as before
  es_new_record o/r 1 o/r 2 orca /parent "$WORK" child main running stopped > "$REC"
  register; jq -e '.turn_input.generation == 1 and .turn_state == null' "$REC"
}

@test "dependency_wait: stale Stop and late input do not publish the mark" {
  register
  append_row assistant "$dep_marker"$'\n状態: 作業報告 — old'
  input newer
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop "$dep_marker"$'\n状態: 作業報告 — old')" "$HOOK"
  [ "$status" -eq 0 ]; [ "$(jq -r .turn_state "$REC")" = null ]
  input race
  race_at_lock
  run stop "$dep_marker"$'\n状態: 作業報告 — late'
  [ "$status" -eq 0 ]
  jq -e '.turn_state == null and .stop_uuid == "parent-uuid"' "$REC"
}

@test "dependency_wait: an owner-sent work report with the field stays excluded like a record without turn state" {
  parent_fixture
  marker='止まった理由: 依存待ち: https://github.com/o/r/issues/22'
  for extra in none flag; do
    printf 0 > "$STUB_CFG/ghcount_11"
    put_record 11
    if [ "$extra" = flag ]; then
      f="$(rec_of 1122 11)"
      jq '.turn_input={generation:1,session_id:"s1",sender:"owner",received_at:"2026-01-01T00:00:00Z",transcript_path:"/x",transcript_offset:0}
          | .turn_state={generation:1,session_id:"s1",value:"作業報告",summary:"a",recorded_at:"2026-01-01T00:00:00Z",dependency_wait:true}' "$f" > "$f.tmp"
      mv "$f.tmp" "$f"
    fi
    put_chat 11 s1 "$(said d1 "$(ago 300)" "$marker"$'\n状態: 作業報告 — a')" "$(turn_end "$(ago 300)")"
    # #1744: none has no turn state; flag is sender owner. Owner turns are never stop targets, and dependency_wait:true must not change that.
    run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11
    [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
    [ "$(calls '^judge ')" -eq 0 ]; [ "$(calls '^orca terminal send')" -eq 0 ]
  done
}

@test "dependency_wait: a parent-sent work report with the field is received as a dependency stop" {
  parent_fixture
  marker='止まった理由: 依存待ち: https://github.com/o/r/issues/22'
  printf 0 > "$STUB_CFG/ghcount_11"
  put_record 11
  f="$(rec_of 1122 11)"
  jq '.turn_input={generation:1,session_id:"s1",sender:"parent",received_at:"2026-01-01T00:00:00Z",transcript_path:"/x",transcript_offset:0}
      | .turn_state={generation:1,session_id:"s1",value:"作業報告",summary:"a",recorded_at:"2026-01-01T00:00:00Z",dependency_wait:true}' "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
  put_chat 11 s1 "$(said d1 "$(ago 300)" "$marker"$'\n状態: 作業報告 — a')" "$(turn_end "$(ago 300)")"
  # #1744: the pair of the owner case above; parent turns with dependency_wait:true are stops.
  run dispatch wait --interval 0 --timeout 0 --watch-stopped --resolve 400 11
  [ "$status" -eq 0 ]; [ "$output" = 'stopped 11' ]
  [ "$(calls '^judge ')" -eq 0 ]; [ "$(calls '^orca terminal send')" -eq 0 ]
}

# --- 作業待ち向け（background）の予約文（#1792） ---
bg_text() { python3 "$PLUGIN_DIR/scripts/child-log-read.py" --keepalive-text background; }
bg_reply() {
  jq -r '.background | .separator as $s | [.reply_prefix] + [.fields[] | . + " value"] | join($s)' "$PLUGIN_DIR/references/child-cache-keepalive.json"
}
other_reply() {
  jq -r '.separator as $s | [.reply_prefix] + [.fields[] | . + " value"] | join($s)' "$PLUGIN_DIR/references/child-cache-keepalive.json"
}

@test "background keepalive: reception and every kind of reply keep the whole record, plain and dependency_wait" {
  for dep in plain wait; do
    rm -f "$LOG"
    SID=s1; register
    if [ "$dep" = wait ]; then
      stop "$dep_marker"$'\n状態: 作業報告 — a'
      [ "$(jq -r '.turn_state.dependency_wait' "$REC")" = true ]
    else
      stop '状態: 作業報告 — a'
    fi
    snapshot
    reserved="$(bg_text)"
    run input "$reserved"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
    append_row user "$reserved"
    for msg in "$(bg_reply)" "$(other_reply)" '逸脱した応答' $'複数行\n行目' $'状態: 完了 — 状態行付き' "$(bg_reply)"$'\n状態: 完了 — x'; do
      run stop "$msg"; [ "$status" -eq 0 ]; [ -z "$output" ]
      unchanged
    done
  done
}

@test "background keepalive: a changed text and a real input after it advance the generation and Stop is checked normally" {
  register; stop '状態: 作業報告 — a'
  reserved="$(bg_text)"
  input "${reserved}x"
  [ "$(jq -r .turn_input.generation "$REC")" = 2 ]
  [ "$(jq -r .turn_state "$REC")" = null ]
  input "$reserved"; append_row user "$reserved"
  run stop "$(bg_reply)"; [ "$status" -eq 0 ]
  [ "$(jq -r .turn_input.generation "$REC")" = 2 ]
  input 'owner words'
  [ "$(jq -r .turn_input.generation "$REC")" = 3 ]
  [ "$(jq -r .turn_state "$REC")" = null ]
  append_row user 'owner words'
  run stop "$(bg_reply)"; blocked
  run stop '状態: 完了 — done'; [ "$status" -eq 0 ]
  jq -e '.turn_state.value == "完了" and .turn_state.generation == 3' "$REC"
  # parent input after the reserved text
  input "$reserved"; append_row user "$reserved"
  input '親エピック #1 の判断: ok'
  [ "$(jq -r .turn_input.generation "$REC")" = 4 ]
  [ "$(jq -r .turn_input.sender "$REC")" = parent ]
  [ "$(jq -r .turn_state "$REC")" = null ]
}

@test "background keepalive: an unregistered or out-of-scope session leaves the record and gives no notice" {
  snapshot
  run input "$(bg_text)"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
  register; stop '状態: 作業報告 — a'
  snapshot
  SID=s2; run input "$(bg_text)"; [ "$status" -eq 0 ]; [ -z "$output" ]; unchanged
}

# --- 作業待ちの明示行（background_wait、#1777） ---
bg_marker='作業待ち: task-17 2026-11-24T00:00:00Z'
bgw_of() { jq -r 'if (.turn_state|type)=="object" and (.turn_state|has("background_wait")) then (.turn_state.background_wait|tojson) else "absent" end' "$REC"; }

@test "background_wait: the line right before a work report is saved with the state" {
  register
  jq '.status="running" | .stop="resumed"' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  run stop "$bg_marker"$'\n状態: 作業報告 — agent の結果待ち'; [ "$status" -eq 0 ]; [ -z "$output" ]
  jq -e '.turn_state.value == "作業報告" and .turn_state.summary == "agent の結果待ち"
    and .turn_state.background_wait == {id:"task-17",started_at:"2026-11-24T00:00:00Z"}
    and (.turn_state | has("dependency_wait") | not)
    and .turn_state.generation == .turn_input.generation and .turn_state.session_id == .turn_input.session_id
    and .schema == 1 and .stop == "resumed" and .status == "running" and .opaque.keep' "$REC"
  # CRLF, blank lines between and ids with the allowed punctuation
  for msg in "$bg_marker"$'\r\n状態: 作業報告 — a\r\n' "$bg_marker"$'\n\n状態: 作業報告 — a' $'本文\n作業待ち: A.b_c:d-1 2026-02-28T23:59:59Z\n状態: 作業報告 — a'; do
    input next; run stop "$msg"; [ "$status" -eq 0 ]; [ -z "$output" ]
    [ "$(bgw_of)" != absent ] || return 1
  done
  [ "$(jq -r .turn_state.background_wait.id "$REC")" = A.b_c:d-1 ]
}

@test "background_wait: prose, quotes, code and lines in the middle are not markers" {
  register
  for msg in $'CI 待ち\n状態: 作業報告 — CI 待ち' '状態: 作業報告 — 作業待ち: task-17 2026-11-24T00:00:00Z' \
    "$bg_marker"$'\n後続\n状態: 作業報告 — a' "> $bg_marker"$'\n状態: 作業報告 — a' \
    $'```\n'"$bg_marker"$'\n```\n状態: 作業報告 — a' '状態: 作業報告 — 通常の報告'; do
    input next; run stop "$msg"; [ "$status" -eq 0 ]; [ -z "$output" ]
    jq -e '.turn_state.value == "作業報告"' "$REC"
    [ "$(bgw_of)" = absent ] || { echo "msg=$msg"; return 1; }
  done
  # an unclosed fence is still the existing status-line rejection
  input next; run stop $'```\n'"$bg_marker"$'\n状態: 作業報告 — a'; blocked
  [ "$(jq -r .turn_state "$REC")" = null ]
}

@test "background_wait: fullwidth colon blocks and clears the previous state" {
  register
  stop "$bg_marker"$'\n状態: 作業報告 — a'
  run stop '作業待ち： task-17 2026-11-24T00:00:00Z'$'\n状態: 作業報告 — a'
  blocked
  [[ "$output" == *'作業待ち: <wait-id> <started-at>'* ]] || return 1
  [ "$(jq -r .turn_state "$REC")" = null ]
}

@test "background_wait: leading space blocks and clears the previous state" {
  register
  stop "$bg_marker"$'\n状態: 作業報告 — a'
  run stop ' 作業待ち: task-17 2026-11-24T00:00:00Z'$'\n状態: 作業報告 — a'
  blocked
  [[ "$output" == *'作業待ち: <wait-id> <started-at>'* ]] || return 1
  [ "$(jq -r .turn_state "$REC")" = null ]
}

@test "background_wait: list blocks and clears the previous state" {
  register
  stop "$bg_marker"$'\n状態: 作業報告 — a'
  run stop '- 作業待ち: task-17 2026-11-24T00:00:00Z'$'\n状態: 作業報告 — a'
  blocked
  [[ "$output" == *'作業待ち: <wait-id> <started-at>'* ]] || return 1
  [ "$(jq -r .turn_state "$REC")" = null ]
}

@test "background_wait: bold blocks and clears the previous state" {
  register
  stop "$bg_marker"$'\n状態: 作業報告 — a'
  run stop '**作業待ち: task-17 2026-11-24T00:00:00Z**'$'\n状態: 作業報告 — a'
  blocked
  [[ "$output" == *'作業待ち: <wait-id> <started-at>'* ]] || return 1
  [ "$(jq -r .turn_state "$REC")" = null ]
}

@test "background_wait: a malformed line, another value or a dependency wait blocks and publishes nothing" {
  register
  stop "$bg_marker"$'\n状態: 作業報告 — a'
  [ "$(bgw_of)" != absent ]
  for msg in $'作業待ち:  2026-11-24T00:00:00Z\n状態: 作業報告 — a' $'作業待ち: task 17 2026-11-24T00:00:00Z\n状態: 作業報告 — a' \
    $'作業待ち: -x 2026-11-24T00:00:00Z\n状態: 作業報告 — a' $'作業待ち: task-17 2026-02-30T00:00:00Z\n状態: 作業報告 — a' \
    $'作業待ち: task-17 2026-11-24 00:00:00\n状態: 作業報告 — a' $'作業待ち: task-17\n状態: 作業報告 — a' \
    $'作業待ち: task-17 2026-11-24T00:00:00+09:00\n状態: 作業報告 — a' \
    "$bg_marker"$'\n状態: 完了 — a' "$bg_marker"$'\n状態: 主の返事待ち — a' \
    "$dep_marker"$'\n'"$bg_marker"$'\n状態: 作業報告 — a' "$bg_marker"$'\n'"$dep_marker"$'\n状態: 作業報告 — a'; do
    run stop "$msg"; blocked
    [[ "$output" == *'作業待ち: <wait-id> <started-at>'* ]] || { echo "msg=$msg"; return 1; }
    [ "$(jq -r .turn_state "$REC")" = null ] || return 1
  done
  run stop "$bg_marker"$'\n状態: 作業報告 — 直した'; [ "$status" -eq 0 ]; [ -z "$output" ]
  [ "$(jq -r .turn_state.background_wait.id "$REC")" = task-17 ]
}

@test "background_wait: new input of every sender, a plain end and other values drop it" {
  register
  stop "$bg_marker"$'\n状態: 作業報告 — a'
  for p in hello '親エピック #1（o/r）の判断: ok'; do
    input "$p"
    jq -e '.turn_state == null and .stop_uuid == "parent-uuid"' "$REC"
    stop "$bg_marker"$'\n状態: 作業報告 — a'
  done
  for msg in '状態: 作業報告 — 回収済み' '状態: 主の返事待ち — 判断を' '状態: 完了 — 済み'; do
    input next; stop "$bg_marker"$'\n状態: 作業報告 — a'; [ "$(bgw_of)" != absent ]
    input again; stop "$msg"
    [ "$(bgw_of)" = absent ] || return 1
  done
}

@test "background_wait: stale Stop and late input never publish it" {
  register
  append_row assistant "$bg_marker"$'\n状態: 作業報告 — old'
  input newer
  run bash -c 'printf "%s" "$1" | "$2"' _ "$(payload Stop "$bg_marker"$'\n状態: 作業報告 — old')" "$HOOK"
  [ "$status" -eq 0 ]; [ "$(jq -r .turn_state "$REC")" = null ]
  input race
  race_at_lock
  run stop "$bg_marker"$'\n状態: 作業報告 — late'
  [ "$status" -eq 0 ]
  jq -e '.turn_state == null' "$REC"
}

@test "background_wait: only a well-typed object passes the type check; old records stay readable" {
  register
  stop "$bg_marker"$'\n状態: 作業報告 — a'
  run input again; [ "$status" -eq 0 ]
  stop '状態: 作業報告 — 旧記録'
  run input again; [ "$status" -eq 0 ]
  for bad in true '"task-17"' null '[]' '{}' '{"id":"task-17"}' '{"id":1,"started_at":"2026-11-24T00:00:00Z"}' \
    '{"id":"a b","started_at":"2026-11-24T00:00:00Z"}' '{"id":"task-17","started_at":"2026-13-01T00:00:00Z"}' \
    '{"id":"task-17","started_at":"2026-11-24T00:00:00Z","x":1}'; do
    input next; stop "$bg_marker"$'\n状態: 作業報告 — a'
    jq --argjson v "$bad" '.turn_state.background_wait=$v' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
    before="$(cat "$REC")"
    run input again; [ "$status" -eq 2 ] || { echo "bad=$bad"; return 1; }
    [ "$(cat "$REC")" = "$before" ]
    jq 'del(.turn_state.background_wait)' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  done
  # a valid pair on another value or together with dependency_wait is a broken extension too
  for patch in '.turn_state.value="完了"' '.turn_state.dependency_wait=true'; do
    input next; stop "$bg_marker"$'\n状態: 作業報告 — a'
    jq "$patch" "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
    run input again; [ "$status" -eq 2 ]
    jq 'del(.turn_state.background_wait) | .turn_state.value="作業報告" | del(.turn_state.dependency_wait)' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  done
  # dependency_wait false is allowed beside it
  input next; stop "$bg_marker"$'\n状態: 作業報告 — a'
  jq '.turn_state.dependency_wait=false' "$REC" > "$REC.tmp"; mv "$REC.tmp" "$REC"
  run input again; [ "$status" -eq 0 ]
}

@test "background_wait: the reserved background text and its reply keep the pair and the whole record" {
  register
  stop "$bg_marker"$'\n状態: 作業報告 — a'
  snapshot
  reserved="$(bg_text)"
  run input "$reserved"; [ "$status" -eq 0 ]; unchanged
  append_row user "$reserved"
  run stop "$(bg_reply)"; [ "$status" -eq 0 ]; [ -z "$output" ]
  unchanged
}

# --- 裏の作業の通知などで始まる入力は直前の送り手を引き継ぐ（#1821） ---
sender_is() { jq -e --arg s "$1" --argjson g "$2" '.turn_input.sender == $s and .turn_input.generation == $g and .turn_state == null' "$REC"; }

@test "notification input: the five non-owner prefixes inherit the previous sender and start a new generation" {
  register
  stop '状態: 作業報告 — 裏で作業中'
  input '<task-notification><task-id>b1</task-id><status>completed</status></task-notification>'
  sender_is startup 2
  input '親エピック #1 の判断（主の承認ではない）: ok'
  sender_is parent 3
  g=3
  for p in '<task-notification><task-id>b2</task-id></task-notification>' '<local-command-stdout>x</local-command-stdout>' \
      '<bash-input>ls</bash-input>' '<bash-stdout>x</bash-stdout>' '<bash-stderr>x</bash-stderr>' \
      $'  \n\t<task-notification><task-id>b3</task-id></task-notification>'; do
    stop '状態: 作業報告 — 続き'
    jq -e '.turn_state != null' "$REC"
    input "$p"; g=$((g + 1))
    sender_is parent "$g"
  done
  input '調査結果を教えて'; g=$((g + 1))
  sender_is owner "$g"
  input '<task-notification><task-id>b4</task-id></task-notification>'; g=$((g + 1))
  sender_is owner "$g"
}

@test "notification input: a prefix only in the middle and a command-name prompt stay owner" {
  register
  for p in '結果は <task-notification> の中にある' '<command-name>/compact</command-name><command-args></command-args>'; do
    input '親エピック #1 の判断（主の承認ではない）: ok'
    [ "$(jq -r .turn_input.sender "$REC")" = parent ]
    input "$p"
    [ "$(jq -r .turn_input.sender "$REC")" = owner ]
  done
}

# Drive the real input/Stop hook against the parent suite's record 11, then let the parent watch it.
child_hook_on_11() {
  parent_fixture
  put_record 11
  WORK="$BATS_TEST_TMPDIR/work/issue-11"
  git init -q "$WORK"
  WORK="$(cd "$WORK" && pwd -P)"
  f="$(rec_of 1122 11)"
  jq --arg w "$WORK" '.worktree = $w' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  REC="$f" LOG="$BATS_TEST_TMPDIR/child-11.jsonl" SID=s11
  : > "$LOG"
  input '/develop #11 （エピック #1122 の子。親ワークツリー /work/parent から Orca で起動）'
  [ "$(jq -r .turn_input.sender "$REC")" = startup ]
}

@test "notification input: a parent-started work's notification turn that waits for the owner is stopped" {
  for first in startup parent; do
    child_hook_on_11
    if [ "$first" = parent ]; then
      input '親エピック #1122 の判断（主の承認ではない）: 進めてよい'
    fi
    stop '状態: 作業報告 — 裏でテストを回す'
    input '<task-notification><task-id>b1</task-id><status>completed</status></task-notification>'
    [ "$(jq -r .turn_input.sender "$REC")" = "$first" ]
    stop '状態: 主の返事待ち — マージしてよいか'
    jq -e '.turn_state.value == "主の返事待ち"' "$REC"
    gh_seq 11 open
    run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
    [ "$status" -eq 0 ]; [ "$output" = 'stopped 11' ]
    [ "$(rec_get 11 stop)" = stopped-seen ]
  done
}

@test "notification input: owner turns and owner-started notification turns keep the owner-away handling" {
  for kind in typed notified; do
    child_hook_on_11
    input '調査して結果を教えて'
    if [ "$kind" = notified ]; then
      stop '状態: 作業報告 — 裏で調べる'
      input '<task-notification><task-id>b1</task-id><status>completed</status></task-notification>'
    fi
    [ "$(jq -r .turn_input.sender "$REC")" = owner ]
    stop '状態: 主の返事待ち — どちらにしますか'
    gh_seq 11 open
    run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
    [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
    gh_seq 11 open
    EPIC_DISPATCH_OWNER_AWAY_SEC=0 run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
    [ "$status" -eq 0 ]; [ "$output" = 'owner-away 11' ]
    gh_seq 11 open
    EPIC_DISPATCH_OWNER_AWAY_SEC=0 run dispatch wait --interval 0 --timeout 0 --watch-stopped 11
    [ "$status" -eq 2 ]; [ "$output" = 'timeout 11' ]
    [ "$(rec_get 11 stop)" = '' ]
    [ "$(calls '^orca terminal send')" -eq 0 ]; [ "$(calls '^judge ')" -eq 0 ]
  done
}
