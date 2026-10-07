#!/usr/bin/env bats
#
# spec: cost-ledger-attribution（同じ応答の 2 行目以降の issue と投稿の印）
#       cost-ledger-persistence（補足の事実の台帳への追記と --rescan）
#
# 1 回の応答が会話ログで複数行に分かれ、2 行目以降にだけ gh issue と投稿の印がある場合を固定する。
# 会話ログ・台帳はすべて $BATS_TEST_TMPDIR に置く。

load helper

setup() {
  export LC_ALL=C.UTF-8
  cl_setup
  LEDGER="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
  HOOK="$PLUGIN_DIR/scripts/ledger-hook.sh"
}

# 1 行ぶんの assistant レコード。モデルは haiku、input_tokens=1000000 で $1.00。
# $1=requestId $2=uuid $3=timestamp $4=input_tokens $5=種別(none|bash|edit) $6=command か本文
ml_row() {
  python3 - "$@" <<'PY'
import json, sys
rid, uuid, ts, tokens, kind = sys.argv[1:6]
text = sys.argv[6] if len(sys.argv) > 6 else ""
content = [{"type": "text", "text": "x"}]
if kind == "bash":
    content = [{"type": "tool_use", "id": "t-" + uuid, "name": "Bash", "input": {"command": text}}]
elif kind == "edit":
    content = [{"type": "tool_use", "id": "t-" + uuid, "name": "Edit",
                "input": {"new_string": text}}]
print(json.dumps({
    "type": "assistant", "requestId": rid, "uuid": uuid, "timestamp": ts,
    "sessionId": "S1", "isSidechain": False, "cwd": "/nonexistent/x", "gitBranch": "feat/x",
    "message": {"id": "m-" + rid, "model": "claude-haiku-4-5", "role": "assistant",
                "content": content,
                "usage": {"input_tokens": int(tokens), "output_tokens": 0,
                          "cache_read_input_tokens": 0,
                          "cache_creation": {"ephemeral_5m_input_tokens": 0,
                                             "ephemeral_1h_input_tokens": 0}}}},
    ensure_ascii=False))
PY
}

# 応答 r1 が 3 行（1 行目: 本文、2 行目: $1 の Bash、3 行目: 本文）に分かれたログ
write_split() {  # $1=ログの名前 $2=2 行目の command
  {
    ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 none
    ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 bash "$2"
    ml_row r1 u3 2026-09-01T00:00:03.000Z 1000000 none
  } | cl_write_log "$1"
}

facts_json() {  # 事実を JSON 配列で標準出力へ
  python3 "$CL" facts | python3 -c 'import json,sys; print(json.dumps([json.loads(l) for l in sys.stdin]))'
}

@test "multiline: gh issue view only on the second line of a response lands in issues" {  # 2 行目にだけある issue 番号
  write_split a "gh issue view 42"
  run python3 -c '
import json, subprocess, sys
rows = [json.loads(l) for l in subprocess.check_output(["python3", sys.argv[1], "facts"], text=True).splitlines()]
sup = [r for r in rows if r["issues"] == ["42"]]
assert len(sup) == 1, rows
assert sup[0]["continuation"] is True and sup[0]["request_id"] == "r1#u2", sup
assert sup[0]["input_tokens"] == 0 and sup[0]["output_tokens"] == 0, sup
print("ok")' "$CL"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *ok* ]]
}

@test "multiline: tokens and cost stay at one response's worth" {  # 金額が行数ぶん重複しない
  write_split a "gh issue view 42"
  run python3 "$CL" branch feat/x
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == *'$1.00'* ]] || { echo "$output"; return 1; }
  [[ "$output" == *"1 メッセージ"* ]] || { echo "$output"; return 1; }
}

@test "multiline: a post marker only on the second line closes the interval there" {  # 2 行目にだけある投稿の印
  {
    ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 none
    ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 bash "gh pr comment 300 --body x"
    ml_row r2 v1 2026-09-01T00:00:03.000Z 1000000 none
  } | cl_write_log a
  run python3 "$CL" intervals --branch feat/x --json
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" | python3 -c '
import json, sys
d = json.load(sys.stdin)
iv = d["intervals"]
assert len(iv) == 2, iv
assert iv[0]["closed_by"] and iv[0]["messages"] == 1, iv[0]
assert iv[1]["closed_by"] is None and iv[1]["messages"] == 1, iv[1]
assert d["messages"] == 2, d["messages"]
assert abs(d["total_usd"] - 2.0) < 1e-9, d["total_usd"]
'
}

@test "multiline: gh issue view written in an Edit body is not attributed" {  # 実行していない文字列は拾わない
  {
    ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 none
    ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 edit "gh issue view 999"
  } | cl_write_log a
  run bash -c "python3 '$CL' facts | grep -c '999' || true"
  [ "$output" = "0" ] || { echo "$output"; return 1; }
  run bash -c "python3 '$CL' facts | wc -l | tr -d ' '"
  [ "$output" = "1" ]
}

@test "multiline: a copied head line does not become a supplement" {  # 複製されたログの先頭の行
  {
    ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 bash "gh pr comment 300 --body x"
    ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 none
  } | cl_write_log a
  {
    ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 bash "gh pr comment 300 --body x"
    ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 none
  } | cl_write_log b
  run bash -c "python3 '$CL' facts | wc -l | tr -d ' '"
  [ "$output" = "1" ] || { echo "$output"; return 1; }
  run python3 "$CL" intervals --branch feat/x --json
  echo "$output" | python3 -c '
import json, sys
iv = json.load(sys.stdin)["intervals"]
assert len(iv) == 1 and iv[0]["closed_by"], iv
'
}

@test "multiline: a copied later line yields one supplement" {  # 複製された後続行は 1 つだけ
  write_split a "gh issue view 42"
  write_split b "gh issue view 42"
  run bash -c "python3 '$CL' facts | grep -c '\"continuation\": true'"
  [ "$output" = "1" ] || { echo "$output"; return 1; }
}

@test "multiline: later lines with the same timestamp but different uuids both stay" {  # 同じ時刻の別の後続行
  {
    ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 none
    ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 bash "gh issue view 42"
    ml_row r1 u3 2026-09-01T00:00:02.000Z 1000000 bash "gh issue view 43"
  } | cl_write_log a
  run bash -c "python3 '$CL' facts | grep -c '\"continuation\": true'"
  [ "$output" = "2" ] || { echo "$output"; return 1; }
}

@test "multiline: a head read in one sync is not a supplement in the next sync" {  # 同期が分かれても先頭の行は後続行にならない
  export COST_LEDGER_PATH="$LEDGER"
  ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 bash "gh pr comment 300 --body x" | cl_write_log a
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "1" ]
  ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 bash "gh issue view 42" >> "$CONFIG_DIR/projects/a/a.jsonl"
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  run bash -c "grep -c '\"continuation\": true' '$LEDGER'"
  [ "$output" = "1" ]
  run bash -c "tail -n 1 '$LEDGER' | grep -c '\"request_id\": \"r1#u2\"'"
  [ "$output" = "1" ]
}

@test "ledger: supplements are written and equal the direct read" {  # 台帳の行は直読みと同じ
  write_split a "gh issue view 42"
  python3 "$CL" facts > "$BATS_TEST_TMPDIR/direct.txt"
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  cmp "$LEDGER" "$BATS_TEST_TMPDIR/direct.txt"
}

# 補足を足す前の形の台帳（先頭の行だけ。uuid 欄なし）を作る
legacy_ledger() {
  mkdir -p "$(dirname "$LEDGER")"
  # facts は COST_LEDGER_PATH があると台帳へ追記するので、台帳を作る間は外す
  env -u COST_LEDGER_PATH python3 "$CL" facts | head -n 1 | python3 -c '
import json, sys
for l in sys.stdin:
    d = json.loads(l); d.pop("uuid", None)
    print(json.dumps(d, ensure_ascii=False))' > "$LEDGER"
}

@test "ledger: --rescan appends only supplements and leaves old rows byte-identical" {  # 既存の行は変わらない
  write_split a "gh issue view 42"
  legacy_ledger
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before.jsonl"
  local size; size=$(wc -c < "$LEDGER" | tr -d ' ')
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --rescan --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(head -c "$size" "$LEDGER" | cmp - "$BATS_TEST_TMPDIR/before.jsonl"; echo $?)" = "0" ]
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "2" ]
  run bash -c "tail -n 1 '$LEDGER' | grep -c '\"request_id\": \"r1#u2\"'"
  [ "$output" = "1" ]
}

@test "ledger: --rescan twice appends nothing the second time, even without the state file" {  # 2 回目は 0 行
  write_split a "gh issue view 42"
  legacy_ledger
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --rescan --quiet
  local n; n=$(wc -l < "$LEDGER" | tr -d ' ')
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "$n" ]
  rm -f "$LEDGER.state.sqlite"*
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "$n" ]
}

@test "ledger: --rescan does not turn a copied head line into a supplement" {  # 複製の先頭行は補足にならない
  {
    ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 bash "gh pr comment 300 --body x"
    ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 none
  } | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  {
    ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 bash "gh pr comment 300 --body x"
    ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 none
  } | cl_write_log b
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "1" ]
  # 旧形式の台帳でも同じ（旧形式の台帳に今の控えは付いていない）
  legacy_ledger
  rm -f "$LEDGER".state.sqlite*
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "1" ]
}

@test "ledger: plain ledger-sync does not reread logs that are already read" {  # --rescan なしは読み直さない
  write_split a "gh issue view 42"
  legacy_ledger
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet   # 控えを作る（古い行の取りこぼしは直さない）
  local n; n=$(wc -l < "$LEDGER" | tr -d ' ')
  python3 "$CL" ledger-sync --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "$n" ]
}

@test "ledger: --rescan after the logs are gone appends nothing and exits 0" {  # 消えた分は補えない
  write_split a "gh issue view 42"
  legacy_ledger
  rm -rf "$CONFIG_DIR/projects/a"
  export COST_LEDGER_PATH="$LEDGER"
  run python3 "$CL" ledger-sync --rescan --quiet
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "1" ]
}

@test "ledger: concurrent hooks keep one row per requestId and one per supplement key" {  # 同時に動く（改定版）
  local i
  {
    for i in $(seq 1 100); do
      ml_row "q$i" "a$i" 2026-09-01T00:00:01.000Z 1000000 none
    done
    for i in $(seq 1 100); do
      ml_row "p$i" "b$i" 2026-09-01T00:00:02.000Z 1000000 none
      ml_row "p$i" "c$i" 2026-09-01T00:00:03.000Z 1000000 bash "gh issue view $i"
    done
  } | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  sh "$HOOK" </dev/null &
  local p1=$!
  sh "$HOOK" </dev/null &
  local p2=$!
  sh "$HOOK" </dev/null
  wait "$p1" "$p2"
  [ "$(grep -vc '"continuation": true' "$LEDGER")" -eq 200 ] || return 1
  [ "$(grep -c '"continuation": true' "$LEDGER")" -eq 100 ] || return 1
  [ "$(cut -c1-40 "$LEDGER" | sort | uniq -d | wc -l | tr -d ' ')" -eq 0 ] || return 1
}
