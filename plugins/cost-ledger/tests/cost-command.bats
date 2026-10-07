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

@test "cost: the command passes the userConfig value to the script" {  # 本文が userConfig の値を環境変数で渡す
  run grep -F "CLAUDE_PLUGIN_OPTION_LEDGER_PATH='\${user_config.LEDGER_PATH}' python3" "$PLUGIN_DIR/commands/cost.md"
  [ "$status" -eq 0 ]
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

@test "cost: the script lookup tries the substituted plugin root first" {  # 探索の先頭候補は本文置換される絶対パス
  local first
  first="$(grep -n -A2 '^for dir in' "$PLUGIN_DIR/commands/cost.md" | sed -n 2p)"
  [[ "$first" == *'"${CLAUDE_PLUGIN_ROOT}/scripts"'* ]] || return 1
  [[ "$first" != *':+'* ]] || return 1
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
