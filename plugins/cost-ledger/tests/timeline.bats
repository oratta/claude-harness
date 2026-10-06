#!/usr/bin/env bats
#
# spec: cost-ledger-timeline
#
# cost_ledger.py timeline（標準入力の既存のコメント本文に行を 1 行足して返す）を固定する。
# hook に JSON を流して gh の呼び出しを見る Scenario は gate-report.bats に置く。
# 時刻の欄は TZ=UTC で固定し、会話ログの行の timestamp と --at の前後関係は各テストに書く。

load helper

setup() {
  export LC_ALL=C.UTF-8 TZ=UTC
  cl_setup
  B=1788220800                      # 2026-09-01T00:00:00Z の epoch 秒
  FAR=1900000000                    # どの応答よりも後の時刻
  IN="$BATS_TEST_TMPDIR/in.md"
  OUT="$BATS_TEST_TMPDIR/out.md"
  : > "$IN"
  HEADER='| 時刻 | きっかけ | 金額 | 入出力 | キャッシュ |'
  SEP='|---|---|---|---|---|'
}

tl() { python3 "$CL" timeline "$@"; }

# 表の行（見出しと区切りを除く）
rows() { grep '^| ' "$1" | grep -vF "$HEADER" || true; }
nrows() { rows "$1" | wc -l | tr -d ' '; }
row() { rows "$1" | sed -n "${2}p"; }  # $1=本文 $2=何行目
marker() { tail -n 1 "$1"; }
cell() { row "$1" "$2" | awk -F'|' -v n="$3" '{v=$(n+1); sub(/^ /,"",v); sub(/ $/,"",v); print v}'; }  # $3: 1=時刻 2=きっかけ 3=金額 4=入出力 5=キャッシュ

# 既存の本文を組み立てる。$1=1 行目  $2=最終行  標準入力=表の行
body() {
  { printf '%s\n\n%s\n%s\n' "$1" "$HEADER" "$SEP"; cat; printf '\n%s\n' "$2"; }
}

# haiku の 1 応答（input_tokens=1000000 が $1.00）を feat/t のログに足す
add_row() {  # $1=requestId $2=秒（00:00:SS） $3=input_tokens
  mkdir -p "$CONFIG_DIR/projects/t"
  cl_row S1 "$1" "2026-09-01T00:00:$2.000Z" feat/t /nonexistent/t "$3" >> "$CONFIG_DIR/projects/t/t.jsonl"
}

PR_ARGS=(--pr 300 --branch feat/t)

# --- 行の書式 ---

@test "timeline: the second row shows the totals with signed increments" {  # 前の累計 $16.60・900,000・33,000,000 に $39.62・2,100,000・81,000,000 で積むと (+23.02)・(+1.2M)・(+48M)
  cl_mini_log feat/t claude-opus-5-5 '{"input_tokens":1161250,"output_tokens":938750,"cache_read_input_tokens":81000000}'
  first='| 09/01 00:00 | PR コメント | $16.60 (+16.60) | 900K (+900K) | 33M (+33M) |'
  printf '%s\n' "$first" | body 'コスト: $16.60 / ¥2,490 @150 — PR #300 (feat/t) 帰属: ブランチ' \
    "<!-- cost-ledger:timeline v1 $((B+5)).000:16.600000:900000:33000000 -->" > "$IN"
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+60)) < "$IN" > "$OUT"
  [ "$(sed -n 1p "$OUT")" = 'コスト: $39.62 / ¥5,943 @150 — PR #300 (feat/t) 帰属: ブランチ' ]
  [ "$(nrows "$OUT")" -eq 2 ]
  [ "$(row "$OUT" 1)" = "$first" ]
  [ "$(row "$OUT" 2)" = '| 09/01 00:01 | Ready | $39.62 (+23.02) | 2.1M (+1.2M) | 81M (+48M) |' ]
  [ "$(marker "$OUT")" = "<!-- cost-ledger:timeline v1 $((B+5)).000:16.600000:900000:33000000 $((B+60)).000:39.620000:2100000:81000000 -->" ]
}

@test "timeline: the first row's increment equals its total" {  # コメントが無い状態で $16.60 を積むと $16.60 (+16.60)。本文は 1 行目・空行・表・空行・最終行
  add_row r1 10 16600000
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+60)) < "$IN" > "$OUT"
  [ "$(sed -n 1p "$OUT")" = 'コスト: $16.60 / ¥2,490 @150 — PR #300 (feat/t) 帰属: ブランチ' ]
  [ -z "$(sed -n 2p "$OUT")" ]
  [ "$(sed -n 3p "$OUT")" = "$HEADER" ]
  [ "$(sed -n 4p "$OUT")" = "$SEP" ]
  [ "$(sed -n 5p "$OUT")" = '| 09/01 00:01 | PR コメント | $16.60 (+16.60) | 17M (+17M) | 0 (+0) |' ]
  [ -z "$(sed -n 6p "$OUT")" ]
  [ "$(sed -n 7p "$OUT")" = "<!-- cost-ledger:timeline v1 $((B+60)).000:16.600000:16600000:0 -->" ]
  [ "$(wc -l < "$OUT" | tr -d ' ')" -eq 7 ]
}

@test "timeline: a total that went down is written with a minus sign" {  # 前の累計 $5.00 に $3.80 で積むと $3.80 (-1.20)
  add_row r1 10 3800000
  printf '%s\n' '| 09/01 00:00 | issue コメント | $5.00 (+5.00) | 5.0M (+5.0M) | 0 (+0) |' \
    | body 'コスト: $5.00' "<!-- cost-ledger:timeline v1 $((B+5)).000:5.000000:5000000:0 -->" > "$IN"
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+60)) < "$IN" > "$OUT"
  [ "$(cell "$OUT" 2 3)" = '$3.80 (-1.20)' ]
  [ "$(cell "$OUT" 2 4)" = '3.8M (-1.2M)' ]
}

@test "timeline: tokens of a model without a price are still counted" {  # 料金表に無いモデルの入力 1,000 トークンだけでも終了コード 0 で $0.00 (+0.00)・1K (+1K) の行が出る
  cl_mini_log feat/t mystery-model-1 '{"input_tokens":1000,"output_tokens":0}'
  run tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" < "$IN"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" > "$OUT"
  [ "$(cell "$OUT" 1 3)" = '$0.00 (+0.00)' ]
  [ "$(cell "$OUT" 1 4)" = '1K (+1K)' ]
}

@test "timeline: token units switch at the documented boundaries" {  # 999・1,000・999,999・1,000,000・9,999,999・10,000,000・1,000,000,000 の表示。四捨五入で次の単位に届く値（999,999 → 1.0M、9,999,999 → 10M）は次の単位で書く
  while read -r tokens shown; do
    cl_mini_log feat/t mystery-model-1 "{\"input_tokens\":$tokens,\"output_tokens\":0}"
    tl "${PR_ARGS[@]}" --trigger x --at "$FAR" < "$IN" > "$OUT"
    [ "$(cell "$OUT" 1 4)" = "$shown (+$shown)" ] || { echo "$tokens: $(cell "$OUT" 1 4)"; return 1; }
  done <<'EOF'
999 999
1000 1K
999499 999K
999999 1.0M
1000000 1.0M
2100000 2.1M
9999999 10M
10000000 10M
81000000 81M
999999999 1.0B
1000000000 1.0B
1200000000 1.2B
EOF
}

# --- 前の節目の値はコメントの最終行から読む ---

@test "timeline: increments come from the exact values in the last line" {  # 記録 949,999 に 1,050,001 で積むと入出力の増分は +100K（表示 950K と 1.1M の差ではない）
  add_row r1 10 1050001
  printf '%s\n' '| 09/01 00:00 | PR コメント | $16.60 (+16.60) | 950K (+950K) | 33M (+33M) |' \
    | body 'コスト: $16.60' "<!-- cost-ledger:timeline v1 $((B+5)).000:16.604000:949999:33000000 -->" > "$IN"
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+60)) < "$IN" > "$OUT"
  [ "$(cell "$OUT" 2 4)" = '1.1M (+100K)' ]
}

@test "timeline: a broken last line keeps the rows and writes (?) increments" {  # 記録の金額が数値でない（表は 2 行）→ 既存の 2 行はそのまま、足した行の増分は 3 項目とも (?)、記録は今回の 1 つ
  add_row r1 10 3000000
  printf '%s\n' '| 09/01 00:00 | PR コメント | $1.00 (+1.00) | 1.0M (+1.0M) | 0 (+0) |' \
                '| 09/01 00:00 | Ready | $2.00 (+1.00) | 2.0M (+1.0M) | 0 (+0) |' \
    | body 'コスト: $2.00' "<!-- cost-ledger:timeline v1 $((B+5)).000:abc:1000000:0 $((B+6)).000:2.000000:2000000:0 -->" > "$IN"
  rows "$IN" > "$BATS_TEST_TMPDIR/before"
  tl "${PR_ARGS[@]}" --trigger "マージ" --at $((B+60)) < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 3 ]
  rows "$OUT" | head -n 2 | cmp - "$BATS_TEST_TMPDIR/before"
  [ "$(row "$OUT" 3)" = '| 09/01 00:01 | マージ | $3.00 (?) | 3.0M (?) | 0 (?) |' ]
  [ "$(marker "$OUT")" = "<!-- cost-ledger:timeline v1 $((B+60)).000:3.000000:3000000:0 -->" ]
}

@test "timeline: a body without the marker line is treated as unreadable, not as zero" {  # 目印の行が無い本文に積むと増分は (?)（0 から全額増えたとは書かない）
  add_row r1 10 3000000
  printf 'コスト: $1.00\n\n%s\n%s\n%s\n' "$HEADER" "$SEP" '| 09/01 00:00 | PR コメント | $1.00 (+1.00) | 1.0M (+1.0M) | 0 (+0) |' > "$IN"
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+60)) < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
  [ "$(cell "$OUT" 2 3)" = '$3.00 (?)' ]
}

@test "timeline: after a broken line, the next row is exact and the extra rows stay" {  # 表 3 行・記録 1 つ → 既存の 3 行はそのまま、足した行の増分は記録との正確な差、記録は 2 つ
  add_row r1 10 3000000
  printf '%s\n' '| 09/01 00:00 | PR コメント | $0.40 (+0.40) | 400K (+400K) | 0 (+0) |' \
                '| 09/01 00:00 | Ready | $0.70 (+0.30) | 700K (+300K) | 0 (+0) |' \
                '| 09/01 00:00 | PR コメント | $1.00 (?) | 1.0M (?) | 0 (?) |' \
    | body 'コスト: $1.00' "<!-- cost-ledger:timeline v1 $((B+10)).000:1.000000:1000000:0 -->" > "$IN"
  rows "$IN" > "$BATS_TEST_TMPDIR/before"
  tl "${PR_ARGS[@]}" --trigger "マージ" --at $((B+60)) < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 4 ]
  rows "$OUT" | head -n 3 | cmp - "$BATS_TEST_TMPDIR/before"
  [ "$(row "$OUT" 4)" = '| 09/01 00:01 | マージ | $3.00 (+2.00) | 3.0M (+2.0M) | 0 (+0) |' ]
  [ "$(marker "$OUT")" = "<!-- cost-ledger:timeline v1 $((B+10)).000:1.000000:1000000:0 $((B+60)).000:3.000000:3000000:0 -->" ]
}

# --- 累計はきっかけの時刻で切る ---

@test "timeline: responses after --at are not counted" {  # T(00:00:30) より前の $1.00 と後の $2.00 → 行は $1.00 (+1.00)、1 行目も $1.00
  add_row r1 10 1000000
  add_row r2 50 2000000
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$IN" > "$OUT"
  [ "$(cell "$OUT" 1 3)" = '$1.00 (+1.00)' ]
  sed -n 1p "$OUT" | grep -qF 'コスト: $1.00 /'
}

@test "timeline: a response stamped exactly at --at is counted" {  # timestamp が --at と同じ応答は数える（以前 = 含む）
  add_row r1 30 1000000
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$IN" > "$OUT"
  [ "$(cell "$OUT" 1 3)" = '$1.00 (+1.00)' ]
}

@test "timeline: the same log and the same input give the same body" {  # 同じ会話ログと同じ標準入力なら、時間をおいて 2 回実行しても 1 文字も違わない
  add_row r1 10 1000000
  add_row r2 50 2000000
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$IN" > "$OUT"
  sleep 1
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$IN" > "$OUT.2"
  cmp "$OUT" "$OUT.2"
}

@test "timeline: a response written after the read lands in the next row's increment" {  # T1 のあとで足された T1 より前の $0.50 と T1〜T2 の $2.00 → 1 行目は $1.00 (+1.00) のまま、2 行目は $3.50 (+2.50)
  add_row r1 10 1000000
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$IN" > "$OUT"
  add_row r0 05 500000
  add_row r2 40 2000000
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+55)) < "$OUT" > "$OUT.2"
  [ "$(cell "$OUT.2" 1 3)" = '$1.00 (+1.00)' ]
  [ "$(cell "$OUT.2" 2 3)" = '$3.50 (+2.50)' ]
}

@test "timeline: an issue total is cut at --at too" {  # issue #12 の区間に T の前後の応答 → 累計は、T より後の応答を除いた会話ログで cost 12 を実行した値と同じ
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  mkdir -p "$CONFIG_DIR/projects/i"
  cl_row S1 r1 2026-09-01T00:00:10.000Z main "$RA" 1000000 "gh issue view 12" > "$CONFIG_DIR/projects/i/i.jsonl"
  cl_row S1 r2 2026-09-01T00:00:50.000Z main "$RA" 2000000 >> "$CONFIG_DIR/projects/i/i.jsonl"
  tl --issue 12 --trigger "issue コメント" --at $((B+30)) --repo "$RA" --target-repo acme/ra < "$IN" > "$OUT"
  [ "$(cell "$OUT" 1 3)" = '$1.00 (+1.00)' ]
  # T より後の応答を除いた会話ログ
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/claude-cut"
  mkdir -p "$CLAUDE_CONFIG_DIR/projects/i"
  head -n 1 "$CONFIG_DIR/projects/i/i.jsonl" > "$CLAUDE_CONFIG_DIR/projects/i/i.jsonl"
  cl_fake_gh <<'EOF'
for arg in "$@"; do case "$arg" in */issues/12) echo 12; exit 0 ;; esac; done
exit 1
EOF
  python3 "$CL" cost 12 --repo "$RA" > "$OUT.cost"
  [ "$(sed -n 1p "$OUT")" = "$(sed -n 1p "$OUT.cost")" ]
}

# --- 行は時刻順に並べ、完了順によらず同じ本文にする ---

two_rows_log() {  # T1(00:00:30) 以前の累計 $1.00、T2(00:00:55) 以前の累計 $3.00
  add_row r1 10 1000000
  add_row r2 40 2000000
}

@test "timeline: two calls finishing in reverse order give the same body" {  # T2 → T1 の順でも、行は PR コメント・Ready の順で $1.00 (+1.00)・$3.00 (+2.00)、本文は T1 → T2 と同じ
  two_rows_log
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+55)) < "$IN" > "$OUT.r1"
  [ "$(cell "$OUT.r1" 1 3)" = '$3.00 (+3.00)' ]
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$OUT.r1" > "$OUT.r2"
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$IN" > "$OUT.f1"
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+55)) < "$OUT.f1" > "$OUT.f2"
  [ "$(nrows "$OUT.r2")" -eq 2 ]
  [ "$(cell "$OUT.r2" 1 2)" = 'PR コメント' ]
  [ "$(cell "$OUT.r2" 2 2)" = 'Ready' ]
  [ "$(cell "$OUT.r2" 1 3)" = '$1.00 (+1.00)' ]
  [ "$(cell "$OUT.r2" 2 3)" = '$3.00 (+2.00)' ]
  sed -n 1p "$OUT.r2" | grep -qF 'コスト: $3.00 /'
  diff "$OUT.r2" "$OUT.f2"
}

@test "timeline: three calls finishing as T3, T1, T2 give the same body as T1, T2, T3" {  # 3 回の逆順（T3 → T1 → T2）でも T1 → T2 → T3 の本文と差が無い
  two_rows_log
  add_row r3 50 4000000
  tl "${PR_ARGS[@]}" --trigger "マージ" --at $((B+58)) < "$IN" > "$OUT.a"
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$OUT.a" > "$OUT.b"
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+45)) < "$OUT.b" > "$OUT.c"
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$IN" > "$OUT.x"
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+45)) < "$OUT.x" > "$OUT.y"
  tl "${PR_ARGS[@]}" --trigger "マージ" --at $((B+58)) < "$OUT.y" > "$OUT.z"
  [ "$(nrows "$OUT.c")" -eq 3 ]
  [ "$(cell "$OUT.c" 3 3)" = '$7.00 (+4.00)' ]
  diff "$OUT.c" "$OUT.z"
}

@test "timeline: two calls at the same time are ordered by the trigger name" {  # 同じ --at の Ready と PR コメント → どちらの順でも本文は同じで、呼び名のバイト順、下の行の増分は 0
  two_rows_log
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+55)) < "$IN" > "$OUT.a1"
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+55)) < "$OUT.a1" > "$OUT.a2"
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+55)) < "$IN" > "$OUT.b1"
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+55)) < "$OUT.b1" > "$OUT.b2"
  diff "$OUT.a2" "$OUT.b2"
  [ "$(nrows "$OUT.a2")" -eq 2 ]
  [ "$(row "$OUT.a2" 1)" = '| 09/01 00:00 | PR コメント | $3.00 (+3.00) | 3.0M (+3.0M) | 0 (+0) |' ]
  [ "$(row "$OUT.a2" 2)" = '| 09/01 00:00 | Ready | $3.00 (+0.00) | 3.0M (+0) | 0 (+0) |' ]
}

@test "timeline: running the same milestone twice adds no row" {  # 時刻・きっかけ・累計が同じなら終了コード 0 で、出力は標準入力の本文と同じ
  two_rows_log
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+55)) < "$IN" > "$OUT"
  run tl "${PR_ARGS[@]}" --trigger Ready --at $((B+55)) < "$OUT"
  [ "$status" -eq 0 ]
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+55)) < "$OUT" > "$OUT.2"
  cmp "$OUT" "$OUT.2"
}

@test "timeline: in the usual order the existing rows are untouched" {  # 表が 2 行のコメントに、どの記録よりも後の時刻で積むと先頭の 2 行は 1 文字も違わない
  two_rows_log
  add_row r3 50 4000000
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at $((B+30)) < "$IN" > "$OUT.1"
  tl "${PR_ARGS[@]}" --trigger Ready --at $((B+45)) < "$OUT.1" > "$OUT.2"
  tl "${PR_ARGS[@]}" --trigger "マージ" --at $((B+58)) < "$OUT.2" > "$OUT.3"
  [ "$(nrows "$OUT.3")" -eq 3 ]
  rows "$OUT.2" > "$BATS_TEST_TMPDIR/before"
  rows "$OUT.3" | head -n 2 | cmp - "$BATS_TEST_TMPDIR/before"
}

# --- 数字と書式は timeline サブコマンドから取る ---

@test "timeline: the first line matches cost <PR number>" {  # どの応答よりも後の --at なら、1 行目は cost 271 の 1 行目と一致する
  cl_materialize
  cl_fake_gh <<'EOF'
for arg in "$@"; do
  case "$arg" in
    */pulls/271) echo "oratta/sample-feature"; exit 0 ;;
    */issues/148) echo "148"; exit 0 ;;
  esac
done
exit 1
EOF
  python3 "$CL" cost 271 --repo "$REPO_A" > "$OUT.cost"
  : > "$BATS_TEST_TMPDIR/gh-called"
  cl_fake_gh <<EOF
echo called >> "$BATS_TEST_TMPDIR/gh-called"
exit 1
EOF
  tl --pr 271 --branch oratta/sample-feature --trigger "PR コメント" --at "$FAR" --repo "$REPO_A" --target-repo acme/repo-a < "$IN" > "$OUT"
  [ "$(sed -n 1p "$OUT")" = "$(sed -n 1p "$OUT.cost")" ]
  [ "$(sed -n 1p "$OUT")" = 'コスト: $5.80 / ¥870 @150 — PR #271 (oratta/sample-feature) 帰属: ブランチ' ]
  [ ! -s "$BATS_TEST_TMPDIR/gh-called" ]   # timeline は gh を呼ばない
}

@test "timeline: the first line matches cost <issue number>" {  # issue の 1 行目は cost 148 の 1 行目と一致する（timeline は gh を呼ばない）
  cl_materialize
  cl_fake_gh <<'EOF'
for arg in "$@"; do case "$arg" in */issues/148) echo "148"; exit 0 ;; esac; done
exit 1
EOF
  python3 "$CL" cost 148 --repo "$REPO_A" > "$OUT.cost"
  : > "$BATS_TEST_TMPDIR/gh-called"
  cl_fake_gh <<EOF
echo called >> "$BATS_TEST_TMPDIR/gh-called"
exit 1
EOF
  tl --issue 148 --trigger "issue コメント" --at "$FAR" --repo "$REPO_A" --target-repo acme/repo-a < "$IN" > "$OUT"
  [ "$(sed -n 1p "$OUT")" = "$(sed -n 1p "$OUT.cost")" ]
  [ "$(sed -n 1p "$OUT")" = 'コスト: $2.20 / ¥330 @150 — issue #148 (acme/repo-a) 帰属: 区間' ]
  [ ! -s "$BATS_TEST_TMPDIR/gh-called" ]
}

@test "timeline: the first line matches cost at the sixth-digit rounding boundary" {  # claude-opus-5-5 のキャッシュ読み出し 24,998 トークン（$0.0049996）など境界の値でも、1 行目は cost 271 の 1 行目と一致する
  cl_fake_gh <<'EOF'
for arg in "$@"; do case "$arg" in */pulls/271) echo "feat/m"; exit 0 ;; esac; done
exit 1
EOF
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  for case in "24998:\$0.01 / ¥1" "24997:\$0.00 / ¥1" "25000:\$0.01 / ¥1" "24975:\$0.00 / ¥1"; do
    tokens="${case%%:*}" shown="${case#*:}"
    cl_mini_log feat/m claude-opus-5-5 "{\"input_tokens\": 0, \"output_tokens\": 0, \"cache_read_input_tokens\": $tokens}"
    python3 "$CL" cost 271 --repo "$BATS_TEST_TMPDIR/plain" > "$OUT.cost"
    tl --pr 271 --branch feat/m --trigger "PR コメント" --at "$FAR" < "$IN" > "$OUT"
    [ "$(sed -n 1p "$OUT")" = "$(sed -n 1p "$OUT.cost")" ]
    sed -n 1p "$OUT" | grep -qF "コスト: $shown @150 — PR #271 (feat/m) 帰属: ブランチ"
  done
}

@test "timeline: responses added after the last ledger-sync are included" {  # ledger-sync のあとに増えた応答も、Stop hook を待たずに累計に含まれる
  export COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
  add_row r1 10 1000000
  python3 "$CL" ledger-sync --quiet
  add_row r2 40 2000000
  tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" < "$IN" > "$OUT"
  [ "$(cell "$OUT" 1 3)" = '$3.00 (+3.00)' ]
}

@test "timeline: no cost and no comment prints nothing and exits 3" {  # そのブランチの行が 1 つも無く標準入力も空 → 出力は空で終了コード 3
  add_row r1 10 1000000
  run tl --pr 300 --branch feat/none --trigger "PR コメント" --at "$FAR" < "$IN"
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}

@test "timeline: zero cost still adds a row when a comment already exists" {  # 累計が 0 でも既にコメントがあれば積む
  printf '%s\n' '| 09/01 00:00 | PR コメント | $1.00 (+1.00) | 1.0M (+1.0M) | 0 (+0) |' \
    | body 'コスト: $1.00' "<!-- cost-ledger:timeline v1 $((B+5)).000:1.000000:1000000:0 -->" > "$IN"
  run tl --pr 300 --branch feat/none --trigger Ready --at "$FAR" < "$IN"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
  [ "$(cell "$OUT" 2 3)" = '$0.00 (-1.00)' ]
}

@test "timeline: an issue in another repository prints nothing and exits 3" {  # --target-repo が --repo の場所のリポジトリと違う issue → 出力は空で終了コード 3
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  mkdir -p "$CONFIG_DIR/projects/i"
  cl_row S1 r1 2026-09-01T00:00:10.000Z main "$RA" 1000000 "gh issue view 12" > "$CONFIG_DIR/projects/i/i.jsonl"
  run tl --issue 12 --trigger "issue コメント" --at "$FAR" --repo "$RA" --target-repo acme/other < "$IN"
  [ "$status" -eq 3 ]
  [ -z "$output" ]
  run tl --issue 12 --trigger "issue コメント" --at "$FAR" --repo "$RA" --target-repo acme/ra < "$IN"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | sed -n 1p | grep -qF 'コスト: $1.00 / ¥150 @150 — issue #12 (acme/ra) 帰属: 区間'
}

@test "timeline: a PR in another repository prints nothing and exits 3" {  # --target-repo が --repo の場所のリポジトリと違う PR → そのブランチにコストがあっても出力は空で終了コード 3
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  add_row r1 10 1000000
  run tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" --repo "$RA" --target-repo acme/other < "$IN"
  [ "$status" -eq 3 ]
  [ -z "$output" ]
  # 既にコメントがあっても積まない
  printf '%s\n' '| 09/01 00:00 | PR コメント | $1.00 (+1.00) | 1.0M (+1.0M) | 0 (+0) |' \
    | body 'コスト: $1.00' "<!-- cost-ledger:timeline v1 $((B+5)).000:1.000000:1000000:0 -->" > "$IN"
  run tl "${PR_ARGS[@]}" --trigger Ready --at "$FAR" --repo "$RA" --target-repo acme/other < "$IN"
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}

@test "timeline: a PR in the same repository is stacked" {  # --target-repo が --repo の場所のリポジトリと同じ PR → 積む
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  add_row r1 10 1000000
  run tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" --repo "$RA" --target-repo acme/ra < "$IN"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | sed -n 1p | grep -qF 'コスト: $1.00 / ¥150 @150 — PR #300 (feat/t) 帰属: ブランチ'
}

@test "timeline: a same-named repository on another host is not stacked" {  # 作業中のリポジトリの origin が github.com 以外のホストの acme/ra → --target-repo acme/ra の PR でも issue でも出力は空で終了コード 3
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  add_row r1 10 1000000
  cl_row S1 r2 2026-09-01T00:00:10.000Z main "$RA" 1000000 "gh issue view 12" >> "$CONFIG_DIR/projects/t/t.jsonl"
  for url in https://unrelated.example/acme/ra.git git@unrelated.example:acme/ra.git \
             ssh://git@unrelated.example/acme/ra.git; do
    git -C "$RA" remote set-url origin "$url"
    run tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" --repo "$RA" --target-repo acme/ra < "$IN"
    [ "$status" -eq 3 ]
    [ -z "$output" ]
    run tl --issue 12 --trigger "issue コメント" --at "$FAR" --repo "$RA" --target-repo acme/ra < "$IN"
    [ "$status" -eq 3 ]
    [ -z "$output" ]
  done
}

@test "timeline: an ssh origin on github.com is stacked" {  # origin が git@github.com:acme/ra.git と ssh://git@github.com/acme/ra.git → --target-repo acme/ra の PR を積む
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  add_row r1 10 1000000
  for url in git@github.com:acme/ra.git ssh://git@github.com/acme/ra.git; do
    git -C "$RA" remote set-url origin "$url"
    run tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" --repo "$RA" --target-repo acme/ra < "$IN"
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | sed -n 1p | grep -qF 'コスト: $1.00 / ¥150 @150 — PR #300 (feat/t) 帰属: ブランチ'
  done
}

@test "timeline: a working repository without origin is not stacked" {  # origin の無い git リポジトリ → ホストを判別できないので --target-repo があれば出力は空で終了コード 3
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  git -C "$RA" remote remove origin
  add_row r1 10 1000000
  run tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" --repo "$RA" --target-repo ra < "$IN"
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}

@test "timeline: a PR without --target-repo is stacked without the comparison" {  # --target-repo を渡さない PR → 照合せずに積む（--repo が git リポジトリでなくても同じ）
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  add_row r1 10 1000000
  run tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" --repo "$RA" < "$IN"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | sed -n 1p | grep -qF 'コスト: $1.00 / ¥150 @150 — PR #300 (feat/t) 帰属: ブランチ'
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  run tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" --repo "$BATS_TEST_TMPDIR/plain" < "$IN"
  [ "$status" -eq 0 ]
}

@test "timeline: a PR whose working repository is unknown is not stacked" {  # --repo が git リポジトリでなく --target-repo がある PR → 作業中のリポジトリと照合できないので出力は空で終了コード 3
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  add_row r1 10 1000000
  run tl "${PR_ARGS[@]}" --trigger "PR コメント" --at "$FAR" --repo "$BATS_TEST_TMPDIR/plain" --target-repo acme/ra < "$IN"
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}

# --- issue の集計は関係するセッションだけを読む ---

issue_json_digest() {  # issue <番号> --json の total_usd・messages・intervals を 1 つの文字列にする
  python3 "$CL" issue "$1" --repo "$2" --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(json.dumps([round(d["total_usd"], 9), d["messages"], d["intervals"],
                  round(d["unknown_repo_usd"], 9), d["unknown_repo_messages"]],
                 ensure_ascii=False, sort_keys=True))'
}

@test "timeline: reading only the sessions that touched the issue changes nothing" {  # 台帳から絞って読んだ issue <番号> --json と cost <番号> の 1 行目は、会話ログの直読みと同じ
  cl_materialize
  cl_fake_gh <<'EOF'
for arg in "$@"; do case "$arg" in */issues/148) echo "148"; exit 0 ;; esac; done
exit 1
EOF
  for repo in "$REPO_A" "$REPO_B"; do
    unset COST_LEDGER_PATH
    direct="$(issue_json_digest 148 "$repo")"
    direct_line="$(python3 "$CL" cost 148 --repo "$repo" | sed -n 1p)"
    export COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
    ledger="$(issue_json_digest 148 "$repo")"
    ledger_line="$(python3 "$CL" cost 148 --repo "$repo" | sed -n 1p)"
    [ -n "$direct" ]
    [ "$direct" = "$ledger" ] || { echo "direct=$direct"; echo "ledger=$ledger"; return 1; }
    [ "$direct_line" = "$ledger_line" ]
  done
  [ -s "$COST_LEDGER_PATH" ]
  echo "$direct" | grep -q '"session_id"'   # 区間が 1 つ以上ある（空同士の一致ではない）
}

@test "timeline: the session filter reads other issues' sessions out, not in" {  # 別の issue だけを触ったセッションは読まれないが、同じ issue を触ったセッションの全行は区間に入る
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  mkdir -p "$CONFIG_DIR/projects/i"
  {
    cl_row S1 a1 2026-09-01T00:00:10.000Z main "$RA" 1000000 "gh issue view 12"
    cl_row S1 a2 2026-09-01T00:00:20.000Z main "$RA" 2000000
    cl_row S2 b1 2026-09-01T00:00:10.000Z main "$RA" 4000000 "gh issue view 13"
    cl_row S3 c1 2026-09-01T00:00:10.000Z main "$RA" 8000000
  } > "$CONFIG_DIR/projects/i/i.jsonl"
  export COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
  python3 "$CL" issue 12 --repo "$RA" > "$OUT"
  sed -n 1p "$OUT" | grep -qF 'コスト: $3.00 /'
  tl --issue 12 --trigger "issue コメント" --at "$FAR" --repo "$RA" < "$IN" > "$OUT.t"
  [ "$(cell "$OUT.t" 1 3)" = '$3.00 (+3.00)' ]
  [ "$(cell "$OUT.t" 1 4)" = '3.0M (+3.0M)' ]
}
