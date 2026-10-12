#!/usr/bin/env bats
#
# accounts.sh: 登録簿の一覧・追加・オン・オフ。
# spec: usage-account-registry（登録簿を一覧・追加・オン・オフするコマンド）
#
# 実ホームは触らない。登録簿は CLAUDE_ACCOUNTS_FILE、基点は CLAUDE_ACCOUNTS_HOME を一時ディレクトリに向ける。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CMD="${PLUGIN_DIR}/scripts/accounts.sh"
  INIT="${PLUGIN_DIR}/scripts/accounts-init.sh"
  WORK="$(mktemp -d)"
  export CLAUDE_ACCOUNTS_FILE="${WORK}/accounts.json"
  export CLAUDE_ACCOUNTS_HOME="${WORK}/home"
  unset CLAUDE_SECURESTORAGE_CONFIG_DIR
}

teardown() {
  rm -rf "$WORK"
}

write_registry() {
  cat > "$CLAUDE_ACCOUNTS_FILE" <<JSON
{ "schema": 1, "accounts": [
  { "id": "a", "label": "A", "securestorage": null },
  { "id": "b", "label": "B", "securestorage": "/x/b", "extra": [1, 2] },
  { "id": "c", "label": "C", "securestorage": "/x/c", "enabled": false }
] }
JSON
}

@test "add: appends a slot to an empty registry and creates the directory" {
  printf '{"schema":1,"accounts":[]}\n' > "$CLAUDE_ACCOUNTS_FILE"
  run "$CMD" add b --label B
  [ "$status" -eq 0 ]
  [ -d "${CLAUDE_ACCOUNTS_HOME}/b" ]
  run python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
assert len(d["accounts"])==1, d
s=d["accounts"][0]
assert s=={"id":"b","label":"B","securestorage":sys.argv[2]}, s
' "$CLAUDE_ACCOUNTS_FILE" "${CLAUDE_ACCOUNTS_HOME}/b"
  [ "$status" -eq 0 ]
}

@test "add: prints one login command line on stdout" {
  printf '{"schema":1,"accounts":[]}\n' > "$CLAUDE_ACCOUNTS_FILE"
  run --separate-stderr "$CMD" add b
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = 1 ]
  [ "${output#CLAUDE_SECURESTORAGE_CONFIG_DIR=\'}" != "$output" ]
  [ "${output%\' claude}" != "$output" ]
}

@test "add: creates the registry when it does not exist, without a .bak" {
  run "$CMD" add b
  [ "$status" -eq 0 ]
  [ -f "$CLAUDE_ACCOUNTS_FILE" ]
  [ ! -e "${CLAUDE_ACCOUNTS_FILE}.bak" ]
}

@test "add: an existing id exits 2, leaves the registry and does not create the directory" {
  write_registry
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  run "$CMD" add b
  [ "$status" -eq 2 ]
  cmp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  [ ! -e "${CLAUDE_ACCOUNTS_HOME}/b" ]
}

@test "add: a login command with a space and a quote in the base evaluates to the securestorage" {
  export CLAUDE_ACCOUNTS_HOME="${WORK}/ho me's"
  printf '{"schema":1,"accounts":[]}\n' > "$CLAUDE_ACCOUNTS_FILE"
  run --separate-stderr "$CMD" add b
  [ "$status" -eq 0 ]
  local line="$output"
  local got
  got="$(bash -c "${line%claude}"'printenv CLAUDE_SECURESTORAGE_CONFIG_DIR')"
  local want
  want="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["accounts"][0]["securestorage"])' "$CLAUDE_ACCOUNTS_FILE")"
  [ "$got" = "$want" ]
  [ "$want" = "${WORK}/ho me's/b" ]
}

@test "add: a relative CLAUDE_ACCOUNTS_HOME exits 2 and changes nothing" {
  write_registry
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  CLAUDE_ACCOUNTS_HOME="rel/path" run "$CMD" add z
  [ "$status" -eq 2 ]
  cmp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  [ ! -e "${WORK}/rel" ]
}

@test "add: invalid id and label exit 2" {
  write_registry
  run "$CMD" add 'bad id'
  [ "$status" -eq 2 ]
  run "$CMD" add "$(printf 'x%.0s' $(seq 1 33))"
  [ "$status" -eq 2 ]
  run "$CMD" add z --label "$(printf 'y%.0s' $(seq 1 17))"
  [ "$status" -eq 2 ]
  run "$CMD" add z --label
  [ "$status" -eq 2 ]
}

@test "off then on: enabled goes false then true; other fields and order are unchanged" {
  write_registry
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/orig"
  run "$CMD" off b
  [ "$status" -eq 0 ]
  run python3 - "$CLAUDE_ACCOUNTS_FILE" "${WORK}/orig" false <<'PY'
import json,sys
new=json.load(open(sys.argv[1])); old=json.load(open(sys.argv[2]))
want=sys.argv[3]=="true"
assert [s["id"] for s in new["accounts"]]==["a","b","c"]
for n,o in zip(new["accounts"],old["accounts"]):
    if o["id"]=="b":
        assert n["enabled"] is want, n
        n=dict(n); n.pop("enabled")
    assert n==o, (n,o)
PY
  [ "$status" -eq 0 ]
  run "$CMD" on b
  [ "$status" -eq 0 ]
  run python3 - "$CLAUDE_ACCOUNTS_FILE" "${WORK}/orig" true <<'PY'
import json,sys
new=json.load(open(sys.argv[1])); old=json.load(open(sys.argv[2]))
want=sys.argv[3]=="true"
assert [s["id"] for s in new["accounts"]]==["a","b","c"]
for n,o in zip(new["accounts"],old["accounts"]):
    if o["id"]=="b":
        assert n["enabled"] is want, n
        n=dict(n); n.pop("enabled")
    assert n==o, (n,o)
PY
  [ "$status" -eq 0 ]
}

@test "off: the credential directory is not removed" {
  write_registry
  mkdir -p "${CLAUDE_ACCOUNTS_HOME}/b"
  run "$CMD" off b
  [ "$status" -eq 0 ]
  [ -d "${CLAUDE_ACCOUNTS_HOME}/b" ]
}

@test "on/off: an unknown id exits 2 and leaves the registry" {
  write_registry
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  run "$CMD" off z
  [ "$status" -eq 2 ]
  run "$CMD" on z
  [ "$status" -eq 2 ]
  cmp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
}

@test "list: prints tab-separated id label on|off securestorage, null as -" {
  write_registry
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  run --separate-stderr "$CMD" list
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | sed -n 1p)" = "$(printf 'a\tA\ton\t-')" ]
  [ "$(printf '%s\n' "$output" | sed -n 2p)" = "$(printf 'b\tB\ton\t/x/b')" ]
  [ "$(printf '%s\n' "$output" | sed -n 3p)" = "$(printf 'c\tC\toff\t/x/c')" ]
  cmp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
}

@test "list: a slot turned off with off shows off" {
  write_registry
  run "$CMD" off b
  [ "$status" -eq 0 ]
  run --separate-stderr "$CMD" list
  [ "$(printf '%s\n' "$output" | sed -n 2p)" = "$(printf 'b\tB\toff\t/x/b')" ]
}

@test "broken registry: exit 1 and not a byte changed (off, on, add, list)" {
  printf '{ "schema": 1, "accounts": [ ' > "$CLAUDE_ACCOUNTS_FILE"
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  run "$CMD" off b
  [ "$status" -eq 1 ]
  run "$CMD" on b
  [ "$status" -eq 1 ]
  run "$CMD" add b
  [ "$status" -eq 1 ]
  run "$CMD" list
  [ "$status" -eq 1 ]
  cmp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  [ ! -e "${CLAUDE_ACCOUNTS_HOME}/b" ]
}

@test "registry whose accounts is not an array: exit 1 and unchanged" {
  printf '{"schema":1,"accounts":{"a":1}}\n' > "$CLAUDE_ACCOUNTS_FILE"
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  run "$CMD" off a
  [ "$status" -eq 1 ]
  run "$CMD" add b
  [ "$status" -eq 1 ]
  cmp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  printf '[1,2]\n' > "$CLAUDE_ACCOUNTS_FILE"
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  run "$CMD" off a
  [ "$status" -eq 1 ]
  cmp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
}

@test "backup: .bak is identical to the registry before the write" {
  write_registry
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  run "$CMD" off b
  [ "$status" -eq 0 ]
  cmp "${CLAUDE_ACCOUNTS_FILE}.bak" "${WORK}/before"
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before2"
  run "$CMD" on b
  [ "$status" -eq 0 ]
  cmp "${CLAUDE_ACCOUNTS_FILE}.bak" "${WORK}/before2"
}

@test "usage: unknown subcommand, no subcommand and missing arguments exit 2" {
  write_registry
  cp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
  run "$CMD" frobnicate
  [ "$status" -eq 2 ]
  run "$CMD"
  [ "$status" -eq 2 ]
  run "$CMD" add
  [ "$status" -eq 2 ]
  run "$CMD" off
  [ "$status" -eq 2 ]
  run "$CMD" on
  [ "$status" -eq 2 ]
  run "$CMD" off b extra
  [ "$status" -eq 2 ]
  cmp "$CLAUDE_ACCOUNTS_FILE" "${WORK}/before"
}

@test "accounts-init.sh still works against a registry written by accounts.sh" {
  printf '{"schema":1,"accounts":[]}\n' > "$CLAUDE_ACCOUNTS_FILE"
  run "$CMD" add b
  [ "$status" -eq 0 ]
  run "$CMD" off b
  [ "$status" -eq 0 ]
  CLAUDE_SECURESTORAGE_CONFIG_DIR="${WORK}/other" run "$INIT" --id b --label B
  [ "$status" -eq 0 ]
  run python3 -c '
import json,sys
s=json.load(open(sys.argv[1]))["accounts"][0]
assert s["enabled"] is False and s["securestorage"]==sys.argv[2], s
' "$CLAUDE_ACCOUNTS_FILE" "${WORK}/other"
  [ "$status" -eq 0 ]
}
