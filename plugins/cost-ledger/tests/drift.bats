#!/usr/bin/env bats
#
# spec: cost-ledger-pricing（本体のコスト値との突き合わせ）/ session-cost-record（読み手の側）
#
# statusline が書き残した Claude Code 本体のセッションコスト
# （<設定ディレクトリ>/.session-cost/<セッション ID>）と、自前の単価表で計算した額を
# 突き合わせて、ずれを警告することを固定する。記録はテストが直接書く。
# モデルは既定で haiku（input_tokens=1000000 が $1.00）なので、期待値を手で置ける。

load helper

B=1790000000   # 記録の時刻の基準（epoch 秒）

setup() {
  cl_setup
  export LC_ALL=C.UTF-8
  unset COST_LEDGER_DRIFT_BUDGET_SECONDS
  REC_DIR="$CONFIG_DIR/.session-cost"
  mkdir -p "$REC_DIR"
}

# 1 レコードぶんの JSON。$3 は基準 B からの秒数（小数可）
dr_row() {  # $1=sessionId $2=requestId $3=秒 $4=branch $5=input_tokens [$6=model] [$7=cwd] [$8=Bashコマンド]
  python3 - "$B" "$@" <<'PY'
import datetime, json, sys
base, sid, rid, offset, branch, tokens = sys.argv[1:7]
model = sys.argv[7] if len(sys.argv) > 7 and sys.argv[7] else "claude-haiku-4-5"
cwd = sys.argv[8] if len(sys.argv) > 8 and sys.argv[8] else "/nonexistent/drift"
command = sys.argv[9] if len(sys.argv) > 9 else ""
moment = datetime.datetime.fromtimestamp(int(base) + float(offset), datetime.timezone.utc)
ts = moment.strftime("%Y-%m-%dT%H:%M:%S.") + "%03dZ" % (moment.microsecond // 1000)
content = []
if command:
    content.append({"type": "tool_use", "id": "t-" + rid, "name": "Bash", "input": {"command": command}})
print(json.dumps({
    "type": "assistant", "requestId": rid, "uuid": "u-" + rid, "timestamp": ts,
    "sessionId": sid, "isSidechain": False, "cwd": cwd, "gitBranch": branch,
    "message": {"id": "msg-" + rid, "model": model, "role": "assistant", "content": content,
                "usage": {"input_tokens": int(tokens), "output_tokens": 0,
                          "cache_read_input_tokens": 0,
                          "cache_creation": {"ephemeral_5m_input_tokens": 0,
                                             "ephemeral_1h_input_tokens": 0}}}},
    ensure_ascii=False))
PY
}

# 記録を書く。時刻は基準 B からの秒数
dr_rec() {  # $1=sessionId $2=t0 の秒 $3=v0 $4=t1 の秒 $5=v1
  printf '1 %s %s %s %s\n' "$((B + $2))" "$3" "$((B + $4))" "$5" > "$REC_DIR/$1"
}

# セッション S1 がブランチ feat に $1（tokens）の行を 1 つ持ち、本体の値の増分が $2 の状態を作る
dr_simple() {  # $1=input_tokens $2=本体の値の増分
  dr_row S1 r1 100 feat "$1" | cl_write_log s1
  dr_rec S1 0 0 200 "$2"
}

drift_lines() { printf '%s\n' "$output" | grep -c '単価表のずれ:' || true; }

@test "drift: a difference above both thresholds warns" {  # 差が両方の閾値を超えると警告が出る
  dr_simple 6000000 10
  run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  line="$(printf '%s\n' "$output" | grep '単価表のずれ:')"
  [[ "$line" == *S1* && "$line" == *'$10.00'* && "$line" == *'$6.00'* ]] || { echo "$line"; return 1; }
  [[ "$line" == *'$0.50'* && "$line" == *'10%'* ]] || { echo "$line"; return 1; }
  [[ "${lines[0]}" == "コスト: "* && "${lines[0]}" != *単価表のずれ* ]] || { echo "$output"; return 1; }
}

@test "drift: a difference within the thresholds does not warn" {  # 差が閾値以内（差額 $0.50・割合 5%）では出ない
  dr_simple 9500000 10
  run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || return 1
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: ratio above but amount below the threshold does not warn" {  # 割合は超えるが差額が小さい
  dr_simple 300000 0.60
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: amount above but ratio below the threshold does not warn" {  # 差額は超えるが割合が小さい
  dr_simple 95000000 100
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: a larger own calculation also warns" {  # 自前の計算の方が大きい
  dr_simple 10000000 6
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
}

@test "drift: several drifted sessions still produce one line" {  # ずれありが複数でも 1 行
  { dr_row S1 r1 100 feat 6000000; } | cl_write_log s1
  { dr_row S2 r2 100 feat 12000000; } | cl_write_log s2
  { dr_row S3 r3 100 feat 3000000; } | cl_write_log s3
  dr_rec S1 0 0 200 10
  dr_rec S2 0 0 200 20
  dr_rec S3 0 0 200 5
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  line="$(printf '%s\n' "$output" | grep '単価表のずれ:')"
  [[ "$line" == *'3 セッションのうち 3 '* ]] || { echo "$line"; return 1; }
  [[ "$line" == *S2* && "$line" == *'$20.00'* && "$line" == *'$12.00'* ]] || { echo "$line"; return 1; }
}

@test "drift: the increment is the last value minus the first value" {  # 本体の値は v1 − v0
  dr_row S1 r1 100 feat 10000000 | cl_write_log s1
  dr_rec S1 0 5 200 15
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: rows on another branch count toward the own calculation" {  # 別ブランチの行も自前の計算に入る
  { dr_row S1 r1 100 feat 1000000; dr_row S1 r2 120 wt 2000000; } | cl_write_log s1
  dr_rec S1 0 0 200 3
  run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || return 1
  [[ "${lines[0]}" == 'コスト: $1.00 '* ]] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: rows of the session in another log file count too" {  # 同じセッションの別ファイルの行（サブエージェント）も入る
  dr_row S1 r1 100 feat 1000000 | cl_write_log s1
  dr_row S1 r2 120 wt 2000000 | cl_write_log s1-sub
  dr_rec S1 0 0 200 3
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: rows outside the interval are not compared" {  # 区間の外の行は比べない
  { dr_row S1 r1 -50 feat 5000000; dr_row S1 r2 100 feat 2000000; } | cl_write_log s1
  dr_rec S1 0 0 200 2
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: the interval is [t0+1, t1+1) in seconds" {  # 区間の端。t0 と同じ秒は外、t1 と同じ秒は内
  { dr_row S1 r1 0.5 feat 3000000; dr_row S1 r2 200.5 feat 2000000; dr_row S1 r3 201 feat 4000000; } | cl_write_log s1
  dr_rec S1 0 0 200 2
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: sessions without a record are not compared" {  # 記録が無いセッションは比べない
  dr_row S1 r1 100 feat 6000000 | cl_write_log s1
  run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || return 1
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: a malformed or single-observation record changes nothing" {  # 壊れた記録・観測が 1 回だけの記録で止まらない
  dr_row S1 r1 100 feat 6000000 | cl_write_log s1
  run python3 "$CL" branch feat
  plain="$output"
  for body in 'garbage' "2 $B 0 $((B + 200)) 10" "1 $B 0 $((B + 200)) 10 extra" "1 $B x $((B + 200)) 10" \
              "1 $B 0 $B 10" ''; do
    printf '%s\n' "$body" > "$REC_DIR/S1"
    run python3 "$CL" branch feat
    [ "$status" -eq 0 ] || { echo "rc=$status body=$body"; return 1; }
    [ "$output" = "$plain" ] || { echo "body=$body"; echo "$output"; return 1; }
  done
  rm -f "$REC_DIR/S1"
  mkdir "$REC_DIR/S1"   # 読めない記録
  run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || return 1
  [ "$output" = "$plain" ] || { echo "$output"; return 1; }
}

@test "drift: reading from the ledger gives the same warning" {  # 台帳から読むときも同じ結果になる
  { dr_row S1 r1 100 feat 6000000; dr_row S1 r2 120 wt 1000000; } | cl_write_log s1
  dr_rec S1 0 0 200 10
  run python3 "$CL" branch feat
  direct="$(printf '%s\n' "$output" | grep '単価表のずれ:')"
  [ -n "$direct" ] || { echo "$output"; return 1; }
  [[ "$direct" == *'$7.00'* ]] || { echo "$direct"; return 1; }
  COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger/ledger.jsonl" run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(printf '%s\n' "$output" | grep '単価表のずれ:')" = "$direct" ] || { echo "$output"; return 1; }
}

@test "drift: a model without a price warns even within the thresholds" {  # 単価の無いモデルの行が区間にある
  { dr_row S1 r1 100 feat 50000; dr_row S1 r2 120 feat 1000 claude-future-9; } | cl_write_log s1
  dr_rec S1 0 0 200 0.20
  run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || return 1
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  line="$(printf '%s\n' "$output" | grep '単価表のずれ:')"
  [[ "$line" == *claude-future-9* && "$line" == *'$0.20'* && "$line" == *'$0.05'* ]] || { echo "$line"; return 1; }
  # 既存の未知モデルの表示は置き換えない
  [[ "$output" == *'未知モデル: claude-future-9 1 行'* ]] || { echo "$output"; return 1; }
}

@test "drift: a drifted session with an unpriced model produces two lines" {  # 閾値超えと単価の無いモデルは別の行
  { dr_row S1 r1 100 feat 6000000; dr_row S1 r2 120 feat 1000 claude-future-9; } | cl_write_log s1
  dr_rec S1 0 0 200 10
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "2" ] || { echo "$output"; return 1; }
}

@test "drift: an unpriced model without tokens does not warn" {  # トークンの無い未知モデルの行だけでは警告しない
  { dr_row S1 r1 100 feat 2000000; dr_row S1 r2 120 feat 0 '<synthetic>'; } | cl_write_log s1
  dr_rec S1 0 0 200 2
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: an unpriced model outside the interval does not warn" {  # 区間の外の未知モデルは対象にしない
  { dr_row S1 r1 100 feat 2000000; dr_row S1 r2 -50 feat 1000 claude-future-9; } | cl_write_log s1
  dr_rec S1 0 0 200 2
  run python3 "$CL" branch feat
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: the first line and the exit code do not change" {  # 警告があっても 1 行目は同じ
  dr_simple 6000000 10
  run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || return 1
  with="${lines[0]}"
  [ "$(drift_lines)" = "1" ] || return 1
  rm -f "$REC_DIR/S1"
  run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || return 1
  [ "${lines[0]}" = "$with" ] || { echo "$output"; return 1; }
}

# 実在のリポジトリのブランチ feat に、ずれありのセッションを作る（cost の経路用）
dr_repo_case() {
  REPO="$BATS_TEST_TMPDIR/repo"
  cl_init_repo "$REPO" "acme/repo"
  git -C "$REPO" checkout -q -b feat
  dr_row S1 r1 100 feat 6000000 '' "$REPO" "${1-}" | cl_write_log s1
  dr_rec S1 0 0 200 10
}

@test "drift: cost --no-drift-check skips the comparison" {  # 突き合わせを省く
  dr_repo_case
  run python3 "$CL" cost --repo "$REPO"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  first="${lines[0]}"
  run python3 "$CL" cost --repo "$REPO" --no-drift-check
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
  [ "${lines[0]}" = "$first" ] || { echo "$output"; return 1; }
}

@test "drift: the comparison never calls gh" {  # 突き合わせは gh を呼ばない
  dr_repo_case
  export DR_GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  cl_fake_gh <<'EOF'
echo "$*" >> "$DR_GH_LOG"
exit 1
EOF
  run python3 "$CL" cost --repo "$REPO"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  [ ! -s "$DR_GH_LOG" ] || { cat "$DR_GH_LOG"; return 1; }
}

@test "drift: the issue path warns and reports price_drift in JSON" {  # issue の経路の警告と JSON の price_drift
  dr_repo_case "gh issue view 148"
  run python3 "$CL" issue 148 --repo "$REPO"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == 'コスト: $6.00 '* ]] || { echo "$output"; return 1; }
  run python3 "$CL" issue 148 --repo "$REPO" --json
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  got="$(printf '%s' "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin)["price_drift"]; print(d["checked"], d["drifted"])')"
  [ "$got" = "1 1" ] || { echo "$output"; return 1; }
  rm -f "$REC_DIR/S1"
  run python3 "$CL" issue 148 --repo "$REPO" --json
  got="$(printf '%s' "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("price_drift" in d, d["price_drift"])')"
  [ "$got" = "True None" ] || { echo "$output"; return 1; }
}

@test "drift: the issue path is never cut off" {  # issue の経路は読み直さないので上限が働かない
  dr_repo_case "gh issue view 148"
  COST_LEDGER_DRIFT_BUDGET_SECONDS=0 run python3 "$CL" issue 148 --repo "$REPO"
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  [[ "$output" != *未確認* ]] || { echo "$output"; return 1; }
}

@test "drift: the issue path from the ledger gives the same warning" {  # 台帳から issue を触ったセッションだけを読んでも、そのセッションの全行で比べる
  REPO="$BATS_TEST_TMPDIR/repo"
  cl_init_repo "$REPO" "acme/repo"
  git -C "$REPO" checkout -q -b feat
  { dr_row S1 r1 100 feat 6000000 '' "$REPO" "gh issue view 148"
    dr_row S1 r2 120 other 1000000 '' "$REPO"; } | cl_write_log s1
  dr_rec S1 0 0 200 10
  run python3 "$CL" issue 148 --repo "$REPO"
  direct="$(printf '%s\n' "$output" | grep '単価表のずれ:')"
  [[ "$direct" == *'$7.00'* ]] || { echo "$output"; return 1; }
  COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger/ledger.jsonl" run python3 "$CL" issue 148 --repo "$REPO"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(printf '%s\n' "$output" | grep '単価表のずれ:')" = "$direct" ] || { echo "$output"; return 1; }
}

@test "drift: timeline does not compare" {  # 行を積む hook が呼ぶ timeline は突き合わせを行わない
  dr_repo_case "gh issue view 148"
  run python3 "$CL" timeline --pr 1 --branch feat --trigger x --at "$((B + 300))" --repo "$REPO" < /dev/null
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == "コスト: "* ]] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
  run python3 "$CL" timeline --issue 148 --trigger x --at "$((B + 300))" --repo "$REPO" < /dev/null
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == "コスト: "* ]] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: a zero budget cuts the re-read off and says so" {  # 上限に達したら未確認の行を出す
  dr_simple 6000000 10
  rm -f "$REC_DIR/S1"
  run python3 "$CL" branch feat
  plain_first="${lines[0]}"
  dr_rec S1 0 0 200 10
  COST_LEDGER_DRIFT_BUDGET_SECONDS=0 run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  line="$(printf '%s\n' "$output" | grep '単価表のずれ:')"
  [[ "$line" == *未確認* && "$line" == *COST_LEDGER_DRIFT_BUDGET_SECONDS* ]] || { echo "$line"; return 1; }
  [ "${lines[0]}" = "$plain_first" ] || { echo "$output"; return 1; }
}

@test "drift: an infinite budget compares to the end" {  # 打ち切らない設定では最後まで突き合わせる
  dr_simple 6000000 10
  COST_LEDGER_DRIFT_BUDGET_SECONDS=inf run python3 "$CL" branch feat
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  [[ "$output" == *'$6.00'* && "$output" != *未確認* ]] || { echo "$output"; return 1; }
}

@test "drift: the ledger re-read is cut off too" {  # 台帳から読むときも打ち切る
  dr_simple 6000000 10
  COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger/ledger.jsonl" COST_LEDGER_DRIFT_BUDGET_SECONDS=0 \
    run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(drift_lines)" = "1" ] || { echo "$output"; return 1; }
  [[ "$output" == *未確認* ]] || { echo "$output"; return 1; }
}

@test "drift: no re-read means no cut-off line" {  # 読み直しが要らなければ未確認の行は出ない
  dr_row S1 r1 100 feat 6000000 | cl_write_log s1
  COST_LEDGER_DRIFT_BUDGET_SECONDS=0 run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || return 1
  [ "$(drift_lines)" = "0" ] || { echo "$output"; return 1; }
}

@test "drift: an unreadable budget value falls back to the default" {  # 読めない上限の値では既定を使う
  dr_simple 6000000 10
  for value in abc -1 nan ''; do
    COST_LEDGER_DRIFT_BUDGET_SECONDS="$value" run python3 "$CL" branch feat
    [ "$status" -eq 0 ] || { echo "value=$value"; echo "$output"; return 1; }
    [ "$(drift_lines)" = "1" ] || { echo "value=$value"; echo "$output"; return 1; }
    [[ "$output" == *'$6.00'* && "$output" != *未確認* ]] || { echo "value=$value"; echo "$output"; return 1; }
  done
}

@test "drift: the re-read does not count unreadable lines twice" {  # 読み直しで「読み取れなかった行」を二重に数えない
  { dr_row S1 r1 100 feat 6000000; echo '["assistant", "S1", "feat"]'; } | cl_write_log s1
  dr_rec S1 0 0 200 10
  run python3 "$CL" branch feat
  [ "$status" -eq 0 ] || return 1
  [[ "$output" == *'読み取れなかった行: 1 件'* ]] || { echo "$output"; return 1; }
}
