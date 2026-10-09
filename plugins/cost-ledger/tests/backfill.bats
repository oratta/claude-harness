#!/usr/bin/env bats
#
# spec: cost-ledger-backfill / cost-ledger-timeline（`--backfill` の要件）
#
# セッション開始の hook（backfill.sh）が、手元から見えなかったマージと issue のクローズへ、次の
# セッション開始で最後の行を積むことを固定する。前半は hook に SessionStart の JSON を流して gh の
# stub の呼び出しを見る。後半は cost_ledger.py timeline --backfill を直接呼ぶ（gh は呼ばれない）。
#
# 実物には触れない: スクリプトを一時ディレクトリへ複製し、gh は PATH の先頭の stub に差し替え、
# 台帳（COST_LEDGER_PATH）と控えは一時ディレクトリに置く。hook は COST_LEDGER_HOOK_FOREGROUND=1 で
# その場で最後まで実行させる（切り離しそのものを見るテストを除く）。
#
# 台帳は複製したスクリプトの親（${WORK}）の外に置く。cost_ledger.py は自分を含むディレクトリの配下の
# 台帳を断るため（その検査だけ $WORK の中を指す）。

load helper

setup() {
  export LC_ALL=C.UTF-8 TZ=UTC
  cl_setup
  REAL_PYTHON="$(command -v python3)"
  WORK="$BATS_TEST_TMPDIR/backfill"
  FIX="$WORK/fixtures"
  CWD="$BATS_TEST_TMPDIR/cwd"
  LEDGER="$BATS_TEST_TMPDIR/ledger/ledger.jsonl"
  STATE="$LEDGER.backfill.json"
  mkdir -p "$WORK/scripts" "$WORK/bin" "$WORK/log" "$WORK/tmp" "$FIX" "$BATS_TEST_TMPDIR/ledger"
  for f in backfill.sh backfill.py gate_report.py cost_ledger.py write_allow.py; do
    if [ -f "$PLUGIN_DIR/scripts/$f" ]; then cp "$PLUGIN_DIR/scripts/$f" "$WORK/scripts/$f"; fi
  done
  cp "$PLUGIN_DIR/pricing.json" "$WORK/pricing.json"
  SCRIPT="$WORK/scripts/backfill.sh"
  cl_init_repo "$CWD" acme/cwd-repo
  export GH_LOG="$WORK/log/gh.log" COST_LOG="$WORK/log/cost.log" GH_FIX="$FIX"
  export TMPDIR="$WORK/tmp"                 # 対象ごとのロックファイルの置き場
  export COST_LEDGER_PATH="$LEDGER"
  export COST_LEDGER_HOOK_FOREGROUND=1
  unset COST_LEDGER_GATE_REPORT COST_LEDGER_BACKFILL GH_HOST GH_REPO
  unset FAKE_GH_FAIL FAKE_GH_DELAY FAKE_PATCH_FAIL FAKE_POST_FAIL FAKE_COMMENTS_FAIL
  unset FAKE_LIST FAKE_LIST_FAIL FAKE_LIST_RAW_TAIL FAKE_HEAD_REPO FAKE_CLOSING_PRS
  write_stub_gh
  export PATH="$WORK/bin:$PATH"
  # GitHub に書くのは許可の一覧に載っているリポジトリだけ（spec cost-ledger-write-allowlist）。
  # このファイルのテストの大半は「一覧に載っている」前提の動きを固定するので、cwd のリポジトリ
  # （acme/cwd-repo）を載せた一覧を cwd の外に置く。一覧に無い・一覧が無いときの動きは
  # 「許可の一覧に従う」の節が固定する
  export HOME="$WORK/home"                  # 利用者の $HOME/.config/cost-ledger/write-repos を読まない
  export COST_LEDGER_WRITE_REPOS_FILE="$WORK/write-repos"
  unset CLAUDE_PROJECT_DIR                  # 一覧の置き場所の検査に、実行環境の作業ディレクトリを混ぜない
  write_allow_list acme/cwd-repo
  # timeline の直接呼び出しで使う値
  B=1788220800                      # 2026-09-01T00:00:00Z の epoch 秒
  T=$((B + 3600))                   # 2026-09-01T01:00:00Z。後追いが渡す出来事の時刻
  IN="$BATS_TEST_TMPDIR/in.md"
  OUT="$BATS_TEST_TMPDIR/out.md"
  : > "$IN"
  HEADER='| 時刻 | きっかけ | 金額 | 入出力 | キャッシュ |'
  SEP='|---|---|---|---|---|'
}

teardown() {  # 切り離しのテストが途中で落ちても、裏のプロセスを残さない
  wait_for_workers || true
}

SEEN0="2026-09-01T12:00:00Z"        # 多くのテストが控えに置く「前回見た時刻」
M="2026-09-02T00:00:00Z"            # 候補のマージ・クローズの時刻（SEEN0 より後）
M_EPOCH=1788307200

# 呼ばれた引数を 1 呼び出し 1 行でログに書く gh（$GH_LOG の行数が呼び出し回数）。gate-report.bats の
# stub を写し、後追いが使う応答を足したもの。
#   一覧:          repos/<A>/issues?state=closed&since=... は $GH_FIX/list.<ページ>.json（ページごとの
#                  配列）を順に返す。無ければ FAKE_LIST（JSON の配列。既定は空）の 1 ページ。--jq は
#                  ページごとに当てる（本物の gh api --paginate --jq と同じ形）。クエリは $GH_LOG.list に
#                  書く。FAKE_LIST_FAIL=1 は一覧だけ失敗、FAKE_LIST_RAW_TAIL は最後のページのあとに
#                  その文字列を 1 行そのまま出す（JSON として読めない行）
#   PR の確認:     repos/<A>/pulls/<N> の既定は「マージ済み・ヘッド feat/a・ヘッドもベースも <A>」。
#                  FAKE_HEAD_REPO でヘッドのリポジトリを差し替え、$GH_FIX/pull.<N>.json で上書きする
#   既存コメント:  $GH_FIX/comments.<N>.<ページ>.json（無ければ空の 1 ページ）
#   書き込み:      --input - の JSON の body を $GH_LOG.body に書き、POST は comments.<N>.9.json に足し、
#                  PATCH はその id のコメントを書き換える（続けて流すテストで次の取得に現れる）
#   閉じた PR:     api graphql は closedByPullRequestsReferences の応答を返す（nodes は FAKE_CLOSING_PRS）
#   遅延と失敗:    FAKE_GH_DELAY（全部の呼び出し）・FAKE_GH_FAIL・FAKE_POST_FAIL・FAKE_PATCH_FAIL・
#                  FAKE_COMMENTS_FAIL
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
    sys.exit(0)

method, path, jqf, source = None, "", None, None
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
        i += 2
    elif a == "--paginate":
        i += 1
    elif a == "--hostname":
        i += 2
    else:
        path = a; i += 1
body = json.loads(sys.stdin.read())["body"] if source == "-" else None
method = method or ("POST" if body is not None else "GET")

if path == "graphql":
    note(LOG + ".graphql", "graphql")
    refs = {"nodes": json.loads(env("FAKE_CLOSING_PRS", "[]")), "pageInfo": {"hasNextPage": False}}
    sys.stdout.write(json.dumps(
        {"data": {"repository": {"issue": {"closedByPullRequestsReferences": refs}}}}) + "\n")
    sys.exit(0)
path, _, query = path.partition("?")
m = re.fullmatch(r"repos/([^/]+/[^/]+)/(.*)", path)
if not m:
    sys.exit(1)
repo, rest = m.groups()

def emit(text):
    if jqf is None:
        sys.stdout.write(text + "\n")
    else:
        sys.stdout.write(subprocess.run(["jq", "-r", jqf], input=text, capture_output=True,
                                        encoding="utf-8", check=True).stdout)

m_pull = re.fullmatch(r"pulls/(\d+)", rest)
m_comments = re.fullmatch(r"issues/(\d+)/comments", rest)
m_comment = re.fullmatch(r"issues/comments/(\d+)", rest)
if method == "GET" and rest == "issues":
    note(LOG + ".list", query)
    if env("FAKE_LIST_FAIL") == "1":
        sys.stderr.write("gh: list boom\n")
        sys.exit(1)
    found = sorted(glob.glob(os.path.join(FIX, "list.*.json")))
    if not found:
        emit(env("FAKE_LIST", "[]"))
    for p in found:
        emit(open(p, encoding="utf-8").read())
    if env("FAKE_LIST_RAW_TAIL") is not None:
        sys.stdout.write(env("FAKE_LIST_RAW_TAIL") + "\n")
elif method == "GET" and m_pull:
    n = int(m_pull.group(1))
    data = {"number": n, "state": "closed", "draft": False, "merged": True,
            "merged_at": "2026-09-02T00:00:00Z",
            "head": {"ref": "feat/a", "repo": {"full_name": env("FAKE_HEAD_REPO", repo)}},
            "base": {"repo": {"full_name": repo}}}
    p = os.path.join(FIX, "pull.%d.json" % n)
    if os.path.exists(p):
        data.update(json.load(open(p, encoding="utf-8")))
    emit(json.dumps(data))
elif method == "GET" and m_comments:
    if env("FAKE_COMMENTS_FAIL") == "1":
        sys.stderr.write("gh: boom\n")
        sys.exit(1)
    found = sorted(glob.glob(os.path.join(FIX, "comments.%d.*.json" % int(m_comments.group(1)))))
    if not found:
        emit("[]")
    for p in found:
        emit(open(p, encoding="utf-8").read())
elif method == "POST" and m_comments:
    if env("FAKE_POST_FAIL") == "1":
        sys.stderr.write("gh: post failed\n")
        sys.exit(1)
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

# 許可の一覧を書く。引数 1 つが 1 行（引数なしなら大きさ 0 のファイル）。${LIST_FILE}（既定は
# COST_LEDGER_WRITE_REPOS_FILE の場所）に置く
write_allow_list() {
  local file="${LIST_FILE-$COST_LEDGER_WRITE_REPOS_FILE}"
  mkdir -p "$(dirname "$file")"
  if [ "$#" -eq 0 ]; then : >| "$file"; else printf '%s\n' "$@" >| "$file"; fi
  chmod 600 "$file"
}

# 起動されたらログに書いて 0 以外で終わる python3（python3 を起動しない経路の検査のときだけ置く）
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
no_python() { [ ! -e "$WORK/log/python.log" ]; }

# SessionStart の hook の JSON。HOOK_CWD（既定 ${CWD}）
session_json() {  # $1=source（既定 startup。"-" で省く）
  "$REAL_PYTHON" - "${1-startup}" "${HOOK_CWD-$CWD}" <<'PY'
import json, sys
source, cwd = sys.argv[1:3]
d = {"session_id": "S1", "transcript_path": "/tmp/claude/projects/p/S1.jsonl",
     "hook_event_name": "SessionStart", "cwd": cwd}
if source != "-":
    d["source"] = source
print(json.dumps(d, ensure_ascii=False))
PY
}

run_backfill() {  # $1=source（既定 startup）
  session_json "${1-startup}" > "$WORK/payload.json"
  run bash "$SCRIPT" < "$WORK/payload.json"
}

now() { "$REAL_PYTHON" -c 'import time; print("%.3f" % time.time())'; }
# いまから $1 秒前の UTC の ISO 8601（秒まで）
iso_ago() { "$REAL_PYTHON" -c 'import sys, time; print(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - int(sys.argv[1]))))' "$1"; }

# 一覧の要素の配列を作る。引数 1 つが 1 件で、`種類,番号,出来事の時刻[,更新時刻]`。
# 種類は pr（マージ済み）・issue（クローズ済み）・closedpr（マージされずに閉じられた PR）
list_json() {
  "$REAL_PYTHON" - "$@" <<'PY'
import json, sys
items = []
for spec in sys.argv[1:]:
    parts = spec.split(",")
    kind, number, event = parts[0], int(parts[1]), parts[2]
    d = {"number": number, "state": "closed", "closed_at": event,
         "updated_at": parts[3] if len(parts) > 3 else event, "body": "x" * 50}
    if kind == "pr":
        d["pull_request"] = {"url": "x", "merged_at": event}
    elif kind == "closedpr":
        d["pull_request"] = {"url": "x", "merged_at": None}
    items.append(d)
print(json.dumps(items))
PY
}
set_list() { FAKE_LIST="$(list_json "$@")"; export FAKE_LIST; }

# 控えファイルの seen_until を読む・書く（$2 は owner/repo。既定 acme/cwd-repo）
seen() {
  "$REAL_PYTHON" - "$STATE" "${1-acme/cwd-repo}" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["repos"][sys.argv[2]]["seen_until"])
PY
}
set_seen() {  # $1=時刻 $2=owner/repo
  "$REAL_PYTHON" - "$STATE" "$1" "${2-acme/cwd-repo}" <<'PY'
import json, os, sys
path, value, repo = sys.argv[1:4]
d = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {"version": 1, "repos": {}}
d["repos"][repo] = {"seen_until": value}
json.dump(d, open(path, "w", encoding="utf-8"))
PY
}

no_gh_call() { [ ! -s "$GH_LOG" ]; }
gh_calls() { if [ -f "$GH_LOG" ]; then wc -l < "$GH_LOG" | tr -d ' '; else echo 0; fi; }
count_log() { [ -f "$GH_LOG" ] || { echo 0; return 0; }; grep -cE -- "$1" "$GH_LOG" || true; }
list_calls() { count_log 'repos/[^ ]+/issues\?state=closed'; }
comment_reads() { count_log 'repos/[^ ]+/issues/[0-9]+/comments\?per_page'; }
posts() { count_log '-X POST repos/[^ ]+/issues/[0-9]+/comments'; }
patches() { count_log '-X PATCH repos/[^ ]+/issues/comments/'; }
no_write() { [ "$(posts)" -eq 0 ] && [ "$(patches)" -eq 0 ]; }
queried_pull() { grep -qE "(^| )repos/acme/cwd-repo/pulls/$1( |\$)" "$GH_LOG"; }
forget_gh_log() { command rm -f "$GH_LOG" "$GH_LOG.list" "$GH_LOG.body" "$GH_LOG.env" "$GH_LOG.graphql"; }

# closedByPullRequestsReferences の nodes の 1 件
closing_node() {  # $1=番号 $2=ヘッドブランチ
  printf '{"number":%s,"headRefName":"%s","isCrossRepository":false,"baseRepository":{"nameWithOwner":"acme/cwd-repo"}}' "$1" "$2"
}

# 最後に書き込まれた本文の表の行（見出しと区切りを除く）
body_rows() { grep '^| ' "$GH_LOG.body" | grep -v '^| 時刻 ' || true; }
body_nrows() { body_rows | wc -l | tr -d ' '; }
body_cell() { body_rows | sed -n "${1}p" | awk -F'|' -v n="$2" '{v=$(n+1); sub(/^ /,"",v); sub(/ $/,"",v); print v}'; }  # $2: 1=時刻 2=きっかけ 3=金額
body_trigger() { body_cell "$1" 2; }

# ヘッドブランチ feat/a に $1.00 の応答を 1 つ置く（マージの時刻より前）
log_feat_a() {
  cl_row S1 r1 2026-09-01T00:00:10.000Z feat/a "$CWD" 1000000 | cl_write_log s1
}
# issue #12 の区間に $1.00 の応答を 1 つ置く
log_issue_12() {
  cl_row S2 q1 2026-09-01T00:00:20.000Z main "$CWD" 1000000 "gh issue view 12" | cl_write_log s2
}

# 目印付きのコメント（表 1 行・累計 $1.00）を対象の 1 ページ目に置く
seed_comment() {  # $1=番号 $2=きっかけ $3=記録の時刻（epoch 秒）
  "$REAL_PYTHON" - "$FIX/comments.$1.1.json" "$2" "$3" <<'PY'
import json, sys
path, trigger, at = sys.argv[1:4]
body = "\n".join([
    "コスト: $1.00 / ¥150 @150 — PR #300 (feat/a) 帰属: ブランチ", "",
    "| 時刻 | きっかけ | 金額 | 入出力 | キャッシュ |", "|---|---|---|---|---|",
    "| 09/01 00:30 | %s | $1.00 (+1.00) | 1M (+1M) | 0 (+0) |" % trigger, "",
    "<!-- cost-ledger:timeline v1 %s.000:1.000000:1000000:0 -->" % at])
json.dump([{"id": 11, "body": "LGTM"}, {"id": 21, "body": body}],
          open(path, "w", encoding="utf-8"), ensure_ascii=False)
PY
}

# 複製した cost_ledger.py に、受け取った引数を $COST_LOG へ書く 2 行を足す（timeline へ渡した引数の検査）
log_timeline_args() {
  "$REAL_PYTHON" - "$WORK/scripts/cost_ledger.py" <<'PY'
import sys
path = sys.argv[1]
s = open(path, encoding="utf-8").read()
mark = '\nif __name__ == "__main__":'
i = s.rindex(mark)
extra = ('\nif __name__ == "__main__" and os.environ.get("COST_LOG"):\n'
         '    open(os.environ["COST_LOG"], "a", encoding="utf-8").write("args=%s\\n" % " ".join(sys.argv[1:]))\n')
open(path, "w", encoding="utf-8").write(s[:i] + extra + s[i:])
PY
}

wait_for_workers() {  # 裏のプロセスが終わるまで待つ（最大 40 秒）
  local i
  for i in $(seq 1 200); do
    pgrep -f "$WORK/scripts/backfill.py" >/dev/null 2>&1 || return 0
    sleep 0.2
  done
  return 1
}

# 候補が PR #300 の 1 件（M にマージ、手元のコストあり）で、前回見た時刻が SEEN0 の状態
one_pr_candidate() {
  log_feat_a
  set_seen "$SEEN0"
  set_list "pr,300,$M"
}

# --- セッション開始の hook で後追いを起こす ---

@test "backfill: hooks.json registers a SessionStart hook for startup and resume with timeout 10" {  # SessionStart に matcher startup|resume・timeout 10 で backfill.sh を呼ぶ hook があり、PostToolUse と Stop は変更前と同じ
  [ -x "$PLUGIN_DIR/scripts/backfill.sh" ]
  python3 - "$PLUGIN_DIR/hooks/hooks.json" <<'PY'
import json, sys
hooks = json.load(open(sys.argv[1], encoding="utf-8"))["hooks"]
assert sorted(hooks) == ["PostToolUse", "SessionStart", "Stop"], sorted(hooks)
(entry,) = hooks["SessionStart"]
assert entry["matcher"] == "startup|resume", entry
(hook,) = entry["hooks"]
assert hook == {"type": "command", "command": '"${CLAUDE_PLUGIN_ROOT}/scripts/backfill.sh"', "timeout": 10}, hook
assert hooks["PostToolUse"] == [{"matcher": "Bash", "hooks": [
    {"type": "command", "command": '"${CLAUDE_PLUGIN_ROOT}/scripts/gate-report.sh"', "timeout": 60}]}]
assert hooks["Stop"] == [{"hooks": [
    {"type": "command", "command": '"${CLAUDE_PLUGIN_ROOT}/scripts/ledger-hook.sh"', "timeout": 120}]}]
PY
}

@test "backfill: the hook returns at once and the comment is written afterwards" {  # gh が 1 回 3 秒かかっても hook は 1 秒未満で終わり、そのあとでコメントが書き込まれる
  unset COST_LEDGER_HOOK_FOREGROUND
  one_pr_candidate
  export FAKE_GH_DELAY=3
  session_json startup > "$WORK/payload.json"
  start="$(now)"
  run bash "$SCRIPT" < "$WORK/payload.json"
  end="$(now)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  python3 -c 'import sys; assert float(sys.argv[2]) - float(sys.argv[1]) < 1.0, sys.argv' "$start" "$end"
  [ "$(posts)" -eq 0 ]
  wait_for_workers
  [ "$(posts)" -eq 1 ]
}

@test "backfill: prints nothing when a row is stacked, when gh fails, and on broken JSON" {  # 候補がある・gh がすべて失敗する・壊れた JSON のどれでも stdout と stderr は空で終了コード 0
  one_pr_candidate
  run_backfill
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(posts)" -eq 1 ]
  export FAKE_GH_FAIL=1
  set_seen "$SEEN0"
  run_backfill
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  unset FAKE_GH_FAIL
  forget_gh_log
  printf '%s' '{"cwd": ' > "$WORK/payload.json"
  run bash "$SCRIPT" < "$WORK/payload.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
}

@test "backfill: prints nothing when dirname is not on PATH" {  # PATH に gh と python3 しか無く dirname が見つからなくても、stdout と stderr は空で終了コード 0
  one_pr_candidate
  real_bash="$(command -v bash)"
  mkdir -p "$WORK/onlybin"
  cp "$WORK/bin/gh" "$WORK/onlybin/gh"
  printf '#!%s\necho "python3 started" >> "%s"\nexit 3\n' "$real_bash" "$WORK/log/python.log" > "$WORK/onlybin/python3"
  chmod +x "$WORK/onlybin/python3"
  session_json startup > "$WORK/payload.json"
  run env PATH="$WORK/onlybin" "$real_bash" "$SCRIPT" < "$WORK/payload.json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
  no_python
}

@test "backfill: with COST_LEDGER_HOOK_FOREGROUND=1 the comment is written before the hook ends" {  # その場で実行すると、hook が終わった時点でコメントの作成が済んでいる
  one_pr_candidate
  run_backfill
  [ "$status" -eq 0 ]
  [ "$(posts)" -eq 1 ]
  [ "$(body_trigger 1)" = "マージ" ]
}

# --- 後追いが動かない条件 ---

@test "backfill: COST_LEDGER_BACKFILL=off starts neither gh nor python3" {  # 後追いだけの緊急停止。gh と python3 は一度も呼ばれず、stdout は空で終了コード 0
  one_pr_candidate
  use_stub_python
  export COST_LEDGER_BACKFILL=off
  run_backfill
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
  no_python
}

@test "backfill: COST_LEDGER_GATE_REPORT=off stops the backfill too" {  # 既存の緊急停止でも gh と python3 は一度も呼ばれない
  one_pr_candidate
  use_stub_python
  export COST_LEDGER_GATE_REPORT=off
  run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  no_python
}

@test "backfill: without COST_LEDGER_PATH neither gh nor python3 starts" {  # 台帳が未設定なら控えの置き場所が決まらないので動かない
  set_list "pr,300,$(iso_ago 3600)"
  use_stub_python
  unset COST_LEDGER_PATH
  run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  no_python
  export COST_LEDGER_PATH=""
  run_backfill
  no_gh_call
  no_python
}

@test "backfill: a ledger set only through the userConfig LEDGER_PATH still runs the backfill" {  # COST_LEDGER_PATH を外し CLAUDE_PLUGIN_OPTION_LEDGER_PATH だけを設定しても、候補に行が積まれ、控えとロックは userConfig 側の台帳の隣にできる
  one_pr_candidate
  unset COST_LEDGER_PATH
  export CLAUDE_PLUGIN_OPTION_LEDGER_PATH="$LEDGER"
  run_backfill
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(posts)" -eq 1 ]
  [ "$(body_trigger 1)" = "マージ" ]
  [ -e "$STATE" ]
  [ -e "$LEDGER.backfill.lock" ]
}

@test "backfill: when both ledger settings differ the userConfig one holds the state and lock" {  # 両方を別の場所に設定したら userConfig 側の隣にだけ控えとロックができ、COST_LEDGER_PATH 側には作られない
  one_pr_candidate
  other="$BATS_TEST_TMPDIR/other/ledger.jsonl"
  export COST_LEDGER_PATH="$other"
  export CLAUDE_PLUGIN_OPTION_LEDGER_PATH="$LEDGER"
  run_backfill
  [ "$status" -eq 0 ]
  [ "$(posts)" -eq 1 ]
  [ -e "$STATE" ]
  [ -e "$LEDGER.backfill.lock" ]
  [ ! -e "$other.backfill.json" ]
  [ ! -e "$other.backfill.lock" ]
}

@test "backfill: an empty userConfig LEDGER_PATH falls back to COST_LEDGER_PATH" {  # CLAUDE_PLUGIN_OPTION_LEDGER_PATH が空文字なら COST_LEDGER_PATH を使う
  one_pr_candidate
  export CLAUDE_PLUGIN_OPTION_LEDGER_PATH=""
  run_backfill
  [ "$status" -eq 0 ]
  [ "$(posts)" -eq 1 ]
  [ -e "$STATE" ]
}

@test "backfill: a ledger inside the plugin's own tree is refused" {  # 台帳がスクリプトを含むディレクトリの配下を指していれば、gh を呼ばず控えも書かない
  set_list "pr,300,$(iso_ago 3600)"
  export COST_LEDGER_PATH="$WORK/ledger.jsonl"
  run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  [ ! -e "$WORK/ledger.jsonl.backfill.json" ]
}

@test "backfill: an origin that is not github.com is skipped" {  # origin が github.com でないリポジトリでは gh を呼ばず、控えも作らない
  set_list "pr,300,$(iso_ago 3600)"
  git -C "$CWD" remote set-url origin https://unrelated.example/acme/repo-a.git
  run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  [ ! -e "$STATE" ]
}

@test "backfill: an inherited GH_HOST other than github.com is skipped" {  # GH_HOST=ghe.example.com を引き継いだセッションからは github.com へ書かない
  set_list "pr,300,$(iso_ago 3600)"
  export GH_HOST=ghe.example.com
  run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  [ ! -e "$STATE" ]
  export GH_HOST=GitHub.com
  run_backfill
  [ "$(list_calls)" -eq 1 ]
  [ -z "$(grep -vx -- '-' "$GH_LOG.env")" ] || return 1   # 引き継いだ GH_HOST は gh に渡さない
}

@test "backfill: source clear and compact do nothing" {  # 同じセッションの続きなので、直接流されても gh を呼ばず控えも作らない
  set_list "pr,300,$(iso_ago 3600)"
  run_backfill clear
  [ "$status" -eq 0 ]
  run_backfill compact
  [ "$status" -eq 0 ]
  no_gh_call
  [ ! -e "$STATE" ]
}

@test "backfill: resume, an unknown source and a missing source all run" {  # startup・resume 以外の値や値が無い JSON でも、matcher を通った以上は起動として扱う
  run_backfill resume
  [ "$(list_calls)" -eq 1 ]
  run_backfill something-new
  [ "$(list_calls)" -eq 2 ]
  run_backfill -
  [ "$(list_calls)" -eq 3 ]
}

@test "backfill: a cwd that is not a git repository is skipped" {  # git リポジトリでない場所・origin が無い場所・cwd が文字列でない JSON では gh を呼ばない
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  HOOK_CWD="$BATS_TEST_TMPDIR/plain" run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  git init -q "$BATS_TEST_TMPDIR/noorigin"
  HOOK_CWD="$BATS_TEST_TMPDIR/noorigin" run_backfill
  no_gh_call
  printf '%s' '{"hook_event_name":"SessionStart","source":"startup","cwd":7}' > "$WORK/payload.json"
  run bash "$SCRIPT" < "$WORK/payload.json"
  [ "$status" -eq 0 ]
  no_gh_call
  [ ! -e "$STATE" ]
}

@test "backfill: a cwd that no longer exists is skipped even under a listed repository" {  # 削除済みの worktree の cwd は、パスから持ち主を推定せず gh を呼ばない（spec「後追いが動かない条件」）
  set_list "pr,300,$(iso_ago 3600)"
  HOOK_CWD="$CWD/.claude/worktrees/gone" run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  [ ! -e "$STATE" ]
}

# --- 許可の一覧に従う（spec cost-ledger-write-allowlist。後追いもこの一覧に無いリポジトリには書かない） ---

@test "backfill: a repository that is not on the list gets no gh call at all" {  # cwd のリポジトリが一覧に無ければ、一覧の取得も書き込みもせず、控えも変えない
  one_pr_candidate
  write_allow_list acme/other
  run_backfill
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
  [ "$(seen)" = "$SEEN0" ]
}

@test "backfill: without a list file neither gh nor python3 starts" {  # 一覧のファイルが無ければどこにも書かない。python3 も起動しない
  one_pr_candidate
  use_stub_python
  command rm -f "$COST_LEDGER_WRITE_REPOS_FILE"
  run_backfill
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
  no_python
  [ "$(seen)" = "$SEEN0" ]
}

@test "backfill: an empty list file starts neither gh nor python3" {  # 大きさ 0 の一覧は、無いのと同じ
  one_pr_candidate
  use_stub_python
  write_allow_list
  run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  no_python
}

@test "backfill: a list with no valid line writes nowhere" {  # コメントと書式に合わない行だけの一覧では、python3 は起動するが gh を呼ばない
  one_pr_candidate
  write_allow_list '# acme/cwd-repo' 'github.com/acme/cwd-repo' 'acme/*'
  run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  [ "$(seen)" = "$SEEN0" ]
}

@test "backfill: the default list under HOME is read when the variable is unset" {  # COST_LEDGER_WRITE_REPOS_FILE が無ければ $HOME/.config/cost-ledger/write-repos を読む。そこにも無ければ書かない
  one_pr_candidate
  command rm -f "$COST_LEDGER_WRITE_REPOS_FILE"
  unset COST_LEDGER_WRITE_REPOS_FILE
  run_backfill
  no_gh_call
  LIST_FILE="$HOME/.config/cost-ledger/write-repos" write_allow_list acme/cwd-repo
  run_backfill
  [ "$status" -eq 0 ]
  [ "$(list_calls)" -eq 1 ]
  [ "$(posts)" -eq 1 ]
}

@test "backfill: a list file inside the working repository is not a list" {  # cwd のリポジトリの中に置いた一覧では自分を許可できない
  one_pr_candidate
  export COST_LEDGER_WRITE_REPOS_FILE="$CWD/write-repos"
  write_allow_list acme/cwd-repo
  run_backfill
  [ "$status" -eq 0 ]
  no_gh_call
  [ "$(seen)" = "$SEEN0" ]
}

@test "backfill: backfill.py started directly still obeys the list" {  # backfill.sh を通らずに起動されても、一覧が無い・一覧に無いリポジトリでは gh を呼ばない
  one_pr_candidate
  session_json > "$WORK/payload.json"
  command rm -f "$COST_LEDGER_WRITE_REPOS_FILE"
  run "$REAL_PYTHON" "$WORK/scripts/backfill.py" < "$WORK/payload.json"
  [ "$status" -eq 0 ]
  no_gh_call
  write_allow_list acme/other
  run "$REAL_PYTHON" "$WORK/scripts/backfill.py" < "$WORK/payload.json"
  no_gh_call
  [ "$(seen)" = "$SEEN0" ]
  write_allow_list acme/other acme/cwd-repo
  COST_LEDGER_BACKFILL=off run "$REAL_PYTHON" "$WORK/scripts/backfill.py" < "$WORK/payload.json"
  no_gh_call
  COST_LEDGER_GATE_REPORT=off run "$REAL_PYTHON" "$WORK/scripts/backfill.py" < "$WORK/payload.json"
  no_gh_call
  run "$REAL_PYTHON" "$WORK/scripts/backfill.py" < "$WORK/payload.json"
  [ "$(posts)" -eq 1 ]
}

@test "backfill: backfill.py imports write_allow and asks allowed() before the first gh" {  # 判定は write_allow.py の allowed() に任せ、一覧の読み方を書き写さない
  grep -qE '^import .*\bwrite_allow\b' "$PLUGIN_DIR/scripts/backfill.py"
  grep -qF 'write_allow.allowed(' "$PLUGIN_DIR/scripts/backfill.py"
  if grep -qE 'write-repos|COST_LEDGER_WRITE_REPOS_FILE' "$PLUGIN_DIR/scripts/backfill.py"; then return 1; fi
}

# --- 候補は前回見た時刻以降の分だけを一覧 1 回で探す ---

@test "backfill: with nothing new, gh is called once" {  # 一覧が 0 件なら gh は 1 回で、コメントの作成も書き換えも無い
  set_seen "$SEEN0"
  run_backfill
  [ "$(gh_calls)" -eq 1 ]
  no_write
}

@test "backfill: the list is narrowed by the last seen time and pinned to github.com" {  # 一覧は repos/acme/cwd-repo/issues に対するもので、state=closed と since=<前回見た時刻> を含む
  set_seen "2026-10-07T01:00:00Z"
  run_backfill
  [ "$(cat "$GH_LOG.list")" = "state=closed&since=2026-10-07T01:00:00Z&sort=updated&direction=asc&per_page=100" ]
  grep -qE '^api --paginate repos/acme/cwd-repo/issues\?state=closed.* --hostname github\.com$' "$GH_LOG"
  [ "$(cat "$GH_LOG.env")" = "-" ]
}

@test "backfill: an item that was only updated is not asked about" {  # 前回見た時刻より前にマージされ、後に更新されただけの PR では gh は 1 回
  set_seen "2026-10-07T01:00:00Z"
  set_list "pr,300,2026-10-07T00:30:00Z,2026-10-07T01:30:00Z"
  run_backfill
  [ "$(gh_calls)" -eq 1 ]
  no_write
}

@test "backfill: a pull request closed without merging is not a candidate" {  # merged_at が null の PR は、closed_at が前回見た時刻より後でも候補にしない
  set_seen "$SEEN0"
  set_list "closedpr,301,$M"
  run_backfill
  [ "$(gh_calls)" -eq 1 ]
}

@test "backfill: when the list fails nothing is stacked and the state file is untouched" {  # 一覧の失敗では何も積まず、控えを変えない
  one_pr_candidate
  cp "$STATE" "$WORK/state.before"
  export FAKE_LIST_FAIL=1
  run_backfill
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" -eq 1 ]
  no_write
  cmp "$STATE" "$WORK/state.before"
}

@test "backfill: a list of two pages is read to the end with one gh call" {  # 1 ページ目が更新されただけの 100 件、2 ページ目に候補の PR #300。#300 に行が積まれ、seen_until は 2 ページ目まで含めた最大値
  log_feat_a
  set_seen "$SEEN0"
  specs=()
  for i in $(seq 1 100); do specs+=("issue,$((1000 + i)),2026-08-30T00:00:00Z,2026-09-01T13:00:00Z"); done
  list_json "${specs[@]}" > "$FIX/list.1.json"
  list_json "pr,300,$M,2026-09-02T00:00:07Z" > "$FIX/list.2.json"
  run_backfill
  [ "$(list_calls)" -eq 1 ]
  [ "$(gh_calls)" -eq 4 ]
  [ "$(posts)" -eq 1 ]
  [ "$(body_trigger 1)" = "マージ" ]
  [ "$(seen)" = "2026-09-02T00:00:07Z" ]
}

@test "backfill: candidates on both pages are stacked" {  # 候補が 1 ページ目と 2 ページ目に 1 件ずつあるとき、両方に行が積まれる
  log_feat_a
  set_seen "$SEEN0"
  list_json "pr,300,$M" > "$FIX/list.1.json"
  list_json "pr,301,2026-09-02T00:00:01Z" > "$FIX/list.2.json"
  run_backfill
  [ "$(posts)" -eq 2 ]
  grep -qF -- "-X POST repos/acme/cwd-repo/issues/300/comments" "$GH_LOG"
  grep -qF -- "-X POST repos/acme/cwd-repo/issues/301/comments" "$GH_LOG"
}

@test "backfill: an unreadable line on a later page fails the whole list" {  # 2 ページ目に読めない行があれば、1 ページ目の候補にも積まず、控えも変えない
  one_pr_candidate
  cp "$STATE" "$WORK/state.before"
  export FAKE_LIST_RAW_TAIL='{"number": 301, "updated_at"'
  run_backfill
  [ "$(gh_calls)" -eq 1 ]
  no_write
  cmp "$STATE" "$WORK/state.before"
}

@test "backfill: an item with a broken shape fails the whole list" {  # number が整数でない・updated_at が時刻として読めない要素があれば、何も積まず控えも変えない
  one_pr_candidate
  cp "$STATE" "$WORK/state.before"
  export FAKE_LIST_RAW_TAIL='{"number":"301","state":"closed","updated_at":"2026-09-02T00:00:09Z","closed_at":null,"is_pr":false,"merged_at":null}'
  run_backfill
  [ "$(gh_calls)" -eq 1 ]
  cmp "$STATE" "$WORK/state.before"
  forget_gh_log
  export FAKE_LIST_RAW_TAIL='{"number":301,"state":"closed","updated_at":"yesterday","closed_at":null,"is_pr":false,"merged_at":null}'
  run_backfill
  [ "$(gh_calls)" -eq 1 ]
  cmp "$STATE" "$WORK/state.before"
}

@test "backfill: one run handles at most 20 candidates and the rest go to the next run" {  # 出来事の時刻がすべて違う 25 件。既存コメントの取得は 20 件分で、seen_until は 20 件目の時刻。もう一度流すと残りの 5 件
  set_seen "$SEEN0"
  specs=()
  for i in $(seq 25 -1 1); do specs+=("issue,$((100 + i)),$(printf '2026-09-02T00:00:%02dZ' "$i"),2026-09-02T01:00:00Z"); done
  set_list "${specs[@]}"
  run_backfill
  [ "$(comment_reads)" -eq 20 ]
  [ "$(seen)" = "2026-09-02T00:00:20Z" ]
  grep -qF "issues/120/comments" "$GH_LOG"
  ! grep -qF "issues/121/comments" "$GH_LOG" || return 1
  run_backfill
  [ "$(comment_reads)" -eq 25 ]
  [ "$(seen)" = "2026-09-02T01:00:00Z" ]
}

@test "backfill: candidates at the same second as the 20th are not split" {  # 20 件目と 21 件目の出来事の時刻が同じなら 21 件すべてを処理する
  set_seen "$SEEN0"
  specs=()
  for i in $(seq 1 20); do specs+=("issue,$((100 + i)),$(printf '2026-09-02T00:00:%02dZ' "$i")"); done
  specs+=("issue,121,2026-09-02T00:00:20Z")
  set_list "${specs[@]}"
  run_backfill
  [ "$(comment_reads)" -eq 21 ]
  [ "$(seen)" = "2026-09-02T00:00:20Z" ]
}

# --- どこまで見たかを台帳の隣に記録する ---

@test "backfill: the first run looks back 24 hours" {  # 控えが無ければ since は実行した時刻の 24 時間前（前後 60 秒）。1 時間前にマージされた #300 だけが処理され、控えが書かれる
  log_feat_a
  [ ! -e "$STATE" ]
  set_list "pr,300,$(iso_ago 3600)" "issue,12,$(iso_ago 172800),$(iso_ago 3500)"
  run_backfill
  python3 - "$(cat "$GH_LOG.list")" <<'PY'
import calendar, re, sys, time
since = re.search(r"since=([^&]+)", sys.argv[1]).group(1)
at = calendar.timegm(time.strptime(since, "%Y-%m-%dT%H:%M:%SZ"))
assert abs(at - (time.time() - 86400)) <= 60, since
PY
  queried_pull 300
  [ "$(posts)" -eq 1 ]
  ! grep -qF "issues/12/comments" "$GH_LOG" || return 1
  [ -n "$(seen)" ]
  python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); assert d["version"] == 1 and list(d["repos"]) == ["acme/cwd-repo"], d' "$STATE"
}

@test "backfill: seen_until advances to the newest updated_at in the list" {  # 02:00:00 にマージされ 02:00:05 に更新された PR なら、実行後の seen_until は 02:00:05
  log_feat_a
  set_seen "2026-10-07T01:00:00Z"
  set_list "pr,300,2026-10-07T02:00:00Z,2026-10-07T02:00:05Z"
  run_backfill
  [ "$(seen)" = "2026-10-07T02:00:05Z" ]
}

@test "backfill: an empty list leaves seen_until as it was" {  # 一覧が 0 件で控えに値があれば変えない
  set_seen "2026-10-07T01:00:00Z"
  cp "$STATE" "$WORK/state.before"
  run_backfill
  cmp "$STATE" "$WORK/state.before"
}

@test "backfill: an empty list with no stored value writes this run's since" {  # 控えが無く一覧が 0 件なら、実行後の seen_until は一覧の since と同じ。gh は一覧の 1 回だけ
  [ ! -e "$STATE" ]
  run_backfill
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" -eq 1 ]
  since="$(sed -n 's/.*since=\([^&]*\).*/\1/p' "$GH_LOG.list")"
  [ -n "$since" ]
  [ "$(seen)" = "$since" ]
}

@test "backfill: empty lists in a row do not slide the 24 hour window" {  # 一覧が空の回が続いても since は 1 回目と同じで、その間にマージされた PR #300 は 2 回目で候補になる
  log_feat_a
  run_backfill
  first="$(seen)"
  recent="$(iso_ago 3600)"
  set_list "pr,300,$recent"
  run_backfill
  second="$(sed -n 's/.*since=\([^&]*\).*/\1/p' "$GH_LOG.list" | tail -n 1)"   # 一覧の問い合わせは回ごとに 1 行足される
  [ "$second" = "$first" ]
  [ "$(posts)" -eq 1 ]
}

@test "backfill: an empty list with a broken state file rewrites it as this run's since" {  # 壊れた控えで一覧が 0 件なら、控えは読める形になり seen_until は一覧の since
  printf '%s' 'not json' > "$STATE"
  run_backfill
  [ "$status" -eq 0 ]
  since="$(sed -n 's/.*since=\([^&]*\).*/\1/p' "$GH_LOG.list")"
  [ "$(seen)" = "$since" ]
}

@test "backfill: a failed list with no stored value writes no state" {  # 控えが無く一覧の取得が失敗したら控えは作られない
  export FAKE_LIST_FAIL=1
  run_backfill
  [ "$status" -eq 0 ]
  [ ! -e "$STATE" ]
}

@test "backfill: seen_until never moves backwards" {  # 控えの値より古い updated_at しか返らない一覧では値が変わらない
  set_seen "2026-10-07T01:00:00Z"
  set_list "issue,12,2026-10-07T00:10:00Z,2026-10-07T00:30:00Z"
  run_backfill
  [ "$(seen)" = "2026-10-07T01:00:00Z" ]
}

@test "backfill: a failed write for one candidate does not hold seen_until back" {  # 候補の書き込みだけが失敗しても、seen_until は一覧の更新時刻の最大値まで進む
  one_pr_candidate
  set_list "pr,300,$M,2026-09-02T00:00:09Z"
  export FAKE_POST_FAIL=1
  run_backfill
  [ "$status" -eq 0 ]
  [ "$(posts)" -eq 1 ]
  [ ! -e "$FIX/comments.300.9.json" ]
  [ "$(seen)" = "2026-09-02T00:00:09Z" ]
}

@test "backfill: a failed comment read for one candidate does not hold seen_until back" {  # 既存コメントの取得だけが失敗しても、書き込みはせず、seen_until は一覧の更新時刻の最大値まで進む
  one_pr_candidate
  set_list "pr,300,$M,2026-09-02T00:00:09Z"
  export FAKE_COMMENTS_FAIL=1
  run_backfill
  [ "$status" -eq 0 ]
  [ "$(posts)" -eq 0 ]
  [ "$(seen)" = "2026-09-02T00:00:09Z" ]
}

@test "backfill: a failed rewrite of an existing comment does not hold seen_until back" {  # 積み先のコメントの書き換え（PATCH）だけが失敗しても、seen_until は一覧の更新時刻の最大値まで進む
  one_pr_candidate
  seed_comment 300 "PR コメント" $((B + 1800))
  set_list "pr,300,$M,2026-09-02T00:00:09Z"
  export FAKE_PATCH_FAIL=1
  run_backfill
  [ "$status" -eq 0 ]
  grep -qF -- "-X PATCH" "$GH_LOG"
  [ "$(seen)" = "2026-09-02T00:00:09Z" ]
}

@test "backfill: the values of other repositories are kept, and the key is lowercased" {  # 控えの acme/other の値は実行前と同じまま残る。鍵は owner/repo を小文字にしたもの
  log_feat_a
  set_seen "2026-08-01T00:00:00Z" acme/other
  set_seen "$SEEN0"
  git -C "$CWD" remote set-url origin https://github.com/Acme/Cwd-Repo.git
  set_list "pr,300,$M"
  run_backfill
  grep -qE '^api --paginate repos/Acme/Cwd-Repo/issues\?' "$GH_LOG"
  [ "$(seen acme/other)" = "2026-08-01T00:00:00Z" ]
  [ "$(seen acme/cwd-repo)" = "$M" ]
  python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); assert sorted(d["repos"]) == ["acme/cwd-repo", "acme/other"], d' "$STATE"
}

@test "backfill: a broken state file is treated as the first run and rewritten" {  # 控えが JSON でなければ 24 時間前からの一覧になり、実行後の控えは読める形になる
  log_feat_a
  printf '%s' 'not json' > "$STATE"
  recent="$(iso_ago 3600)"
  set_list "pr,300,$recent"
  run_backfill
  python3 - "$(cat "$GH_LOG.list")" <<'PY'
import calendar, re, sys, time
since = re.search(r"since=([^&]+)", sys.argv[1]).group(1)
assert abs(calendar.timegm(time.strptime(since, "%Y-%m-%dT%H:%M:%SZ")) - (time.time() - 86400)) <= 60, since
PY
  [ "$(seen)" = "$recent" ]
}

# --- 後追いの行を積む ---

@test "backfill: acceptance: a merged pull request without a last row gets exactly one row" {  # 積み先に PR コメントの行が 1 行ある #300 に、書き換えがちょうど 1 回。表は 2 行で、2 行目は マージ・時刻は merged_at
  one_pr_candidate
  seed_comment 300 "PR コメント" $((B + 1800))
  log_timeline_args
  run_backfill
  [ "$status" -eq 0 ]
  [ "$(patches)" -eq 1 ]
  [ "$(posts)" -eq 0 ]
  grep -qF -- "-X PATCH repos/acme/cwd-repo/issues/comments/21" "$GH_LOG"
  [ "$(body_nrows)" -eq 2 ]
  [ "$(body_trigger 1)" = "PR コメント" ]
  [ "$(body_trigger 2)" = "マージ" ]
  [ "$(body_cell 2 1)" = "09/02 00:00" ]
  [ "$(body_cell 2 3)" = '$1.00 (+0.00)' ]
  grep -qE -- "^args=timeline --pr 300 --branch feat/a --trigger マージ --at $M_EPOCH\.000 --repo $CWD --target-repo acme/cwd-repo --backfill\$" "$COST_LOG"
}

@test "backfill: acceptance: running again adds nothing and calls gh once" {  # もう一度流すと、コメントの作成も書き換えも無く、gh は一覧の 1 回だけ
  one_pr_candidate
  seed_comment 300 "PR コメント" $((B + 1800))
  run_backfill
  [ "$(patches)" -eq 1 ]
  cp "$FIX/comments.300.1.json" "$WORK/comments.before"
  forget_gh_log
  run_backfill
  [ "$(gh_calls)" -eq 1 ]
  no_write
  cmp "$FIX/comments.300.1.json" "$WORK/comments.before"
}

@test "backfill: after the state file is deleted the same row is not stacked again" {  # 控えを消して流しても、時刻・きっかけ・累計が同じ行は増えない
  log_feat_a
  set_list "pr,300,$(iso_ago 3600)"
  run_backfill
  [ "$(posts)" -eq 1 ]
  cp "$FIX/comments.300.9.json" "$WORK/comments.before"
  command rm -f "$STATE"
  forget_gh_log
  run_backfill
  [ "$(gh_calls)" -eq 3 ]
  no_write
  cmp "$FIX/comments.300.9.json" "$WORK/comments.before"
}

@test "backfill: the total is cut at the merge time" {  # merged_at より前の応答（$1.00）と後の応答（$2.00）があるとき、マージの行の累計は $1.00
  {
    cl_row S1 r1 2026-09-01T00:00:10.000Z feat/a "$CWD" 1000000
    cl_row S1 r2 2026-09-03T00:00:10.000Z feat/a "$CWD" 2000000
  } | cl_write_log s1
  set_seen "$SEEN0"
  set_list "pr,300,$M"
  run_backfill
  [ "$(posts)" -eq 1 ]
  [ "$(body_cell 1 3)" = '$1.00 (+1.00)' ]
}

@test "backfill: an auto-closed issue gets the close row and the total row" {  # 自動でクローズされた issue #12 に、閉じた PR #300 を合わせた合計の行まで付く
  log_feat_a
  log_issue_12
  set_seen "$SEEN0"
  set_list "issue,12,$M"
  FAKE_CLOSING_PRS="[$(closing_node 300 feat/a)]"; export FAKE_CLOSING_PRS
  log_timeline_args
  run_backfill
  [ "$(posts)" -eq 1 ]
  grep -qF -- "-X POST repos/acme/cwd-repo/issues/12/comments" "$GH_LOG"
  grep -qE -- "^args=timeline --issue 12 --trigger issue クローズ --at $M_EPOCH\.000 --closing-pr 300:feat/a --repo $CWD --target-repo acme/cwd-repo --backfill\$" "$COST_LOG"
  [ "$(body_nrows)" -eq 2 ]
  [ "$(body_trigger 1)" = "issue クローズ" ]
  [[ "$(body_trigger 2)" == "合計（"* ]] || return 1
  ! grep -qE "repos/acme/cwd-repo/issues/12( |\$)" "$GH_LOG" || return 1   # 対象の確認の問い合わせを足さない
}

@test "backfill: a pull request from a fork is not stacked" {  # ヘッドのリポジトリがベースと違う PR では、既存コメントの取得も書き込みもしない
  one_pr_candidate
  export FAKE_HEAD_REPO=someone/cwd-repo
  run_backfill
  [ "$(gh_calls)" -eq 2 ]
  [ "$(comment_reads)" -eq 0 ]
  no_write
  [ "$(seen)" = "$M" ]
}

@test "backfill: a pull request that fails the check is not stacked" {  # 未マージ・ベースが別のリポジトリ・ヘッドブランチが空・ヘッドのリポジトリが無い、のどれでも積まない
  log_feat_a
  for override in '{"merged": false, "merged_at": null}' \
                  '{"base": {"repo": {"full_name": "acme/elsewhere"}}}' \
                  '{"head": {"ref": "", "repo": {"full_name": "acme/cwd-repo"}}}' \
                  '{"head": {"ref": "feat/a", "repo": null}}'; do
    printf '%s' "$override" > "$FIX/pull.300.json"
    forget_gh_log
    command rm -f "$STATE"
    set_seen "$SEEN0"
    set_list "pr,300,$M"
    run_backfill
    [ "$(gh_calls)" -eq 2 ]
    [ "$(comment_reads)" -eq 0 ]
    no_write
  done
}

@test "backfill: the base repository is compared without regard to case" {  # ベースとヘッドのリポジトリ名の大文字と小文字が origin と違っても積む
  one_pr_candidate
  printf '%s' '{"base": {"repo": {"full_name": "Acme/Cwd-Repo"}}, "head": {"ref": "feat/a", "repo": {"full_name": "ACME/cwd-repo"}}}' > "$FIX/pull.300.json"
  run_backfill
  [ "$(posts)" -eq 1 ]
}

@test "backfill: a row stacked by hand for the same merge is not doubled" {  # 積み先に merged_at の 5 秒後の マージ の行が既にあれば、作成も書き換えもしない
  one_pr_candidate
  seed_comment 300 "マージ" $((M_EPOCH + 5))
  run_backfill
  [ "$(gh_calls)" -eq 3 ]
  no_write
}

@test "backfill: a pull request with no local cost is not stacked" {  # ヘッドブランチの行が手元に 1 つも無ければ、別の PC が積んだ行のあるコメントを書き換えない
  one_pr_candidate
  printf '%s' '{"head": {"ref": "feat/none", "repo": {"full_name": "acme/cwd-repo"}}}' > "$FIX/pull.300.json"
  seed_comment 300 "PR コメント" $((B + 1800))
  run_backfill
  [ "$(gh_calls)" -eq 3 ]
  no_write
  [ "$(seen)" = "$M" ]
}

# --- 後追いの gh の呼び出し回数 ---

@test "backfill: one merged pull request costs four gh calls" {  # 一覧 1 回 + PR の確認・既存コメントの取得・書き込み
  one_pr_candidate
  run_backfill
  [ "$(gh_calls)" -eq 4 ]
  [ "$(list_calls)" -eq 1 ]
  queried_pull 300
  [ "$(comment_reads)" -eq 1 ]
  [ "$(posts)" -eq 1 ]
}

@test "backfill: one closed issue costs four gh calls" {  # 一覧 1 回 + 既存コメントの取得・閉じた PR の問い合わせ・書き込み
  log_issue_12
  set_seen "$SEEN0"
  set_list "issue,12,$M"
  run_backfill
  [ "$(gh_calls)" -eq 4 ]
  [ "$(list_calls)" -eq 1 ]
  [ "$(comment_reads)" -eq 1 ]
  [ "$(wc -l < "$GH_LOG.graphql" | tr -d ' ')" -eq 1 ]
  [ "$(posts)" -eq 1 ]
  [ "$(body_trigger 1)" = "issue クローズ" ]
}

# --- 後追いは同時に 1 つだけ走らせる ---

@test "backfill: while another backfill holds the lock, gh is not called" {  # <COST_LEDGER_PATH>.backfill.lock を別のプロセスが持っていれば、gh を呼ばず控えも変えない
  one_pr_candidate
  cp "$STATE" "$WORK/state.before"
  "$REAL_PYTHON" - "$LEDGER.backfill.lock" "$WORK/lock.ready" "$WORK/lock.stop" >/dev/null 2>&1 3>&- <<'PY' &
import fcntl, os, sys, time
fd = os.open(sys.argv[1], os.O_RDWR | os.O_CREAT, 0o600)
fcntl.flock(fd, fcntl.LOCK_EX)
open(sys.argv[2], "w").close()
for _ in range(300):
    if os.path.exists(sys.argv[3]):
        break
    time.sleep(0.1)
PY
  holder=$!
  for i in $(seq 1 100); do [ -e "$WORK/lock.ready" ] && break; sleep 0.1; done
  [ -e "$WORK/lock.ready" ]
  run_backfill
  touch "$WORK/lock.stop"
  wait "$holder"
  [ "$status" -eq 0 ]
  no_gh_call
  cmp "$STATE" "$WORK/state.before"
  run_backfill
  [ "$(posts)" -eq 1 ]
}

@test "backfill: two hooks at the same moment leave one comment with one row" {  # 同時に 2 つ流しても、その PR のコメントは 1 本で マージ の行は 1 行
  one_pr_candidate
  export FAKE_GH_DELAY=0.3
  session_json startup > "$WORK/payload.json"
  bash "$SCRIPT" < "$WORK/payload.json" >/dev/null 2>&1 3>&- &
  first=$!
  bash "$SCRIPT" < "$WORK/payload.json" >/dev/null 2>&1 3>&- &
  second=$!
  wait "$first"
  wait "$second"
  [ "$(posts)" -eq 1 ]
  [ "$(patches)" -eq 0 ]
  python3 - "$FIX/comments.300.9.json" <<'PY'
import json, sys
(comment,) = json.load(open(sys.argv[1], encoding="utf-8"))
rows = [l for l in comment["body"].split("\n") if l.startswith("| ") and not l.startswith("| 時刻 ")]
assert len(rows) == 1 and "| マージ |" in rows[0], rows
PY
}

# --- cost_ledger.py timeline --backfill（直接呼ぶ。gh は呼ばれない） ---

tl() { env -u COST_LEDGER_PATH python3 "$CL" timeline "$@"; }
rows() { grep '^| ' "$1" | grep -vF "$HEADER" || true; }
nrows() { rows "$1" | wc -l | tr -d ' '; }
cell() { rows "$1" | sed -n "${2}p" | awk -F'|' -v n="$3" '{v=$(n+1); sub(/^ /,"",v); sub(/ $/,"",v); print v}'; }  # $3: 1=時刻 2=きっかけ 3=金額

# 既存の本文を組み立てる。$1=最終行  標準入力=表の行
body() {
  { printf '%s\n\n%s\n%s\n' 'コスト: $1.00 / ¥150 @150 — PR #300 (feat/a) 帰属: ブランチ' "$HEADER" "$SEP"; cat; printf '\n%s\n' "$1"; }
}
# 表の行が 1 行（累計 $1.00）の本文。$1=きっかけ $2=記録の時刻（epoch 秒）
one_row_body() {
  printf '%s\n' "| 09/01 00:50 | $1 | \$1.00 (+1.00) | 1M (+1M) | 0 (+0) |" \
    | body "<!-- cost-ledger:timeline v1 $2.000:1.000000:1000000:0 -->"
}
# haiku の 1 応答（input_tokens=1000000 が $1.00）を feat/a のログに足す
add_a() {  # $1=requestId $2=時刻（HH:MM:SS） $3=input_tokens
  mkdir -p "$CONFIG_DIR/projects/a"
  cl_row S1 "$1" "2026-09-01T$2.000Z" feat/a "$CWD" "$3" >> "$CONFIG_DIR/projects/a/a.jsonl"
}
MERGE=(--pr 300 --branch feat/a --trigger マージ)

@test "timeline --backfill: a row with the same trigger near --at leaves the body as it is" {  # きっかけ マージ・記録の時刻 T+5 秒の行があれば、終了コード 0 で標準入力の本文をそのまま返す
  add_a r1 00:40:00 1000000
  add_a r2 00:55:00 1000000
  one_row_body マージ $((T + 5)) > "$IN"
  run tl "${MERGE[@]}" --at "$T" --backfill < "$IN"
  [ "$status" -eq 0 ]
  tl "${MERGE[@]}" --at "$T" --backfill < "$IN" > "$OUT"
  cmp "$IN" "$OUT"
}

@test "timeline --backfill: a joined trigger is matched by its parts" {  # きっかけが PR コメント+マージ の行も同じ出来事として見る
  add_a r1 00:40:00 1000000
  add_a r2 00:55:00 1000000
  one_row_body "PR コメント+マージ" $((T + 5)) > "$IN"
  tl "${MERGE[@]}" --at "$T" --backfill < "$IN" > "$OUT"
  cmp "$IN" "$OUT"
}

@test "timeline --backfill: without a row of the same trigger the row is added" {  # PR コメント（T−600 秒・$1.00）だけの本文に、T 以前の累計 $3.00 で積むと 2 行目が マージ・$3.00 (+2.00)
  add_a r1 00:30:00 1000000
  add_a r2 00:40:00 1000000
  add_a r3 00:55:00 1000000
  one_row_body "PR コメント" $((T - 600)) > "$IN"
  tl "${MERGE[@]}" --at "$T" --backfill < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
  [ "$(cell "$OUT" 2 2)" = "マージ" ]
  [ "$(cell "$OUT" 2 3)" = '$3.00 (+2.00)' ]
}

@test "timeline --backfill: an older close row does not block a new close" {  # issue クローズ（T−3600 秒）の行は古いので、新しい issue クローズ の行を積む
  cl_row S2 q1 2026-09-01T00:00:20.000Z main "$CWD" 1000000 "gh issue view 12" | cl_write_log s2
  one_row_body "issue クローズ" $((T - 3600)) > "$IN"
  tl --issue 12 --repo "$CWD" --trigger "issue クローズ" --at "$T" --backfill < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
  [ "$(cell "$OUT" 2 2)" = "issue クローズ" ]
}

@test "timeline --backfill: the 300-second window includes its edge" {  # 同じ呼び名の行の記録の時刻がちょうど T−300 秒なら足さず、T−301 秒なら足す
  add_a r1 00:40:00 2000000
  one_row_body マージ $((T - 300)) > "$IN"
  tl "${MERGE[@]}" --at "$T" --backfill < "$IN" > "$OUT"
  cmp "$IN" "$OUT"
  one_row_body マージ $((T - 301)) > "$IN"
  tl "${MERGE[@]}" --at "$T" --backfill < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
  [ "$(cell "$OUT" 2 2)" = "マージ" ]
}

@test "timeline --backfill: the row goes to its place by time even with later rows" {  # PR コメント（T−600・$1.00）と PR コメント（T+600・$3.00）のあいだに マージ（$2.00）が入り、後ろの行の増分が書き直される
  add_a r1 00:40:00 1000000
  add_a r2 00:55:00 1000000
  add_a r3 01:05:00 1000000
  printf '%s\n' '| 09/01 00:50 | PR コメント | $1.00 (+1.00) | 1M (+1M) | 0 (+0) |' \
                '| 09/01 01:10 | PR コメント | $3.00 (+2.00) | 3M (+2M) | 0 (+0) |' \
    | body "<!-- cost-ledger:timeline v1 $((T - 600)).000:1.000000:1000000:0 $((T + 600)).000:3.000000:3000000:0 -->" > "$IN"
  tl "${MERGE[@]}" --at "$T" --backfill < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 3 ]
  [ "$(cell "$OUT" 1 2)" = "PR コメント" ]
  [ "$(cell "$OUT" 2 2)" = "マージ" ]
  [ "$(cell "$OUT" 3 2)" = "PR コメント" ]
  [ "$(cell "$OUT" 2 3)" = '$2.00 (+1.00)' ]
  [ "$(cell "$OUT" 3 3)" = '$3.00 (+1.00)' ]
}

@test "timeline --backfill: with no local cost nothing is stacked even onto an existing body" {  # ブランチの行が手元に 1 つも無ければ、既存の本文があっても出力は空で終了コード 3
  printf '%s\n' '| 09/01 00:50 | PR コメント | $39.62 (+39.62) | 2.1M (+2.1M) | 81M (+81M) |' \
    | body "<!-- cost-ledger:timeline v1 $((T - 600)).000:39.620000:2100000:81000000 -->" > "$IN"
  run tl --pr 300 --branch feat/none --trigger マージ --at "$T" --backfill < "$IN"
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}

@test "timeline: without --backfill the same input still gets a row" {  # --backfill が無ければ今までと同じ。終了コード 0 で マージ の行が 1 行足される
  printf '%s\n' '| 09/01 00:50 | PR コメント | $39.62 (+39.62) | 2.1M (+2.1M) | 81M (+81M) |' \
    | body "<!-- cost-ledger:timeline v1 $((T - 600)).000:39.620000:2100000:81000000 -->" > "$IN"
  tl --pr 300 --branch feat/none --trigger マージ --at "$T" < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
  [ "$(cell "$OUT" 2 2)" = "マージ" ]
  # 同じきっかけの行が近くにあっても、--backfill が無ければ足す
  add_a r1 00:40:00 2000000
  one_row_body マージ $((T + 5)) > "$IN"
  tl "${MERGE[@]}" --at "$T" < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
}

@test "timeline --backfill: a zero interval is still stacked when the closing pull request has cost" {  # issue #13 に区間が無くても、閉じた PR のブランチに行があれば issue クローズ の行と合計の行を積む
  add_a r1 00:40:00 1000000
  one_row_body "issue コメント" $((T - 600)) > "$IN"
  run tl --issue 13 --repo "$CWD" --trigger "issue クローズ" --closing-pr 300:feat/a --at "$T" --backfill < "$IN"
  [ "$status" -eq 0 ]
  tl --issue 13 --repo "$CWD" --trigger "issue クローズ" --closing-pr 300:feat/a --at "$T" --backfill < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 3 ]
  [ "$(cell "$OUT" 2 2)" = "issue クローズ" ]
  [[ "$(cell "$OUT" 3 2)" == "合計（"* ]] || return 1
}

@test "timeline --backfill: zero everywhere is not stacked for an issue either" {  # 区間も閉じた PR の分も 0 なら、既存の本文があっても終了コード 3
  one_row_body "issue コメント" $((T - 600)) > "$IN"
  run tl --issue 13 --repo "$CWD" --trigger "issue クローズ" --closing-pr 300:feat/none --at "$T" --backfill < "$IN"
  [ "$status" -eq 3 ]
  [ -z "$output" ]
}

@test "timeline --backfill: a body with an unreadable last line is judged by the trigger alone" {  # 目印の行の記録が壊れていれば、時刻を見ずに呼び名だけで判定する
  add_a r1 00:40:00 2000000
  printf '%s\n' '| 08/01 00:00 | マージ | $1.00 (+1.00) | 1M (+1M) | 0 (+0) |' \
    | body '<!-- cost-ledger:timeline v1 broken -->' > "$IN"
  tl "${MERGE[@]}" --at "$T" --backfill < "$IN" > "$OUT"
  cmp "$IN" "$OUT"
}

@test "timeline --backfill: a leading row without a record is judged by the trigger alone" {  # 表の行数が記録より多いときの先頭の余りの行は、時刻を見ずに呼び名だけで判定する
  add_a r1 00:40:00 2000000
  printf '%s\n' '| 08/01 00:00 | マージ | $0.50 (+0.50) | 500K (+500K) | 0 (+0) |' \
                '| 09/01 00:50 | PR コメント | $1.00 (+0.50) | 1M (+500K) | 0 (+0) |' \
    | body "<!-- cost-ledger:timeline v1 $((T - 600)).000:1.000000:1000000:0 -->" > "$IN"
  tl "${MERGE[@]}" --at "$T" --backfill < "$IN" > "$OUT"
  cmp "$IN" "$OUT"
}

@test "timeline --backfill: a total row is not counted as the same trigger" {  # きっかけが 合計（ で始まる行は判定の対象にしない。合計の行だけがある本文に issue クローズ を積める
  cl_row S2 q1 2026-09-01T00:00:20.000Z main "$CWD" 1000000 "gh issue view 12" | cl_write_log s2
  one_row_body '合計（#300 $1.00 + PR 外 $0.00）+issue クローズ' $((T + 5)) > "$IN"
  tl --issue 12 --repo "$CWD" --trigger "issue クローズ" --at "$T" --backfill < "$IN" > "$OUT"
  [ "$(nrows "$OUT")" -eq 2 ]
  rows "$OUT" | grep -qF '| issue クローズ |'
}
