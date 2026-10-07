#!/usr/bin/env bats
#
# spec: cost-ledger-attribution（行から抽出する事実の出力トークン・出力トークンの差分）
#       cost-ledger-persistence（出力の差分の台帳への追記と --rescan・控えの作り直し）
#
# 応答の途中の行は暫定の output_tokens を持ち、stop_reason が付く確定行だけが確定値を持つ。
# 確定値との差分を補足の事実に載せ、応答単位の合計が確定値になることを固定する。
# 会話ログ・台帳はすべて $BATS_TEST_TMPDIR に置く。

load helper

setup() {
  export LC_ALL=C.UTF-8
  cl_setup
  LEDGER="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
  HOOK="$PLUGIN_DIR/scripts/ledger-hook.sh"
}

# 1 行ぶんの assistant レコード。モデルは haiku（出力 $5/MTok）。
# $1=requestId $2=uuid $3=timestamp $4=output_tokens $5=stop_reason（無しなら none）$6=Bash の command（省略可）
fo_row() {
  python3 - "$@" <<'PY'
import json, sys
rid, uuid, ts, out, stop = sys.argv[1:6]
cmd = sys.argv[6] if len(sys.argv) > 6 else ""
content = [{"type": "text", "text": "x"}]
if cmd:
    content = [{"type": "tool_use", "id": "t-" + uuid, "name": "Bash", "input": {"command": cmd}}]
msg = {"id": "m-" + rid, "model": "claude-haiku-4-5", "role": "assistant", "content": content,
       "stop_reason": None if stop == "none" else stop,
       "usage": {"input_tokens": 100, "output_tokens": int(out), "cache_read_input_tokens": 20,
                 "cache_creation": {"ephemeral_5m_input_tokens": 30, "ephemeral_1h_input_tokens": 40}}}
print(json.dumps({"type": "assistant", "requestId": rid, "uuid": uuid, "timestamp": ts,
                  "sessionId": "S1", "isSidechain": True, "cwd": "/nonexistent/x",
                  "gitBranch": "feat/x", "message": msg}, ensure_ascii=False))
PY
}

# 先頭の行（途中の出力 8）と確定行（出力 251）の 2 行の応答 r1
write_two() {  # $1=ログの名前 $2=確定行の command（省略可）
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 251 tool_use "${2:-}"
  } | cl_write_log "$1"
}

facts_json() {
  env -u COST_LEDGER_PATH python3 "$CL" facts | python3 -c 'import json,sys; print(json.dumps([json.loads(l) for l in sys.stdin]))'
}

assert_py() {  # $1=python の検査（rows = 事実の配列）
  facts_json | python3 -c "import json,sys; rows=json.load(sys.stdin); $1"
}

@test "finaloutput: a final line adds the difference as a supplement and the total is the final value" {
  write_two a
  assert_py '
sup=[r for r in rows if r.get("continuation")]; head=[r for r in rows if not r.get("continuation")]
assert len(head)==1 and head[0]["output_tokens"]==8, rows
assert len(sup)==1 and sup[0]["output_tokens"]==243 and sup[0]["request_id"]=="r1#u2", rows
assert sup[0]["input_tokens"]==0 and sup[0]["cache_read_tokens"]==0 and sup[0]["cache_write_5m_tokens"]==0 and sup[0]["cache_write_1h_tokens"]==0, sup
assert sum(r["output_tokens"] for r in rows)==251'
}

@test "finaloutput: the final line also carrying gh issue view lands in one supplement" {
  write_two a "gh issue view 42"
  assert_py '
sup=[r for r in rows if r.get("continuation")]
assert len(sup)==1 and sup[0]["issues"]==["42"] and sup[0]["output_tokens"]==243, rows'
}

@test "finaloutput: a response with no stop_reason keeps the first value" {
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 7 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 7 none
  } | cl_write_log a
  assert_py '
assert len(rows)==1 and rows[0]["output_tokens"]==7, rows'
}

@test "finaloutput: a response final from the first line adds nothing" {
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 400 tool_use
    fo_row r1 u2 2026-09-01T00:00:02.000Z 400 tool_use
    fo_row r1 u3 2026-09-01T00:00:03.000Z 400 end_turn
  } | cl_write_log a
  assert_py '
assert len(rows)==1 and rows[0]["output_tokens"]==400, rows'
}

@test "finaloutput: stop_reason that is not a non-empty string is not a final line" {
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 251 ""
  } | cl_write_log a
  assert_py '
assert sum(r["output_tokens"] for r in rows)==8, rows'
}

@test "finaloutput: reading the same final line twice or from a copy adds the difference once" {
  write_two a
  cp -R "$CONFIG_DIR/projects/a" "$CONFIG_DIR/projects/b"
  assert_py '
assert sum(r["output_tokens"] for r in rows)==251 and len(rows)==2, rows'
}

@test "finaloutput: a smaller final line than what is counted adds nothing" {
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 300 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 251 tool_use
  } | cl_write_log a
  assert_py '
assert len(rows)==1 and rows[0]["output_tokens"]==300, rows'
}

@test "finaloutput: the supplement does not count as a message, and cost uses the final value" {
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 100000 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 1000000 tool_use
  } | cl_write_log a
  run python3 "$CL" branch feat/x
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  # 入力 100 ×$1 + 出力 1,000,000 ×$5 + キャッシュ分 = 約 $5.00
  [[ "$output" == *'$5.0'* ]] || { echo "$output"; return 1; }
  [[ "$output" == *"1 メッセージ"* ]] || { echo "$output"; return 1; }
}

@test "finaloutput: ledger-sync writes the supplement and matches the direct read" {
  write_two a
  env -u COST_LEDGER_PATH python3 "$CL" facts > "$BATS_TEST_TMPDIR/direct.txt"
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/direct.txt"
}

@test "finaloutput: sync split between the head line and the final line gives a total of 251" {
  fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before.jsonl"
  local size; size=$(wc -c < "$LEDGER" | tr -d ' ')
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 251 tool_use
  } | cl_write_log a
  python3 "$CL" ledger-sync --quiet
  [ "$(head -c "$size" "$LEDGER" | cmp - "$BATS_TEST_TMPDIR/before.jsonl"; echo $?)" = "0" ]
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert sum(r["output_tokens"] for r in rows) == 251 and rows[1]["output_tokens"] == 243, rows
PY
}

# 途中の出力のまま書かれた既存の台帳（先頭の行だけ）
legacy_ledger() {
  mkdir -p "$(dirname "$LEDGER")"
  env -u COST_LEDGER_PATH python3 "$CL" facts | head -n 1 > "$LEDGER"
}

@test "finaloutput: --rescan appends the difference, leaves old rows alone, and is idempotent" {
  write_two a
  legacy_ledger
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before.jsonl"
  local size; size=$(wc -c < "$LEDGER" | tr -d ' ')
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --rescan --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(head -c "$size" "$LEDGER" | cmp - "$BATS_TEST_TMPDIR/before.jsonl"; echo $?)" = "0" ]
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  run bash -c "tail -n 1 '$LEDGER' | grep -c '\"output_tokens\": 243'"
  [ "$output" = "1" ]
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  rm -f "$LEDGER.state.sqlite"*
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
}

@test "finaloutput: an old-format state file is rebuilt from the ledger without double counting" {
  write_two a
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  # counted の表を持たない古い形の控えにする（表を落とす）
  python3 - "$LEDGER.state.sqlite" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1]); db.execute("DROP TABLE IF EXISTS counted"); db.commit()
PY
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
}

@test "finaloutput: --rescan after the conversation log is gone appends nothing and exits 0" {
  write_two a
  legacy_ledger
  rm -rf "$CONFIG_DIR/projects/a"
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --rescan --quiet
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "1" ]
}

@test "finaloutput: two hooks at once write each supplement once" {
  write_two a "gh issue view 42"
  export COST_LEDGER_PATH="$LEDGER"
  echo '{}' | "$HOOK" & echo '{}' | "$HOOK" & wait
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  [ "$(grep -c '"request_id": "r1#u2"' "$LEDGER")" = "1" ]
}
