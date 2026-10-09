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
  for f in gate_report.py write_allow.py; do
    if [ -f "$PLUGIN_DIR/scripts/$f" ]; then cp "$PLUGIN_DIR/scripts/$f" "$WORK/scripts/$f"; fi
  done
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
  # GitHub に書くのは許可の一覧に載っているリポジトリだけ（spec cost-ledger-write-allowlist）。
  # このファイルのテストは「一覧に載っている」前提の動きを固定するので、cwd を origin が
  # acme/cwd-repo の git リポジトリにし、テストが名指しするリポジトリを全部載せた一覧を cwd の外に置く。
  # 一覧に無いときの動きは write-allow.bats が固定する
  cl_init_repo "$CWD" acme/cwd-repo
  export HOME="$WORK/home"                  # 利用者の $HOME/.config/cost-ledger/write-repos を読まない
  export COST_LEDGER_WRITE_REPOS_FILE="$WORK/write-repos"
  write_allow_list
}

# 許可の一覧を作る。cwd のリポジトリ（acme/cwd-repo）と、このファイルのコマンドが名指しする
# リポジトリ（-R / --repo / GH_REPO= / シェル変数 R= / gh api のパス / github.com の URL）を、
# このファイル自身から拾って全部載せる。「対象の確認までは行い、書かない」ことを確かめるテストが
# 名指しする名前も入る。手で並べないのは、テストを足したときに載せ忘れないようにするため
write_allow_list() {
  {
    echo "acme/cwd-repo"
    grep -oE -- '(-R |--repo[ =]|GH_REPO=|R=|repos/|github\.com/)[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' \
      "$BATS_TEST_FILENAME" | sed -E 's/^(-R |--repo[ =]|GH_REPO=|R=|repos\/|github\.com\/)//' | sort -u
  } > "$COST_LEDGER_WRITE_REPOS_FILE"
  chmod 600 "$COST_LEDGER_WRITE_REPOS_FILE"
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
#                  既定は「open・draft でない・未マージ・合格ラベル付き・ヘッド oratta/sample・
#                  いま作られた（created_at が現在の時刻）PR」。pulls?head=... の問い合わせ文字列は
#                  $GH_LOG.query に書く（どのブランチで探したかを確かめる）。
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
    # emit() はこの下で定義されるので、ここでは使わない（問い合わせは --jq を付けない）
    sys.stdout.write(json.dumps(
        {"data": {"repository": {"issue": {"closedByPullRequestsReferences": refs}}}}) + "\n")
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
                     "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
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

# stub の timeline が最後に受け取った --trigger の値（無ければ空）
trigger_arg() {
  [ -f "$COST_LOG" ] || return 0
  tail -n 1 "$COST_LOG" | sed -n 's/^args=timeline .*--trigger \(.*\) --at [0-9.]*\( .*\)\{0,1\}$/\1/p'
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
            if h.get("command") == '"${CLAUDE_PLUGIN_ROOT}/scripts/gate-report.sh"']
assert len(handlers) == 1, handlers
h = handlers[0]
assert h.get("type") == "command", h
assert h.get("timeout") == 60, h
assert "async" not in h, h
assert all("if" not in e for e in entries) and "if" not in h, entries
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "gate-report: a Bash call with none of the trigger strings starts neither gh nor python3" {  # 10 個の文字列のどれも含まず、gh api の書き込みの形でもない Bash（gh pr view 300 を含む）では gh も python3 も起動せず、無出力で 0
  use_stub_python
  for c in "ls -la && git status" "gh pr view 300" "gh issue view 12 --comments" \
           "gh pr list" "gh issue edit 12 --add-label bug"; do
    run_hook "$c"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    no_gh_call
    [ ! -e "$WORK/log/python.log" ] || { echo "python3 started for: $c"; return 1; }
  done
}

@test "gate-report: a gh api read starts neither gh nor python3" {  # gh api の読み取り（書き込みを示すオプションが無い）3 形では gh も python3 も起動しない
  use_stub_python
  for c in "gh api repos/o/r/issues/300/comments" "gh api repos/o/r/pulls/300 --jq .state" \
           "gh api --paginate repos/o/r/issues/300/comments --jq '.[].body'"; do
    run_hook "$c"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    no_gh_call
    [ ! -e "$WORK/log/python.log" ] || { echo "python3 started for: $c"; return 1; }
  done
}

@test "gate-report: a gh api write outside /issues/ and /pulls/ starts neither gh nor python3" {  # /issues/ も /pulls/ も含まない gh api の書き込みでは python3 が起動しない
  use_stub_python
  run_hook "gh api -X POST repos/o/r/releases -f tag_name=v1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
  [ ! -e "$WORK/log/python.log" ]
}

@test "gate-report: each of the ten trigger strings passes the fast path" {  # 10 個の文字列のどれかを含めば python3 が起動する
  use_stub_python
  for c in "echo agent-review:passed" "gh pr create --title x" "gh pr comment 1" "gh pr ready 1" "gh pr close 1" \
           "gh pr reopen 300" "gh pr merge 1" "gh issue comment 1" "gh issue close 1" "gh issue reopen 1"; do
    command rm -f "$WORK/log/python.log"
    run_hook "$c"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -e "$WORK/log/python.log" ] || { echo "python3 not started for: $c"; return 1; }
  done
}

@test "gate-report: a gh api write under /issues/ or /pulls/ passes the fast path" {  # gh api の書き込み 4 形（フィールド・-X PATCH・-X PUT・--input）では python3 が起動する
  use_stub_python
  for c in "gh api repos/o/r/issues/300/comments -f body=x" "gh api -X PATCH repos/o/r/pulls/300 -f state=closed" \
           "gh api -X PUT repos/o/r/pulls/300/merge" "gh api repos/o/r/issues/300/comments --input body.json"; do
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

@test "gate-report: an owner or repo of . or .. is an unresolvable target and gh is never called" {  # -R の owner / repo のどちらかが . か .. なら解決できない対象として扱い、gh を呼ばない。名前の中に . を含むだけの指定は今までどおり対象の確認を行う
  run_hook "gh pr comment 1 -R a/.. --body x"
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook "gh pr comment 1 -R ../b --body x"
  no_gh_call
  run_hook "gh pr comment 1 -R ./b --body x"
  no_gh_call
  run_hook "gh pr comment 1 -R ./.. --body x"
  no_gh_call
  run_hook "GH_REPO=a/.. gh pr comment 1 --body x"
  no_gh_call
  run_hook "gh pr comment 1 -R my.org/my.repo --body x"
  queried my.org/my.repo 1
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

# --- gh api の呼び出しの読み方（spec: cost-ledger-timeline） ---

@test "gh-api: a call with a field or --input and no method is a POST" {  # メソッド省略＋フィールドは POST、--input だけでも POST（どちらもコメントの投稿として積む）
  run_hook "gh api repos/acme/cwd-repo/issues/300/comments -f body=x"
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "PR コメント" ]
  touch "$FIX/nopull.12"
  run_hook "gh api repos/acme/cwd-repo/issues/12/comments --input body.json"
  posted_to acme/cwd-repo 12
  [ "$(body_trigger 1)" = "issue コメント" ]
}

@test "gh-api: the value of --input is not read as the endpoint" {  # --input の値がラベルのパスの形でも拾わない（#5 だけが対象で #300 は問い合わせない）
  run_hook "gh api repos/acme/repo-a/issues/5/labels -X POST --input repos/acme/repo-a/issues/300/labels -f 'labels[]=agent-review:passed'"
  [ "$status" -eq 0 ]
  queried acme/repo-a 5
  ! queried acme/repo-a 300 || return 1
  ! grep -q 'issues/300' "$GH_LOG" || return 1
}

@test "gh-api: the values of --jq and -H are not read as the endpoint" {  # --jq・-H の値が endpoint の形でも、対象は最初の位置引数の #7 だけ
  echo '{"state":"closed","merged":true}' > "$FIX/pull.7.json"
  run_hook "gh api --jq repos/o/r/issues/300/comments -H repos/o/r/pulls/300/merge -X PUT repos/o/r/pulls/7/merge"
  [ "$status" -eq 0 ]
  queried o/r 7
  ! grep -q '/300' "$GH_LOG" || return 1
}

@test "gh-api: attached option values are read as one word" {  # -XPATCH・-fstate=closed・--method=PATCH・--raw-field=state=closed
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh api -XPATCH repos/acme/cwd-repo/pulls/300 -fstate=closed"
  posted_to acme/cwd-repo 300
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "PR クローズ" ]
  run_hook "gh api --method=PATCH repos/acme/cwd-repo/pulls/300 --raw-field=state=closed"
  [ "$(body_nrows)" -eq 2 ]
  [ "$(body_trigger 2)" = "PR クローズ" ]
}

@test "gh-api: state=closed inside another value is not a state change" {  # -f body='state=closed' と --jq state=closed は積まない
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/pulls/300 -f body='state=closed'"
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook "gh api -X PATCH repos/acme/cwd-repo/pulls/300 -f title=x --jq state=closed"
  no_gh_call
}

@test "gh-api: the last state field wins" {  # state のフィールドが複数あれば最後のものを使う
  run_hook "gh api -X PATCH repos/acme/cwd-repo/pulls/300 -f state=closed -f state=open"
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "PR 再オープン" ]
}

@test "gh-api: assignments in the same command are expanded" {  # R=...; N=... のあとの gh api -X PUT repos/\$R/pulls/\$N/merge
  echo '{"state":"closed","merged":true}' > "$FIX/pull.300.json"
  run_hook "R=acme/cwd-repo; N=300; gh api -X PUT repos/\$R/pulls/\$N/merge"
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "マージ" ]
}

@test "gh-api: a label name outside a field is not a grant" {  # --jq 'labels[]=agent-review:passed' は付与と見ない
  run_hook "gh api -X POST repos/acme/repo-a/issues/300/labels --jq 'labels[]=agent-review:passed'"
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook "gh api -X POST repos/acme/repo-a/issues/300/labels -f 'x=labels[]=agent-review:passed'"
  no_gh_call
}

@test "gh-api: a grant on a {owner}/{repo} endpoint targets the cwd repository" {  # repos/{owner}/{repo}/issues/300/labels は cwd のリポジトリの #300 への付与。前置きの GH_REPO があればそのリポジトリ。解決できなければ飛ばす
  run_hook "gh api repos/{owner}/{repo}/issues/300/labels -f 'labels[]=agent-review:passed'"
  queried '\{owner\}/\{repo\}' 300
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "ゲート通過" ]
  : > "$GH_LOG"
  run_hook "GH_REPO=oratta/other gh api repos/{owner}/{repo}/issues/300/labels -f 'labels[]=agent-review:passed'"
  queried oratta/other 300
  asked_timeline oratta/other pr 300
  : > "$GH_LOG"
  run_hook "GH_REPO=\$(cat r) gh api repos/{owner}/{repo}/issues/300/labels -f 'labels[]=agent-review:passed'"
  [ "$status" -eq 0 ]
  no_gh_call
}

@test "gh-api: a method that cannot be resolved is skipped" {  # -X \"\$M\"（M の代入がコマンドに無い）の呼び出しは飛ばし、gh を呼ばない。代入があれば解決する
  run_hook 'gh api -X "$M" repos/acme/cwd-repo/issues/300/comments -f body=x'
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook "gh api -X \"\$M\" repos/acme/cwd-repo/issues/300/labels -f 'labels[]=agent-review:passed'"
  no_gh_call
  run_hook 'M=post; gh api -X "$M" repos/acme/cwd-repo/issues/300/comments -f body=x'
  posted_to acme/cwd-repo 300
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

@test "timeline-hook: gh api calls, gh pr create and gh pr reopen each add one row to the same comment" {  # gh pr create・gh api のコメント投稿・gh api の PATCH state=closed・gh pr reopen・gh api の PUT merge を順に流すと、POST は最初の 1 回だけで、流すたびに行が 1 行ずつ増える
  export FAKE_HEAD_PR=300
  run_hook "gh pr create --title x --body y"
  [ "$(body_nrows)" -eq 1 ]
  run_hook "gh api repos/acme/cwd-repo/issues/300/comments -f body=x"
  [ "$(body_nrows)" -eq 2 ]
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/pulls/300 -f state=closed"
  [ "$(body_nrows)" -eq 3 ]
  echo '{"state":"open"}' > "$FIX/pull.300.json"
  run_hook "gh pr reopen 300"
  [ "$(body_nrows)" -eq 4 ]
  echo '{"state":"closed","merged":true}' > "$FIX/pull.300.json"
  run_hook "gh api -X PUT repos/acme/cwd-repo/pulls/300/merge"
  [ "$(body_nrows)" -eq 5 ]
  [ "$(body_rows | awk -F'|' '{v=$3; sub(/^ /,"",v); sub(/ $/,"",v); printf "%s,", v}')" = "PR 作成,PR コメント,PR クローズ,PR 再オープン,マージ," ]
  [ "$(grep -cF -- '-X POST repos/acme/cwd-repo/issues/300/comments' "$GH_LOG")" -eq 1 ]
  [ "$(patches)" -eq 4 ]
}

@test "timeline-hook: gh api calls on an issue each add one row" {  # PR でない issue #12 への gh api のコメント投稿・state=closed・state=open で、きっかけは issue コメント・issue クローズ・issue 再オープン
  touch "$FIX/nopull.12"
  run_hook "gh api repos/acme/cwd-repo/issues/12/comments -f body=x"
  [ "$(body_nrows)" -eq 1 ]
  echo '{"state":"closed"}' > "$FIX/issue.12.json"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/issues/12 -f state=closed"
  [ "$(body_nrows)" -eq 2 ]
  echo '{"state":"open"}' > "$FIX/issue.12.json"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/issues/12 -f state=open"
  [ "$(body_nrows)" -eq 3 ]
  [ "$(body_rows | awk -F'|' '{v=$3; sub(/^ /,"",v); sub(/ $/,"",v); printf "%s,", v}')" = "issue コメント,issue クローズ,issue 再オープン," ]
  [ "$(grep -cF -- '-X POST repos/acme/cwd-repo/issues/12/comments' "$GH_LOG")" -eq 1 ]
  [ "$(patches)" -eq 2 ]
}

@test "timeline-hook: gh commands outside the table add nothing" {  # gh pr view・gh issue view・gh pr list・gh api graphql では積まない
  for c in "gh pr view 300" "gh issue view 12" "gh pr list --search 'gh pr comment 300'" \
           "gh api graphql -f query='mutation { closePullRequest(input: {pullRequestId: \"x\"}) { clientMutationId } }' -f path=/pulls/300"; do
    run_hook "$c"
    [ "$status" -eq 0 ]
    no_gh_call
  done
}

@test "timeline-hook: one gh api trigger makes exactly one write" {  # 目印付きのコメントが無い PR #300 に gh api のコメント投稿を 1 回流すと、新規作成 1 回・書き換え 0 回・表の行 1 行（hook の書き込みを受けてもう 1 回動かない）
  run_hook "gh api repos/acme/cwd-repo/issues/300/comments -f body=x"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(posts)" -eq 1 ]
  [ "$(patches)" -eq 0 ]
  [ "$(body_nrows)" -eq 1 ]
  [ "$(gh_calls)" -eq 4 ]
}

@test "timeline-hook: a command shaped like the hook's own PATCH adds nothing" {  # hook の書き換えと同じ形（issues/comments/<id> への PATCH）を Bash で流しても gh は 1 回も呼ばれない
  run_hook "gh api -X PATCH repos/acme/cwd-repo/issues/comments/900 --input -"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
}

@test "timeline-hook: gh api reads add nothing" {  # gh api の GET（メソッド省略で書き込みのオプション無し・-X GET にフィールド）では gh が 1 回も呼ばれない
  for c in "gh api repos/acme/cwd-repo/issues/300/comments" "gh api repos/acme/cwd-repo/pulls/300 --jq .state" \
           "gh api --paginate repos/acme/cwd-repo/issues/300/comments --jq '.[].body'" \
           "gh api -X GET repos/acme/cwd-repo/issues/300/comments -f per_page=100" \
           "gh api --method get repos/acme/cwd-repo/pulls/300 -f state=closed"; do
    run_hook "$c"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    no_gh_call || { echo "gh called for: $c"; return 1; }
  done
}

@test "timeline-hook: a PATCH that does not change state adds nothing" {  # state のフィールドが無い PATCH（タイトルの編集・--input で本文を渡したもの）では gh が 1 回も呼ばれない
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  for c in "gh api -X PATCH repos/acme/cwd-repo/pulls/300 -f title=x" \
           "gh api -X PATCH repos/acme/cwd-repo/issues/12 --input body.json" \
           "gh api -X PATCH repos/acme/cwd-repo/pulls/300 --input body.json" \
           "gh api -X PATCH repos/acme/cwd-repo/pulls/300 -f state=merged"; do
    run_hook "$c"
    [ "$status" -eq 0 ]
    no_gh_call || { echo "gh called for: $c"; return 1; }
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

@test "timeline-hook: gh pr create targets the PR of the cwd branch" {  # gh pr create は cwd のブランチをヘッドに持つ、作られたばかりの PR #300 が対象になる（きっかけは PR 作成）
  export FAKE_HEAD_PR=300
  run_hook "gh pr create --draft --title x --body y"
  grep -qF 'repos/{owner}/{repo}/pulls?head={owner}:{branch}&state=all' "$GH_LOG"
  posted_to acme/cwd-repo 300
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "PR 作成" ]
  grep -qE "^args=timeline --pr 300 --branch oratta/sample " "$COST_LOG"
}

@test "timeline-hook: gh pr create --head looks up that branch" {  # --head feat/x・--head=feat/x・-H feat/x・-Hfeat/x は、cwd のブランチではなく feat/x で問い合わせる。-R があればそのリポジトリ
  export FAKE_HEAD_PR=300
  for c in "gh pr create --draft --head feat/x --base main --title x --body y" "gh pr create --head=feat/x --title x" \
           "gh pr create -H feat/x --title x" "gh pr create -Hfeat/x --title x"; do
    : > "$GH_LOG"
    run_hook "$c"
    grep -qF 'repos/{owner}/{repo}/pulls?head={owner}:feat/x&state=all' "$GH_LOG" || { echo "not looked up by feat/x: $c"; return 1; }
    ! grep -qF '{branch}' "$GH_LOG" || return 1
    # 1 回目は新規作成、2 回目からは stub に残ったコメントの書き換えになる
    [ "$(( $(posts) + $(patches) ))" -eq 1 ] || { echo "no row written: $c"; return 1; }
  done
  : > "$GH_LOG"
  run_hook "gh pr create -R acme/other --head feat/x --title x"
  grep -qF 'repos/acme/other/pulls?head=acme:feat/x&state=all' "$GH_LOG"
}

@test "timeline-hook: gh pr create that makes no PR, or names another owner's branch, is skipped" {  # --head owner:branch・解決できない --head・ブランチ名に使えない文字・--dry-run・-w / --web は gh を呼ばない
  export FAKE_HEAD_PR=300
  for c in "gh pr create --head someone:feat/x --title x --body y" 'gh pr create --head "$(git branch --show-current)" --title x' \
           'gh pr create --head "$B" --title x' "gh pr create --head 'feat/x&state=open' --title x" \
           "gh pr create --dry-run --title x" "gh pr create --web" "gh pr create -w" "gh pr create --title x --web=true"; do
    run_hook "$c"
    [ "$status" -eq 0 ]
    no_gh_call || { echo "gh called for: $c"; return 1; }
  done
}

@test "timeline-hook: option values of gh pr create are not mistaken for flags" {  # --title・--body・-l などの値が --dry-run や --web でも、PR を作るコマンドとして積む
  export FAKE_HEAD_PR=300
  run_hook "gh pr create --title --dry-run --body --web -l -w"
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "PR 作成" ]
}

@test "timeline-hook: gh pr reopen needs a number or a URL" {  # gh pr reopen は番号か URL が要り、位置引数が無いときは積まない
  export FAKE_HEAD_PR=300
  run_hook "gh pr reopen"
  no_gh_call
  run_hook "gh pr reopen 300 -c 999"
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "PR 再オープン" ]
  ! queried '\{owner\}/\{repo\}' 999 || return 1
  : > "$GH_LOG"
  run_hook "gh pr reopen https://github.com/acme/other/pull/301"
  queried acme/other 301
}

@test "timeline-hook: a gh api endpoint names the repository and number" {
  # repos/acme/cwd-repo/... と repos/{owner}/{repo}/... はどちらも cwd のリポジトリの #300。先頭の / は有っても無くてもよい。前置きの GH_REPO は {owner}/{repo} にだけ効く
  touch "$FIX/nopull.12"
  run_hook "gh api repos/acme/cwd-repo/issues/12/comments -f body=x"
  queried acme/cwd-repo 12
  posted_to acme/cwd-repo 12
  : > "$GH_LOG"
  run_hook "gh api repos/{owner}/{repo}/issues/12/comments -f body=x"
  queried '\{owner\}/\{repo\}' 12
  grep -qxF "$(cd "$CWD" && pwd -P)" "$GH_LOG.cwd"
  [ "$(patches)" -eq 1 ]
  : > "$GH_LOG"
  run_hook "gh api /repos/acme/cwd-repo/issues/12/comments -f body=x"
  queried acme/cwd-repo 12
  : > "$GH_LOG"
  run_hook "GH_REPO=acme/third gh api repos/{owner}/{repo}/issues/12/comments -f body=x"
  queried acme/third 12
  : > "$GH_LOG"
  run_hook "GH_REPO=acme/third gh api repos/acme/fourth/issues/12/comments -f body=x"
  queried acme/fourth 12
  ! queried acme/third 12 || return 1
}

@test "timeline-hook: a gh api endpoint that does not fit the shape is skipped" {  # 完全な URL・問い合わせ文字列付き・:owner/:repo・コマンド置換や未定義の変数を含む endpoint・片方だけ置き換え記法の endpoint は gh を呼ばない
  for c in "gh api https://api.github.com/repos/acme/cwd-repo/issues/300/comments -f body=x" \
           'gh api "repos/acme/cwd-repo/issues/$(echo 300)/comments" -f body=x' \
           'gh api repos/acme/cwd-repo/issues/$N/comments -f body=x' \
           "gh api 'repos/acme/cwd-repo/issues/300/comments?per_page=1' -f body=x" \
           "gh api repos/:owner/:repo/issues/300/comments -f body=x" \
           "gh api repos/{owner}/cwd-repo/issues/300/comments -f body=x" \
           "gh api repos/acme/cwd-repo/issues/300/comments/1 -f body=x" \
           "gh api repos/acme/cwd-repo/pulls/300/comments -f body=x" \
           "gh api -X PUT repos/acme/cwd-repo/issues/300/merge" \
           "gh api -X DELETE repos/acme/cwd-repo/issues/300/comments -f body=x" \
           "gh api -X POST repos/acme/cwd-repo/pulls/300/merge"; do
    run_hook "$c"
    [ "$status" -eq 0 ]
    no_gh_call || { echo "gh called for: $c"; return 1; }
  done
}

@test "timeline-hook: a gh api call aimed at another host never stacks" {  # --hostname ghe.example の gh api のコメント投稿は gh を呼ばない（前置きの GH_HOST も同じ）
  run_hook "gh api --hostname ghe.example repos/acme/cwd-repo/issues/300/comments -f body=x"
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook "GH_HOST=ghe.example gh api -X PUT repos/acme/cwd-repo/pulls/300/merge"
  no_gh_call
  run_hook "GH_HOST=ghe.example gh pr create --title x"
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

@test "timeline-hook: a gh api endpoint in another repository gets nothing" {  # cwd が acme/repo-a で、gh api の endpoint が acme/other を指すときは対象を確かめるが書かない（cwd のリポジトリの endpoint には書く）
  use_real_repo_a
  HOOK_CWD="$RA" run_hook "gh api repos/acme/other/issues/300/comments -f body=x"
  [ "$status" -eq 0 ]
  queried acme/other 300
  no_write
  : > "$GH_LOG"
  HOOK_CWD="$RA" run_hook "gh api repos/acme/repo-a/issues/300/comments -f body=x"
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

@test "timeline-hook: gh issue reopen on a PR number is a PR reopen" {  # gh issue reopen 300 の番号が PR なら PR 再オープンとして、PR の state を確かめてから積む
  run_hook "gh issue reopen 300"
  [ "$status" -eq 0 ]
  posted_to acme/cwd-repo 300
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "PR 再オープン" ]
  grep -qE "^args=timeline --pr 300 --branch oratta/sample " "$COST_LOG"
  run_hook "gh issue comment 300 --body x; gh issue reopen 300"
  [ "$(body_nrows)" -eq 2 ]
  [ "$(body_trigger 2)" = "PR コメント+PR 再オープン" ]
  echo '{"state":"closed"}' > "$FIX/pull.301.json"
  : > "$GH_LOG"
  run_hook "gh issue reopen 301"
  no_write
}

@test "timeline-hook: a gh api issue endpoint given a PR number is treated as a PR" {  # issues/300/comments・issues/300 の state=closed・state=open の番号が PR なら、きっかけは PR コメント・PR クローズ・PR 再オープン
  run_hook "gh api repos/acme/cwd-repo/issues/300/comments -f body=x"
  [ "$(body_trigger 1)" = "PR コメント" ]
  grep -qE "^args=timeline --pr 300 --branch oratta/sample " "$COST_LOG"
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/issues/300 -f state=closed"
  [ "$(body_trigger 2)" = "PR クローズ" ]
  echo '{"state":"open"}' > "$FIX/pull.300.json"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/issues/300 -f state=open"
  [ "$(body_nrows)" -eq 3 ]
  [ "$(body_trigger 3)" = "PR 再オープン" ]
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

@test "timeline-hook: no row when a gh api merge or close did not happen" {  # gh api の PUT merge でマージ済みでない・PATCH state=closed で state が open のまま・state=open で closed のままなら積まない
  run_hook "gh api -X PUT repos/acme/cwd-repo/pulls/300/merge"
  [ "$status" -eq 0 ]
  queried acme/cwd-repo 300
  no_write
  [ ! -e "$COST_LOG" ]
  run_hook "gh api -X PATCH repos/acme/cwd-repo/pulls/300 -f state=closed"
  no_write
  touch "$FIX/nopull.12"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/issues/12 -f state=closed"
  no_write
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/pulls/300 -f state=open"
  no_write
  [ ! -e "$COST_LOG" ]
}

@test "timeline-hook: no row when the reopen did not happen" {  # gh pr reopen 300 で state が closed のままなら積まない
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh pr reopen 300"
  [ "$status" -eq 0 ]
  queried '\{owner\}/\{repo\}' 300
  no_write
  [ ! -e "$COST_LOG" ]
}

@test "timeline-hook: an existing PR gets no PR-created row" {  # cwd のブランチの PR の created_at が 1 時間前（gh pr create が「既にある」で失敗した場合）なら積まない。閉じた PR・created_at が無い・読めない応答でも積まない。300 秒以内なら積む
  export FAKE_HEAD_PR=300
  ago() { "$REAL_PYTHON" -c 'import sys, time; print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - int(sys.argv[1]))))' "$1"; }
  echo "{\"created_at\":\"$(ago 3600)\"}" > "$FIX/pull.300.json"
  run_hook "gh pr create --title x --body y"
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" -eq 1 ]
  no_write
  [ ! -e "$COST_LOG" ]
  echo "{\"created_at\":\"$(ago -3600)\"}" > "$FIX/pull.300.json"
  run_hook "gh pr create --title x --body y"
  no_write
  echo '{"created_at":null}' > "$FIX/pull.300.json"
  run_hook "gh pr create --title x --body y"
  no_write
  echo '{"created_at":"yesterday"}' > "$FIX/pull.300.json"
  run_hook "gh pr create --title x --body y"
  no_write
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh pr create --title x --body y"
  no_write
  echo "{\"created_at\":\"$(ago 200)\"}" > "$FIX/pull.300.json"
  run_hook "gh pr create --title x --body y"
  posted_to acme/cwd-repo 300
  [ "$(body_trigger 1)" = "PR 作成" ]
}

@test "timeline-hook: gh pr create with no PR for the branch adds nothing" {  # gh pr create が失敗して、cwd のブランチをヘッドに持つ PR が無ければ積まない
  run_hook "gh pr create --title x --body y"
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" -eq 1 ]
  no_write
}

@test "timeline-hook: gh pr create and a comment on the same PR make one row" {  # gh pr create && gh pr comment（番号なし）は同じ対象で、行は 1 行。前からある PR なら PR コメントだけが残る
  export FAKE_HEAD_PR=300
  run_hook "gh pr create --title x --body y && gh pr comment --body z"
  [ "$(posts)" -eq 1 ]
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "PR 作成+PR コメント" ]
  [ "$(gh_calls)" -eq 3 ]
  echo '{"created_at":"2020-01-01T00:00:00Z"}' > "$FIX/pull.300.json"
  run_hook "gh pr create --title x --body y && gh pr comment --body z"
  [ "$(body_nrows)" -eq 2 ]
  [ "$(body_trigger 2)" = "PR コメント" ]
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

@test "timeline-hook: gh pr create, gh pr reopen and PR-side gh api calls cost three gh calls" {  # gh pr create・gh pr reopen 300・gh api の PATCH state=closed（pulls）・gh api の PUT merge は、どれも gh が 3 回
  export FAKE_HEAD_PR=300
  run_hook "gh pr create --title x --body y"
  [ "$(gh_calls)" -eq 3 ]
  : > "$GH_LOG"
  run_hook "gh pr reopen 300"
  [ "$(gh_calls)" -eq 3 ]
  : > "$GH_LOG"
  echo '{"state":"closed"}' > "$FIX/pull.300.json"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/pulls/300 -f state=closed"
  [ "$(gh_calls)" -eq 3 ]
  : > "$GH_LOG"
  echo '{"state":"closed","merged":true}' > "$FIX/pull.300.json"
  run_hook "gh api -X PUT repos/acme/cwd-repo/pulls/300/merge"
  [ "$(gh_calls)" -eq 3 ]
  [ "$(posts)" -eq 0 ]
  [ "$(patches)" -eq 1 ]
}

@test "timeline-hook: a gh api comment costs three gh calls on an issue and four on a PR" {  # gh api のコメント投稿は、PR でない issue #12 では 3 回、PR #300 では 4 回（issue として確かめてから PR として取り直す 1 回）
  touch "$FIX/nopull.12"
  run_hook "gh api repos/acme/cwd-repo/issues/12/comments -f body=x"
  [ "$(gh_calls)" -eq 3 ]
  [ "$(graphql_calls)" -eq 0 ]
  : > "$GH_LOG"
  run_hook "gh api repos/acme/cwd-repo/issues/300/comments -f body=x"
  [ "$(gh_calls)" -eq 4 ]
}

@test "timeline-hook: closing an issue through gh api costs four gh calls" {  # PR でない issue #12 への gh api の PATCH state=closed は 4 回（閉じた PR の問い合わせを含む）
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x)]"
  run_hook "gh api -X PATCH repos/acme/cwd-repo/issues/12 -f state=closed"
  [ "$(gh_calls)" -eq 4 ]
  [ "$(graphql_calls)" -eq 1 ]
  [ "$(closing_args)" = "704:feat/x" ]
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

# lock() を直接呼び、os.open / os.lstat の呼び出しを記録する。置き場を検査してから開くまでの間に
# パスの解決が入らない（fd を fstat し、ロックファイルはその fd を dir_fd にして開く）ことを確かめる
@test "timeline-hook: the lock file is opened relative to the verified directory fd" {  # 置き場を O_DIRECTORY | O_NOFOLLOW で開いて fstat し、ロックファイルはその fd を dir_fd に名前だけで開く。置き場のパスに lstat しない
  run "$REAL_PYTHON" -B -I - "$WORK/scripts" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
import gate_report
calls, lstats = [], []
real_open, real_lstat = os.open, os.lstat
def spy_open(path, flags, mode=0o777, *, dir_fd=None):
    calls.append((path, flags, dir_fd))
    return real_open(path, flags, mode, dir_fd=dir_fd)
def spy_lstat(path, *a, **k):
    lstats.append(path)
    return real_lstat(path, *a, **k)
os.open, os.lstat = spy_open, spy_lstat
fd = gate_report.lock("a/b", 1)
assert isinstance(fd, int), fd
folder = [c for c in calls if c[2] is None]
lockf = [c for c in calls if c[2] is not None]
assert len(folder) == 1 and len(lockf) == 1, calls
need = os.O_DIRECTORY | os.O_NOFOLLOW
assert folder[0][1] & need == need, calls
assert "/" not in lockf[0][0] and lockf[0][0].endswith(".lock"), calls
assert lockf[0][1] & os.O_NOFOLLOW, calls
assert not any(p == folder[0][0] for p in lstats), lstats
# 検査用の fd は閉じてある: ロックの fd の直前の番号は残っていない
try:
    os.fstat(fd - 1)
    leaked = fd - 1 not in (0, 1, 2) and os.path.exists("/dev/fd/%d" % (fd - 1)) and \
        os.fstat(fd - 1).st_ino == real_lstat(folder[0][0]).st_ino
except OSError:
    leaked = False
assert not leaked, "directory fd leaked"
PY
  [ "$status" -eq 0 ]
}

@test "timeline-hook: lock retries on the same directory fd when the lock file creation returns ENOENT" {  # ロックファイルの作成が 4 回続けて ENOENT でも、同じ dir_fd のまま開き直してロックを取る（書かずに終わらない）。置き場は開き直さない
  run "$REAL_PYTHON" -B -I - "$WORK/scripts" <<'PY3'
import os, sys
sys.path.insert(0, sys.argv[1])
import gate_report
fails, folder_opens, dir_fds = [0], [0], []
real_open = os.open
def spy_open(path, flags, mode=0o777, *, dir_fd=None):
    if dir_fd is None and flags & os.O_DIRECTORY:
        folder_opens[0] += 1
    if dir_fd is not None:
        dir_fds.append(dir_fd)
        if fails[0] < 4:
            fails[0] += 1
            raise FileNotFoundError(2, "injected", path)
    return real_open(path, flags, mode, dir_fd=dir_fd)
os.open = spy_open
fd = gate_report.lock("a/b", 1)
assert isinstance(fd, int), fd
assert fails[0] == 4 and folder_opens[0] == 1, (fails, folder_opens)
assert len(dir_fds) == 5 and len(set(dir_fds)) == 1, dir_fds
# 取った fd は、置き場にあるロックファイルそのもの
folder = os.path.join(os.environ["TMPDIR"], "cost-ledger-timeline")
names = os.listdir(folder)
assert len(names) == 1, names
assert os.fstat(fd).st_ino == os.stat(os.path.join(folder, names[0])).st_ino
PY3
  [ "$status" -eq 0 ]
}

@test "timeline-hook: lock returns None without writing when the lock file creation returns ENOENT 5 times" {  # 5 回とも ENOENT なら、ロックを取れなかったものとして None を返す（直列にできないので書かない）。置き場は開き直さず、例外は外へ出さない
  run "$REAL_PYTHON" -B -I - "$WORK/scripts" <<'PY4'
import os, sys
sys.path.insert(0, sys.argv[1])
import gate_report
n, folder_opens = [0], [0]
real_open = os.open
def spy_open(path, flags, mode=0o777, *, dir_fd=None):
    if dir_fd is None and flags & os.O_DIRECTORY:
        folder_opens[0] += 1
    if dir_fd is not None:
        n[0] += 1
        raise FileNotFoundError(2, "injected", path)
    return real_open(path, flags, mode, dir_fd=dir_fd)
os.open = spy_open
assert gate_report.lock("a/b", 1) is None
assert n[0] == 5 and folder_opens[0] == 1, (n, folder_opens)
PY4
  [ "$status" -eq 0 ]
}

@test "timeline-hook: lock returns None and locks no other directory when the lock directory is removed after it was opened" {  # fd で開いた後に置き場が消えたら、置き場を作り直して別の inode をロックすることはせず、None を返す（先にロックを取った側と同時に読み書きに入らない）
  run "$REAL_PYTHON" -B -I - "$WORK/scripts" <<'PY5'
import os, sys, shutil
sys.path.insert(0, sys.argv[1])
import gate_report
folder = os.path.join(os.environ["TMPDIR"], "cost-ledger-timeline")
real_open = os.open
state, folder_opens = [0], [0]
def spy_open(path, flags, mode=0o777, *, dir_fd=None):
    if dir_fd is None and flags & os.O_DIRECTORY:
        folder_opens[0] += 1
    if dir_fd is not None and state[0] == 0:
        state[0] = 1
        shutil.rmtree(folder)
    return real_open(path, flags, mode, dir_fd=dir_fd)
os.open = spy_open
assert gate_report.lock("a/b", 1) is None
assert state[0] == 1 and folder_opens[0] == 1, (state, folder_opens)
assert not os.path.lexists(folder), "the lock directory was recreated"
PY5
  [ "$status" -eq 0 ]
}

@test "timeline-hook: repos differing only in letter case share one lock file" {  # owner/repo の大文字小文字だけが違う 2 つの名前で lock() を呼ぶと同じ名前のロックファイルを開く（大文字小文字を区別する環境でも同じ対象が別のロックにならない）
  run "$REAL_PYTHON" -B -I - "$WORK/scripts" <<'PY2'
import os, sys
sys.path.insert(0, sys.argv[1])
import gate_report
names = []
real_open = os.open
def spy_open(path, flags, mode=0o777, *, dir_fd=None):
    if dir_fd is not None:
        names.append(path)
    return real_open(path, flags, mode, dir_fd=dir_fd)
os.open = spy_open
for repo in ("Acme/Repo", "acme/repo"):
    fd = gate_report.lock(repo, 7)
    assert isinstance(fd, int), fd
    os.close(fd)
assert len(names) == 2 and names[0] == names[1] == "acme__repo__7.lock", names
PY2
  [ "$status" -eq 0 ]
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

@test "timeline-hook: a failed closing-PR query marks the trigger" {  # GraphQL の失敗・JSON でない応答・形の崩れ・100 件超のどれでも --trigger は issue クローズ+PR 照会失敗。gh は 4 回のまま
  closed_issue_12
  export FAKE_CLOSING_PRS="[$(closing_node 704 feat/x)]" FAKE_GRAPHQL_FAIL=1
  run_hook "gh issue close 12"
  [ "$(trigger_arg)" = "issue クローズ+PR 照会失敗" ]
  [ "$(body_trigger 1)" = "issue クローズ+PR 照会失敗" ]
  [ "$(gh_calls)" -eq 4 ]
  unset FAKE_GRAPHQL_FAIL
  for raw in 'not json' '[]' '{"data":{"repository":{"issue":null}}}'; do
    : > "$COST_LOG"
    FAKE_GRAPHQL_RAW="$raw" run_hook "gh issue close 12"
    [ "$(trigger_arg)" = "issue クローズ+PR 照会失敗" ] || { echo "$raw"; return 1; }
  done
  unset FAKE_GRAPHQL_RAW
  : > "$COST_LOG"
  FAKE_CLOSING_NEXT=1 run_hook "gh issue close 12"
  [ "$(trigger_arg)" = "issue クローズ+PR 照会失敗" ]
  for bad in '{"number":"705","headRefName":"feat/y","isCrossRepository":false,"baseRepository":{"nameWithOwner":"acme/cwd-repo"}}' 'null'; do
    : > "$COST_LOG"
    FAKE_CLOSING_PRS="[$(closing_node 704 feat/x),$bad]" run_hook "gh issue close 12"
    [ "$(trigger_arg)" = "issue クローズ+PR 照会失敗" ] || { echo "$bad"; return 1; }
  done
}

@test "timeline-hook: a comment and a failed close query mark the joined trigger" {  # gh issue comment 12 --body x && gh issue close 12 で問い合わせが失敗 → issue コメント+issue クローズ+PR 照会失敗
  closed_issue_12
  export FAKE_GRAPHQL_FAIL=1
  run_hook "gh issue comment 12 --body x && gh issue close 12"
  [ "$(trigger_arg)" = "issue コメント+issue クローズ+PR 照会失敗" ]
}

@test "timeline-hook: a successful closing-PR query leaves the rows as #689 had them and keeps four gh calls" {  # 本物の cost_ledger.py で、1 件・0 件・別のリポジトリや fork の PR だけ、のどれでも先頭行と表の行（時刻の欄を除く）が #689 のときと同じで、印は付かず、gh は 4 回
  use_real_repo_a
  closed_issue_12
  cl_row S2 r2 2026-09-01T00:00:20.000Z main "$RA" 1000000 "gh issue comment 12 --body x" | cl_write_log issue12
  # 期待値は #689 のとき（8e7c18e4 の gate_report.py）に同じ fixture で得たコメント。CI は浅い clone で
  # 過去の commit を取り出せないので直書きする。時刻の欄は実行時刻なので sed で落として比べる
  local -a want_head=('コスト: $2.00 / ¥300 @150 — issue #12 (acme/repo-a) 帰属: 区間+閉じた PR' \
                      'コスト: $1.00 / ¥150 @150 — issue #12 (acme/repo-a) 帰属: 区間' \
                      'コスト: $1.00 / ¥150 @150 — issue #12 (acme/repo-a) 帰属: 区間')
  local -a want_rows=('| issue クローズ | $1.00 (+1.00) | 1.0M (+1.0M) | 0 (+0) |
| 合計（#704 $1.00 + PR 外 $1.00） | $2.00 (+1.00) | 2.0M (+1.0M) | 0 (+0) |' \
                      '| issue クローズ | $1.00 (+1.00) | 1.0M (+1.0M) | 0 (+0) |' \
                      '| issue クローズ | $1.00 (+1.00) | 1.0M (+1.0M) | 0 (+0) |')
  local -a prs_list=("[$(closing_node 704 oratta/sample acme/repo-a)]" "[]" "[$(closing_node 9 main acme/other),$(closing_node 705 main acme/repo-a true)]")
  local i
  for i in 0 1 2; do
    rm -f "$GH_LOG" "$GH_LOG.body" "$FIX"/comments.12.*.json
    FAKE_CLOSING_PRS="${prs_list[$i]}" HOOK_CWD="$RA" run_hook "gh issue close 12"
    [ "$(gh_calls)" -eq 4 ] || { echo "case $i: gh calls"; return 1; }
    [ "$(body_trigger 1)" = "issue クローズ" ] || { echo "case $i: trigger"; return 1; }
    [ "$(head -n 1 "$GH_LOG.body")" = "${want_head[$i]}" ] || { echo "case $i: head: $(head -n 1 "$GH_LOG.body")"; return 1; }
    [ "$(body_rows | sed 's/^| [^|]* |/|/')" = "${want_rows[$i]}" ] || { echo "case $i: rows: $(body_rows)"; return 1; }
  done
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
    [ "$(body_trigger 1)" = "issue クローズ+PR 照会失敗" ] || { echo "$bad"; return 1; }
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

@test "timeline-hook: the real timeline tells a failed query from zero closing PRs" {  # 本物の cost_ledger.py で、問い合わせが失敗した回と 0 件の回のコメントは、きっかけの欄の印だけが違い、どちらにも合計の行は無い
  use_real_repo_a
  closed_issue_12
  cl_row S2 r2 2026-09-01T00:00:20.000Z main "$RA" 1000000 "gh issue comment 12 --body x" | cl_write_log issue12
  export FAKE_CLOSING_PRS="[]"
  HOOK_CWD="$RA" run_hook "gh issue close 12"
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "issue クローズ" ]
  ok="$(cat "$GH_LOG.body")"
  ok_rows="$(body_rows)"
  rm -f "$GH_LOG" "$GH_LOG.body" "$FIX"/comments.12.*.json
  FAKE_GRAPHQL_FAIL=1 HOOK_CWD="$RA" run_hook "gh issue close 12"
  [ "$(body_nrows)" -eq 1 ]
  [ "$(body_trigger 1)" = "issue クローズ+PR 照会失敗" ]
  [ "$(printf '%s\n' "$ok" | head -n 1)" = "$(head -n 1 "$GH_LOG.body")" ]
  # 表の行は、失敗時から印を除けば 0 件時と行全体が同じ（時刻の欄は実行時刻なので落とす）
  [ "$(printf '%s\n' "$ok_rows" | sed 's/^| [^|]* |/|/')" = "$(body_rows | sed 's/+PR 照会失敗//; s/^| [^|]* |/|/')" ]
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
