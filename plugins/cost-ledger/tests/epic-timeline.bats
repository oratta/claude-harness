#!/usr/bin/env bats
#
# spec: cost-ledger-timeline（子 issue を持つ issue に積む行は子 issue の分を含む / `gh` の呼び出し回数）
#
# エピック（子 issue を持つ issue）のコメントに積む行が、子 issue と子 PR の分を含むことを固定する。
#   - timeline（cost_ledger.py）: --child-issue / --child-pr を受けて、/cost <番号> の 1 行目と同じ額を積む
#   - hook（gate-report.sh → gate_report.py）: 子を持つ issue だけ子孫を GraphQL で辿って timeline に渡す。
#     子を持たない issue と PR は、gh の回数も timeline の引数も変えない
# 実物には触れない: gh は PATH の先頭の偽物、会話ログは合成、書き込みは一時ディレクトリのファイルへ。
#
# 共通のデータ（リポジトリ acme/ra。どの行も haiku の input_tokens=1000000 で $1.00）:
#   S11: r1 main / r2 main（issue #11 の区間）  S12: r3 main（#12 の区間）  S10: r4 main（#10 の区間）
#   SA : r5 feat/a / r6 feat/a   SB: r7 feat/b   S12B: r8 feat/a（#12 の区間の行が #11 の PR のブランチ上にある）
# gh は #10 の子が #11（PR #300 feat/a）と #12（PR #301 feat/b）だと答える。合計は $8.00。

load helper

setup() {
  export LC_ALL=C.UTF-8 TZ=UTC
  cl_setup
  FAR=1900000000
  RA="$BATS_TEST_TMPDIR/ra"
  cl_init_repo "$RA" acme/ra
  export EPIC_GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  export EPIC_GQL_DIR="$BATS_TEST_TMPDIR/gql"
  export EPIC_SUBS="10=2"
  export EPIC_GQL_FAIL=""
  mkdir -p "$EPIC_GQL_DIR"
  : > "$EPIC_GH_LOG"
  fake_gh
}

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
    */pulls/*) exit 1 ;;
    */issues/*)
      n="${arg##*/}"; total=0
      for kv in $EPIC_SUBS; do [ "${kv%%=*}" = "$n" ] && total="${kv#*=}"; done
      echo "$n $total"; exit 0 ;;
  esac
done
exit 1
EOF
}

gh_calls() { wc -l < "$EPIC_GH_LOG" | tr -d ' '; }

pr() {
  printf '{"number": %s, "headRefName": "%s", "isCrossRepository": %s, "baseRepository": {"nameWithOwner": "%s"}}' \
    "$1" "$2" "${3:-false}" "${4:-acme/ra}"
}
prs() {
  local IFS=,
  printf '{"nodes": [%s], "pageInfo": {"hasNextPage": %s}}' "$*" "${PR_MORE:-false}"
}
child() {  # $1=番号 $2=題名 $3=状態 $4=子の数 $5=prs の出力 $6=リポジトリ
  printf '{"number": %s, "title": "%s", "state": "%s", "repository": {"nameWithOwner": "%s"}, "subIssuesSummary": {"total": %s}, "closedByPullRequestsReferences": %s}' \
    "$1" "$2" "$3" "${6:-acme/ra}" "$4" "${5:-$(prs)}"
}
gql() {  # $1=番号 $2=題名 $3=状態 $4=自身の prs $5..=child
  local number="$1" title="$2" state="$3" own="$4"
  shift 4
  local IFS=,
  printf '{"data": {"repository": {"nameWithOwner": "acme/ra", "issue": {"number": %s, "title": "%s", "state": "%s", "closedByPullRequestsReferences": %s, "subIssues": {"nodes": [%s], "pageInfo": {"hasNextPage": %s}}}}}}\n' \
    "$number" "$title" "$state" "$own" "$*" "${SUB_MORE:-false}" > "$EPIC_GQL_DIR/$number.json"
}
tree() {  # #10 の子が #11 と #12。$1=#11 を閉じた PR $2=#12 を閉じた PR
  gql 10 epic OPEN "$(prs)" \
    "$(child 11 'child a' CLOSED 0 "$(prs ${1:+"$1"})")" \
    "$(child 12 'child b' OPEN 0 "$(prs ${2:+"$2"})")"
}

logs() {
  {
    cl_row S11 r1 2026-09-01T00:00:10.000Z main "$RA" 1000000 "gh issue view 11"
    cl_row S11 r2 2026-09-01T00:00:20.000Z main "$RA" 1000000
  } | cl_write_log s11
  cl_row S12 r3 2026-09-01T00:00:30.000Z main "$RA" 1000000 "gh issue view 12" | cl_write_log s12
  cl_row S10 r4 2026-09-01T00:00:40.000Z main "$RA" 1000000 "gh issue view 10" | cl_write_log s10
  {
    cl_row SA r5 2026-09-01T00:00:50.000Z feat/a "$RA" 1000000
    cl_row SA r6 2026-09-01T00:01:00.000Z feat/a "$RA" 1000000
  } | cl_write_log sa
  cl_row SB r7 2026-09-01T00:01:10.000Z feat/b "$RA" 1000000 | cl_write_log sb
  cl_row S12B r8 2026-09-01T00:01:20.000Z feat/a "$RA" 1000000 "gh issue view 12" | cl_write_log s12b
}

timeline() {  # 引数を timeline にそのまま渡す。標準入力は空、時刻は十分あと
  : > "$BATS_TEST_TMPDIR/in.md"
  python3 "$CL" timeline --issue 10 --repo "$RA" --at "$FAR" "$@" \
    < "$BATS_TEST_TMPDIR/in.md"
}

# 表の行（見出しと区切りを除く）
rows_of() { grep '^| ' | grep -v '^| 時刻\|^|---'; }

# ---- timeline: 子 issue 込みの額 -------------------------------------------

@test "epic-timeline: acceptance: the total row equals the first line of cost for the epic" {  # 合計の行の額は cost 10 の 1 行目の額と同じ $8.00。1 行目は文字列まで一致
  logs
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  run timeline --child-issue 11 --child-issue 12 --child-pr 300:feat/a --child-pr 301:feat/b \
    --closing-pr 300:feat/a --closing-pr 301:feat/b --trigger "issue クローズ"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  echo "$output" > "$BATS_TEST_TMPDIR/out.md"
  total_row="$(rows_of < "$BATS_TEST_TMPDIR/out.md" | grep -F '合計（')"
  [[ "$total_row" == *'| $8.00 '* ]] || { echo "$output"; return 1; }
  cost_first="$(python3 "$CL" cost 10 --repo "$RA" --no-drift-check | head -n 1)"
  [[ "$cost_first" == 'コスト: $8.00 / '* ]]
  [ "$(head -n 1 "$BATS_TEST_TMPDIR/out.md")" = "$cost_first" ]
  [ "$(rows_of < "$BATS_TEST_TMPDIR/out.md" | wc -l | tr -d ' ')" -eq 2 ]
}

@test "epic-timeline: the milestone row is also child-inclusive and has no total row without --closing-pr" {  # 行の金額は $8.00、1 行目の帰属の種別は 子 issue 込み、行は 1 本
  logs
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  run timeline --child-issue 11 --child-issue 12 --child-pr 300:feat/a --child-pr 301:feat/b \
    --trigger "issue コメント"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [[ "$(printf '%s\n' "$output" | head -n 1)" == *'帰属: 子 issue 込み' ]]
  [ "$(printf '%s\n' "$output" | rows_of | wc -l | tr -d ' ')" -eq 1 ]
  printf '%s\n' "$output" | rows_of | grep -qF '| $8.00 ($8.00) |' || printf '%s\n' "$output" | rows_of | grep -qF '| $8.00 (?) |' || printf '%s\n' "$output" | rows_of | grep -qF '| $8.00 (+8.00) |'
}

@test "epic-timeline: the total row's trigger shows counts, not each PR's amount" {  # 合計（子 issue 2 件込み: PR 2 件 $4.00 + PR 外 $4.00）
  logs
  run timeline --child-issue 11 --child-issue 12 --child-pr 300:feat/a --child-pr 301:feat/b \
    --closing-pr 300:feat/a --closing-pr 301:feat/b --trigger "issue クローズ"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | rows_of | grep -qF '| 合計（子 issue 2 件込み: PR 2 件 $4.00 + PR 外 $4.00） |' || { echo "$output"; return 1; }
  [[ "$output" != *'#300 $'* ]]
}

@test "epic-timeline: the same PR given several times is counted once" {  # feat/a を --child-pr と --closing-pr で 2 回ずつ渡しても PR 1 件・$3.00
  logs
  run timeline --child-issue 11 --child-issue 12 --child-pr 300:feat/a --child-pr 305:feat/a \
    --closing-pr 300:feat/a --trigger "issue クローズ"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | rows_of | grep -qF '合計（子 issue 2 件込み: PR 1 件 $3.00 + PR 外 $4.00）' || { echo "$output"; return 1; }
  printf '%s\n' "$output" | rows_of | grep -F '合計（' | grep -qF '| $7.00 ' || { echo "$output"; return 1; }
}

@test "epic-timeline: an interval row on a child's PR branch is counted once" {  # r8 は #12 の区間かつ feat/a の行。feat/b は渡さないので r7 は入らず、合計は $7.00（二重に数えると $8.00）
  logs
  run timeline --child-issue 11 --child-issue 12 --child-pr 300:feat/a --trigger "issue コメント"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | rows_of | grep -qF '| $7.00 ' || { echo "$output"; return 1; }
}

@test "epic-timeline: without --child-issue the cumulative is the interval total only" {  # --child-pr だけでは何も変わらない。区間 $1.00
  logs
  run timeline --child-pr 300:feat/a --trigger "issue コメント"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | rows_of | grep -qF '| $1.00 ' || { echo "$output"; return 1; }
  [[ "$(printf '%s\n' "$output" | head -n 1)" == *'帰属: 区間' ]]
}

@test "epic-timeline: the cut time applies to children and PR rows" {  # r5 と r6 より前の時刻で切ると feat/a の行が数えられない。区間 r1〜r4 の $4.00 だけ
  logs
  : > "$BATS_TEST_TMPDIR/in.md"
  run python3 "$CL" timeline --issue 10 --repo "$RA" --at 1788220845 --child-issue 11 --child-issue 12 \
    --child-pr 300:feat/a --trigger "issue コメント" < "$BATS_TEST_TMPDIR/in.md"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  printf '%s\n' "$output" | rows_of | grep -qF '| $4.00 ' || { echo "$output"; return 1; }
}

@test "epic-timeline: bad arguments give exit code 2 and no output" {  # --pr と --child-issue、番号でない値、0、形の崩れた --child-pr
  logs
  for bad in "--pr 300 --branch feat/a --child-issue 11" "--issue 10 --child-issue abc" \
             "--issue 10 --child-issue 0" "--issue 10 --child-issue 11 --child-pr 300" \
             "--pr 300 --branch feat/a --child-pr 300:feat/a"; do
    : > "$BATS_TEST_TMPDIR/in.md"
    # shellcheck disable=SC2086
    run python3 "$CL" timeline $bad --repo "$RA" --at "$FAR" --trigger x < "$BATS_TEST_TMPDIR/in.md"
    [ "$status" -eq 2 ] || { echo "$bad -> $status: $output"; return 1; }
    [ -z "$(python3 "$CL" timeline $bad --repo "$RA" --at "$FAR" --trigger x 2>/dev/null < "$BATS_TEST_TMPDIR/in.md")" ]
  done
}

@test "epic-timeline: timeline does not call gh" {  # 子込みの行を作っても gh は 0 回
  logs
  timeline --child-issue 11 --child-issue 12 --child-pr 300:feat/a --closing-pr 300:feat/a \
    --trigger "issue クローズ" > /dev/null
  [ "$(gh_calls)" -eq 0 ]
}

# ---- hook: 子孫の問い合わせと gh の回数 ------------------------------------

hook_setup() {
  REAL_PYTHON="$(command -v python3)"
  WORK="$BATS_TEST_TMPDIR/hook"
  mkdir -p "$WORK/scripts" "$WORK/bin" "$WORK/tmp"
  for f in gate-report.sh gate_report.py write_allow.py; do
    command cp "$PLUGIN_DIR/scripts/$f" "$WORK/scripts/$f"
  done
  printf '#!%s\nimport os, sys\nopen(os.environ["TL_LOG"], "a").write(" ".join(sys.argv[1:]) + "\\n")\nos.execv(sys.executable, [sys.executable, os.environ["REAL_CL"]] + sys.argv[1:])\n' \
    "$REAL_PYTHON" > "$WORK/scripts/cost_ledger.py"
  export TL_LOG="$WORK/timeline.log" REAL_CL="$CL" TMPDIR="$WORK/tmp"
  : > "$TL_LOG"
  export COST_LEDGER_HOOK_FOREGROUND=1
  unset COST_LEDGER_GATE_REPORT
  export HOME="$WORK/home"
  export COST_LEDGER_WRITE_REPOS_FILE="$WORK/write-repos"
  echo "acme/ra" > "$COST_LEDGER_WRITE_REPOS_FILE"
  chmod 600 "$COST_LEDGER_WRITE_REPOS_FILE"
  export EPIC_STATE=open EPIC_BODY="$WORK/body.txt"
  # issue の問い合わせ（resolve）は子の数と状態を返す。コメント一覧は空。書き込みは本文をファイルへ
  command rm -f "$BATS_TEST_TMPDIR/bin/gh"
  cl_fake_gh <<'EOF'
printf '%s\n' "$*" >> "$EPIC_GH_LOG"
case "$*" in
  *"-X POST"*|*"-X PATCH"*) cat > "$EPIC_BODY"; echo '{}'; exit 0 ;;
esac
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
    */comments*) exit 0 ;;
    */issues/*)
      n="${arg##*/}"; total=0; extra=""
      for kv in $EPIC_SUBS; do [ "${kv%%=*}" = "$n" ] && total="${kv#*=}"; done
      case " $EPIC_PRS " in *" $n "*) extra=',"pull_request":{"url":"x"}' ;; esac
      printf '{"number":%s,"state":"%s","repository_url":"https://api.github.com/repos/acme/ra","sub_issues_summary":{"total":%s,"completed":0,"percent_completed":0}%s}\n' \
        "$n" "$EPIC_STATE" "$total" "$extra"
      exit 0 ;;
  esac
done
exit 1
EOF
  export EPIC_PRS=""
}

run_hook() {  # $1=コマンド
  python3 -c 'import json,sys; print(json.dumps({"tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' \
    "$1" "$RA" > "$WORK/payload.json"
  bash "$WORK/scripts/gate-report.sh" < "$WORK/payload.json"
}

gql_calls() { grep -c '^api graphql' "$EPIC_GH_LOG" || true; }
tl_args() { cat "$TL_LOG"; }

@test "epic-timeline: hook: acceptance: an issue without sub-issues keeps its gh count and timeline arguments" {  # コメント 3 回・クローズ 4 回（GraphQL は閉じた PR の 1 回）。--child-* は渡らない
  hook_setup
  logs
  EPIC_SUBS="12=0"
  run_hook "gh issue comment 12 --body x"
  [ "$(gh_calls)" -eq 3 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gql_calls)" -eq 0 ]
  [[ "$(tl_args)" != *--child* ]]
  : > "$EPIC_GH_LOG"; : > "$TL_LOG"
  gql 12 solo CLOSED "$(prs "$(pr 300 feat/a)")"
  EPIC_STATE=closed
  # 子を持たない issue を閉じる問い合わせは closedByPullRequestsReferences だけ（subIssues は読まない）
  printf '{"data":{"repository":{"issue":{"closedByPullRequestsReferences":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}}}' > "$EPIC_GQL_DIR/12.json"
  run_hook "gh issue close 12"
  [ "$(gh_calls)" -eq 4 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gql_calls)" -eq 1 ]
  [[ "$(tl_args)" != *--child* ]]
  [[ "$(tl_args)" == *"--issue 12 --trigger issue クローズ --at "* ]]
}

@test "epic-timeline: hook: acceptance: a PR keeps its gh count and timeline arguments" {  # PR へのコメントは gh 3 回。--child-* は渡らない
  hook_setup
  logs
  command rm -f "$BATS_TEST_TMPDIR/bin/gh"
  cl_fake_gh <<'EOF'
printf '%s\n' "$*" >> "$EPIC_GH_LOG"
case "$*" in
  *"-X POST"*|*"-X PATCH"*) cat > "$EPIC_BODY"; echo '{}'; exit 0 ;;
esac
for arg in "$@"; do
  case "$arg" in
    */comments*) exit 0 ;;
    */pulls/*) printf '{"number":300,"state":"open","draft":false,"merged":false,"head":{"ref":"feat/a"},"base":{"repo":{"full_name":"acme/ra"}}}\n'; exit 0 ;;
  esac
done
exit 1
EOF
  run_hook "gh pr comment 300 --body x"
  [ "$(gh_calls)" -eq 3 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gql_calls)" -eq 0 ]
  [[ "$(tl_args)" == *"--pr 300 --branch feat/a"* ]]
  [[ "$(tl_args)" != *--child* ]]
}

@test "epic-timeline: hook: an epic takes 4 gh calls for a comment and passes its descendants" {  # 子 2 件: gh 4 回（GraphQL 1 回）。--child-issue 11・12、--child-pr 2 つ、--closing-pr は無し。本文は $8.00 の子 issue 込み
  hook_setup
  logs
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  run_hook "gh issue comment 10 --body x"
  [ "$(gh_calls)" -eq 4 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gql_calls)" -eq 1 ]
  a="$(tl_args)"
  [[ "$a" == *"--issue 10 "* && "$a" == *"--child-issue 11 --child-issue 12 --child-pr 300:feat/a --child-pr 301:feat/b"* && "$a" != *--closing-pr* ]] || { echo "$a"; return 1; }
  [ -s "$EPIC_BODY" ]
  head -n 1 "$EPIC_BODY" | python3 -c 'import json,sys; b=json.loads(sys.stdin.read())["body"]; assert "帰属: 子 issue 込み" in b.splitlines()[0], b'
}

@test "epic-timeline: hook: closing an epic takes 4 gh calls and stacks the total row" {  # gh 4 回（閉じた PR だけの問い合わせは足さない）。--closing-pr は子孫の問い合わせの PR。合計の行が付く
  hook_setup
  logs
  EPIC_STATE=closed
  tree "$(pr 300 feat/a)" "$(pr 301 feat/b)"
  run_hook "gh issue close 10"
  [ "$(gh_calls)" -eq 4 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gql_calls)" -eq 1 ]
  a="$(tl_args)"
  [[ "$a" == *"--closing-pr 300:feat/a --closing-pr 301:feat/b"* && "$a" == *"--child-issue 11"* ]] || { echo "$a"; return 1; }
  python3 -c 'import json,sys; b=json.load(open(sys.argv[1]))["body"]; assert "合計（子 issue 2 件込み: PR 2 件 $4.00 + PR 外 $4.00）" in b, b' "$EPIC_BODY"
}

@test "epic-timeline: hook: the epic's own closing PR comes from the same response" {  # エピック自身を閉じた PR #310 も --closing-pr と --child-pr に入る
  hook_setup
  logs
  EPIC_STATE=closed
  gql 10 epic CLOSED "$(prs "$(pr 310 feat/e)")" \
    "$(child 11 'child a' CLOSED 0 "$(prs "$(pr 300 feat/a)")")" \
    "$(child 12 'child b' OPEN 0)"
  run_hook "gh issue close 10"
  a="$(tl_args)"
  [[ "$a" == *"--closing-pr 300:feat/a --closing-pr 310:feat/e"* ]] || { echo "$a"; return 1; }
}

@test "epic-timeline: hook: a child with a grandchild takes 5 gh calls" {  # #12 が孫 #13 を持つ → GraphQL 2 回、gh 5 回。--child-issue に 13 も入る
  hook_setup
  logs
  EPIC_SUBS="10=2 12=1"
  gql 10 epic OPEN "$(prs)" "$(child 11 'child a' CLOSED 0)" "$(child 12 'child b' OPEN 1)"
  gql 12 'child b' OPEN "$(prs)" "$(child 13 grandchild OPEN 0)"
  run_hook "gh issue comment 10 --body x"
  [ "$(gh_calls)" -eq 5 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gql_calls)" -eq 2 ]
  [[ "$(tl_args)" == *"--child-issue 11 --child-issue 12 --child-issue 13"* ]]
}

@test "epic-timeline: hook: more than 5 sub-issue queries is a failure" {  # 子 5 件がどれも子を持つ → GraphQL は 5 回で止まり gh 8 回。きっかけの最後は 子 issue 照会失敗、--child-* は無し
  hook_setup
  logs
  EPIC_SUBS="10=5 11=1 12=1 13=1 14=1 15=1"
  gql 10 epic OPEN "$(prs)" "$(child 11 a OPEN 1)" "$(child 12 b OPEN 1)" "$(child 13 c OPEN 1)" \
    "$(child 14 d OPEN 1)" "$(child 15 e OPEN 1)"
  for n in 11 12 13 14 15; do gql "$n" x OPEN "$(prs)" "$(child 2$n y OPEN 0)"; done
  run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 5 ] || { cat "$EPIC_GH_LOG"; return 1; }
  [ "$(gh_calls)" -eq 8 ]
  a="$(tl_args)"
  [[ "$a" != *--child* && "$a" == *"--trigger issue コメント+子 issue 照会失敗 "* ]] || { echo "$a"; return 1; }
}

@test "epic-timeline: hook: a failing query stacks the old row with a failure mark and no total row" {  # 閉じる回: きっかけ issue クローズ+子 issue 照会失敗、--closing-pr も --child-* も無し、gh 4 回、書き込みは 1 本
  hook_setup
  logs
  EPIC_STATE=closed EPIC_GQL_FAIL=1
  run_hook "gh issue close 10"
  a="$(tl_args)"
  [[ "$a" == *"--trigger issue クローズ+子 issue 照会失敗 "* && "$a" != *--child* && "$a" != *--closing-pr* ]] || { echo "$a"; return 1; }
  [ "$(gh_calls)" -eq 4 ]
  python3 -c 'import json,sys; b=json.load(open(sys.argv[1]))["body"]; assert "合計（" not in b and "子 issue 照会失敗" in b, b' "$EPIC_BODY"
}

@test "epic-timeline: hook: a malformed child, more than 100 children, a chain longer than the query limit: all fail" {  # 子の number が文字列 / subIssues の hasNextPage が真 / 鎖が 5 回の上限を超える → 一部だけ渡さず失敗の印（8 段の深さの上限は 5 回の上限より先には効かないので、fetch_epic_tree と同じ値を持つだけ）
  hook_setup
  logs
  printf '{"data":{"repository":{"nameWithOwner":"acme/ra","issue":{"number":10,"title":"e","state":"OPEN","closedByPullRequestsReferences":%s,"subIssues":{"nodes":[{"number":"11","title":"a","state":"OPEN","repository":{"nameWithOwner":"acme/ra"},"subIssuesSummary":{"total":0},"closedByPullRequestsReferences":%s}],"pageInfo":{"hasNextPage":false}}}}}}\n' \
    "$(prs)" "$(prs)" > "$EPIC_GQL_DIR/10.json"
  run_hook "gh issue comment 10 --body x"
  [[ "$(tl_args)" != *--child* && "$(tl_args)" == *"+子 issue 照会失敗 "* ]] || { tl_args; return 1; }
  : > "$TL_LOG"
  SUB_MORE=true tree "$(pr 300 feat/a)" ""
  run_hook "gh issue comment 10 --body x"
  [[ "$(tl_args)" != *--child* && "$(tl_args)" == *"+子 issue 照会失敗 "* ]] || { tl_args; return 1; }
  : > "$TL_LOG"
  # #10→#11→…→#18 の鎖。5 回の上限が先に効く
  EPIC_SUBS="10=1"
  for n in 10 11 12 13 14 15 16 17 18; do
    EPIC_SUBS="$EPIC_SUBS $n=1"
    gql "$n" "n$n" OPEN "$(prs)" "$(child $((n + 1)) "n$((n + 1))" OPEN 1)"
  done
  run_hook "gh issue comment 10 --body x"
  [[ "$(tl_args)" != *--child* && "$(tl_args)" == *"+子 issue 照会失敗 "* ]] || { tl_args; return 1; }
}

@test "epic-timeline: hook: a child in another repository and a fork's PR are not passed" {  # 別のリポジトリの子 #99 と isCrossRepository の PR は --child-issue / --child-pr に入らない
  hook_setup
  logs
  gql 10 epic OPEN "$(prs)" \
    "$(child 11 'child a' CLOSED 0 "$(prs "$(pr 300 feat/a)" "$(pr 302 feat/fork true)" "$(pr 303 feat/o false acme/other)")")" \
    "$(child 99 'other repo' OPEN 3 "$(prs "$(pr 304 feat/x)")" acme/other)"
  run_hook "gh issue comment 10 --body x"
  a="$(tl_args)"
  [[ "$a" == *"--child-issue 11 --child-pr 300:feat/a "* && "$a" != *"--child-issue 99"* && "$a" != *feat/fork* && "$a" != *feat/o* && "$a" != *feat/x* ]] || { echo "$a"; return 1; }
  [ "$(gql_calls)" -eq 1 ]
}

@test "epic-timeline: hook: a PR number given to gh issue comment asks nothing about descendants" {  # PR #300 に gh issue comment → 子孫の問い合わせは 0 回
  hook_setup
  logs
  EPIC_SUBS="300=4"
  EPIC_PRS="300"
  tree "" ""
  command rm -f "$BATS_TEST_TMPDIR/bin/gh"
  cl_fake_gh <<'EOF'
printf '%s\n' "$*" >> "$EPIC_GH_LOG"
case "$*" in
  *"-X POST"*|*"-X PATCH"*) cat > "$EPIC_BODY"; echo '{}'; exit 0 ;;
esac
for arg in "$@"; do
  case "$arg" in
    */comments*) exit 0 ;;
    */pulls/*) printf '{"number":300,"state":"open","draft":false,"merged":false,"head":{"ref":"feat/a"},"base":{"repo":{"full_name":"acme/ra"}}}\n'; exit 0 ;;
    */issues/*) printf '{"number":300,"state":"open","repository_url":"https://api.github.com/repos/acme/ra","pull_request":{"url":"x"},"sub_issues_summary":{"total":4}}\n'; exit 0 ;;
  esac
done
exit 1
EOF
  run_hook "gh issue comment 300 --body x"
  [ "$(gql_calls)" -eq 0 ]
  [[ "$(tl_args)" == *"--pr 300 --branch feat/a"* && "$(tl_args)" != *--child* ]]
}

@test "epic-timeline: a sub_issues_summary that is not a positive integer means no descendants" {  # total が 0・文字列・null・欠落・真偽値のどれでも GraphQL は 0 回
  hook_setup
  logs
  for v in 0 '"3"' null true; do
    : > "$EPIC_GH_LOG"; : > "$TL_LOG"
    command rm -f "$BATS_TEST_TMPDIR/bin/gh"
    V="$v" cl_fake_gh <<EOF
printf '%s\n' "\$*" >> "\$EPIC_GH_LOG"
case "\$*" in
  *"-X POST"*|*"-X PATCH"*) cat > "\$EPIC_BODY"; echo '{}'; exit 0 ;;
esac
for arg in "\$@"; do
  case "\$arg" in
    */comments*) exit 0 ;;
    */issues/*) printf '{"number":10,"state":"open","repository_url":"https://api.github.com/repos/acme/ra","sub_issues_summary":{"total":$v}}\n'; exit 0 ;;
  esac
done
exit 1
EOF
    run_hook "gh issue comment 10 --body x"
    [ "$(gql_calls)" -eq 0 ] || { echo "total=$v"; cat "$EPIC_GH_LOG"; return 1; }
    [ "$(gh_calls)" -eq 3 ]
    [[ "$(tl_args)" != *--child* ]]
  done
}

# ---- hook の epic_tree() と cost の fetch_epic_tree() が同じ集合を返す ----------

@test "epic-timeline: epic_tree and fetch_epic_tree return the same descendants and PRs" {  # 孫・別リポジトリの子・fork の PR・同じブランチの PR 2 件を含む応答で、子孫の集合と PR の集合が一致
  logs
  EPIC_SUBS="10=3 12=1"
  gql 10 epic OPEN "$(prs "$(pr 310 feat/e)")" \
    "$(child 11 'child a' CLOSED 0 "$(prs "$(pr 305 feat/a)" "$(pr 302 feat/fork true)")")" \
    "$(child 12 'child b' OPEN 1 "$(prs "$(pr 300 feat/a)")")" \
    "$(child 99 'other repo' OPEN 2 "$(prs "$(pr 304 feat/x)")" acme/other)"
  gql 12 'child b' OPEN "$(prs)" "$(child 13 grandchild OPEN 0 "$(prs "$(pr 320 feat/g)" "$(pr 321 feat/o false acme/other)")")"
  python3 - "$PLUGIN_DIR/scripts" "$EPIC_GQL_DIR" <<'PY'
import json, os, subprocess, sys
sys.path.insert(0, sys.argv[1])
import cost_ledger, gate_report
gql_dir = sys.argv[2]

def answer(args):
    number = next(a.split("=", 1)[1] for a in args if a.startswith("number="))
    return open(os.path.join(gql_dir, number + ".json"), encoding="utf-8").read()

cost_ledger._gh = lambda where, *args: answer(args)
gate_report.gh_api = lambda args, **kw: subprocess.CompletedProcess(args, 0, answer(args), "")
issues, _skipped = cost_ledger.fetch_epic_tree("/x", 10)
want_issues = sorted(row["number"] for row in issues[1:])
best = {}
for row in issues:
    for pr, head in row["prs"]:
        best[head] = min(pr, best.get(head, pr))
want_prs = sorted((pr, head) for head, pr in best.items())
got_issues, got_prs = gate_report.epic_tree("acme/ra", 10)
assert got_issues == want_issues, (got_issues, want_issues)
assert got_prs == want_prs, (got_prs, want_prs)
assert got_issues == [11, 12, 13] and (300, "feat/a") in got_prs and (310, "feat/e") in got_prs, got_issues
print("ok")
PY
}
