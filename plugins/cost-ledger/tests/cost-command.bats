#!/usr/bin/env bats
#
# spec: cost-ledger-cost-command
#
# /cost の入力解釈（番号が PR か issue か・番号なしの既定動作）と、出力の 1 行目の固定書式を
# 固定する。番号の判別は GitHub への問い合わせなので、テストは gh を PATH 上で差し替えて
# ネットワークから切り離す。

load helper

setup() {
  cl_setup
  cl_materialize
  # fixture のブランチを実在の repo-a 側にも作る（番号なしの既定動作で読む）
  git -C "$REPO_A" checkout -q -b oratta/sample-feature
}

# 番号 271 だけを PR として答える gh。ヘッドブランチは fixture のブランチ。
fake_gh_pr_271() {
  cl_fake_gh <<'EOF'
for arg in "$@"; do
  case "$arg" in
    */pulls/271) echo "oratta/sample-feature"; exit 0 ;;
    */issues/148) echo "148"; exit 0 ;;
  esac
done
exit 1
EOF
}

# どの番号にも「無い」と答える gh。
fake_gh_nothing() {
  cl_fake_gh <<'EOF'
exit 1
EOF
}

@test "cost: a PR number resolves to its head branch" {  # PR 番号を渡すとそのヘッドブランチのコストが返る
  fake_gh_pr_271
  run python3 "$CL" cost 271 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'コスト: $5.80 / ¥870 @150 — PR #271 (oratta/sample-feature) 帰属: ブランチ' ]
  [[ "$output" == *'ブランチ oratta/sample-feature'* ]] || return 1
}

@test "cost: an issue number counts only rows from the running repository" {  # issue 番号は実行した作業ディレクトリのリポジトリの行だけから集計される
  fake_gh_pr_271
  run python3 "$CL" cost 148 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $2.20 / ¥330 @150 — issue #148 (acme/repo-a) 帰属: 区間' ]] || return 1

  run python3 "$CL" cost 148 --repo "$REPO_B"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $1.00 / ¥150 @150 — issue #148 (acme/repo-b) 帰属: 区間' ]] || return 1
}

@test "cost: rows whose repository is unknown are listed separately" {  # リポジトリ不明の行の件数と金額が別立てで出力される
  fake_gh_pr_271
  run python3 "$CL" cost 148 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  # fixture の S4 は cwd が削除済みで、issue 148 へ $1.00 ぶん投稿している
  [[ "$output" == *'リポジトリ不明: 1 件 $1.00'* ]] || return 1
}

@test "cost: an unknown number is reported as not found, never as zero" {  # 存在しない番号で 0 円と表示せず、見つからないと伝える
  fake_gh_nothing
  run python3 "$CL" cost 999999 --repo "$REPO_A"
  [ "$status" -ne 0 ]
  [[ "$output" == *'見つかりません'* ]] || return 1
  [[ "$output" != *'$0.00'* ]] || return 1
}

@test "cost: without a number it reports the current branch" {  # 番号なしで呼ぶと現在のブランチのコストが返る
  fake_gh_nothing
  run python3 "$CL" cost --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'コスト: $5.80 / ¥870 @150 — ブランチ oratta/sample-feature (acme/repo-a) 帰属: ブランチ' ]
}

@test "cost: outside a git repository it says the branch cannot be determined" {  # git リポジトリの外ではブランチが決まらないと伝える
  fake_gh_nothing
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  run python3 "$CL" cost --repo "$BATS_TEST_TMPDIR/plain"
  [ "$status" -ne 0 ]
  [[ "$output" == *'ブランチが決まりません'* ]] || return 1
  [[ "$output" != *'$0.00'* ]] || return 1
}

@test "cost: the first line carries money, rate, target and attribution kind" {  # 出力の 1 行目が固定書式で、金額・換算レート・帰属先・帰属の種別をすべて含む
  fake_gh_pr_271
  local pattern='^コスト: \$[0-9,]+\.[0-9]{2} / ¥[0-9,]+ @[0-9]+ — .+ 帰属: (ブランチ|区間)$'

  run python3 "$CL" cost 271 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" =~ $pattern ]] || return 1
  [[ "${lines[0]}" == *'PR #271'* ]] || return 1

  run python3 "$CL" cost 148 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" =~ $pattern ]] || return 1
  [[ "${lines[0]}" == *'issue #148'* ]] || return 1
  # 内訳は 2 行目以降にあり、1 行目の書式を崩さない
  [[ "${lines[1]}" == *'区間'* ]] || return 1
}

@test "cost: the PR route keeps rows whose worktree was deleted" {  # PR の経路は worktree の削除に強い（ヘッドブランチの行が落ちない）
  fake_gh_pr_271
  # 既に消えた worktree から同じブランチで走った行（$1.00）を足す
  cl_row S9 gone-1 2026-09-01T15:00:00.000Z oratta/sample-feature /nonexistent/deleted-worktree 1000000 \
    | cl_write_log deleted-worktree

  run python3 "$CL" cost 271 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  # $5.80 のままなら、リポジトリを引けない行が黙って落ちている
  [ "${lines[0]}" = 'コスト: $6.80 / ¥1,020 @150 — PR #271 (oratta/sample-feature) 帰属: ブランチ' ]
}

@test "cost: the issue route says the number is an estimate" {  # issue 単位の数字が区間分割による推定だと分かる
  fake_gh_pr_271
  run python3 "$CL" cost 148 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [[ "$output" == *'推定'* ]] || return 1
  [[ "$output" == *'区間'* ]] || return 1
}

@test "cost: the slash command exists and delegates to the script" {  # /cost コマンドのファイルがあり、集計スクリプトの cost サブコマンドを呼ぶ
  [ -f "$PLUGIN_DIR/commands/cost.md" ]
  run grep -q 'cost_ledger.py' "$PLUGIN_DIR/commands/cost.md"
  [ "$status" -eq 0 ]
}

# commands/cost.md の bash ブロックを取り出し、本文の読み込み時に起きる置換（${CLAUDE_PLUGIN_ROOT} と
# ${user_config.LEDGER_PATH} を値へ文字どおり差し替える）を模擬して、bash で実行する。
# 引数: 1 = プラグインのルートの置換値、2 = 台帳パスの置換値。出力は偽の集計スクリプトが書く 2 行
# （受け取った CLAUDE_PLUGIN_OPTION_LEDGER_PATH と、自分のパス）。
run_cost_block() {
  python3 -I - "$PLUGIN_DIR/commands/cost.md" "$1" "$2" > "$BATS_TEST_TMPDIR/block.sh" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
block = re.search(r"```bash\n(.*?)```", text, re.S).group(1)
block = block.replace("${CLAUDE_PLUGIN_ROOT}", sys.argv[2]).replace("${user_config.LEDGER_PATH}", sys.argv[3])
sys.stdout.write(block)
PY
  HOME="$BATS_TEST_TMPDIR/nohome" run /bin/bash "$BATS_TEST_TMPDIR/block.sh"
}

# root の下に、受け取った値と自分のパスを 1 行ずつ出す偽の cost_ledger.py を置く
make_fake_root() {
  mkdir -p "$1/scripts"
  cat > "$1/scripts/cost_ledger.py" <<'PY'
import os, sys
print("LEDGER=" + os.environ.get("CLAUDE_PLUGIN_OPTION_LEDGER_PATH", "<unset>"))
print("SELF=" + os.path.abspath(__file__))
PY
}

@test "cost: the command reads both substituted values through quoted here-documents" {  # 置換値は引用した here-document で読む
  local md="$PLUGIN_DIR/commands/cost.md"
  run grep -n -e "LEDGER_PATH_EOF" -e "COST_LEDGER_PLUGIN_ROOT" "$md"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 4 ]
  grep -q "<<'LEDGER_PATH_EOF'" "$md" || return 1
  grep -q "<<'COST_LEDGER_PLUGIN_ROOT'" "$md" || return 1
  run grep -n -e "LEDGER_PATH='" -e 'plugin_root="' "$md"
  [ "$status" -eq 1 ]
}

@test "cost: a ledger path with an even number of single quotes reaches the script as is" {  # ' が偶数個のパスも設定どおり渡る
  make_fake_root "$BATS_TEST_TMPDIR/root"
  run_cost_block "$BATS_TEST_TMPDIR/root" "/x/'b'/ledger.jsonl"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "LEDGER=/x/'b'/ledger.jsonl" ]
  [ ! -e /x/b ]
}

@test "cost: ledger paths with an odd quote, spaces, \$, backticks and double quotes reach the script as is" {  # 特殊文字を含む台帳パス
  local v
  make_fake_root "$BATS_TEST_TMPDIR/root"
  for v in "/x/it's/l.jsonl" '/x/a  b/l.jsonl' '/x/$HOME/$(echo hi)/l.jsonl' '/x/`echo hi`/l.jsonl' '/x/"q"/l.jsonl' '/x/a\b/l.jsonl' '/x/ trailing /l.jsonl '; do
    run_cost_block "$BATS_TEST_TMPDIR/root" "$v"
    [ "$status" -eq 0 ] || { echo "status $status for $v: $output"; return 1; }
    [ "${lines[0]}" = "LEDGER=$v" ] || { echo "got ${lines[0]} for $v"; return 1; }
  done
}

@test "cost: an unsubstituted ledger placeholder is passed on unchanged for the script to treat as unset" {  # 未設定のとき置換されない文字列がそのまま渡る
  make_fake_root "$BATS_TEST_TMPDIR/root"
  run_cost_block "$BATS_TEST_TMPDIR/root" '${user_config.LEDGER_PATH}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'LEDGER=${user_config.LEDGER_PATH}' ]
}

@test "cost: a plugin root with spaces, \$(...), backticks and double quotes is used as the first candidate as is" {  # 特殊文字を含むルートが先頭候補として文字どおり使われる
  local root
  root="$BATS_TEST_TMPDIR"'/a b$(printf x)`q"d/plugin'
  make_fake_root "$root"
  mkdir -p "$BATS_TEST_TMPDIR/nohome"
  run_cost_block "$root" "/x/l.jsonl"
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "SELF=$root/scripts/cost_ledger.py" ] || { echo "$output"; return 1; }
  # 値の一部がコマンドとして実行されたなら、別名のディレクトリを探しに行く
  [ ! -e "$BATS_TEST_TMPDIR/a bx" ]
}

@test "cost: an unsubstituted plugin root is skipped and the later candidates are tried" {  # ルートが置換されないときは後続の候補へ進む
  local home="$BATS_TEST_TMPDIR/nohome"
  make_fake_root "$home/.claude/plugins/marketplaces/m/plugins/cost-ledger"
  run_cost_block '${CLAUDE_PLUGIN_ROOT}' "/x/l.jsonl"
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "SELF=$home/.claude/plugins/marketplaces/m/plugins/cost-ledger/scripts/cost_ledger.py" ] || { echo "$output"; return 1; }
}

@test "cost: the unset-ledger guidance names /config before settings" {  # 未設定時の案内は /config が先
  run python3 -c '
import sys
t = open(sys.argv[1], encoding="utf-8").read()
line = [l for l in t.splitlines() if "settings" in l][0]
sys.exit(0 if "/config" in line and line.index("/config") < line.index("settings") else 1)
' "$PLUGIN_DIR/commands/cost.md"
  [ "$status" -eq 0 ]
}

@test "cost: the script lookup tries the substituted plugin root first" {  # 探索の先頭候補は本文置換される絶対パスから作る
  local first
  first="$(grep -n -A2 '^for dir in' "$PLUGIN_DIR/commands/cost.md" | sed -n 2p)"
  [[ "$first" == *'"${PLUGIN_ROOT:+$PLUGIN_ROOT/scripts}"'* ]] || return 1
  [[ "$first" != *'CLAUDE_PLUGIN_ROOT:+'* ]] || return 1
}

# 2 つのリポジトリと、削除済み worktree に、同じ名前のブランチ "shared-name" の行を置く
shared_branch_rows() {
  {
    cl_row SH1 sh-a 2026-09-02T10:00:00.000Z shared-name "$REPO_A" 1000000
    cl_row SH2 sh-b 2026-09-02T11:00:00.000Z shared-name "$REPO_B" 2000000
    cl_row SH3 sh-u 2026-09-02T12:00:00.000Z shared-name /nonexistent/gone 4000000
  } | cl_write_log shared-name
}

@test "cost: without a number, a same-named branch in another repository is not added" {  # 番号なしの /cost は、別リポジトリの同名ブランチの金額を合算しない
  fake_gh_nothing
  shared_branch_rows
  git -C "$REPO_A" checkout -q -b shared-name
  git -C "$REPO_B" checkout -q -b shared-name

  run python3 "$CL" cost --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'コスト: $1.00 / ¥150 @150 — ブランチ shared-name (acme/repo-a) 帰属: ブランチ' ]

  run python3 "$CL" cost --repo "$REPO_B"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'コスト: $2.00 / ¥300 @150 — ブランチ shared-name (acme/repo-b) 帰属: ブランチ' ]
}

@test "cost: without a number, unknown-repository rows are neither dropped nor added" {  # 番号なしの /cost は、リポジトリ不明の行を除外も合算もせず件数と金額で別立てにする
  fake_gh_nothing
  shared_branch_rows
  git -C "$REPO_A" checkout -q -b shared-name

  run python3 "$CL" cost --repo "$REPO_A"
  [ "$status" -eq 0 ]
  # 合計に不明ぶん（$4.00）が入っていない
  [[ "${lines[0]}" == 'コスト: $1.00 /'* ]] || return 1
  [[ "$output" == *'リポジトリ不明: 1 件 $4.00'* ]] || return 1
}

@test "cost: the PR route still adds every repository's rows of the head branch" {  # PR の経路は従来どおりブランチ名だけで引く（リポジトリで絞らない）
  fake_gh_nothing
  shared_branch_rows
  cl_fake_gh <<'GH'
if [[ "$*" == *"pulls/55"* ]]; then echo shared-name; exit 0; fi
exit 1
GH

  run python3 "$CL" cost 55 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'コスト: $7.00 / ¥1,050 @150 — PR #55 (shared-name) 帰属: ブランチ' ]
}

# --- issue の合計（閉じた PR の分）---
# 呼び出し 1 回につき 1 行を $GH_LOG に控える gh。pulls/* は PR ではない、issues/148 は番号だけ、
# api graphql は $GQL_BODY の中身（無ければ失敗）を返す。
fake_gh_closing() {
  export GH_LOG="$BATS_TEST_TMPDIR/gh.log" GQL_BODY="$BATS_TEST_TMPDIR/gql.json"
  : > "$GH_LOG"
  cl_fake_gh <<'EOF2'
printf '%s\n' "$*" >> "$GH_LOG"
if [ "$1" = api ] && [ "$2" = graphql ]; then
  [ -f "$GQL_BODY" ] || exit 1
  cat "$GQL_BODY"; exit 0
fi
for arg in "$@"; do
  case "$arg" in
    */pulls/*) exit 1 ;;
    */issues/148) echo "148"; exit 0 ;;
  esac
done
exit 1
EOF2
}

# 閉じた PR の応答。$1=ノードの JSON の配列、$2=hasNextPage
closing_body() {
  printf '{"data":{"repository":{"nameWithOwner":"acme/repo-a","issue":{"closedByPullRequestsReferences":{"nodes":%s,"pageInfo":{"hasNextPage":%s}}}}}}' "$1" "${2:-false}" > "$GQL_BODY"
}
PR300='{"number":300,"headRefName":"oratta/sample-feature","isCrossRepository":false,"baseRepository":{"nameWithOwner":"acme/repo-a"}}'
gql_count() { grep -c '^api graphql' "$GH_LOG" || true; }

@test "cost: an issue closed by a PR shows the combined total under an unchanged first line" {  # 閉じた PR がある issue は、1 行目そのまま、合計と内訳が出る
  fake_gh_closing
  closing_body "[$PR300]"
  run python3 "$CL" cost 148 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $2.20 / ¥330 @150 — issue #148 (acme/repo-a) 帰属: 区間' ]] || return 1
  [[ "$output" == *'合計（閉じた PR 込み）:'*'PR #300 $'*'PR 外 $'* ]] || return 1
  [ "$(gql_count)" -eq 1 ]
}

@test "cost: an issue with no closing PR prints exactly what cost_ledger issue prints" {  # 閉じた PR が 0 件なら通常出力は issue の経路と同一
  fake_gh_closing
  closing_body "[]"
  run python3 "$CL" cost 148 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  expected="$output"
  run python3 "$CL" issue 148 --repo "$REPO_A"
  [ "$output" = "$expected" ]
  [[ "$expected" != *'読めなかった'* ]] || return 1
  [ "$(gql_count)" -eq 1 ]
}

@test "cost: a failed closing-PR query keeps the interval output and says so" {  # 問い合わせが失敗したら区間の分のまま、読めなかった旨を 1 行
  fake_gh_closing
  rm -f "$GQL_BODY"
  run python3 "$CL" cost 148 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == 'コスト: $2.20 / ¥330 @150 — issue #148 (acme/repo-a) 帰属: 区間' ]] || return 1
  [[ "$output" == *'閉じた PR を読めなかったため、PR の分は合計に入っていません。'* ]] || return 1
  [[ "$output" != *'合計（閉じた PR 込み）:'* ]] || return 1
}

@test "cost: a malformed or truncated closing-PR response counts as unreadable" {  # 形の崩れ・100 件超は読めなかった扱い
  fake_gh_closing
  closing_body '[{"number":"x"}]'
  run python3 "$CL" cost 148 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  [[ "$output" == *'閉じた PR を読めなかった'* ]] || return 1
  closing_body "[$PR300]" true
  run python3 "$CL" cost 148 --repo "$REPO_A"
  [[ "$output" == *'閉じた PR を読めなかった'* ]] || return 1
  [[ "$output" != *'合計（閉じた PR 込み）:'* ]] || return 1
}

@test "cost: --json stays pure JSON and reports closing_prs_error" {  # --json は JSON のまま。エラーは鍵で表す
  fake_gh_closing
  rm -f "$GQL_BODY"
  run python3 "$CL" cost 148 --repo "$REPO_A" --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["closing_prs_error"] is True and d["closing_prs"]==[]'
  closing_body "[]"
  run python3 "$CL" cost 148 --repo "$REPO_A" --json
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["closing_prs_error"] is False and d["closing_prs"]==[]'
  closing_body "[$PR300]"
  run python3 "$CL" cost 148 --repo "$REPO_A" --json
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["closing_prs_error"] is False and d["closing_prs"][0]["number"]==300'
}

@test "cost: cross-repository and other-base PRs are not counted" {  # フォーク・別ベースの PR は数えない
  fake_gh_closing
  closing_body "[{\"number\":301,\"headRefName\":\"fork/x\",\"isCrossRepository\":true,\"baseRepository\":{\"nameWithOwner\":\"acme/repo-a\"}},{\"number\":302,\"headRefName\":\"oratta/sample-feature\",\"isCrossRepository\":false,\"baseRepository\":{\"nameWithOwner\":\"acme/other\"}}]"
  run python3 "$CL" cost 148 --repo "$REPO_A"
  [[ "$output" != *'PR #301'* && "$output" != *'PR #302'* ]] || return 1
  [[ "$output" != *'合計（閉じた PR 込み）:'* ]] || return 1
}

@test "cost: the PR route and the numberless route never ask for closing PRs" {  # PR 番号・番号なしでは閉じた PR を問い合わせない
  fake_gh_closing
  cl_fake_gh <<'EOF2'
printf '%s\n' "$*" >> "$GH_LOG"
case "$*" in *pulls/271*) echo "oratta/sample-feature"; exit 0 ;; esac
exit 1
EOF2
  run python3 "$CL" cost 271 --repo "$REPO_A"
  [ "$status" -eq 0 ]
  run python3 "$CL" cost --repo "$REPO_A"
  [ "$(gql_count)" -eq 0 ]
}
