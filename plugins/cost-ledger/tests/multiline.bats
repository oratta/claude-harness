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
import json, os, sys
rid, uuid, ts, tokens, kind = sys.argv[1:6]
text = sys.argv[6] if len(sys.argv) > 6 else ""
full = 1 if os.environ.get("ML_FULL") else 0  # 1 なら 5 種のトークンをすべて非ゼロにする
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
                "usage": {"input_tokens": int(tokens), "output_tokens": 7 * full,
                          "cache_read_input_tokens": 11 * full,
                          "cache_creation": {"ephemeral_5m_input_tokens": 13 * full,
                                             "ephemeral_1h_input_tokens": 17 * full}}}},
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

# ---- 同時刻の後続行の並び（元ログの行頭バイト位置 source_offset）----

# 同じ requestId r1・同じ timestamp の後続行 3 つ。実行順は u2(issue 41) → uz(投稿) → ua(issue 42)。
# uuid 順（ua < u2 < uz）と実行順が逆になる。
ord_head() { ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 none; }
ord_tail_post() {
  ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 bash "gh issue view 41"
  ml_row r1 uz 2026-09-01T00:00:02.000Z 1000000 bash "gh pr comment 300 --body x"
}
ord_tail_next() { ml_row r1 ua 2026-09-01T00:00:02.000Z 1000000 bash "gh issue view 42"; }
write_ordered() { { ord_head; ord_tail_post; ord_tail_next; } | cl_write_log "$1"; }

# 区間を「帰属先 issue:閉じた印の有無」の列と、メッセージ数・総額で表す
iv_summary() {
  python3 "$CL" intervals --branch feat/x --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(" ".join("%s:%s" % (i["issue"], "closed" if i["closed_by"] else "open") for i in d["intervals"]),
      d["messages"], "%.2f" % d["total_usd"])'
}
ORD_EXPECT="41:closed 42:open 1 1.00"

@test "order: same-timestamp later lines split at the post line in log order (direct read)" {
  write_ordered a
  run iv_summary
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "$ORD_EXPECT" ] || { echo "$output"; return 1; }
  # 通常の事実が先頭で、補足は元ログの位置順
  run bash -c "python3 '$CL' facts | python3 -c '
import json, sys
rows = [json.loads(l) for l in sys.stdin]
assert [r[\"request_id\"] for r in rows] == [\"r1\", \"r1#u2\", \"r1#uz\", \"r1#ua\"], rows
offs = [r[\"source_offset\"] for r in rows[1:]]
assert offs == sorted(offs) and len(set(offs)) == 3, offs
assert \"source_offset\" not in rows[0]
'"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "order: one sync, the ledger rows, and the direct read give the same intervals" {
  write_ordered a
  run iv_summary
  local direct="$output"
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  run iv_summary
  [ "$output" = "$direct" ] || { echo "$output"; return 1; }
  [ "$output" = "$ORD_EXPECT" ]
  # 台帳の補足の行に位置が保存されている
  [ "$(grep -c '"source_offset": [0-9]' "$LEDGER")" = "3" ]
}

@test "order: sync split right after the post line gives the same intervals" {
  { ord_head; ord_tail_post; } | cl_write_log a
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  ord_tail_next >> "$CONFIG_DIR/projects/a/a.jsonl"
  python3 "$CL" ledger-sync --quiet
  run iv_summary
  [ "$output" = "$ORD_EXPECT" ] || { echo "$output"; return 1; }
  # 分割しない 1 回の同期と、台帳の行が同じ（位置も同じ）
  local split="$BATS_TEST_TMPDIR/split.jsonl"
  cp "$LEDGER" "$split"
  rm -f "$LEDGER" "$LEDGER".state.sqlite*
  python3 "$CL" ledger-sync --quiet
  cmp "$LEDGER" "$split"
}

@test "order: --rescan on a ledger of old head rows gives the same intervals and keeps old bytes" {
  write_ordered a
  legacy_ledger
  cp "$LEDGER" "$BATS_TEST_TMPDIR/before.jsonl"
  local size; size=$(wc -c < "$LEDGER" | tr -d ' ')
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --rescan --quiet
  head -c "$size" "$LEDGER" | cmp - "$BATS_TEST_TMPDIR/before.jsonl"
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "4" ]
  run iv_summary
  [ "$output" = "$ORD_EXPECT" ] || { echo "$output"; return 1; }
  # 再実行・控えを消した再走査は追記しない
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "4" ]
  rm -f "$LEDGER".state.sqlite*
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "4" ]
}

@test "order: reversing the input order of facts gives the same intervals" {
  write_ordered a
  run python3 -B - "$CL" <<'PY'
import importlib.util, json, subprocess, sys
spec = importlib.util.spec_from_file_location("cl", sys.argv[1])
cl = importlib.util.module_from_spec(spec); spec.loader.exec_module(cl)
facts = [json.loads(l) for l in subprocess.check_output(["python3", "-B", sys.argv[1], "facts"], text=True).splitlines()]
want = [(i["issue"], i["request_ids"]) for i in cl.split_intervals(facts)]
got = [(i["issue"], i["request_ids"]) for i in cl.split_intervals(list(reversed(facts)))]
assert got == want, (got, want)
assert want == [("41", ["r1", "r1#u2", "r1#uz"]), ("42", ["r1#ua"])], want
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "order: positions stay byte offsets with non-ASCII text, skipped lines, CRLF and a half-written last line" {
  local f="$CONFIG_DIR/projects/a/a.jsonl"
  mkdir -p "$(dirname "$f")"
  {
    ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 bash "echo 日本語のコマンド"
    printf 'not json at all \xff\xfe\n'
    printf '{"type": "user", "message": "あいう"}\n'
    ml_row r1 u2 2026-09-01T00:00:02.000Z 1000000 bash "gh issue view 41"
    ml_row r1 uz 2026-09-01T00:00:02.000Z 1000000 bash "gh pr comment 300 --body 本文" | sed 's/$/\r/'
  } > "$f"
  # 書きかけの最後の行（改行なし）
  ml_row r1 ua 2026-09-01T00:00:02.000Z 1000000 bash "gh issue view 42" | tr -d '\n' >> "$f"
  local check='
import json, sys
path = sys.argv[1]
data = open(path, "rb").read()
want = {}
pos = 0
for raw in data.split(b"\n"):
    for u in (b"u2", b"uz", b"ua"):
        if (b"\"uuid\": \"" + u + b"\"") in raw:
            want["r1#" + u.decode()] = pos
    pos += len(raw) + 1
got = {}
for l in sys.stdin:
    d = json.loads(l)
    if d.get("continuation"):
        got[d["request_id"]] = d["source_offset"]
for k, v in got.items():
    assert want[k] == v, (k, v, want)
print(sorted(got))'
  run bash -c "python3 '$CL' facts | python3 -c '$check' '$f'"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == "['r1#u2', 'r1#ua', 'r1#uz']" ]] || { echo "$output"; return 1; }
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  # 書きかけの行は次回に回る
  [ "$(grep -c 'r1#ua' "$LEDGER")" = "0" ]
  # 書きかけだった行が完成してから 2 回目の同期（増分同期でも位置が元ログのまま）
  printf '\n' >> "$f"
  python3 "$CL" ledger-sync --quiet
  run bash -c "cat '$LEDGER' | python3 -c '$check' '$f'"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" == "['r1#u2', 'r1#ua', 'r1#uz']" ]] || { echo "$output"; return 1; }
}

@test "order: supplements without source_offset fall back to request_id order for that group" {
  write_ordered a
  run python3 -B - "$CL" <<'PY'
import importlib.util, json, subprocess, sys
spec = importlib.util.spec_from_file_location("cl", sys.argv[1])
cl = importlib.util.module_from_spec(spec); spec.loader.exec_module(cl)
facts = [json.loads(l) for l in subprocess.check_output(["python3", "-B", sys.argv[1], "facts"], text=True).splitlines()]
legacy = [dict(f) for f in facts]
for f in legacy:
    f.pop("source_offset", None)
def ids(fs):
    return [r for i in cl.split_intervals(fs) for r in i["request_ids"]]
# 順序欄の無い補足だけ: 通常の事実が先、補足は request_id 順
assert ids(legacy) == ["r1", "r1#u2", "r1#ua", "r1#uz"], ids(legacy)
# 1 つでも順序欄が無ければ、そのグループ全体が request_id 順に戻る
mixed = [dict(f) for f in facts]
mixed[-1].pop("source_offset")
assert ids(mixed) == ["r1", "r1#u2", "r1#ua", "r1#uz"], ids(mixed)
# 別の同時刻グループ（別の requestId）には影響しない
other = dict(facts[1]); other["request_id"] = "r2#q1"; other["timestamp"] = "2026-09-01T00:00:09.000Z"
other.pop("source_offset")
assert ids(facts + [other])[:4] == ["r1", "r1#u2", "r1#uz", "r1#ua"], ids(facts + [other])
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# ---- F2: キャッシュを含むトークン 5 種のゼロ化 ----

@test "multiline: a supplement zeroes all five token kinds and the cost stays one response's worth" {
  export ML_FULL=1
  write_split a "gh issue view 42"
  run python3 "$CL" facts
  echo "$output" | python3 -c '
import json, sys
rows = [json.loads(l) for l in sys.stdin]
keys = ["input_tokens", "output_tokens", "cache_write_5m_tokens", "cache_write_1h_tokens", "cache_read_tokens"]
head = [r for r in rows if not r.get("continuation")]
sup = [r for r in rows if r.get("continuation")]
assert len(head) == 1 and len(sup) == 1, rows
assert all(head[0][k] > 0 for k in keys), head[0]
assert all(sup[0][k] == 0 for k in keys), sup[0]
'
  run python3 "$CL" branch feat/x
  [ "$status" -eq 0 ]
  local split_out="$output"
  # 先頭の行だけのログと同じ金額・メッセージ数
  ml_row r1 u1 2026-09-01T00:00:01.000Z 1000000 none | cl_write_log a
  run python3 "$CL" branch feat/x
  [ "$output" = "$split_out" ] || { echo "$split_out"; echo "$output"; return 1; }
}

# ---- F3: 通常の同期は既読のログを開き直さない ----

@test "ledger: plain ledger-sync does not reopen a log that was rewritten in place at the same length" {
  write_split a "gh issue view 42"
  export COST_LEDGER_PATH="$LEDGER"
  python3 "$CL" ledger-sync --quiet
  local n; n=$(wc -l < "$LEDGER" | tr -d ' ')
  local f="$CONFIG_DIR/projects/a/a.jsonl"
  local ino; ino=$(ls -i "$f" | cut -d' ' -f1)
  # 同じ inode・同じバイト長のまま、requestId だけ別の値に書き換える（読み直せば新しい事実が出る）
  python3 - "$f" <<'PY'
import sys
data = open(sys.argv[1], "rb").read()
new = data.replace(b'"requestId": "r1"', b'"requestId": "r9"')
assert new != data and len(new) == len(data)
with open(sys.argv[1], "r+b") as fh:
    fh.write(new)
PY
  [ "$(ls -i "$f" | cut -d' ' -f1)" = "$ino" ]
  python3 "$CL" ledger-sync --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" = "$n" ]
  # 対照: --rescan なら読み直して新しい事実が出る（書き換えが検出できる状態だったことの確認）
  python3 "$CL" ledger-sync --rescan --quiet
  [ "$(wc -l < "$LEDGER" | tr -d ' ')" -gt "$n" ]
}
