#!/usr/bin/env bats
# 子の会話ログの読み取りの部品 child-log-read.py。wait・pending-owner・child-log が共有する。
# spec: dev-workflow-develop（wait・pending-owner・child-log は子の会話ログを同じ読み取りで読む）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  READER="$PLUGIN_DIR/scripts/child-log-read.py"
  DIR="$BATS_TEST_TMPDIR/log"
  mkdir -p "$DIR"
  LOG="$DIR/s1.jsonl"
}

# 行を作る。すべて entrypoint は cli（指定で上書きできる）
line() { # <jq の式>
  jq -cn "{entrypoint: \"cli\"} + ($1)"
}
user() { line "{type: \"user\", uuid: \"$1\", timestamp: \"$2\", message: {role: \"user\", content: \"$3\"}}"; }
child() { line "{type: \"assistant\", uuid: \"$1\", timestamp: \"$2\", message: {role: \"assistant\", content: [{type: \"text\", text: \"$3\"}]}}"; }
turn_end() { line "{type: \"system\", subtype: \"turn_duration\", uuid: \"td\", timestamp: \"$1\"}"; }
tool_use() { line "{type: \"assistant\", uuid: \"$1\", timestamp: \"$2\", message: {role: \"assistant\", content: [{type: \"tool_use\", id: \"$3\", name: \"$4\", input: $5}]}}"; }
tool_result() { # <uuid> <時刻> <tool_use_id> [<toolUseResult の JSON>]
  local extra="${4-}"
  [ -n "$extra" ] || extra='{}'
  line "{type: \"user\", uuid: \"$1\", timestamp: \"$2\", toolUseResult: $extra, message: {role: \"user\", content: [{type: \"tool_result\", tool_use_id: \"$3\", content: \"ok\"}]}}"
}
notification() { # <時刻> <task-id>
  line "{type: \"queue-operation\", operation: \"enqueue\", timestamp: \"$1\", content: \"<task-notification>\\n<task-id>$2</task-id>\\n</task-notification>\"}"
  line "{type: \"user\", uuid: \"n-$2\", timestamp: \"$1\", origin: {kind: \"task-notification\"}, message: {role: \"user\", content: \"<task-notification>\\n<task-id>$2</task-id>\\n</task-notification>\"}}"
}
keepalive_request() { python3 "$READER" --keepalive-text; }
keepalive_reply() {
  jq -r '.separator as $s | [.reply_prefix] + [.fields[] | . + " value"] | join($s)' "$PLUGIN_DIR/references/child-cache-keepalive.json"
}
raw_user() { # <uuid> <時刻> <本文>
  jq -cn --arg u "$1" --arg t "$2" --arg x "$3" '{entrypoint: "cli", type: "user", uuid: $u, timestamp: $t, message: {role: "user", content: $x}}'
}
# Claude Code がその場で処理したスラッシュコマンド。実ログでは caveat の行・コマンドの行・出力の行の順に並ぶ
local_command() { # <時刻> <コマンド名>
  line "{type: \"user\", isMeta: true, uuid: \"cv\", timestamp: \"$1\", message: {role: \"user\", content: \"<local-command-caveat>x</local-command-caveat>\"}}"
  raw_user cmd "$1" "<command-name>/$2</command-name>
            <command-message>$2</command-message>
            <command-args></command-args>"
}
local_output_user() { raw_user lo "$1" '<local-command-stdout>done</local-command-stdout>'; }
local_output_system() { line "{type: \"system\", subtype: \"local_command\", uuid: \"lo\", timestamp: \"$1\", content: \"<local-command-stdout>done</local-command-stdout>\"}"; }
bang_line() { # <時刻>。主が ! で打った行とその出力
  raw_user bi "$1" '<bash-input>git status</bash-input>'
  raw_user bo "$1" '<bash-stdout>clean</bash-stdout><bash-stderr></bash-stderr>'
}
read_log() { python3 "$READER" "$DIR"; }
field() { read_log | jq -r "$1"; }

@test "a child question that ended the turn gives the uuid, text and turn_ended" {
  { user d0 2026-10-30T00:00:00.000Z 'はじめて'
    child c1 2026-10-30T00:01:00.000Z '続けてよいですか'
    turn_end 2026-10-30T00:01:01.000Z; } > "$LOG"
  run read_log
  [ "$status" -eq 0 ]
  [ "$(field .session)" = s1 ]
  [ "$(field .uuid)" = c1 ]
  [ "$(field .text)" = '続けてよいですか' ]
  [ "$(field .at)" = 2026-10-30T00:01:00.000Z ]
  [ "$(field .turn_ended)" = true ]
  [ "$(field .bg_running)" = false ]
  [ "$(field .input_after)" = false ]
  [ "$(field .last_input_at)" = 2026-10-30T00:00:00.000Z ]
  [ "$(field .last_activity_at)" = 2026-10-30T00:01:01.000Z ]
  [ "$(field '.questions | length')" = 0 ]
  [ "$(field .owner.text)" = 'はじめて' ]
}

@test "the middle of a turn is not turn_ended" {
  { user d0 2026-10-30T00:00:00.000Z 'はじめて'
    turn_end 2026-10-30T00:00:01.000Z
    user d1 2026-10-30T00:01:00.000Z 'つづき'
    child c1 2026-10-30T00:01:10.000Z 'いま進めています'
    tool_use t1 2026-10-30T00:01:11.000Z tu1 Bash '{command: "ls"}'; } > "$LOG"
  [ "$(field .turn_ended)" = false ]
  [ "$(field .uuid)" = c1 ]
}

@test "an unanswered AskUserQuestion gives its questions and becomes the last child statement" {
  { child c1 2026-10-30T00:01:00.000Z '聞きます'
    tool_use a1 2026-10-30T00:01:05.000Z tu1 AskUserQuestion '{questions: [{question: "A にしますか"}, {question: "B にしますか"}]}'; } > "$LOG"
  [ "$(field '.questions | join("|")')" = 'A にしますか|B にしますか' ]
  [ "$(field .uuid)" = a1 ]
  [ "$(field .text)" = '聞きます' ]
  [ "$(field .turn_ended)" = false ]
}

@test "an answered AskUserQuestion has no questions and counts as an input" {
  { child c1 2026-10-30T00:01:00.000Z '聞きます'
    tool_use a1 2026-10-30T00:01:05.000Z tu1 AskUserQuestion '{questions: [{question: "A にしますか"}]}'
    tool_result r1 2026-10-30T00:02:00.000Z tu1; } > "$LOG"
  [ "$(field '.questions | length')" = 0 ]
  [ "$(field .last_input_at)" = 2026-10-30T00:02:00.000Z ]
  [ "$(field .input_after)" = true ]
}

@test "a background Bash task runs until its notification, and the notification is not an input" {
  { user d0 2026-10-30T00:00:00.000Z 'はじめて'
    tool_use t1 2026-10-30T00:00:10.000Z tu1 Bash '{command: "sleep 9"}'
    tool_result r1 2026-10-30T00:00:11.000Z tu1 '{backgroundTaskId: "b1"}'
    child c1 2026-10-30T00:00:12.000Z '待ちます'
    turn_end 2026-10-30T00:00:13.000Z; } > "$LOG"
  [ "$(field .bg_running)" = true ]
  notification 2026-10-30T00:05:00.000Z b1 >> "$LOG"
  [ "$(field .bg_running)" = false ]
  [ "$(field .turn_ended)" = true ]
  [ "$(field .uuid)" = c1 ]
  [ "$(field .input_after)" = false ]
  [ "$(field .last_input_at)" = 2026-10-30T00:00:00.000Z ]
  [ "$(field .last_activity_at)" = 2026-10-30T00:05:00.000Z ]
}

@test "a background agent runs until its notification" {
  { tool_use t1 2026-10-30T00:00:10.000Z tu1 Agent '{prompt: "x"}'
    tool_result r1 2026-10-30T00:00:11.000Z tu1 '{status: "async_launched", agentId: "a1"}'; } > "$LOG"
  [ "$(field .bg_running)" = true ]
  notification 2026-10-30T00:05:00.000Z a1 >> "$LOG"
  [ "$(field .bg_running)" = false ]
}

@test "a keepalive round trip is neither a child statement nor an input" {
  { child c1 2026-10-30T00:01:00.000Z '続けてよいですか'
    turn_end 2026-10-30T00:01:01.000Z
    jq -cn --arg x "$(keepalive_request)" '{entrypoint: "cli", type: "user", uuid: "k1", timestamp: "2026-10-30T01:00:00.000Z", message: {role: "user", content: $x}}'
    jq -cn --arg x "$(keepalive_reply)" '{entrypoint: "cli", type: "assistant", uuid: "k2", timestamp: "2026-10-30T01:00:01.000Z", message: {role: "assistant", content: [{type: "text", text: $x}]}}'
    turn_end 2026-10-30T01:00:02.000Z; } > "$LOG"
  [ "$(field .uuid)" = c1 ]
  [ "$(field .input_after)" = false ]
  [ "$(field .turn_ended)" = true ]
}

@test "a hook session in the same directory is not selected" {
  { user d0 2026-10-30T00:00:00.000Z 'はじめて'; child c1 2026-10-30T00:01:00.000Z 'cli の発言'; } > "$LOG"
  { line '{type: "assistant", entrypoint: "sdk-py", uuid: "h1", timestamp: "2026-10-30T09:00:00.000Z", message: {role: "assistant", content: [{type: "text", text: "hook の発言"}]}}'; } > "$DIR/s2.jsonl"
  [ "$(field .uuid)" = c1 ]
  [ "$(field .last_activity_at)" = 2026-10-30T00:01:00.000Z ]
}

@test "an api error message is not a child statement, a parent reply is an input but not the owner" {
  { child c1 2026-10-30T00:01:00.000Z '本当の発言'
    line '{type: "assistant", isApiErrorMessage: true, uuid: "e1", timestamp: "2026-10-30T00:02:00.000Z", message: {role: "assistant", content: [{type: "text", text: "API Error"}]}}'; } > "$LOG"
  [ "$(field .uuid)" = c1 ]
  user p1 2026-10-30T00:03:00.000Z '親エピック #400 の判断（主の承認ではない）: 進めてよい' >> "$LOG"
  [ "$(field .input_after)" = true ]
  [ "$(field .owner)" = null ]
}

@test "meta and compact summary lines are not inputs" {
  { child c1 2026-10-30T00:01:00.000Z '発言'
    line '{type: "user", isMeta: true, uuid: "m1", timestamp: "2026-10-30T00:02:00.000Z", message: {role: "user", content: "<system-reminder>x</system-reminder>"}}'
    line '{type: "user", isCompactSummary: true, uuid: "m2", timestamp: "2026-10-30T00:03:00.000Z", message: {role: "user", content: "要約"}}'; } > "$LOG"
  [ "$(field .input_after)" = false ]
}

@test "a local slash command is not an input, whether its output comes as a user or a system line" {
  for output in local_output_user local_output_system; do
    { user d0 2026-10-30T00:00:00.000Z 'はじめて'
      child c1 2026-10-30T00:01:00.000Z '続けてよいですか'
      turn_end 2026-10-30T00:01:01.000Z
      local_command 2026-10-30T00:02:00.000Z mcp
      "$output" 2026-10-30T00:02:01.000Z; } > "$LOG"
    [ "$(field .uuid)" = c1 ]
    [ "$(field .input_after)" = false ]
    [ "$(field .turn_ended)" = true ]
    [ "$(field .last_input_at)" = 2026-10-30T00:00:00.000Z ]
    [ "$(field .owner.text)" = 'はじめて' ]
  done
}

@test "a local slash command does not hide an unanswered question" {
  { child c1 2026-10-30T00:01:00.000Z '聞きます'
    tool_use a1 2026-10-30T00:01:05.000Z tu1 AskUserQuestion '{questions: [{question: "A にしますか"}]}'
    local_command 2026-10-30T00:02:00.000Z reload-plugins
    local_output_system 2026-10-30T00:02:01.000Z; } > "$LOG"
  [ "$(field .uuid)" = a1 ]
  [ "$(field '.questions | length')" = 1 ]
  [ "$(field .input_after)" = false ]
  [ "$(field .last_input_at)" = '' ]
}

@test "a ! line and its output are neither inputs nor the owner's words" {
  { user d0 2026-10-30T00:00:00.000Z 'はじめて'
    child c1 2026-10-30T00:01:00.000Z '続けてよいですか'
    turn_end 2026-10-30T00:01:01.000Z
    bang_line 2026-10-30T00:02:00.000Z; } > "$LOG"
  [ "$(field .input_after)" = false ]
  [ "$(field .turn_ended)" = true ]
  [ "$(field .last_input_at)" = 2026-10-30T00:00:00.000Z ]
  [ "$(field .owner.text)" = 'はじめて' ]
}

@test "a keepalive reply is still matched after a local command in between" {
  { child c1 2026-10-30T00:01:00.000Z '続けてよいですか'
    turn_end 2026-10-30T00:01:01.000Z
    jq -cn --arg x "$(keepalive_request)" '{entrypoint: "cli", type: "user", uuid: "k1", timestamp: "2026-10-30T01:00:00.000Z", message: {role: "user", content: $x}}'
    bang_line 2026-10-30T01:00:01.000Z
    jq -cn --arg x "$(keepalive_reply)" '{entrypoint: "cli", type: "assistant", uuid: "k2", timestamp: "2026-10-30T01:00:02.000Z", message: {role: "assistant", content: [{type: "text", text: $x}]}}'; } > "$LOG"
  [ "$(field .uuid)" = c1 ]
}

@test "a slash command sent to the model stays an input and is not the owner's words" {
  { user d0 2026-10-30T00:00:00.000Z 'はじめて'
    child c1 2026-10-30T00:01:00.000Z '続けてよいですか'
    turn_end 2026-10-30T00:01:01.000Z
    raw_user s1 2026-10-30T00:02:00.000Z '<command-message>dev-workflow:develop</command-message>
<command-name>/dev-workflow:develop</command-name>
<command-args>11</command-args>'
    line '{type: "user", isMeta: true, uuid: "m1", timestamp: "2026-10-30T00:02:00.000Z", message: {role: "user", content: [{type: "text", text: "スキルの本文"}]}}'; } > "$LOG"
  [ "$(field .input_after)" = true ]
  [ "$(field .last_input_at)" = 2026-10-30T00:02:00.000Z ]
  [ "$(field .owner.text)" = 'はじめて' ]
}

@test "subagent logs count only for the last activity" {
  { child c1 2026-10-30T00:01:00.000Z '発言'; } > "$LOG"
  mkdir -p "$DIR/s1/subagents"
  line '{type: "assistant", uuid: "sa", timestamp: "2026-10-30T02:00:00.000Z", message: {role: "assistant", content: [{type: "text", text: "子の子"}]}}' > "$DIR/s1/subagents/agent-a.jsonl"
  [ "$(field .uuid)" = c1 ]
  [ "$(field .last_activity_at)" = 2026-10-30T02:00:00.000Z ]
  [ "$(field .last_activity_epoch)" -gt 0 ]
}

@test "a uuid outside [0-9a-f-] or not a string is read as empty, and the statement stays" {
  for bad in '"a-1;pending-12"' '"A-1"' '"a-1\\nb"' '12'; do
    { line "{type: \"assistant\", uuid: $bad, timestamp: \"2026-10-30T00:01:00.000Z\", message: {role: \"assistant\", content: [{type: \"text\", text: \"聞きます\"}]}}"
      turn_end 2026-10-30T00:01:01.000Z; } > "$LOG"
    [ "$(field '.uuid')" = '' ]
    [ "$(field '.text')" = '聞きます' ]
    [ "$(field '.at')" = 2026-10-30T00:01:00.000Z ]
  done
}

@test "no cli log exits 1 with nothing on stdout" {
  run python3 "$READER" "$BATS_TEST_TMPDIR/none"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  jq -cn '{type: "assistant", timestamp: "2026-10-30T00:00:00.000Z", message: {role: "assistant", content: "x"}}' > "$LOG"
  run read_log
  [ "$status" -eq 1 ]
}

@test "the reader does not change the log" {
  { child c1 2026-10-30T00:01:00.000Z '発言'; } > "$LOG"
  before="$(cat "$LOG")"
  read_log >/dev/null
  [ "$(cat "$LOG")" = "$before" ]
  [ "$(ls "$DIR")" = s1.jsonl ]
}
