#!/usr/bin/env bats
#
# spec: cost-ledger-attribution / cost-ledger-timeline
#
# issue の合計（その issue を閉じた PR の分 + PR のブランチ上に無い区間の分）と、timeline が
# `issue クローズ` の行に続けて積む合計の行を固定する。cost_ledger.py を直接呼ぶ（gh は呼ばれない）。
# hook に JSON を流して閉じた PR の問い合わせを見る Scenario は gate-report.bats に置く。
#
# 共通のデータ（どの行も haiku の input_tokens=1000000 で $1.00）:
#   S1（issue #12 を触ったセッション。3 行とも #12 の区間）: r1 main 00:00:10 / r2 main 00:00:20 / r3 feat/a 00:00:30
#   S2（issue を触っていないセッション。区間の外）:          r4 feat/a 00:00:40 / r5 feat/a 00:00:50
# 区間の合計は $3.00、ブランチ feat/a の合計は $3.00、重なるのは r3 の $1.00。

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
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  {
    cl_row S1 r1 2026-09-01T00:00:10.000Z main "$RA" 1000000 "gh issue view 12"
    cl_row S1 r2 2026-09-01T00:00:20.000Z main "$RA" 1000000
    cl_row S1 r3 2026-09-01T00:00:30.000Z feat/a "$RA" 1000000
  } | cl_write_log s1
  {
    cl_row S2 r4 2026-09-01T00:00:40.000Z feat/a "$RA" 1000000
    cl_row S2 r5 2026-09-01T00:00:50.000Z feat/a "$RA" 1000000
  } | cl_write_log s2
  CLOSE=(--issue 12 --repo "$RA" --trigger "issue クローズ")
}

tl() { python3 "$CL" timeline "$@"; }
issue_json() { python3 "$CL" issue "$@" --repo "$RA" --json; }

# 表の行（見出しと区切りを除く）
rows() { grep '^| ' "$1" | grep -vF "$HEADER" || true; }
nrows() { rows "$1" | wc -l | tr -d ' '; }
row() { rows "$1" | sed -n "${2}p"; }  # $1=本文 $2=何行目
marker() { tail -n 1 "$1"; }
cell() { row "$1" "$2" | awk -F'|' -v n="$3" '{v=$(n+1); sub(/^ /,"",v); sub(/ $/,"",v); print v}'; }  # $3: 1=時刻 2=きっかけ 3=金額 4=入出力 5=キャッシュ

# 標準入力の JSON に python の式（d が JSON）を当て、偽なら落とす。
# eval に渡す式は、このファイルの各テストに書いた固定の文字列だけ（外から来る入力は渡さない）
check() {  # $1=式
  python3 -c '
import json, sys
d = json.load(sys.stdin)
near = lambda a, b: abs(a - b) < 1e-9
assert eval(sys.argv[1]), d
' "$1"
}

# ブランチ feat/b の行を 2 行足す（issue を触っていないセッション）
add_feat_b() {
  {
    cl_row S3 r6 2026-09-01T00:00:41.000Z feat/b "$RA" 1000000
    cl_row S3 r7 2026-09-01T00:00:42.000Z feat/b "$RA" 1000000
  } | cl_write_log s3
}

# 番号 12 だけを issue として答える gh（cost の番号の判別用）
fake_gh_issue_12() {
  cl_fake_gh <<'EOF'
for arg in "$@"; do case "$arg" in */issues/12) echo 12; exit 0 ;; esac; done
exit 1
EOF
}

# --- issue の合計（cost-ledger-attribution） ---

@test "issue-total: acceptance: a row on the PR branch inside the interval is counted once" {  # 区間 $3.00 と feat/a $3.00 が 1 行重なる → combined_total_usd は 5.0（6.0 ではない）
  issue_json 12 --closing-pr 300:feat/a > "$OUT"
  check 'near(d["total_usd"], 3.0)' < "$OUT"
  check 'd["closing_prs"] == [{"number": 300, "branch": "feat/a", "usd": 3.0}]' < "$OUT"
  check 'near(d["outside_pr_usd"], 2.0)' < "$OUT"
  check 'near(d["combined_total_usd"], 5.0)' < "$OUT"
}

@test "issue-total: acceptance: with no closing PR the total equals cost <issue number>" {  # --closing-pr 無しの combined_total_usd は total_usd と同じで、cost 12 の 1 行目の金額と一致する
  issue_json 12 > "$OUT"
  check 'd["closing_prs"] == []' < "$OUT"
  check 'd["combined_total_usd"] == d["total_usd"] and d["outside_pr_usd"] == d["total_usd"]' < "$OUT"
  check 'near(d["combined_total_usd"], 3.0)' < "$OUT"
  fake_gh_issue_12
  run python3 "$CL" cost 12 --repo "$RA" --no-drift-check
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'コスト: $3.00 / ¥450 @150 — issue #12 (acme/ra) 帰属: 区間' ]
  # cost の JSON にも同じ鍵が出て、同じ値になる
  python3 "$CL" cost 12 --repo "$RA" --no-drift-check --json > "$OUT"
  check 'd["closing_prs"] == [] and d["combined_total_usd"] == d["total_usd"] == d["outside_pr_usd"]' < "$OUT"
}

@test "issue-total: two closing PRs are listed in ascending number order" {  # 301:feat/b と 300:feat/a → 300・301 の順で 3.0・2.0、PR 外 2.0、合計 7.0
  add_feat_b
  issue_json 12 --closing-pr 301:feat/b --closing-pr 300:feat/a > "$OUT"
  check '[(p["number"], p["branch"]) for p in d["closing_prs"]] == [(300, "feat/a"), (301, "feat/b")]' < "$OUT"
  check 'near(d["closing_prs"][0]["usd"], 3.0) and near(d["closing_prs"][1]["usd"], 2.0)' < "$OUT"
  check 'near(d["outside_pr_usd"], 2.0) and near(d["combined_total_usd"], 7.0)' < "$OUT"
  check 'near(d["combined_total_usd"], sum(p["usd"] for p in d["closing_prs"]) + d["outside_pr_usd"])' < "$OUT"
}

@test "issue-total: two PRs with the same head branch count the smallest number only" {  # 305:feat/a と 300:feat/a → 300 の 1 件だけで合計 5.0
  issue_json 12 --closing-pr 305:feat/a --closing-pr 300:feat/a > "$OUT"
  check '[p["number"] for p in d["closing_prs"]] == [300]' < "$OUT"
  check 'near(d["combined_total_usd"], 5.0)' < "$OUT"
}

@test "issue-total: a PR with no local rows is listed with zero" {  # どの行にも無いブランチ → usd 0 の 1 件で、PR 外と合計は 3.0
  issue_json 12 --closing-pr 300:feat/none > "$OUT"
  check 'd["closing_prs"] == [{"number": 300, "branch": "feat/none", "usd": 0}]' < "$OUT"
  check 'near(d["outside_pr_usd"], 3.0) and near(d["combined_total_usd"], 3.0)' < "$OUT"
}

@test "issue-total: the text output adds one line with the total and its breakdown" {  # 1 行目は --closing-pr 無しと同じで、$5.00・PR #300 $3.00・PR 外 $2.00 を含む行が 1 行ある
  plain="$(python3 "$CL" issue 12 --repo "$RA")"
  python3 "$CL" issue 12 --repo "$RA" --closing-pr 300:feat/a > "$OUT"
  [ "$(sed -n 1p "$OUT")" = "$(printf '%s\n' "$plain" | sed -n 1p)" ]
  [ "$(sed -n 2p "$OUT")" = '  合計（閉じた PR 込み）: $5.00 — PR #300 $3.00 + PR 外 $2.00' ]
  [ "$(grep -cF '合計（閉じた PR 込み）' "$OUT")" -eq 1 ]
  # --closing-pr 無しの表示は 1 行も増えない
  [ "$(printf '%s\n' "$plain" | grep -cF '合計（閉じた PR 込み）' || true)" -eq 0 ]
  [ "$(sed 2d "$OUT")" = "$plain" ]
}

@test "issue-total: a malformed --closing-pr exits 2 with empty stdout" {  # 300・:feat・x:feat・300:・0:feat は終了コード 2 で標準出力は空
  for bad in 300 :feat x:feat 300: 0:feat -1:feat; do
    run bash -c "python3 '$CL' issue 12 --repo '$RA' --closing-pr=$bad 2>/dev/null"
    [ "$status" -eq 2 ] || { echo "$bad: $status"; return 1; }
    [ -z "$output" ] || { echo "$bad: $output"; return 1; }
    run bash -c "python3 '$CL' issue 12 --repo '$RA' --closing-pr=$bad 2>&1 >/dev/null"
    [ -n "$output" ] || { echo "$bad: no reason on stderr"; return 1; }
  done
}

@test "issue-total: a branch name may contain colons" {  # 最初の : で分ける（300:a:b のブランチは a:b）
  issue_json 12 --closing-pr 300:a:b > "$OUT"
  check 'd["closing_prs"] == [{"number": 300, "branch": "a:b", "usd": 0}]' < "$OUT"
}

@test "issue-total: the plain sum of the two keys is not the issue total" {  # total_usd 3.0 と PR の分 3.0 の和 6.0 より、重なった 1 行の $1.00 だけ小さい
  issue_json 12 --closing-pr 300:feat/a > "$OUT"
  check 'near(d["total_usd"] + d["closing_prs"][0]["usd"], 6.0)' < "$OUT"
  check 'near(d["total_usd"] + d["closing_prs"][0]["usd"] - d["combined_total_usd"], 1.0)' < "$OUT"
}

@test "issue-total: the ledger gives the same total and is synced once" {  # COST_LEDGER_PATH を使っても combined_total_usd は 5.0。PR が 2 件でも同じ行を台帳に 2 回書かない
  add_feat_b
  export COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
  issue_json 12 --closing-pr 300:feat/a > "$OUT"
  check 'near(d["total_usd"], 3.0) and near(d["outside_pr_usd"], 2.0) and near(d["combined_total_usd"], 5.0)' < "$OUT"
  check 'd["closing_prs"] == [{"number": 300, "branch": "feat/a", "usd": 3.0}]' < "$OUT"
  [ "$(wc -l < "$COST_LEDGER_PATH" | tr -d ' ')" -eq 7 ]
  issue_json 12 --closing-pr 301:feat/b --closing-pr 300:feat/a > "$OUT"
  check 'near(d["combined_total_usd"], 7.0)' < "$OUT"
  [ "$(wc -l < "$COST_LEDGER_PATH" | tr -d ' ')" -eq 7 ]
  tl "${CLOSE[@]}" --at "$FAR" --closing-pr 300:feat/a < "$IN" > "$OUT"
  [ "$(cell "$OUT" 2 2)" = '合計（#300 $3.00 + PR 外 $2.00）' ]
  [ "$(cell "$OUT" 2 3)" = '$5.00 (+2.00)' ]
}

# --- 合計の行（cost-ledger-timeline） ---

@test "issue-total: timeline adds the total row after the close row" {  # 表は 2 行。issue クローズ $3.00 (+3.00)、合計（#300 $3.00 + PR 外 $2.00） $5.00 (+2.00)・5.0M (+2.0M)、記録は 2 つ
  tl "${CLOSE[@]}" --at "$FAR" --closing-pr 300:feat/a < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
  [ "$(cell "$OUT" 1 2)" = 'issue クローズ' ]
  [ "$(cell "$OUT" 1 3)" = '$3.00 (+3.00)' ]
  [ "$(cell "$OUT" 2 2)" = '合計（#300 $3.00 + PR 外 $2.00）' ]
  [ "$(cell "$OUT" 2 3)" = '$5.00 (+2.00)' ]
  [ "$(cell "$OUT" 2 4)" = '5.0M (+2.0M)' ]
  [ "$(cell "$OUT" 2 5)" = '0 (+0)' ]
  [ "$(cell "$OUT" 2 1)" = "$(cell "$OUT" 1 1)" ]
  [ "$(marker "$OUT")" = "<!-- cost-ledger:timeline v1 $FAR.000:3.000000:3000000:0 $FAR.000:5.000000:5000000:0 -->" ]
}

@test "issue-total: the total row is cut at --at" {  # feat/a の区間の外の 1 行（r5）だけが T より後 → 合計（#300 $2.00 + PR 外 $2.00） $4.00 (+1.00)
  tl "${CLOSE[@]}" --at $((B+45)) --closing-pr 300:feat/a < "$IN" > "$OUT"
  [ "$(cell "$OUT" 1 3)" = '$3.00 (+3.00)' ]
  [ "$(cell "$OUT" 2 2)" = '合計（#300 $2.00 + PR 外 $2.00）' ]
  [ "$(cell "$OUT" 2 3)" = '$4.00 (+1.00)' ]
}

@test "issue-total: without --closing-pr timeline is unchanged" {  # 表は 1 行で、1 行目は cost 12 の 1 行目と一致する
  tl "${CLOSE[@]}" --at "$FAR" < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 1 ]
  fake_gh_issue_12
  run python3 "$CL" cost 12 --repo "$RA" --no-drift-check
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$OUT")" = "${lines[0]}" ]
  [ "$(sed -n 1p "$OUT")" = 'コスト: $3.00 / ¥450 @150 — issue #12 (acme/ra) 帰属: 区間' ]
}

@test "issue-total: four PRs are each written with their amount" {  # 303:b3・300:feat/a・301:b1・302:b2 → 番号の昇順に 4 件とも書く（まとめない）
  tl "${CLOSE[@]}" --at "$FAR" --closing-pr 303:b3 --closing-pr 300:feat/a --closing-pr 301:b1 --closing-pr 302:b2 < "$IN" > "$OUT"
  [ "$(cell "$OUT" 2 2)" = '合計（#300 $3.00 + #301 $0.00 + #302 $0.00 + #303 $0.00 + PR 外 $2.00）' ]
  [ "$(cell "$OUT" 2 3)" = '$5.00 (+2.00)' ]
}

@test "issue-total: the rows are stacked when only the PR has cost" {  # issue #13 に区間が無くても、feat/a に行があれば 2 行積む。1 行目は $0.00 (+0.00)
  run tl --issue 13 --repo "$RA" --trigger "issue クローズ" --at "$FAR" --closing-pr 300:feat/a < "$IN"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
  [ "$(cell "$OUT" 1 3)" = '$0.00 (+0.00)' ]
  [ "$(cell "$OUT" 2 2)" = '合計（#300 $3.00 + PR 外 $0.00）' ]
  [ "$(cell "$OUT" 2 3)" = '$3.00 (+3.00)' ]
}

@test "issue-total: timeline rejects a malformed --closing-pr and --pr with --closing-pr" {  # 300・:feat・x:feat・300: と、--pr と一緒に渡した場合は出力が空で終了コード 2
  for bad in 300 :feat x:feat 300:; do
    run bash -c "python3 '$CL' timeline --issue 12 --repo '$RA' --trigger 'issue クローズ' --at $FAR --closing-pr=$bad < '$IN' 2>/dev/null"
    [ "$status" -eq 2 ] || { echo "$bad: $status"; return 1; }
    [ -z "$output" ] || { echo "$bad: $output"; return 1; }
  done
  run bash -c "python3 '$CL' timeline --pr 300 --branch feat/a --repo '$RA' --trigger 'PR クローズ' --at $FAR --closing-pr 300:feat/a < '$IN' 2>/dev/null"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "issue-total: the first line shows the total when the last row is the total row" {  # 1 行目は コスト: $5.00 で始まり、issue #12 を含み、帰属: 区間+閉じた PR で終わる
  tl "${CLOSE[@]}" --at "$FAR" --closing-pr 300:feat/a < "$IN" > "$OUT"
  [ "$(sed -n 1p "$OUT")" = 'コスト: $5.00 / ¥750 @150 — issue #12 (acme/ra) 帰属: 区間+閉じた PR' ]
}

@test "issue-total: a later row brings the first line back to the interval total" {  # 合計の行のあとに issue 再オープンを積むと、1 行目は cost 12 の 1 行目と一致し、合計の行は 1 文字も変わらない
  tl "${CLOSE[@]}" --at $((B+60)) --closing-pr 300:feat/a < "$IN" > "$OUT"
  total_row="$(row "$OUT" 2)"
  tl --issue 12 --repo "$RA" --trigger "issue 再オープン" --at $((B+120)) < "$OUT" > "$OUT.2"
  fake_gh_issue_12
  run python3 "$CL" cost 12 --repo "$RA" --no-drift-check
  [ "$(sed -n 1p "$OUT.2")" = "${lines[0]}" ]
  [ "$(nrows "$OUT.2")" -eq 3 ]
  [ "$(row "$OUT.2" 1)" = "$(row "$OUT" 1)" ]
  [ "$(row "$OUT.2" 2)" = "$total_row" ]
  [ "$(cell "$OUT.2" 3 2)" = 'issue 再オープン' ]
}

@test "issue-total: a row after the total row does not use the total as its base" {  # issue クローズ $3.00・合計 $5.00 のあと、区間の累計 $3.50 で積むと $3.50 (+0.50)（-1.50 ではない）
  tl "${CLOSE[@]}" --at $((B+60)) --closing-pr 300:feat/a < "$IN" > "$OUT"
  cl_row S1 r8 2026-09-01T00:01:30.000Z main "$RA" 500000 >> "$CONFIG_DIR/projects/s1/s1.jsonl"
  tl --issue 12 --repo "$RA" --trigger "issue 再オープン" --at $((B+120)) < "$OUT" > "$OUT.2"
  [ "$(cell "$OUT.2" 3 3)" = '$3.50 (+0.50)' ]
  [ "$(cell "$OUT.2" 3 4)" = '3.5M (+500K)' ]
  [ "$(row "$OUT.2" 2)" = "$(row "$OUT" 2)" ]
}

@test "issue-total: the body does not depend on the completion order" {  # T1 issue コメント・T2 issue クローズ+合計・T3 issue 再オープン を T1→T2→T3 と T3→T2→T1 で積んだ本文が 1 文字も違わない
  cl_row S1 r8 2026-09-01T00:01:30.000Z main "$RA" 500000 >> "$CONFIG_DIR/projects/s1/s1.jsonl"
  T1=$((B+15)); T2=$((B+60)); T3=$((B+120))
  one() { tl --issue 12 --repo "$RA" --trigger "issue コメント" --at "$T1"; }
  two() { tl "${CLOSE[@]}" --at "$T2" --closing-pr 300:feat/a; }
  three() { tl --issue 12 --repo "$RA" --trigger "issue 再オープン" --at "$T3"; }
  one < "$IN" | two | three > "$OUT"
  three < "$IN" | two | one > "$OUT.rev"
  diff "$OUT" "$OUT.rev"
  [ "$(nrows "$OUT")" -eq 4 ]
  [ "$(cell "$OUT" 1 2)" = 'issue コメント' ]
  [ "$(cell "$OUT" 1 3)" = '$1.00 (+1.00)' ]
  [ "$(cell "$OUT" 2 2)" = 'issue クローズ' ]
  [ "$(cell "$OUT" 2 3)" = '$3.00 (+2.00)' ]
  [ "$(cell "$OUT" 3 2)" = '合計（#300 $3.00 + PR 外 $2.00）' ]
  [ "$(cell "$OUT" 3 3)" = '$5.00 (+2.00)' ]
  [ "$(cell "$OUT" 4 2)" = 'issue 再オープン' ]
  [ "$(cell "$OUT" 4 3)" = '$3.50 (+0.50)' ]
  [ "$(sed -n 1p "$OUT")" = 'コスト: $3.50 / ¥525 @150 — issue #12 (acme/ra) 帰属: 区間' ]
  # 途中の順（T2 → T1 → T3、T2 → T3 → T1）でも同じ
  two < "$IN" | one | three > "$OUT.mid"
  diff "$OUT" "$OUT.mid"
  two < "$IN" | three | one > "$OUT.mid2"
  diff "$OUT" "$OUT.mid2"
}

@test "issue-total: running the same close twice changes nothing" {  # --closing-pr 付きの出力を標準入力にして同じ引数でもう 1 回 → 出力は標準入力と同じ（2 行のまま）
  tl "${CLOSE[@]}" --at "$FAR" --closing-pr 300:feat/a < "$IN" > "$OUT"
  run tl "${CLOSE[@]}" --at "$FAR" --closing-pr 300:feat/a < "$OUT"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > "$OUT.2"
  diff "$OUT" "$OUT.2"
  [ "$(nrows "$OUT.2")" -eq 2 ]
}

@test "issue-total: the total row is added to a body that already has the close row" {  # 節目の行だけが既にある本文に同じ時刻で --closing-pr 付きを流すと、合計の行だけが足され、節目の行は変わらない
  tl "${CLOSE[@]}" --at "$FAR" < "$IN" > "$OUT"
  tl "${CLOSE[@]}" --at "$FAR" --closing-pr 300:feat/a < "$OUT" > "$OUT.2"
  [ "$(nrows "$OUT.2")" -eq 2 ]
  [ "$(row "$OUT.2" 1)" = "$(row "$OUT" 1)" ]
  [ "$(cell "$OUT.2" 2 3)" = '$5.00 (+2.00)' ]
}

@test "issue-total: the total row's increment is computed even when the records are unreadable" {  # 記録が読めない本文では節目の行の増分は (?) だが、合計の行の増分は計算した値
  printf '%s\n\n%s\n%s\n%s\n' 'コスト: $1.00' "$HEADER" '|---|---|---|---|---|' \
    '| 09/01 00:00 | issue コメント | $1.00 (+1.00) | 1.0M (+1.0M) | 0 (+0) |' > "$IN"
  tl "${CLOSE[@]}" --at "$FAR" --closing-pr 300:feat/a < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 3 ]
  [ "$(cell "$OUT" 2 3)" = '$3.00 (?)' ]
  [ "$(cell "$OUT" 3 3)" = '$5.00 (+2.00)' ]
  [ "$(cell "$OUT" 3 4)" = '5.0M (+2.0M)' ]
}

@test "issue-total: --closing-pr does not change the close row" {  # 同じ --at で --closing-pr を付けた場合と付けない場合の issue クローズの行は 1 文字も違わない
  tl "${CLOSE[@]}" --at "$FAR" --closing-pr 300:feat/a < "$IN" > "$OUT"
  tl "${CLOSE[@]}" --at "$FAR" < "$IN" > "$OUT.plain"
  [ "$(row "$OUT" 1)" = "$(row "$OUT.plain" 1)" ]
  [ "$(cell "$OUT" 1 2)" = 'issue クローズ' ]
}

@test "issue-total: nothing is stacked when both the interval and the total are zero" {  # 区間も feat/none の行も無く、標準入力も空 → 出力は空で終了コード 3
  run tl --issue 13 --repo "$RA" --trigger "issue クローズ" --at "$FAR" --closing-pr 300:feat/none < "$IN"
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}
