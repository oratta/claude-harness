#!/usr/bin/env bats
#
# usage-probe.sh が snapshot を書いた直後に headroom.py write --refresh-codex を呼ぶ
#
# spec: dev-workflow-headroom（usage-probe が snapshot を書いた直後に headroom を書く）
# 実ホームの snapshot・Keychain・~/.codex には触れない。Codex は CODEX_HOME を存在しない
# ディレクトリにして取りに行かせない（既定の home が無い扱い）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PROBE="${PLUGIN_DIR}/scripts/usage-probe.sh"
  WORK="$(mktemp -d)"
  SNAP="${WORK}/.usage-snapshot"
  ACCOUNTS="${WORK}/accounts.json"
  HEADROOM="${WORK}/.headroom.json"
  NOW=1000000000
  export CLAUDE_CONFIG_DIR="$WORK"
  export CLAUDE_ACCOUNTS_FILE="$ACCOUNTS"
  export USAGE_SNAPSHOT="$SNAP"
  export USAGE_SESSIONS_DIR="${WORK}/sessions"
  export USAGE_PROBE_STATE="${WORK}/probe-state.json"
  export USAGE_PROBE_LOCK="${WORK}/probe.lock"
  export USAGE_PROBE_NOW="$NOW"
  export CODEX_HOME="${WORK}/no-codex-home"
  unset USAGE_PROBE_RESPONSE_FILE USAGE_PROBE_STATUS CLAUDE_SECURESTORAGE_CONFIG_DIR \
    HEADROOM_7D_CAP_PCT HEADROOM_NORMAL_RATE_PCT_PER_DAY
  printf '{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":"%s/sec-a"},{"id":"b","label":"B","securestorage":"%s/sec-b"}]}' \
    "$WORK" "$WORK" > "$ACCOUNTS"
  cat > "${WORK}/r.json" <<'JSON'
{ "five_hour": { "utilization": 10, "resets_at": "2026-09-04T12:00:00+00:00" },
  "seven_day": { "utilization": 20, "resets_at": "2026-09-06T00:00:00+00:00" } }
JSON
}

teardown() {
  rm -rf "${WORK:?}"
}

@test "probe writes .headroom.json in schema 1 after the snapshot" {
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$status" -eq 0 ]
  [ -f "$SNAP" ]
  [ "$(jq '.schema' "$HEADROOM")" = "1" ]
  [ "$(jq -c '[.accounts[] | [.provider, .account, .status]]' "$HEADROOM")" = '[["claude","a","ok"],["claude","b","ok"]]' ]
  [ "$(jq -c '.settings' "$HEADROOM")" = '{"cap_7d_pct":90,"normal_rate_pct_per_day":null}' ]
}

@test "an invalid HEADROOM_7D_CAP_PCT does not fail the probe and writes only the snapshot" {
  HEADROOM_7D_CAP_PCT=abc USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -f "$SNAP" ]
  [ ! -e "$HEADROOM" ]
}

@test "all slots failing with no reset_grants to drop writes no snapshot and no headroom" {
  printf '{"schema":2,"active":"a","accounts":{"a":{"label":"A","fetched_at":5,"five_hour_pct":1}}}' > "$SNAP"
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_STATUS=429 run "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -e "$HEADROOM" ]
}

@test "all slots failing still calls headroom when the snapshot is rewritten to drop reset_grants" {
  printf '{"schema":2,"active":"a","accounts":{"a":{"label":"A","fetched_at":5,"weekly_all_pct":2,"weekly_resets_epoch":%s,"reset_grants":[{"resets_left":1,"ends_at":null,"paused":false}]}}}' \
    "$((NOW + 86400))" > "$SNAP"
  USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_STATUS=429 run "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.accounts.a | has("reset_grants")' "$SNAP")" = "false" ]
  [ "$(jq '.schema' "$HEADROOM")" = "1" ]
}

@test "test overrides without CLAUDE_CONFIG_DIR and CODEX_HOME do not write the real .headroom.json" {
  mkdir -p "${WORK}/home/.claude"
  HOME="${WORK}/home" CLAUDE_CONFIG_DIR= USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$status" -eq 0 ]
  [ -f "$SNAP" ]
  [ ! -e "${WORK}/home/.claude/.headroom.json" ]
  unset CODEX_HOME
  HOME="${WORK}/home" USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -e "${WORK}/home/.claude/.headroom.json" ]
}
