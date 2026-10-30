#!/usr/bin/env bats
#
# dev-workflow-account-selector:
#   accounts.json・セッション記録・schema 2 usage snapshot の実効値から起動アカウントを選ぶ規則。
#
# spec: usage-account-registry（起動アカウント選択）
#       usage-session-records（記録と snapshot から実効値を求める）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SELECTOR="${PLUGIN_DIR}/scripts/select-account.sh"
  README="${PLUGIN_DIR}/README.md"
  WORK="$(mktemp -d)"
  ACCOUNTS="${WORK}/accounts.json"
  SNAP="${WORK}/.usage-snapshot"
  SESSIONS="${WORK}/.usage-sessions"
  NOW=1000000000
  SECURE_A="${WORK}/claude a"
  SECURE_B="${WORK}/claude b"
  # 本物の ~/.codex と設定ディレクトリの Codex の cache を読まないよう、存在しない home を指す
  CODEX_DIR="${WORK}/no-codex-home"
  HEADROOM_CAP=""
}

teardown() {
  rm -rf "$WORK"
}

# $1=a の securestorage（JSON）$2=b の securestorage（JSON）
# $3=a の enabled（JSON の値。空なら書かない）$4=b の enabled（同）
write_registry() {
  local secure_a="${1:-null}" secure_b="${2:-\"${SECURE_B}\"}"
  local enabled_a="${3:+, \"enabled\": $3}" enabled_b="${4:+, \"enabled\": $4}"
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": ${secure_a}${enabled_a} },
  { "id": "b", "label": "B", "securestorage": ${secure_b}${enabled_b} }
] }
JSON
}

# $1=a fetched_at $2=b fetched_at $3=a 5h $4=b 5h $5=a weekly $6=b weekly
# 5 時間枠はリセット時刻を持たせる（リセット時刻 null の値を使うのは使用率 0 のときだけなので）
write_snapshot() {
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $1, "five_hour_pct": $3, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": $5, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $2, "five_hour_pct": $4, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": $6, "weekly_resets_epoch": $((NOW + 302400)) }
} }
JSON
}

# $1=securestorage（空なら既定アカウント）→ そのアカウントのセッション記録の鍵
record_key() {
  if [ -z "$1" ]; then echo default; return; fi
  python3 -c 'import hashlib,sys,unicodedata;print(hashlib.sha256(unicodedata.normalize("NFC",sys.argv[1]).encode()).hexdigest()[:8])' "$1"
}

# $1=securestorage $2=observed_at $3=5h% $4=週次% [$5=週次リセット epoch]
write_record() {
  local key
  key="$(record_key "$1")"
  mkdir -p "$SESSIONS"
  printf '{"schema":1,"key":"%s","observed_at":%s,"five_hour_pct":%s,"five_hour_resets_epoch":%s,"weekly_all_pct":%s,"weekly_resets_epoch":%s}\n' \
    "$key" "$2" "$3" "$((NOW + 9000))" "$4" "${5:-$((NOW + 302400))}" > "${SESSIONS}/${key}.json"
}

# headroom の設定は空（既定値）に固定し、利用者の環境の HEADROOM_* を持ち込まない
invoke_env() {
  env -u CLAUDE_SECURESTORAGE_CONFIG_DIR CLAUDE_CONFIG_DIR="$WORK" CODEX_HOME="$CODEX_DIR" \
    CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" USAGE_SNAPSHOT="$SNAP" USAGE_SESSIONS_DIR="$SESSIONS" \
    HEADROOM_7D_CAP_PCT="$HEADROOM_CAP" HEADROOM_NORMAL_RATE_PCT_PER_DAY="" "$@"
}

invoke() {
  invoke_env SELECT_ACCOUNT_NOW="$NOW" "$SELECTOR" "$@" >"${WORK}/stdout" 2>"${WORK}/stderr"
}

# Codex の current account（CODEX_HOME）に、主体の一致する auth.json と使用量の cache を置く。
# $1=週次の使用率（書き方は test_headroom.py の Env.codex を手本にする）
write_codex() {
  CODEX_DIR="${WORK}/codex"
  mkdir -p "$CODEX_DIR" "${WORK}/codex-usage"
  python3 - "$CODEX_DIR" "${WORK}/codex-usage" "$NOW" "$1" <<'PY'
import base64, hashlib, json, pathlib, sys
home, cache_dir, now, used = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4])
claims = base64.urlsafe_b64encode(json.dumps({'email': 'test@example.invalid'}).encode()).decode().rstrip('=')
(home / 'auth.json').write_text(json.dumps({'tokens': {'id_token': 'x.' + claims + '.x', 'account_id': 'account'}}))
cache = {'version': 2, 'fetched_at': now,
         'windows': [{'minutes': 10080, 'used_percent': used, 'reset_at': now + 302400}],
         'identity': {'email_hash': hashlib.sha256(b'test@example.invalid').hexdigest(),
                      'account_id_hash': hashlib.sha256(b'account').hexdigest()}}
digest = hashlib.sha256(str(home.resolve()).encode()).hexdigest()
(cache_dir / (digest + '.json')).write_text(json.dumps(cache))
PY
}

write_shell_stubs() {
  mkdir -p "${WORK}/bin" "${WORK}/scripts"
  cat > "${WORK}/scripts/usage-probe.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  cat > "${WORK}/scripts/select-account.sh" <<'SH'
#!/usr/bin/env bash
[ -z "${SELECTOR_ARGS_LOG:-}" ] || printf '<%s>\n' "$@" > "$SELECTOR_ARGS_LOG"
if [ "${SELECTOR_RC:-0}" -ne 0 ]; then
  exit "$SELECTOR_RC"
fi
printf '%s\n' "${SELECTOR_VALUE:-}"
SH
  cat > "${WORK}/bin/claude" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${CLAUDE_SECURESTORAGE_CONFIG_DIR+x}:${CLAUDE_SECURESTORAGE_CONFIG_DIR-}" > "$CLAUDE_ENV_LOG"
printf '<%s>\n' "$@" > "$CLAUDE_ARGS_LOG"
printf '%s\n' "${CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS+x}:${CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS-}" > "${CLAUDE_IDLE_LOG:-/dev/null}"
SH
  chmod +x "${WORK}/scripts/usage-probe.sh" \
    "${WORK}/scripts/select-account.sh" "${WORK}/bin/claude"
}

@test "automatic: selects the greatest surplus and reports every margin" {
  # 要件の変更（理由 max-weekly-margin → max-surplus）。リセットまで 84 時間で余り = 90 − 2 × 週次なので順位は margin と同じ
  write_registry
  write_snapshot "$NOW" "$NOW" 10 10 40 20
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:10.00,b:30.00" ]
  [ "$(wc -l < "${WORK}/stderr" | tr -d ' ')" = 1 ]
}

@test "automatic: equal zero surplus keeps declaration order even when the margins differ" {
  # 要件の変更（margin 最大 → headroom の余り最大・同点は宣言順）により、未丸めの margin では
  # b が大きいが、余りはどちらも 0（天井に届く見込み）なので宣言順で先の a を選ぶ
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $NOW, "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 50, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $NOW, "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 50, "weekly_resets_epoch": $((NOW + 302399)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:0.00,b:0.00" ]
}

@test "age: an old value before its reset still takes part and can win" {
  write_registry
  write_snapshot "$((NOW - 86400))" "$NOW" 10 10 0 40
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:50.00,b:10.00" ]
}

@test "age: a value past its weekly reset is compared as 0%" {
  # 要件の変更（margin 最大 → headroom の余り最大）により、0% として数えた a（余り 90）が
  # b（余り 30）より余るので a を選ぶ。a の margin は週が始まったばかりで 0.00
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $((NOW - 604800)), "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 95, "weekly_resets_epoch": $((NOW - 10)) },
  "b": { "fetched_at": $NOW, "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 30, "weekly_resets_epoch": $((NOW + 302400)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:0.00,b:20.00" ]
}

@test "records: session records alone select without a snapshot" {
  write_registry
  write_record "" "$((NOW - 3600))" 10 40
  write_record "$SECURE_B" "$((NOW - 7200))" 10 20
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:10.00,b:30.00" ]
}

@test "records: repeated 429s leave the snapshot empty but records still select" {
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": null, "five_hour_pct": null,
           "weekly_all_pct": null, "weekly_resets_epoch": null },
  "b": { "fetched_at": null, "five_hour_pct": null,
           "weekly_all_pct": null, "weekly_resets_epoch": null }
} }
JSON
  write_record "" "$((NOW - 60))" 10 45
  write_record "$SECURE_B" "$((NOW - 60))" 10 25
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  ! grep -qF 'missing' "${WORK}/stderr" || return 1
  grep -qF 'selected=b reason=max-surplus' "${WORK}/stderr"
}

@test "records: B's record is never read as A's" {
  write_registry
  write_record "$SECURE_B" "$NOW" 10 0
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:missing,b:50.00" ]
}

@test "records: a newer 0% record after a manual reset beats an older 100% snapshot" {
  write_registry
  write_snapshot "$NOW" "$((NOW - 7200))" 10 10 30 100
  write_record "$SECURE_B" "$((NOW - 60))" 10 0
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:20.00,b:50.00" ]
}

@test "fallback: all missing slots select the registered default id" {
  write_registry
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-missing-usage margins=a:missing,b:missing" ]
}

@test "fallback: an unregistered default uses the sentinel" {
  write_registry "\"${SECURE_A}\""
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  grep -qF 'selected=@unregistered-default reason=default-due-to-missing-usage' "${WORK}/stderr"
}

@test "five-hour guard: 89.99 is eligible and 90 is excluded" {
  write_registry
  write_snapshot "$NOW" "$NOW" 89.99 90 40 0
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:10.00,b:five-hour>=90" ]
}

@test "five-hour guard: all limited slots use a distinct fallback reason" {
  write_registry
  write_snapshot "$NOW" "$NOW" 90 100 40 20
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-five-hour-limit margins=a:five-hour>=90,b:five-hour>=90" ]
  ! grep -qF 'default-due-to-missing-usage' "${WORK}/stderr" || return 1
}

@test "explicit: registered id succeeds without reading the snapshot" {
  write_registry
  mkdir "$SNAP"
  run invoke b
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=explicit margins=-" ]
}

@test "explicit: unknown id and excess arguments return 2 without stdout" {
  write_registry
  run invoke missing
  [ "$status" -eq 2 ]
  [ ! -s "${WORK}/stdout" ]
  grep -qF 'unknown account id: missing' "${WORK}/stderr"

  run invoke a b
  [ "$status" -eq 2 ]
  [ ! -s "${WORK}/stdout" ]
  grep -qF 'usage:' "${WORK}/stderr"
}

@test "shell integration: selector failure does not launch claude" {
  write_registry
  marker="${WORK}/claude-called"
  cld_account() {
    local selected status
    selected="$(env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" USAGE_SNAPSHOT="$SNAP" \
      "$SELECTOR" "$1")"
    status=$?
    [ "$status" -eq 0 ] || return "$status"
    shift
    if [ -z "$selected" ]; then
      env -u CLAUDE_SECURESTORAGE_CONFIG_DIR claude "$@"
    else
      CLAUDE_SECURESTORAGE_CONFIG_DIR="$selected" claude "$@"
    fi
  }
  claude() { : > "$marker"; }

  run cld_account missing --dangerously-skip-permissions
  [ "$status" -eq 2 ]
  [ ! -e "$marker" ]
}

# bin/cld・bin/cld-account（実行ファイル）。scripts はスタブに差し替え、claude もスタブにする。
# 関数定義の無い非ログインの bash から PATH だけで呼ぶ。
run_cld() {
  # $1=実行ファイル名、残りは引数。RUN_CLD_ENV（配列）に追加の環境変数を入れる
  local exe="$1"; shift
  write_shell_stubs
  export CLAUDE_ENV_LOG="${WORK}/claude-env" CLAUDE_ARGS_LOG="${WORK}/claude-args" CLAUDE_IDLE_LOG="${WORK}/claude-idle"
  run env -u CLD_DEFAULT_ARGS -u CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS PATH="${WORK}/bin:${PLUGIN_DIR}/bin:${PATH}" \
    CLAUDE_HARNESS_SCRIPTS="${WORK}/scripts" ${RUN_CLD_ENV[@]+"${RUN_CLD_ENV[@]}"} "$exe" "$@"
}

@test "bin/cld and bin/cld-account exist and are executable" {
  [ -x "${PLUGIN_DIR}/bin/cld" ]
  [ -x "${PLUGIN_DIR}/bin/cld-account" ]
}

@test "bin/cld launches with unset account env and preserves quoted arguments" {
  export SELECTOR_VALUE="" SELECTOR_RC=0
  RUN_CLD_ENV=(CLAUDE_SECURESTORAGE_CONFIG_DIR=inherited)
  run_cld cld "argument with spaces" "*.md"
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_ENV_LOG")" = ":" ]
  [ "$(cat "$CLAUDE_ARGS_LOG")" = $'<argument with spaces>\n<*.md>' ]
}

@test "bin/cld sets the selected securestorage" {
  export SELECTOR_VALUE="${SECURE_B}" SELECTOR_RC=0
  RUN_CLD_ENV=()
  run_cld cld --resume
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_ENV_LOG")" = "x:${SECURE_B}" ]
  [ "$(cat "$CLAUDE_ARGS_LOG")" = '<--resume>' ]
}

@test "bin/cld-account passes the slot id to the selector and drops it from claude args" {
  export SELECTOR_VALUE="${SECURE_B}" SELECTOR_RC=0 SELECTOR_ARGS_LOG="${WORK}/selector-args"
  RUN_CLD_ENV=()
  run_cld cld-account b --resume
  [ "$status" -eq 0 ]
  [ "$(cat "$SELECTOR_ARGS_LOG")" = "<b>" ]
  [ "$(cat "$CLAUDE_ENV_LOG")" = "x:${SECURE_B}" ]
  [ "$(cat "$CLAUDE_ARGS_LOG")" = '<--resume>' ]
}

@test "bin/cld-account preserves selector exit 2 and does not launch Claude" {
  export SELECTOR_RC=2
  RUN_CLD_ENV=()
  run_cld cld-account missing "argument with spaces"
  [ "$status" -eq 2 ]
  [ ! -e "$CLAUDE_ENV_LOG" ]
  [ ! -e "$CLAUDE_ARGS_LOG" ]
}

@test "bin/cld preserves a nonzero selector status and does not launch Claude" {
  export SELECTOR_RC=3
  RUN_CLD_ENV=()
  run_cld cld
  [ "$status" -eq 3 ]
  [ ! -e "$CLAUDE_ARGS_LOG" ]
}

@test "bin/cld-account without a slot id exits 2 and does not launch Claude" {
  export SELECTOR_VALUE="" SELECTOR_RC=0
  RUN_CLD_ENV=()
  run_cld cld-account
  [ "$status" -eq 2 ]
  [[ "$output" == *usage:* ]]
  [ ! -e "$CLAUDE_ARGS_LOG" ]
}

@test "CLD_DEFAULT_ARGS words go first for both executables" {
  export SELECTOR_VALUE="" SELECTOR_RC=0
  RUN_CLD_ENV=(CLD_DEFAULT_ARGS="--dangerously-skip-permissions --remote-control")
  run_cld cld --resume
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_ARGS_LOG")" = $'<--dangerously-skip-permissions>\n<--remote-control>\n<--resume>' ]
  rm -f "$CLAUDE_ARGS_LOG"
  RUN_CLD_ENV=(CLD_DEFAULT_ARGS="--remote-control")
  run_cld cld-account b --resume
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_ARGS_LOG")" = $'<--remote-control>\n<--resume>' ]
}

@test "CLD_DEFAULT_ARGS is not evaluated by the shell" {
  export SELECTOR_VALUE="" SELECTOR_RC=0
  RUN_CLD_ENV=(CLD_DEFAULT_ARGS='--x $(touch '"${WORK}"'/pwned) *')
  run_cld cld
  [ "$status" -eq 0 ]
  [ ! -e "${WORK}/pwned" ]
  grep -qF '<--x>' "$CLAUDE_ARGS_LOG"
  grep -qF '<*>' "$CLAUDE_ARGS_LOG"
}

@test "bin/cld does not override or add the idle compact threshold" {
  export SELECTOR_VALUE="" SELECTOR_RC=0
  RUN_CLD_ENV=(CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=50000)
  run_cld cld
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_IDLE_LOG")" = "x:50000" ]
  RUN_CLD_ENV=()
  run_cld cld
  [ "$(cat "$CLAUDE_IDLE_LOG")" = ":" ]
}

@test "bin/cld finds scripts through a symlink when CLAUDE_HARNESS_SCRIPTS is unset" {
  # bin/ と scripts/ が兄弟の配置を作り、その bin/cld への symlink を PATH に置く
  mkdir -p "${WORK}/clone/bin" "${WORK}/clone/scripts" "${WORK}/linkbin"
  cp "${PLUGIN_DIR}/bin/cld" "${WORK}/clone/bin/cld"
  write_shell_stubs
  cp "${WORK}/scripts/"*.sh "${WORK}/clone/scripts/"
  ln -s "${WORK}/clone/bin/cld" "${WORK}/linkbin/cld"
  export CLAUDE_ENV_LOG="${WORK}/claude-env" CLAUDE_ARGS_LOG="${WORK}/claude-args"
  export SELECTOR_VALUE="${SECURE_A}" SELECTOR_RC=0
  run env -u CLAUDE_HARNESS_SCRIPTS -u CLD_DEFAULT_ARGS PATH="${WORK}/bin:${WORK}/linkbin:${PATH}" cld --resume
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_ENV_LOG")" = "x:${SECURE_A}" ]
}

@test "README no longer pastes shell functions and describes the PATH and env lines" {
  ! grep -q '^cld()' "$README"
  ! grep -q '^cld-account()' "$README"
  grep -qF 'CLD_DEFAULT_ARGS' "$README"
  grep -qF 'plugins/dev-workflow/bin' "$README"
}

@test "tie break: equal surplus keeps registry declaration order" {
  write_registry
  write_snapshot "$NOW" "$NOW" 10 10 25 25
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  grep -qF 'selected=a reason=max-surplus margins=a:25.00,b:25.00' "${WORK}/stderr"
}

@test "a non-numeric fetched_at and a future observation are passed through" {
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": "not-a-number", "five_hour_pct": 1, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 1, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $((NOW + 1)), "five_hour_pct": 1, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 1, "weekly_resets_epoch": $((NOW + 302400)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:49.00,b:49.00" ]
}

@test "a non-numeric weekly value is excluded and an unknown five-hour value is kept" {
  # 要件の変更（候補の外し方を headroom の best に揃える）により、five_hour_pct が null の a は
  # 候補に残り、週次の使用率が数でない b だけが missing になる
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $NOW, "five_hour_pct": null,
           "weekly_all_pct": 1, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $NOW, "five_hour_pct": 1, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": "bad", "weekly_resets_epoch": $((NOW + 302400)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:49.00,b:missing" ]
}

@test "streams: a securestorage path with spaces is the only stdout value" {
  write_registry "\"${SECURE_A}\""
  write_snapshot "$NOW" "$NOW" 10 10 0 40
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_A" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(wc -l < "${WORK}/stderr" | tr -d ' ')" = 1 ]
  ! grep -qF 'selected=' "${WORK}/stdout" || return 1
}

# ── enabled（usage-account-registry「スロットを enabled でオフにできる」）──

@test "enabled: an off slot is not selected even with the greatest surplus" {
  # b は週の 90% 経過・週次 0%（余裕 90）。a は余裕 10
  write_snapshot "$NOW" "$NOW" 10 10 40 20
  write_record "$SECURE_B" "$NOW" 0 0 "$((NOW + 60480))"
  write_registry
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:10.00,b:90.00" ]

  write_registry "" "" "" false
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:10.00,b:off" ]
  [ "$(wc -l < "${WORK}/stderr" | tr -d ' ')" = 1 ]
}

@test "enabled: a slot turned off with accounts.sh is not selected" {
  # b は週の 90% 経過・週次 0%（余裕 90）で最大。accounts.sh off b でオフにする
  write_snapshot "$NOW" "$NOW" 10 10 40 20
  write_record "$SECURE_B" "$NOW" 0 0 "$((NOW + 60480))"
  write_registry
  CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "${PLUGIN_DIR}/scripts/accounts.sh" off b
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:10.00,b:off" ]
}

@test "enabled: a registry without enabled selects the same as one with enabled true" {
  write_snapshot "$NOW" "$NOW" 10 10 40 20
  write_registry
  run invoke
  [ "$status" -eq 0 ]
  cp "${WORK}/stdout" "${WORK}/stdout.omitted"
  cp "${WORK}/stderr" "${WORK}/stderr.omitted"
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:10.00,b:30.00" ]

  write_registry "" "" true true
  run invoke
  [ "$status" -eq 0 ]
  cmp "${WORK}/stdout" "${WORK}/stdout.omitted"
  cmp "${WORK}/stderr" "${WORK}/stderr.omitted"
}

@test "enabled: only the JSON false turns a slot off" {
  write_snapshot "$NOW" "$NOW" 10 10 40 20
  local value
  for value in '"false"' 0 null; do
    write_registry "" "" "" "$value"
    run invoke
    [ "$status" -eq 0 ]
    [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:10.00,b:30.00" ]
  done
}

@test "enabled: explicit selection of an off slot returns 2 with the way back" {
  write_registry "" "" "" false
  run invoke b
  [ "$status" -eq 2 ]
  [ ! -s "${WORK}/stdout" ]
  [ "$(wc -l < "${WORK}/stderr" | tr -d ' ')" = 1 ]
  grep -qF 'account b is off' "${WORK}/stderr"
  grep -qF 'enabled' "${WORK}/stderr"
  grep -qF "$ACCOUNTS" "${WORK}/stderr"
  ! grep -qF 'unknown account id' "${WORK}/stderr" || return 1

  # オンのスロットの明示選択は変わらない
  run invoke a
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=explicit margins=-" ]
}

@test "enabled: all slots off fall back to the default account without an error" {
  write_snapshot "$NOW" "$NOW" 10 10 40 20
  write_registry "" "" false false
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-all-off margins=a:off,b:off" ]
}

@test "enabled: all slots off without a registered default use the sentinel" {
  write_registry "\"${SECURE_A}\"" "" false false
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=@unregistered-default reason=default-due-to-all-off margins=a:off,b:off" ]
}

@test "enabled: an on slot with missing usage is not replaced by an off slot with values" {
  write_record "$SECURE_B" "$NOW" 0 0
  write_registry "" "" "" false
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-missing-usage margins=a:missing,b:off" ]
}

@test "enabled: an off default slot with the on slot's usage missing falls back to the default" {
  write_registry "" "" false
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-missing-usage margins=a:off,b:missing" ]
}

@test "enabled: explicit selection of a slot turned off with accounts.sh points to accounts.sh on" {
  write_registry
  CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "${PLUGIN_DIR}/scripts/accounts.sh" off b
  run invoke b
  [ "$status" -eq 2 ]
  [ ! -s "${WORK}/stdout" ]
  [ "$(wc -l < "${WORK}/stderr" | tr -d ' ')" = 1 ]
  grep -qF 'accounts.sh on b' "${WORK}/stderr"
}

@test "enabled: the way back printed for an off slot runs as is without accounts.sh on PATH" {
  write_registry
  CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" "${PLUGIN_DIR}/scripts/accounts.sh" off b
  run invoke b
  [ "$status" -eq 2 ]
  local line cmd
  line="$(cat "${WORK}/stderr")"
  cmd="${line#*: run }"
  [ "$cmd" != "$line" ]
  case "$cmd" in /*|\'/*) ;; *) return 1 ;; esac
  # PATH に scripts を入れずに、表示された案内をそのまま実行して戻せる
  run env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" PATH="/usr/bin:/bin" sh -c "$cmd"
  [ "$status" -eq 0 ]
  run invoke b
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=explicit margins=-" ]
}

# ── headroom の余りで選ぶ（usage-account-registry「起動アカウントを headroom の余りから自動選択する」）──

@test "headroom: a slot holding a reset grant wins on surplus though its margin is smaller" {
  # 受け入れ条件 1。週の 50% 経過。a は週次 10%（margin 40・余り 70）。
  # b は週次 40%（margin 10）で、12 時間後に切れるリセット権 1 枚を持つ（余り 約 134）
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $NOW, "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 10, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $NOW, "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 40, "weekly_resets_epoch": $((NOW + 302400)),
           "reset_grants": [ { "resets_left": 1, "ends_at": "2001-09-09T13:46:40Z", "paused": false } ] }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:40.00,b:10.00" ]
}

@test "headroom: a slot whose five-hour use is unknown stays a candidate" {
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $NOW, "five_hour_pct": null,
           "weekly_all_pct": 0, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $NOW, "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 40, "weekly_resets_epoch": $((NOW + 302400)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:50.00,b:10.00" ]
}

@test "headroom: a weekly value observed 61 seconds ahead is stale and 60 seconds ahead is kept" {
  write_registry
  write_snapshot "$NOW" "$((NOW + 61))" 10 10 40 0
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:10.00,b:stale" ]

  write_snapshot "$NOW" "$((NOW + 60))" 10 10 40 0
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:10.00,b:50.00" ]
}

@test "headroom: only stale slots fall back with the missing-usage reason" {
  write_registry
  write_snapshot "$((NOW + 61))" "$((NOW + 61))" 10 10 40 0
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-missing-usage margins=a:stale,b:stale" ]
}

@test "headroom: a session record adopted for the weekly value decides the future check" {
  # b の snapshot は 120 秒先の取得で週次リセットを過ぎている。記録は今の時刻で別の週の窓
  # （同じ窓とみなす 3600 秒の外）を持つので、build_view は記録を週次の実効値に採用する
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $NOW, "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 40, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $((NOW + 120)), "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 30, "weekly_resets_epoch": $((NOW - 10)) }
} }
JSON
  write_record "$SECURE_B" "$NOW" 10 0 "$((NOW + 302400))"
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:10.00,b:50.00" ]
}

@test "headroom: Codex having the most left does not stop selecting a Claude slot" {
  # Codex は週次 0%（余り 90）。Claude は a 40%（余り 10）・b 20%（余り 50）
  write_registry
  write_snapshot "$NOW" "$NOW" 10 10 40 20
  write_codex 0
  run invoke_env "${PLUGIN_DIR}/scripts/headroom.py" --json --now "$NOW"
  [ "$status" -eq 0 ]
  python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["best"]=={"provider":"codex","account":"current"}, d["best"]; assert d["best_by_provider"]["claude"]=={"provider":"claude","account":"b"}' "$output"
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-surplus margins=a:10.00,b:30.00" ]
}

@test "headroom: an invalid headroom setting falls back to the default account" {
  write_registry
  write_snapshot "$NOW" "$NOW" 10 10 40 20
  HEADROOM_CAP=abc
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-invalid-headroom-setting margins=-" ]

  write_registry "\"${SECURE_A}\""
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stderr")" = "selected=@unregistered-default reason=default-due-to-invalid-headroom-setting margins=-" ]
}

@test "headroom: select-account.sh does not count the week itself" {
  # 受け入れ条件 2。margin を数える式（週の秒数）が残っていない
  ! grep -nE '604800|86400|WEEK_SECONDS' "$SELECTOR" || return 1
  grep -qF 'import headroom' "$SELECTOR"
}

@test "headroom: a reset beyond seven days keeps the unclamped negative margin" {
  # a は週次 0%・リセット 8 日先。経過率 100 x (1 - 8/7) = -14.29 を 0 に切り詰めずに出す
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $NOW, "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 0, "weekly_resets_epoch": $((NOW + 691200)) },
  "b": { "fetched_at": $NOW, "five_hour_pct": 10, "five_hour_resets_epoch": $((NOW + 9000)),
           "weekly_all_pct": 40, "weekly_resets_epoch": $((NOW + 302400)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-surplus margins=a:-14.29,b:10.00" ]
}
