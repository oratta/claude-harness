#!/usr/bin/env bats
#
# spec: cost-ledger-persistence（台帳の場所の解決）
#
# 台帳パスは userConfig の LEDGER_PATH（環境変数 CLAUDE_PLUGIN_OPTION_LEDGER_PATH）と
# 従来の COST_LEDGER_PATH の 2 つで決まる。前者が優先。台帳・会話ログは $BATS_TEST_TMPDIR だけに置く。

load helper

setup() {
  export LC_ALL=C.UTF-8
  cl_setup
  HOOK="$PLUGIN_DIR/scripts/ledger-hook.sh"
  NEW_LEDGER="$BATS_TEST_TMPDIR/new-home/ledger.jsonl"
  OLD_LEDGER="$BATS_TEST_TMPDIR/old-home/ledger.jsonl"
  cl_row S1 r1 "2026-09-01T00:00:01.000Z" feat/x /nonexistent/x 1000000 | cl_write_log a
}

@test "userconfig: plugin.json declares LEDGER_PATH as a file without default" {  # 宣言
  local json="$PLUGIN_DIR/.claude-plugin/plugin.json"
  [ "$(jq -r '.userConfig | keys | index("LEDGER_PATH") != null' "$json")" = true ]
  [ "$(jq -r '.userConfig.LEDGER_PATH.type' "$json")" = file ]
  [ "$(jq -r '.userConfig.LEDGER_PATH | has("default")' "$json")" = false ]
}

@test "userconfig: hook appends with CLAUDE_PLUGIN_OPTION_LEDGER_PATH only" {  # userConfig だけ
  CLAUDE_PLUGIN_OPTION_LEDGER_PATH="$NEW_LEDGER" run sh "$HOOK" </dev/null
  [ "$status" -eq 0 ] && [ -z "$output" ]
  [ "$(wc -l < "$NEW_LEDGER" | tr -d ' ')" = 1 ]
}

@test "userconfig: hook appends with COST_LEDGER_PATH only" {  # 従来だけ
  COST_LEDGER_PATH="$OLD_LEDGER" run sh "$HOOK" </dev/null
  [ "$status" -eq 0 ] && [ -z "$output" ]
  [ "$(wc -l < "$OLD_LEDGER" | tr -d ' ')" = 1 ]
}

@test "userconfig: when both are set the userConfig path wins" {  # 両方
  CLAUDE_PLUGIN_OPTION_LEDGER_PATH="$NEW_LEDGER" COST_LEDGER_PATH="$OLD_LEDGER" run sh "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [ -s "$NEW_LEDGER" ]
  [ ! -e "$OLD_LEDGER" ]
}

@test "userconfig: an empty userConfig value falls back to COST_LEDGER_PATH" {  # 空文字
  CLAUDE_PLUGIN_OPTION_LEDGER_PATH="" COST_LEDGER_PATH="$OLD_LEDGER" run sh "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [ -s "$OLD_LEDGER" ]
}

@test "userconfig: hook does nothing and does not start python when both are unset or empty" {  # どちらも無し
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\ntouch "%s/python-started"\n' "$BATS_TEST_TMPDIR" >| "$BATS_TEST_TMPDIR/bin/python3"
  chmod +x "$BATS_TEST_TMPDIR/bin/python3"
  CLAUDE_PLUGIN_OPTION_LEDGER_PATH="" COST_LEDGER_PATH="" run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" sh "$HOOK" </dev/null
  [ "$status" -eq 0 ] && [ -z "$output" ]
  [ ! -e "$BATS_TEST_TMPDIR/python-started" ]
}

@test "userconfig: cost reads from the ledger when only the userConfig variable is set" {  # /cost
  export CLAUDE_PLUGIN_OPTION_LEDGER_PATH="$NEW_LEDGER"
  run python3 "$CL" ledger-sync
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  mv "$CONFIG_DIR/projects" "$BATS_TEST_TMPDIR/away"; mkdir -p "$CONFIG_DIR/projects"
  run python3 "$CL" branch feat/x
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *'$1.00'* ]] || { echo "$output"; return 1; }
}

@test "userconfig: an unsubstituted placeholder falls back to COST_LEDGER_PATH" {  # プレースホルダ
  mkdir -p "$BATS_TEST_TMPDIR/cwd"
  cd "$BATS_TEST_TMPDIR/cwd"
  CLAUDE_PLUGIN_OPTION_LEDGER_PATH='${user_config.LEDGER_PATH}' COST_LEDGER_PATH="$OLD_LEDGER" run python3 "$CL" ledger-sync
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ -s "$OLD_LEDGER" ]
  [ ! -e "$BATS_TEST_TMPDIR/cwd/\${user_config.LEDGER_PATH}" ]
}

@test "userconfig: an unsubstituted placeholder alone means no ledger" {  # プレースホルダだけ
  mkdir -p "$BATS_TEST_TMPDIR/cwd"
  cd "$BATS_TEST_TMPDIR/cwd"
  CLAUDE_PLUGIN_OPTION_LEDGER_PATH='${user_config.LEDGER_PATH}' run python3 "$CL" branch feat/x
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == *'$1.00'* ]] || { echo "$output"; return 1; }
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/cwd")" ]
}

@test "userconfig: hook treats an unsubstituted placeholder as unset and writes nothing in cwd" {  # hook・プレースホルダだけ
  mkdir -p "$BATS_TEST_TMPDIR/cwd"
  cd "$BATS_TEST_TMPDIR/cwd"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\ntouch "%s/python-started"\n' "$BATS_TEST_TMPDIR" >| "$BATS_TEST_TMPDIR/bin/python3"
  chmod +x "$BATS_TEST_TMPDIR/bin/python3"
  CLAUDE_PLUGIN_OPTION_LEDGER_PATH='${user_config.LEDGER_PATH}' COST_LEDGER_PATH="" run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" sh "$HOOK" </dev/null
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ -z "$output" ] || return 1
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/cwd")" ] || return 1
  [ ! -e "$BATS_TEST_TMPDIR/python-started" ] || return 1
}

@test "userconfig: hook with an unsubstituted placeholder and COST_LEDGER_PATH appends to COST_LEDGER_PATH" {  # hook・プレースホルダ＋従来
  mkdir -p "$BATS_TEST_TMPDIR/cwd"
  cd "$BATS_TEST_TMPDIR/cwd"
  CLAUDE_PLUGIN_OPTION_LEDGER_PATH='${user_config.LEDGER_PATH}' COST_LEDGER_PATH="$OLD_LEDGER" run sh "$HOOK" </dev/null
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(wc -l < "$OLD_LEDGER" | tr -d ' ')" = 1 ] || return 1
  [ -z "$(ls -A "$BATS_TEST_TMPDIR/cwd")" ] || return 1
}
