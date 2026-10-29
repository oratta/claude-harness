#!/usr/bin/env bats
load helper

setup() {
  export LC_ALL=C.UTF-8 TZ=UTC
  cl_setup
  export TMPDIR="$BATS_TEST_TMPDIR/tmp" PYTHONDONTWRITEBYTECODE=1
  mkdir -p "$TMPDIR"
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
if [ "$1" = api ]
  [ "$2" = graphql ]; then
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
  printf '{"number": %s, "title": "%s", "state": "%s", "repository": {"nameWithOwner": "%s"}, "updatedAt": "2026-09-01T00:00:00Z", "subIssuesSummary": {"total": %s, "completed": 0}, "closedByPullRequestsReferences": %s}' \
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
if [ "$1" = api ]
  [ "$2" = graphql ]; then
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

@test "cache: storage: fd survives path replacement, files are private, resources close" {
  python3 - "$PLUGIN_DIR/scripts" "$TMPDIR" <<'PY'
import json, os, sys
sys.path.insert(0, sys.argv[1])
import gate_report as g
lock = g.lock('acme/ra', 10)
assert lock is not None
folder = os.path.join(sys.argv[2], 'cost-ledger-timeline')
os.rename(folder, folder + '.old')
os.mkdir(folder, 0o700)
g.cache_write(lock, 'acme/ra', 10, {'nodes': {}})
assert g.cache_read(lock, 'acme/ra', 10) == {'nodes': {}}
files = os.listdir(folder + '.old')
assert any(n.endswith('.json') for n in files)
assert not os.listdir(folder)
for n in files:
    assert os.stat(os.path.join(folder + '.old', n)).st_mode & 0o077 == 0
dir_fd = lock.dir_fd
g.unlock(lock)
for fd in (int(lock), dir_fd):
    try: os.fstat(fd)
    except OSError: pass
    else: raise AssertionError('fd leaked')
PY
}

@test "cache: storage: missing corrupt mismatched unreadable and symlink files are ignored" {
  python3 - "$PLUGIN_DIR/scripts" "$TMPDIR" <<'PY'
import json, os, sys
from unittest.mock import patch
sys.path.insert(0, sys.argv[1])
import gate_report as g
lock = g.lock('acme/ra', 10)
assert g.cache_read(lock, 'acme/ra', 10) is None
g.cache_write(lock, 'acme/ra', 10, {'nodes': {}})
folder = os.path.join(sys.argv[2], 'cost-ledger-timeline')
path = next(os.path.join(folder, n) for n in os.listdir(folder) if n.endswith('.json'))
good = open(path).read()
for bad in ('{', '[]', good.replace('acme/ra', 'other/repo'), good.replace('"version": 1', '"version": 9')):
    open(path, 'w').write(bad)
    assert g.cache_read(lock, 'acme/ra', 10) is None, bad
open(path, 'w').write(good)
os.chmod(path, 0o666)
assert g.cache_read(lock, 'acme/ra', 10) is None
os.chmod(path, 0o600)
with patch.object(g.os, 'open', side_effect=PermissionError):
    assert g.cache_read(lock, 'acme/ra', 10) is None
    g.cache_write(lock, 'acme/ra', 10, {'nodes': {}})
os.rename(path, path + '.victim')
os.symlink(path + '.victim', path)
assert g.cache_read(lock, 'acme/ra', 10) is None
g.cache_write(lock, 'acme/ra', 10, {'nodes': {'changed': True}})
assert open(path + '.victim').read() == good
assert os.path.islink(path)
g.unlock(lock)
PY
}

# 二つの子がそれぞれ孫を持つ。hook は毎回別のプロセス。
cache_tree() {
  gql 10 epic OPEN "$(prs "$(pr 310 feat/e)")" \
    "$(child 11 a CLOSED 1 "$(prs "$(pr 300 feat/a)")")" \
    "$(child 12 b OPEN 1 "$(prs "$(pr 301 feat/b)")")"
  gql 11 a CLOSED "$(prs)" "$(child 13 grand OPEN 0 "$(prs)")"
  gql 12 b OPEN "$(prs)" "$(child 14 grand OPEN 0 "$(prs)")"
}
reset_calls() { : > "$EPIC_GH_LOG"; : > "$TL_LOG"; }
cache_file() { printf '%s/cost-ledger-timeline/acme__ra__10.json' "$TMPDIR"; }
mutate_root() {
  python3 - "$EPIC_GQL_DIR/10.json" "$1" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
n = d['data']['repository']['issue']['subIssues']['nodes']
exec(sys.argv[2])
open(p, 'w').write(json.dumps(d))
PY
}

@test "cache: unchanged and one changed child reduce GraphQL 3 to 1 and 2 across hooks" {
  hook_setup; logs; cache_tree
  run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 3 ]
  [ "$(gh_calls)" -eq 6 ]
  reset_calls
  run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 1 ]
  [ "$(gh_calls)" -eq 4 ]
  [[ "$(tl_args)" == *'--child-issue 11 --child-issue 12 --child-issue 13 --child-issue 14'* ]]
  mutate_root 'n[0]["updatedAt"] = "2026-09-02T00:00:00Z"'
  reset_calls
  run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 2 ]
  [ "$(gh_calls)" -eq 5 ]
  [[ "$(grep '^api graphql' "$EPIC_GH_LOG")" == *number=11* ]]
  [[ "$(grep '^api graphql' "$EPIC_GH_LOG")" != *number=12* ]]
}

@test "cache: each signal invalidates separately, PR order alone does not" {
  hook_setup; logs; cache_tree
  mutate_root 'n[0]["closedByPullRequestsReferences"]["nodes"].append(dict(n[0]["closedByPullRequestsReferences"]["nodes"][0], number=305))'
  run_hook "gh issue comment 10 --body x"
  for change in \
    'n[0]["updatedAt"] = "2026-09-03T00:00:00Z"' \
    'n[0]["subIssuesSummary"]["completed"] = 1' \
    'n[0]["subIssuesSummary"]["total"] = 2' \
    'n[0]["closedByPullRequestsReferences"]["nodes"][0]["number"] = 302' \
    'n[0]["closedByPullRequestsReferences"]["nodes"][0]["headRefName"] = "feat/new"' \
    'n[0]["closedByPullRequestsReferences"]["nodes"][0]["baseRepository"]["nameWithOwner"] = "acme/other"' \
    'n[0]["closedByPullRequestsReferences"]["nodes"][0]["isCrossRepository"] = True'; do
    mutate_root "$change"; reset_calls
    run_hook "gh issue comment 10 --body x"
    [ "$(gql_calls)" -eq 2 ] || { cat "$EPIC_GH_LOG"; return 1; }
  done
  mutate_root 'n[0]["closedByPullRequestsReferences"]["nodes"].reverse()'
  reset_calls; run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 1 ]
}

@test "cache: storage: invalid or incomplete tree falls back to full retrieval" {
  hook_setup; logs; cache_tree
  run_hook "gh issue comment 10 --body x"
  for bad in corrupt version target incomplete signal; do
    python3 - "$(cache_file)" "$bad" <<'PY'
import json, sys
p, bad = sys.argv[1:]; d = json.load(open(p))
if bad == 'version': d['version'] = 9
if bad == 'target': d['number'] = 99
if bad == 'incomplete': d['tree']['nodes'].pop('11')
if bad == 'signal': d['tree']['nodes']['11'].pop('signal')
open(p, 'w').write('{' if bad == 'corrupt' else json.dumps(d))
PY
    reset_calls; run_hook "gh issue comment 10 --body x"
    [ "$(gql_calls)" -eq 3 ]
    [[ "$(tl_args)" == *'--child-issue 14'* ]]
  done
}

@test "cache: storage: write failure still uses complete fresh result" {
  hook_setup; logs; cache_tree
  mkdir -p "$TMPDIR/cost-ledger-timeline/acme__ra__10.json"
  chmod 700 "$TMPDIR/cost-ledger-timeline"
  run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 3 ]
  [[ "$(tl_args)" == *'--child-issue 14'* && "$(tl_args)" != *'照会失敗'* ]]
}

assert_cost_total() {
  # /cost は保存を使わず全件取得する偽 gh へ切替。hook 用は戻す。
  cp "$BATS_TEST_TMPDIR/bin/gh" "$WORK/hook-gh"
  fake_gh
  cost_first="$(python3 "$CL" cost 10 --repo "$RA" --no-drift-check | head -n 1)"
  cp "$WORK/hook-gh" "$BATS_TEST_TMPDIR/bin/gh"
  python3 - "$EPIC_BODY" "$cost_first" <<'PY'
import json, re, sys
body = json.load(open(sys.argv[1]))['body']
assert body.splitlines()[0] == sys.argv[2], (body, sys.argv[2])
amount = re.search(r'\$[0-9.]+', sys.argv[2])[0]
rows = [r for r in body.splitlines() if '| 合計（' in r]
assert len(rows) == 1 and '| ' + amount + ' ' in rows[0], body
PY
}

@test "cache: totals match full cost before and after new grandchildren PRs and local logs" {
  hook_setup; logs; cache_tree
  EPIC_STATE=closed
  run_hook "gh issue close 10"
  assert_cost_total
  reset_calls; run_hook "gh issue close 10"
  [ "$(gql_calls)" -eq 1 ]
  assert_cost_total
  cl_row SG r9 2026-09-01T00:02:00.000Z main "$RA" 1000000 "gh issue view 15" | cl_write_log sg
  cl_row SP r10 2026-09-01T00:03:00.000Z feat/new "$RA" 1000000 | cl_write_log sp
  mutate_root 'n[0]["updatedAt"] = "2026-09-04T00:00:00Z"'
  gql 11 a CLOSED "$(prs)" "$(child 15 new OPEN 0 "$(prs "$(pr 315 feat/new)" "$(pr 316 feat/a)")")" \
    "$(child 14 duplicate OPEN 0)"
  reset_calls; run_hook "gh issue close 10"
  [ "$(gql_calls)" -eq 2 ]
  [[ "$(tl_args)" != *'--child-issue 13'* ]]
  [[ "$(tl_args)" == *'--child-issue 14 --child-issue 15'* ]]
  assert_cost_total
  # 関連が同じでもコストを再計算（+ $1.00）。
  before="$cost_first"
  cl_row SP r11 2026-09-01T00:04:00.000Z feat/new "$RA" 1000000 | cl_write_log sp2
  reset_calls; run_hook "gh issue close 10"
  [ "$(gql_calls)" -eq 1 ]
  assert_cost_total
  [ "$before" != "$cost_first" ]
}

@test "cache: children removed added made leaves and reparented keep complete unique relations" {
  hook_setup; logs; cache_tree
  # #12 の子を #11 の子と共有する。保存には重複排除前の関連を残す。
  gql 12 b OPEN "$(prs)" "$(child 13 shared OPEN 0)"
  run_hook "gh issue comment 10 --body x"
  mutate_root 'n.pop(0)'
  reset_calls; run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 1 ]
  [[ "$(tl_args)" == *'--child-issue 12 --child-issue 13'* && "$(tl_args)" != *'--child-issue 11'* ]]
  mutate_root 'n[0]["subIssuesSummary"]["total"] = 0; n.append(dict(n[0], number=15, title="new"))'
  reset_calls; run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 1 ]
  [[ "$(tl_args)" == *'--child-issue 12 --child-issue 15'* && "$(tl_args)" != *'--child-issue 13'* ]]
}

@test "cache: failures never mask live errors or publish partial results" {
  hook_setup; logs; cache_tree
  EPIC_STATE=closed
  run_hook "gh issue close 10"
  cp "$(cache_file)" "$WORK/good-cache"
  cp "$EPIC_GQL_DIR/10.json" "$WORK/good-root"
  for bad in gh json shape children prs signal subtree; do
    cp "$WORK/good-root" "$EPIC_GQL_DIR/10.json"
    EPIC_GQL_FAIL=""
    case "$bad" in
      gh) EPIC_GQL_FAIL=1 ;;
      json) echo '{' > "$EPIC_GQL_DIR/10.json" ;;
      shape) echo '{}' > "$EPIC_GQL_DIR/10.json" ;;
      children) mutate_root 'd["data"]["repository"]["issue"]["subIssues"]["pageInfo"]["hasNextPage"] = True' ;;
      prs) mutate_root 'n[0]["closedByPullRequestsReferences"]["pageInfo"]["hasNextPage"] = True' ;;
      signal) mutate_root 'n[0].pop("updatedAt")' ;;
      subtree)
        mutate_root 'n[0]["updatedAt"] = "changed"'
        echo '{}' > "$EPIC_GQL_DIR/11.json" ;;
    esac
    reset_calls; run_hook "gh issue close 10"
    [[ "$(tl_args)" == *'子 issue 照会失敗'* && "$(tl_args)" != *--child* && "$(tl_args)" != *--closing-pr* ]]
    cmp "$(cache_file)" "$WORK/good-cache"
    python3 - "$EPIC_BODY" <<'PY'
import json, sys
body = json.load(open(sys.argv[1]))['body']
assert '子 issue 照会失敗' in body and '合計（' not in body, body
PY
  done
}

@test "cache: only real queries count toward five and a sixth is never called" {
  hook_setup; logs; cache_tree
  run_hook "gh issue comment 10 --body x"
  for n in 20 21 22 23 24; do
    gql "$n" new OPEN "$(prs)" "$(child $((n+100)) leaf OPEN 0)"
  done
  mutate_root 'n.extend(dict(n[0], number=i) for i in range(20,24))'
  reset_calls; run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 5 ]
  [[ "$(tl_args)" == *'--child-issue 123'* && "$(tl_args)" != *'照会失敗'* ]]
  cp "$(cache_file)" "$WORK/good-cache"
  mutate_root 'n.extend(dict(n[0], number=i) for i in range(30,35))'
  for n in 30 31 32 33 34; do
    gql "$n" new OPEN "$(prs)" "$(child $((n+100)) leaf OPEN 0)"
  done
  reset_calls; run_hook "gh issue comment 10 --body x"
  [ "$(gql_calls)" -eq 5 ]
  [[ "$(tl_args)" == *'照会失敗'* && "$(tl_args)" != *--child* ]]
  [[ "$(grep '^api graphql' "$EPIC_GH_LOG")" != *number=34* ]]
  cmp "$(cache_file)" "$WORK/good-cache"
}

@test "cache: reused descendants still enforce root-relative depth" {
  cache_tree
  gql 10 root OPEN "$(prs)" "$(child 11 a OPEN 1)"
  gql 11 a OPEN "$(prs)" "$(child 13 b OPEN 1)"
  gql 13 b OPEN "$(prs)" "$(child 14 leaf OPEN 0)"
  python3 - "$PLUGIN_DIR/scripts" "$EPIC_GQL_DIR" <<'PY'
import json, os, subprocess, sys
sys.path.insert(0, sys.argv[1]); import gate_report as g
g.EPIC_MAX_DEPTH = 3
calls = []
def answer(args):
    n = next(a.split('=')[1] for a in args if a.startswith('number='))
    calls.append(int(n))
    return subprocess.CompletedProcess(args, 0, open(os.path.join(sys.argv[2], n+'.json')).read(), '')
g.gh_api = answer
lock = g.lock('acme/ra', 10)
assert g.epic_tree('acme/ra', 10, lock)[0] == [11,13,14]
path = os.path.join(sys.argv[2], '10.json'); root = json.load(open(path))
child = root['data']['repository']['issue']['subIssues']['nodes'][0]
root['data']['repository']['issue']['subIssues']['nodes'] = [dict(child, number=12)]
open(path, 'w').write(json.dumps(root))
new = json.loads(json.dumps(root)); new['data']['repository']['issue']['number'] = 12
new['data']['repository']['issue']['subIssues']['nodes'] = [child]
open(os.path.join(sys.argv[2], '12.json'), 'w').write(json.dumps(new))
calls.clear()
assert g.epic_tree('acme/ra', 10, lock) is None
assert calls == [10,12], calls
g.unlock(lock)
PY
}

@test "cache: deep changes without child signal are missed and full cost remains available" {
  hook_setup; logs; cache_tree
  EPIC_STATE=closed
  run_hook "gh issue close 10"
  assert_cost_total
  old="$cost_first"
  gql 11 a CLOSED "$(prs)" "$(child 15 hidden OPEN 0 "$(prs "$(pr 315 feat/hidden)")")"
  cl_row SH hidden 2026-09-01T00:05:00.000Z feat/hidden "$RA" 1000000 | cl_write_log hidden
  reset_calls; run_hook "gh issue close 10"
  [ "$(gql_calls)" -eq 1 ]
  [[ "$(tl_args)" == *'--child-issue 13'* && "$(tl_args)" != *'--child-issue 15'* ]]
  fake_gh
  cost_first="$(python3 "$CL" cost 10 --repo "$RA" --no-drift-check | head -n 1)"
  [ "$old" != "$cost_first" ]
  python3 - "$EPIC_BODY" "$old" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))['body'].splitlines()[0] == sys.argv[2]
PY
}
