#!/usr/bin/env bats
#
# owner-reply-check.sh（issue #721）— 会話ログに主の発言が実在するかを確かめる。
# spec: dev-workflow-owner-reply-check
# 入力の行の形は 2026-10-07 時点の実物の会話ログから抜いたもの。

setup() {
  export LC_ALL=C.UTF-8
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/owner-reply-check.sh"
  export OWNER_REPLY_PROJECTS_DIR="$BATS_TEST_TMPDIR/projects"
  SID="0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"
  PROJ="$OWNER_REPLY_PROJECTS_DIR/-Users-someone-repo"
  LOG="$PROJ/$SID.jsonl"
  mkdir -p "$PROJ"
  : > "$LOG"
}

# 1 行を会話ログに足す（JSON をそのまま書く）
add() { printf '%s\n' "$1" >> "$LOG"; }

run_check() { run bash "$SCRIPT" "$@"; }

# ---- 通す

@test "owner-reply: a normal human message matches (exit 0, MATCH and MATCHES lines)" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"許容する。進めて"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MATCH: 2026-10-07T01:00:00.000Z 許容する。進めて"* ]] || return 1
  [[ "$output" == *"MATCHES=1"* ]] || return 1
}

@test "owner-reply: /develop command args match" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"timestamp":"2026-10-07T02:00:00.000Z","message":{"role":"user","content":"<command-message>dev-workflow:develop</command-message>\n<command-name>/dev-workflow:develop</command-name>\n<command-args>721 許容する</command-args>"}}'
  run_check "$SID" "721 許容する"
  [ "$status" -eq 0 ]
}

@test "owner-reply: bash-input of gh pr comment without origin matches" {
  add '{"type":"user","isSidechain":false,"timestamp":"2026-10-07T03:00:00.000Z","message":{"role":"user","content":"<bash-input> gh pr comment 868 --body \"許容する\"</bash-input>"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 0 ]
}

@test "owner-reply: content array of text elements only matches" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"timestamp":"2026-10-07T04:00:00.000Z","message":{"role":"user","content":[{"type":"text","text":"リスクは"},{"type":"text","text":"許容します"}]}}'
  run_check "$SID" "許容します"
  [ "$status" -eq 0 ]
}

@test "owner-reply: whitespace and newline differences are ignored" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"timestamp":"2026-10-07T05:00:00.000Z","message":{"role":"user","content":"この件は\n  許容する\n進めて"}}'
  run_check "$SID" "この件は 許容する 進めて"
  [ "$status" -eq 0 ]
}

@test "owner-reply: multiple matches are all reported" {
  add '{"type":"user","origin":{"kind":"human"},"timestamp":"2026-10-07T06:00:00.000Z","message":{"content":"許容する"}}'
  add '{"type":"user","origin":{"kind":"human"},"timestamp":"2026-10-07T06:05:00.000Z","message":{"content":"やっぱり許容しない"}}'
  run_check "$SID" "許容"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MATCH: 2026-10-07T06:05:00.000Z やっぱり許容しない"* ]] || return 1
  [[ "$output" == *"MATCHES=2"* ]] || return 1
}

@test "owner-reply: broken JSON lines are skipped" {
  add '{not json'
  add '{"type":"user","origin":{"kind":"human"},"timestamp":"2026-10-07T07:00:00.000Z","message":{"content":"許容する"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 0 ]
}

# ---- 通さない（exit 1）

@test "owner-reply: assistant message does not match" {
  add '{"type":"assistant","isSidechain":false,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"許容する"}]}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MATCHES=0"* ]] || return 1
}

@test "owner-reply: sidechain user message does not match" {
  add '{"type":"user","isSidechain":true,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"許容する"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
}

@test "owner-reply: tool_result does not match" {
  add '{"type":"user","isSidechain":false,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"x","content":"許容する"}]}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
}

@test "owner-reply: forwarded message from another session (no origin, no isMeta) does not match" {
  add '{"type":"user","isSidechain":false,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"Another Claude session sent a message:\n許容する"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
}

@test "owner-reply: teammate message does not match" {
  add '{"type":"user","isSidechain":false,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"<teammate-message teammate_id=\"w\">許容する</teammate-message>"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
}

@test "owner-reply: isMeta line does not match" {
  add '{"type":"user","isSidechain":false,"isMeta":true,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"許容する"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
}

@test "owner-reply: origin.kind other than human does not match" {
  for kind in peer task-notification channel; do
    : > "$LOG"
    add '{"type":"user","isSidechain":false,"origin":{"kind":"'"$kind"'"},"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"許容する"}}'
    run_check "$SID" "許容する"
    [ "$status" -eq 1 ] || { echo "kind=$kind status=$status"; return 1; }
  done
}

@test "owner-reply: shell and local command output does not match" {
  for tag in bash-stdout bash-stderr local-command-stdout local-command-stderr; do
    : > "$LOG"
    add '{"type":"user","isSidechain":false,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"<'"$tag"'>許容する</'"$tag"'>"}}'
    run_check "$SID" "許容する"
    [ "$status" -eq 1 ] || { echo "tag=$tag status=$status"; return 1; }
  done
}

@test "owner-reply: subagent logs under <id>/subagents are not read" {
  mkdir -p "$PROJ/$SID/subagents"
  printf '%s\n' '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"timestamp":"2026-10-07T01:00:00.000Z","message":{"content":"許容する"}}' > "$PROJ/$SID/subagents/agent-a.jsonl"
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
}

@test "owner-reply: no matching text gives exit 1" {
  add '{"type":"user","origin":{"kind":"human"},"timestamp":"2026-10-07T01:00:00.000Z","message":{"content":"ちょっと待って"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MATCHES=0"* ]] || return 1
}

# ---- 確かめられない（exit 2）

@test "owner-reply: wrong number of arguments gives exit 2" {
  run_check "$SID"
  [ "$status" -eq 2 ]
  run_check "$SID" "a" "b"
  [ "$status" -eq 2 ]
}

@test "owner-reply: non-UUID session id gives exit 2" {
  run_check "../$SID" "許容する"
  [ "$status" -eq 2 ]
  run_check "not-a-uuid" "許容する"
  [ "$status" -eq 2 ]
}

@test "owner-reply: blank excerpt gives exit 2" {
  run_check "$SID" "   "
  [ "$status" -eq 2 ]
}

@test "owner-reply: missing log (another PC) gives exit 2" {
  run_check "11111111-2222-4333-8444-555555555555" "許容する"
  [ "$status" -eq 2 ]
}

# ---- ゲート 1 周目の指摘（F1〜F3）

@test "owner-reply: origin null is not treated as a missing origin (exit 1)" {
  add '{"type":"user","isSidechain":false,"origin":null,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"許容する"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
}

@test "owner-reply: bash-input without origin still matches after the origin null fix" {
  add '{"type":"user","isSidechain":false,"timestamp":"2026-10-07T03:00:00.000Z","message":{"role":"user","content":"<bash-input> gh pr comment 868 --body \"許容する\"</bash-input>"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 0 ]
}

@test "owner-reply: an excerpt that normalizes to empty (U+0085 only) gives exit 2" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"許容しない"}}'
  run_check "$SID" "$(printf '\302\205')"
  [ "$status" -eq 2 ]
  [[ "$output" != *"MATCH:"* ]] || return 1
}

@test "owner-reply: an unreadable log gives exit 2, not exit 1" {
  [ "$(id -u)" -ne 0 ] || skip "root reads files regardless of mode"
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"許容する"}}'
  chmod 000 "$LOG"
  run_check "$SID" "許容する"
  chmod 600 "$LOG"
  [ "$status" -eq 2 ]
}
