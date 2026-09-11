#!/usr/bin/env bats
#
# spec: cost-ledger-gate-report
#
# ゲート通過（agent-review:passed の付与）を PostToolUse の hook で捕まえて、PR にコストの
# 1 行を貼る gate-report.sh を固定する。実物には触れない: スクリプトを一時ディレクトリへ
# 複製し、同じディレクトリに stub の cost_ledger.py を置き（$(dirname "$0") から引くことの検査）、
# gh も PATH の先頭の stub に差し替える。

load helper

setup() {
  cl_setup
  REAL_PYTHON="$(command -v python3)"
  WORK="$BATS_TEST_TMPDIR/gate"
  FIX="$WORK/fixtures"
  CWD="$WORK/cwd"
  mkdir -p "$WORK/scripts" "$WORK/bin" "$WORK/log" "$FIX" "$CWD"
  cp "$PLUGIN_DIR/scripts/gate-report.sh" "$WORK/scripts/gate-report.sh"
  SCRIPT="$WORK/scripts/gate-report.sh"
  export GH_LOG="$WORK/log/gh.log" COST_LOG="$WORK/log/cost.log" GH_FIX="$FIX"
  export FAKE_CWD_REPO="acme/cwd-repo"
  unset COST_LEDGER_GATE_REPORT GH_REPO FAKE_GH_FAIL FAKE_PATCH_FAIL FAKE_COST_RC FAKE_COST_LINE
  write_stub_cost_ledger
  write_stub_gh
  export PATH="$WORK/bin:$PATH"
}

# 受け取った引数と GH_REPO をログに書き、固定の 1 行目を出す cost_ledger.py
write_stub_cost_ledger() {
  cat > "$WORK/scripts/cost_ledger.py" <<'PY'
import os, sys
with open(os.environ["COST_LOG"], "a", encoding="utf-8") as f:
    f.write("args=%s GH_REPO=%s\n" % (" ".join(sys.argv[1:]), os.environ.get("GH_REPO", "")))
number = sys.argv[2] if len(sys.argv) > 2 else "?"
print(os.environ.get("FAKE_COST_LINE",
                     "コスト: $1.23 / ¥185 @150 — PR #%s (oratta/sample) 帰属: ブランチ" % number))
print("  内訳（stub）")
sys.exit(int(os.environ.get("FAKE_COST_RC", "0")))
PY
}

# 呼ばれた引数を 1 呼び出し 1 行でログに書く gh。問い合わせには fixture で答える。
#   ラベル:        $GH_FIX/issue.<N>.json（無ければ agent-review:passed 付きの既定）
#   既存コメント:  $GH_FIX/comments.<N>.<ページ>.json（無ければ空の 1 ページ）
#   --jq があれば各ページに jq を当てた出力を、無ければ各ページの JSON を連結して返す
#   （本物の gh --paginate と同じ形）
write_stub_gh() {
  cat > "$WORK/bin/gh" <<'SH'
#!/usr/bin/env bash
all="$*"
printf '%s\n' "${all//$'\n'/\\n}" >> "$GH_LOG"
if [ "${FAKE_GH_FAIL:-}" = 1 ]; then echo "gh: boom" >&2; exit 1; fi
if [ "$1" = repo ]; then
  echo "repo-view-cwd=$PWD" >> "$GH_LOG"
  echo "$FAKE_CWD_REPO"
  exit 0
fi
[ "$1" = api ] || exit 0
shift
method=GET path="" jqf=""
while [ $# -gt 0 ]; do
  case "$1" in
    -X|--method) method="$2"; shift 2 ;;
    --jq|-q) jqf="$2"; shift 2 ;;
    -f|-F|--raw-field|--field) case "$2" in body=*) printf '%s' "${2#body=}" > "$GH_LOG.body";; esac; shift 2 ;;
    --paginate) shift ;;
    *) path="$1"; shift ;;
  esac
done
emit() { if [ -n "$jqf" ]; then jq -r "$jqf" "$1"; else cat "$1"; fi; }
case "$method:$path" in
  GET:repos/*/issues/*/comments)
    n="${path%/comments}"; n="${n##*/}"
    pages=$(ls "$GH_FIX"/comments."$n".*.json 2>/dev/null | sort)
    if [ -z "$pages" ]; then echo '[]' > "$GH_FIX/empty.json"; pages="$GH_FIX/empty.json"; fi
    for p in $pages; do emit "$p"; done ;;
  GET:repos/*/issues/*)
    n="${path##*/}"
    f="$GH_FIX/issue.$n.json"
    [ -f "$f" ] || { f="$GH_FIX/default-issue.json"; printf '{"number":%s,"labels":[{"name":"agent-review:pending"},{"name":"agent-review:passed"}]}' "$n" > "$f"; }
    emit "$f" ;;
  PATCH:*) [ "${FAKE_PATCH_FAIL:-}" = 1 ] && { echo "gh: patch failed" >&2; exit 1; }; echo '{}' ;;
  POST:*) echo '{}' ;;
esac
exit 0
SH
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

GRANT_LITERAL="gh api -X POST repos/oratta/claude-harness/issues/300/labels -f 'labels[]=agent-review:passed'"

# ラベルの問い合わせ（repos/<A>/issues/<N> そのもの。/comments や /labels は除く）が出たか
queried() {  # $1=owner/repo $2=番号
  grep -qE "(^| )repos/$1/issues/$2( |$)" "$GH_LOG"
}

no_gh_call() { [ ! -s "$GH_LOG" ]; }

# コメントの作成も書き換えも無い
no_write() {
  [ ! -f "$GH_LOG" ] && return 0
  ! grep -qE -- '-X (POST|PATCH) repos/[^ ]+/(issues/[0-9]+/comments|issues/comments/)' "$GH_LOG" || return 1
}

posted_to() {  # $1=owner/repo $2=番号
  grep -qF -- "-X POST repos/$1/issues/$2/comments" "$GH_LOG"
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

@test "gate-report: a Bash call without the label starts neither gh nor python3" {  # agent-review:passed を含まない Bash では gh も python3 も起動せず、無出力で 0
  use_stub_python
  run_hook "ls -la && git status"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
  [ ! -e "$WORK/log/python.log" ]
}

@test "gate-report: gh pr comment does not trigger a post" {  # gh pr comment では gh が一度も呼ばれない（本文にラベル名があっても）
  run_hook 'gh pr comment 300 --body "レビュー済み"'
  [ "$status" -eq 0 ]
  no_gh_call
  run_hook 'gh pr comment 300 --body "agent-review:passed を付けた"'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
}

@test "gate-report: COST_LEDGER_GATE_REPORT=off stops everything" {  # COST_LEDGER_GATE_REPORT=off では付与コマンドでも gh が呼ばれず、無出力で 0
  export COST_LEDGER_GATE_REPORT=off
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  no_gh_call
}

# --- 付与の判定と対象 PR の取り出し ---

@test "gate-report: a literal gh api grant targets that PR" {  # リテラルの gh api 付与で oratta/claude-harness の #300 が対象になる
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  queried oratta/claude-harness 300
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

@test "gate-report: gh pr edit --add-label targets the cwd repository" {  # -R 無しの gh pr edit は cwd で gh repo view した結果のリポジトリの #313 が対象になる
  run_hook "gh pr edit 313 --remove-label agent-review:pending --add-label agent-review:passed"
  queried acme/cwd-repo 313
  grep -qxF "repo-view-cwd=$CWD" "$GH_LOG"
}

@test "gate-report: gh pr edit with -R / --repo targets that repository" {  # -R / --repo があればそのリポジトリが対象になり、gh repo view は呼ばない
  run_hook "gh pr edit 313 -R oratta/other --add-label agent-review:passed"
  queried oratta/other 313
  run_hook "gh issue edit 314 --add-label agent-review:passed,foo --repo oratta/other"
  queried oratta/other 314
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

# --- 付与の実測・数字の取得・投稿 ---

@test "gate-report: no post when the PR does not actually carry the label" {  # 問い合わせた PR に agent-review:passed が無ければ作成も書き換えもしない
  echo '{"number":300,"labels":[{"name":"agent-review:pending"}]}' > "$FIX/issue.300.json"
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  queried oratta/claude-harness 300
  no_write
  [ ! -e "$COST_LOG" ]
}

@test "gate-report: first gate creates one marker comment with the cost line first" {  # マーカー付きのコメントが無ければ POST で 1 本作り、1 行目がコストの行・2 行目が時点・最終行がマーカー
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  posted_to oratta/claude-harness 300
  [ "$(grep -cE -- '-X (POST|PATCH)' "$GH_LOG")" -eq 1 ]
  "$REAL_PYTHON" - "$GH_LOG.body" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
assert len(lines) == 3, lines
assert lines[0] == "コスト: $1.23 / ¥185 @150 — PR #300 (oratta/sample) 帰属: ブランチ", lines[0]
assert re.fullmatch(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2} 時点・ゲート通過時に自動投稿", lines[1]), lines[1]
assert lines[2] == "<!-- cost-ledger:gate-report -->", lines[2]
PY
}

@test "gate-report: a re-gate patches the existing marker comment" {  # マーカー付きのコメントがあれば PATCH で書き換え、POST しない
  echo '[{"id":11,"body":"LGTM"},{"id":555,"body":"コスト: $0.10\nold\n<!-- cost-ledger:gate-report -->"}]' > "$FIX/comments.300.1.json"
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  grep -qF -- "-X PATCH repos/oratta/claude-harness/issues/comments/555" "$GH_LOG"
  ! posted_to oratta/claude-harness 300 || return 1
  head -1 "$GH_LOG.body" | grep -qF 'コスト: $1.23'
}

@test "gate-report: the marker comment is found on the second page" {  # マーカー付きのコメントが 2 ページ目にあっても PATCH になる
  echo '[{"id":11,"body":"LGTM"}]' > "$FIX/comments.300.1.json"
  echo '[{"id":777,"body":"x\n<!-- cost-ledger:gate-report -->"},{"id":778,"body":"y\n<!-- cost-ledger:gate-report -->"}]' > "$FIX/comments.300.2.json"
  run_hook "$GRANT_LITERAL"
  grep -qF -- "-X PATCH repos/oratta/claude-harness/issues/comments/777" "$GH_LOG"
  ! grep -qF -- "issues/comments/778" "$GH_LOG" || return 1
  ! posted_to oratta/claude-harness 300 || return 1
}

@test "gate-report: a failed PATCH does not fall back to POST" {  # PATCH が失敗しても POST に切り替えない
  echo '[{"id":555,"body":"x\n<!-- cost-ledger:gate-report -->"}]' > "$FIX/comments.300.1.json"
  export FAKE_PATCH_FAIL=1
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  grep -qF -- "-X PATCH repos/oratta/claude-harness/issues/comments/555" "$GH_LOG"
  ! posted_to oratta/claude-harness 300 || return 1
}

@test "gate-report: cost is asked with GH_REPO set to the labelled repository" {  # cost <N> --repo <cwd> を GH_REPO=付与先で呼ぶ。cwd のリポジトリと違っても付与先になる
  run_hook "$GRANT_LITERAL"
  grep -qxF "args=cost 300 --repo $CWD GH_REPO=oratta/claude-harness" "$COST_LOG"
  : > "$COST_LOG"
  run_hook "gh pr edit 313 -R oratta/other --add-label agent-review:passed"
  grep -qxF "args=cost 313 --repo $CWD GH_REPO=oratta/other" "$COST_LOG"
}

@test "gate-report: works without transcript_path and from a subagent transcript" {  # transcript_path が無くても、サブエージェントのトランスクリプトを指していても貼る
  HOOK_TRANSCRIPT=- run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  posted_to oratta/claude-harness 300
  : > "$GH_LOG"
  HOOK_TRANSCRIPT=/tmp/claude/projects/p/S1/subagents/agent-a1.jsonl run_hook "$GRANT_LITERAL"
  posted_to oratta/claude-harness 300
}

@test "gate-report: a for loop grant posts to each PR" {  # for で 2 件付与したら #96 と #97 のそれぞれに貼る
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
}

@test "gate-report: no post when cost fails or its first line is not a cost line" {  # cost_ledger.py が 0 以外、または 1 行目が「コスト: 」で始まらなければ貼らない
  export FAKE_COST_RC=1
  run_hook "$GRANT_LITERAL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -s "$COST_LOG" ]
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
