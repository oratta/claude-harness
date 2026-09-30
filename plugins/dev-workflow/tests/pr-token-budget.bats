#!/usr/bin/env bats
#
# pr-token-budget.sh: 記録先番号（#N）に紐付くサブエージェントの全リクエストの usage と、
# 記録先に残した Codex 消費を合計し、上限超なら exit 2 を返す（develop の本体が spawn /
# SendMessage / Codex 委譲の前に呼ぶ）。
#
# spec: openspec/changes/add-pr-token-budget（dev-workflow-pr-token-budget）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/pr-token-budget.sh"
  WORK="$(cd "$(mktemp -d)" && pwd -P)"
  PROJECTS="${WORK}/projects"
  REPO="${WORK}/repo"
  WT="${WORK}/wt"
  OTHER="${WORK}/other"
  GONE="${WORK}/gone"
  HOME1="${WORK}/codex1"
  HOME2="${WORK}/codex2"
  export CODEX_HOME="${WORK}/codex-default"
  unset DEV_WORKFLOW_PR_TOKEN_CAP

  git init -q "$REPO"
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$REPO" worktree add -q "$WT" -b side
  git init -q "$OTHER"
}

teardown() {
  rm -rf "$WORK"
}

# サブエージェント 1 体: $1=id $2=meta JSON（cwd 等を埋めたもの） $3=cwd（トランスクリプトの cwd）
# 以降の行は stdin からトランスクリプト本文として追記する
make_agent() {
  local id="$1" meta="$2" cwd="$3"
  local dir="${PROJECTS}/proj/sess1/subagents"
  mkdir -p "$dir"
  printf '%s\n' "$meta" > "${dir}/agent-${id}.meta.json"
  printf '{"type":"user","isSidechain":true,"cwd":"%s","message":{"role":"user","content":"hi"}}\n' "$cwd" > "${dir}/agent-${id}.jsonl"
  cat >> "${dir}/agent-${id}.jsonl"
}

# assistant 行: $1=requestId（空なら省略） $2=message.id（空なら省略） $3=uuid $4..$7=input,cache_create,cache_read,output
arec() {
  local rid="" mid=""
  [ -n "$1" ] && rid="\"requestId\":\"$1\","
  [ -n "$2" ] && mid="\"id\":\"$2\","
  printf '{"type":"assistant",%s"uuid":"%s","message":{%s"model":"claude-sonnet-5","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":%s}}}\n' \
    "$rid" "$3" "$mid" "$4" "$5" "$6" "$7"
}

# 固定入力。#288 に紐付くのは R1（346）・W（6664）・G（100）の 3 体で Claude 分 7110
fixture_agents() {
  # 名前なしの R1（346 = 116 + 230）
  { arec rA mA u1 1 10 100 5; arec rB mB u2 2 20 200 8; } |
    make_agent a1 '{"agentType":"dev-workflow:decider","description":"R1: spec review for #288","model":"fable"}' "$REPO"
  # worktree 隔離の W（6664 = 1100 + 5560 + 4）: 同じ requestId の重複行・壊れた行・usage が文字列の行・再開分
  {
    arec r1 m1 u3 1000 0 0 100
    arec r1 m1 u4 1000 0 0 100
    echo '{"type":"assistant","message":{"usage":'
    echo '{"type":"assistant","requestId":"rX","uuid":"u5","message":{"usage":"oops"}}'
    arec r2 m2 u6 10 500 5000 50
    arec "" m3 u7 1 1 1 1
  } | make_agent a2 "{\"agentType\":\"general-purpose\",\"worktreePath\":\"${WT}\",\"spawnedWithWorktree\":true,\"description\":\"W: spec phase for #288\",\"name\":\"W-288\",\"model\":\"opus\"}" "$WT"
  # 桁の多い番号（数えない）
  arec r3 m4 u8 999999 0 0 0 |
    make_agent a3 '{"description":"W: impl for #2880","name":"W-2880","model":"sonnet"}' "$REPO"
  # 別リポジトリの #288（数えない）
  arec r4 m5 u9 777777 0 0 0 |
    make_agent a4 '{"description":"W: impl for #288","name":"W-other","model":"sonnet"}' "$OTHER"
  # 作業ディレクトリが消えた #288（unresolved）
  arec r5 m6 u10 555 0 0 0 |
    make_agent a5 '{"description":"W: old for #288","model":"sonnet"}' "$GONE"
  # G（#400 と #288 の両方を含む。100）
  arec r6 m7 u11 50 0 0 50 |
    make_agent a6 '{"description":"G: gate for PR #400 (#288)","name":"G-288","model":"sonnet"}' "$REPO"
}

# rollout: $1=CODEX_HOME $2=thread_id、stdin の各行を total_tokens として token_count 行にする（"null" は info null）
make_rollout() {
  local dir="$1/sessions/2026/09/23"
  mkdir -p "$dir"
  local f="${dir}/rollout-2026-09-23T10-00-00-$2.jsonl"
  printf '{"type":"session_meta","payload":{"id":"%s","cwd":"/tmp"}}\n' "$2" > "$f"
  while read -r v; do
    if [ "$v" = "null" ]; then
      echo '{"type":"event_msg","payload":{"type":"token_count","info":null}}' >> "$f"
    else
      printf '{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":%s,"output_tokens":0,"total_tokens":%s}}}}\n' "$v" "$v" >> "$f"
    fi
  done
  echo '{"type":"response_item","payload":{"type":"message"}}' >> "$f"
}

# Codex 側の固定入力: tc1 1000（重複行あり）・tc3 は HOME1 の rollout で 250・tc5 は HOME2 にだけあり 300・
# tc9 はどこにも無い・書式違反 2 行。Codex 分 1550、codex_threads 3、codex_unresolved 1、skipped 2
fixture_codex() {
  RECORDS="${WORK}/records.txt"
  printf 'tc1 1000\ntc1 1000\ntc3 -\ntc5 -\ntc9 -\ntc4 abc\nlonely\n' > "$RECORDS"
  printf '100\n250\n250\nnull\n' | make_rollout "$HOME1" tc3
  printf '300\n' | make_rollout "$HOME2" tc5
}

# 出力 JSON に対してテスト内に固定で書いた式を評価する（式はこのファイルの定数だけで、外部入力は渡さない）
j() { python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(eval(sys.argv[2], {"d": d}))' "$output" "$1"; }

@test "script: is executable and exits 1 without a record number" {
  [ -x "$SCRIPT" ]
  cd "$REPO"
  run "$SCRIPT" --projects "$PROJECTS"
  [ "$status" -eq 1 ]
}

@test "fixed input: claude/codex/total tokens, counts, unresolved and skipped lines match hand-computed values" {
  fixture_agents; fixture_codex
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "$RECORDS" --codex-home "$HOME1" --codex-home "$HOME2"
  echo "$output"
  [ "$status" -eq 0 ]
  [ "$(j 'd["claude_tokens"]')" = 7110 ]
  [ "$(j 'd["codex_tokens"]')" = 1550 ]
  [ "$(j 'd["total_tokens"]')" = 8660 ]
  [ "$(j 'd["agent_count"]')" = 3 ]
  [ "$(j 'd["codex_threads"]')" = 3 ]
  [ "$(j 'd["unresolved"]')" = 1 ]
  [ "$(j 'd["codex_unresolved"]')" = 1 ]
  [ "$(j 'd["skipped_lines"]')" = 4 ]
  [ "$(j 'd["records"]')" = "[288]" ]
  [ "$(j 'd["cap"]')" = 30000000 ]
  [ "$(j 'd["over_cap"]')" = False ]
  [ "$(j 'sorted(a["tokens"] for a in d["agents"])')" = "[100, 346, 6664]" ]
  [ "$(j 'sorted((c["thread_id"], c["tokens"], c["source"]) for c in d["codex"])')" = "[('tc1', 1000, 'record'), ('tc3', 250, 'rollout'), ('tc5', 300, 'rollout')]" ]
}

@test "linking: unnamed R1 and worktree-isolated W are counted; W counts every request incl. resume, once per requestId" {
  fixture_agents
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS"
  [ "$status" -eq 0 ]
  [ "$(j '[a["tokens"] for a in d["agents"] if a["description"].startswith("R1")][0]')" = 346 ]
  [ "$(j '[(a["name"], a["tokens"], a["requests"]) for a in d["agents"] if a["description"].startswith("W:")][0]')" = "('W-288', 6664, 3)" ]
  [ "$(j 'd["skipped_lines"]')" = 2 ]
}

@test "linking: #2880 does not match #288" {
  arec r3 m4 u8 999999 0 0 0 |
    make_agent a3 '{"description":"W: impl for #2880","name":"W-2880","model":"sonnet"}' "$REPO"
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS"
  [ "$status" -eq 0 ]
  [ "$(j 'd["agent_count"]')" = 0 ]
  [ "$(j 'd["total_tokens"]')" = 0 ]
}

@test "linking: passing 288 and 400 counts the G matching both only once" {
  fixture_agents
  cd "$REPO"
  run "$SCRIPT" 288 400 --projects "$PROJECTS"
  [ "$status" -eq 0 ]
  [ "$(j 'd["agent_count"]')" = 3 ]
  [ "$(j 'd["claude_tokens"]')" = 7110 ]
  [ "$(j 'd["records"]')" = "[288, 400]" ]
}

@test "repo: another repository's #288 is excluded, missing workdir goes to unresolved" {
  fixture_agents
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS"
  [ "$(j '[a for a in d["agents"] if a["name"] == "W-other"]')" = "[]" ]
  [ "$(j 'd["unresolved"]')" = 1 ]
}

@test "repo: running from the side worktree counts the same agents" {
  fixture_agents
  cd "$WT"
  run "$SCRIPT" 288 --projects "$PROJECTS"
  [ "$status" -eq 0 ]
  [ "$(j 'd["claude_tokens"]')" = 7110 ]
}

@test "cap: over the --cap exits 2 with over_cap true" {
  fixture_agents
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --cap 7000
  [ "$status" -eq 2 ]
  [ "$(j 'd["over_cap"]')" = True ]
}

@test "cap: codex tokens push the total over the cap (exit 2)" {
  fixture_agents; fixture_codex
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --cap 8000 --codex-records "$RECORDS" --codex-home "$HOME1" --codex-home "$HOME2"
  [ "$status" -eq 2 ]
  [ "$(j 'd["claude_tokens"] <= d["cap"] < d["total_tokens"]')" = True ]
}

@test "cap: no agents and no codex records exits 0 with zeros" {
  cd "$REPO"
  run "$SCRIPT" 999 --projects "$PROJECTS"
  [ "$status" -eq 0 ]
  [ "$(j '(d["total_tokens"], d["agent_count"], d["codex_threads"])')" = "(0, 0, 0)" ]
}

@test "cap: DEV_WORKFLOW_PR_TOKEN_CAP is used, and --cap overrides it" {
  fixture_agents
  cd "$REPO"
  DEV_WORKFLOW_PR_TOKEN_CAP=7000 run "$SCRIPT" 288 --projects "$PROJECTS"
  [ "$status" -eq 2 ]
  [ "$(j 'd["cap"]')" = 7000 ]
  DEV_WORKFLOW_PR_TOKEN_CAP=7000 run "$SCRIPT" 288 --projects "$PROJECTS" --cap 9000
  [ "$status" -eq 0 ]
  [ "$(j 'd["cap"]')" = 9000 ]
}

@test "cap: a non-numeric --cap or env cap exits 1" {
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --cap abc
  [ "$status" -eq 1 ]
  DEV_WORKFLOW_PR_TOKEN_CAP=x run "$SCRIPT" 288 --projects "$PROJECTS"
  [ "$status" -eq 1 ]
}

@test "errors: outside a git repository exits 1" {
  mkdir -p "${WORK}/plain"
  cd "${WORK}/plain"
  run "$SCRIPT" 288 --projects "$PROJECTS"
  [ "$status" -eq 1 ]
}

@test "codex: recorded tokens are summed" {
  printf 't1 1000\nt2 500\n' > "${WORK}/r.txt"
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "${WORK}/r.txt" --codex-home "$HOME1"
  [ "$status" -eq 0 ]
  [ "$(j '(d["codex_tokens"], d["codex_threads"], d["total_tokens"])')" = "(1500, 2, 1500)" ]
}

@test "codex: the same thread is counted once (max of recorded values)" {
  printf 't1 1000\nt1 1000\nt1 900\n' > "${WORK}/r.txt"
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "${WORK}/r.txt" --codex-home "$HOME1"
  [ "$(j '(d["codex_tokens"], d["codex_threads"])')" = "(1000, 1)" ]
}

@test "codex: '-' reads the max cumulative total from the rollout, ignoring repeats and null info" {
  printf 't3 -\n' > "${WORK}/r.txt"
  printf '100\n250\n250\nnull\n' | make_rollout "$HOME1" t3
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "${WORK}/r.txt" --codex-home "$HOME1"
  [ "$(j '(d["codex_tokens"], d["codex"][0]["source"])')" = "(250, 'rollout')" ]
}

@test "codex: the rollout is also searched in the second --codex-home" {
  printf 't5 -\n' > "${WORK}/r.txt"
  printf '300\n' | make_rollout "$HOME2" t5
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "${WORK}/r.txt" --codex-home "$HOME1" --codex-home "$HOME2"
  [ "$(j 'd["codex_tokens"]')" = 300 ]
}

@test "codex: without --codex-home, \${CODEX_HOME} is searched" {
  printf 't6 -\n' > "${WORK}/r.txt"
  printf '42\n' | make_rollout "$CODEX_HOME" t6
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "${WORK}/r.txt"
  [ "$(j 'd["codex_tokens"]')" = 42 ]
}

@test "codex: a '-' thread with no rollout anywhere goes to codex_unresolved, exit decided by total vs cap" {
  printf 't9 -\n' > "${WORK}/r.txt"
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "${WORK}/r.txt" --codex-home "$HOME1" --cap 0
  [ "$status" -eq 0 ]
  [ "$(j '(d["codex_tokens"], d["codex_threads"], d["codex_unresolved"])')" = "(0, 0, 1)" ]
}

@test "codex: an empty records file means codex_threads 0 and no error" {
  : > "${WORK}/r.txt"
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "${WORK}/r.txt"
  [ "$status" -eq 0 ]
  [ "$(j '(d["codex_tokens"], d["codex_threads"], d["skipped_lines"])')" = "(0, 0, 0)" ]
}

@test "codex: malformed record lines are skipped and counted in skipped_lines" {
  printf 't4 abc\nlonely\nt1 10\n' > "${WORK}/r.txt"
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "${WORK}/r.txt"
  [ "$status" -eq 0 ]
  [ "$(j '(d["codex_tokens"], d["skipped_lines"])')" = "(10, 2)" ]
}

@test "codex: a missing --codex-records file exits 1" {
  cd "$REPO"
  run "$SCRIPT" 288 --projects "$PROJECTS" --codex-records "${WORK}/nope.txt"
  [ "$status" -eq 1 ]
}
