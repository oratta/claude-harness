#!/usr/bin/env bats
#
# 主の委任の合否（issue #1293）。
# spec: dev-workflow-owner-reply-check「owner-reply-check.sh --delegated は主の委任の確認を親の会話ログの場所で確かめる」
#       「--delegated の守備範囲」「主の委任の合否を、名指しの許容と混在したログで機械的に固定する」
# 親の会話ログ 1 本に、委任の記録より前の名指しの許容・委任の記録より後で親の問いより前の別の主の発言・
# 委任の記録を示した親の問い・主の委任の確認・その後の停止を並べ、--delegated と --relayed を当てる。
# 固定するのは owner-reply-check.sh の出力と終了コードまで。GitHub 上の確かめ（委任の記録の書式・投稿者・最新か・
# 編集の有無・エピックが開いているか・子の所属・停止の記録の推奨）は呼び出し側の手順なので対象外。
# 実行: scripts/test.sh owner-reply-delegated-scenario
# OWNER_REPLY_SCRIPT で対象のスクリプトを差し替えられる。

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

  DELEG_AT="2026-10-23T11:03:32Z"
  DELEG_URL="https://github.com/oratta/claude-harness/issues/1038#issuecomment-6363422938"
  STOP_AT="2026-10-23T11:10:00Z"          # 確認より後の停止
  EARLY_STOP_AT="2026-10-23T11:05:30Z"    # 確認より前の停止（委任の記録より後）
  STOP_URL="https://github.com/oratta/claude-harness/issues/1245#issuecomment-6363448774"
  NAMED_UUID="aaaaaaaa-0000-4000-8000-000000000001"     # 委任の記録より前の、別の子だけを名指しした許容
  BEFORE_ASK_UUID="aaaaaaaa-0000-4000-8000-000000000002" # 委任の記録より後で親の問いより前の別の主の発言
  ASK_UUID="cccccccc-0000-4000-8000-000000000001"        # 親の問い
  CONFIRM_UUID="bbbbbbbb-0000-4000-8000-000000000001"    # 主の委任の確認
  AFTER_UUID="cccccccc-0000-4000-8000-000000000002"      # 確認のあとの親の発言
}

add() { printf '%s\n' "$1" >> "$LOG"; }

owner_line() {  # $1 = uuid, $2 = timestamp, $3 = 本文
  add '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"'"$1"'","timestamp":"'"$2"'","message":{"role":"user","content":"'"$3"'"}}'
}
parent_line() {  # $1 = uuid, $2 = timestamp, $3 = 本文
  add '{"type":"assistant","isSidechain":false,"uuid":"'"$1"'","timestamp":"'"$2"'","message":{"role":"assistant","content":[{"type":"text","text":"'"$3"'"}]}}'
}
ask_with() {  # $1 = 親の問いに書く URL
  parent_line "$ASK_UUID" "2026-10-23T11:05:00.000Z" "委任の記録: $1 この範囲で子のリスク許容を任せてよいか。答え方: 親のタブで 任せる を、この問いの直後に別の発言を挟まずに打つ"
}

# 並び: 名指しの許容（10:00）→ 委任の記録（11:03:32）→ 別の主の発言（11:04）→ 親の問い（11:05）→ 確認（11:06）
#       → 親の発言（11:06:30）→ 停止（11:10）
build_log() {  # $1 = 親の問いの URL（既定は委任の記録の URL）, $2 = 確認の本文（既定は「任せる」）
  owner_line "$NAMED_UUID" "2026-10-23T10:00:00.000Z" "1034は許容"
  owner_line "$BEFORE_ASK_UUID" "2026-10-23T11:04:00.000Z" "1238 の件はあとで見る"
  ask_with "${1:-$DELEG_URL}"
  owner_line "$CONFIRM_UUID" "2026-10-23T11:06:00.000Z" "${2:-任せる}"
  parent_line "$AFTER_UUID" "2026-10-23T11:06:30.000Z" "委任を受け取った"
}

delegated() {  # $1 = uuid, $2 = 停止の記録の作成日時（既定は STOP_AT）
  run bash "$SCRIPT" --delegated "$SID" "$1" "$DELEG_AT" "$DELEG_URL" "${2:-$STOP_AT}"
}

expect_fail() {  # $1 = REASON
  [ "$status" -eq 1 ] || return 1
  [[ "$output" == *"REASON=$1"* ]] || return 1
  [[ "$output" == *"MATCHES=0"* ]] || return 1
  [[ "$output" != *"MATCH: "* ]] || return 1
}

expect_pass() {  # $1 = MATCH の行に出る本文
  [ "$status" -eq 0 ] || return 1
  [[ "$output" == *"MATCH: 2026-10-23T11:06:00.000Z $1"* ]] || return 1
  [[ "$output" == *"MATCHES=1"* ]] || return 1
  [[ "$output" != *"REASON="* ]] || return 1
}

# ---- 名指しの許容と混在したログでの合否

@test "delegated scenario: the confirmation before the stop record passes" {
  build_log
  delegated "$CONFIRM_UUID"
  expect_pass "任せる"
}

@test "delegated scenario: a named acceptance of another child before the delegation fails on both paths with not-after" {
  build_log
  delegated "$NAMED_UUID"
  expect_fail not-after
  run bash "$SCRIPT" --relayed "$SID" "$NAMED_UUID" "$STOP_AT" "$STOP_URL"
  expect_fail not-after
}

@test "delegated scenario: the delegation confirmation itself fails on --relayed with not-after" {
  build_log
  run bash "$SCRIPT" --relayed "$SID" "$CONFIRM_UUID" "$STOP_AT" "$STOP_URL"
  expect_fail not-after
}

@test "delegated scenario: a confirmation after the stop record is not-before" {
  build_log
  delegated "$CONFIRM_UUID" "$EARLY_STOP_AT"
  expect_fail not-before
}

@test "delegated scenario: another owner message between the ask and the confirmation is not-direct" {
  owner_line "$NAMED_UUID" "2026-10-23T10:00:00.000Z" "1034は許容"
  ask_with "$DELEG_URL"
  owner_line "aaaaaaaa-0000-4000-8000-000000000003" "2026-10-23T11:05:30.000Z" "ちょっと待って"
  owner_line "$CONFIRM_UUID" "2026-10-23T11:06:00.000Z" "任せる"
  delegated "$CONFIRM_UUID"
  expect_fail not-direct
}

@test "delegated scenario: a parent message with only a longer URL (digits appended) is not-asked" {
  build_log "${DELEG_URL}0"
  delegated "$CONFIRM_UUID"
  expect_fail not-asked
}

@test "delegated scenario: an owner message after the delegation record but before the ask does not block the confirmation" {
  build_log
  # 別の主の発言（11:04）が委任の記録より後で親の問いより前にある
  grep -q "$BEFORE_ASK_UUID" "$LOG"
  delegated "$CONFIRM_UUID"
  expect_pass "任せる"
  delegated "$BEFORE_ASK_UUID"
  expect_fail not-asked
}

# ---- --delegated の個々の落ち方

@test "delegated: wrong number of arguments gives exit 2" {
  build_log
  run bash "$SCRIPT" --delegated "$SID" "$CONFIRM_UUID" "$DELEG_AT" "$DELEG_URL"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: "*"--delegated"* ]] || return 1
  run bash "$SCRIPT" --delegated "$SID" "$CONFIRM_UUID" "$DELEG_AT" "$DELEG_URL" "$STOP_AT" extra
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: "*"--delegated"* ]] || return 1
}

@test "delegated: a session id or uuid that is not a UUID gives exit 2" {
  build_log
  run bash "$SCRIPT" --delegated "0a1b2c3d" "$CONFIRM_UUID" "$DELEG_AT" "$DELEG_URL" "$STOP_AT"
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" --delegated "$SID" "bbbbbbbb" "$DELEG_AT" "$DELEG_URL" "$STOP_AT"
  [ "$status" -eq 2 ]
}

@test "delegated: an unreadable delegation record time or stop record time gives exit 2" {
  build_log
  run bash "$SCRIPT" --delegated "$SID" "$CONFIRM_UUID" "yesterday" "$DELEG_URL" "$STOP_AT"
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" --delegated "$SID" "$CONFIRM_UUID" "$DELEG_AT" "$DELEG_URL" "2026-10-23T11:10:00"
  [ "$status" -eq 2 ]
}

@test "delegated: a delegation record URL that does not start with https:// gives exit 2" {
  build_log
  run bash "$SCRIPT" --delegated "$SID" "$CONFIRM_UUID" "$DELEG_AT" "issues/1038#issuecomment-6363422938" "$STOP_AT"
  [ "$status" -eq 2 ]
}

@test "delegated: a uuid that is not in the log is not-found" {
  build_log
  delegated "99999999-9999-4999-8999-999999999999"
  expect_fail not-found
}

@test "delegated: the parent's own message is not-owner" {
  build_log
  delegated "$AFTER_UUID"
  expect_fail not-owner
}

@test "delegated: a tool result, isMeta, isSidechain, compact summary and head-typed reply are not-owner" {
  local u="dddddddd-0000-4000-8000-000000000001"
  for line in \
    '{"type":"user","isSidechain":false,"uuid":"'"$u"'","timestamp":"2026-10-23T11:06:10.000Z","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"任せる"}]}}' \
    '{"type":"user","isSidechain":false,"isMeta":true,"uuid":"'"$u"'","timestamp":"2026-10-23T11:06:10.000Z","message":{"role":"user","content":"任せる"}}' \
    '{"type":"user","isSidechain":true,"origin":{"kind":"human"},"uuid":"'"$u"'","timestamp":"2026-10-23T11:06:10.000Z","message":{"role":"user","content":"任せる"}}' \
    '{"type":"user","isSidechain":false,"isCompactSummary":true,"uuid":"'"$u"'","timestamp":"2026-10-23T11:06:10.000Z","message":{"role":"user","content":"任せる"}}' \
    '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"uuid":"'"$u"'","timestamp":"2026-10-23T11:06:10.000Z","message":{"role":"user","content":"主の返事（親エピック #1038 経由）: 任せる"}}'
  do
    : > "$LOG"
    build_log
    add "$line"
    delegated "$u"
    expect_fail not-owner || return 1
  done
}

@test "delegated: an owner message at or before the delegation record time is not-after (Z and +00:00 are the same)" {
  owner_line "$CONFIRM_UUID" "2026-10-23T11:03:32.000Z" "任せる"
  run bash "$SCRIPT" --delegated "$SID" "$CONFIRM_UUID" "2026-10-23T11:03:32+00:00" "$DELEG_URL" "$STOP_AT"
  expect_fail not-after
}

@test "delegated: a URL only before the delegation record time is not-asked" {
  parent_line "$ASK_UUID" "2026-10-23T11:03:00.000Z" "委任の記録: $DELEG_URL"
  owner_line "$CONFIRM_UUID" "2026-10-23T11:06:00.000Z" "任せる"
  delegated "$CONFIRM_UUID"
  expect_fail not-asked
}

@test "delegated: a URL only in a subagent message is not-asked" {
  add '{"type":"assistant","isSidechain":true,"uuid":"'"$ASK_UUID"'","timestamp":"2026-10-23T11:05:00.000Z","message":{"role":"assistant","content":[{"type":"text","text":"委任の記録: '"$DELEG_URL"'"}]}}'
  owner_line "$CONFIRM_UUID" "2026-10-23T11:06:00.000Z" "任せる"
  delegated "$CONFIRM_UUID"
  expect_fail not-asked
}

@test "delegated: the stop record URL in the ask does not stand in for the delegation record URL" {
  ask_with "$STOP_URL"
  owner_line "$CONFIRM_UUID" "2026-10-23T11:06:00.000Z" "任せる"
  delegated "$CONFIRM_UUID"
  expect_fail not-asked
}

@test "delegated: the confirmation exactly at the stop record time is not-before" {
  build_log
  delegated "$CONFIRM_UUID" "2026-10-23T11:06:00+00:00"
  expect_fail not-before
}

@test "delegated: the words of acceptance are not read (a refusal passes and is printed in full)" {
  build_log "" "任せない"
  delegated "$CONFIRM_UUID"
  expect_pass "任せない"
}

@test "delegated: does not change --relayed for an answer to a stop report" {
  parent_line "$ASK_UUID" "2026-10-23T11:12:00.000Z" "子 #1245 が止まった。停止の記録: $STOP_URL"
  owner_line "$CONFIRM_UUID" "2026-10-23T11:13:00.000Z" "許容"
  run bash "$SCRIPT" --relayed "$SID" "$CONFIRM_UUID" "$STOP_AT" "$STOP_URL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MATCHES=1"* ]] || return 1
}
