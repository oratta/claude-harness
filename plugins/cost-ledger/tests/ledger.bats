#!/usr/bin/env bats
#
# spec: cost-ledger-persistence
#
# 会話ログが消えてもコストが残る台帳（COST_LEDGER_PATH）と、Stop hook による差分追記を固定する。
# 台帳・控え・会話ログはすべて $BATS_TEST_TMPDIR に置き、利用者の台帳と会話ログには触れない。

load helper

setup() {
  export LC_ALL=C.UTF-8
  cl_setup
  LEDGER="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
  HOOK="$PLUGIN_DIR/scripts/ledger-hook.sh"
  unset COST_LEDGER_PATH
}

# 1 応答 1 行のログを書く（haiku・input_tokens=1000000 で $1.00）
write_rows() {  # $1=ログの名前 $2..=requestId
  local name="$1"
  shift
  local rid
  for rid in "$@"; do
    cl_row S1 "$rid" "2026-09-01T00:00:0${#rid}.000Z" feat/x /nonexistent/x 1000000
  done | cl_write_log "$name"
}

append_row() {  # $1=ログの名前 $2=requestId
  cl_row S1 "$2" "2026-09-01T00:01:00.000Z" feat/x /nonexistent/x 1000000 \
    >> "$CONFIG_DIR/projects/$1/$1.jsonl"
}

ledger_lines() {
  if [ -f "$LEDGER" ]; then wc -l < "$LEDGER" | tr -d ' '; else echo 0; fi
}

@test "ledger: COST_LEDGER_PATH unset reads logs directly and creates no ledger" {  # 未設定なら台帳は作られず、会話ログ直読みの値
  write_rows a r1 r2
  run python3 "$CL" branch feat/x
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == *'$2.00'* ]] || { echo "$output"; return 1; }
  [ ! -e "$LEDGER" ] || return 1
  [ -z "$(ls -A "$BATS_TEST_TMPDIR" | grep ledger-home)" ] || return 1
}

@test "ledger: ledger-sync without COST_LEDGER_PATH exits 2" {  # 未設定の ledger-sync は終了コード 2
  run python3 "$CL" ledger-sync
  [ "$status" -eq 2 ] || { echo "$output"; return 1; }
  [[ "$output" == *COST_LEDGER_PATH* ]] || { echo "$output"; return 1; }
}

@test "ledger: a ledger inside the plugin repository is refused" {  # リポジトリ配下は終了コード 2 で作らない
  local inside="$REPO_ROOT/h274-should-not-exist.jsonl"
  export COST_LEDGER_PATH="$inside"
  write_rows a r1
  run python3 "$CL" ledger-sync
  [ "$status" -eq 2 ] || { echo "$output"; return 1; }
  [ ! -e "$inside" ] || { rm -f "$inside" "$inside".*; return 1; }
  [ ! -e "$inside.lock" ] || { rm -f "$inside".*; return 1; }
}

@test "ledger: each ledger line equals the fact extracted from the log" {  # 台帳の行は facts（直読み）の行と同じ
  write_rows a r1 r2
  run python3 "$CL" facts
  [ "$status" -eq 0 ] || return 1
  local direct="$output"
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"2 行追記"* ]] || { echo "$output"; return 1; }
  [ "$(cat "$LEDGER")" = "$direct" ] || { diff <(echo "$direct") "$LEDGER"; return 1; }
}

@test "ledger: running ledger-sync twice appends nothing the second time" {  # 2 回目は 0 行
  write_rows a r1 r2
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  run python3 "$CL" ledger-sync
  [[ "$output" == *"0 行追記"* ]] || { echo "$output"; return 1; }
  [ "$(ledger_lines)" -eq 2 ] || return 1
}

@test "ledger: only the new response is appended" {  # 増えた 1 行だけを追記する
  write_rows a r1 r2
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  append_row a r3
  run python3 "$CL" ledger-sync
  [[ "$output" == *"1 行追記"* ]] || { echo "$output"; return 1; }
  [ "$(ledger_lines)" -eq 3 ] || return 1
  [ "$(grep -c '"request_id": "r3"' "$LEDGER")" -eq 1 ] || return 1
}

@test "ledger: losing or corrupting the state file keeps the ledger unchanged" {  # 控えが消えても壊れても行数は変わらない
  write_rows a r1 r2
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  rm -f "$LEDGER.state.sqlite"
  run python3 "$CL" ledger-sync
  [[ "$output" == *"0 行追記"* ]] || { echo "$output"; return 1; }
  echo "not a database" >| "$LEDGER.state.sqlite"
  run python3 "$CL" ledger-sync
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *"0 行追記"* ]] || { echo "$output"; return 1; }
  [ "$(ledger_lines)" -eq 2 ] || return 1
}

@test "ledger: the same requestId in two logs is written once" {  # ファイルをまたぐ重複は 1 行
  write_rows a r1 r2
  write_rows b r2 r3
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  [ "$(ledger_lines)" -eq 3 ] || { cat "$LEDGER"; return 1; }
  [ "$(grep -c '"request_id": "r2"' "$LEDGER")" -eq 1 ] || return 1
  # 後から別ファイルに同じ requestId が来ても書かない
  write_rows c r1
  python3 "$CL" ledger-sync --quiet
  [ "$(ledger_lines)" -eq 3 ] || return 1
}

@test "ledger: a half-written last line waits for the next sync" {  # 書きかけの末尾行は次回に 1 行だけ書く
  write_rows a r1
  export COST_LEDGER_PATH="$LEDGER"
  local log="$CONFIG_DIR/projects/a/a.jsonl" row
  row="$(cl_row S1 r2 2026-09-01T00:02:00.000Z feat/x /nonexistent/x 1000000)"
  printf '%s' "${row:0:40}" >> "$log"
  python3 "$CL" ledger-sync --quiet
  [ "$(ledger_lines)" -eq 1 ] || { cat "$LEDGER"; return 1; }
  printf '%s\n' "${row:40}" >> "$log"
  run python3 "$CL" ledger-sync
  [[ "$output" == *"1 行追記"* ]] || { echo "$output"; return 1; }
  [ "$(grep -c '"request_id": "r2"' "$LEDGER")" -eq 1 ] || return 1
}

@test "ledger: a truncated or replaced log is reread from the start" {  # ファイルが縮んだら先頭から読み直す（重複は書かない）
  write_rows a r1 r2 r3
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  write_rows a r4
  python3 "$CL" ledger-sync --quiet
  [ "$(ledger_lines)" -eq 4 ] || { cat "$LEDGER"; return 1; }
}

@test "ledger: syncing another log root keeps this root's read positions" {  # 別の置き場所で同期しても、次は増えた分だけ読む
  write_rows a r1 r2
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  # CLAUDE_CONFIG_DIR の違う別アカウントが同じ台帳へ同期する（置き場所は空）
  local other="$BATS_TEST_TMPDIR/claude-other"
  mkdir -p "$other/projects"
  CLAUDE_CONFIG_DIR="$other" python3 "$CL" ledger-sync --quiet
  # 読み終えた部分を同じ長さ・同じ inode のまま書き換える。読み終え位置が残っていれば
  # 先頭から読み直さないので、書き換えた r9 は台帳に入らない
  python3 - "$CONFIG_DIR/projects/a/a.jsonl" <<'PY'
import sys
with open(sys.argv[1], "r+b") as fh:
    data = fh.read()
    fh.seek(0)
    fh.write(data.replace(b'"r1"', b'"r9"'))
PY
  append_row a r3
  run python3 "$CL" ledger-sync
  [[ "$output" == *"1 行追記"* ]] || { echo "$output"; cat "$LEDGER"; return 1; }
  [ "$(grep -c '"request_id": "r9"' "$LEDGER")" -eq 0 ] || return 1
  [ "$(grep -c '"request_id": "r3"' "$LEDGER")" -eq 1 ] || return 1
}

@test "ledger: the same log root reached through a symlink keeps its read positions" {  # シンボリックリンク経由でも、次は増えた分だけ読む
  write_rows a r1 r2
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  local link="$BATS_TEST_TMPDIR/claude-link"
  ln -s "$CONFIG_DIR" "$link"
  # 読み終えた部分を同じ長さ・同じ inode のまま書き換える（上のテストと同じ見分け方）
  python3 - "$CONFIG_DIR/projects/a/a.jsonl" <<'PY'
import sys
with open(sys.argv[1], "r+b") as fh:
    data = fh.read()
    fh.seek(0)
    fh.write(data.replace(b'"r1"', b'"r9"'))
PY
  append_row a r3
  CLAUDE_CONFIG_DIR="$link" run python3 "$CL" ledger-sync
  [[ "$output" == *"1 行追記"* ]] || { echo "$output"; cat "$LEDGER"; return 1; }
  [ "$(grep -c '"request_id": "r9"' "$LEDGER")" -eq 0 ] || return 1
  # リンクを外した元の表記に戻しても、読み終え位置は同じものを使う
  append_row a r4
  run python3 "$CL" ledger-sync
  [[ "$output" == *"1 行追記"* ]] || { echo "$output"; cat "$LEDGER"; return 1; }
  [ "$(grep -c '"request_id": "r9"' "$LEDGER")" -eq 0 ] || return 1
}

@test "ledger: hooks.json registers ledger-hook.sh on Stop" {  # Stop に ledger-hook.sh が登録されている
  [ -x "$HOOK" ] || return 1
  run python3 - "$PLUGIN_DIR/hooks/hooks.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
handlers = [h for e in d["hooks"]["Stop"] for h in e["hooks"]
            if h.get("command") == '"${CLAUDE_PLUGIN_ROOT}/scripts/ledger-hook.sh"']
assert len(handlers) == 1, handlers
assert handlers[0].get("type") == "command", handlers
assert handlers[0].get("timeout") == 120, handlers
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "ledger: the hook does nothing and starts no python3 without COST_LEDGER_PATH" {  # 未設定なら python3 を起動しない
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho started >> "%s"\nexit 1\n' "$BATS_TEST_TMPDIR/python3.log" > "$BATS_TEST_TMPDIR/bin/python3"
  chmod +x "$BATS_TEST_TMPDIR/bin/python3"
  write_rows a r1
  run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" sh "$HOOK" <<< '{"hook_event_name":"Stop"}'
  [ "$status" -eq 0 ] || return 1
  [ -z "$output" ] || { echo "$output"; return 1; }
  [ ! -e "$BATS_TEST_TMPDIR/python3.log" ] || return 1
}

@test "ledger: the hook appends silently" {  # hook が追記し、出力は空で 0
  write_rows a r1 r2
  export COST_LEDGER_PATH="$LEDGER"
  run sh "$HOOK" <<< '{"hook_event_name":"Stop"}'
  [ "$status" -eq 0 ] || return 1
  [ -z "$output" ] || { echo "$output"; return 1; }
  [ "$(ledger_lines)" -eq 2 ] || return 1
}

@test "ledger: the hook stays silent and exits 0 on failure" {  # リポジトリ配下でも出力は空で 0
  write_rows a r1
  export COST_LEDGER_PATH="$REPO_ROOT/h274-should-not-exist.jsonl"
  run sh "$HOOK" <<< '{"hook_event_name":"Stop"}'
  [ "$status" -eq 0 ] || return 1
  [ -z "$output" ] || { echo "$output"; return 1; }
  [ ! -e "$COST_LEDGER_PATH" ] || { rm -f "$COST_LEDGER_PATH"*; return 1; }
}

@test "ledger: concurrent hooks neither duplicate nor drop lines" {  # 同時に動いても 1 requestId 1 行
  local i rids=()
  for i in $(seq 1 200); do rids+=("q$i"); done
  write_rows a "${rids[@]}"
  write_rows b "${rids[@]:100}"
  export COST_LEDGER_PATH="$LEDGER"
  sh "$HOOK" </dev/null &
  local p1=$!
  sh "$HOOK" </dev/null &
  local p2=$!
  sh "$HOOK" </dev/null
  wait "$p1" "$p2"
  [ "$(ledger_lines)" -eq 200 ] || { echo "lines=$(ledger_lines)"; return 1; }
  [ "$(cut -c1-40 "$LEDGER" | sort | uniq -d | wc -l | tr -d ' ')" -eq 0 ] || return 1
}

@test "ledger: /cost returns the same value after the logs are moved away" {  # 会話ログ退避後も PR の 1 行目が同じ
  cl_materialize
  cl_fake_gh <<'SH'
case "$*" in
  *pulls/42*) echo "oratta/sample-feature" ;;
  *) exit 1 ;;
esac
SH
  run python3 "$CL" cost 42 --repo "$REPO_A"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  local before="${lines[0]}"
  [[ "$before" != *'$0.00'* ]] || { echo "$output"; return 1; }
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  mv "$CONFIG_DIR/projects" "$BATS_TEST_TMPDIR/projects-moved"
  mkdir -p "$CONFIG_DIR/projects"
  run python3 "$CL" cost 42 --repo "$REPO_A"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "${lines[0]}" = "$before" ] || { echo "before=$before"; echo "$output"; return 1; }
}

@test "ledger: rows written after the last sync are included without waiting for the hook" {  # 最後の追記以降の行も含む
  write_rows a r1
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  append_row a r2
  run python3 "$CL" branch feat/x
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == *'$2.00'* ]] || { echo "$output"; return 1; }
}

@test "ledger: the issue route reads from the ledger after the logs are gone" {  # issue 経路も台帳から同じ値
  REPO_A="$BATS_TEST_TMPDIR/repo-a"
  cl_init_repo "$REPO_A" acme/repo-a
  {
    cl_row S9 i1 2026-09-01T00:00:01.000Z feat/y "$REPO_A" 1000000 "gh issue view 7"
    cl_row S9 i2 2026-09-01T00:00:02.000Z feat/y "$REPO_A" 2000000 "gh issue comment 7 --body x"
  } | cl_write_log issue
  run python3 "$CL" issue 7 --repo "$REPO_A"
  local before="${lines[0]}"
  [[ "$before" == *'$3.00'* ]] || { echo "$output"; return 1; }
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  rm -rf "$CONFIG_DIR/projects/issue"
  run python3 "$CL" issue 7 --repo "$REPO_A"
  [ "${lines[0]}" = "$before" ] || { echo "$output"; return 1; }
}
