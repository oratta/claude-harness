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
  [[ "$output" == *ok* ]]

  run python3 "$CL" branch oratta/sample-feature
  [ "$status" -eq 0 ]
  [[ "$output" == *'$5.80'* ]]   # sidechain を落とすと $5.10
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
  [[ "$output" == *ok* ]]

  # 人が読む出力にも件数と金額が出る
  run python3 "$CL" report
  [ "$status" -eq 0 ]
  [[ "$output" == *"未帰属"* ]]
  [[ "$output" == *'1 件 $0.50'* ]]
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
  [[ "$output" == *ok* ]]

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
  [[ "$output" == *ok* ]]
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
  [[ "$output" == *ok* ]]

  # 人が読む出力にも別立てで出る
  run python3 "$CL" report
  [ "$status" -eq 0 ]
  [[ "$output" == *"リポジトリ不明: 1 件 \$1.00"* ]]
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
  [[ "$output" == *ok* ]]
}
