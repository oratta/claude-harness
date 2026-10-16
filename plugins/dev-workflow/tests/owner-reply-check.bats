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

@test "owner-reply: isCompactSummary false does not exclude a human message" {
  add '{"type":"user","isSidechain":false,"isCompactSummary":false,"origin":{"kind":"human"},"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"許容する"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 0 ]
}

# isVisibleInTranscriptOnly だけでは除外しない（除外の根拠は isCompactSummary。spec 守備範囲③、issue #838）
@test "owner-reply: isVisibleInTranscriptOnly true without isCompactSummary does not exclude a human message" {
  add '{"type":"user","isSidechain":false,"isVisibleInTranscriptOnly":true,"origin":{"kind":"human"},"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"許容する"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 0 ]
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

# 圧縮後の要約の行（issue #756）。属性は実ログの要約の行と同じ（type user・isMeta なし・origin なし・isVisibleInTranscriptOnly true）
@test "owner-reply: compact summary starting with 'This session is being continued' does not match" {
  add '{"type":"user","isSidechain":false,"isCompactSummary":true,"isVisibleInTranscriptOnly":true,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"This session is being continued from a previous conversation that ran out of context. The user said: 許容する"}}'
  run_check "$SID" "許容する"
  [ "$status" -eq 1 ]
}

@test "owner-reply: compact summary starting with another prefix does not match" {
  add '{"type":"user","isSidechain":false,"isCompactSummary":true,"isVisibleInTranscriptOnly":true,"timestamp":"2026-10-07T01:00:00.000Z","message":{"role":"user","content":"<artifact-content-authored-by-others/>\nThe user said: 許容する"}}'
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

# ---- 9 つ目の条件: エピックの親の打ち込みと子を起動する指示（issue #1059）
# 入力の行の形は 2026-10-15 時点の Orca 経路のエピックの親と子の実物に合わせる。
# 起動の指示の <command-args> は scripts/epic-dispatch.sh の launch（:301）と reply --relaunch（:404）の文字列を写す:
#   launch:   /develop #$n （エピック #$epic の子。親ワークツリー $parent から Orca で起動）
#   relaunch: /develop #$n （エピック #$epic の子。返事を受けて起動し直し） $msg

@test "owner-reply #1059: a reply typed by the parent with the owner-reply head does not match" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"11111111-1111-4111-8111-111111111111","timestamp":"2026-10-15T08:33:00.000Z","message":{"role":"user","content":"主の返事（親エピック #1038 経由）: 許容"}}'
  run_check "$SID" "許容"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MATCHES=0"* ]] || return 1
}

@test "owner-reply #1059: a reply typed by the parent with the parent-epic head does not match (leading spaces too)" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"11111111-1111-4111-8111-111111111112","timestamp":"2026-10-15T08:33:00.000Z","message":{"role":"user","content":"  親エピック #1038 から: 主が会話で『許容』と返した"}}'
  run_check "$SID" "主が会話で『許容』と返した"
  [ "$status" -eq 1 ]
}

@test "owner-reply #1059: the launch instruction from epic-dispatch.sh does not match" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"11111111-1111-4111-8111-111111111113","timestamp":"2026-10-15T06:00:00.000Z","message":{"role":"user","content":"<command-message>dev-workflow:develop</command-message>\n<command-name>/develop</command-name>\n<command-args>#1034 （エピック #1038 の子。親ワークツリー /Users/someone/orca/workspaces/repo/epic から Orca で起動） 許容</command-args>"}}'
  run_check "$SID" "許容"
  [ "$status" -eq 1 ]
}

@test "owner-reply #1059: the relaunch instruction from epic-dispatch.sh does not match" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"11111111-1111-4111-8111-111111111114","timestamp":"2026-10-15T08:34:00.000Z","message":{"role":"user","content":"<command-message>dev-workflow:develop</command-message>\n<command-name>/develop</command-name>\n<command-args>#1034 （エピック #1038 の子。返事を受けて起動し直し） 主の返事（親エピック #1038 経由）: 許容</command-args>"}}'
  run_check "$SID" "許容"
  [ "$status" -eq 1 ]
}

@test "owner-reply #1059: other /develop args such as 721 still match" {
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"11111111-1111-4111-8111-111111111115","timestamp":"2026-10-15T02:00:00.000Z","message":{"role":"user","content":"<command-name>/dev-workflow:develop</command-name>\n<command-args>721 許容する</command-args>"}}'
  run_check "$SID" "721 許容する"
  [ "$status" -eq 0 ]
}

# ---- --locate

@test "owner-reply #1059: --locate prints timestamp, uuid and the full text" {
  add '{"parentUuid":"346795f5-2475-4a44-a047-a8ac29560b91","isSidechain":false,"type":"user","message":{"role":"user","content":"1034は許容"},"uuid":"56c1ea83-9220-4d69-95bf-37f878ddcc94","timestamp":"2026-10-15T08:32:56.042Z","origin":{"kind":"human"},"promptSource":"typed"}'
  run_check --locate "$SID" "1034は許容"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MATCH: 2026-10-15T08:32:56.042Z 56c1ea83-9220-4d69-95bf-37f878ddcc94 1034は許容"* ]] || return 1
  [[ "$output" == *"MATCHES=1"* ]] || return 1
}

@test "owner-reply #1059: --locate skips lines without a uuid" {
  add '{"isSidechain":false,"type":"user","message":{"role":"user","content":"1034は許容"},"timestamp":"2026-10-15T08:30:00.000Z","origin":{"kind":"human"}}'
  run_check --locate "$SID" "1034は許容"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MATCHES=0"* ]] || return 1
  [[ "$output" != *"MATCH: "* ]] || return 1
}

@test "owner-reply #1059: --locate applies the owner conditions (assistant line is not located)" {
  add '{"type":"assistant","isSidechain":false,"uuid":"22222222-2222-4222-8222-222222222222","timestamp":"2026-10-15T08:30:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"1034は許容"}]}}'
  run_check --locate "$SID" "1034は許容"
  [ "$status" -eq 1 ]
}

@test "owner-reply #1059: --locate with a wrong number of arguments gives exit 2" {
  run_check --locate "$SID"
  [ "$status" -eq 2 ]
}

# ---- --relayed
# 停止の記録の作成日時 07:00、親の報告 07:34（URL あり）、圧縮の要約 08:00、主の答え 08:32 の並び

STOP_AT="2026-10-15T07:00:00Z"
STOP_URL="https://github.com/oratta/claude-harness/issues/1034#issuecomment-1111111111"
OWNER_UUID="56c1ea83-9220-4d69-95bf-37f878ddcc94"

add_report() {  # $1 = timestamp, $2 = sidechain(true/false)
  add '{"type":"assistant","isSidechain":'"${2:-false}"',"uuid":"33333333-3333-4333-8333-33333333333'"${3:-3}"'","timestamp":"'"$1"'","message":{"role":"assistant","content":[{"type":"text","text":"子 #1034 が主の許容を待って止まった。停止の記録: '"$STOP_URL"'"}]}}'
}
add_summary() {
  add '{"type":"user","isSidechain":false,"isCompactSummary":true,"isVisibleInTranscriptOnly":true,"uuid":"44444444-4444-4444-8444-444444444444","timestamp":"2026-10-15T08:00:00.000Z","message":{"role":"user","content":"This session is being continued from a previous conversation. 1034は許容"}}'
}
add_owner() {  # $1 = timestamp
  add '{"parentUuid":"346795f5-2475-4a44-a047-a8ac29560b91","isSidechain":false,"type":"user","message":{"role":"user","content":"1034は許容"},"uuid":"'"$OWNER_UUID"'","timestamp":"'"${1:-2026-10-15T08:32:56.042Z}"'","origin":{"kind":"human"},"promptSource":"typed"}'
}

@test "owner-reply #1059: --relayed passes for the owner's answer after the report (compact summary in between)" {
  add_report "2026-10-15T07:34:00.000Z"
  add_summary
  add_owner
  run_check --relayed "$SID" "$OWNER_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MATCH: 2026-10-15T08:32:56.042Z 1034は許容"* ]] || return 1
  [[ "$output" == *"MATCHES=1"* ]] || return 1
}

@test "owner-reply #1059: --relayed treats +00:00 and Z as the same time" {
  add_report "2026-10-15T07:34:00.000Z"
  add_owner
  run_check --relayed "$SID" "$OWNER_UUID" "2026-10-15T07:00:00+00:00" "$STOP_URL"
  [ "$status" -eq 0 ]
}

@test "owner-reply #1059: --relayed reports not-found for a uuid that is not in the log" {
  add_report "2026-10-15T07:34:00.000Z"
  add_owner
  run_check --relayed "$SID" "99999999-9999-4999-8999-999999999999" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REASON=not-found"* ]] || return 1
  [[ "$output" == *"MATCHES=0"* ]] || return 1
}

relayed_not_owner() {  # $1 = the line to point at (uuid 55555555-...)
  add_report "2026-10-15T07:34:00.000Z"
  add "$1"
  run_check --relayed "$SID" "55555555-5555-4555-8555-555555555555" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REASON=not-owner"* ]] || return 1
  [[ "$output" == *"MATCHES=0"* ]] || return 1
}

@test "owner-reply #1059: --relayed not-owner for a tool result" {
  relayed_not_owner '{"type":"user","isSidechain":false,"uuid":"55555555-5555-4555-8555-555555555555","timestamp":"2026-10-15T08:32:00.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"1034は許容"}]}}'
}

@test "owner-reply #1059: --relayed not-owner for the parent's own message" {
  relayed_not_owner '{"type":"assistant","isSidechain":false,"uuid":"55555555-5555-4555-8555-555555555555","timestamp":"2026-10-15T08:32:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"1034は許容として送る"}]}}'
}

@test "owner-reply #1059: --relayed not-owner for a compact summary" {
  relayed_not_owner '{"type":"user","isSidechain":false,"isCompactSummary":true,"isVisibleInTranscriptOnly":true,"uuid":"55555555-5555-4555-8555-555555555555","timestamp":"2026-10-15T08:32:00.000Z","message":{"role":"user","content":"This session is being continued from a previous conversation. 1034は許容"}}'
}

@test "owner-reply #1059: --relayed not-owner for an isMeta line (hook injection)" {
  relayed_not_owner '{"type":"user","isSidechain":false,"isMeta":true,"uuid":"55555555-5555-4555-8555-555555555555","timestamp":"2026-10-15T08:32:00.000Z","message":{"role":"user","content":"1034は許容"}}'
}

@test "owner-reply #1059: --relayed not-owner for an isSidechain line" {
  relayed_not_owner '{"type":"user","isSidechain":true,"origin":{"kind":"human"},"uuid":"55555555-5555-4555-8555-555555555555","timestamp":"2026-10-15T08:32:00.000Z","message":{"role":"user","content":"1034は許容"}}'
}

@test "owner-reply #1059: --relayed not-owner for a reply typed with the owner-reply head" {
  relayed_not_owner '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"55555555-5555-4555-8555-555555555555","timestamp":"2026-10-15T08:32:00.000Z","message":{"role":"user","content":"主の返事（親エピック #900 経由）: 許容"}}'
}

@test "owner-reply #1059: --relayed not-owner for a reply typed with the parent-epic head" {
  relayed_not_owner '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"55555555-5555-4555-8555-555555555555","timestamp":"2026-10-15T08:32:00.000Z","message":{"role":"user","content":"親エピック #900 から: 主が会話で『許容』と返した"}}'
}

@test "owner-reply #1059: --relayed not-owner for a launch instruction" {
  relayed_not_owner '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"55555555-5555-4555-8555-555555555555","timestamp":"2026-10-15T08:32:00.000Z","message":{"role":"user","content":"<command-name>/develop</command-name>\n<command-args>#1038 （エピック #900 の子。返事を受けて起動し直し） 主の返事（親エピック #900 経由）: 許容</command-args>"}}'
}

@test "owner-reply #1059: --relayed reports not-after for an owner message before the stop record" {
  add_owner "2026-10-15T06:59:59.000Z"
  add_report "2026-10-15T07:34:00.000Z"
  run_check --relayed "$SID" "$OWNER_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REASON=not-after"* ]] || return 1
}

@test "owner-reply #1059: --relayed reports not-asked when no parent message has the stop record URL" {
  add '{"type":"assistant","isSidechain":false,"uuid":"33333333-3333-4333-8333-333333333339","timestamp":"2026-10-15T07:34:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"子 #1030 が止まった。停止の記録: https://github.com/oratta/claude-harness/issues/1030#issuecomment-2222222222"}]}}'
  add_owner
  run_check --relayed "$SID" "$OWNER_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REASON=not-asked"* ]] || return 1
}

@test "owner-reply #1059: --relayed reports not-asked when the URL appears only before the stop record" {
  add_report "2026-10-15T06:30:00.000Z"
  add_owner
  run_check --relayed "$SID" "$OWNER_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REASON=not-asked"* ]] || return 1
}

@test "owner-reply #1059: --relayed reports not-asked when the URL appears only in a subagent message" {
  add_report "2026-10-15T07:34:00.000Z" true
  add_owner
  run_check --relayed "$SID" "$OWNER_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REASON=not-asked"* ]] || return 1
}

@test "owner-reply #1059: --relayed reports not-asked when the URL appears only after the owner's answer" {
  add_owner
  add_report "2026-10-15T08:40:00.000Z"
  run_check --relayed "$SID" "$OWNER_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REASON=not-asked"* ]] || return 1
}

@test "owner-reply #1059: --relayed with three arguments gives exit 2" {
  add_report "2026-10-15T07:34:00.000Z"
  add_owner
  run_check --relayed "$SID" "$OWNER_UUID" "$STOP_AT"
  [ "$status" -eq 2 ]
}

@test "owner-reply #1059: --relayed with a uuid that is not a UUID gives exit 2" {
  add_report "2026-10-15T07:34:00.000Z"
  add_owner
  run_check --relayed "$SID" "56c1ea83" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 2 ]
}

@test "owner-reply #1059: --relayed with an unreadable stop time gives exit 2" {
  add_report "2026-10-15T07:34:00.000Z"
  add_owner
  run_check --relayed "$SID" "$OWNER_UUID" "yesterday" "$STOP_URL"
  [ "$status" -eq 2 ]
}

@test "owner-reply #1059: --relayed with a URL that is not https gives exit 2" {
  add_report "2026-10-15T07:34:00.000Z"
  add_owner
  run_check --relayed "$SID" "$OWNER_UUID" "$STOP_AT" "issues/1034#issuecomment-1"
  [ "$status" -eq 2 ]
}

@test "owner-reply #1059: --relayed with a missing log gives exit 2" {
  run_check --relayed "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee" "$OWNER_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 2 ]
}

@test "owner-reply #1059: --relayed with an unreadable timestamp on the pointed line gives exit 2" {
  add_report "2026-10-15T07:34:00.000Z"
  add_owner "not-a-time"
  run_check --relayed "$SID" "$OWNER_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 2 ]
}
