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
# 実ログと同じ空白なしの JSON で書く（確定行を生の文字列 "stop_reason":" で見分ける分岐を通すため）。
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
                  "gitBranch": "feat/x", "message": msg}, ensure_ascii=False, separators=(",", ":")))
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
  # モデル別の内訳の行も確定値（合計の額と内訳が合う）
  [[ "$output" == *'out=1,000,000'* ]] || { echo "$output"; return 1; }
}

# メイン側の応答 m1（3 行とも出力 400）とサブエージェント側の応答 s1（出力 8 → 251）。
# 出力の合計は 400 + 251 = 651。確定行の値をそのまま足すと 400 × 3 + 8 + 251 = 1,459 になる。
write_main_and_sub() {
  {
    fo_row m1 a1 2026-09-01T00:00:01.000Z 400 tool_use
    fo_row m1 a2 2026-09-01T00:00:02.000Z 400 tool_use
    fo_row m1 a3 2026-09-01T00:00:03.000Z 400 end_turn
    fo_row s1 b1 2026-09-01T00:00:04.000Z 8 none
    fo_row s1 b2 2026-09-01T00:00:05.000Z 251 tool_use
  } | cl_write_log a
}

@test "finaloutput: without a ledger, the closing PR part of issue counts the output once (651)" {
  write_main_and_sub
  cl_init_repo "$BATS_TEST_TMPDIR/ra" acme/ra
  run env -u COST_LEDGER_PATH python3 "$CL" issue 12 --repo "$BATS_TEST_TMPDIR/ra" --closing-pr 300:feat/x --json
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  # 先頭の行 2 つの入力・キャッシュ分（1 つ $0.0002195）+ 出力 651 × $5/MTok = $0.003694
  python3 -c '
import json, sys
d = json.loads(sys.argv[1])
usd = d["closing_prs"][0]["usd"]
out = round((usd - 2 * (100 * 1.0 + 20 * 0.1 + 30 * 1.25 + 40 * 2.0) / 1e6) / 5e-6)
assert out == 651, (out, d)
' "$output"
}

@test "finaloutput: without a ledger, the re-read for the price drift check counts the output once (651)" {
  write_main_and_sub
  run env -u COST_LEDGER_PATH python3 - "$PLUGIN_DIR/scripts" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import cost_ledger
facts = cost_ledger.session_facts(["S1"], 0, 60.0)
print(sum(f["output_tokens"] for f in facts))
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "651" ] || { echo "$output"; return 1; }
}

@test "finaloutput: ledger-sync writes the supplement and matches the direct read" {
  write_two a
  env -u COST_LEDGER_PATH python3 "$CL" facts > "$BATS_TEST_TMPDIR/direct.txt"
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/direct.txt"
  [ "$(grep -c '"output_tokens": 243' "$LEDGER")" = "1" ]
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
  # 台帳に先頭の行（出力 8）だけがある状態で、counted の表を持たない古い形の控えにする
  fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  python3 - "$LEDGER.state.sqlite" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1]); db.execute("DROP TABLE IF EXISTS counted"); db.commit()
PY
  # 確定行を --rescan なしで取り込む。控えを台帳から作り直していなければ差分が 251 になる
  write_two a
  python3 "$CL" ledger-sync --quiet
  python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["output_tokens"] for r in rows] == [8, 243], rows
PY
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

# 先頭 8、確定行が 2 つ（100 → 251）の応答。差分は 100 - 8 = 92 と 251 - 100 = 151
write_two_finals() {
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 100 tool_use
    fo_row r1 u3 2026-09-01T00:00:03.000Z 251 end_turn
  } | cl_write_log a
}

@test "finaloutput: two final lines in one response, read directly, give [8,92,151]" {
  write_two_finals
  assert_py '
assert [r["output_tokens"] for r in rows]==[8,92,151], rows
assert sum(r["output_tokens"] for r in rows)==251'
}

@test "finaloutput: two final lines in one response within a single ledger-sync give [8,92,151]" {
  write_two_finals
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["output_tokens"] for r in rows] == [8, 92, 151], rows
assert sum(r["output_tokens"] for r in rows) == 251
PY
}

@test "finaloutput: two final lines arriving in a later ledger-sync give a total of 251" {
  fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  write_two_finals
  python3 "$CL" ledger-sync --quiet
  python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["output_tokens"] for r in rows] == [8, 92, 151], rows
assert sum(r["output_tokens"] for r in rows) == 251
PY
}

@test "finaloutput: final lines arriving in two separate ledger-syncs add up to [8,92,151]" {
  # 控えの足し込み（cost_ledger.py の out = out + excluded.out）を検査する。u2=100、u3=251 を別々の同期で足す。
  # 足し込みが上書き（out = excluded.out）に壊れると、3 回目の差分が [8,92,151] でなく [8,92,159] になる
  fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 100 tool_use
  } | cl_write_log a
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  write_two_finals
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["output_tokens"] for r in rows] == [8, 92, 151], rows
PY
}

@test "finaloutput: a null or missing stop_reason on a larger line with Bash is not a final line" {
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 251 none "echo hi"
    fo_row r1 u3 2026-09-01T00:00:03.000Z 252 none "echo hi" | sed 's/"stop_reason":null,//'
  } | cl_write_log a
  # sed が当たらなければ u3 も "stop_reason" を持ち 3 になる。2 なら u3 だけ消えている
  [ "$(grep -c '"stop_reason"' "$CONFIG_DIR/projects/a/a.jsonl")" = "2" ] || return 1
  [ "$(wc -l < "$CONFIG_DIR/projects/a/a.jsonl" | tr -d ' ')" = "3" ] || return 1
  assert_py '
assert sum(r["output_tokens"] for r in rows)==8, rows'
}

@test "finaloutput: a numeric stop_reason on a larger line with Bash is not a final line" {
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 251 none "echo hi" | sed 's/"stop_reason":null/"stop_reason":7/'
  } | cl_write_log a
  grep -q '"stop_reason":7' "$CONFIG_DIR/projects/a/a.jsonl"
  assert_py '
assert sum(r["output_tokens"] for r in rows)==8, rows'
}

@test "finaloutput: --rescan adds the difference to a legacy ledger row that has no uuid field" {
  write_two a
  legacy_ledger
  python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
for r in rows:
    r.pop("uuid", None)
open(sys.argv[1], "w").write("".join(json.dumps(r) + "\n" for r in rows))
PY
  ! grep -q '"uuid"' "$LEDGER" || return 1
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --rescan --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["output_tokens"] for r in rows] == [8, 243], rows
PY
}

@test "finaloutput: replacing the ledger with a shorter one and --rescan rebuilds the counted output" {
  write_two a
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  # 台帳を先頭の行だけの短いものに差し替える（控えの covered より小さい）。
  # 数えた出力 251 が残っていると差分が 0 になり、追記されない
  head -n 1 "$LEDGER" > "$BATS_TEST_TMPDIR/short.jsonl"
  /bin/cp -f "$BATS_TEST_TMPDIR/short.jsonl" "$LEDGER"
  run python3 "$CL" ledger-sync --rescan --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["output_tokens"] for r in rows] == [8, 243], rows
PY
}

@test "finaloutput: a plain ledger-sync does not reopen a log it has already read to the end" {
  write_two a
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  # 控えだけを「差分をまだ数えていない」状態に戻す（台帳は触らない）。
  # 読み終えたログを開き直せば、差分の行が台帳に追記される
  python3 - "$LEDGER.state.sqlite" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("DELETE FROM ids WHERE id = 'r1#u2'")
db.execute("UPDATE counted SET out = 8 WHERE id = 'r1'")
db.commit()
PY
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before.jsonl"
  python3 "$CL" ledger-sync --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/before.jsonl"
}

@test "finaloutput: a state file rebuilt from a ledger holding supplements adds a later final line once (49)" {
  write_two a
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  rm -f "$LEDGER.state.sqlite"*
  {
    fo_row r1 u1 2026-09-01T00:00:01.000Z 8 none
    fo_row r1 u2 2026-09-01T00:00:02.000Z 251 tool_use
    fo_row r1 u3 2026-09-01T00:00:03.000Z 300 end_turn
  } | cl_write_log a
  python3 "$CL" ledger-sync --quiet
  python3 - "$LEDGER" <<'PY'
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r["output_tokens"] for r in rows] == [8, 243, 49], rows
PY
}
