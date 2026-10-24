#!/usr/bin/env bats
#
# spec: cost-ledger-attribution
#
# 第 1 の鍵（ブランチ）と、リポジトリ識別子の導出を固定する。サブエージェントの行を
# 落とさないこと、ブランチを持たない行とリポジトリが導けない行を黙って消さないこと、
# worktree が親リポジトリに畳まれること、そして別立てにしたぶんを含めた合計が総額と
# 一致することを見る。

load helper

setup() {
  cl_setup
  cl_materialize
}

@test "attribution: sidechain lines land on the same branch" {  # isSidechain: true の行もブランチの合計に含まれる
  # fixture の req-002 は sidechain で、そのぶんが $0.70
  run bash -c "python3 '$CL' facts | python3 -c '
import json, sys
for line in sys.stdin:
    d = json.loads(line)
    if d[\"request_id\"] == \"req-002\":
        assert d[\"is_sidechain\"] is True, d
        assert d[\"branch\"] == \"oratta/sample-feature\", d
        print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1

  run python3 "$CL" branch oratta/sample-feature
  [ "$status" -eq 0 ]
  [[ "$output" == *'$5.80'* ]] || return 1   # sidechain を落とすと $5.10
}

@test "attribution: a line without gitBranch survives as unattributed" {  # gitBranch が無い行が黙って消えず未帰属として残る
  run bash -c "python3 '$CL' report --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert \"\" not in d[\"branches\"], d[\"branches\"]
assert d[\"unattributed_branch_messages\"] == 1, d
assert abs(d[\"unattributed_branch_usd\"] - 0.50) < 1e-9, d
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1

  # 人が読む出力にも件数と金額が出る
  run python3 "$CL" report
  [ "$status" -eq 0 ]
  [[ "$output" == *"未帰属"* ]] || return 1
  [[ "$output" == *'1 件 $0.50'* ]] || return 1
}

@test "attribution: a worktree folds into its parent repository" {  # メイン worktree と副 worktree が同一のリポジトリ識別子に畳まれる
  # fixture は同じリポジトリのメイン worktree（req-001）と副 worktree（req-007）に行を持つ
  run bash -c "python3 '$CL' facts | python3 -c '
import json, sys
ids = {}
for line in sys.stdin:
    d = json.loads(line)
    ids[d[\"request_id\"]] = d[\"repo_id\"]
assert ids[\"req-001\"] == ids[\"req-007\"], (ids[\"req-001\"], ids[\"req-007\"])
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1

  # --path-format=absolute を省くとメイン worktree で相対の .git が返り、識別子が割れる
  run grep -F -- '--path-format=absolute' "$PLUGIN_DIR/scripts/cost_ledger.py"
  [ "$status" -eq 0 ]

  # 表示名は origin の URL から owner/repo に直る
  run bash -c "python3 '$CL' report --json | python3 -c '
import json, sys
labels = {r[\"label\"] for r in json.load(sys.stdin)[\"repos\"].values()}
assert \"acme/repo-a\" in labels, labels
assert \"acme/repo-b\" in labels, labels
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}

@test "attribution: a deleted cwd becomes an unknown repository, not a crash" {  # cwd が削除済みでも集計が中断せず、リポジトリ識別子が「不明」として記録される
  [ ! -d /tmp/cost-ledger-deleted-cwd-does-not-exist ]

  run bash -c "python3 '$CL' report --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
unknown = d[\"repos\"][\"不明\"]
assert unknown[\"messages\"] == 1, d[\"repos\"]
assert abs(unknown[\"usd\"] - 1.00) < 1e-9, unknown
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1

  # 人が読む出力にも別立てで出る
  run python3 "$CL" report
  [ "$status" -eq 0 ]
  [[ "$output" == *"リポジトリ不明: 1 件 \$1.00"* ]] || return 1
}

@test "attribution: unattributed and unknown-repo sums add up to the grand total" {  # 未帰属とリポジトリ不明を含めた合計が全行のコストの総額と一致する
  run bash -c "python3 '$CL' report --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
total = d[\"total_usd\"]
by_branch = sum(d[\"branches\"].values()) + d[\"unattributed_branch_usd\"]
by_repo = sum(r[\"usd\"] for r in d[\"repos\"].values())
assert abs(by_branch - total) < 1e-9, (by_branch, total)
assert abs(by_repo - total) < 1e-9, (by_repo, total)
assert abs(total - 8.80) < 1e-9, total
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}

# ---- cost-ledger-attribution: issue による帰属（reopen と gh api の issues endpoint） ----

# 実行した Bash コマンド 1 つから拾われた issue 番号を、カンマ区切りで返す（無ければ空）
issues_of() {  # $1=Bash コマンド
  cl_row S1 r1 2026-09-01T00:00:01.000Z feat/x "/nonexistent/a" 1000000 "$1" | cl_write_log a
  python3 "$CL" facts | python3 -c '
import json, sys
for line in sys.stdin:
    d = json.loads(line)
    if d["request_id"] == "r1":
        print(",".join(d["issues"]))
'
}

@test "issue key: gh issue reopen picks the number" {  # reopen も鍵になる
  run issues_of "gh issue reopen 42"
  [ "$status" -eq 0 ]
  [ "$output" = "42" ]
}

@test "issue key: gh api issues endpoint picks the number (POST comments, PATCH, plain, query)" {  # -X / --method の有無と末尾の形
  run issues_of "gh api -X POST repos/acme/app/issues/42/comments -f body=x"
  [ "$output" = "42" ]
  run issues_of "gh api -X PATCH repos/acme/app/issues/42 -f state=open"
  [ "$output" = "42" ]
  run issues_of "gh api --method PATCH repos/acme/app/issues/42"
  [ "$output" = "42" ]
  run issues_of "gh api repos/acme/app/issues/42?per_page=1"
  [ "$output" = "42" ]
  run issues_of "gh api repos/acme/app/issues/42"
  [ "$output" = "42" ]
}

@test "issue key: gh api in a command position picks the number (line start, after && ; || |, VAR=x prefix)" {  # コマンドの位置
  run issues_of "cd x && gh api repos/acme/app/issues/7/comments"
  [ "$output" = "7" ]
  run issues_of "cd x;gh api repos/acme/app/issues/7"
  [ "$output" = "7" ]
  run issues_of "false || gh api repos/acme/app/issues/8"
  [ "$output" = "8" ]
  run issues_of "echo hi | gh api repos/acme/app/issues/9"
  [ "$output" = "9" ]
  run issues_of "GH_TOKEN=x gh api -X PATCH repos/acme/app/issues/11 -f state=open"
  [ "$output" = "11" ]
  run issues_of "$(printf 'echo ok\ngh api repos/acme/app/issues/13')"
  [ "$output" = "13" ]
}

@test "issue key: a gh api string inside a field value does not pick 99" {  # R1 2 周目の BLOCKER。42 だけ拾う
  run issues_of 'gh api -X POST repos/acme/app/issues/42/comments -f body="gh api repos/acme/app/issues/99"'
  [ "$output" = "42" ]
  run issues_of 'gh issue comment 42 --body "gh api repos/acme/app/issues/99"'
  [ "$output" = "42" ]
}

@test "issue key: gh api outside a command position is not read (xargs, time, if)" {  # 読み落とし。別の issue へ寄らない
  run issues_of "xargs gh api repos/acme/app/issues/5"
  [ "$output" = "" ]
  run issues_of "time gh api repos/acme/app/issues/5"
  [ "$output" = "" ]
  run issues_of "if gh api repos/acme/app/issues/5; then :; fi"
  [ "$output" = "" ]
}

@test "issue key: comment endpoint, graphql, and issues/42abc are not keys" {  # 別の endpoint
  run issues_of "gh api -X PATCH repos/acme/app/issues/comments/777"
  [ "$output" = "" ]
  run issues_of "gh api repos/acme/app/issues/42abc"
  [ "$output" = "" ]
  run issues_of "gh api graphql -f query=x"
  [ "$output" = "" ]
}

@test "issue key: strings in Agent prompts and Edit bodies are not keys (reopen too)" {  # 実行していない文字列
  cl_row_tool S1 r1 2026-09-01T00:00:01.000Z feat/x "/nonexistent/a" 1000000 Agent '{"prompt":"gh issue reopen 999"}' | cl_write_log a
  run bash -c "python3 '$CL' facts | python3 -c '
import json, sys
for line in sys.stdin:
    d = json.loads(line)
    if d[\"request_id\"] == \"r1\":
        print(\",\".join(d[\"issues\"]))
'"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "issue key: a backslash-escaped separator or line continuation is not a command position" {  # PR #880 G 1 周目 F1。echo の引数で実行されない
  run issues_of 'echo x\; gh api repos/acme/app/issues/99'
  [ "$output" = "" ]
  run issues_of 'echo x\| gh api repos/acme/app/issues/99'
  [ "$output" = "" ]
  run issues_of "$(printf 'echo x \\\ngh api repos/acme/app/issues/99')"
  [ "$output" = "" ]
}

@test "issue key: gh api does not take its endpoint from the next line" {  # PR #880 G 1 周目 F2。改行で別のコマンドになる
  run issues_of "$(printf 'gh api\nrepos/acme/app/issues/42')"
  [ "$output" = "" ]
  run issues_of "$(printf 'gh api -X POST\nrepos/acme/app/issues/42')"
  [ "$output" = "" ]
  run issues_of "$(printf 'gh api --method\nPATCH repos/acme/app/issues/42')"
  [ "$output" = "" ]
}

@test "issue key: KNOWN EXCEPTION a gh api after ; inside a shell comment is still picked" {  # 既知の例外。行内のそれより前の # は正規表現から見えない
  run issues_of 'echo ok #; gh api repos/acme/app/issues/99'
  [ "$output" = "99" ]
}

@test "issue key: KNOWN EXCEPTION a gh api after ; inside a quoted value is also picked (#879)" {  # 既知の例外。塞ぐなら #879
  run issues_of 'gh api -X POST repos/acme/app/issues/42/comments -f body="x; gh api repos/acme/app/issues/99"'
  [ "$output" = "42,99" ]
}
