#!/usr/bin/env bats
#
# subagent-stop-guard.sh: 自分が run_in_background で起動した背景タスクを終わらせないまま
# ターンを終えようとするサブエージェントの停止を、SubagentStop hook で拒否する（issue #264）。
#
# spec: openspec/specs/dev-workflow-subagent-waiting
#       「未完了の背景タスクを残したサブエージェントの停止を実行時に拒否する」
#       「停止の拒否は上限回数までの後詰めにする」
#       「停止の拒否はサブエージェントに限り、判定できなければ通す」
#       「実行時の検査が文言検査の素通りする違反を止めることを再現ケースで示す」
#
# 未完了 = {自分のトランスクリプトの tool_result 本文 `Command running in background with ID: <id>` の id}
#        ∩ {payload background_tasks のうち status:"running" の id}
# テスト名は ASCII のみ。

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/subagent-stop-guard.sh"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  CANON="${PLUGIN_DIR}/references/subagent-waiting.md"
  WORK="${BATS_TEST_TMPDIR}/w"
  PARENT_DIR="${WORK}/projects/-Users-x-repo"
  SESS="11111111-2222-3333-4444-555555555555"
  AGENT_ID="a17e28bcaab978169"
  mkdir -p "$PARENT_DIR"
  TRANSCRIPT_PATH="${PARENT_DIR}/${SESS}.jsonl"
  : > "$TRANSCRIPT_PATH"
  SUBAGENTS="${PARENT_DIR}/${SESS}/subagents"
  TRANSCRIPT="${SUBAGENTS}/agent-${AGENT_ID}.jsonl"
  # カウンタの置き場をテストごとに分ける
  export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  mkdir -p "$TMPDIR"
  COUNTER_DIR="${TMPDIR}/dev-workflow-stop-guard"
  unset DEV_WORKFLOW_STOP_GUARD || true
}

# サブエージェントのトランスクリプトを始める（背景起動は無い）: $1=ファイル（省略時 $TRANSCRIPT）
new_transcript() {
  local f="${1:-$TRANSCRIPT}"
  mkdir -p "$(dirname "$f")"
  printf '{"type":"user","isSidechain":true,"agentId":"%s","message":{"role":"user","content":"work"}}\n' "$AGENT_ID" > "$f"
  printf '{"type":"assistant","isSidechain":true,"message":{"role":"assistant","content":[{"type":"text","text":"ok"}]}}\n' >> "$f"
}

# 背景起動の tool_result を 1 行足す。実測の形（type:"user"・toolUseResult は null・ID は本文だけ）に合わせる。
# $1=タスク ID  $2=ファイル（省略時 $TRANSCRIPT）  $3=記録の type（省略時 user）
add_launch() {
  local id="$1" f="${2:-$TRANSCRIPT}" typ="${3:-user}"
  ID="$id" TYP="$typ" python3 - >> "$f" <<'PY'
import json, os
i = os.environ["ID"]
body = ("Command running in background with ID: %s. Output is being written to: "
        "/private/tmp/claude-501/x/tasks/%s.output. You will be notified when it completes. "
        "To check interim output, use Read on that file path." % (i, i))
print(json.dumps({"type": os.environ["TYP"], "isSidechain": True, "toolUseResult": None,
                  "message": {"role": "user", "content": [
                      {"type": "tool_result", "tool_use_id": "toolu_" + i, "content": body}]}},
                 ensure_ascii=False))
PY
}

# payload を作る。$1=background_tasks の JSON 配列（"-" でキーごと出さない）
# 環境変数 NO_AGENT=1 で agent_id を出さない。ATP=<path> で agent_transcript_path を出す。
payload() {
  BT="$1" SESS="$SESS" TP="$TRANSCRIPT_PATH" AID="$AGENT_ID" python3 - <<'PY'
import json, os
d = {"session_id": os.environ["SESS"], "transcript_path": os.environ["TP"], "cwd": "/tmp/x",
     "hook_event_name": "SubagentStop", "stop_hook_active": os.environ.get("SHA") == "1",
     "last_assistant_message": "完了を待ちます"}
if os.environ.get("NO_AGENT") != "1":
    d["agent_id"] = os.environ["AID"]
    d["agent_type"] = "general-purpose"
if os.environ.get("ATP"):
    d["agent_transcript_path"] = os.environ["ATP"]
if os.environ["BT"] != "-":
    d["background_tasks"] = json.loads(os.environ["BT"])
print(json.dumps(d, ensure_ascii=False))
PY
}

# background_tasks の配列を作る: 停止する本人（subagent）＋ 引数の id を shell/running で並べる
bt_running() {
  python3 - "$AGENT_ID" "$@" <<'PY'
import json, sys
a = [{"id": sys.argv[1], "type": "subagent", "status": "running", "description": "self", "agent_type": "general-purpose"}]
for i in sys.argv[2:]:
    a.append({"id": i, "type": "shell", "status": "running", "description": "bg", "command": "sleep 20"})
print(json.dumps(a))
PY
}

run_hook() {  # $1=payload の JSON。stdout と stderr を分けて取る
  printf '%s' "$1" > "${BATS_TEST_TMPDIR}/payload.json"
  run --separate-stderr bash -c "'$SCRIPT' < '${BATS_TEST_TMPDIR}/payload.json'"
}

assert_block() {
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["decision"]=="block", d; assert d["reason"], d'
}

assert_silent() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

reason() {
  echo "$output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["reason"])'
}

# ---------- 2.1 / 2.2 拒否と理由文 ----------

@test "script: exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "block: a launch still running in background_tasks is refused" {
  new_transcript; add_launch bushn690g
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_block
}

@test "block: the reason names the task, the foreground wait, TaskStop, the canonical path and the count" {
  new_transcript; add_launch bushn690g
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_block
  r="$(reason)"
  echo "$r"
  echo "$r" | grep -qF 'bushn690g'
  echo "$r" | grep -qF '/tasks/bushn690g.output'
  echo "$r" | grep -q '前景の待ちループ'
  echo "$r" | grep -qF 'ターンを終えてはならない'
  echo "$r" | grep -qF 'TaskStop'
  echo "$r" | grep -qF 'references/subagent-waiting.md'
  echo "$r" | grep -qF '1/3'
}

@test "block: the reason does not restate the wait values or the marker template" {
  new_transcript; add_launch bushn690g
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_block
  r="$(reason)"
  for pat in '540000' '__CODEX_DONE' '27 分' 'timeout:' 'until grep' 'sleep 10'; do
    if echo "$r" | grep -qF -- "$pat"; then
      echo "reason restates '$pat'"; return 1
    fi
  done
}

@test "block: only the still-running launches are listed" {
  new_transcript; add_launch b1done; add_launch b2live
  run_hook "$(payload "$(bt_running b2live)")"
  assert_block
  r="$(reason)"
  echo "$r" | grep -qF 'b2live'
  ! echo "$r" | grep -qF 'b1done' || return 1
}

# ---------- 2.3 通す入力 ----------

@test "pass: a launched task absent from background_tasks (completed or stopped)" {
  new_transcript; add_launch bushn690g
  run_hook "$(payload "$(bt_running)")"
  assert_silent
  [ -z "$stderr" ]
}

@test "pass: a launched task whose status is not running (including unknown values)" {
  new_transcript; add_launch bx1; add_launch bx2
  bt='[{"id":"bx1","type":"shell","status":"completed"},{"id":"bx2","type":"shell","status":"weird"}]'
  run_hook "$(payload "$bt")"
  assert_silent
}

@test "pass: no background launch in the transcript" {
  new_transcript
  run_hook "$(payload "$(bt_running)")"
  assert_silent
}

@test "pass: an empty background_tasks array" {
  new_transcript; add_launch bushn690g
  run_hook "$(payload '[]')"
  assert_silent
}

@test "ownership: the launch text in a non-user record is not counted as a launch" {
  # type:"user" の tool_result 以外（assistant の本文に同じ文字列を書いた等）は所有とみなさない
  new_transcript; add_launch bquoted "$TRANSCRIPT" assistant
  run_hook "$(payload "$(bt_running bquoted)")"
  assert_silent
}

# ---------- 2.11 本体の背景タスク ----------

@test "pass: a parent shell (ci-watch.sh wait) running while this subagent launched nothing" {
  new_transcript
  bt="$(python3 -c 'import json,sys; print(json.dumps([
    {"id": sys.argv[1], "type": "subagent", "status": "running", "description": "self"},
    {"id": "bparent01", "type": "shell", "status": "running", "description": "CI watch",
     "command": "plugins/dev-workflow/scripts/ci-watch.sh wait oratta/claude-harness 540"}]))' "$AGENT_ID")"
  run_hook "$(payload "$bt")"
  assert_silent
}

@test "pass: a parent shell running while this subagent's own launch has finished" {
  new_transcript; add_launch bmine
  run_hook "$(payload "$(bt_running bparent01)")"
  assert_silent
}

# ---------- 2.4 拒否の上限（後詰め） ----------

@test "limit: refused up to the limit, then passed with one stderr line and the counter removed" {
  new_transcript; add_launch bushn690g
  p="$(payload "$(bt_running bushn690g)")"
  for n in 1 2 3; do
    run_hook "$p"
    assert_block
    reason | grep -qF "${n}/3"
  done
  counter="${COUNTER_DIR}/${SESS}-${AGENT_ID}.count"
  [ -f "$counter" ]
  run_hook "$p"
  assert_silent
  [ -n "$stderr" ]
  [ "$(printf '%s\n' "$stderr" | wc -l | tr -d ' ')" -eq 1 ]
  [ ! -e "$counter" ]
}

@test "limit: another agent_id is counted separately" {
  new_transcript; add_launch bushn690g
  p="$(payload "$(bt_running bushn690g)")"
  run_hook "$p"; assert_block
  run_hook "$p"; assert_block
  OTHER="a0000000000000001"
  T2="${SUBAGENTS}/agent-${OTHER}.jsonl"
  new_transcript "$T2"; add_launch bother "$T2"
  p2="$(AGENT_ID="$OTHER" payload "$(AGENT_ID="$OTHER" bt_running bother)")"
  run_hook "$p2"
  assert_block
  reason | grep -qF '1/3'
}

@test "limit: stop_hook_active=true is still refused within the limit" {
  new_transcript; add_launch bushn690g
  p="$(payload "$(bt_running bushn690g)")"
  run_hook "$p"; assert_block
  p="$(SHA=1 payload "$(bt_running bushn690g)")"
  run_hook "$p"
  assert_block
  reason | grep -qF '2/3'
}

# ---------- 2.5 上限回数の定数と正本の一致 ----------

@test "limit: the hook's constant equals the total wait cap in the canonical contract" {
  canon="$(grep -oE '上限は前景ループ [0-9]+ 回' "$CANON" | grep -oE '[0-9]+' | head -n1)"
  hook="$(grep -oE '^MAX_BLOCKS = [0-9]+' "$SCRIPT" | grep -oE '[0-9]+')"
  [ -n "$canon" ] || { echo "hint: 正本に「上限は前景ループ N 回」が見つからない"; return 1; }
  [ -n "$hook" ] || { echo "hint: hook に MAX_BLOCKS = N が見つからない"; return 1; }
  [ "$canon" = "$hook" ] || {
    echo "hint: 正本の上限回数 ${canon} と hook の MAX_BLOCKS ${hook} が違う。hook の定数を正本に合わせる"
    return 1
  }
}

# ---------- 2.6 fail-open と全解除 ----------

@test "fail-open: no agent_id (main session) is silent on stdout and stderr" {
  new_transcript; add_launch bushn690g
  run_hook "$(NO_AGENT=1 payload "$(bt_running bushn690g)")"
  assert_silent
  [ -z "$stderr" ]
}

@test "fail-open: DEV_WORKFLOW_STOP_GUARD=off is silent on stdout and stderr" {
  new_transcript; add_launch bushn690g
  export DEV_WORKFLOW_STOP_GUARD=off
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_silent
  [ -z "$stderr" ]
}

@test "fail-open: python3 missing is silent" {
  new_transcript; add_launch bushn690g
  p="$(payload "$(bt_running bushn690g)")"
  printf '%s' "$p" > "${BATS_TEST_TMPDIR}/payload.json"
  shim="${BATS_TEST_TMPDIR}/shim"; mkdir -p "$shim"
  for c in bash cat dirname; do ln -s "$(command -v "$c")" "${shim}/${c}"; done
  run --separate-stderr env PATH="$shim" bash -c "'$SCRIPT' < '${BATS_TEST_TMPDIR}/payload.json'"
  assert_silent
  [ -z "$stderr" ]
}

@test "fail-open: a broken payload is silent" {
  run_hook '{"agent_id": "a1", not json'
  assert_silent
  [ -z "$stderr" ]
  run_hook '["agent_id"]'
  assert_silent
}

@test "fail-open: a missing transcript passes with one stderr line" {
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_silent
  [ -n "$stderr" ]
}

@test "fail-open: a counter directory that cannot be created passes with one stderr line" {
  new_transcript; add_launch bushn690g
  : > "$COUNTER_DIR"    # 同名のファイルがあるとディレクトリを作れない
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_silent
  [ -n "$stderr" ]
}

@test "fail-open: an unreadable counter passes with one stderr line" {
  new_transcript; add_launch bushn690g
  mkdir -p "$COUNTER_DIR"
  printf 'garbage' > "${COUNTER_DIR}/${SESS}-${AGENT_ID}.count"
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_silent
  [ -n "$stderr" ]
}

@test "fail-open: a payload without background_tasks passes with one stderr line" {
  new_transcript; add_launch bushn690g
  run_hook "$(payload -)"
  assert_silent
  [ -n "$stderr" ]
  [ "$(printf '%s\n' "$stderr" | wc -l | tr -d ' ')" -eq 1 ]
}

# ---------- 2.7 対象トランスクリプトの解決 ----------

@test "resolve: agent_transcript_path is used when present" {
  elsewhere="${WORK}/elsewhere/agent-x.jsonl"
  new_transcript "$elsewhere"; add_launch bushn690g "$elsewhere"
  # 導出先には起動の無いトランスクリプトを置き、agent_transcript_path のほうが読まれることを見る
  new_transcript
  run_hook "$(ATP="$elsewhere" payload "$(bt_running bushn690g)")"
  assert_block
}

@test "resolve: without agent_transcript_path the path is derived from transcript_path, session_id and agent_id" {
  new_transcript; add_launch bushn690g
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_block
}

@test "resolve: a transcript nested below subagents/ is found by the bounded search" {
  nested="${SUBAGENTS}/a/b/agent-${AGENT_ID}.jsonl"
  new_transcript "$nested"; add_launch bushn690g "$nested"
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_block
}

@test "resolve: deeper than three levels is not found (same bound as context-tripwire.sh)" {
  deep="${SUBAGENTS}/a/b/c/agent-${AGENT_ID}.jsonl"
  new_transcript "$deep"; add_launch bushn690g "$deep"
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_silent
}

@test "resolve: the search gives up past the entry budget (same bound as context-tripwire.sh)" {
  mkdir -p "${SUBAGENTS}/deep"
  for i in $(seq 1 260); do : > "${SUBAGENTS}/filler-${i}.jsonl"; done
  nested="${SUBAGENTS}/deep/agent-${AGENT_ID}.jsonl"
  new_transcript "$nested"; add_launch bushn690g "$nested"
  run_hook "$(payload "$(bt_running bushn690g)")"
  assert_silent
}

# ---------- 2.8 性能 ----------

@test "cost: one hook run on a 5MB transcript stays under 200ms (best of 3)" {
  new_transcript
  python3 - "$TRANSCRIPT" <<'PY'
import json, sys
line = json.dumps({"type": "user", "message": {"role": "user", "content": [
    {"type": "tool_result", "tool_use_id": "toolu_x", "content": "x" * 900}]}}) + "\n"
with open(sys.argv[1], "a") as fh:
    for _ in range(5200):
        fh.write(line)
PY
  add_launch bushn690g
  [ "$(wc -c < "$TRANSCRIPT")" -gt 5000000 ]
  p="$(payload "$(bt_running bushn690g)")"
  printf '%s' "$p" > "${BATS_TEST_TMPDIR}/payload.json"
  best=99999
  for _ in 1 2 3; do
    rm -rf "$COUNTER_DIR"
    t0="$(python3 -c 'import time;print(int(time.time()*1000))')"
    bash -c "'$SCRIPT' < '${BATS_TEST_TMPDIR}/payload.json'" >/dev/null
    t1="$(python3 -c 'import time;print(int(time.time()*1000))')"
    d=$(( t1 - t0 ))
    if [ "$d" -lt "$best" ]; then best=$d; fi
  done
  echo "elapsed(best of 3) = ${best}ms"
  [ "$best" -lt 200 ]
}

# ---------- 2.9 hooks.json ----------

@test "hooks.json: SubagentStop runs subagent-stop-guard.sh" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]
entries = d["SubagentStop"]
hit = [h for e in entries for h in e["hooks"] if "subagent-stop-guard.sh" in h["command"]]
assert len(hit) == 1, entries
assert hit[0]["type"] == "command"
assert hit[0]["command"] == "${CLAUDE_PLUGIN_ROOT}/scripts/subagent-stop-guard.sh", hit[0]
PY
}

@test "hooks.json: the pre-existing entries are unchanged" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]
assert set(d) == {"SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "SubagentStop"}, sorted(d)
assert d["SessionStart"] == [{"matcher": "startup|clear|compact", "hooks": [
    {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/session-tripwires.sh"}]}], d["SessionStart"]
assert d["UserPromptSubmit"] == [{"hooks": [
    {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/prompt-tripwires-refresh.sh"}]}], d["UserPromptSubmit"]
assert d["PreToolUse"] == [
    {"matcher": "Agent", "hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/agent-model-guard.sh"}]},
    {"matcher": "Edit|Write|NotebookEdit|Bash", "hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh"}]},
], d["PreToolUse"]
assert d["PostToolUse"] == [{"hooks": [
    {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh"}]}], d["PostToolUse"]
PY
}

# ---------- 2.10 文言検査の素通りと実行時の検査の対 ----------

@test "paired: a paraphrased wait-by-ending-the-turn passes subagent-waiting.bats, and the hook refuses it" {
  # (1) 文言検査は素通りする: プラグインを丸ごと複製し、複製の worker.md に禁止語を使わずに
  #     言い換えた違反を差し込んで、複製に対して既存の subagent-waiting.bats を実際に走らせる。
  #     既存の禁止 1 行は消さずに足す（構造検査を満たし続けるため）。禁止語のリストはここに写さない。
  copy="${BATS_TEST_TMPDIR}/plugin-copy"
  cp -R "$PLUGIN_DIR" "$copy"
  worker="${copy}/skills/develop/references/roles/worker.md"
  violation='- フルテストは run_in_background で起動し、結果の知らせが届くまでいったん手を止めてこのターンを締める'
  printf '\n%s\n' "$violation" >> "$worker"
  grep -qF "$violation" "$worker"
  run bats "${copy}/tests/subagent-waiting.bats"
  echo "$output" | tail -n 5
  [ "$status" -eq 0 ]

  # (2) 実行時の検査は止める: 同じ違反どおりに動いたトランスクリプト（背景起動 1 件・終了せず）と
  #     payload（同じ ID が running）で、hook が停止を拒否する。
  new_transcript; add_launch bfulltest1
  printf '{"type":"assistant","isSidechain":true,"message":{"role":"assistant","content":[{"type":"text","text":"結果の知らせが届くまで手を止めます"}]}}\n' >> "$TRANSCRIPT"
  run_hook "$(payload "$(bt_running bfulltest1)")"
  assert_block
}

# ---------- 2.12 実測 payload による形式のピン留め ----------

@test "pinned: the real probe (a) first SubagentStop payload is refused" {
  # 原本: https://github.com/oratta/claude-harness/issues/264#issuecomment-5851393522
  # （Claude Code 2.1.283、2026-09-27）。payload は原本のまま、2 つの path だけを合成トランスクリプトに差し替える。
  fx="${BATS_TEST_TMPDIR}/fx"; mkdir -p "$fx"
  cat > "${fx}/payload.json" <<'JSON'
{
  "session_id": "e1111253-d57d-4fb9-8d17-06dfe2f4516b",
  "transcript_path": "/Users/oratta/.claude/projects/-private-tmp-claude-501--Users-oratta-orca-workspaces-claude-harness-issue-264-498f74cd-5026-42dc-afda-063e418ef315-scratchpad-probe-work/e1111253-d57d-4fb9-8d17-06dfe2f4516b.jsonl",
  "cwd": "/private/tmp/claude-501/-Users-oratta-orca-workspaces-claude-harness-issue-264/498f74cd-5026-42dc-afda-063e418ef315/scratchpad/probe/work",
  "prompt_id": "e8acdc16-e9b0-4096-a6b9-049eeec7d312",
  "permission_mode": "bypassPermissions",
  "agent_id": "a17e28bcaab978169",
  "agent_type": "general-purpose",
  "hook_event_name": "SubagentStop",
  "stop_hook_active": false,
  "agent_transcript_path": "/Users/oratta/.claude/projects/-private-tmp-claude-501--Users-oratta-orca-workspaces-claude-harness-issue-264-498f74cd-5026-42dc-afda-063e418ef315-scratchpad-probe-work/e1111253-d57d-4fb9-8d17-06dfe2f4516b/subagents/agent-a17e28bcaab978169.jsonl",
  "background_tasks": [
    {
      "id": "a17e28bcaab978169",
      "type": "subagent",
      "status": "running",
      "description": "背景タスク起動のプローブ",
      "agent_type": "general-purpose"
    },
    {
      "id": "bushn690g",
      "type": "shell",
      "status": "running",
      "description": "Background task that sleeps and outputs A-DONE",
      "command": "sleep 20; echo A-DONE"
    }
  ],
  "session_crons": [],
  "last_assistant_message": "完了を待ちます"
}
JSON
  cat > "${fx}/launch.txt" <<'TXT'
Command running in background with ID: bushn690g. Output is being written to: /private/tmp/claude-501/-private-tmp-claude-501--Users-oratta-orca-workspaces-claude-harness-issue-264-498f74cd-5026-42dc-afda-063e418ef315-scratchpad-probe-work/e1111253-d57d-4fb9-8d17-06dfe2f4516b/tasks/bushn690g.output. You will be notified when it completes. To check interim output, use Read on that file path.
TXT
  parent="${fx}/projects/-probe-work"
  sub="${parent}/e1111253-d57d-4fb9-8d17-06dfe2f4516b/subagents"
  mkdir -p "$sub"
  : > "${parent}/e1111253-d57d-4fb9-8d17-06dfe2f4516b.jsonl"
  FX="$fx" PARENT="$parent" SUB="$sub" python3 - <<'PY'
import json, os
fx, parent, sub = os.environ["FX"], os.environ["PARENT"], os.environ["SUB"]
body = open(os.path.join(fx, "launch.txt"), encoding="utf-8").read().rstrip("\n")
t = os.path.join(sub, "agent-a17e28bcaab978169.jsonl")
with open(t, "w", encoding="utf-8") as f:
    f.write(json.dumps({"type": "user", "isSidechain": True, "message": {"role": "user", "content": "probe"}}) + "\n")
    f.write(json.dumps({"type": "user", "isSidechain": True, "toolUseResult": None, "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": "toolu_probe", "content": body}]}}, ensure_ascii=False) + "\n")
p = json.load(open(os.path.join(fx, "payload.json"), encoding="utf-8"))
p["transcript_path"] = os.path.join(parent, "e1111253-d57d-4fb9-8d17-06dfe2f4516b.jsonl")
p["agent_transcript_path"] = t
json.dump(p, open(os.path.join(fx, "payload.local.json"), "w", encoding="utf-8"), ensure_ascii=False)
PY
  run_hook "$(cat "${fx}/payload.local.json")"
  assert_block
  r="$(reason)"
  echo "$r" | grep -qF 'bushn690g'
  # 停止する本人（type:"subagent"）は起動記録が無いので未完了に数えない
  ! echo "$r" | grep -qF 'a17e28bcaab978169' || return 1
}
