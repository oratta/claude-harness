#!/usr/bin/env bats
#
# context-tripwire.sh: サブエージェントが 1 回の起動の中でコンテキストを膨らませ続けるのを
# 途中で止める hook。PostToolUse で上限超を通知し、さらに越えたら PreToolUse で編集系を拒否する。
#
# spec: openspec/specs/dev-workflow-execution-strategy「起動の途中でコンテキストを測る hook」
#       同「上限超は PostToolUse の additionalContext で締めを通知する」
#       同「強制停止の閾値を超えたら PreToolUse が編集を拒否する」
#       同「worktree 隔離のサブエージェントでも途中計測が効く」

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/context-tripwire.sh"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  WORK="$(mktemp -d)"
  PROJECTS="${WORK}/projects"
  SLUG="-Users-x-repo"
  SESS="11111111-2222-3333-4444-555555555555"
  AGENT_ID="ab9e20b3cde9ae07"
  PARENT_DIR="${PROJECTS}/${SLUG}"
  mkdir -p "$PARENT_DIR"
  TRANSCRIPT_PATH="${PARENT_DIR}/${SESS}.jsonl"
  : > "$TRANSCRIPT_PATH"
  SUBAGENTS="${PARENT_DIR}/${SESS}/subagents"
  # 既定の閾値では実データが要るので、テストは常に閾値を明示して振る舞いを固定する
  export DEV_WORKFLOW_CONTEXT_CAP=150000
  export DEV_WORKFLOW_CONTEXT_HARD_CAP=220000
  unset DEV_WORKFLOW_CONTEXT_TRIPWIRE || true
}

teardown() {
  rm -rf "$WORK"
}

# トランスクリプトを 1 本置く: $1=置き場のディレクトリ $2=ファイル名 $3..=各 assistant の (input,cache_create,cache_read)
make_transcript() {
  local dir="$1" fname="$2"; shift 2
  mkdir -p "$dir"
  local f="${dir}/${fname}"
  printf '{"type":"user","isSidechain":true,"cwd":"/tmp/x","message":{"role":"user","content":"hi"}}\n' > "$f"
  local triple i c r
  for triple in "$@"; do
    IFS=, read -r i c r <<<"$triple"
    printf '{"type":"assistant","message":{"model":"claude-sonnet-5","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":10}}}\n' "$i" "$c" "$r" >> "$f"
  done
  echo "$f"
}

# hook の payload を作る: $1=event $2=agent_id（空ならフィールドごと出さない） $3=tool_name $4=command（Bash のとき）
# agent_id が空のときに文字列 "agent_id" が payload に一切現れないことが、bash 側の早期脱出の前提。
payload() {
  EV="$1" AID="$2" TOOL="$3" CMD="${4-}" SESS="$SESS" TP="$TRANSCRIPT_PATH" python3 - <<'PY'
import json, os
d = {"hook_event_name": os.environ["EV"], "session_id": os.environ["SESS"],
     "transcript_path": os.environ["TP"], "cwd": "/tmp/x", "tool_name": os.environ["TOOL"]}
if os.environ["AID"]:
    d["agent_id"] = os.environ["AID"]
if os.environ["TOOL"] == "Bash":
    d["tool_input"] = {"command": os.environ["CMD"]}
elif os.environ["TOOL"]:
    d["tool_input"] = {"file_path": "/tmp/x/a.txt"}
print(json.dumps(d))
PY
}

# ---------- 1. 計測ロジック ----------

@test "script: exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "measure: sums input + cache_creation + cache_read of the LAST assistant record" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "1000,2000,3000" "500,0,200000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  # 合算は 500+0+200000 = 200500（最後のレコードだけ）。cap 150000 超なので通知が出る
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert '200500' in d['hookSpecificOutput']['additionalContext'], d"
}

@test "measure: broken lines in the middle are skipped, last valid usage wins" {
  f="$(make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "1,1,1")"
  printf 'not json at all\n' >> "$f"
  printf 'null\n' >> "$f"
  printf '{"type":"assistant","message":{"usage":{"input_tokens":100,"cache_creation_input_tokens":400,"cache_read_input_tokens":199500,"output_tokens":1}}}\n' >> "$f"
  printf '{"type":"user","message":{"role":"user","content":"x"}}\n' >> "$f"
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert '200000' in d['hookSpecificOutput']['additionalContext'], d"
}

@test "measure: transcript without any usage is silent (fail-open)" {
  mkdir -p "$SUBAGENTS"
  printf '{"type":"user","message":{"role":"user","content":"hi"}}\n' > "${SUBAGENTS}/agent-${AGENT_ID}.jsonl"
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "measure: missing transcript is silent (fail-open)" {
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "measure: subagent-context.sh --file and the hook report the same value" {
  # 末尾 256KB に最後の assistant usage が含まれる短いトランスクリプトで比較する。
  # 末尾 256KB の外にある場合は hook 側が fail-open で無音になり、一致しないのが正しい挙動。
  f="$(make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "1000,2000,3000" "7000,3000,90000")"
  run "${PLUGIN_DIR}/scripts/subagent-context.sh" --file "$f" --cap 150000
  [ "$status" -eq 0 ]
  from_script="$(echo "$output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["context_tokens"])')"
  # hook は上限内だと無音なので、cap を小さくして additionalContext 中の計測値を読む
  run bash -c "DEV_WORKFLOW_CONTEXT_CAP=1000 '$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  from_hook="$(echo "$output" | python3 -c 'import json,re,sys; print(re.search(r"(\d+) tokens", json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]).group(1))')"
  [ "$from_script" = "$from_hook" ]
  [ "$from_script" = "100000" ]
}

# ---------- 2. 早期脱出と fail-open ----------

@test "early exit: a payload without agent_id does not start python3" {
  # メインスレッド（agent_id 無し）は install 先の全ユーザーの全ツール呼び出しの大多数なので、
  # そこに python3 の起動コストを課さない。PATH に置いた偽 python3 が呼ばれないことで検査する。
  shim="${WORK}/shim"; mkdir -p "$shim"
  printf '#!/bin/sh\ntouch "%s/python3-was-called"\nexit 0\n' "$WORK" > "${shim}/python3"
  chmod +x "${shim}/python3"
  p="$(payload PostToolUse "" Read)"
  run bash -c "PATH=\"${shim}:\$PATH\" '$SCRIPT' <<< '$p'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "${WORK}/python3-was-called" ]
  # 逆方向（サブエージェントなのに素通り）は起きない: agent_id は JSON キーとして必ず入る。
  # 文字列 "agent_id" を含む Bash コマンドをメインスレッドで打つと python3 は起動するが、
  # その先で agent_id フィールドが無いと判定されて fail-open するだけなので無害。
}

@test "early exit: mainthread payload mentioning agent_id in a command stays silent" {
  run bash -c "'$SCRIPT' <<< '$(payload PreToolUse "" Bash "grep agent_id foo.json")'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fail-open: DEV_WORKFLOW_CONTEXT_TRIPWIRE=off silences everything" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,900000" >/dev/null
  run bash -c "DEV_WORKFLOW_CONTEXT_TRIPWIRE=off '$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fail-open: a non-integer cap is silent" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,900000" >/dev/null
  run bash -c "DEV_WORKFLOW_CONTEXT_CAP=abc '$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fail-open: unparsable stdin is silent" {
  run bash -c "printf '{\"agent_id\": broken' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "silent: under the cap nothing is emitted" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "1000,1000,1000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------- 2.4 入れ子のサブエージェント ----------

@test "nested: a transcript two levels below subagents/ is found" {
  make_transcript "${SUBAGENTS}/agent-parent" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q additionalContext
}

@test "nested: a transcript three levels below subagents/ is found" {
  make_transcript "${SUBAGENTS}/a/b" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q additionalContext
}

@test "nested: deeper than three levels is not found (fail-open)" {
  make_transcript "${SUBAGENTS}/a/b/c" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "nested: the scan gives up past the entry budget" {
  mkdir -p "${SUBAGENTS}/deep"
  for i in $(seq 1 260); do : > "${SUBAGENTS}/filler-${i}.jsonl"; done
  make_transcript "${SUBAGENTS}/deep" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------- 2.6 PostToolUse の通知 ----------

@test "notify: over the cap emits hookSpecificOutput.additionalContext and exits 0" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
h = json.loads(sys.argv[1])["hookSpecificOutput"]
assert h["hookEventName"] == "PostToolUse", h
ac = h["additionalContext"]
assert "300000" in ac, ac                      # 計測値
assert "150000" in ac, ac                      # DEV_WORKFLOW_CONTEXT_CAP の値
assert "DEV_WORKFLOW_CONTEXT_CAP" in ac, ac
assert "return" in ac, ac                      # 締めて return せよ
assert "工程完了:" in ac and "工程中断:" in ac, ac   # return の 1 行目の書き分け
assert "pr-review-gate" in ac, ac              # tasks.md が無い受け手のための一意化
assert len(ac.splitlines()) <= 6, ac           # 出力は数行に抑える
PY
}

@test "notify: the notification does not vary by role" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  p1="$(payload PostToolUse "$AGENT_ID" Read)"
  a="$(bash -c "'$SCRIPT' <<< '$p1'")"
  p2="$(echo "$p1" | python3 -c 'import json,sys; d=json.load(sys.stdin); d["agent_type"]="dev-workflow:decider"; print(json.dumps(d))')"
  b="$(bash -c "'$SCRIPT' <<< '$p2'")"
  [ "$a" = "$b" ]
}

@test "notify: PostToolUse never denies" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,900000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Write)'"
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q permissionDecision
}

# ---------- 2.7 PreToolUse の強制停止 ----------

@test "hard stop: Edit is denied above the hard cap" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PreToolUse "$AGENT_ID" Edit)'"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
h = json.loads(sys.argv[1])["hookSpecificOutput"]
assert h["hookEventName"] == "PreToolUse", h
assert h["permissionDecision"] == "deny", h
r = h["permissionDecisionReason"]
assert "300000" in r and "220000" in r, r
assert "DEV_WORKFLOW_CONTEXT_HARD_CAP" in r, r
assert "commit" in r and "return" in r, r
assert "工程中断:" in r, r
PY
}

@test "hard stop: Write and NotebookEdit are denied too" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  for tool in Write NotebookEdit; do
    run bash -c "'$SCRIPT' <<< '$(payload PreToolUse "$AGENT_ID" "$tool")'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"permissionDecision": *"deny"'
  done
}

@test "hard stop: read-only tools are never denied" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,900000" >/dev/null
  for tool in Read Grep Glob; do
    run bash -c "'$SCRIPT' <<< '$(payload PreToolUse "$AGENT_ID" "$tool")'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "hard stop: between cap and hard cap edits still pass" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,180000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PreToolUse "$AGENT_ID" Edit)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hard stop: an inverted pair of thresholds is fail-open" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,900000" >/dev/null
  run bash -c "DEV_WORKFLOW_CONTEXT_CAP=220000 DEV_WORKFLOW_CONTEXT_HARD_CAP=150000 '$SCRIPT' <<< '$(payload PreToolUse "$AGENT_ID" Edit)'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------- 2.8 Bash の許可判定 ----------

@test "bash allow: git -C <worktree> commit passes" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  for cmd in "git status" "git diff --stat" "git add -A" "git -C /path/to/wt commit -m x" "git -c user.name=a commit -m y" "git push -u origin br"; do
    run bash -c "'$SCRIPT' <<< '$(payload PreToolUse "$AGENT_ID" Bash "$cmd")'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "bash allow: a commit message with parentheses is not mistaken for a subshell" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  p="$(payload PreToolUse "$AGENT_ID" Bash 'git commit -m "fix(dev-workflow): a; b | c"')"
  run bash -c "'$SCRIPT' <<< '$p'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bash deny: command substitution is denied with a workaround in the reason" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  p="$(payload PreToolUse "$AGENT_ID" Bash 'git commit -m "$(printf x)"')"
  run bash -c "'$SCRIPT' <<< '$p'"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
h = json.loads(sys.argv[1])["hookSpecificOutput"]
assert h["permissionDecision"] == "deny", h
r = h["permissionDecisionReason"]
assert "-m" in r and "1 行ずつ" in r, r
PY
}

@test "bash deny: compound commands are denied" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  for cmd in "git status && rm -rf build" "git status | head" "git status; rm x" "npm test" "gh pr comment 1 --body x"; do
    run bash -c "'$SCRIPT' <<< '$(payload PreToolUse "$AGENT_ID" Bash "$cmd")'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"permissionDecision": *"deny"'
  done
}

@test "bash deny: a git subcommand outside the allowlist is denied" {
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  for cmd in "git reset --hard" "git clean -f" "git -C /wt checkout -- ."; do
    run bash -c "'$SCRIPT' <<< '$(payload PreToolUse "$AGENT_ID" Bash "$cmd")'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '"permissionDecision": *"deny"'
  done
}

# ---------- 2.9 実行コスト ----------

@test "cost: one hook run on a 5MB transcript stays under 100ms" {
  mkdir -p "$SUBAGENTS"
  f="${SUBAGENTS}/agent-${AGENT_ID}.jsonl"
  python3 - "$f" <<'PY'
import sys
line = '{"type":"assistant","message":{"usage":{"input_tokens":10,"cache_creation_input_tokens":0,"cache_read_input_tokens":10,"output_tokens":1,"pad":"%s"}}}\n' % ("x" * 900)
with open(sys.argv[1], "w") as fh:
    for _ in range(5200):
        fh.write(line)
    fh.write('{"type":"assistant","message":{"usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":300000,"output_tokens":1}}}\n')
PY
  [ "$(wc -c < "$f")" -gt 5000000 ]
  p="$(payload PostToolUse "$AGENT_ID" Read)"
  # 3 回のうち最良を採る。hook は毎ツール呼び出しで走るのでファイルは温まっている前提。
  best=99999
  for _ in 1 2 3; do
    t0="$(python3 -c 'import time;print(int(time.time()*1000))')"
    bash -c "'$SCRIPT' <<< '$p'" >/dev/null
    t1="$(python3 -c 'import time;print(int(time.time()*1000))')"
    d=$(( t1 - t0 ))
    if [ "$d" -lt "$best" ]; then best=$d; fi
  done
  echo "elapsed(best of 3) = ${best}ms"
  [ "$best" -lt 100 ]
}

# ---------- 3. hooks.json の登録 ----------

@test "hooks.json: PostToolUse runs context-tripwire.sh for every tool" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
entries = d["hooks"]["PostToolUse"]
hit = [e for e in entries if any("context-tripwire.sh" in h["command"] for h in e["hooks"])]
assert len(hit) == 1, entries
e = hit[0]
# 全ツール = matcher を書かないか空文字。特定ツールに絞られていないことを見る
assert e.get("matcher", "") in ("", "*"), e.get("matcher")
cmd = e["hooks"][0]["command"]
assert e["hooks"][0]["type"] == "command"
assert "${CLAUDE_PLUGIN_ROOT}" in cmd, cmd
PY
}

@test "hooks.json: PreToolUse matcher is limited to editing tools and Bash" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
entries = d["hooks"]["PreToolUse"]
hit = [e for e in entries if any("context-tripwire.sh" in h["command"] for h in e["hooks"])]
assert len(hit) == 1, entries
# matcher が編集系 + Bash に限られていることが「読み取り系（Read / Grep / Glob）を
# 拒否しない」を構造的に保証する。スクリプト側の判定を待たずに hook が呼ばれない。
assert hit[0]["matcher"] == "Edit|Write|NotebookEdit|Bash", hit[0].get("matcher")
assert "${CLAUDE_PLUGIN_ROOT}" in hit[0]["hooks"][0]["command"]
PY
}

@test "hooks.json: the pre-existing entries are untouched" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]
assert any("session-tripwires.sh" in h["command"]
           for e in d["SessionStart"] for h in e["hooks"]), d["SessionStart"]
assert any("prompt-tripwires-refresh.sh" in h["command"]
           for e in d["UserPromptSubmit"] for h in e["hooks"]), d["UserPromptSubmit"]
guard = [e for e in d["PreToolUse"] if any("agent-model-guard.sh" in h["command"] for h in e["hooks"])]
assert len(guard) == 1 and guard[0]["matcher"] == "Agent", d["PreToolUse"]
PY
}

# ---------- 4.1 worktree 隔離 ----------

@test "worktree isolation: a filename without the agent name is still measured" {
  # isolation: "worktree" のサブエージェントは agent-a<16 桁 hex>.jsonl に置かれ、
  # ファイル名に名前が入らない（#243 の直接原因）。hook は名前ではなく agent_id で引く。
  AGENT_ID="a1b2c3d4e5f60718"
  make_transcript "$SUBAGENTS" "agent-${AGENT_ID}.jsonl" "0,0,300000" >/dev/null
  run bash -c "'$SCRIPT' <<< '$(payload PostToolUse "$AGENT_ID" Read)'"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q additionalContext
  run bash -c "'$SCRIPT' <<< '$(payload PreToolUse "$AGENT_ID" Edit)'"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"permissionDecision": *"deny"'
}
