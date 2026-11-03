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
  # テスト経路で headroom を呼ばせる専用の変数（未設定の既存テストは headroom を呼ばない）
  export USAGE_PROBE_HEADROOM=1
  # User-Agent を固定し、claude の版を探させない（PATH に claude が無い CI では、版を取れなかった
  # 警告が標準エラーに出て、headroom の出力が漏れないことを確かめるテストの $output に混ざる）
  export USAGE_PROBE_USER_AGENT='claude-cli/2.1.0 (external, cli)'
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
  [ "$(jq -c 'keys_unsorted' "$HEADROOM")" = '["schema","computed_at","settings","best","best_by_provider","accounts"]' ]
  [ "$(jq '.computed_at' "$HEADROOM")" = "$NOW" ]
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

@test "test overrides without USAGE_PROBE_HEADROOM do not call headroom" {
  # 書き先を明示していても、専用の変数が無ければ headroom を呼ばない（本来の書き先にも書かない）
  USAGE_PROBE_HEADROOM= USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$status" -eq 0 ]
  [ -f "$SNAP" ]
  [ ! -e "$HEADROOM" ]
  # 書き先も Codex の home も未設定なら、HOME の下の既定の書き先にも書かない
  mkdir -p "${WORK}/home/.claude"
  rm -f "$SNAP" "$USAGE_PROBE_STATE"
  HOME="${WORK}/home" CLAUDE_CONFIG_DIR= CODEX_HOME= USAGE_PROBE_HEADROOM= \
    USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" run "$PROBE"
  [ "$status" -eq 0 ]
  [ -f "$SNAP" ]
  [ ! -e "${WORK}/home/.claude/.headroom.json" ]
  [ ! -e "$HEADROOM" ]
}
