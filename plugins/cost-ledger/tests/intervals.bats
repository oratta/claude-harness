#!/usr/bin/env bats
#
# spec: cost-ledger-attribution
#
# 第 2 の鍵（リポジトリ識別子と issue 番号の組）と、セッションごとの区間分割を固定する。
# 区間は sessionId ごとに timestamp 順で切り、投稿 4 種を境界にして、直近に触った issue
# へ寄せる。ブランチ全体を時刻順に並べて切ってはならない（並行セッションが混ざる）。

load helper

setup() {
  cl_setup
  cl_materialize
}

@test "intervals: the same issue number in two repositories is never merged" {  # 別リポジトリの同じ issue 番号が合算されない
  # fixture はリポジトリ A の 148（$2.20）とリポジトリ B の 148（$1.00）を持つ
  run bash -c "python3 '$CL' issue 148 --repo '$REPO_A' --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert abs(d[\"total_usd\"] - 2.20) < 1e-9, d[\"total_usd\"]
assert d[\"repo_label\"] == \"acme/repo-a\", d
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1

  run bash -c "python3 '$CL' issue 148 --repo '$REPO_B' --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert abs(d[\"total_usd\"] - 1.00) < 1e-9, d[\"total_usd\"]
assert d[\"repo_label\"] == \"acme/repo-b\", d
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}

@test "intervals: a session on main that commented on an issue attributes to that issue" {  # main 上で gh issue comment 148 を実行したセッションの区間がそのリポジトリの issue 148 へ帰属する
  run bash -c "python3 '$CL' issue 148 --repo '$REPO_B' --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
rows = d[\"intervals\"]
assert len(rows) == 1, rows
assert rows[0][\"session_id\"] == \"S3\", rows[0]
assert rows[0][\"branches\"] == [\"main\"], rows[0]
assert abs(rows[0][\"usd\"] - 1.00) < 1e-9, rows[0]
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}

@test "intervals: gh issue close alone attributes the session to that issue" {  # gh issue close だけのセッションもその issue へ帰属する
  # fixture の S6 は main 上で gh issue close 273 だけを実行している（投稿の境界は無い）
  run bash -c "python3 '$CL' issue 273 --repo '$REPO_A' --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert abs(d[\"total_usd\"] - 0.50) < 1e-9, d[\"total_usd\"]
assert [r[\"session_id\"] for r in d[\"intervals\"]] == [\"S6\"], d[\"intervals\"]
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}

@test "intervals: gh issue develop alone attributes the session to that issue" {  # gh issue develop だけのセッションもその issue へ帰属する
  rm -rf "$CONFIG_DIR/projects"/*
  { cl_row D1 dev-1 2026-09-02T09:00:00.000Z main "$REPO_A" 1000000 "gh issue develop 273 --name wip"
  } | cl_write_log develop-only

  run bash -c "python3 '$CL' issue 273 --repo '$REPO_A' --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert abs(d[\"total_usd\"] - 1.00) < 1e-9, d[\"total_usd\"]
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}

@test "intervals: gh pr ready closes an interval" {  # gh pr ready が区間の境界として扱われる
  # fixture の S2 は gh pr ready で閉じる区間を持つ
  run bash -c "python3 '$CL' intervals --json | python3 -c '
import json, sys
rows = [r for r in json.load(sys.stdin)[\"intervals\"] if r[\"session_id\"] == \"S2\"]
assert len(rows) == 1, rows
assert rows[0][\"closed_by\"] == \"gh pr ready\", rows[0]
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1

  # 境界のあとに行が続くセッションでは、そこで区間が 2 つに割れる
  rm -rf "$CONFIG_DIR/projects"/*
  { cl_row R1 rd-1 2026-09-02T09:00:00.000Z feat "$REPO_A" 1000000 "gh issue view 900"
    cl_row R1 rd-2 2026-09-02T09:01:00.000Z feat "$REPO_A" 1000000 "gh pr ready 900"
    cl_row R1 rd-3 2026-09-02T09:02:00.000Z feat "$REPO_A" 1000000 "gh issue view 901"
  } | cl_write_log ready-split

  run bash -c "python3 '$CL' intervals --json | python3 -c '
import json, sys
rows = json.load(sys.stdin)[\"intervals\"]
assert len(rows) == 2, rows
assert rows[0][\"closed_by\"] == \"gh pr ready\", rows[0]
assert rows[0][\"issue\"] == \"900\" and abs(rows[0][\"usd\"] - 2.00) < 1e-9, rows[0]
assert rows[1][\"issue\"] == \"901\" and abs(rows[1][\"usd\"] - 1.00) < 1e-9, rows[1]
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}

@test "intervals: two concurrent sessions on one branch do not cut each other" {  # 同じブランチで並行する 2 セッションの区間が混ざらない
  # fixture の S1（10:00〜10:40）と S2（10:07〜10:12）は同じブランチで時刻が重なる。
  # 時刻順にブランチ全体を切ると、S2 の req-007 が S1 の issue 148 の区間に入り $3.20 になる。
  run bash -c "python3 '$CL' issue 148 --repo '$REPO_A' --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
rows = d[\"intervals\"]
assert len(rows) == 1, rows
assert rows[0][\"session_id\"] == \"S1\", rows[0]
assert rows[0][\"request_ids\"] == [\"req-001\", \"req-002\", \"req-003\"], rows[0]
assert abs(rows[0][\"usd\"] - 2.20) < 1e-9, rows[0]
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}

@test "intervals: the intervals of a branch add up to the branch total" {  # 区間ごとのコストの合計がブランチの総額と一致する
  run bash -c "python3 '$CL' intervals --branch oratta/sample-feature --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert abs(sum(r[\"usd\"] for r in d[\"intervals\"]) - d[\"total_usd\"]) < 1e-9, d
assert abs(d[\"total_usd\"] - 5.80) < 1e-9, d[\"total_usd\"]
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1

  # branch サブコマンドが出す総額と同じ値であること
  run python3 "$CL" branch oratta/sample-feature
  [ "$status" -eq 0 ]
  [[ "$output" == *'$5.80'* ]] || return 1
}

@test "intervals: a line on a feature branch that viewed an issue counts in both" {  # feature ブランチ上で gh issue view した行がブランチにも issue にも帰属する
  # fixture の req-004 は oratta/sample-feature 上の gh issue view 213（$1.00）
  run bash -c "python3 '$CL' issue 213 --repo '$REPO_A' --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
ids = [i for r in d[\"intervals\"] for i in r[\"request_ids\"]]
assert \"req-004\" in ids, ids
assert abs(d[\"total_usd\"] - 2.00) < 1e-9, d[\"total_usd\"]
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1

  # 同じ行がブランチの合計にも入っている（両方に帰属するので足し合わせて総額にはならない）
  run bash -c "python3 '$CL' intervals --branch oratta/sample-feature --json | python3 -c '
import json, sys
d = json.load(sys.stdin)
ids = [i for r in d[\"intervals\"] for i in r[\"request_ids\"]]
assert \"req-004\" in ids, ids
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}

@test "intervals: a session that touched no issue stays unattributed" {  # issue を一度も触っていないセッションはどの issue にも帰属しない
  run bash -c "python3 '$CL' intervals --json | python3 -c '
import json, sys
rows = json.load(sys.stdin)[\"intervals\"]
s2 = [r for r in rows if r[\"session_id\"] == \"S2\"]
assert s2[0][\"issue\"] is None, s2
# 帰属先の無い区間も落とさず残る
assert abs(sum(r[\"usd\"] for r in rows if r[\"issue\"] is None) - 2.10) < 1e-9, \
    [(r[\"session_id\"], r[\"usd\"]) for r in rows if r[\"issue\"] is None]
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]] || return 1
}
