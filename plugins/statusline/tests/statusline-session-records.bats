#!/usr/bin/env bats
#
# statusline-session-records:
#   statusline.sh が起動アカウント別のセッション記録（.usage-sessions/<鍵>.json）を書く契約。
#   鍵は起動環境の CLAUDE_SECURESTORAGE_CONFIG_DIR だけから決まり、レジストリや snapshot の
#   active からは決めない。
#
# spec: usage-session-records「ステータスラインが起動アカウント別の記録を書く」

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SL="${PLUGIN_DIR}/scripts/statusline.sh"
  WORK="$(mktemp -d)"
  export HOME="$WORK/home" FLATMATE_RATE_SHARE_CONF="$WORK/no-share-conf"
  unset FLATMATE_RATE_SHARE_DIR
  mkdir -p "$HOME"
  export CLAUDE_CONFIG_DIR="$WORK"
  export STATUSLINE_API_PACE=0
  export STATUSLINE_CODEX=0
  unset CLAUDE_ACCOUNTS_FILE USAGE_SESSIONS_DIR CLAUDE_SECURESTORAGE_CONFIG_DIR
  SESSIONS="${WORK}/.usage-sessions"
  SECURE_B="${WORK}/claude-b"
  NOW="$(date +%s)"
  export NOW
  # 出力の比較で残り時間の分の桁がずれないよう、`date +%s` を固定する
  # （statusline-multi-account.bats と同じ方式）。
  date() {
    if [ "$1" = "+%s" ]; then
      printf '%s\n' "$NOW"
    else
      command date "$@"
    fi
  }
  export -f date
}

teardown() {
  chmod -R u+w "$WORK" 2>/dev/null
  rm -rf "$WORK"
}

# $1=5h消化率 $2=7d消化率 $3=5h残り秒 $4=7d残り秒 → stdin JSON
mk_input() {
  printf '{"session_id":"session-record-test","workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":%s}}}' \
    "$WORK" "$1" "$((NOW + $3))" "$2" "$((NOW + $4))"
}

key_of() {
  python3 -c 'import hashlib,sys,unicodedata;print(hashlib.sha256(unicodedata.normalize("NFC",sys.argv[1]).encode()).hexdigest()[:8])' "$1"
}

write_two_slot_registry() {
  cat > "${WORK}/accounts.json" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "${SECURE_B}" }
] }
JSON
  printf '{"schema":2,"active":"a","accounts":{}}\n' > "${WORK}/.usage-snapshot"
}

@test "record: the default account session writes default.json" {
  mk_input 3 69 14000 172800 | bash "$SL" > /dev/null
  [ -f "$SESSIONS/default.json" ]
  run jq -r '[.schema, .key, .observed_at, .five_hour_pct, .five_hour_resets_epoch, .weekly_all_pct, .weekly_resets_epoch] | @tsv' "$SESSIONS/default.json"
  [ "$output" = "$(printf '1\tdefault\t%s\t3\t%s\t69\t%s' "$NOW" "$((NOW + 14000))" "$((NOW + 172800))")" ]
}

@test "record: a B session writes only B's key, never default.json" {
  write_two_slot_registry
  mk_input 7 12 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="$SECURE_B" bash "$SL" > /dev/null
  key="$(key_of "$SECURE_B")"
  [ -f "$SESSIONS/${key}.json" ]
  [ ! -e "$SESSIONS/default.json" ]
  [ "$(ls "$SESSIONS" | wc -l | tr -d ' ')" = "1" ]
  run jq -r '[.key, .weekly_all_pct] | @tsv' "$SESSIONS/${key}.json"
  [ "$output" = "$(printf '%s\t12' "$key")" ]
}

@test "record: a B session leaves an existing default.json untouched" {
  write_two_slot_registry
  mk_input 3 69 14000 172800 | bash "$SL" > /dev/null
  before="$(cat "$SESSIONS/default.json")"
  mk_input 99 99 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="$SECURE_B" bash "$SL" > /dev/null
  [ "$(cat "$SESSIONS/default.json")" = "$before" ]
}

@test "record: an unregistered account writes its own key only" {
  write_two_slot_registry
  mk_input 3 69 14000 172800 | bash "$SL" > /dev/null
  before="$(cat "$SESSIONS/default.json")"
  other="${WORK}/claude-unregistered"
  mk_input 50 50 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="$other" bash "$SL" > /dev/null
  [ -f "$SESSIONS/$(key_of "$other").json" ]
  [ ! -e "$SESSIONS/$(key_of "$SECURE_B").json" ]
  [ "$(cat "$SESSIONS/default.json")" = "$before" ]
}

@test "record: no rate_limits writes nothing" {
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"}}' "$WORK" | bash "$SL" > /dev/null
  [ ! -e "$SESSIONS" ] || [ -z "$(ls -A "$SESSIONS")" ]
}

@test "record: a missing seven_day is written as null" {
  printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"rate_limits":{"five_hour":{"used_percentage":4.5,"resets_at":%s}}}' \
    "$WORK" "$((NOW + 100))" | bash "$SL" > /dev/null
  run jq -c '[.five_hour_pct, .weekly_all_pct, .weekly_resets_epoch]' "$SESSIONS/default.json"
  [ "$output" = "[4.5,null,null]" ]
}

@test "record: USAGE_SESSIONS_DIR overrides the directory and no temp file is left" {
  export USAGE_SESSIONS_DIR="${WORK}/elsewhere"
  mk_input 3 69 14000 172800 | bash "$SL" > /dev/null
  [ -f "${WORK}/elsewhere/default.json" ]
  [ ! -e "$SESSIONS" ]
  [ "$(ls -A "${WORK}/elsewhere")" = "default.json" ]
}

@test "record: an unwritable directory keeps exit 0 and the same output" {
  mk_input 3 69 14000 172800 | bash "$SL" > "$WORK/writable.txt"
  mkdir -p "$WORK/ro"
  chmod 555 "$WORK/ro"
  export USAGE_SESSIONS_DIR="$WORK/ro/sessions"
  run bash -c "bash '$SL' > '$WORK/readonly.txt'" < <(mk_input 3 69 14000 172800)
  [ "$status" -eq 0 ]
  [ ! -e "$WORK/ro/sessions" ]
  diff "$WORK/writable.txt" "$WORK/readonly.txt"
}

@test "record: .rate-limit-snapshot keeps its shape and its default-only condition" {
  mk_input 3 69 14000 172800 | bash "$SL" > /dev/null
  run jq -r 'keys | join(",")' "$WORK/.rate-limit-snapshot"
  [ "$output" = "five_hour_pct,five_hour_resets_at,host,obs_sig,observed_at,session_id,seven_day_pct,seven_day_resets_at,storage_binding,ts,written_at" ]
  rm -f "$WORK/.rate-limit-snapshot"
  mk_input 3 69 14000 172800 | CLAUDE_SECURESTORAGE_CONFIG_DIR="$SECURE_B" bash "$SL" > /dev/null
  [ ! -e "$WORK/.rate-limit-snapshot" ]
}
