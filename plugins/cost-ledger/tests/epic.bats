#!/usr/bin/env bats
#
# spec: cost-ledger-cost-command / cost-ledger-attribution / cost-ledger-timeline
#
# 子 issue を持つ issue（エピック）の `cost <番号>` が、子 issue ごとの内訳と合計を返すことを固定する。
# cost_ledger.py を直接呼び、gh は偽物に差し替える（ネットワークには出ない）。
#
# 共通のデータ（リポジトリ acme/ra。どの行も haiku の input_tokens=1000000 で $1.00）:
#   S11（issue #11 を触ったセッション）: r1 main / r2 main
#   S12（issue #12 を触ったセッション）: r3 main
#   S10（issue #10 を触ったセッション）: r4 main
#   SA （issue を触っていないセッション）: r5 feat/a / r6 feat/a
#   SB （issue を触っていないセッション）: r7 feat/b
# gh は、#10 の子 issue が #11（child a・closed）と #12（child b・open）だと答える。

load helper

setup() {
  export LC_ALL=C.UTF-8 TZ=UTC
  cl_setup
  FAR=1900000000                    # どの応答よりも後の時刻
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  export EPIC_GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  export EPIC_GQL_DIR="$BATS_TEST_TMPDIR/gql"
  export EPIC_SUBS="10=2"           # issue の問い合わせが答える子の数（<番号>=<数> を空白区切り）
  export EPIC_BARE=""               # 空でなければ、issue の問い合わせは番号だけを返す
  export EPIC_GQL_FAIL=""           # 空でなければ、GraphQL の呼び出しだけが失敗する
  export EPIC_PR="" EPIC_PR_HEAD="" # PR として答える番号と、そのヘッドブランチ
  mkdir -p "$EPIC_GQL_DIR"
  : > "$EPIC_GH_LOG"
  fake_gh
}

# 呼び出し 1 回につき 1 行を控える gh。
#   pulls/<N>   … EPIC_PR と同じ番号だけヘッドブランチを返す。ほかは失敗（PR ではない）
#   issues/<N>  … "<番号> <子の数>"（EPIC_BARE があれば番号だけ）
#   api graphql … 引数の number=<N> を見て $EPIC_GQL_DIR/<N>.json を返す。無ければ失敗
fake_gh() {
  cl_fake_gh <<'EOF'
printf '%s\n' "$*" >> "$EPIC_GH_LOG"
if [ "$1" = api ] && [ "$2" = graphql ]; then
  [ -z "$EPIC_GQL_FAIL" ] || exit 1
  n=""
  for arg in "$@"; do case "$arg" in number=*) n="${arg#number=}" ;; esac; done
  [ -f "$EPIC_GQL_DIR/$n.json" ] || exit 1
  cat "$EPIC_GQL_DIR/$n.json"
  exit 0
fi
for arg in "$@"; do
  case "$arg" in
    */pulls/*)
      [ -n "$EPIC_PR" ] && [ "${arg##*/}" = "$EPIC_PR" ] || exit 1
      echo "$EPIC_PR_HEAD"; exit 0 ;;
    */issues/*)
      n="${arg##*/}"; total=0
      for kv in $EPIC_SUBS; do [ "${kv%%=*}" = "$n" ] && total="${kv#*=}"; done
      if [ -n "$EPIC_BARE" ]; then echo "$n"; else echo "$n $total"; fi
      exit 0 ;;
  esac
done
exit 1
EOF
}

# 子を持たない issue <N> を閉じた PR が 0 件、という GraphQL の応答を置く
no_closing_prs() {  # $1=issue 番号
  printf '{"data":{"repository":{"nameWithOwner":"acme/ra","issue":{"closedByPullRequestsReferences":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}}}' > "$EPIC_GQL_DIR/$1.json"
}

gh_calls() { wc -l < "$EPIC_GH_LOG" | tr -d ' '; }
gql_calls() { grep -c '^api graphql' "$EPIC_GH_LOG" || true; }

# ---- GraphQL の応答を作る -------------------------------------------------

# 閉じた PR 1 件。$1=番号 $2=ヘッドブランチ $3=isCrossRepository $4=ベースのリポジトリ
pr() {
  printf '{"number": %s, "headRefName": "%s", "isCrossRepository": %s, "baseRepository": {"nameWithOwner": "%s"}}' \
    "$1" "$2" "${3:-false}" "${4:-acme/ra}"
}

# closedByPullRequestsReferences。$@=pr の出力。PR_MORE=true で hasNextPage を真にする
prs() {
  local IFS=,
  printf '{"nodes": [%s], "pageInfo": {"hasNextPage": %s}}' "$*" "${PR_MORE:-false}"
}

# 子 1 件。$1=番号 $2=題名 $3=状態(OPEN|CLOSED) $4=子の数 $5=prs の出力 $6=リポジトリ
child() {
  printf '{"number": %s, "title": "%s", "state": "%s", "repository": {"nameWithOwner": "%s"}, "subIssuesSummary": {"total": %s}, "closedByPullRequestsReferences": %s}' \
    "$1" "$2" "$3" "${6:-acme/ra}" "$4" "${5:-$(prs)}"
}

# issue 1 件への問い合わせの応答を置く。$1=番号 $2=題名 $3=状態 $4=その issue 自身の prs の出力 $5..=child の出力
# SUB_MORE=true で subIssues の hasNextPage を真にする
gql() {
  local number="$1" title="$2" state="$3" own="$4"
  shift 4
  local IFS=,
  printf '{"data": {"repository": {"nameWithOwner": "acme/ra", "issue": {"number": %s, "title": "%s", "state": "%s", "closedByPullRequestsReferences": %s, "subIssues": {"nodes": [%s], "pageInfo": {"hasNextPage": %s}}}}}}\n' \
    "$number" "$title" "$state" "$own" "$*" "${SUB_MORE:-false}" > "$EPIC_GQL_DIR/$number.json"
}

# #10 の子が #11 と #12。$1=#11 を閉じた PR（pr の出力。空可） $2=#12 を閉じた PR
tree() {
  gql 10 epic OPEN "$(prs)" \
    "$(child 11 'child a' CLOSED 0 "$(prs ${1:+"$1"})")" \
    "$(child 12 'child b' OPEN 0 "$(prs ${2:+"$2"})")"
}

# ---- 会話ログ -------------------------------------------------------------

# 共通のデータ。$1 に no-r4 を渡すと、issue #10 の区間の行 r4 を置かない
logs() {
  {
    cl_row S11 r1 2026-09-01T00:00:10.000Z main "$RA" 1000000 "gh issue view 11"
    cl_row S11 r2 2026-09-01T00:00:20.000Z main "$RA" 1000000
  } | cl_write_log s11
  cl_row S12 r3 2026-09-01T00:00:30.000Z main "$RA" 1000000 "gh issue view 12" | cl_write_log s12
  if [ "${1:-}" != no-r4 ]; then
    cl_row S10 r4 2026-09-01T00:00:40.000Z main "$RA" 1000000 "gh issue view 10" | cl_write_log s10
  fi
  {
    cl_row SA r5 2026-09-01T00:00:50.000Z feat/a "$RA" 1000000
    cl_row SA r6 2026-09-01T00:01:00.000Z feat/a "$RA" 1000000
  } | cl_write_log sa
  cl_row SB r7 2026-09-01T00:01:10.000Z feat/b "$RA" 1000000 | cl_write_log sb
}

# 「孫を辿る」の状態: #12 の子が #13、main に issue #13 の区間の行 r9、閉じた PR は無い
grandchild() {
  logs
  cl_row S13 r9 2026-09-01T00:01:30.000Z main "$RA" 1000000 "gh issue view 13" | cl_write_log s13
  export EPIC_SUBS="10=2 12=1"
  gql 10 epic OPEN "$(prs)" \
    "$(child 11 'child a' CLOSED 0)" \
    "$(child 12 'child b' OPEN 1)"
  gql 12 'child b' OPEN "$(prs)" "$(child 13 grandchild OPEN 0)"
}

cost() { python3 "$CL" cost "$@" --repo "$RA" --no-drift-check; }
cost_json() { cost "$@" --json; }

# 標準入力の JSON に python の式を当て、偽なら落とす。d が JSON、i は番号から issues の 1 件を引く辞書。
# eval に渡す式は、このファイルの各テストに書いた固定の文字列だけ（外から来る入力は渡さない）
check() {  # $1=式
  python3 -c '
import json, sys
d = json.load(sys.stdin)
near = lambda a, b: abs(a - b) < 1e-9
i = {row["number"]: row for row in d.get("issues", [])}
assert eval(sys.argv[1]), d
' "$1"
}

# 標準出力と標準エラーを分けて受ける。OUT と ERR に入る
run_split() {
  local out="$BATS_TEST_TMPDIR/stdout" err="$BATS_TEST_TMPDIR/stderr"
  status=0
  "$@" > "$out" 2> "$err" || status=$?
  OUT="$(cat "$out")"
  ERR="$(cat "$err")"
}

# ---- cost-ledger-attribution: エピックの合計は行の和集合 -------------------

@test "epic: children closed by separate PRs" {  # #10 が 1.0、#11 が 4.0、#12 が 2.0、合計 7.0。どの issue も割り当てた額と単独の合計が同じ
  logs
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  cost_json 10 | check 'near(d["total_usd"], 7.0) and [i[n]["own_usd"] for n in (10, 11, 12)] == [1.0, 4.0, 2.0] and all(near(r["own_usd"], r["standalone_usd"]) for r in d["issues"]) and near(sum(r["own_usd"] for r in d["issues"]), d["total_usd"])'
}

@test "epic: one PR closing two children is counted once" {  # 合計は 6.0（8.0 ではない）。割り当てた額は 1.0・4.0・1.0、単独の合計は #11 が 4.0、#12 が 3.0
  logs
  tree "$(pr 300 feat/a)" "$(pr 300 feat/a)"
  cost_json 10 | check 'near(d["total_usd"], 6.0) and [i[n]["own_usd"] for n in (10, 11, 12)] == [1.0, 4.0, 1.0] and near(i[11]["standalone_usd"], 4.0) and near(i[12]["standalone_usd"], 3.0)'
}

@test "epic: an interval row on another child's PR branch is counted once" {  # feat/a に #12 の区間の行 r8 → 合計 8.0、#11 が 5.0、#12 が 2.0（単独 3.0）
  logs
  cl_row S12B r8 2026-09-01T00:01:20.000Z feat/a "$RA" 1000000 "gh issue view 12" | cl_write_log s12b
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  cost_json 10 | check 'near(d["total_usd"], 8.0) and near(i[11]["own_usd"], 5.0) and near(i[12]["own_usd"], 2.0) and near(i[12]["standalone_usd"], 3.0)'
}

@test "epic: two PRs with the same head branch go to the smaller issue number" {  # #11 に PR #305、#12 に PR #300（どちらも feat/a）→ feat/a は #11、合計 6.0
  logs
  tree "$(pr 305 feat/a)" "$(pr 300 feat/a)"
  cost_json 10 | check 'near(d["total_usd"], 6.0) and near(i[11]["own_usd"], 4.0) and near(i[12]["own_usd"], 1.0) and i[12]["closing_prs"][0]["counted_in"] == 11 and i[11]["closing_prs"][0]["counted_in"] == 11'
}

@test "epic: reading from the ledger gives the same values" {  # 台帳へ取り込んでから読んでも、合計・割り当てた額・単独の合計は直読みと同じ
  logs
  tree "$(pr 300 feat/a)" "$(pr 300 feat/a)"
  cost_json 10 > "$BATS_TEST_TMPDIR/direct.json"
  export COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
  python3 "$CL" ledger-sync --quiet
  cost_json 10 > "$BATS_TEST_TMPDIR/ledger.json"
  check 'near(d["total_usd"], 6.0)' < "$BATS_TEST_TMPDIR/ledger.json"
  python3 - "$BATS_TEST_TMPDIR/direct.json" "$BATS_TEST_TMPDIR/ledger.json" <<'PY'
import json, sys
a, b = (json.load(open(p)) for p in sys.argv[1:3])
pick = lambda d: (d["total_usd"], [(r["number"], r["own_usd"], r["standalone_usd"]) for r in d["issues"]])
assert pick(a) == pick(b), (pick(a), pick(b))
PY
}

# ---- cost-ledger-cost-command: 子 issue ごとの内訳と合計 --------------------

@test "epic: acceptance: each child's amount and the total are shown" {  # 1 行目は $7.00・子 issue 込み。#10・#11・#12 の行がこの順
  logs
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "${lines[0]}" = 'コスト: $7.00 / ¥1,050 @150 — issue #10 (acme/ra) 帰属: 子 issue 込み' ] || { echo "$output"; return 1; }
  a="$(printf '%s\n' "$output" | grep -nxF '  #10 open $7.00（自身 $1.00） — epic' | cut -d: -f1)"
  b="$(printf '%s\n' "$output" | grep -nxF '    #11 closed $4.00 — child a' | cut -d: -f1)"
  c="$(printf '%s\n' "$output" | grep -nxF '    #12 open $2.00 — child b' | cut -d: -f1)"
  [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] || { echo "$output"; return 1; }
  [[ "$output" == *'  対象: issue #10（acme/ra）と子孫の issue 2 件'* ]]
}

@test "epic: acceptance: the total equals the sum of the children's amounts" {  # r4 を除くと total_usd・children_usd・子の usd の和が 6.0、self_usd は 0.0
  logs no-r4
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  cost_json 10 | check 'near(d["total_usd"], 6.0) and near(i[11]["usd"], 4.0) and near(i[12]["usd"], 2.0) and near(d["total_usd"], i[11]["usd"] + i[12]["usd"]) and near(d["children_usd"], 6.0) and d["self_usd"] == 0.0'
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == 'コスト: $6.00 / '* ]] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qxF '  子 issue の合計: $6.00'
  printf '%s\n' "$output" | grep -qxF '  issue #10 自身: $0.00'
}

@test "epic: acceptance: the epic's own interval is added to the children's total" {  # children_usd 6.0 + self_usd 1.0 = total_usd 7.0。2 行がこの順
  logs
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  cost_json 10 | check 'near(d["children_usd"], 6.0) and near(d["children_usd"], i[11]["usd"] + i[12]["usd"]) and near(d["self_usd"], 1.0) and near(d["total_usd"], 7.0) and near(d["total_usd"], d["children_usd"] + d["self_usd"]) and near(d["total_usd"], sum(r["own_usd"] for r in d["issues"])) and near(d["self_usd"], i[10]["own_usd"]) and near(i[10]["usd"], d["total_usd"])'
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == 'コスト: $7.00 / '* ]] || { echo "$output"; return 1; }
  a="$(printf '%s\n' "$output" | grep -nxF '  子 issue の合計: $6.00' | cut -d: -f1)"
  b="$(printf '%s\n' "$output" | grep -nxF '  issue #10 自身: $1.00' | cut -d: -f1)"
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] || { echo "$output"; return 1; }
}

@test "epic: acceptance: two children referring to the same PR" {  # 合計 6.0。#12 の行に（単独 $3.00、PR #300 は #11 に計上）。JSON の counted_in は 11
  logs
  tree "$(pr 300 feat/a)" "$(pr 300 feat/a)"
  cost_json 10 | check 'near(d["total_usd"], 6.0) and i[12]["closing_prs"] == [{"number": 300, "branch": "feat/a", "usd": 2.0, "counted_in": 11}]'
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qxF '    #12 open $1.00 — child b（単独 $3.00、PR #300 は #11 に計上）' || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qxF '    #11 closed $4.00 — child a'
}

@test "epic: grandchildren are followed" {  # #12 の行に（自身 $1.00）、その直後に #13。1 行目は $5.00
  grandchild
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == 'コスト: $5.00 / '* ]] || { echo "$output"; return 1; }
  a="$(printf '%s\n' "$output" | grep -nxF '    #12 open $2.00（自身 $1.00） — child b' | cut -d: -f1)"
  b="$(printf '%s\n' "$output" | grep -nxF '      #13 open $1.00 — grandchild' | cut -d: -f1)"
  [ -n "$a" ] && [ -n "$b" ] && [ "$b" -eq $((a + 1)) ] || { echo "$output"; return 1; }
}

@test "epic: a cycle stops" {  # #10 の子が #11、#11 の子が #10 → issues は 2 件、GraphQL は 2 回
  logs
  export EPIC_SUBS="10=1 11=1"
  gql 10 epic OPEN "$(prs)" "$(child 11 'child a' CLOSED 1)"
  gql 11 'child a' CLOSED "$(prs)" "$(child 10 epic OPEN 1)"
  run_split cost_json 10
  [ "$status" -eq 0 ] || { echo "$OUT$ERR"; return 1; }
  printf '%s' "$OUT" | check '[r["number"] for r in d["issues"]] == [10, 11]'
  [ "$(gql_calls)" -eq 2 ]
}

@test "epic: a child in another repository is not counted" {  # acme/other#5（子 3 件）は skipped に入り、辿らない。GraphQL は 1 回
  logs
  gql 10 epic OPEN "$(prs)" \
    "$(child 11 'child a' CLOSED 0)" \
    "$(child 5 elsewhere OPEN 3 "$(prs)" acme/other)"
  run_split cost_json 10
  [ "$status" -eq 0 ] || { echo "$OUT$ERR"; return 1; }
  printf '%s' "$OUT" | check '[r["number"] for r in d["issues"]] == [10, 11] and d["skipped"] == [{"repo": "acme/other", "number": 5, "parent": 10}]'
  [ "$(gql_calls)" -eq 1 ]
  run cost 10
  printf '%s\n' "$output" | grep -qxF '  数えていない子 issue: acme/other#5（別のリポジトリ）' || { echo "$output"; return 1; }
}

@test "epic: a failing sub-issue query gives no total" {  # GraphQL だけが失敗 → 終了コード 2、標準出力は空、標準エラーに #10
  logs
  export EPIC_GQL_FAIL=1
  run_split cost 10
  [ "$status" -eq 2 ] || { echo "$status $OUT$ERR"; return 1; }
  [ -z "$OUT" ]
  [[ "$ERR" == *'#10'* ]]
}

@test "epic: more than 100 children gives no total" {  # subIssues の hasNextPage が真 → 終了コード 2、標準出力は空
  logs
  SUB_MORE=true tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  run_split cost 10
  [ "$status" -eq 2 ] || { echo "$status $OUT$ERR"; return 1; }
  [ -z "$OUT" ]
  [[ "$ERR" == *'#10'* ]]
}

@test "epic: more than 100 closing PRs on a child gives no total" {  # 子の closedByPullRequestsReferences の hasNextPage が真 → 終了コード 2
  logs
  gql 10 epic OPEN "$(prs)" "$(child 11 'child a' CLOSED 0 "$(PR_MORE=true prs "$(pr 300 feat/a)")")"
  run_split cost 10
  [ "$status" -eq 2 ] || { echo "$status $OUT$ERR"; return 1; }
  [ -z "$OUT" ]
  [[ "$ERR" == *'#11'* ]]
}

@test "epic: a malformed response gives no total" {  # 子 #11 を閉じた PR の headRefName が空 → 終了コード 2、標準出力は空
  logs
  tree "$(pr 300 '')" "$(pr 301 feat/b)"
  run_split cost 10
  [ "$status" -eq 2 ] || { echo "$status $OUT$ERR"; return 1; }
  [ -z "$OUT" ]
  [[ "$ERR" == *'#11'* ]]
}

@test "epic: deeper than 8 levels gives no total" {  # #10→#11→…→#18 の鎖で #18 がさらに子を持つ → 終了コード 2、GraphQL は 8 回
  logs
  export EPIC_SUBS="10=1"
  local n
  for n in 10 11 12 13 14 15 16 17; do
    gql "$n" "level $n" OPEN "$(prs)" "$(child $((n + 1)) "level $((n + 1))" OPEN 1)"
  done
  gql 18 'level 18' OPEN "$(prs)" "$(child 19 'level 19' OPEN 0)"
  run_split cost 10
  [ "$status" -eq 2 ] || { echo "$status $OUT$ERR"; return 1; }
  [ -z "$OUT" ]
  [[ "$ERR" == *'#18'* ]]
  [ "$(gql_calls)" -eq 8 ]
}

@test "epic: exactly 8 levels is read" {  # #18 が子を持たなければ 9 件を読み切る（GraphQL は 8 回）
  logs
  export EPIC_SUBS="10=1"
  local n
  for n in 10 11 12 13 14 15 16; do
    gql "$n" "level $n" OPEN "$(prs)" "$(child $((n + 1)) "level $((n + 1))" OPEN 1)"
  done
  gql 17 'level 17' OPEN "$(prs)" "$(child 18 'level 18' OPEN 0)"
  run_split cost_json 10
  [ "$status" -eq 0 ] || { echo "$status $OUT$ERR"; return 1; }
  printf '%s' "$OUT" | check 'len(d["issues"]) == 9 and d["issues"][-1]["depth"] == 8'
  [ "$(gql_calls)" -eq 8 ]
}

@test "epic: a long title is cut to 40 characters" {  # 50 文字の題名は先頭 39 文字と …
  logs
  local title="12345678901234567890123456789012345678901234567890"
  gql 10 epic OPEN "$(prs)" "$(child 11 "$title" CLOSED 0)"
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qxF '    #11 closed $2.00 — 123456789012345678901234567890123456789…' || { echo "$output"; return 1; }
  cost_json 10 | check 'i[11]["title"] == "12345678901234567890123456789012345678901234567890"'
}

@test "epic: control characters in a title are shown as spaces" {  # ESC・改行・U+202E は空白 1 つになり、内訳の行は増えない。--json の title は取った値のまま
  logs
  # 題名の中身（JSON の書き方）: x ESC [2Ky 改行 空白 4 つ #99 closed $9.00 — fake U+202E z
  gql 10 epic OPEN "$(prs)" "$(child 11 'x\u001b[2Ky\n    #99 closed $9.00 — fake‮z' CLOSED 0)"
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" != *$'\x1b'* ]] || { echo "ESC が残っている"; return 1; }
  [[ "$output" != *$'\xe2\x80\xae'* ]] || { echo "U+202E が残っている"; return 1; }
  printf '%s\n' "$output" | grep -qxF '    #11 closed $2.00 — x [2Ky #99 closed $9.00 — fake z' || { echo "$output"; return 1; }
  [ "$(printf '%s\n' "$output" | grep -cE '^ +#[0-9]+ (open|closed) ')" -eq 2 ] || { echo "$output"; return 1; }
  cost_json 10 | check 'i[11]["title"] == "x\x1b[2Ky\n    #99 closed $9.00 — fake‮z"'
}

@test "epic: a title is cut after control characters are removed" {  # 先頭のタブ 3 つと 40 文字 → 取り除いたあとは 40 文字なので切らない
  logs
  gql 10 epic OPEN "$(prs)" "$(child 11 '\t\t\t1234567890123456789012345678901234567890' CLOSED 0)"
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | grep -qxF '    #11 closed $2.00 — 1234567890123456789012345678901234567890' || { echo "$output"; return 1; }
}

@test "epic: control characters in a skipped repository name are shown as spaces" {  # 数えていない子 issue の行のリポジトリ名も同じ規則。--json の repo は取った値のまま
  logs
  gql 10 epic OPEN "$(prs)" \
    "$(child 11 'child a' CLOSED 0)" \
    "$(child 5 elsewhere OPEN 0 "$(prs)" 'acme/o\u001b[2Kt\nher')"
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$output" != *$'\x1b'* ]] || { echo "ESC が残っている"; return 1; }
  printf '%s\n' "$output" | grep -qxF '  数えていない子 issue: acme/o [2Kt her#5（別のリポジトリ）' || { echo "$output"; return 1; }
  cost_json 10 | check 'd["skipped"][0]["repo"] == "acme/o\x1b[2Kt\nher"'
}

@test "epic: a continuation line of a response is not counted as an unknown-repository message" {  # cwd が消えたセッションで、応答の 2 行目にだけ gh issue view 11 → リポジトリ不明は 2 件 $2.00（後続行は件数に数えない。issue 11 の表示と同じ件数）
  logs
  tree
  {
    cl_row SU rU 2026-09-01T00:02:00.000Z main /nonexistent/gone 1000000
    cl_row SU rU 2026-09-01T00:02:01.000Z main /nonexistent/gone 1000000 "gh issue view 11" | sed 's/"u-rU"/"u-rU-2"/'
    cl_row SU rV 2026-09-01T00:02:10.000Z main /nonexistent/gone 1000000
  } | cl_write_log su
  cost_json 10 | check 'd["unknown_repo_messages"] == 2 and near(d["unknown_repo_usd"], 2.0) and near(d["total_usd"], 4.0)'
  python3 "$CL" issue 11 --repo "$RA" --json | check 'd["unknown_repo_messages"] == 2 and near(d["unknown_repo_usd"], 2.0)'
  run cost 10
  [[ "$output" == *'  リポジトリ不明: 2 件 $2.00'* ]] || { echo "$output"; return 1; }
}

@test "epic: a PR from a fork is not counted" {  # isCrossRepository が真の PR だけ → closing_prs は空、own_usd は 2.0
  logs
  tree "$(pr 300 feat/a true)" ""
  cost_json 10 | check 'i[11]["closing_prs"] == [] and near(i[11]["own_usd"], 2.0)'
}

# ---- cost-ledger-cost-command: `/cost <番号>` の入力解釈 --------------------

@test "epic: an issue with sub-issues gets the breakdown" {  # 子の数が 2 → 帰属の種別は 子 issue 込み、2 行目以降に子の行
  logs
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "${lines[0]}" == *'帰属: 子 issue 込み' ]] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | tail -n +2 | grep -q '^    #11 '
  printf '%s\n' "$output" | tail -n +2 | grep -q '^    #12 '
}

@test "epic: no sub-issue count in the response falls back to the interval total" {  # 番号だけの応答 → 出力は issue 12 と同じ、GraphQL は閉じた PR の問い合わせの 1 回だけ
  logs
  no_closing_prs 12
  export EPIC_BARE=1
  run cost 12
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "$(python3 "$CL" issue 12 --repo "$RA")" ] || { echo "$output"; return 1; }
  [ "$(gql_calls)" -eq 1 ]
}

# ---- cost-ledger-cost-command: gh と台帳の読み取りの回数 --------------------

@test "epic: two children without grandchildren take 3 gh calls" {  # gh は 3 回（うち GraphQL 1 回）
  logs
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(gh_calls)" -eq 3 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gql_calls)" -eq 1 ]
}

@test "epic: a child with a grandchild takes 4 gh calls" {  # gh は 4 回（うち GraphQL 2 回）
  grandchild
  run cost 10
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$(gh_calls)" -eq 4 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gql_calls)" -eq 2 ]
}

@test "epic: an issue without sub-issues and a PR are unchanged" {  # issue は gh 3 回（うち GraphQL は閉じた PR の 1 回）、PR は 1 回、GraphQL は 0 回。issue の出力は issue 12 と同じ
  logs
  no_closing_prs 12
  run cost 12
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "$(python3 "$CL" issue 12 --repo "$RA")" ] || { echo "$output"; return 1; }
  [ "$(gh_calls)" -eq 3 ] || { cat "$EPIC_GH_LOG"; return 1; }
  : > "$EPIC_GH_LOG"
  export EPIC_PR=300 EPIC_PR_HEAD=feat/a
  run cost 300
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "${lines[0]}" = 'コスト: $2.00 / ¥300 @150 — PR #300 (feat/a) 帰属: ブランチ' ] || { echo "$output"; return 1; }
  [ "$(gh_calls)" -eq 1 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gql_calls)" -eq 0 ]
}

@test "epic: the ledger is appended to once and a second run changes nothing" {  # 2 回続けて実行しても台帳の行数は 1 回目のあとから増えず、結果も同じ
  logs
  tree "$(pr 300 feat/a)" "$(pr 300 feat/a)"
  export COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger-home/cost-ledger.jsonl"
  cost_json 10 > "$BATS_TEST_TMPDIR/first.json"
  first="$(wc -l < "$COST_LEDGER_PATH" | tr -d ' ')"
  [ "$first" -eq 7 ] || { echo "$first"; return 1; }
  cost_json 10 > "$BATS_TEST_TMPDIR/second.json"
  [ "$(wc -l < "$COST_LEDGER_PATH" | tr -d ' ')" -eq "$first" ]
  cmp "$BATS_TEST_TMPDIR/first.json" "$BATS_TEST_TMPDIR/second.json"
  check 'near(d["total_usd"], 6.0)' < "$BATS_TEST_TMPDIR/second.json"
}

# ---- cost-ledger-timeline: 子 issue を持つ issue に積む行は区間だけの累計 ----

@test "epic: timeline for an issue with sub-issues stacks the interval total only" {  # 金額は $1.00 (+1.00)、gh は 0 回、1 行目は issue 10 の 1 行目と一致
  logs
  tree "$(pr 300 feat/a)" ""
  : > "$BATS_TEST_TMPDIR/in.md"
  python3 "$CL" timeline --issue 10 --repo "$RA" --trigger "issue コメント" --at "$FAR" \
    < "$BATS_TEST_TMPDIR/in.md" > "$BATS_TEST_TMPDIR/out.md"
  row="$(grep '^| ' "$BATS_TEST_TMPDIR/out.md" | grep -F 'issue コメント')"
  [[ "$row" == *'| $1.00 (+1.00) |'* ]] || { cat "$BATS_TEST_TMPDIR/out.md"; return 1; }
  [ "$(gh_calls)" -eq 0 ]
  [ "$(head -n 1 "$BATS_TEST_TMPDIR/out.md")" = "$(python3 "$CL" issue 10 --repo "$RA" | head -n 1)" ]
}
