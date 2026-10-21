#!/usr/bin/env bats
#
# usage-probe.sh の reset_grants 欄（snapshot の accounts.<id>.reset_grants）
#
# spec: dev-workflow-escalation-tripwires（usage-probe と snapshot 契約）
# 実ホームの snapshot・Keychain には触れない。応答は USAGE_PROBE_RESPONSE_FILE[_<ID>] で与える。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PROBE="${PLUGIN_DIR}/scripts/usage-probe.sh"
  WORK="$(mktemp -d)"
  SNAP="${WORK}/.usage-snapshot"
  ACCOUNTS="${WORK}/accounts.json"
  NOW=1000000000
  export CLAUDE_ACCOUNTS_FILE="$ACCOUNTS"
  export USAGE_SNAPSHOT="$SNAP"
  export USAGE_SESSIONS_DIR="${WORK}/sessions"
  export USAGE_PROBE_STATE="${WORK}/probe-state.json"
  export USAGE_PROBE_LOCK="${WORK}/probe.lock"
  export USAGE_PROBE_NOW="$NOW"
  unset USAGE_PROBE_RESPONSE_FILE USAGE_PROBE_STATUS CLAUDE_SECURESTORAGE_CONFIG_DIR
}

teardown() {
  rm -rf "${WORK:?}"
}

# $1=出力先 $2=cedar_ember の JSON（空なら cedar_ember なし）
write_resp() {
  local ce=""
  [ -n "$2" ] && ce=", \"cedar_ember\": $2"
  cat > "$1" <<JSON
{ "five_hour": { "utilization": 10, "resets_at": "2026-09-04T12:00:00+00:00" },
  "seven_day": { "utilization": 20, "resets_at": "2026-09-06T00:00:00+00:00" }${ce} }
JSON
}

registry() {  # $@=slot ids
  local ids=("$@") out="" id
  for id in "${ids[@]}"; do
    out+="{\"id\":\"$id\",\"label\":\"$id\",\"securestorage\":\"${WORK}/sec-$id\"},"
  done
  printf '{"schema":1,"accounts":[%s]}' "${out%,}" > "$ACCOUNTS"
}

grants_of() {  # $1=slot → compact JSON か "absent"
  jq -c --arg id "$1" '(.accounts[$id] | if has("reset_grants") then .reset_grants else "absent" end)' "$SNAP"
}

# 既存 snapshot（a と b が使用率と reset_grants を持つ）
write_prev_snapshot() {
  cat > "$SNAP" <<'JSON'
{"schema":2,"active":"a","fetched_at":5,"five_hour_pct":1,"accounts":{
 "a":{"label":"a","securestorage":null,"fetched_at":5,"five_hour_pct":1,"weekly_all_pct":2,
      "reset_grants":[{"resets_left":9,"ends_at":null,"paused":false}]},
 "b":{"label":"b","securestorage":null,"fetched_at":6,"five_hour_pct":3,"weekly_all_pct":4,
      "reset_grants":[{"resets_left":8,"ends_at":null,"paused":false}]},
 "c":{"label":"c","securestorage":null,"fetched_at":7,"five_hour_pct":5,"weekly_all_pct":6,
      "reset_grants":[{"resets_left":7,"ends_at":null,"paused":false}]}}}
JSON
}

@test "copies grants verbatim (only the three keys, order kept, nulls kept)" {
  registry a
  write_resp "${WORK}/r.json" '{"eligible":true,"grants":[
    {"id":"x","type":"weekly","resets_left":1,"ends_at":"2026-11-02T03:00:00.123Z","paused":false,"label":"L"},
    {"id":"y","resets_left":0,"ends_at":null,"paused":true},
    {"resets_left":2}]}'
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(grants_of a)" = '[{"resets_left":1,"ends_at":"2026-11-02T03:00:00.123Z","paused":false},{"resets_left":0,"ends_at":null,"paused":true},{"resets_left":2}]' ]
}

@test "no reset_grants when cedar_ember is missing, null, ineligible, or grants is not an array" {
  registry a
  local ce
  for ce in '' 'null' '{"eligible":false,"grants":[]}' '{"grants":[]}' '{"eligible":true,"grants":"x"}' '{"eligible":true}' '"str"'; do
    rm -f "$SNAP" "$USAGE_PROBE_STATE"
    write_resp "${WORK}/r.json" "$ce"
    USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
    [ "$status" -eq 0 ]
    [ "$(jq '.accounts.a.five_hour_pct' "$SNAP")" = "10" ]
    [ "$(grants_of a)" = '"absent"' ]
  done
}

@test "originally empty grants is []" {
  registry a
  write_resp "${WORK}/r.json" '{"eligible":true,"grants":[]}'
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$(grants_of a)" = '[]' ]
}

@test "grants whose every element is invalid has no field; partly invalid keeps the valid ones" {
  registry a
  write_resp "${WORK}/r.json" '{"eligible":true,"grants":[null,3]}'
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$(grants_of a)" = '"absent"' ]
  rm -f "$SNAP" "$USAGE_PROBE_STATE"
  write_resp "${WORK}/r.json" '{"eligible":true,"grants":[null,{"resets_left":1,"ends_at":null,"paused":false}]}'
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$(grants_of a)" = '[{"resets_left":1,"ends_at":null,"paused":false}]' ]
}

@test "a failed single slot drops its previous reset_grants and keeps the rest" {
  registry a
  write_prev_snapshot
  write_resp "${WORK}/r.json" '{"eligible":true,"grants":[]}'
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_STATUS_A=429 run "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(grants_of a)" = '"absent"' ]
  [ "$(jq '.accounts.a.five_hour_pct, .accounts.a.fetched_at' "$SNAP" | tr '\n' ' ')" = "1 5 " ]
}

@test "all slots failing still drops the failed slots' reset_grants, nothing else changes" {
  registry a b
  write_prev_snapshot
  write_resp "${WORK}/r.json" '{"eligible":true,"grants":[]}'
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_STATUS=429 run "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(grants_of a)" = '"absent"' ]
  [ "$(grants_of b)" = '"absent"' ]
  [ "$(jq -c '[.fetched_at,.five_hour_pct,.accounts.a.fetched_at,.accounts.b.five_hour_pct,.accounts.b.weekly_all_pct]' "$SNAP")" = "[5,1,5,3,4]" ]
  [ "$(grants_of c)" = '[{"resets_left":7,"ends_at":null,"paused":false}]' ]
}

@test "partial failure plus untried: A rebuilt, B dropped, C kept" {
  registry a b c
  write_prev_snapshot
  printf '{"slots":{"c":{"last_attempt":%s,"consecutive_429":0}}}' "$((NOW - 60))" > "$USAGE_PROBE_STATE"
  write_resp "${WORK}/ra.json" '{"eligible":true,"grants":[{"resets_left":1,"ends_at":null,"paused":false}]}'
  write_resp "${WORK}/rb.json" ''
  USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
    USAGE_PROBE_STATUS_B=500 run "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(grants_of a)" = '[{"resets_left":1,"ends_at":null,"paused":false}]' ]
  [ "$(grants_of b)" = '"absent"' ]
  [ "$(grants_of c)" = '[{"resets_left":7,"ends_at":null,"paused":false}]' ]
  [ "$(jq '.accounts.b.five_hour_pct' "$SNAP")" = "3" ]
}

@test "all failing with no reset_grants to drop leaves the snapshot untouched" {
  registry a
  printf '{"schema":2,"active":"a","accounts":{"a":{"label":"a","fetched_at":5,"five_hour_pct":1}}}' > "$SNAP"
  cp "$SNAP" "${WORK}/before"
  write_resp "${WORK}/r.json" ''
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_STATUS=429 run "$PROBE"
  [ "$status" -eq 0 ]
  cmp -s "$SNAP" "${WORK}/before"
}

@test "all failing with no snapshot writes nothing" {
  registry a
  write_resp "${WORK}/r.json" ''
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_STATUS=429 run "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -e "$SNAP" ]
}

@test "an untried slot keeps its previous reset_grants when another slot succeeds" {
  registry a c
  write_prev_snapshot
  printf '{"slots":{"c":{"last_attempt":%s,"consecutive_429":0}}}' "$((NOW - 60))" > "$USAGE_PROBE_STATE"
  write_resp "${WORK}/ra.json" ''
  USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" run "$PROBE"
  [ "$(grants_of a)" = '"absent"' ]
  [ "$(grants_of c)" = '[{"resets_left":7,"ends_at":null,"paused":false}]' ]
}

@test "a cedar_ember-only response is a failure: usage kept, no reset_grants" {
  registry a
  write_prev_snapshot
  printf '{"cedar_ember":{"eligible":true,"grants":[{"resets_left":1}]}}' > "${WORK}/r.json"
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq '.accounts.a.five_hour_pct, .accounts.a.fetched_at' "$SNAP" | tr '\n' ' ')" = "1 5 " ]
  [ "$(grants_of a)" = '"absent"' ]
}

@test "a response missing five_hour keeps the old rule: five_hour_pct null, weekly set, reset_grants written" {
  registry a
  printf '{"seven_day":{"utilization":33,"resets_at":"2026-09-06T00:00:00+00:00"},"cedar_ember":{"eligible":true,"grants":[]}}' > "${WORK}/r.json"
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$(jq -c '[.accounts.a.five_hour_pct,.accounts.a.weekly_all_pct]' "$SNAP")" = "[null,33]" ]
  [ "$(grants_of a)" = '[]' ]
}

@test "the default endpoint carries the cedar_ember query" {
  run grep -F 'ENDPOINT="${USAGE_PROBE_ENDPOINT:-https://api.anthropic.com/api/oauth/usage?cedar_ember=1&skip_spend=1}"' "$PROBE"
  [ "$status" -eq 0 ]
}
