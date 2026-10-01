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
  BASE="$NOW"
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

# $1=5h消化率 $2=7d消化率 $3=5h残り秒 $4=7d残り秒 [$5=session_id（既定 session-record-test、空なら付けない）]
# → stdin JSON。リセット時刻は setup の時刻（BASE）から数えるので、描画の時刻（NOW）を
# 進めても同じ引数なら同じ値になる。
mk_input() {
  local sid="${5-session-record-test}" sid_field=""
  [ -z "$sid" ] || sid_field="\"session_id\":\"${sid}\","
  printf '{%s"workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":%s}}}' \
    "$sid_field" "$WORK" "$1" "$((BASE + $3))" "$2" "$((BASE + $4))"
}

# $1=秒 → statusline が見る現在時刻（date +%s）を進める
advance() {
  NOW=$((NOW + $1))
  export NOW
}

# → default.json の「週次% 取得時刻」
weekly_and_observed() {
  jq -r '"\(.weekly_all_pct) \(.observed_at)"' "$SESSIONS/default.json"
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
  [ "$(ls -A "${WORK}/elsewhere" | grep -vx '.sessions')" = "default.json" ]
  [ "$(ls -A "${WORK}/elsewhere/.sessions" | wc -l | tr -d ' ')" = "1" ]
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

# ---------- セッションごとの前回値（#643） ----------
# spec: usage-session-records「ステータスラインが起動アカウント別の記録を書く」の前回値の判定

@test "previous value: a stale session redrawing its old value keeps the newer session's record" {
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  advance 10
  mk_input 3 60 14000 172800 session-y | bash "$SL" > /dev/null
  y_time="$NOW"
  advance 10
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  [ "$(weekly_and_observed)" = "60 $y_time" ]
}

@test "previous value: the session writes again once it receives a new value" {
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  advance 10
  mk_input 3 60 14000 172800 session-y | bash "$SL" > /dev/null
  advance 10
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  advance 10
  mk_input 3 45 14000 172800 session-x | bash "$SL" > /dev/null
  [ "$(weekly_and_observed)" = "45 $NOW" ]
}

@test "previous value: the same session redrawing the same value keeps observed_at" {
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  first="$NOW"
  advance 30
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  [ "$(weekly_and_observed)" = "40 $first" ]
}

@test "previous value: a render without session_id writes every time" {
  mk_input 3 40 14000 172800 "" | bash "$SL" > /dev/null
  advance 30
  mk_input 3 40 14000 172800 "" | bash "$SL" > /dev/null
  [ "$(weekly_and_observed)" = "40 $NOW" ]
  [ ! -e "$SESSIONS/.sessions" ] || [ -z "$(ls -A "$SESSIONS/.sessions")" ]
}

@test "previous value: the file is named by the sha256 of the quoted session_id" {
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  name="$(printf '%s' '"session-x"' | shasum -a 256 | cut -c1-16)"
  [ "$(cat "$SESSIONS/.sessions/$name")" = "3|$((BASE + 14000))|40|$((BASE + 172800))" ]
}

@test "previous value: an unreadable or malformed previous value is treated as none" {
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  name="$(printf '%s' '"session-x"' | shasum -a 256 | cut -c1-16)"
  printf 'garbage\n' >| "$SESSIONS/.sessions/$name"
  advance 30
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  [ "$(weekly_and_observed)" = "40 $NOW" ]
}

@test "previous value: an unwritable previous-value place keeps the record and the output" {
  mk_input 3 40 14000 172800 session-x | bash "$SL" > "$WORK/normal.txt"
  rm -rf "$SESSIONS"
  mkdir -p "$SESSIONS"
  : > "$SESSIONS/.sessions"
  run bash -c "bash '$SL' > '$WORK/blocked.txt'" < <(mk_input 3 40 14000 172800 session-x)
  [ "$status" -eq 0 ]
  diff "$WORK/normal.txt" "$WORK/blocked.txt"
  [ "$(weekly_and_observed)" = "40 $NOW" ]
}

@test "previous value: files older than 7 days are removed on write and fresh ones stay" {
  mkdir -p "$SESSIONS/.sessions"
  : > "$SESSIONS/.sessions/0000000000000000"
  : > "$SESSIONS/.sessions/1111111111111111"
  touch -t "$(command date -v-10d +%Y%m%d%H%M 2>/dev/null || command date -d '10 days ago' +%Y%m%d%H%M)" \
    "$SESSIONS/.sessions/0000000000000000"
  mk_input 3 40 14000 172800 session-x | bash "$SL" > /dev/null
  [ ! -e "$SESSIONS/.sessions/0000000000000000" ]
  [ -e "$SESSIONS/.sessions/1111111111111111" ]
}
