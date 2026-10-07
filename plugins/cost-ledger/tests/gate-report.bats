#!/usr/bin/env bats
#
# spec: cost-ledger-gate-report / cost-ledger-timeline（hook の側）
#
# PR / issue へのコメント・状態の変更・ゲート通過（agent-review:passed の付与）を PostToolUse の
# hook で捕まえて、同じ 1 本のコメントに「ここまでのコスト」を 1 行ずつ積む gate-report.sh を
# 固定する。実物には触れない: スクリプトを一時ディレクトリへ複製し、同じディレクトリに stub の
# cost_ledger.py を置き（スクリプトの隣から引くことの検査）、gh も PATH の先頭の stub に差し替える。
# hook は COST_LEDGER_HOOK_FOREGROUND=1 でその場で最後まで実行させる（切り離しそのものを見る
# テストを除く）。

load helper

setup() {
  cl_setup
  REAL_PYTHON="$(command -v python3)"
  WORK="$BATS_TEST_TMPDIR/gate"
  FIX="$WORK/fixtures"
  CWD="$WORK/cwd"
  mkdir -p "$WORK/scripts" "$WORK/bin" "$WORK/log" "$WORK/tmp" "$FIX" "$CWD"
  cp "$PLUGIN_DIR/scripts/gate-report.sh" "$WORK/scripts/gate-report.sh"
  if [ -f "$PLUGIN_DIR/scripts/gate_report.py" ]; then
    cp "$PLUGIN_DIR/scripts/gate_report.py" "$WORK/scripts/gate_report.py"
  fi
  SCRIPT="$WORK/scripts/gate-report.sh"
  export GH_LOG="$WORK/log/gh.log" COST_LOG="$WORK/log/cost.log" GH_FIX="$FIX"
  export FAKE_CWD_REPO="acme/cwd-repo"
  export TMPDIR="$WORK/tmp"                 # 対象ごとのロックファイルの置き場
  export COST_LEDGER_HOOK_FOREGROUND=1
  unset COST_LEDGER_GATE_REPORT GH_REPO FAKE_GH_FAIL FAKE_PATCH_FAIL FAKE_COST_RC FAKE_COST_LINE
  unset FAKE_GH_DELAY FAKE_GH_CONFIRM_DELAY FAKE_COMMENTS_FAIL FAKE_HEAD_PR FAKE_CWD_BRANCH
  unset FAKE_CLOSING_PRS FAKE_CLOSING_NEXT FAKE_GRAPHQL_FAIL FAKE_GRAPHQL_RAW
  write_stub_cost_ledger
  write_stub_gh
  export PATH="$WORK/bin:$PATH"
}

# timeline を受け、引数と標準入力（既存の本文）を記録して、既存の行に 1 行足した固定の本文を返す
# cost_ledger.py。数字は固定で、並べ替えはしない（書式と並びは timeline.bats が本物で固定する）。
write_stub_cost_ledger() {
  cat > "$WORK/scripts/cost_ledger.py" <<'PY'
import os, sys
args = sys.argv[1:]
existing = sys.stdin.read()
log = os.environ["COST_LOG"]
with open(log, "a", encoding="utf-8") as f:
    f.write("args=%s\n" % " ".join(args))
with open(log + ".stdin", "w", encoding="utf-8") as f:
    f.write(existing)

def opt(name):
    return args[args.index(name) + 1] if name in args else ""

MARK = "<!-- cost-ledger:timeline v1"
lines = existing.split("\n")
rows = [l for l in lines if l.startswith("| ") and not l.startswith("| 時刻 ")]
records = []
for l in lines:
    if l.startswith(MARK):
        records = l[len(MARK):].replace("-->", "").split()
rows.append("| 10/06 07:20 | %s | $1.23 (+1.23) | 1K (+1K) | 2K (+2K) |" % opt("--trigger"))
records.append("%s:1.230000:1000:2000" % opt("--at"))
kind, number = ("PR", opt("--pr")) if "--pr" in args else ("issue", opt("--issue"))
print(os.environ.get("FAKE_COST_LINE",
                     "コスト: $1.23 / ¥185 @150 — %s #%s (oratta/sample) 帰属: ブランチ" % (kind, number)))
print("")
print("| 時刻 | きっかけ | 金額 | 入出力 | キャッシュ |")
print("|---|---|---|---|---|")
print("\n".join(rows))
print("")
print("%s %s -->" % (MARK, " ".join(records)))
sys.exit(int(os.environ.get("FAKE_COST_RC", "0")))
PY
}

# 本物の cost_ledger.py と料金表を複製して使う（並び順・同時実行・別リポジトリの検査）。
# ヘッドブランチ oratta/sample に $1.00 の応答を 1 つ置く。
use_real_cost_ledger() {
  cp "$PLUGIN_DIR/scripts/cost_ledger.py" "$WORK/scripts/cost_ledger.py"
  cp "$PLUGIN_DIR/pricing.json" "$WORK/pricing.json"
  cl_row S1 r1 2026-09-01T00:00:10.000Z oratta/sample /nonexistent/x 1000000 | cl_write_log real
}

# 呼ばれた引数を 1 呼び出し 1 行でログに書く gh（$GH_LOG の行数が呼び出し回数）。
#   対象の確認:    repos/<A>/pulls/<N>・repos/<A>/issues/<N>・repos/<A>/pulls?head=...
#                  既定は「open・draft でない・未マージ・合格ラベル付き・ヘッド oratta/sample の PR」。
#                  $GH_FIX/pull.<N>.json / issue.<N>.json があれば既定に上書きする。
#                  $GH_FIX/nopull.<N> があれば PR ではない（issue）、missing.<N> があれば存在しない
#   パス:          repos/{owner}/{repo}/... は FAKE_CWD_REPO で埋め、実行した cwd を $GH_LOG.cwd に書く
#   既存コメント:  $GH_FIX/comments.<N>.<ページ>.json（無ければ空の 1 ページ）。--jq はページごとに当てる
#   書き込み:      --input - の JSON の body を $GH_LOG.body に書き、POST は comments.<N>.9.json に足し、
#                  PATCH はその id のコメントを書き換える（続けて流すテストで次の取得に現れる）
#   遅延と失敗:    FAKE_GH_DELAY（全部の呼び出し）・FAKE_GH_CONFIRM_DELAY（対象の確認だけ）・
#                  FAKE_GH_FAIL・FAKE_PATCH_FAIL・FAKE_COMMENTS_FAIL
#   閉じた PR:     api graphql は closedByPullRequestsReferences の応答を返す。nodes は FAKE_CLOSING_PRS
#                  （JSON の配列。既定は 0 件）、pageInfo.hasNextPage は FAKE_CLOSING_NEXT=1 で真。
#                  FAKE_GRAPHQL_FAIL=1 は GraphQL だけ失敗、FAKE_GRAPHQL_RAW は応答をその文字列にする。
#                  呼び出しは $GH_LOG にも入り、GraphQL の分だけ $GH_LOG.graphql に 1 回 1 行で書く
#                  （-f / -F の値は $GH_LOG.graphql.fields に 1 個 1 行）
write_stub_gh() {
  printf '#!%s\n' "$REAL_PYTHON" > "$WORK/bin/gh"
  cat >> "$WORK/bin/gh" <<'PY'
import glob, json, os, re, subprocess, sys, time

args = sys.argv[1:]
LOG, FIX = os.environ["GH_LOG"], os.environ["GH_FIX"]
env = os.environ.get

def note(path, line):
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o644)
    os.write(fd, (line.replace("\n", "\\n") + "\n").encode("utf-8"))
    os.close(fd)

note(LOG, " ".join(args))
note(LOG + ".env", " ".join("%s=%s" % (k, os.environ[k]) for k in
                            ("GH_HOST", "GH_ENTERPRISE_TOKEN", "GITHUB_ENTERPRISE_TOKEN")
                            if k in os.environ) or "-")
if env("FAKE_GH_DELAY"):
    time.sleep(float(env("FAKE_GH_DELAY")))
if env("FAKE_GH_FAIL") == "1":
    sys.stderr.write("gh: boom\n")
    sys.exit(1)
if not args or args[0] != "api":
    if args and args[0] == "repo":
        print(env("FAKE_CWD_REPO", ""))
    sys.exit(0)

method, path, jqf, source, fields = None, "", None, None, []
i = 1
while i < len(args):
    a = args[i]
    if a in ("-X", "--method"):
        method = args[i + 1]; i += 2
    elif a in ("--jq", "-q"):
        jqf = args[i + 1]; i += 2
    elif a == "--input":
        source = args[i + 1]; i += 2
    elif a in ("-f", "-F", "--raw-field", "--field"):
        fields.append(args[i + 1]); i += 2
    elif a == "--paginate":
        i += 1
    elif a == "--hostname":
        i += 2
    else:
        path = a; i += 1
body = json.loads(sys.stdin.read())["body"] if source == "-" else None
method = method or ("POST" if body is not None else "GET")

if "{" in path:
    note(LOG + ".cwd", os.path.realpath(os.getcwd()))
    owner, name = env("FAKE_CWD_REPO", "acme/cwd-repo").split("/")
    path = (path.replace("{owner}", owner).replace("{repo}", name)
                .replace("{branch}", env("FAKE_CWD_BRANCH", "feat/here")))
if path == "graphql":
    note(LOG + ".graphql", "graphql")
    for field in fields:
        note(LOG + ".graphql.fields", field)
    if env("FAKE_GRAPHQL_FAIL") == "1":
        sys.stderr.write("gh: graphql boom\n")
        sys.exit(1)
    if env("FAKE_GRAPHQL_RAW") is not None:
        sys.stdout.write(env("FAKE_GRAPHQL_RAW") + "\n")
        sys.exit(0)
    refs = {"nodes": json.loads(env("FAKE_CLOSING_PRS", "[]")),
            "pageInfo": {"hasNextPage": env("FAKE_CLOSING_NEXT") == "1"}}
    emit(json.dumps({"data": {"repository": {"issue": {"closedByPullRequestsReferences": refs}}}}))
    sys.exit(0)
path, _, query = path.partition("?")
m = re.fullmatch(r"repos/([^/]+/[^/]+)/(.*)", path)
if not m:
    sys.exit(1)
repo, rest = m.groups()

LABELS = [{"name": "agent-review:pending"}, {"name": "agent-review:passed"}]

def has(name):
    return os.path.exists(os.path.join(FIX, name))

def override(base, name):
    p = os.path.join(FIX, name)
    if os.path.exists(p):
        base.update(json.load(open(p, encoding="utf-8")))
    return base

def pull(n):
    return override({"number": n, "state": "open", "draft": False, "merged": False,
                     "merged_at": None, "labels": list(LABELS),
                     "head": {"ref": "oratta/sample"},
                     "base": {"repo": {"full_name": repo}}}, "pull.%d.json" % n)

def issue(n):
    d = {"number": n, "state": "open", "labels": list(LABELS),
         "repository_url": "https://api.github.com/repos/" + repo}
    if not has("nopull.%d" % n):
        d["pull_request"] = {"url": "x"}
    return override(d, "issue.%d.json" % n)

def emit(text):
    if jqf is None:
        sys.stdout.write(text + "\n")
    else:
        sys.stdout.write(subprocess.run(["jq", "-r", jqf], input=text, capture_output=True,
                                        encoding="utf-8", check=True).stdout)

def confirm_delay():
    if env("FAKE_GH_CONFIRM_DELAY"):
        time.sleep(float(env("FAKE_GH_CONFIRM_DELAY")))

def pages(n):
    return sorted(glob.glob(os.path.join(FIX, "comments.%d.*.json" % n)))

m_pull = re.fullmatch(r"pulls/(\d+)", rest)
m_issue = re.fullmatch(r"issues/(\d+)", rest)
m_comments = re.fullmatch(r"issues/(\d+)/comments", rest)
m_comment = re.fullmatch(r"issues/comments/(\d+)", rest)
if method == "GET" and rest == "pulls":
    confirm_delay()
    note(LOG + ".query", query)
    n = env("FAKE_HEAD_PR")
    emit(json.dumps([pull(int(n))] if n else []))
elif method == "GET" and m_pull:
    confirm_delay()
    n = int(m_pull.group(1))
    if has("nopull.%d" % n) or has("missing.%d" % n):
        sys.stderr.write("gh: Not Found (HTTP 404)\n")
        sys.exit(1)
    emit(json.dumps(pull(n)))
elif method == "GET" and m_issue:
    confirm_delay()
    n = int(m_issue.group(1))
    if has("missing.%d" % n):
        sys.stderr.write("gh: Not Found (HTTP 404)\n")
        sys.exit(1)
    emit(json.dumps(issue(n)))
elif method == "GET" and m_comments:
    if env("FAKE_COMMENTS_FAIL") == "1":
        sys.stderr.write("gh: boom\n")
        sys.exit(1)
    found = pages(int(m_comments.group(1)))
    if not found:
        emit("[]")
    for p in found:
        emit(open(p, encoding="utf-8").read())
elif method == "POST" and m_comments:
    n = int(m_comments.group(1))
    open(LOG + ".body", "w", encoding="utf-8").write(body or "")
    p = os.path.join(FIX, "comments.%d.9.json" % n)
    items = json.load(open(p, encoding="utf-8")) if os.path.exists(p) else []
    items.append({"id": 900000 + n * 100 + len(items), "body": body or ""})
    json.dump(items, open(p, "w", encoding="utf-8"), ensure_ascii=False)
    print("{}")
elif method == "PATCH" and m_comment:
    if env("FAKE_PATCH_FAIL") == "1":
        sys.stderr.write("gh: patch failed\n")
        sys.exit(1)
    open(LOG + ".body", "w", encoding="utf-8").write(body or "")
    cid = int(m_comment.group(1))
    for p in glob.glob(os.path.join(FIX, "comments.*.json")):
        items = json.load(open(p, encoding="utf-8"))
        hit = [c for c in items if c.get("id") == cid]
        if hit:
            hit[0]["body"] = body or ""
            json.dump(items, open(p, "w", encoding="utf-8"), ensure_ascii=False)
    print("{}")
else:
    print("{}")
PY
  chmod +x "$WORK/bin/gh"
}

# 起動されたらログに書いて 0 以外で終わる python3（fast path の検査のときだけ PATH の先頭に置く）
use_stub_python() {
  mkdir -p "$WORK/pybin"
  cat > "$WORK/pybin/python3" <<SH
#!/usr/bin/env bash
echo "python3 started" >> "$WORK/log/python.log"
exit 3
SH
  chmod +x "$WORK/pybin/python3"
  export PATH="$WORK/pybin:$PATH"
}

# hook の JSON を組み立てる。コマンド文字列のエスケープは json.dumps に任せる。
#   HOOK_CWD（既定 ${CWD}）/ HOOK_TRANSCRIPT（"-" で省く）/ HOOK_STDOUT（tool_response の stdout）
hook_json() {  # $1=command
  "$REAL_PYTHON" - "$1" "${HOOK_CWD-$CWD}" "${HOOK_TRANSCRIPT-/tmp/claude/projects/p/S1.jsonl}" "${HOOK_STDOUT-}" <<'PY'
import json, sys
command, cwd, transcript, stdout = sys.argv[1:5]
d = {"session_id": "S1", "hook_event_name": "PostToolUse", "tool_name": "Bash",
     "tool_input": {"command": command, "description": "test"},
     "tool_response": {"stdout": stdout, "stderr": "", "interrupted": False,
                       "isImage": False},
     "cwd": cwd}
if transcript != "-":
    d["transcript_path"] = transcript
print(json.dumps(d, ensure_ascii=False))
PY
}

run_hook() {  # $1=command
  hook_json "$1" > "$WORK/payload.json"
  run bash "$SCRIPT" < "$WORK/payload.json"
}

now() { "$REAL_PYTHON" -c 'import time; print("%.3f" % time.time())'; }

GRANT_LITERAL="gh api -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'"
OLD_MARKER='<!-- cost-ledger:gate-report -->'
TL_MARKER='<!-- cost-ledger:timeline v1'

# 対象の確認（repos/<A>/pulls/<N> か repos/<A>/issues/<N> そのもの。/comments や /labels は除く）が出たか。
# cwd のリポジトリを指すときは $1 に '{owner}/{repo}' を渡す
queried() {  # $1=owner/repo $2=番号
  grep -qE "(^| )repos/$1/(pulls|issues)/$2( |\$)" "$GH_LOG"
}

no_gh_call() { [ ! -s "$GH_LOG" ]; }
gh_calls() { if [ -f "$GH_LOG" ]; then wc -l < "$GH_LOG" | tr -d ' '; else echo 0; fi; }

# GraphQL（閉じた PR の問い合わせ）が呼ばれた回数
graphql_calls() { if [ -f "$GH_LOG.graphql" ]; then wc -l < "$GH_LOG.graphql" | tr -d ' '; else echo 0; fi; }

# closedByPullRequestsReferences の nodes の 1 件
closing_node() {  # $1=番号 $2=ヘッドブランチ $3=ベースの owner/repo（既定 acme/cwd-repo） $4=isCrossRepository（既定 false）
  printf '{"number":%s,"headRefName":"%s","isCrossRepository":%s,"baseRepository":{"nameWithOwner":"%s"}}' \
    "$1" "$2" "${4:-false}" "${3:-acme/cwd-repo}"
}

# #12 を「クローズ済みの、PR でない issue」にする
closed_issue_12() {
  touch "$FIX/nopull.12"
  echo '{"state":"closed"}' > "$FIX/issue.12.json"
}

# stub の timeline が受け取った --closing-pr の値を、渡された順に空白で区切って返す（無ければ空）
closing_args() {
  [ -f "$COST_LOG" ] || return 0
  tail -n 1 "$COST_LOG" | grep -oE -- '--closing-pr [^ ]+' | sed 's/^--closing-pr //' | tr '\n' ' ' | sed 's/ $//'
}

# コメントの作成も書き換えも無い
no_write() {
  [ ! -f "$GH_LOG" ] && return 0
  ! grep -qE -- '-X (POST|PATCH) repos/[^ ]+/(issues/[0-9]+/comments|issues/comments/)' "$GH_LOG" || return 1
}

posted_to() {  # $1=owner/repo $2=番号
  grep -qF -- "-X POST repos/$1/issues/$2/comments" "$GH_LOG"
}
# stub の timeline が、その対象（--target-repo）と作業中の場所（--repo）で呼ばれたか。別リポジトリの
# 対象に書かないことは timeline が決める（終了コード 3）ので、stub を使うテストでは渡した引数を見る
asked_timeline() {  # $1=owner/repo $2=pr|issue $3=番号
  grep -qE -- "^args=timeline --$2 $3 .*--repo $CWD --target-repo $1\$" "$COST_LOG"
}

posts() { [ -f "$GH_LOG" ] || { echo 0; return 0; }; grep -cE -- '-X POST repos/[^ ]+/issues/[0-9]+/comments' "$GH_LOG" || true; }
patches() { [ -f "$GH_LOG" ] || { echo 0; return 0; }; grep -cE -- '-X PATCH repos/[^ ]+/issues/comments/' "$GH_LOG" || true; }

# 最後に書き込まれた本文の表の行（見出しと区切りを除く）
body_rows() { grep '^| ' "$GH_LOG.body" | grep -v '^| 時刻 ' || true; }
body_nrows() { body_rows | wc -l | tr -d ' '; }
body_trigger() { body_rows | sed -n "${1}p" | awk -F'|' '{v=$3; sub(/^ /,"",v); sub(/ $/,"",v); print v}'; }

# 目印付きのコメント（表 2 行）を #300 の 1 ページ目に置く
seed_timeline_comment() {  # $1=コメントの id
  "$REAL_PYTHON" - "$FIX/comments.300.1.json" "$1" <<'PY'
import json, sys
body = "\n".join([
    "コスト: $0.50 / ¥75 @150 — PR #300 (oratta/sample) 帰属: ブランチ", "",
    "| 時刻 | きっかけ | 金額 | 入出力 | キャッシュ |", "|---|---|---|---|---|",
    "| 10/05 01:00 | PR コメント | $0.20 (+0.20) | 1K (+1K) | 2K (+2K) |",
    "| 10/05 02:00 | PR コメント | $0.50 (+0.30) | 2K (+1K) | 4K (+2K) |", "",
    "<!-- cost-ledger:timeline v1 1791162000.000:0.200000:1000:2000 1791165600.000:0.500000:2000:4000 -->"])
json.dump([{"id": 11, "body": "LGTM"}, {"id": int(sys.argv[2]), "body": body}],
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PY
}

# --- hook の登録と fast path ---

@test "gate-report: hooks.json registers a synchronous PostToolUse Bash hook with timeout 60" {  # hooks.json の PostToolUse に matcher Bash・timeout 60 の hook があり、async も if も無い
  [ -x "$PLUGIN_DIR/scripts/gate-report.sh" ]
  run "$REAL_PYTHON" - "$PLUGIN_DIR/hooks/hooks.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
entries = [e for e in d["hooks"]["PostToolUse"] if e.get("matcher") == "Bash"]
handlers = [h for e in entries for h in e["hooks"]
            if h.get("command") == "${CLAUDE_PLUGIN_ROOT}/scripts/gate-report.sh"]
assert len(handlers) == 1, handlers
h = handlers[0]
assert h.get("type") == "command", h
assert h.get("timeout") == 60, h
assert "async" not in h, h
assert all("if" not in e for e in entries) and "if" not in h, entries
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "gate-report: a Bash call with none of the trigger strings starts neither gh nor python3" {  # 8 つの文字列のどれも含まない Bash（gh pr view 300 を含む）では gh も python3 も起動せず、無出力で 0
  use_stub_python
  for c in "ls -la && git status" "gh pr view 300" "gh issue view 12 --comments" "gh pr create --title x" \
           "gh pr reopen 300" "gh pr list" "gh issue edit 12 --add-label bug"; do
    run_hook "$c"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    no_gh_call
    [ ! -e "$WORK/log/python.log" ] || { echo "python3 started for: $c"; return 1; }
  done
}

@test "gate-report: each of the eight trigger strings passes the fast path" {  # 8 つの文字列のどれかを含めば python3 が起動する
  use_stub_python
  for c in "echo agent-review:passed" "gh pr comment 1" "gh pr ready 1" "gh pr close 1" "gh pr merge 1" \
           "gh issue comment 1" "gh issue close 1" "gh issue reopen 1"; do
    command rm -f "$WORK/log/python.log"
    run_hook "$c"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -e "$WORK/log/python.log" ] || { echo "python3 not started for: $c"; return 1; }
  done
}

@test "gate-report: gh pr comment adds one row to that PR" {  # gh pr comment 300 で #300 に行を 1 行積む（きっかけは PR コメント）
  run_hook 'gh pr comment 300 --body "レビュー済み"'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  posted_to acme/cwd-repo 300
  [ "$(posts)" -eq 1 ]
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "PR コメント" ]
}

@test "gate-report: COST_LEDGER_GATE_REPORT=off stops everything" {  # COST_LEDGER_GATE_REPORT=off では付与コマンドでも gh が呼ばれず、無出力で 0
  export COST_LEDGER_GATE_REPORT=off
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
}

@test "gate-report: COST_LEDGER_GATE_REPORT=off also stops the comment trigger" {  # 緊急停止は gh pr comment にも効く（gh も python3 も呼ばれない）
  export COST_LEDGER_GATE_REPORT=off
  use_stub_python
  run_hook 'gh pr comment 300 --body x'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
  [ ! -e "$WORK/log/python.log" ]
}

# --- 付与の判定と対象 PR の取り出し ---

@test "gate-report: a literal gh api grant targets that PR" {  # リテラルの gh api 付与で oratta/claude-harness の #300 が対象になる
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  queried oratta/claude-harness 300
  asked_timeline oratta/claude-harness pr 300
  grep -qE -- '^args=timeline .*--trigger ゲート通過 ' "$COST_LOG"
}

@test "gate-report: variables assigned in the same command are expanded" {  # 同じコマンドで代入した R・N を展開して #300 が対象になる
  run_hook "R=oratta/claude-harness; N=300; gh api -X POST repos/\$R/issues/\$N/labels -f 'labels[]=agent-review:passed'"
  queried oratta/claude-harness 300
}

@test "gate-report: braced and quoted assignments are expanded" {  # \${R} / \${N} の形と引用符付きの代入も展開する
  run_hook "R=oratta/claude-harness
N=300
gh api -X POST \"repos/\${R}/issues/\${N}/labels\" -f 'labels[]=agent-review:passed'"
  queried oratta/claude-harness 300
  : > "$GH_LOG"
  run_hook "R=\"oratta/claude-harness\"; N='301' && gh api -X POST repos/\$R/issues/\$N/labels -f 'labels[]=agent-review:passed'"
  queried oratta/claude-harness 301
}

@test "gate-report: a for loop over literal numbers targets each PR" {  # for N in 96 97 の中の付与で #96 と #97 の両方が対象になる
  run_hook "R=oratta/kg-recruit
for N in 96 97; do
  gh api -X POST repos/\$R/issues/\$N/labels -f 'labels[]=agent-review:passed' >/dev/null
done"
  queried oratta/kg-recruit 96
  queried oratta/kg-recruit 97
}

@test "gate-report: gh pr edit --add-label targets the cwd repository without gh repo view" {  # -R 無しの gh pr edit は gh repo view を呼ばず、repos/{owner}/{repo}/pulls/313 を cwd で問い合わせた応答のリポジトリに書く
  run_hook "gh pr edit 313 --remove-label agent-review:pending --add-label agent-review:passed"
  queried '\{owner\}/\{repo\}' 313
  ! grep -q '^repo ' "$GH_LOG" || return 1
  grep -qxF "$(cd "$CWD" && pwd -P)" "$GH_LOG.cwd"
  posted_to acme/cwd-repo 313
}

@test "gate-report: gh pr edit with -R / --repo targets that repository" {  # -R / --repo があればそのリポジトリが対象になり（timeline の --target-repo に渡る）、gh repo view は呼ばない
  run_hook "gh pr edit 313 -R oratta/other --add-label agent-review:passed"
  queried oratta/other 313
  asked_timeline oratta/other pr 313
  run_hook "gh issue edit 314 --add-label agent-review:passed,foo --repo oratta/other"
  queried oratta/other 314
  asked_timeline oratta/other pr 314
  ! grep -q '^repo ' "$GH_LOG" || return 1
}

@test "gate-report: gh api without -X POST is still a grant" {  # -X POST を書かない gh api ... -f 'labels[]=agent-review:passed' も付与として扱う
  run_hook "gh api repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'"
  queried oratta/claude-harness 300
}

@test "gate-report: removing the label never posts" {  # ラベルを外す DELETE（パスの形・--method DELETE の形）ではコメントの作成も書き換えも無い
  run_hook "gh api -X DELETE repos/oratta/claude-harness/issues/300/labels/agent-review:passed"
  [ "$status" -eq 0 ]
  no_write
  ! queried oratta/claude-harness 300 || return 1
  run_hook "gh api --method DELETE repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'"
  [ "$status" -eq 0 ]
  no_write
  ! queried oratta/claude-harness 300 || return 1
}

@test "gate-report: merely mentioning the label never posts" {  # ラベル名を文字列として含むだけのコマンド（出力に出る・echo・付与コマンドの echo）では投稿しない
  HOOK_STDOUT='{"labels":[{"name":"agent-review:passed"}]}' run_hook "gh pr view 300 --json labels"
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook "echo agent-review:passed"
  no_gh_call
  run_hook "echo \"gh api -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'\""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
}

@test "gate-report: command substitution in an assignment is never resolved" {  # N=\$(...) のようにコマンド置換で代入された番号は解決せず、無出力で 0
  run_hook "R=oratta/claude-harness; N=\$(gh pr view --json number -q .number); gh api -X POST repos/\$R/issues/\$N/labels -f 'labels[]=agent-review:passed'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_write
  no_gh_call
  run_hook "R=oratta/claude-harness; N=\`cat n.txt\`; gh api -X POST repos/\$R/issues/\$N/labels -f 'labels[]=agent-review:passed'"
  no_gh_call
  run_hook "R=oratta/claude-harness; N=\"\$PR\"; gh api -X POST repos/\$R/issues/\$N/labels -f 'labels[]=agent-review:passed'"
  no_gh_call
}

@test "gate-report: a reassigned variable resolves to the nearest preceding assignment" {  # 再代入は使う位置より前の直近の代入で解決する（直近が解決できなければ飛ばす）
  run_hook "R=oratta/claude-harness; N=1; N=300; gh api -X POST repos/\$R/issues/\$N/labels -f 'labels[]=agent-review:passed'"
  queried oratta/claude-harness 300
  ! queried oratta/claude-harness 1 || return 1
  : > "$GH_LOG"
  run_hook "R=oratta/claude-harness; N=300; N=\$(cat n); gh api -X POST repos/\$R/issues/\$N/labels -f 'labels[]=agent-review:passed'"
  no_gh_call
}

@test "gate-report: assignments inside a ( ) subshell do not leak out of it" {  # ( ) の中の代入は括弧の中でだけ効き、括弧を出たら外の値に戻る
  run_hook "N=300; (N=5; echo x); gh api -X POST repos/oratta/claude-harness/issues/\$N/labels -f 'labels[]=agent-review:passed'"
  queried oratta/claude-harness 300
  ! queried oratta/claude-harness 5 || return 1
  : > "$GH_LOG"
  run_hook "N=300
(N=301; gh pr view \"\$N\" -R acme/project)
gh pr edit \"\$N\" -R acme/project --add-label agent-review:passed"
  queried acme/project 300
  ! queried acme/project 301 || return 1
  : > "$GH_LOG"
  run_hook "N=300; (N=301; gh api -X POST repos/oratta/claude-harness/issues/\$N/labels -f 'labels[]=agent-review:passed')"
  queried oratta/claude-harness 301
}

@test "gate-report: a GH_REPO prefix on gh pr edit targets that repository" {  # 前置きの GH_REPO があればそのリポジトリが対象で gh repo view を呼ばない。-R が優先し、解決できない値なら飛ばす
  run_hook "GH_REPO=oratta/other gh pr edit 300 --add-label agent-review:passed"
  queried oratta/other 300
  asked_timeline oratta/other pr 300
  ! grep -q '^repo ' "$GH_LOG" || return 1
  : > "$GH_LOG"
  run_hook "R=oratta/other; GH_REPO=\$R gh issue edit 301 --add-label agent-review:passed"
  queried oratta/other 301
  : > "$GH_LOG"
  run_hook "GH_REPO=oratta/other gh pr edit 302 -R oratta/third --add-label agent-review:passed"
  queried oratta/third 302
  ! queried oratta/other 302 || return 1
  : > "$GH_LOG"
  run_hook "GH_REPO=\$(cat r) gh pr edit 300 --add-label agent-review:passed"
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook "GH_REPO=\$UNSET gh pr edit 300 --add-label agent-review:passed"
  no_gh_call
}

@test "gate-report: a command aimed at another host never stacks" {  # --hostname（github.com 以外）・前置きの GH_HOST（github.com 以外）・-R の HOST/OWNER/REPO（github.com 以外）のコマンドは gh を呼ばず無出力で 0。github.com を明示した形は積む
  run_hook "gh api --hostname ghe.example -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
  run_hook "gh api --hostname=ghe.example -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'"
  no_gh_call
  run_hook "GH_HOST=ghe.example gh pr comment 300 --body x"
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook "GH_HOST=ghe.example gh issue close 12"
  no_gh_call
  run_hook "gh pr comment 300 -R ghe.example/acme/cwd-repo --body x"
  no_gh_call
  GH_HOST=ghe.example run_hook "gh pr comment 300 --body x"
  no_gh_call
  run_hook "GH_HOST=github.com gh pr comment 300 --body x"
  posted_to acme/cwd-repo 300
}

@test "gate-report: every gh api call of the background work is pinned to github.com" {  # 対象の確認・番号省略の PR の検索・コメント一覧・POST・PATCH のすべての gh api に --hostname github.com が付く
  run_hook 'gh pr comment 300 --body x'
  posted_to acme/cwd-repo 300
  seed_timeline_comment 555
  FAKE_HEAD_PR=300 run_hook 'gh pr comment --body y'
  grep -qF -- "-X PATCH repos/acme/cwd-repo/issues/comments/555" "$GH_LOG"
  [ "$(grep -c '^api ' "$GH_LOG")" -ge 6 ]
  ! grep '^api ' "$GH_LOG" | grep -vqE -- '--hostname github\.com( |$)' || return 1
}

@test "gate-report: the background work drops GH_HOST and enterprise tokens from gh's environment" {  # 環境に GH_HOST=ghe.example・GH_ENTERPRISE_TOKEN・GITHUB_ENTERPRISE_TOKEN がある状態で裏の処理を流すと、gh が受け取る環境にはどれも無い
  JOB='{"cwd": "'"$CWD"'", "at": "1900000000.000", "targets": [{"kind": "pr", "repo": null, "number": 300, "triggers": ["PR コメント"]}]}'
  GH_HOST=ghe.example GH_ENTERPRISE_TOKEN=t1 GITHUB_ENTERPRISE_TOKEN=t2 \
    "$REAL_PYTHON" "$WORK/scripts/gate_report.py" --work "$JOB"
  posted_to acme/cwd-repo 300
  [ -s "$GH_LOG.env" ]
  ! grep -vqx -- '-' "$GH_LOG.env" || return 1
}

@test "gate-report: an explicit GET on the labels path is not a grant" {  # -X GET / --method GET / -XGET / --method=GET を明示した gh api は付与とみなさない（PUT は付与）
  for m in "-X GET" "--method GET" "-XGET" "--method=GET"; do
    run_hook "gh api $m repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'"
    [ "$status" -eq 0 ]
    no_gh_call
  done
  run_hook "gh api -X PUT repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'"
  queried oratta/claude-harness 300
}

# --- 付与の実測・数字の取得・コメントの形 ---

@test "gate-report: no post when the PR does not actually carry the label" {  # 問い合わせた PR に agent-review:passed が無ければ作成も書き換えもせず、timeline も呼ばない
  echo '{"labels":[{"name":"agent-review:pending"}]}' > "$FIX/pull.300.json"
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  queried oratta/claude-harness 300
  no_write
  [ ! -e "$COST_LOG" ]
  [ "$(gh_calls)" -eq 1 ]
}

@test "gate-report: the first trigger creates one timeline comment" {  # 目印付きのコメントが無ければ POST で 1 本作る。1 行目がコストの行・表の行が 1 行・最終行が目印。本文は引数に載せず標準入力で渡す
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  posted_to oratta/claude-harness 300
  [ "$(posts)" -eq 1 ]
  [ "$(patches)" -eq 0 ]
  grep -E -- '-X POST repos/' "$GH_LOG" | grep -qF -- '--input -'
  ! grep -qF 'body=' "$GH_LOG" || return 1
  "$REAL_PYTHON" - "$GH_LOG.body" <<'PY'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
assert lines[0] == "コスト: $1.23 / ¥185 @150 — PR #300 (oratta/sample) 帰属: ブランチ", lines[0]
assert lines[1] == "", lines
assert lines[2] == "| 時刻 | きっかけ | 金額 | 入出力 | キャッシュ |", lines[2]
rows = [l for l in lines[4:] if l.startswith("| ")]
assert len(rows) == 1 and "| ゲート通過 |" in rows[0], rows
assert lines[-1].startswith("<!-- cost-ledger:timeline v1 "), lines[-1]
PY
}

@test "gate-report: a later trigger patches the same comment and keeps the rows" {  # 目印付きのコメント（表 2 行）があれば PATCH で書き換え、POST せず、表は 3 行で先頭の 2 行は同じ。既存の本文は timeline の標準入力に渡る
  seed_timeline_comment 555
  run_hook "gh pr ready 300"
  [ "$status" -eq 0 ]
  grep -qF -- "-X PATCH repos/acme/cwd-repo/issues/comments/555" "$GH_LOG"
  [ "$(posts)" -eq 0 ]
  [ "$(body_nrows)" -eq 3 ]
  [ "$(body_rows | sed -n 1p)" = '| 10/05 01:00 | PR コメント | $0.20 (+0.20) | 1K (+1K) | 2K (+2K) |' ]
  [ "$(body_rows | sed -n 2p)" = '| 10/05 02:00 | PR コメント | $0.50 (+0.30) | 2K (+1K) | 4K (+2K) |' ]
  [ "$(body_trigger 3)" = "Ready" ]
  grep -qF '1791165600.000:0.500000:2000:4000 -->' "$COST_LOG.stdin"
  grep -qF '| 10/05 01:00 | PR コメント |' "$COST_LOG.stdin"
}

@test "gate-report: the timeline comment is found on the second page" {  # 目印付きのコメントが 2 ページ目にあっても PATCH になる（先に現れた 1 本だけ）
  echo '[{"id":11,"body":"LGTM"}]' > "$FIX/comments.300.1.json"
  echo '[{"id":777,"body":"x\n<!-- cost-ledger:timeline v1 1.000:1.000000:1:1 -->"},{"id":778,"body":"y\n<!-- cost-ledger:timeline v1 1.000:1.000000:1:1 -->"}]' > "$FIX/comments.300.2.json"
  run_hook "$GRANT_LITERAL"
  grep -qF -- "-X PATCH repos/oratta/claude-harness/issues/comments/777" "$GH_LOG"
  ! grep -qF -- "issues/comments/778" "$GH_LOG" || return 1
  [ "$(posts)" -eq 0 ]
}

@test "gate-report: a failed PATCH does not fall back to POST" {  # PATCH が失敗しても POST に切り替えない
  seed_timeline_comment 555
  export FAKE_PATCH_FAIL=1
  run_hook "gh pr comment 300 --body x"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -qF -- "-X PATCH repos/acme/cwd-repo/issues/comments/555" "$GH_LOG"
  [ "$(posts)" -eq 0 ]
}

@test "gate-report: an old gate-report comment is neither searched for nor patched" {  # 古い目印のコメントだけがあるときは新しいコメントを 1 本作り、古い方へ PATCH しない
  echo '[{"id":555,"body":"コスト: $0.10\nold\n<!-- cost-ledger:gate-report -->"}]' > "$FIX/comments.300.1.json"
  run_hook "gh pr comment 300 --body x"
  [ "$status" -eq 0 ]
  [ "$(posts)" -eq 1 ]
  [ "$(patches)" -eq 0 ]
  [ ! -s "$COST_LOG.stdin" ]   # 古い本文は timeline に渡さない
}

@test "gate-report: a marker quoted in the middle of a line is not the timeline comment" {  # 目印の文字列を行の途中に含むだけのコメント（引用など）は書き換えない
  echo '[{"id":555,"body":"see `<!-- cost-ledger:timeline v1 1.000:1.000000:1:1 -->` above"}]' > "$FIX/comments.300.1.json"
  run_hook "gh pr comment 300 --body x"
  [ "$(posts)" -eq 1 ]
  [ "$(patches)" -eq 0 ]
}

@test "gate-report: nothing is written when the comment list cannot be read" {  # コメント一覧の取得が失敗したら書かない（timeline も呼ばない）
  export FAKE_COMMENTS_FAIL=1
  run_hook "gh pr comment 300 --body x"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_write
  [ ! -e "$COST_LOG" ]
}

@test "gate-report: timeline gets the kind, head branch, time, cwd and target repository" {  # timeline に --pr・--branch・--trigger・--at・--repo・--target-repo が渡る。issue は --issue
  run_hook "$GRANT_LITERAL"
  grep -qE "^args=timeline --pr 300 --branch oratta/sample --trigger ゲート通過 --at [0-9]+\.[0-9]{3} --repo $CWD --target-repo oratta/claude-harness\$" "$COST_LOG"
  : > "$COST_LOG"
  touch "$FIX/nopull.12"
  run_hook "gh issue comment 12 --body x"
  grep -qE "^args=timeline --issue 12 --trigger issue コメント --at [0-9]+\.[0-9]{3} --repo $CWD --target-repo acme/cwd-repo\$" "$COST_LOG"
}

@test "gate-report: cost_ledger.py is asked only for timeline, which has no price drift check" {  # hook は突き合わせを行わない timeline だけを呼び、突き合わせのある cost は呼ばない
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ] || return 1
  grep -q '^args=' "$COST_LOG" || return 1
  [ "$(grep '^args=' "$COST_LOG" | grep -cv '^args=timeline ')" -eq 0 ] || { cat "$COST_LOG"; return 1; }
}

@test "gate-report: works without transcript_path and from a subagent transcript" {  # transcript_path が無くても、サブエージェントのトランスクリプトを指していても積む
  HOOK_TRANSCRIPT=- run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  posted_to oratta/claude-harness 300
  command rm -f "$FIX"/comments.300.*.json
  : > "$GH_LOG"
  HOOK_TRANSCRIPT=/tmp/claude/projects/p/S1/subagents/agent-a1.jsonl run_hook "$GRANT_LITERAL"
  posted_to oratta/claude-harness 300
}

@test "gate-report: a for loop grant posts to each PR" {  # for で 2 件付与したら #96 と #97 のそれぞれに積む
  run_hook "R=oratta/kg-recruit; for N in 96 97; do gh api -X POST repos/\$R/issues/\$N/labels -f 'labels[]=agent-review:passed'; done"
  [ "$status" -eq 0 ]
  posted_to oratta/kg-recruit 96
  posted_to oratta/kg-recruit 97
}

# --- 失敗時の抜け方 ---

@test "gate-report: silent exit 0 when every gh call fails" {  # gh がすべて失敗しても無出力で 0
  export FAKE_GH_FAIL=1
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run_hook "gh pr comment 300 --body x"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "gate-report: no write when timeline fails or its first line is not a cost line" {  # cost_ledger.py timeline が 0 以外、または 1 行目が「コスト: 」で始まらなければ書かない
  export FAKE_COST_RC=1
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -s "$COST_LOG" ]
  no_write
  export FAKE_COST_RC=3
  run_hook "gh pr comment 300 --body x"
  no_write
  export FAKE_COST_RC=0 FAKE_COST_LINE="番号 300 は PR でも issue でもない"
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  no_write
}

@test "gate-report: silent exit 0 when gh or python3 is missing from PATH" {  # PATH に gh が無い・python3 が無いときも無出力で 0
  hook_json "$GRANT_LITERAL" > "$WORK/payload.json"
  mkdir -p "$WORK/nogh" "$WORK/nopy"
  for t in cat dirname; do ln -s "$(command -v "$t")" "$WORK/nogh/$t"; ln -s "$(command -v "$t")" "$WORK/nopy/$t"; done
  ln -s "$REAL_PYTHON" "$WORK/nogh/python3"
  ln -s "$WORK/bin/gh" "$WORK/nopy/gh"
  local bash_bin; bash_bin="$(command -v bash)"
  run env PATH="$WORK/nogh" "$bash_bin" "$SCRIPT" < "$WORK/payload.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run env PATH="$WORK/nopy" "$bash_bin" "$SCRIPT" < "$WORK/payload.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_write
}

@test "gate-report: silent exit 0 on broken JSON" {  # 壊れた JSON でも無出力で 0
  printf '%s' '{"tool_input": {"command": "gh api -X POST repos/o/r/issues/1/labels -f labels[]=agent-review:passed' > "$WORK/payload.json"
  run bash "$SCRIPT" < "$WORK/payload.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
}

# --- 行を積むきっかけ（spec: cost-ledger-timeline） ---

@test "timeline-hook: the seven commands each add one row to the same comment" {  # PR に 4 種・issue に 3 種を順に流すと、それぞれ POST は最初の 1 回だけで、流すたびに行が 1 行ずつ増える
  run_hook "gh pr comment 300 --body x"
  [ "$(body_nrows)" -eq 1 ]
  run_hook "gh pr ready 300"
  [ "$(body_nrows)" -eq 2 ]
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh pr close 300"
  [ "$(body_nrows)" -eq 3 ]
  echo '{"state":"closed","merged":true}' > "$FIX/pull.300.json"
  run_hook "gh pr merge 300 --squash"
  [ "$(body_nrows)" -eq 4 ]
  [ "$(body_rows | awk -F'|' '{v=$3; sub(/^ /,"",v); sub(/ $/,"",v); printf "%s,", v}')" = "PR コメント,Ready,PR クローズ,マージ," ]
  [ "$(grep -cF -- '-X POST repos/acme/cwd-repo/issues/300/comments' "$GH_LOG")" -eq 1 ]
  [ "$(patches)" -eq 3 ]

  touch "$FIX/nopull.12"
  run_hook "gh issue comment 12 --body x"
  [ "$(body_nrows)" -eq 1 ]
  echo '{"state":"closed"}' > "$FIX/issue.12.json"
  run_hook "gh issue close 12"
  [ "$(body_nrows)" -eq 2 ]
  echo '{"state":"open"}' > "$FIX/issue.12.json"
  run_hook "gh issue reopen 12"
  [ "$(body_nrows)" -eq 3 ]
  [ "$(body_rows | awk -F'|' '{v=$3; sub(/^ /,"",v); sub(/ $/,"",v); printf "%s,", v}')" = "issue コメント,issue クローズ,issue 再オープン," ]
  [ "$(grep -cF -- '-X POST repos/acme/cwd-repo/issues/12/comments' "$GH_LOG")" -eq 1 ]
  [ "$(patches)" -eq 5 ]
}

@test "timeline-hook: gh commands outside the table add nothing" {  # gh pr view・gh pr create・gh pr reopen・gh issue view では積まない
  for c in "gh pr view 300" "gh pr create --title x --body 'gh pr comment 300'" "gh pr reopen 300" "gh issue view 12"; do
    run_hook "$c"
    [ "$status" -eq 0 ]
    no_gh_call
  done
}

@test "timeline-hook: a command that only contains the text adds nothing" {  # echo \"gh pr comment 300 --body x\" のように文字列として含むだけでは積まない
  run_hook 'echo "gh pr comment 300 --body x"'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
  run_hook "git commit -m 'gh issue close 12 を足す'"
  no_gh_call
}

@test "timeline-hook: several triggers for one target make one row joined with +" {  # gh pr comment 300 && gh pr ready 300 は 1 行で、きっかけは PR コメント+Ready
  run_hook "gh pr comment 300 --body x && gh pr ready 300"
  [ "$(posts)" -eq 1 ]
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "PR コメント+Ready" ]
  [ "$(gh_calls)" -eq 3 ]
}

@test "timeline-hook: gh pr ready --undo adds nothing" {  # gh pr ready --undo は対象外
  run_hook "gh pr ready 300 --undo"
  no_gh_call
  run_hook "gh pr ready --undo 300"
  no_gh_call
}

# --- 対象の解決 ---

@test "timeline-hook: a number targets the cwd repository" {  # gh pr comment 300 は cwd のリポジトリの #300（repos/{owner}/{repo}/pulls/300 を cwd で問い合わせる）
  run_hook "gh pr comment 300 --body x"
  queried '\{owner\}/\{repo\}' 300
  grep -qxF "$(cd "$CWD" && pwd -P)" "$GH_LOG.cwd"
  ! grep -q '^repo ' "$GH_LOG" || return 1
  posted_to acme/cwd-repo 300
}

@test "timeline-hook: a URL targets that repository and number" {  # issue の URL を渡すと acme/other の #12 が対象になる（timeline の --target-repo に渡る）
  touch "$FIX/nopull.12"
  run_hook "gh issue comment https://github.com/acme/other/issues/12 --body x"
  queried acme/other 12
  asked_timeline acme/other issue 12
  : > "$GH_LOG"
  run_hook "gh pr comment https://github.com/acme/other/pull/301 --body x"
  queried acme/other 301
  asked_timeline acme/other pr 301
  : > "$GH_LOG"
  run_hook "gh pr comment https://example.com/acme/other/pull/302 --body x"
  no_gh_call
}

@test "timeline-hook: an omitted number targets the PR of the cwd branch" {  # gh pr ready（番号なし）は cwd のブランチをヘッドに持つ PR #300 が対象になる
  export FAKE_HEAD_PR=300
  run_hook "gh pr ready"
  grep -qF 'repos/{owner}/{repo}/pulls?head={owner}:{branch}&state=all' "$GH_LOG"
  grep -qxF "$(cd "$CWD" && pwd -P)" "$GH_LOG.cwd"
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "Ready" ]
  [ "$(gh_calls)" -eq 3 ]
}

@test "timeline-hook: an omitted number with no PR for the branch adds nothing" {  # 番号なしで、そのブランチの PR が無ければ積まない。番号を省けるのは pr comment / ready / merge だけ
  run_hook "gh pr comment --body x"
  [ "$(gh_calls)" -eq 1 ]
  no_write
  : > "$GH_LOG"
  export FAKE_HEAD_PR=300
  run_hook "gh pr close"
  no_gh_call
  run_hook "gh issue comment --body x"
  no_gh_call
}

# cwd を acme/repo-a の git リポジトリにして、本物の cost_ledger.py を使う
use_real_repo_a() {
  use_real_cost_ledger
  RA="$WORK/ra"
  cl_init_repo "$RA" acme/repo-a
  export FAKE_CWD_REPO=acme/repo-a
}

@test "timeline-hook: -R points at another repository" {  # gh pr comment 300 -R acme/other は acme/other の #300 を対象として確かめるが、作業中のリポジトリではないので書かない
  use_real_repo_a
  HOOK_CWD="$RA" run_hook "gh pr comment 300 -R acme/other --body x"
  [ "$status" -eq 0 ]
  queried acme/other 300
  no_write
  : > "$GH_LOG"
  HOOK_CWD="$RA" run_hook "GH_REPO=acme/third gh pr comment 301 --body x"
  queried acme/third 301
  no_write
  : > "$GH_LOG"
  HOOK_CWD="$RA" run_hook "gh pr comment --repo=acme/fourth 302 --body x"
  queried acme/fourth 302
  no_write
}

@test "timeline-hook: a PR in another repository gets nothing" {  # cwd が acme/repo-a で、別リポジトリの PR の URL・ゲート通過の付与は書かない（cwd のリポジトリの PR には書く）
  use_real_repo_a
  HOOK_CWD="$RA" run_hook "gh pr comment https://github.com/acme/repo-b/pull/300 --body x"
  [ "$status" -eq 0 ]
  queried acme/repo-b 300
  no_write
  : > "$GH_LOG"
  HOOK_CWD="$RA" run_hook "gh pr edit 300 -R acme/repo-b --add-label agent-review:passed"
  queried acme/repo-b 300
  no_write
  : > "$GH_LOG"
  HOOK_CWD="$RA" run_hook "gh pr comment 300 --body x"
  posted_to acme/repo-a 300
  head -n 1 "$GH_LOG.body" | grep -qF 'コスト: $1.00 / ¥150 @150 — PR #300 (oratta/sample) 帰属: ブランチ'
}

@test "timeline-hook: -R naming the cwd repository itself still adds a row" {  # gh pr comment 300 -R acme/repo-a を acme/repo-a の中で実行したら、今までどおり積む
  use_real_repo_a
  HOOK_CWD="$RA" run_hook "gh pr comment 300 -R acme/repo-a --body x"
  [ "$status" -eq 0 ]
  queried acme/repo-a 300
  posted_to acme/repo-a 300
  head -n 1 "$GH_LOG.body" | grep -qF 'コスト: $1.00 / ¥150 @150 — PR #300 (oratta/sample) 帰属: ブランチ'
  [ "$(body_nrows)" -eq 1 ]
}

@test "timeline-hook: a number that cannot be resolved is skipped" {  # コマンド置換・未定義の変数・ブランチ名の位置引数は積まずに飛ばす
  run_hook 'gh pr comment "$(gh pr view --json number -q .number)" --body x'
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook 'gh pr comment "$PR" --body x'
  no_gh_call
  run_hook 'gh pr comment feat/branch --body x'
  no_gh_call
  run_hook 'gh pr merge acme:feat/branch --squash'
  no_gh_call
}

@test "timeline-hook: option values are not mistaken for the number" {  # --body・-b・-F・-c・-t の値を位置引数と取り違えない。pr merge の -m / -r / -s / -d は値を取らない
  run_hook "gh pr comment --body 999 300"
  posted_to acme/cwd-repo 300
  ! queried '\{owner\}/\{repo\}' 999 || return 1
  : > "$GH_LOG"
  echo '{"state":"closed"}' > "$FIX/pull.301.json"
  run_hook "gh pr close -c 999 301"
  posted_to acme/cwd-repo 301
  : > "$GH_LOG"
  echo '{"state":"closed","merged":true}' > "$FIX/pull.302.json"
  run_hook "gh pr merge -s -d 302 -t 999"
  posted_to acme/cwd-repo 302
  ! queried '\{owner\}/\{repo\}' 999 || return 1
}

@test "timeline-hook: variables and for loops resolve like the grant detection" {  # 同じコマンドの中の代入と for の展開で番号を解決する
  run_hook "N=300; gh pr comment \$N --body x"
  posted_to acme/cwd-repo 300
  : > "$GH_LOG"
  run_hook "for N in 96 97; do gh pr comment \$N -R oratta/kg-recruit --body x; done"
  asked_timeline oratta/kg-recruit pr 96
  asked_timeline oratta/kg-recruit pr 97
}

@test "timeline-hook: an issue command given a PR number is treated as a PR" {  # gh issue comment 300 の番号が PR なら PR として扱う（きっかけは PR コメント、gh は 4 回）
  run_hook "gh issue comment 300 --body x"
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "PR コメント" ]
  grep -qE "^args=timeline --pr 300 --branch oratta/sample " "$COST_LOG"
  [ "$(gh_calls)" -eq 4 ]
}

@test "timeline-hook: gh issue close on a PR number is a PR close" {  # gh issue close 300 の番号が PR なら PR クローズとして、PR の state を確かめてから積む
  run_hook "gh issue close 300"
  no_write
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  : > "$GH_LOG"
  run_hook "gh issue close 300"
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "PR クローズ" ]
  grep -qE "^args=timeline --pr 300 --branch oratta/sample " "$COST_LOG"
}

@test "timeline-hook: gh issue reopen on a PR number adds nothing" {  # gh issue reopen 300 の番号が PR なら積まない（PR の再オープンはきっかけの表に無い）
  run_hook "gh issue reopen 300"
  [ "$status" -eq 0 ]
  no_write
  [ ! -e "$COST_LOG" ]
  run_hook "gh issue comment 300 --body x; gh issue reopen 300"
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "PR コメント" ]
}

# --- 状態の変更は実測してから積む ---

@test "timeline-hook: no row when the PR is not merged" {  # gh pr merge 300 --auto でマージ済みでなければ積まない
  run_hook "gh pr merge 300 --auto"
  [ "$status" -eq 0 ]
  queried '\{owner\}/\{repo\}' 300
  no_write
  [ ! -e "$COST_LOG" ]
}

@test "timeline-hook: no row when the close did not happen" {  # gh issue close 12 で state が open のままなら積まない。PR のクローズ・Ready・再オープンも同じ
  touch "$FIX/nopull.12"
  run_hook "gh issue close 12"
  no_write
  run_hook "gh pr close 300"
  no_write
  echo '{"draft":true}' > "$FIX/pull.300.json"
  run_hook "gh pr ready 300"
  no_write
  echo '{"state":"closed"}' > "$FIX/issue.12.json"
  run_hook "gh issue reopen 12"
  no_write
}

@test "timeline-hook: no row for a number that does not exist" {  # gh pr comment 999 で #999 の問い合わせが失敗したら積まない
  touch "$FIX/missing.999"
  run_hook "gh pr comment 999 --body x"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_write
  run_hook "gh issue comment 999 --body x"
  no_write
}

@test "timeline-hook: only the triggers whose state holds are kept" {  # 複合コマンドのうち、状態が確かめられたきっかけだけを行に残す
  run_hook "gh pr comment 300 --body x && gh pr merge 300 --auto"
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "PR コメント" ]
}

@test "timeline-hook: an issue in another repository gets nothing" {  # cwd が acme/repo-a で gh issue comment 12 -R acme/repo-b は書かない（cwd のリポジトリの issue には書く）
  use_real_cost_ledger
  RA="$WORK/ra"
  cl_init_repo "$RA" acme/repo-a
  cl_row S2 i1 2026-09-01T00:00:10.000Z main "$RA" 1000000 "gh issue view 12" | cl_write_log issue
  export FAKE_CWD_REPO=acme/repo-a
  touch "$FIX/nopull.12"
  HOOK_CWD="$RA" run_hook "gh issue comment 12 -R acme/repo-b --body x"
  [ "$status" -eq 0 ]
  queried acme/repo-b 12
  no_write
  : > "$GH_LOG"
  HOOK_CWD="$RA" run_hook "gh issue comment 12 --body x"
  posted_to acme/repo-a 12
  head -n 1 "$GH_LOG.body" | grep -qF 'コスト: $1.00 / ¥150 @150 — issue #12 (acme/repo-a) 帰属: 区間'
}

# --- hook は判定だけをして、残りを裏で行う ---

wait_for_workers() {  # 裏のプロセスが終わるまで待つ（最大 30 秒）
  local i
  for i in $(seq 1 150); do
    pgrep -f "$WORK/scripts/gate_report.py" >/dev/null 2>&1 || return 0
    sleep 0.2
  done
  return 1
}

@test "timeline-hook: the hook returns at once and the comment is written afterwards" {  # gh が 1 回 3 秒かかっても hook は 1 秒未満で終わり、そのあとでコメントが作られる。stdout と stderr は空
  unset COST_LEDGER_HOOK_FOREGROUND
  export FAKE_GH_DELAY=3
  hook_json "gh pr comment 300 --body x" > "$WORK/payload.json"
  start="$(now)"
  run bash "$SCRIPT" < "$WORK/payload.json"
  end="$(now)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  "$REAL_PYTHON" -c 'import sys; sys.exit(0 if float(sys.argv[2]) - float(sys.argv[1]) < 1.0 else 1)' "$start" "$end" \
    || { echo "hook took $start -> $end"; return 1; }
  [ "$(posts)" -eq 0 ]              # hook が終わった時点ではまだ書かれていない
  wait_for_workers
  posted_to acme/cwd-repo 300
  [ "$(body_nrows)" -eq 1 ]
}

@test "timeline-hook: the hook prints nothing on stdout or stderr" {  # きっかけの hook JSON を流しても stdout と stderr は空（裏でも表でも）
  hook_json "gh pr comment 300 --body x" > "$WORK/payload.json"
  bash "$SCRIPT" < "$WORK/payload.json" > "$WORK/stdout" 2> "$WORK/stderr"
  [ ! -s "$WORK/stdout" ]
  [ ! -s "$WORK/stderr" ]
  unset COST_LEDGER_HOOK_FOREGROUND
  bash "$SCRIPT" < "$WORK/payload.json" > "$WORK/stdout" 2> "$WORK/stderr"
  [ ! -s "$WORK/stdout" ]
  [ ! -s "$WORK/stderr" ]
  wait_for_workers
}

@test "timeline-hook: COST_LEDGER_HOOK_FOREGROUND=1 finishes the write before the hook returns" {  # その場で実行すると、hook が終わった時点で書き込みが済んでいる
  export FAKE_GH_DELAY=0.3
  run_hook "gh pr comment 300 --body x"
  [ "$status" -eq 0 ]
  [ "$(posts)" -eq 1 ]
  ! pgrep -f "$WORK/scripts/gate_report.py" >/dev/null 2>&1 || return 1
}

# --- 同じコメントへの同時の書き込みで行を失わない ---

@test "timeline-hook: two triggers at once end up as one comment with two rows" {  # きっかけの違う 2 つを同時に流すと、コメントは 1 本で表は 2 行
  use_real_cost_ledger
  cl_init_repo "$CWD" acme/cwd-repo        # 対象（acme/cwd-repo）が作業中のリポジトリでなければ積まれない
  export FAKE_GH_DELAY=0.2
  hook_json "gh pr comment 300 --body x" > "$WORK/p1.json"
  hook_json "gh pr ready 300" > "$WORK/p2.json"
  bash "$SCRIPT" < "$WORK/p1.json" &
  bash "$SCRIPT" < "$WORK/p2.json" &
  wait
  [ "$(posts)" -eq 1 ]
  [ "$(patches)" -eq 1 ]
  [ "$("$REAL_PYTHON" -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$FIX/comments.300.9.json")" -eq 1 ]
  [ "$(body_nrows)" -eq 2 ]
}

@test "timeline-hook: a trigger whose check was slow still lands above the later one" {  # 先に流した方の「対象の確認」だけが遅れて後の方が先に書いても、両方が終わると先に流したきっかけの行が上にある
  use_real_cost_ledger
  cl_init_repo "$CWD" acme/cwd-repo        # 対象（acme/cwd-repo）が作業中のリポジトリでなければ積まれない
  hook_json "gh pr comment 300 --body x" > "$WORK/p1.json"
  hook_json "gh pr ready 300" > "$WORK/p2.json"
  FAKE_GH_CONFIRM_DELAY=3 bash "$SCRIPT" < "$WORK/p1.json" &
  first=$!
  sleep 0.5
  bash "$SCRIPT" < "$WORK/p2.json"
  # 後に流した方が先に書き込んだ
  [ "$(posts)" -eq 1 ]
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "Ready" ]
  wait "$first"
  [ "$(posts)" -eq 1 ]
  [ "$(patches)" -eq 1 ]
  [ "$(body_nrows)" -eq 2 ]
  [ "$(body_trigger 1)" = "PR コメント" ]
  [ "$(body_trigger 2)" = "Ready" ]
  body_rows | sed -n 1p | grep -qF '$1.00 (+1.00)'
  body_rows | sed -n 2p | grep -qF '$1.00 (+0.00)'
}

# --- gh の呼び出し回数 ---

@test "timeline-hook: one row costs three gh calls" {  # gh pr comment 300 で gh が呼ばれるのは 3 回（対象の確認・既存コメントの取得・書き込み）。行が積まれていても同じ
  run_hook "gh pr comment 300 --body x"
  [ "$(gh_calls)" -eq 3 ]
  : > "$GH_LOG"
  run_hook "gh pr ready 300"
  run_hook "gh pr comment 300 --body y"
  [ "$(gh_calls)" -eq 6 ]
}

@test "timeline-hook: two targets cost six gh calls" {  # gh issue comment 12; gh pr comment 300 で gh が呼ばれるのは 6 回
  touch "$FIX/nopull.12"
  run_hook "gh issue comment 12 --body x; gh pr comment 300 --body y"
  [ "$(gh_calls)" -eq 6 ]
  posted_to acme/cwd-repo 12
  posted_to acme/cwd-repo 300
}

@test "timeline-hook: closing an issue costs four gh calls whatever the number of PRs" {  # closedByPullRequestsReferences が PR を 3 件返す issue #12 に gh issue close 12 → gh は 4 回（対象の確認・閉じた PR の問い合わせ・既存コメントの取得・書き込み）。0 件でも 4 回
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x),$(closing_node 705 feat/y),$(closing_node 706 feat/z)]"
  run_hook "gh issue close 12"
  [ "$(gh_calls)" -eq 4 ]
  [ "$(graphql_calls)" -eq 1 ]
  [ "$(closing_args)" = "704:feat/x 705:feat/y 706:feat/z" ]
  : > "$GH_LOG"
  unset FAKE_CLOSING_PRS
  run_hook "gh issue close 12"
  [ "$(gh_calls)" -eq 4 ]
}

# --- ロックの置き場（共有の /tmp に他人が先に作った場所へ書かない） ---

@test "timeline-hook: nothing is written when the lock directory is a symlink" {  # ロックの置き場がシンボリックリンクなら、たどらずに書かない（リンク先にロックファイルを作らない）
  mkdir -p "$WORK/elsewhere"
  ln -s "$WORK/elsewhere" "$TMPDIR/cost-ledger-timeline"
  run_hook "gh pr comment 300 --body x"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(posts)" -eq 0 ]
  [ "$(patches)" -eq 0 ]
  [ -z "$(ls -A "$WORK/elsewhere")" ]
}

@test "timeline-hook: nothing is written when others can write to the lock directory" {  # ロックの置き場に自分以外が書ける（group / other に書き込み権限がある）なら書かない
  mkdir -p "$TMPDIR/cost-ledger-timeline"
  chmod 777 "$TMPDIR/cost-ledger-timeline"
  run_hook "gh pr comment 300 --body x"
  [ "$status" -eq 0 ]
  [ "$(posts)" -eq 0 ]
  [ "$(patches)" -eq 0 ]
}

@test "timeline-hook: the lock directory is created for the owner only" {  # ロックの置き場は自分だけが読み書きできる権限（700）で作り、そこを使って積む
  run_hook "gh pr comment 300 --body x"
  [ "$(posts)" -eq 1 ]
  [ "$(python3 -B -c 'import os,stat,sys; print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode))[2:])' "$TMPDIR/cost-ledger-timeline")" = "700" ]
}

# --- issue クローズでの、閉じた PR の問い合わせ（合計の行） ---

@test "timeline-hook: closing an issue passes its closing PRs to timeline" {  # PR #704（feat/x、同じリポジトリ）を返す issue #12 に gh issue close 12 → timeline は --issue 12 と --closing-pr 704:feat/x を受け取り、コメントが 1 本書き込まれる
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x)]"
  run_hook "gh issue close 12"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  asked_timeline acme/cwd-repo issue 12
  [ "$(closing_args)" = "704:feat/x" ]
  [ "$(posts)" -eq 1 ]
  [ "$(graphql_calls)" -eq 1 ]
  # 問い合わせは github.com に固定し、owner・name・number は変数で渡す（問い合わせの文字列に埋め込まない）
  grep -qE -- '^api graphql .*--hostname github\.com$' "$GH_LOG"
  grep -qxF 'owner=acme' "$GH_LOG.graphql.fields"
  grep -qxF 'name=cwd-repo' "$GH_LOG.graphql.fields"
  grep -qxF 'number=12' "$GH_LOG.graphql.fields"
  grep '^query=' "$GH_LOG.graphql.fields" | grep -qF 'closedByPullRequestsReferences(first: 100)'
  ! grep '^query=' "$GH_LOG.graphql.fields" | grep -qE 'acme|cwd-repo' || return 1
}

@test "timeline-hook: no --closing-pr when no PR closed the issue" {  # 0 件を返す issue #12 → --closing-pr は渡らず、コメントは 1 本書き込まれる
  closed_issue_12
  run_hook "gh issue close 12"
  asked_timeline acme/cwd-repo issue 12
  [ -z "$(closing_args)" ]
  [ "$(graphql_calls)" -eq 1 ]
  [ "$(posts)" -eq 1 ]
  [ "$(body_trigger 1)" = "issue クローズ" ]
}

@test "timeline-hook: the close row is still stacked when the closing-PR query fails" {  # GraphQL だけが失敗する → --closing-pr は渡らず、コメントは 1 本書き込まれる。応答が JSON でない場合も同じ
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x)]" FAKE_GRAPHQL_FAIL=1
  run_hook "gh issue close 12"
  [ "$(graphql_calls)" -eq 1 ]
  [ -z "$(closing_args)" ]
  [ "$(posts)" -eq 1 ]
  unset FAKE_GRAPHQL_FAIL
  for raw in 'not json' '[]' '{"data":{"repository":{"issue":null}}}' '{"data":{"repository":{"issue":{"closedByPullRequestsReferences":{"nodes":[{"number":704,"headRefName":"feat/x","isCrossRepository":false,"baseRepository":{"nameWithOwner":"acme/cwd-repo"}}]}}}}}'; do
    : > "$COST_LOG"
    FAKE_GRAPHQL_RAW="$raw" run_hook "gh issue close 12"
    [ -z "$(closing_args)" ] || { echo "$raw"; return 1; }
    grep -q '^args=timeline --issue 12 ' "$COST_LOG" || { echo "$raw"; return 1; }
  done
}

@test "timeline-hook: PRs of another repository and PRs from a fork are not counted" {  # #704（同じリポジトリ）・#9（ベースが別のリポジトリ）・#705（isCrossRepository が真）→ --closing-pr は 704:feat/x だけ
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x),$(closing_node 9 main acme/other),$(closing_node 705 main acme/cwd-repo true)]"
  run_hook "gh issue close 12"
  [ "$(closing_args)" = "704:feat/x" ]
  [ "$(posts)" -eq 1 ]
  # ベースのリポジトリの大文字と小文字は区別しない
  : > "$COST_LOG"
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x Acme/CWD-Repo)]"
  run_hook "gh issue close 12"
  [ "$(closing_args)" = "704:feat/x" ]
  # 全部外れたら --closing-pr は渡らない
  : > "$COST_LOG"
  export FAKE_CLOSING_PRS="[$(closing_node 9 main acme/other)]"
  run_hook "gh issue close 12"
  [ -z "$(closing_args)" ]
  grep -q '^args=timeline --issue 12 ' "$COST_LOG"
}

@test "timeline-hook: more than 100 closing PRs add no total" {  # pageInfo.hasNextPage が真 → --closing-pr は渡らず、コメントは 1 本書き込まれる
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x)]" FAKE_CLOSING_NEXT=1
  run_hook "gh issue close 12"
  [ -z "$(closing_args)" ]
  [ "$(posts)" -eq 1 ]
}

@test "timeline-hook: a malformed closing PR drops them all" {  # number が文字列・headRefName が空・真偽値でない isCrossRepository など、1 件でも形が崩れていれば --closing-pr を渡さず、節目の行は積む
  closed_issue_12
  good="$(closing_node 704 feat/x)"
  for bad in '{"number":"705","headRefName":"feat/y","isCrossRepository":false,"baseRepository":{"nameWithOwner":"acme/cwd-repo"}}' \
             '{"number":705,"headRefName":"","isCrossRepository":false,"baseRepository":{"nameWithOwner":"acme/cwd-repo"}}' \
             '{"number":705,"headRefName":"feat/y","isCrossRepository":"no","baseRepository":{"nameWithOwner":"acme/cwd-repo"}}' \
             '{"number":705,"headRefName":"feat/y","isCrossRepository":false,"baseRepository":null}' \
             '{"number":0,"headRefName":"feat/y","isCrossRepository":false,"baseRepository":{"nameWithOwner":"acme/cwd-repo"}}' \
             '{"number":true,"headRefName":"feat/y","isCrossRepository":false,"baseRepository":{"nameWithOwner":"acme/cwd-repo"}}' \
             'null'; do
    : > "$COST_LOG"
    rm -f "$FIX"/comments.12.*.json
    FAKE_CLOSING_PRS="[$good,$bad]" run_hook "gh issue close 12"
    [ -z "$(closing_args)" ] || { echo "$bad"; return 1; }
    [ "$(body_trigger 1)" = "issue クローズ" ] || { echo "$bad"; return 1; }
  done
}

@test "timeline-hook: triggers other than an issue close do not query closing PRs" {  # gh issue comment 12・gh issue reopen 12・PR 向けのきっかけでは GraphQL は 0 回
  touch "$FIX/nopull.12"
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x)]"
  run_hook "gh issue comment 12 --body x"
  [ "$(posts)" -eq 1 ]
  run_hook "gh issue reopen 12"
  run_hook "gh pr comment 300 --body x"
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh pr close 300"
  [ "$(graphql_calls)" -eq 0 ]
  ! grep -qF -- '--closing-pr' "$COST_LOG" || return 1
}

@test "timeline-hook: gh issue close on a PR number does not query closing PRs" {  # PR である #300 に gh issue close 300 → GraphQL は 0 回で、行のきっかけは PR クローズ
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x)]"
  run_hook "gh issue close 300"
  [ "$(posts)" -eq 1 ]
  [ "$(body_trigger 1)" = "PR クローズ" ]
  [ "$(graphql_calls)" -eq 0 ]
  ! grep -qF -- '--closing-pr' "$COST_LOG" || return 1
}

@test "timeline-hook: a comment and a close in one command still query closing PRs" {  # gh issue comment 12 --body x && gh issue close 12（きっかけは issue コメント+issue クローズ）でも問い合わせる
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x)]"
  run_hook "gh issue comment 12 --body x && gh issue close 12"
  [ "$(body_trigger 1)" = "issue コメント+issue クローズ" ]
  [ "$(graphql_calls)" -eq 1 ]
  [ "$(closing_args)" = "704:feat/x" ]
  [ "$(gh_calls)" -eq 4 ]
}

@test "timeline-hook: nothing is queried or written when the comment lookup fails" {  # 既存コメントの取得が失敗したら、閉じた PR があっても書かない
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x)]" FAKE_COMMENTS_FAIL=1
  run_hook "gh issue close 12"
  no_write
  [ ! -s "$COST_LOG" ]
}

@test "timeline-hook: the real timeline stacks the close row and the total row" {  # 本物の cost_ledger.py で、gh issue close 12 が issue クローズの行と合計の行の 2 行を 1 回の書き込みで積む
  use_real_repo_a
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 oratta/sample acme/repo-a)]"
  HOOK_CWD="$RA" run_hook "gh issue close 12"
  [ "$(posts)" -eq 1 ]
  [ "$(body_nrows)" -eq 2 ]
  [ "$(body_trigger 1)" = "issue クローズ" ]
  [ "$(body_trigger 2)" = '合計（#704 $1.00 + PR 外 $0.00）' ]
  head -n 1 "$GH_LOG.body" | grep -qF '帰属: 区間+閉じた PR'
}
