#!/usr/bin/env bats
#
# subagent-context.sh: 名前付きサブエージェントのコンテキスト量を最後の usage から測り、
# 上限超なら exit 2 を返す（develop の本体が SendMessage 再開の前に呼ぶ）。
#
# spec: dev-workflow decision-criteria「コンテキスト上限（サブエージェントの手渡し）」

setup() {
  bats_require_minimum_version 1.5.0
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/subagent-context.sh"
  WORK="$(mktemp -d)"
  PROJECTS="${WORK}/projects"
  unset DEV_WORKFLOW_CONTEXT_CAP DEV_WORKFLOW_CONTEXT_HARD_CAP DEV_WORKFLOW_PR_TOKEN_CAP
  unset AGENT_MODEL ANTHROPIC_MODEL
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
    printf '{"type":"assistant","message":{"model":"claude-sonnet-5-5","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":10}}}\n' "$i" "$c" "$r" >> "$f"
  done
  echo "$f"
}

set_mtime() {
  python3 -c 'import os,sys; t=int(sys.argv[2]); os.utime(sys.argv[1], (t,t))' "$1" "$2"
}

assert_transcript() {
  [ "$status" -eq 0 ]
  python3 - "$output" "$1" "$2" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["file"] == sys.argv[2], d
assert d["context_tokens"] == int(sys.argv[3]), d
PY
}

@test "metadata: finds an opaque filename by exact name" {
  local f
  f="$(make_transcript p1 s1 agent-a123.jsonl "$PWD" "1,2,3")"
  printf '{"name":"W-590"}' > "${f%.jsonl}.meta.json"
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  assert_transcript "$f" 6
}

@test "metadata: name matching rejects prefixes and suffixes" {
  local f name
  f="$(make_transcript p1 s1 agent-a123.jsonl "$PWD" "1,2,3")"
  for name in W-590-extra prefix-W-590; do
    printf '{"name":"%s"}' "$name" > "${f%.jsonl}.meta.json"
    run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
    [ "$status" -eq 1 ]
    [ "$(printf '%s' "$output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["error"])')" = "transcript not found" ]
  done
}

@test "lookup: both legacy filename forms work without metadata" {
  local f sess=0 fname
  for fname in agent-aW-590-abcd.jsonl agent-aW-590.jsonl; do
    sess=$((sess + 1))
    f="$(make_transcript p1 "s$sess" "$fname" "$PWD" "1,2,3")"
    set_mtime "$f" "$((1000 + sess))"
    run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
    assert_transcript "$f" 6
  done
}

@test "metadata: multiple sessions prefer matching cwd over newer logs" {
  local matching newer
  matching="$(make_transcript p1 s1 agent-a123.jsonl "$PWD" "0,0,111")"
  newer="$(make_transcript p2 s2 agent-b456.jsonl /elsewhere "0,0,222")"
  printf '{"name":"W-590"}' > "${matching%.jsonl}.meta.json"
  printf '{"name":"W-590"}' > "${newer%.jsonl}.meta.json"
  set_mtime "$matching" 1000
  set_mtime "$newer" 2000
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  assert_transcript "$matching" 111
}

@test "metadata: same cwd selects latest transcript rather than latest metadata" {
  local older newer
  older="$(make_transcript p1 s1 agent-a123.jsonl "$PWD" "0,0,111")"
  newer="$(make_transcript p1 s2 agent-b456.jsonl "$PWD" "0,0,222")"
  printf '{"name":"W-590"}' > "${older%.jsonl}.meta.json"
  printf '{"name":"W-590"}' > "${newer%.jsonl}.meta.json"
  set_mtime "$older" 1000
  set_mtime "$newer" 2000
  set_mtime "${older%.jsonl}.meta.json" 4000
  set_mtime "${newer%.jsonl}.meta.json" 3000
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  assert_transcript "$newer" 222
}

@test "metadata: no matching cwd selects latest transcript across sessions" {
  local older newer
  older="$(make_transcript p1 s1 agent-a123.jsonl /elsewhere "0,0,111")"
  newer="$(make_transcript p2 s2 agent-b456.jsonl /other "0,0,222")"
  printf '{"name":"W-590"}' > "${older%.jsonl}.meta.json"
  printf '{"name":"W-590"}' > "${newer%.jsonl}.meta.json"
  set_mtime "$older" 1000
  set_mtime "$newer" 2000
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  assert_transcript "$newer" 222
}

@test "metadata: merges legacy and metadata candidates before applying cwd and mtime priority" {
  local legacy meta
  legacy="$(make_transcript p1 s1 agent-aW-590-abcd.jsonl "$PWD" "0,0,111")"
  meta="$(make_transcript p2 s2 agent-b456.jsonl /elsewhere "0,0,222")"
  printf '{"name":"W-590"}' > "${meta%.jsonl}.meta.json"
  set_mtime "$legacy" 1000
  set_mtime "$meta" 2000
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  assert_transcript "$legacy" 111

  # 両方 cwd が一致した場合は探索元にかかわらずログの mtime で選ぶ。
  make_transcript p2 s2 agent-b456.jsonl "$PWD" "0,0,222" >/dev/null
  set_mtime "$meta" 2000
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  assert_transcript "$meta" 222
  set_mtime "$legacy" 3000
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  assert_transcript "$legacy" 111
}

# 各ケースで filename fallback・候補ゼロ・別の正常な metadata の探索を確認する。
check_metadata_fallback() {
  local kind="$1" legacy opaque meta good
  legacy="$(make_transcript p1 s1 agent-aW-590-abcd.jsonl "$PWD" "0,0,111")"
  opaque="${legacy%/*}/agent-b456.jsonl"
  meta="${legacy%.jsonl}.meta.json"
  case "$kind" in
    absent) ;;
    mismatch) printf '{"name":"someone-else"}' > "$meta" ;;
    broken) printf '{not json' > "$meta" ;;
    non-object) printf '["W-590"]' > "$meta" ;;
    no-name) printf '{}' > "$meta" ;;
    no-log) printf '{"name":"W-590"}' > "${legacy%/*}/agent-missing.meta.json" ;;
  esac
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  assert_transcript "$legacy" 111

  mv "$legacy" "$opaque"
  if [ -f "$meta" ]; then mv "$meta" "${opaque%.jsonl}.meta.json"; fi
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  [ "$status" -eq 1 ]
  [ "$(printf '%s' "$output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["error"])')" = "transcript not found" ]

  good="$(make_transcript p2 s2 agent-c789.jsonl "$PWD" "0,0,333")"
  printf '{"name":"W-590"}' > "${good%.jsonl}.meta.json"
  run --separate-stderr "$SCRIPT" W-590 --projects "$PROJECTS"
  assert_transcript "$good" 333
}

@test "metadata fallback: absent metadata" {
  check_metadata_fallback absent
}

@test "metadata fallback: mismatching name" {
  check_metadata_fallback mismatch
}

@test "metadata fallback: broken JSON" {
  check_metadata_fallback broken
}

@test "metadata fallback: non-object JSON" {
  check_metadata_fallback non-object
}

@test "metadata fallback: missing name" {
  check_metadata_fallback no-name
}

@test "metadata fallback: missing corresponding log" {
  check_metadata_fallback no-log
}

@test "script: is executable and prints usage without args" {
  [ -x "$SCRIPT" ]
  run --separate-stderr "$SCRIPT"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  echo "$stderr" | grep -q 'usage'
}

@test "measure: sums input + cache_creation + cache_read of the LAST assistant record" {
  make_transcript p1 s1 agent-aW-42-abcd.jsonl /tmp/x "1000,2000,3000" "500,0,120000" >/dev/null
  run --separate-stderr "$SCRIPT" W-42 --projects "$PROJECTS" --cap 150000
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
  run --separate-stderr "$SCRIPT" W-42 --projects "$PROJECTS" --cap 150000
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"over_cap": true'
}

@test "cap: DEV_WORKFLOW_CONTEXT_CAP env sets the default cap" {
  make_transcript p1 s1 agent-aW-42-abcd.jsonl /tmp/x "1000,0,20000" >/dev/null
  run --separate-stderr env DEV_WORKFLOW_CONTEXT_CAP=10000 "$SCRIPT" W-42 --projects "$PROJECTS"
  [ "$status" -eq 2 ]
  run --separate-stderr env DEV_WORKFLOW_CONTEXT_CAP=50000 "$SCRIPT" W-42 --projects "$PROJECTS"
  [ "$status" -eq 0 ]
}

@test "lookup: prefers the transcript whose cwd matches the current directory over a newer one" {
  local here
  here="$(mktemp -d)"
  make_transcript p1 s1 agent-aW-7-1111.jsonl "$here" "0,0,300000" >/dev/null
  sleep 1
  make_transcript p2 s2 agent-aW-7-2222.jsonl /elsewhere "0,0,1000" >/dev/null
  cd "$here"
  run --separate-stderr "$SCRIPT" W-7 --projects "$PROJECTS"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"context_tokens": 300000'
  rm -rf "$here"
}

@test "lookup: exit 1 with an error field when no transcript matches" {
  mkdir -p "$PROJECTS"
  run --separate-stderr "$SCRIPT" nobody --projects "$PROJECTS"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'transcript not found'
}

@test "lookup: exit 1 when the transcript has no assistant usage yet" {
  make_transcript p1 s1 agent-aW-9-abcd.jsonl /tmp/x >/dev/null
  run --separate-stderr "$SCRIPT" W-9 --projects "$PROJECTS"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'no assistant usage'
}

@test "measure: a malformed or non-object line does not abort the scan (later usage still read)" {
  f="$(make_transcript p1 s1 agent-aW-3-abcd.jsonl /tmp/x "0,0,5")"
  printf 'null\n{not json\n{"type":"assistant","message":{"usage":{"input_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":10}}}\n' >> "$f"
  run --separate-stderr "$SCRIPT" W-3 --projects "$PROJECTS"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"context_tokens": 12'
}

@test "args: --cap without a value returns a one-line JSON error instead of a bare set -u failure" {
  run --separate-stderr "$SCRIPT" W-3 --cap
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '"error"'
}

# --file: worktree 隔離のサブエージェントはファイル名に名前が入らず名前 glob では見つからない（#243）。
# 途中計測 hook が導出したパスをそのまま測れるように、直接指定の経路を持つ。

@test "--file: measures the given transcript without the name glob" {
  f="$(make_transcript p1 s1 agent-a1b2c3d4e5f60718.jsonl /tmp/x "1000,2000,3000" "500,0,120000")"
  run --separate-stderr "$SCRIPT" --file "$f" --cap 150000
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["context_tokens"] == 120500, d
assert d["over_cap"] is False, d
# agent はファイル名から導く（agent- と .jsonl を落とす）
assert d["agent"] == "a1b2c3d4e5f60718", d
PY
}

@test "--file: exit 2 when the given transcript is over the cap" {
  f="$(make_transcript p1 s1 agent-a1b2c3d4e5f60718.jsonl /tmp/x "0,0,200000")"
  run --separate-stderr "$SCRIPT" --file "$f" --cap 150000
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"over_cap": true'
}

@test "--file: exit 1 when the given path is not readable" {
  run --separate-stderr "$SCRIPT" --file "${WORK}/does-not-exist.jsonl"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '"error"'
}

@test "--file: without a value returns a one-line JSON error" {
  run --separate-stderr "$SCRIPT" --file
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '"error"'
}

@test "--file: the name lookup path is unchanged by the addition" {
  # 名前指定の既存挙動（cwd 優先・出力フィールド・exit code）が --file 追加の前後で変わらない
  make_transcript p1 s1 agent-aW-9-abcd.jsonl /tmp/x "0,0,10" >/dev/null
  run --separate-stderr "$SCRIPT" W-9 --projects "$PROJECTS" --cap 150000
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert sorted(d) == ["agent", "calls", "cap", "context_tokens", "file", "over_cap"], sorted(d)
assert d["agent"] == "W-9", d
PY
}

@test "--help: the last line of the header is not the shebang-adjacent set line" {
  run --separate-stderr "$SCRIPT" --help
  [ "$status" -eq 0 ]
  ! echo "$output" | grep -q 'set -uo pipefail' || return 1
  echo "$output" | grep -q -- '--file'
}

# --stop-since: 停止確認が返らないときの終端（#266）。経過時間と無更新時間の 2 条件がそろったときだけ exit 3
@test "stop-since: terminal (exit 3) only when both elapsed-since-stop and transcript-idle reach thresholds" {
  f="$(make_transcript p s agent-aW-1.jsonl "$PWD" 1,1,1)"
  now="$(date +%s)"
  python3 -c 'import os,sys; t=int(sys.argv[2]); os.utime(sys.argv[1],(t,t))' "$f" $((now-1000))
  # 両方超過
  DEV_WORKFLOW_STOP_CONFIRM_TIMEOUT=100 DEV_WORKFLOW_STOP_CONFIRM_STALL=100 run --separate-stderr "$SCRIPT" --file "$f" --stop-since $((now-500))
  [ "$status" -eq 3 ]
  echo "$output" | grep -q '"unconfirmed_terminal": true'
  # 経過時間だけ超過（停止指示が直近）
  DEV_WORKFLOW_STOP_CONFIRM_TIMEOUT=100 DEV_WORKFLOW_STOP_CONFIRM_STALL=100 run --separate-stderr "$SCRIPT" --file "$f" --stop-since $((now-5))
  [ "$status" -eq 0 ]
  # 無更新だけ不足（トランスクリプトが今更新された）
  touch "$f"
  DEV_WORKFLOW_STOP_CONFIRM_TIMEOUT=100 DEV_WORKFLOW_STOP_CONFIRM_STALL=100 run --separate-stderr "$SCRIPT" --file "$f" --stop-since $((now-500))
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"unconfirmed_terminal": false'
}

@test "stop-since: non-numeric env threshold is rejected" {
  f="$(make_transcript p s agent-aW-1.jsonl "$PWD" 1,1,1)"
  DEV_WORKFLOW_STOP_CONFIRM_TIMEOUT=abc run --separate-stderr "$SCRIPT" --file "$f" --stop-since 1
  [ "$status" -eq 1 ]
}

# 末尾に利用上限エラーのレコード（usage 全部 0・isApiErrorMessage）を $2 行足す
add_error_records() {
  local f="$1" k="$2" i
  for i in $(seq "$k"); do
    printf '{"type":"assistant","isApiErrorMessage":true,"message":{"model":"<synthetic>","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}\n' >> "$f"
  done
}

@test "api error: trailing zero-usage error record is skipped, over cap reported (exit 2)" {
  f="$(make_transcript p s agent-aW-1.jsonl "$PWD" 10,0,159990)"
  add_error_records "$f" 1
  run --separate-stderr "$SCRIPT" --file "$f"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"context_tokens": 160000'
  echo "$output" | grep -q '"over_cap": true'
  echo "$output" | grep -q '"last_record": "api_error"'
}

@test "api error: under cap stays exit 0 with the previous usage" {
  f="$(make_transcript p s agent-aW-1.jsonl "$PWD" 10,0,99990)"
  add_error_records "$f" 1
  run --separate-stderr "$SCRIPT" --file "$f"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"context_tokens": 100000'
  echo "$output" | grep -q '"over_cap": false'
}

@test "api error: three trailing error records still use the last normal usage" {
  f="$(make_transcript p s agent-aW-1.jsonl "$PWD" 10,0,159990)"
  add_error_records "$f" 3
  run --separate-stderr "$SCRIPT" --file "$f"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"context_tokens": 160000'
}

@test "api error: only error records means no usage (exit 1)" {
  f="$(make_transcript p s agent-aW-1.jsonl "$PWD")"
  add_error_records "$f" 2
  run --separate-stderr "$SCRIPT" --file "$f"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q 'no assistant usage yet'
}

@test "api error: error key with a falsy value and non-zero usage is still skipped" {
  f="$(make_transcript p s agent-aW-1.jsonl "$PWD" 10,0,159990)"
  printf '{"type":"assistant","error":{},"message":{"usage":{"input_tokens":10,"cache_creation_input_tokens":0,"cache_read_input_tokens":99990,"output_tokens":5}}}\n' >> "$f"
  printf '{"type":"assistant","error":"","message":{"usage":{"input_tokens":10,"cache_creation_input_tokens":0,"cache_read_input_tokens":99990,"output_tokens":5}}}\n' >> "$f"
  run --separate-stderr "$SCRIPT" --file "$f"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"context_tokens": 160000'
  echo "$output" | grep -q '"last_record": "api_error"'
}

@test "api error: error record without usage still sets last_record" {
  f="$(make_transcript p s agent-aW-1.jsonl "$PWD" 10,0,159990)"
  printf '{"type":"assistant","isApiErrorMessage":true,"message":{"model":"<synthetic>"}}\n' >> "$f"
  run --separate-stderr "$SCRIPT" --file "$f"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"context_tokens": 160000'
  echo "$output" | grep -q '"last_record": "api_error"'
}

# 探索先の決まり方（#1231）。実行者の環境に左右されないよう、HOME を一時ディレクトリにして環境変数を外して起動する
@test "search root: without CLAUDE_PROJECTS_DIR the transcript under CLAUDE_CONFIG_DIR is found" {
  PROJECTS="${WORK}/cfg/projects"
  f="$(make_transcript p s agent-a1.jsonl "$PWD" 1000,0,0)"
  printf '{"name":"W-590"}\n' > "${f%.jsonl}.meta.json"
  mkdir -p "${WORK}/home"
  run --separate-stderr env -u CLAUDE_PROJECTS_DIR HOME="${WORK}/home" CLAUDE_CONFIG_DIR="${WORK}/cfg" "$SCRIPT" W-590
  echo "$output"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\"file\": \"$f\""
  echo "$output" | grep -q '"context_tokens": 1000'
}

@test "search root: CLAUDE_PROJECTS_DIR wins over CLAUDE_CONFIG_DIR" {
  PROJECTS="${WORK}/cfg/projects"
  other="$(make_transcript p s agent-W-590.jsonl "$PWD" 1000,0,0)"
  PROJECTS="${WORK}/explicit"
  f="$(make_transcript p s agent-W-590.jsonl "$PWD" 2000,0,0)"
  mkdir -p "${WORK}/home"
  run --separate-stderr env HOME="${WORK}/home" CLAUDE_CONFIG_DIR="${WORK}/cfg" CLAUDE_PROJECTS_DIR="$PROJECTS" "$SCRIPT" W-590
  echo "$output"
  [ "$status" -eq 0 ]
  [ -f "$other" ]
  echo "$output" | grep -q "\"file\": \"$f\""
  echo "$output" | grep -q '"context_tokens": 2000'
}

@test "search root: with neither variable set, \$HOME/.claude/projects is searched" {
  PROJECTS="${WORK}/home/.claude/projects"
  f="$(make_transcript p s agent-W-590.jsonl "$PWD" 3000,0,0)"
  run --separate-stderr env -u CLAUDE_PROJECTS_DIR -u CLAUDE_CONFIG_DIR HOME="${WORK}/home" "$SCRIPT" W-590
  echo "$output"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\"file\": \"$f\""
  echo "$output" | grep -q '"context_tokens": 3000'
}

@test "search root: an empty CLAUDE_CONFIG_DIR falls back to \$HOME/.claude/projects" {
  PROJECTS="${WORK}/home/.claude/projects"
  f="$(make_transcript p s agent-W-590.jsonl "$PWD" 4000,0,0)"
  run --separate-stderr env -u CLAUDE_PROJECTS_DIR HOME="${WORK}/home" CLAUDE_CONFIG_DIR= "$SCRIPT" W-590
  echo "$output"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\"file\": \"$f\""
  echo "$output" | grep -q '"context_tokens": 4000'
}

# 配布先を模したコピー。元の表・共通処理・手順は編集しない。
threshold_plugin() {
  local dest="$WORK/cache-installed"
  mkdir -p "$dest/scripts" "$dest/references" "$dest/skills/develop/references"
  cp "$PLUGIN_DIR/scripts/"{subagent-context.sh,context-tripwire.sh,token_thresholds.py} "$dest/scripts/"
  cp "$PLUGIN_DIR/references/token-thresholds.json" "$dest/references/"
  cp "$PLUGIN_DIR/skills/develop/references/token-thresholds.md" "$dest/skills/develop/references/"
  SCRIPT="$dest/scripts/$(basename "$SCRIPT")"
  TABLE="$dest/references/token-thresholds.json"
  GUIDE="$dest/skills/develop/references/token-thresholds.md"
  python3 - "$TABLE" <<'PYFIX'
import json, sys
from pathlib import Path
p = Path(sys.argv[1]); d = json.loads(p.read_text())
for row, cap, hard in [(d['models']['claude-opus-5-5'], 100, 200),
                       (d['models']['claude-sonnet-5-5'], 300, 400),
                       (d['fallback'], 500, 600)]:
    row['context_cap']['value'] = cap
    row['context_hard_cap']['value'] = hard
p.write_text(json.dumps(d))
PYFIX
  cd "$WORK"
}

# $2 は JSON のモデル値。missing は model フィールドなし。$4=append なら追記。
threshold_record() {
  mkdir -p "$(dirname "$1")"
  python3 - "$@" <<'PYFIX'
import json, sys
p, model, ctx = sys.argv[1:4]
m = {'usage': {'input_tokens': int(ctx), 'output_tokens': 1}}
if model != 'missing':
    m['model'] = json.loads(model)
with open(p, 'a' if len(sys.argv) > 4 else 'w') as f:
    f.write(json.dumps({'type': 'assistant', 'message': m}) + '\n')
PYFIX
}

assert_context_diagnostics() {
  [[ "$stderr" == *unknown_model* ]] || return 1
  [[ "$stderr" == *revalidation_required* ]] || return 1
  [[ "$stderr" == *context_cap* ]] || return 1
  [[ "$stderr" == *"$GUIDE"* ]] || return 1
  [[ "$stderr" != *pr_token_cap* ]] || return 1
  [[ "$stderr" != *epic_child_token_cap* ]] || return 1
  [ -f "$GUIDE" ]
  [ -z "$(find "$WORK/cache-installed" -name '*.pyc' -o -name __pycache__)" ]
}

@test "thresholds: bundled model row, last usage, and trailing API errors stay paired" {
  threshold_plugin
  local f="$WORK/agent-test.jsonl" model
  threshold_record "$f" '"claude-sonnet-5-5"' 350
  threshold_record "$f" '"claude-opus-5-5"' 101 append
  printf '%s\n' '{"type":"assistant","isApiErrorMessage":true,"message":{"model":"claude-sonnet-5-5","usage":{"input_tokens":0}}}' >> "$f"
  run --separate-stderr "$SCRIPT" --file "$f"
  [ "$status" -eq 2 ]
  [ -z "$stderr" ]
  python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["cap"] == 100 and d["context_tokens"] == 101 and d["last_record"] == "api_error"' "$output"
  for model in claude-opus-5-5 claude-sonnet-5-5; do
    threshold_record "$f" "\"$model\"" 100
    run --separate-stderr "$SCRIPT" --file "$f"
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    local expected=100
    [ "$model" = claude-opus-5-5 ] || expected=300
    python3 -c 'import json,sys; assert json.loads(sys.argv[1])["cap"] == int(sys.argv[2])' "$output" "$expected"
  done
  mkdir -p "$PROJECTS/p/s/subagents"
  cp "$f" "$PROJECTS/p/s/subagents/agent-hash.jsonl"
  printf '{"name":"named"}' > "$PROJECTS/p/s/subagents/agent-hash.meta.json"
  run --separate-stderr "$SCRIPT" named --projects "$PROJECTS"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"cap": 300'* ]] || return 1
}

@test "thresholds: missing and unknown models use fallback without borrowing other sources" {
  threshold_plugin
  local f="$WORK/agent-test.jsonl" model
  export AGENT_MODEL=claude-opus-5-5 ANTHROPIC_MODEL=claude-opus-5-5
  for model in missing null 42 '[]' '""' '"   "' '"new-model"' '"opus"' '"sonnet"' '" claude-opus-5-5 "'; do
    threshold_record "$f" '"claude-opus-5-5"' 90
    threshold_record "$f" "$model" 499 append
    run --separate-stderr "$SCRIPT" --file "$f"
    [ "$status" -eq 0 ]
    python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["cap"] == 500 and d["context_tokens"] == 499' "$output"
    assert_context_diagnostics
    [[ "$stderr" != *context_hard_cap* ]] || return 1
  done
}

@test "thresholds: CLI override precedence, whitespace, zero and exact boundaries" {
  threshold_plugin
  local f="$WORK/agent-test.jsonl" value
  threshold_record "$f" '"claude-opus-5-5"' 100
  export DEV_WORKFLOW_CONTEXT_HARD_CAP=bad DEV_WORKFLOW_PR_TOKEN_CAP=bad
  for value in '' '  ' 100 ' 100 '; do
    export DEV_WORKFLOW_CONTEXT_CAP="$value"
    run --separate-stderr "$SCRIPT" --file "$f"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"cap": 100'* ]] || return 1
    [ -z "$stderr" ]
  done
  for value in 200 abc; do
    export DEV_WORKFLOW_CONTEXT_CAP="$value"
    run --separate-stderr "$SCRIPT" --file "$f" --cap 99
    [ "$status" -eq 2 ]
    [[ "$output" == *'"cap": 99'* ]] || return 1
  done
  export DEV_WORKFLOW_CONTEXT_CAP=0
  run --separate-stderr "$SCRIPT" --file "$f"
  [ "$status" -eq 2 ]
  [[ "$output" == *'"cap": 0'* ]] || return 1
  run --separate-stderr "$SCRIPT" --file "$f" --cap 0
  [ "$status" -eq 2 ]
  for value in ' 100 ' abc -1 1.5 １２; do
    run --separate-stderr "$SCRIPT" --file "$f" --cap "$value"
    [ "$status" -eq 1 ]
  done
  for value in abc -1 1.5 １２; do
    export DEV_WORKFLOW_CONTEXT_CAP="$value"
    run --separate-stderr "$SCRIPT" --file "$f"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *subagent-context*invalid_override* ]] || return 1
    python3 -c 'import json,sys; assert isinstance(json.loads(sys.argv[1])["error"], str)' "$output"
  done
}

@test "thresholds: known model with different evidence warns without fallback" {
  threshold_plugin
  python3 - "$TABLE" <<'PYFIX'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d['models']['claude-opus-5-5']['context_cap']['decided_models']=['other-model']
with open(p,'w') as f: json.dump(d,f)
PYFIX
  threshold_record "$WORK/agent-test.jsonl" '"claude-opus-5-5"' 100
  run --separate-stderr "$SCRIPT" --file "$WORK/agent-test.jsonl"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *revalidation_required*other-model*context_cap*"$GUIDE"* ]] || return 1
  [[ "$stderr" != *unknown_model* ]] || return 1
}

@test "thresholds: invalid table and unavailable resolver fail even with explicit cap" {
  threshold_plugin
  local f="$WORK/agent-test.jsonl" kind
  threshold_record "$f" '"claude-opus-5-5"' 100
  cp "$TABLE" "$WORK/table-backup.json"
  for kind in malformed schema missing resolver; do
    cp "$WORK/table-backup.json" "$TABLE"
    case "$kind" in
      malformed) printf '{' > "$TABLE" ;;
      schema) printf '{}' > "$TABLE" ;;
      missing) rm "$TABLE" ;;
      resolver) rm "$WORK/cache-installed/scripts/token_thresholds.py" ;;
    esac
    run --separate-stderr "$SCRIPT" --file "$f" --cap 999
    [ "$status" -eq 1 ]
    python3 -c 'import json,sys; assert isinstance(json.loads(sys.argv[1])["error"], str)' "$output"
    [[ "$stderr" == *subagent-context* ]] || return 1
    if [ "$kind" = resolver ]; then
      [[ "$stderr" == *resolver_unavailable* ]] || return 1
    else
      [[ "$stderr" == *invalid_table* ]] || return 1
    fi
  done
}

@test "thresholds: unknown model diagnostics repeat despite explicit overrides and symlink entry" {
  threshold_plugin
  local f="$WORK/agent-test.jsonl" repeat
  threshold_record "$f" '"new-model"' 100
  ln -s "$SCRIPT" "$WORK/measure-link"
  SCRIPT="$WORK/measure-link"
  for repeat in 1 2; do
    DEV_WORKFLOW_CONTEXT_CAP=bad run --separate-stderr "$SCRIPT" --file "$f" --cap 100
    [ "$status" -eq 0 ]
    assert_context_diagnostics
    [[ "$output" == *'"cap": 100'* ]] || return 1
    [[ "$stderr" != *context_hard_cap* ]] || return 1
  done
}
