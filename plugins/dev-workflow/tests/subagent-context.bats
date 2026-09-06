#!/usr/bin/env bats
#
# subagent-context.sh: 名前付きサブエージェントのコンテキスト量を最後の usage から測り、
# 上限超なら exit 2 を返す（develop の本体が SendMessage 再開の前に呼ぶ）。
#
# spec: dev-workflow decision-criteria「コンテキスト上限（サブエージェントの手渡し）」

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/subagent-context.sh"
  WORK="$(mktemp -d)"
  PROJECTS="${WORK}/projects"
}

teardown() {
  rm -rf "$WORK"
}

# トランスクリプトを 1 本作る: $1=project slug $2=session $3=agent file name $4=cwd $5..=各 assistant の (input,cache_create,cache_read)
make_transcript() {
  local slug="$1" sess="$2" fname="$3" cwd="$4"; shift 4
  local dir="${PROJECTS}/${slug}/${sess}/subagents"
  mkdir -p "$dir"
  local f="${dir}/${fname}"
  printf '{"type":"user","isSidechain":true,"cwd":"%s","message":{"role":"user","content":"hi"}}\n' "$cwd" > "$f"
  for triple in "$@"; do
    IFS=, read -r i c r <<<"$triple"
    printf '{"type":"assistant","message":{"model":"claude-sonnet-5","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":10}}}\n' "$i" "$c" "$r" >> "$f"
  done
  echo "$f"
}

@test "script: is executable and prints usage without args" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'usage'
}

@test "measure: sums input + cache_creation + cache_read of the LAST assistant record" {
  make_transcript p1 s1 agent-aW-42-abcd.jsonl /tmp/x "1000,2000,3000" "500,0,120000" >/dev/null
  run "$SCRIPT" W-42 --projects "$PROJECTS" --cap 150000
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["context_tokens"] == 120500, d
assert d["calls"] == 2, d
assert d["over_cap"] is False, d
assert d["cap"] == 150000, d
PY
}

@test "cap: exit 2 with over_cap=true when the last context exceeds the cap" {
  make_transcript p1 s1 agent-aW-42-abcd.jsonl /tmp/x "1000,0,160000" >/dev/null
  run "$SCRIPT" W-42 --projects "$PROJECTS" --cap 150000
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"over_cap": true'
}

@test "cap: DEV_WORKFLOW_CONTEXT_CAP env sets the default cap" {
  make_transcript p1 s1 agent-aW-42-abcd.jsonl /tmp/x "1000,0,20000" >/dev/null
  run env DEV_WORKFLOW_CONTEXT_CAP=10000 "$SCRIPT" W-42 --projects "$PROJECTS"
  [ "$status" -eq 2 ]
  run env DEV_WORKFLOW_CONTEXT_CAP=50000 "$SCRIPT" W-42 --projects "$PROJECTS"
  [ "$status" -eq 0 ]
}

@test "lookup: prefers the transcript whose cwd matches the current directory over a newer one" {
  local here
  here="$(mktemp -d)"
  make_transcript p1 s1 agent-aW-7-1111.jsonl "$here" "0,0,300000" >/dev/null
  sleep 1
  make_transcript p2 s2 agent-aW-7-2222.jsonl /elsewhere "0,0,1000" >/dev/null
  cd "$here"
  run "$SCRIPT" W-7 --projects "$PROJECTS"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"context_tokens": 300000'
  rm -rf "$here"
}

@test "lookup: exit 1 with an error field when no transcript matches" {
  mkdir -p "$PROJECTS"
  run "$SCRIPT" nobody --projects "$PROJECTS"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'transcript not found'
}

@test "lookup: exit 1 when the transcript has no assistant usage yet" {
  make_transcript p1 s1 agent-aW-9-abcd.jsonl /tmp/x >/dev/null
  run "$SCRIPT" W-9 --projects "$PROJECTS"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'no assistant usage'
}
