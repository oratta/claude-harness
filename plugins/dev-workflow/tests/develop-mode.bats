#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/develop-mode.sh"
  unset DEV_WORKFLOW_UNATTENDED
  OUT="$BATS_TEST_TMPDIR/stdout"
  ERR="$BATS_TEST_TMPDIR/stderr"
}

# Files preserve trailing newlines and keep stderr separate from stdout.
success() {
  local expected=$1 rc=0
  shift
  "$SCRIPT" "$@" >"$OUT" 2>"$ERR" || rc=$?
  [ "$rc" -eq 0 ]
  [ ! -s "$ERR" ]
  printf '%s\n' "$expected" > "$BATS_TEST_TMPDIR/expected"
  cmp "$OUT" "$BATS_TEST_TMPDIR/expected"
}

failure() {
  local rc=0
  "$SCRIPT" "$@" >"$OUT" 2>"$ERR" || rc=$?
  [ "$rc" -eq 1 ]
  [ ! -s "$OUT" ]
  [ -s "$ERR" ]
}

@test "normal: exact lines, newline, empty stderr and success status" {
  success '実行モード: interactive（既定）'
  success '実行モード: channel（チャンネルの依頼）' --channel-request
  export DEV_WORKFLOW_UNATTENDED=1
  success '実行モード: channel（印）'
  success '実行モード: unmanned（引数）' --unmanned
}

@test "precedence: unmanned wins, order and duplicates do not matter" {
  export DEV_WORKFLOW_UNATTENDED=1
  success '実行モード: unmanned（引数）' --unmanned --channel-request
  success '実行モード: unmanned（引数）' --channel-request --unmanned
  success '実行モード: unmanned（引数）' --channel-request --unmanned --unmanned --channel-request
  success '実行モード: channel（印）' --channel-request --channel-request
  unset DEV_WORKFLOW_UNATTENDED
  success '実行モード: channel（チャンネルの依頼）' --channel-request --channel-request
}

@test "marker: unset, empty, zero and ASCII or Unicode whitespace are absent" {
  local value
  success '実行モード: interactive（既定）'
  success '実行モード: channel（チャンネルの依頼）' --channel-request
  for value in '' 0 ' 0 ' $' \t\r\n' $' \t\r\n0\r\n\t ' $'\xc2\xa0\xe3\x80\x80' $'\xc2\xa00\xe3\x80\x80'; do
    export DEV_WORKFLOW_UNATTENDED="$value"
    success '実行モード: interactive（既定）'
    success '実行モード: channel（チャンネルの依頼）' --channel-request
  done
}

@test "marker: nonzero nonempty strings including false and double zero are present" {
  local value
  for value in 1 false 00 $' \t\r\nhello\xc2\xa0\xe3\x80\x80'; do
    export DEV_WORKFLOW_UNATTENDED="$value"
    success '実行モード: channel（印）'
    success '実行モード: channel（印）' --channel-request
  done
}

@test "help: both standalone aliases describe inputs, normalization and results" {
  local flag rc word
  for flag in --help -h; do
    rc=0
    "$SCRIPT" "$flag" >"$OUT" 2>"$ERR" || rc=$?
    [ "$rc" -eq 0 ]
    [ ! -s "$ERR" ]
    for word in 'Usage:' '--unmanned' '--channel-request' '<channel source=' DEV_WORKFLOW_UNATTENDED '.strip()' '優先順' 'exit 0' 'exit 1' '実行モード: interactive（既定）' '実行モード: channel（印）' '実行モード: channel（チャンネルの依頼）' '実行モード: unmanned（引数）'; do
      grep -qF -- "$word" "$OUT"
    done
  done
}

@test "arguments: unknown, positional, assigned values and combined help fail" {
  local arg
  for arg in --unknown 1686 --unmanned=true --channel-request=true; do
    failure "$arg"
    grep -qF 'Usage:' "$ERR"
  done
  failure --help --unmanned
  failure --channel-request -h
  failure --help --help
}

@test "runtime: missing or failing Python never produces a default mode" {
  mkdir "$BATS_TEST_TMPDIR/bin"
  local flag
  for flag in --unmanned --channel-request; do
    PATH="$BATS_TEST_TMPDIR/bin" failure "$flag"
    grep -qi 'python' "$ERR"
  done
  printf '#!/bin/sh\nexit 7\n' > "$BATS_TEST_TMPDIR/bin/python3"
  chmod +x "$BATS_TEST_TMPDIR/bin/python3"
  PATH="$BATS_TEST_TMPDIR/bin" failure
  grep -qi 'python' "$ERR"
}

@test "runtime: successful Python with empty or malformed output fails" {
  mkdir "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\nexit 0\n' > "$BATS_TEST_TMPDIR/bin/python3"
  chmod +x "$BATS_TEST_TMPDIR/bin/python3"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" failure
  grep -qi 'python' "$ERR"

  local value
  for value in 'unexpected' $'実行モード: interactive（既定）\nextra'; do
    printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$value" > "$BATS_TEST_TMPDIR/bin/python3"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" failure
    grep -qi 'python' "$ERR"
  done
}

@test "isolation: no external operation commands or state changes" {
  local cmd
  mkdir "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/home" "$BATS_TEST_TMPDIR/work"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  : > "$CALLS"
  for cmd in gh git claude orca; do
    printf '#!/bin/sh\nprintf "called\\n" >> "$CALLS"\nexit 99\n' > "$BATS_TEST_TMPDIR/bin/$cmd"
    chmod +x "$BATS_TEST_TMPDIR/bin/$cmd"
  done
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH" HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/config" CODEX_HOME="$HOME/codex" CLAUDE_CONFIG_DIR="$HOME/claude"
  printf 'unchanged\n' > "$HOME/settings.json"
  cd "$BATS_TEST_TMPDIR/work"
  success '実行モード: interactive（既定）'
  success '実行モード: channel（チャンネルの依頼）' --channel-request
  export DEV_WORKFLOW_UNATTENDED=1
  success '実行モード: channel（印）'
  success '実行モード: unmanned（引数）' --unmanned
  "$SCRIPT" --help >"$OUT" 2>"$ERR"
  "$SCRIPT" -h >"$OUT" 2>"$ERR"
  failure --unknown
  [ ! -s "$CALLS" ]
  [ "$(find "$HOME" -type f)" = "$HOME/settings.json" ]
  [ "$(cat "$HOME/settings.json")" = unchanged ]
  [ -z "$(find . -mindepth 1)" ]
}
