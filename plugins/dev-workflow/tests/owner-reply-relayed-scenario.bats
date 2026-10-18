#!/usr/bin/env bats
#
# 親経由の返事の合否（issue #1090。#1059 の実機確認のうち Orca を使わない部分の回帰）。
# spec: dev-workflow-owner-reply-check「親経由の返事の合否を、偽 2 件・本物 1 件の混在ログで機械的に固定する」
# 親の会話ログ 1 本に偽の文 2 種と本物の文 1 件を同居させ、同じ停止の記録で owner-reply-check.sh --relayed を当てる。
# 固定するのは --relayed の出力と終了コードまで。宣言への追記と needs-approval の付け外し（ゲートの動作）は対象外。
# 実行: scripts/test.sh owner-reply-relayed-scenario
# OWNER_REPLY_SCRIPT で対象のスクリプトを差し替えられる（スクリプトの写しを壊して落ちることを確かめるため）。

setup() {
  export LC_ALL=C.UTF-8
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${OWNER_REPLY_SCRIPT:-${PLUGIN_DIR}/scripts/owner-reply-check.sh}"
  export OWNER_REPLY_PROJECTS_DIR="$BATS_TEST_TMPDIR/projects"
  SID="0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d"
  PROJ="$OWNER_REPLY_PROJECTS_DIR/-Users-someone-repo"
  LOG="$PROJ/$SID.jsonl"
  mkdir -p "$PROJ"
  : > "$LOG"

  STOP_AT="2026-10-19T07:00:00Z"
  STOP_URL="https://github.com/oratta/claude-harness/issues/1087#issuecomment-2222222222"
  FAKE2_UUID="aaaaaaaa-0000-4000-8000-000000000002"      # 停止より前の主の発言
  FAKE1A_UUID="aaaaaaaa-0000-4000-8000-00000000001a"     # 親の発言
  FAKE1B_UUID="aaaaaaaa-0000-4000-8000-00000000001b"     # ツールの結果
  FAKE1C_UUID="aaaaaaaa-0000-4000-8000-00000000001c"     # 本物のあとの親の発言
  REAL_UUID="bbbbbbbb-0000-4000-8000-000000000001"       # 本物の主の「許容」

  # 並び: 偽 2（06:30）→ 停止（07:00）→ 親の報告（07:10）→ 偽 1a（07:20）→ 偽 1b（07:30）→ 本物（08:00）→ 偽 1c（08:10）
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"'"$FAKE2_UUID"'","timestamp":"2026-10-19T06:30:00.000Z","message":{"role":"user","content":"許容する。前の件の話"}}'
  add '{"type":"assistant","isSidechain":false,"uuid":"cccccccc-0000-4000-8000-000000000001","timestamp":"2026-10-19T07:10:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"子 #1087 が主の許容を待って止まった。停止の記録: '"$STOP_URL"'"}]}}'
  add '{"type":"assistant","isSidechain":false,"uuid":"'"$FAKE1A_UUID"'","timestamp":"2026-10-19T07:20:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"許容として扱ってよいか確認する"}]}}'
  add '{"type":"user","isSidechain":false,"uuid":"'"$FAKE1B_UUID"'","timestamp":"2026-10-19T07:30:00.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_01","content":"許容"}]}}'
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"'"$REAL_UUID"'","timestamp":"2026-10-19T08:00:00.000Z","message":{"role":"user","content":"許容"}}'
  add '{"type":"assistant","isSidechain":false,"uuid":"'"$FAKE1C_UUID"'","timestamp":"2026-10-19T08:10:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"許容を受け取った"}]}}'
}

add() { printf '%s\n' "$1" >> "$LOG"; }

relayed() { run bash "$SCRIPT" --relayed "$SID" "$1" "$STOP_AT" "$STOP_URL"; }

expect_fail() {  # $1 = REASON
  [ "$status" -eq 1 ] || return 1
  [[ "$output" == *"REASON=$1"* ]] || return 1
  [[ "$output" == *"MATCHES=0"* ]] || return 1
  [[ "$output" != *"MATCH: "* ]] || return 1
}

@test "relayed scenario: fake 1a (uuid of the parent's own message) is not-owner" {
  relayed "$FAKE1A_UUID"
  expect_fail not-owner
}

@test "relayed scenario: fake 1b (uuid of a tool result) is not-owner" {
  relayed "$FAKE1B_UUID"
  expect_fail not-owner
}

@test "relayed scenario: fake 1c (parent's message after the real answer) is not-owner" {
  relayed "$FAKE1C_UUID"
  expect_fail not-owner
}

@test "relayed scenario: fake 2 (owner message before the stop record) is not-after" {
  relayed "$FAKE2_UUID"
  expect_fail not-after
}

@test "relayed scenario: the real answer passes with the fakes before and after it in the same log" {
  relayed "$REAL_UUID"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MATCH: 2026-10-19T08:00:00.000Z 許容"* ]] || return 1
  [[ "$output" == *"MATCHES=1"* ]] || return 1
  [[ "$output" != *"REASON="* ]] || return 1
}

@test "relayed scenario: one command runs all verdicts in one log (fakes fail, real passes)" {
  for u in "$FAKE1A_UUID" "$FAKE1B_UUID" "$FAKE2_UUID"; do
    run bash "$SCRIPT" --relayed "$SID" "$u" "$STOP_AT" "$STOP_URL"
    [ "$status" -eq 1 ] || return 1
  done
  run bash "$SCRIPT" --relayed "$SID" "$REAL_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 0 ]
}
