#!/usr/bin/env bats
#
# dev-workflow-account-selector:
#   accounts.json と schema 2 usage snapshot から起動アカウントを選ぶ規則。
#
# spec: usage-account-registry（起動アカウント選択）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SELECTOR="${PLUGIN_DIR}/scripts/select-account.sh"
  WORK="$(mktemp -d)"
  ACCOUNTS="${WORK}/accounts.json"
  SNAP="${WORK}/.usage-snapshot"
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

invoke() {
  env CLAUDE_ACCOUNTS_FILE="$ACCOUNTS" USAGE_SNAPSHOT="$SNAP" \
    SELECT_ACCOUNT_NOW="$NOW" "$SELECTOR" "$@" >"${WORK}/stdout" 2>"${WORK}/stderr"
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

@test "freshness: age 299 is eligible and age 300 is stale" {
  write_registry
  write_snapshot "$((NOW - 300))" "$((NOW - 299))" 10 10 0 40
  run invoke
  [ "$status" -eq 0 ]
  [ "$(cat "${WORK}/stdout")" = "$SECURE_B" ]
  grep -qF 'margins=a:stale,b:10.00' "${WORK}/stderr"
}

@test "freshness: a stale higher-margin slot loses to a fresh slot" {
  write_registry
  write_snapshot "$((NOW - 1))" "$((NOW - 300))" 10 10 49 0
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  grep -qF 'selected=a reason=max-weekly-margin margins=a:1.00,b:stale' "${WORK}/stderr"
}

@test "fallback: all stale slots select the registered default id" {
  write_registry
  write_snapshot "$((NOW - 300))" "$((NOW - 301))" 10 10 40 20
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-missing-usage margins=a:stale,b:stale" ]
}

@test "fallback: an unregistered default uses the sentinel" {
  write_registry "\"${SECURE_A}\""
  write_snapshot "$((NOW - 300))" "$((NOW - 301))" 10 10 40 20
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

@test "tie break: equal margins keep registry declaration order" {
  write_registry
  write_snapshot "$NOW" "$NOW" 10 10 25 25
  run invoke
  [ "$status" -eq 0 ]
  [ -z "$(cat "${WORK}/stdout")" ]
  [ "$(wc -l < "${WORK}/stdout" | tr -d ' ')" = 1 ]
  grep -qF 'selected=a reason=max-weekly-margin margins=a:25.00,b:25.00' "${WORK}/stderr"
}

@test "invalid selection fields are missing and a future observation is stale" {
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
  [ "$(cat "${WORK}/stderr")" = "selected=a reason=default-due-to-missing-usage margins=a:missing,b:stale" ]
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
