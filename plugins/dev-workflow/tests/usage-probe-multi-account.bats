#!/usr/bin/env bats
#
# dev-workflow-usage-probe-multi-account:
#   アカウントレジストリ（accounts.json）と usage-probe.sh の schema 2 / スロット単位 fail-open
#
# spec: usage-account-registry
#       dev-workflow-escalation-tripwires（usage-probe と snapshot 契約）
#
# 既存の usage-probe.bats は 1 スロット時の退行ガードとして無改変で残す。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PROBE="${PLUGIN_DIR}/scripts/usage-probe.sh"
  INIT="${PLUGIN_DIR}/scripts/accounts-init.sh"
  WORK="$(mktemp -d)"
  SNAP="${WORK}/.usage-snapshot"
  ACCOUNTS="${WORK}/accounts.json"
  NOW=1000000000
  # 実環境の ~/.claude（セッション記録・試行状態・ロック）を読み書きしない
  export USAGE_SESSIONS_DIR="${WORK}/sessions"
  export USAGE_PROBE_STATE="${WORK}/probe-state.json"
  export USAGE_PROBE_LOCK="${WORK}/probe.lock"
}

teardown() {
  rm -rf "$WORK"
}

# $1=出力先 $2=5h消化率 $3=7d消化率 $4=Fable週次消化率
write_resp() {
  cat > "$1" <<JSON
{
  "five_hour": { "utilization": $2, "resets_at": "2026-09-04T12:00:00+00:00" },
  "seven_day": { "utilization": $3, "resets_at": "2026-09-06T00:00:00+00:00" },
  "limits": [
    { "kind": "weekly_all", "group": "weekly", "percent": $3, "is_active": false, "scope": null },
    { "kind": "weekly_scoped", "group": "weekly", "percent": $4, "is_active": true,
      "scope": { "model": { "display_name": "Fable" } },
      "resets_at": "2026-09-06T00:00:00+00:00" }
  ]
}
JSON
}

# 2 スロット（a=既定 / b=securestorage 付き）のレジストリを書く
write_two_slot_registry() {
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${WORK}/claude-b" }
] }
JSON
}

# ---------- レジストリ読み取り（--print-slots） ----------

@test "registry: no file degrades to a single default slot" {
  run env CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
  [ "$(printf '%s' "$output" | cut -f4)" = "Claude Code-credentials" ]
}

@test "registry: reads two slots in declaration order" {
  write_two_slot_registry
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | sed -n 1p | cut -f1)" = "a" ]
  [ "$(printf '%s\n' "$output" | sed -n 1p | cut -f2)" = "A" ]
  [ "$(printf '%s\n' "$output" | sed -n 2p | cut -f1)" = "b" ]
}

@test "registry: falls back to CLAUDE_CONFIG_DIR/accounts.json" {
  write_two_slot_registry
  mkdir -p "${WORK}/cfg"
  cp "$ACCOUNTS" "${WORK}/cfg/accounts.json"
  run env -u CLAUDE_ACCOUNTS_FILE CLAUDE_CONFIG_DIR="${WORK}/cfg" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "2" ]
}

@test "registry: a bare top-level array is rejected" {
  printf '[{"id":"a","label":"A","securestorage":null}]' > "$ACCOUNTS"
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
  [ "$(printf '%s' "$output" | cut -f1)" = "default" ]
}

@test "registry: broken JSON degrades to a single default slot" {
  printf 'not json {{{' > "$ACCOUNTS"
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
}

@test "registry: empty accounts array degrades to a single default slot" {
  printf '{"schema":1,"accounts":[]}' > "$ACCOUNTS"
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
}

@test "registry: drops slots without a valid id and keeps the first duplicate" {
  cat > "$ACCOUNTS" <<'JSON'
{ "schema": 1, "accounts": [
  { "label": "NoId" },
  { "id": "bad id!", "label": "Bad" },
  { "id": "a", "label": "First" },
  { "id": "a", "label": "Second" }
] }
JSON
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
  [ "$(printf '%s' "$output" | cut -f2)" = "First" ]
}

@test "registry: label defaults to id when missing" {
  printf '{"schema":1,"accounts":[{"id":"zz","securestorage":null}]}' > "$ACCOUNTS"
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | cut -f2)" = "zz" ]
}

@test "registry: caps the slot list at 8" {
  python3 - "$ACCOUNTS" <<'PY'
import json, sys
json.dump({"schema": 1,
           "accounts": [{"id": "s%d" % i, "label": "S%d" % i, "securestorage": None}
                        for i in range(12)]},
          open(sys.argv[1], "w"))
PY
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "8" ]
}

# ---------- Keychain サービス名の導出 ----------

@test "keychain: default slot maps to the plain service name" {
  printf '{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":""}]}' > "$ACCOUNTS"
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$(printf '%s' "$output" | cut -f4)" = "Claude Code-credentials" ]
}

@test "keychain: securestorage maps to the sha256-suffixed service name" {
  printf '{"schema":1,"accounts":[{"id":"b","label":"B","securestorage":"/tmp/cb"}]}' > "$ACCOUNTS"
  expected="Claude Code-credentials-$(printf '/tmp/cb' | shasum -a 256 | cut -c1-8)"
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$(printf '%s' "$output" | cut -f4)" = "$expected" ]
}

@test "keychain: NFC normalization makes equivalent paths identical" {
  # é: 合成済み (U+00E9) と 結合文字 (e + U+0301)
  python3 - "$ACCOUNTS" <<'PY'
import json, sys
json.dump({"schema": 1, "accounts": [
    {"id": "c1", "label": "C1", "securestorage": "/tmp/café"},
    {"id": "c2", "label": "C2", "securestorage": "/tmp/café"},
]}, open(sys.argv[1], "w"), ensure_ascii=False)
PY
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  s1="$(printf '%s\n' "$output" | sed -n 1p | cut -f4)"
  s2="$(printf '%s\n' "$output" | sed -n 2p | cut -f4)"
  [ "$s1" = "$s2" ]
}

# ---------- snapshot schema 2 ----------

@test "snapshot: writes schema 2 with accounts and active" {
  write_resp "${WORK}/r.json" 55 82 94
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.schema' "$SNAP")" = "2" ]
  [ "$(jq -r '.active' "$SNAP")" = "default" ]
  [ "$(jq -r '.accounts.default.five_hour_pct' "$SNAP")" = "55" ]
  [ "$(jq -r '.accounts.default.weekly_all_pct' "$SNAP")" = "82" ]
  [ "$(jq -r '.accounts.default.fable_weekly_pct' "$SNAP")" = "94" ]
  [ "$(jq -r '.accounts.default.fetched_at' "$SNAP")" = "$NOW" ]
}

@test "snapshot: per-slot key names are fixed by the contract" {
  write_resp "${WORK}/r.json" 55 82 94
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  run jq -r '.accounts.default | keys_unsorted | sort | join(",")' "$SNAP"
  [ "$output" = "fable_active,fable_weekly_pct,fetched_at,five_hour_pct,five_hour_resets_at,five_hour_resets_epoch,label,securestorage,weekly_all_pct,weekly_resets_at,weekly_resets_epoch" ]
}

@test "snapshot: fetches each slot separately" {
  write_two_slot_registry
  write_resp "${WORK}/ra.json" 55 82 94
  write_resp "${WORK}/rb.json" 3 1 0
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts.a.five_hour_pct' "$SNAP")" = "55" ]
  [ "$(jq -r '.accounts.b.five_hour_pct' "$SNAP")" = "3" ]
  [ "$(jq -r '.accounts.a.fable_weekly_pct' "$SNAP")" = "94" ]
  [ "$(jq -r '.accounts.b.fable_weekly_pct' "$SNAP")" = "0" ]
}

@test "snapshot: top-level mirrors the active slot" {
  write_two_slot_registry
  write_resp "${WORK}/ra.json" 55 82 94
  write_resp "${WORK}/rb.json" 3 1 0
  # env で b を active にする
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      CLAUDE_SECURESTORAGE_CONFIG_DIR="${WORK}/claude-b" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.active' "$SNAP")" = "b" ]
  for k in fetched_at fable_weekly_pct fable_active weekly_all_pct weekly_resets_at \
           weekly_resets_epoch five_hour_pct five_hour_resets_at five_hour_resets_epoch; do
    top="$(jq -r ".${k}" "$SNAP")"
    slot="$(jq -r ".accounts.b.${k}" "$SNAP")"
    [ "$top" = "$slot" ]
  done
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "0" ]
}

# ---------- スロット単位 fail-open ----------

@test "fail-open: a failing slot keeps its previous values and fetched_at" {
  write_two_slot_registry
  write_resp "${WORK}/ra.json" 55 82 94
  write_resp "${WORK}/rb.json" 3 1 7
  # 1 回目: 両方成功
  env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$(jq -r '.accounts.b.fable_weekly_pct' "$SNAP")" = "7" ]
  # 2 回目: b だけ失敗し、a は新しい値に更新される
  write_resp "${WORK}/ra.json" 60 85 96
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" USAGE_PROBE_INTERVAL=0 \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/gone.json" \
      USAGE_PROBE_NOW="$((NOW + 7200))" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts.a.fable_weekly_pct' "$SNAP")" = "96" ]
  [ "$(jq -r '.accounts.a.fetched_at' "$SNAP")" = "$((NOW + 7200))" ]
  [ "$(jq -r '.accounts.b.fable_weekly_pct' "$SNAP")" = "7" ]
  [ "$(jq -r '.accounts.b.fetched_at' "$SNAP")" = "$NOW" ]
}

@test "fail-open: fetched_at is the fetch time, not the probe run time" {
  write_resp "${WORK}/r.json" 55 82 94
  env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  # active スロットが失敗しても fetched_at は前回のまま（実行時刻に更新されない）
  # ただし全スロット失敗では snapshot 自体を書かないため、2 スロットで検証する
  write_two_slot_registry
  write_resp "${WORK}/ra.json" 55 82 94
  write_resp "${WORK}/rb.json" 3 1 7
  env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" USAGE_PROBE_INTERVAL=0 \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" USAGE_PROBE_INTERVAL=0 \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/gone.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$((NOW + 9999))" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.active' "$SNAP")" = "a" ]
  [ "$(jq -r '.accounts.a.fetched_at' "$SNAP")" = "$NOW" ]
  [ "$(jq -r '.fetched_at' "$SNAP")" = "$NOW" ]
}

@test "fail-open: a slot with no new and no previous value is null-filled" {
  write_two_slot_registry
  write_resp "${WORK}/ra.json" 55 82 94
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/gone.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts.b.fable_weekly_pct' "$SNAP")" = "null" ]
  [ "$(jq -r '.accounts.b.fetched_at' "$SNAP")" = "null" ]
  [ "$(jq -r '.accounts.b.label' "$SNAP")" = "B" ]
}

@test "fail-open: every slot failing writes no snapshot" {
  write_two_slot_registry
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/gone.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/gone.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -f "$SNAP" ]
}

# ---------- 1 スロット時の退行ガード ----------

@test "single slot: legacy top-level keys keep their previous values" {
  write_resp "${WORK}/r.json" 55 82 94
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts | length' "$SNAP")" = "1" ]
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "94" ]
  [ "$(jq -r '.fable_active' "$SNAP")" = "true" ]
  [ "$(jq -r '.weekly_all_pct' "$SNAP")" = "82" ]
  [ "$(jq -r '.weekly_resets_at' "$SNAP")" = "2026-09-06T00:00:00+00:00" ]
  [ "$(jq -r '.fetched_at' "$SNAP")" = "$NOW" ]
}

# ---------- accounts-init.sh（雛形・生成手段） ----------

@test "init: creates a registry from the live CLAUDE_SECURESTORAGE_CONFIG_DIR" {
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" CLAUDE_SECURESTORAGE_CONFIG_DIR="${WORK}/claude-b" \
      "$INIT" --id b --label B
  [ "$status" -eq 0 ]
  [ -f "$ACCOUNTS" ]
  [ "$(jq -r '.accounts[0].id' "$ACCOUNTS")" = "b" ]
  [ "$(jq -r '.accounts[0].securestorage' "$ACCOUNTS")" = "${WORK}/claude-b" ]
}

@test "init: an unset CLAUDE_SECURESTORAGE_CONFIG_DIR records the default account" {
  run env -u CLAUDE_SECURESTORAGE_CONFIG_DIR CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      "$INIT" --id a --label A
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts[0].securestorage' "$ACCOUNTS")" = "null" ]
}

@test "init: appending a second slot keeps the first" {
  env -u CLAUDE_SECURESTORAGE_CONFIG_DIR CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$INIT" --id a --label A
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" CLAUDE_SECURESTORAGE_CONFIG_DIR="${WORK}/claude-b" \
      "$INIT" --id b --label B
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts | length' "$ACCOUNTS")" = "2" ]
  [ "$(jq -r '.accounts[1].id' "$ACCOUNTS")" = "b" ]
}

# ---------- API エラーボディをフェッチ成功扱いにしない ----------
# 401 / 429 / 5xx でも API は正しい JSON の dict を返す。これを成功扱いにすると
# そのスロットの前回値を全 null で上書きしてしまい、スロット単位 fail-open が壊れる。
# 非 active アカウントはトークン期限切れでこの経路に入るのが常態。

write_error_resp() {
  cat > "$1" <<'JSON'
{ "type": "error",
  "error": { "type": "authentication_error", "message": "OAuth token has expired" } }
JSON
}

@test "error body: an API error response is treated as a fetch failure" {
  write_resp "${WORK}/r.json" 55 82 94
  env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "94" ]
  # エラーボディを返す 2 回目: 全スロット失敗と同じ扱いになり snapshot は据え置き
  write_error_resp "${WORK}/err.json"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" USAGE_PROBE_INTERVAL=0 \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/err.json" USAGE_PROBE_NOW="$((NOW + 7200))" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "94" ]
  [ "$(jq -r '.fetched_at' "$SNAP")" = "$NOW" ]
}

@test "error body: one slot's API error keeps that slot's previous values" {
  write_two_slot_registry
  write_resp "${WORK}/ra.json" 55 82 94
  write_resp "${WORK}/rb.json" 3 1 7
  env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  # b のトークンが期限切れになり、API が 401 のエラーボディを返す
  write_error_resp "${WORK}/err.json"
  write_resp "${WORK}/ra.json" 60 85 96
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" USAGE_PROBE_INTERVAL=0 \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/err.json" \
      USAGE_PROBE_NOW="$((NOW + 7200))" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts.a.fable_weekly_pct' "$SNAP")" = "96" ]
  # b は前回値と前回の fetched_at を保つ（null で上書きされない）
  [ "$(jq -r '.accounts.b.fable_weekly_pct' "$SNAP")" = "7" ]
  [ "$(jq -r '.accounts.b.five_hour_pct' "$SNAP")" = "3" ]
  [ "$(jq -r '.accounts.b.fetched_at' "$SNAP")" = "$NOW" ]
}

@test "error body: an active slot's API error keeps the top-level mirror intact" {
  write_two_slot_registry
  write_resp "${WORK}/ra.json" 55 82 94
  write_resp "${WORK}/rb.json" 3 1 7
  env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  write_error_resp "${WORK}/err.json"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" USAGE_PROBE_INTERVAL=0 \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/err.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$((NOW + 7200))" "$PROBE"
  [ "$status" -eq 0 ]
  # FABLE_BUDGET_MODE の導出元が null に落ちない
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "94" ]
  [ "$(jq -r '.fetched_at' "$SNAP")" = "$NOW" ]
}

# ---------- レジストリの制御文字 ----------

@test "registry: a slot whose label contains a control character is dropped" {
  python3 - "$ACCOUNTS" <<'PY'
import json, sys
json.dump({"schema": 1, "accounts": [
    {"id": "a", "label": "A\n../../../../tmp/pwned\t\tClaude Code-credentials", "securestorage": None},
    {"id": "b", "label": "B", "securestorage": "/tmp/sec-b"},
]}, open(sys.argv[1], "w"))
PY
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  # 壊れたスロットは捨てられ、b だけが残る（幽霊スロットは現れない）
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
  [ "$(printf '%s' "$output" | cut -f1)" = "b" ]
  ! printf '%s' "$output" | grep -q 'pwned'
}

@test "registry: a slot whose securestorage contains a tab is dropped" {
  python3 - "$ACCOUNTS" <<'PY'
import json, sys
json.dump({"schema": 1, "accounts": [
    {"id": "a", "label": "A", "securestorage": "/tmp/a\tghost"},
    {"id": "b", "label": "B", "securestorage": None},
]}, open(sys.argv[1], "w"))
PY
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
  [ "$(printf '%s' "$output" | cut -f1)" = "b" ]
  # 残ったスロットの service 列は空にならない
  [ "$(printf '%s' "$output" | cut -f4)" = "Claude Code-credentials" ]
}

# ---------- accounts-init.sh の引数処理 ----------

@test "init: a value-less --id exits instead of looping forever" {
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$INIT" --id
  [ "$status" -eq 2 ]
  [[ "$output" =~ "requires a value" ]] || return 1
}

@test "init: a value-less --label exits instead of looping forever" {
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$INIT" --id a --label
  [ "$status" -eq 2 ]
  [[ "$output" =~ "requires a value" ]] || return 1
}

@test "init: a label with a control character is rejected" {
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$INIT" --id a --label "$(printf 'A\tB')"
  [ "$status" -eq 2 ]
  [ ! -f "$ACCOUNTS" ]
}

@test "init: an over-long label is rejected" {
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$INIT" --id a --label "0123456789abcdefg"
  [ "$status" -eq 2 ]
  [ ! -f "$ACCOUNTS" ]
}

# ---------- label の切り詰めと test_mode の判定 ----------

@test "registry: an over-long label is clipped to the display-width cap" {
  printf '{"schema":1,"accounts":[{"id":"a","label":"0123456789abcdef","securestorage":null}]}' > "$ACCOUNTS"
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | cut -f2)" = "01234567" ]
}

@test "registry: a full-width label is clipped by display width, not character count" {
  python3 - "$ACCOUNTS" <<'PY'
import json, sys
json.dump({"schema": 1, "accounts": [
    {"id": "a", "label": "仕事用のアカウント", "securestorage": None},
]}, open(sys.argv[1], "w"), ensure_ascii=False)
PY
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$PROBE" --print-slots
  [ "$status" -eq 0 ]
  # 全角は 1 文字 2 桁なので、表示幅 8 = 4 文字ぶんで切られる
  [ "$(printf '%s' "$output" | cut -f2)" = "仕事用の" ]
}

@test "test mode: an empty USAGE_PROBE_RESPONSE_FILE does not force the test path" {
  # 空文字は main と同じく本番経路。テスト経路に入ると無言で exit 0 してしまう。
  # 本番経路では Keychain / curl に進むが、認証が取れなければ fail-open で snapshot を書かない。
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="" USAGE_PROBE_ENDPOINT="http://127.0.0.1:9/none" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -f "$SNAP" ]
}

@test "test mode: a per-slot response file alone still selects the test path" {
  write_two_slot_registry
  write_resp "${WORK}/ra.json" 55 82 94
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts.a.fable_weekly_pct' "$SNAP")" = "94" ]
  # b は共通キーもスロット別キーも無いので失敗扱い（Keychain には触れない）
  [ "$(jq -r '.accounts.b.fable_weekly_pct' "$SNAP")" = "null" ]
}

@test "init: concurrent runs do not clobber each other via a fixed temp name" {
  env -u CLAUDE_SECURESTORAGE_CONFIG_DIR CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "$INIT" --id a --label A
  # 一時ファイルは固定名ではない（.tmp が残らず、mkstemp 由来の名前を使う）
  [ ! -f "${ACCOUNTS}.tmp" ]
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" CLAUDE_SECURESTORAGE_CONFIG_DIR="${WORK}/claude-b" \
      "$INIT" --id b --label B
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts | length' "$ACCOUNTS")" = "2" ]
  [ -z "$(ls "$WORK"/.accounts-* 2>/dev/null)" ]
}

# ---------- 本番経路の User-Agent ----------
# 使用量 API は User-Agent が claude-code/<版> でないリクエストを厳しい別枠で数え、
# 429 を返し続ける。curl と claude を差し替え、実際に送られる見出しを記録して確かめる。

# $1=claude --version の出力（空なら非 0 で終わる claude を置く）
setup_production_stubs() {
  STUB="${WORK}/bin"
  mkdir -p "$STUB" "${WORK}/claude-x"
  printf '{"claudeAiOauth":{"accessToken":"dummy-token"}}' > "${WORK}/claude-x/.credentials.json"
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "x", "label": "X", "securestorage": "${WORK}/claude-x" }
] }
JSON
  write_resp "${WORK}/resp.json" 10 20 30
  cat > "${STUB}/curl" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$@" > "${WORK}/curl-args"
cat > /dev/null
cat "${WORK}/resp.json"
printf '\n200'
SH
  if [ -n "$1" ]; then
    printf '#!/usr/bin/env bash\necho "%s"\n' "$1" > "${STUB}/claude"
  else
    printf '#!/usr/bin/env bash\nexit 1\n' > "${STUB}/claude"
  fi
  chmod +x "${STUB}/curl" "${STUB}/claude"
}

@test "user-agent: production fetch names the installed claude-code version" {
  setup_production_stubs "2.1.280 (Claude Code)"
  run env PATH="${STUB}:${PATH}" USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  grep -qxF 'User-Agent: claude-code/2.1.280' "${WORK}/curl-args"
  [ "$(jq -r '.accounts.x.five_hour_pct' "$SNAP")" = "10" ]
}

@test "user-agent: falls back to a fixed claude-code version when claude is unavailable" {
  setup_production_stubs ""
  run env PATH="${STUB}:${PATH}" USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  grep -qxF 'User-Agent: claude-code/2.1.0' "${WORK}/curl-args"
}

@test "user-agent: an unexpected claude --version output falls back to the fixed version" {
  setup_production_stubs "v2.1.280-beta (Claude Code)"
  run env PATH="${STUB}:${PATH}" USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  grep -qxF 'User-Agent: claude-code/2.1.0' "${WORK}/curl-args"
}

@test "user-agent: USAGE_PROBE_USER_AGENT overrides the header" {
  setup_production_stubs "2.1.280 (Claude Code)"
  run env PATH="${STUB}:${PATH}" USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_NOW="$NOW" USAGE_PROBE_USER_AGENT="claude-code/9.9.9" "$PROBE"
  [ "$status" -eq 0 ]
  grep -qxF 'User-Agent: claude-code/9.9.9' "${WORK}/curl-args"
}

# ---------- 実行条件（セッション記録が主、probe は補助） ----------
# 叩いたかどうかは、応答の値が snapshot に入ったかと試行状態ファイルで見る。

# $1=securestorage（空なら既定アカウント） $2=observed_at
write_record() {
  local key
  key="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import usage_view; print(usage_view.session_key(sys.argv[2]))' \
    "${PLUGIN_DIR}/scripts" "$1")"
  mkdir -p "$USAGE_SESSIONS_DIR"
  printf '{"schema":1,"key":"%s","observed_at":%s,"five_hour_pct":10,"five_hour_resets_epoch":null,"weekly_all_pct":20,"weekly_resets_epoch":%s}\n' \
    "$key" "$2" "$(( $2 + 86400 ))" >| "${USAGE_SESSIONS_DIR}/${key}.json"
}

# $1=スロット id → 試行状態ファイルの値（jq の式 $2 を当てる）
state_of() {
  jq -r --arg id "$1" ".slots[\$id]${2}" "$USAGE_PROBE_STATE"
}

# 2 スロットとも取得済みの snapshot を $1 の時刻で作り、試行状態を消して「未試行」に戻す
seed_two_slot_snapshot() {
  write_two_slot_registry
  write_resp "${WORK}/ra.json" 55 82 94
  write_resp "${WORK}/rb.json" 3 1 7
  env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$1" "$PROBE"
  rm -f "$USAGE_PROBE_STATE"
  write_resp "${WORK}/ra.json" 60 85 96
  write_resp "${WORK}/rb.json" 4 2 8
}

@test "condition: a slot whose record and snapshot are both fresh is not fetched" {
  seed_two_slot_snapshot "$((NOW - 600))"
  write_record "" "$((NOW - 600))"   # a（既定アカウント）の記録だけが 10 分前
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts.a.fable_weekly_pct' "$SNAP")" = "94" ]
  [ "$(jq -r '.accounts.a.fetched_at' "$SNAP")" = "$((NOW - 600))" ]
  [ "$(jq -r '.accounts.b.fable_weekly_pct' "$SNAP")" = "8" ]
  [ "$(state_of a '')" = "null" ]
  [ "$(state_of b .last_attempt)" = "$NOW" ]
}

@test "condition: a fresh record with an old snapshot fetched_at is fetched" {
  seed_two_slot_snapshot "$((NOW - 4 * 3600))"
  write_record "" "$((NOW - 600))"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts.a.fable_weekly_pct' "$SNAP")" = "96" ]
  [ "$(jq -r '.accounts.a.fetched_at' "$SNAP")" = "$NOW" ]
}

@test "condition: an old record with a fresh snapshot fetched_at is fetched" {
  seed_two_slot_snapshot "$((NOW - 600))"
  write_record "" "$((NOW - 4 * 3600))"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE_A="${WORK}/ra.json" USAGE_PROBE_RESPONSE_FILE_B="${WORK}/rb.json" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts.a.fable_weekly_pct' "$SNAP")" = "96" ]
  [ "$(jq -r '.accounts.a.fetched_at' "$SNAP")" = "$NOW" ]
}

@test "condition: a fresh record with no snapshot entry is fetched" {
  write_resp "${WORK}/r.json" 55 82 94
  write_record "" "$((NOW - 600))"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.accounts.default.fable_weekly_pct' "$SNAP")" = "94" ]
}

@test "interval: slots attempted an hour ago are not fetched and no snapshot is written" {
  write_two_slot_registry
  write_resp "${WORK}/r.json" 55 82 94
  printf '{"slots":{"a":{"last_attempt":%s,"consecutive_429":0},"b":{"last_attempt":%s,"consecutive_429":0}}}\n' \
    "$((NOW - 3600))" "$((NOW - 3600))" >| "$USAGE_PROBE_STATE"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -f "$SNAP" ]
  [ "$(state_of a .last_attempt)" = "$((NOW - 3600))" ]
}

@test "interval: a run right after every slot failed does not fetch again" {
  write_two_slot_registry
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/gone.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -f "$SNAP" ]
  [ "$(state_of a .last_attempt)" = "$NOW" ]
  [ "$(state_of b .last_attempt)" = "$NOW" ]
  write_resp "${WORK}/r.json" 55 82 94
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$((NOW + 60))" "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -f "$SNAP" ]
}

@test "429: consecutive 429s double the wait before the next attempt" {
  write_resp "${WORK}/r.json" 55 82 94
  probe_at() {
    env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" USAGE_PROBE_INTERVAL=1000 \
        USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_STATUS="$2" USAGE_PROBE_NOW="$1" "$PROBE"
  }
  probe_at "$NOW" 429
  [ "$(state_of default .consecutive_429)" = "1" ]
  probe_at "$((NOW + 1000))" 429
  [ "$(state_of default .consecutive_429)" = "2" ]
  [ ! -f "$SNAP" ]
  # 2 回続けて 429 → 待ちは間隔の 2 倍。1.5 倍では叩かない
  probe_at "$((NOW + 2500))" 200
  [ ! -f "$SNAP" ]
  [ "$(state_of default .last_attempt)" = "$((NOW + 1000))" ]
  # 2 倍経てば叩く
  probe_at "$((NOW + 3000))" 200
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "94" ]
}

@test "429: the wait is capped at one day" {
  write_resp "${WORK}/r.json" 55 82 94
  printf '{"slots":{"default":{"last_attempt":%s,"consecutive_429":20}}}\n' "$((NOW - 86400))" >| "$USAGE_PROBE_STATE"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "94" ]
}

@test "429: a 200 resets the consecutive count" {
  write_resp "${WORK}/r.json" 55 82 94
  printf '{"slots":{"default":{"last_attempt":%s,"consecutive_429":3}}}\n' "$((NOW - 10 * 86400))" >| "$USAGE_PROBE_STATE"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(state_of default .consecutive_429)" = "0" ]
  [ "$(state_of default .last_attempt)" = "$NOW" ]
}

@test "state: an unreadable state file treats every slot as never attempted" {
  write_resp "${WORK}/r.json" 55 82 94
  printf 'not json' >| "$USAGE_PROBE_STATE"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "94" ]
  [ "$(state_of default .last_attempt)" = "$NOW" ]
}

@test "lock: a fresh lock held by another probe makes this run do nothing" {
  write_resp "${WORK}/r.json" 55 82 94
  mkdir "$USAGE_PROBE_LOCK"
  python3 -c 'import os,sys,time; t=time.time()-60; os.utime(sys.argv[1],(t,t))' "$USAGE_PROBE_LOCK"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -f "$SNAP" ]
  [ ! -f "$USAGE_PROBE_STATE" ]
  [ -d "$USAGE_PROBE_LOCK" ]
}

@test "lock: a stale lock is taken over and released at exit" {
  write_resp "${WORK}/r.json" 55 82 94
  mkdir "$USAGE_PROBE_LOCK"
  python3 -c 'import os,sys,time; t=time.time()-300; os.utime(sys.argv[1],(t,t))' "$USAGE_PROBE_LOCK"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/r.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.fable_weekly_pct' "$SNAP")" = "94" ]
  [ ! -e "$USAGE_PROBE_LOCK" ]
}

@test "lock: released when no slot meets the condition" {
  printf '{"slots":{"default":{"last_attempt":%s,"consecutive_429":0}}}\n' "$NOW" >| "$USAGE_PROBE_STATE"
  run env USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="${WORK}/absent.json" \
      USAGE_PROBE_RESPONSE_FILE="${WORK}/gone.json" USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -e "$USAGE_PROBE_LOCK" ]
}

@test "production: a 429 from the API is counted" {
  setup_production_stubs "2.1.280 (Claude Code)"
  perl -pi -e 's/n200/n429/' "${STUB}/curl"
  grep -q '429' "${STUB}/curl"
  run env PATH="${STUB}:${PATH}" USAGE_SNAPSHOT="$SNAP" CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" \
      USAGE_PROBE_NOW="$NOW" "$PROBE"
  [ "$status" -eq 0 ]
  [ ! -f "$SNAP" ]
  [ "$(state_of x .consecutive_429)" = "1" ]
}
