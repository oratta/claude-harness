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
}

teardown() {
  rm -rf "$WORK"
}

write_registry() {
  local secure_a="${1:-null}" secure_b="${2:-\"${SECURE_B}\"}"
  cat > "$ACCOUNTS" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": ${secure_a} },
  { "id": "b", "label": "B", "securestorage": ${secure_b} }
] }
JSON
}

# $1=a fetched_at $2=b fetched_at $3=a 5h $4=b 5h $5=a weekly $6=b weekly
write_snapshot() {
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $1, "five_hour_pct": $3,
           "weekly_all_pct": $5, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $2, "five_hour_pct": $4,
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
  printf '{"schema":1,"key":"%s","observed_at":%s,"five_hour_pct":%s,"five_hour_resets_epoch":null,"weekly_all_pct":%s,"weekly_resets_epoch":%s}\n' \
    "$key" "$2" "$3" "$4" "${5:-$((NOW + 302400))}" > "${SESSIONS}/${key}.json"
}

invoke() {
  env -u CLAUDE_SECURESTORAGE_CONFIG_DIR CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" USAGE_SNAPSHOT="$SNAP" \
    USAGE_SESSIONS_DIR="$SESSIONS" \
    SELECT_ACCOUNT_NOW="$NOW" "$SELECTOR" "$@" >"${WORK}/stdout" 2>"${WORK}/stderr"
}

extract_readme_functions() {
  export README_FUNCTIONS="${WORK}/readme-functions.zsh"
  awk '
    /^```zsh$/ { in_zsh = 1; next }
    in_zsh && /^```$/ { exit }
    in_zsh { print }
  ' "$README" > "$README_FUNCTIONS"
}

write_shell_stubs() {
  mkdir -p "${WORK}/bin" "${WORK}/scripts"
  cat > "${WORK}/scripts/usage-probe.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  cat > "${WORK}/scripts/select-account.sh" <<'SH'
#!/usr/bin/env bash
if [ "${SELECTOR_RC:-0}" -ne 0 ]; then
  exit "$SELECTOR_RC"
fi
printf '%s\n' "${SELECTOR_VALUE:-}"
SH
  cat > "${WORK}/bin/claude" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${CLAUDE_SECURESTORAGE_CONFIG_DIR+x}:${CLAUDE_SECURESTORAGE_CONFIG_DIR-}" > "$CLAUDE_ENV_LOG"
printf '<%s>\n' "$@" > "$CLAUDE_ARGS_LOG"
SH
  chmod +x "${WORK}/scripts/usage-probe.sh" \
    "${WORK}/scripts/select-account.sh" "${WORK}/bin/claude"
}

@test "automatic: selects the greatest weekly margin and reports every margin" {
  write_registry
  write_snapshot "$NOW" "$NOW" 10 10 40 20
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-weekly-margin margins=a:10.00,b:30.00" ]
  [ "$(wc -l < "${WORK}/stderr" | tr -d ' ')" = 1 ]
}

@test "automatic: compares unrounded margins even when both display as zero" {
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $NOW, "five_hour_pct": 10,
           "weekly_all_pct": 50, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $NOW, "five_hour_pct": 10,
           "weekly_all_pct": 50, "weekly_resets_epoch": $((NOW + 302399)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-weekly-margin margins=a:0.00,b:0.00" ]
}

@test "age: an old value before its reset still takes part and can win" {
  write_registry
  write_snapshot "$((NOW - 86400))" "$NOW" 10 10 0 40
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-weekly-margin margins=a:50.00,b:10.00" ]
}

@test "age: a value past its weekly reset is compared as 0%" {
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $((NOW - 604800)), "five_hour_pct": 10,
           "weekly_all_pct": 95, "weekly_resets_epoch": $((NOW - 10)) },
  "b": { "fetched_at": $NOW, "five_hour_pct": 10,
           "weekly_all_pct": 30, "weekly_resets_epoch": $((NOW + 302400)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-weekly-margin margins=a:0.00,b:20.00" ]
}

@test "records: session records alone select without a snapshot" {
  write_registry
  write_record "" "$((NOW - 3600))" 10 40
  write_record "$SECURE_B" "$((NOW - 7200))" 10 20
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-weekly-margin margins=a:10.00,b:30.00" ]
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
  grep -qF 'selected=b reason=max-weekly-margin' "${WORK}/stderr"
}

@test "records: B's record is never read as A's" {
  write_registry
  write_record "$SECURE_B" "$NOW" 10 0
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  [ "$(cat "${WORK}/stderr")" = "selected=b reason=max-weekly-margin margins=a:missing,b:50.00" ]
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
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-weekly-margin margins=a:10.00,b:five-hour>=90" ]
}

@test "five-hour guard: all limited slots use a distinct fallback reason" {
  write_registry
  write_snapshot "$NOW" "$NOW" 90 100 40 20
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-five-hour-limit margins=a:five-hour>=90,b:five-hour>=90" ]
  ! grep -qF 'default-due-to-missing-usage' "${WORK}/stderr"
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

@test "README zsh functions launch with unset account env and preserve quoted arguments" {
  command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
  extract_readme_functions
  write_shell_stubs
  export CLAUDE_HARNESS_SCRIPTS="${WORK}/scripts"
  export CLAUDE_ENV_LOG="${WORK}/claude-env"
  export CLAUDE_ARGS_LOG="${WORK}/claude-args"
  export SELECTOR_VALUE=""
  export SELECTOR_RC=0

  run env PATH="${WORK}/bin:${PATH}" CLAUDE_SECURESTORAGE_CONFIG_DIR=inherited \
    zsh -fc 'source "$README_FUNCTIONS"; cld "argument with spaces" "*.md"'
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_ENV_LOG")" = ":" ]
  [ "$(cat "$CLAUDE_ARGS_LOG")" = $'<argument with spaces>\n<*.md>' ]
}

@test "README zsh functions preserve selector exit 2 and do not launch Claude" {
  command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
  extract_readme_functions
  write_shell_stubs
  export CLAUDE_HARNESS_SCRIPTS="${WORK}/scripts"
  export CLAUDE_ENV_LOG="${WORK}/claude-env"
  export CLAUDE_ARGS_LOG="${WORK}/claude-args"
  export SELECTOR_RC=2

  run env PATH="${WORK}/bin:${PATH}" zsh -fc \
    'source "$README_FUNCTIONS"; cld-account missing "argument with spaces"'
  [ "$status" -eq 2 ]
  [ ! -e "$CLAUDE_ENV_LOG" ]
  [ ! -e "$CLAUDE_ARGS_LOG" ]
}

@test "README zsh functions replace legacy aliases" {
  command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
  extract_readme_functions
  write_shell_stubs
  export CLAUDE_HARNESS_SCRIPTS="${WORK}/scripts"
  export CLAUDE_ENV_LOG="${WORK}/claude-env"
  export CLAUDE_ARGS_LOG="${WORK}/claude-args"
  export SELECTOR_VALUE="${SECURE_B}"
  export SELECTOR_RC=0

  run env PATH="${WORK}/bin:${PATH}" zsh -fc \
    'alias cld="claude --dangerously-skip-permissions"; alias cld-account="claude"; source "$README_FUNCTIONS"; cld --resume'
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_ENV_LOG")" = "x:${SECURE_B}" ]
  [ "$(cat "$CLAUDE_ARGS_LOG")" = '<--resume>' ]
}

@test "tie break: equal margins keep registry declaration order" {
  write_registry
  write_snapshot "$NOW" "$NOW" 10 10 25 25
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  grep -qF 'selected=a reason=max-weekly-margin margins=a:25.00,b:25.00' "${WORK}/stderr"
}

@test "a non-numeric fetched_at and a future observation are passed through" {
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": "not-a-number", "five_hour_pct": 1,
           "weekly_all_pct": 1, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $((NOW + 1)), "five_hour_pct": 1,
           "weekly_all_pct": 1, "weekly_resets_epoch": $((NOW + 302400)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=max-weekly-margin margins=a:49.00,b:49.00" ]
}

@test "missing and non-numeric required values are excluded" {
  write_registry
  cat > "$SNAP" <<JSON
{ "schema": 2, "accounts": {
  "a": { "fetched_at": $NOW, "five_hour_pct": null,
           "weekly_all_pct": 1, "weekly_resets_epoch": $((NOW + 302400)) },
  "b": { "fetched_at": $NOW, "five_hour_pct": 1,
           "weekly_all_pct": "bad", "weekly_resets_epoch": $((NOW + 302400)) }
} }
JSON
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-missing-usage margins=a:missing,b:missing" ]
}

@test "streams: a securestorage path with spaces is the only stdout value" {
  write_registry "\"${SECURE_A}\""
  write_snapshot "$NOW" "$NOW" 10 10 0 40
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_A" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(wc -l < "${WORK}/stderr" | tr -d ' ')" = 1 ]
  ! grep -qF 'selected=' "${WORK}/stdout"
}
