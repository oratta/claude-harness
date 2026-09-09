#!/usr/bin/env bats
#
# subagent-context-audit.sh: サブエージェントのトランスクリプトを母集団として走査し、
# 初回・最終コンテキストの中央値と上限超の割合を 1 行 JSON で出す（観測専用・fail-open）。
#
# spec: openspec dev-workflow-execution-strategy
#       「サブエージェントのコンテキスト量の母集団集計」「集計結果の永続化と監査手順の文書」
#
# テストは実機の ~/.claude を読まない。fixture ディレクトリを --projects で、
# キャッシュを --cache で差し替える（どちらも指定しないと $HOME を触るため必須）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/subagent-context-audit.sh"
  WORK="$(mktemp -d)"
  PROJECTS="${WORK}/projects"
  CACHE="${WORK}/cache"
}

teardown() {
  rm -rf "$WORK"
}

# サブエージェント 1 体分のトランスクリプトと meta.json を作る。
#   make_agent <slug> <sess> <fname> <meta-mode> <first-ctx> <last-ctx>
# meta-mode: isolated（spawnedWithWorktree: true）/ plain（キー無し）/ none（meta 無し）/ broken（壊れた meta）
make_agent() {
  local slug="$1" sess="$2" fname="$3" mode="$4" first="$5" last="$6"
  local dir="${PROJECTS}/${slug}/${sess}/subagents"
  mkdir -p "$dir"
  local f="${dir}/${fname}"
  printf '{"type":"user","isSidechain":true,"cwd":"/tmp/x","message":{"role":"user","content":"hi"}}\n' > "$f"
  assistant_line "$first" >> "$f"
  printf '{"type":"user","message":{"role":"user","content":"more"}}\n' >> "$f"
  assistant_line "$last" >> "$f"
  local meta="${dir}/${fname%.jsonl}.meta.json"
  case "$mode" in
    isolated) printf '{"name":"W-1","agentType":"general-purpose","spawnedWithWorktree":true,"worktreePath":"/tmp/wt"}\n' > "$meta" ;;
    plain)    printf '{"name":"R1-1","agentType":"general-purpose"}\n' > "$meta" ;;
    none)     : ;;
    broken)   printf '{not json\n' > "$meta" ;;
  esac
  echo "$f"
}

# コンテキスト量 $1 を持つ assistant レコード 1 行（cache_read に全量を寄せる）
assistant_line() {
  printf '{"type":"assistant","message":{"model":"claude-sonnet-5","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s,"output_tokens":10}}}\n' "$1"
}

# $1 日前の touch 用タイムスタンプ（BSD date / GNU date の両対応）
days_ago_stamp() {
  date -v-"$1"d +%Y%m%d%H%M 2>/dev/null || date -d "$1 days ago" +%Y%m%d%H%M
}

@test "script: is executable and prints help without scanning" {
  [ -x "$SCRIPT" ]
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  echo "$output" | grep -q 'subagent-context-audit.sh'
}

@test "output: emits a one-line JSON with every required key and exit 0" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  make_agent p1 s1 agent-aW-2-2222.jsonl plain 20000 50000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | wc -l | tr -d ' ')" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
for k in ("count","first_median","first_max","last_median","last_max",
          "over_cap_pct","cap","days","sources","generated_at"):
    assert k in d, (k, d)
assert d["count"] == 2, d
assert d["days"] == 14, d
assert d["cap"] == 150000, d
PY
}

@test "isolation: isolated and non-isolated agents are both counted and split into sources" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  make_agent p1 s1 agent-aW-2-2222.jsonl plain 20000 50000 >/dev/null
  make_agent p1 s1 agent-aW-3-3333.jsonl plain 30000 160000 >/dev/null
  make_agent p1 s1 agent-abc123def4567890.jsonl isolated 100000 200000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --cap 150000
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["count"] == 4, d
# 全体: first 10000/20000/30000/100000 -> 中央 2 値の平均 25000、最大 100000
assert d["first_median"] == 25000, d
assert d["first_max"] == 100000, d
# 全体: last 40000/50000/160000/200000 -> 105000、最大 200000
assert d["last_median"] == 105000, d
assert d["last_max"] == 200000, d
assert d["over_cap_pct"] == 50.0, d
iso, non = d["sources"]["isolated"], d["sources"]["non_isolated"]
for s in (iso, non):
    for k in ("count","first_median","last_median","over_cap_pct"):
        assert k in s, (k, s)
assert iso["count"] == 1 and non["count"] == 3, d
assert iso["count"] + non["count"] == d["count"], d
assert iso["first_median"] == 100000 and iso["last_median"] == 200000, d
assert iso["over_cap_pct"] == 100.0, d
assert non["first_median"] == 20000 and non["last_median"] == 50000, d
assert non["over_cap_pct"] == 33.3, d
PY
}

@test "population: nested claude sessions, main sessions and workflow subagents are not counted" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  # (a) worktree の中から起動された入れ子の claude セッション（別 project ディレクトリ）
  mkdir -p "${PROJECTS}/p1--claude-worktrees-agent-abc123"
  assistant_line 999999 > "${PROJECTS}/p1--claude-worktrees-agent-abc123/11111111-2222-3333-4444-555555555555.jsonl"
  # (b) メインセッション
  assistant_line 888888 > "${PROJECTS}/p1/66666666-7777-8888-9999-aaaaaaaaaaaa.jsonl"
  # (c) Workflow 経由のサブエージェント（subagents/ の内側だが固定深さの経路に当たらない）
  mkdir -p "${PROJECTS}/p1/s1/subagents/workflows/wf_x"
  assistant_line 777777 > "${PROJECTS}/p1/s1/subagents/workflows/wf_x/agent-y.jsonl"
  assistant_line 666666 > "${PROJECTS}/p1/s1/subagents/workflows/wf_x/journal.jsonl"
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["count"] == 1, d
assert d["sources"]["isolated"]["count"] + d["sources"]["non_isolated"]["count"] == 1, d
assert d["first_max"] == 10000, d
assert d["last_max"] == 40000, d
PY
}

@test "meta: a missing or broken meta.json still counts and falls back to non_isolated" {
  make_agent p1 s1 agent-abc123def4567890.jsonl isolated 100000 200000 >/dev/null
  make_agent p1 s1 agent-aaaa111122223333.jsonl none 10000 40000 >/dev/null
  make_agent p1 s1 agent-bbbb111122223333.jsonl broken 20000 50000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["count"] == 3, d
iso, non = d["sources"]["isolated"], d["sources"]["non_isolated"]
assert iso["count"] == 1, d
assert non["count"] == 2, d
assert iso["count"] + non["count"] == d["count"], d
PY
}

@test "window: transcripts older than --days are not counted" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  old="$(make_agent p1 s1 agent-aW-9-9999.jsonl plain 90000 190000)"
  touch -t "$(days_ago_stamp 30)" "$old"
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --days 14
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["count"] == 1, d
assert d["first_max"] == 10000, d
assert d["sources"]["non_isolated"]["count"] == 1, d
PY
}

@test "cap: over_cap_pct reflects the share above the cap and --cap replaces the threshold" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  make_agent p1 s1 agent-aW-2-2222.jsonl plain 20000 50000 >/dev/null
  make_agent p1 s1 agent-aW-3-3333.jsonl plain 30000 60000 >/dev/null
  make_agent p1 s1 agent-aW-4-4444.jsonl plain 40000 70000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --cap 55000
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["cap"] == 55000, d
assert d["over_cap_pct"] == 50.0, d
PY
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --cap 100000 --refresh
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["over_cap_pct"] == 0.0, d
PY
}

@test "fail-open: an empty or missing projects dir yields count 0 and exit 0" {
  mkdir -p "$PROJECTS"
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["count"]==0, d'
  run "$SCRIPT" --projects "${WORK}/nope" --cache "$CACHE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["count"]==0, d'
}

@test "fail-open: a malformed JSON line does not stop the aggregation" {
  f="$(make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000)"
  printf 'null\n{not json\n' >> "$f"
  assistant_line 45000 >> "$f"
  make_agent p1 s1 agent-aW-2-2222.jsonl plain 20000 50000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["count"] == 2, d
assert d["last_max"] == 50000, d
PY
}

@test "args: an unknown flag or a missing value exits 1 with a one-line JSON error" {
  run "$SCRIPT" --days
  [ "$status" -eq 1 ]
  echo "$output" | grep -q '"error"'
  run "$SCRIPT" --bogus
  [ "$status" -eq 1 ]
}

@test "cache: within the TTL the cached content is returned without rescanning" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  first="$output"
  [ -f "$CACHE" ]
  # トランスクリプトを増やしても、TTL 内なら出力は変わらない（走査していない証拠）
  make_agent p1 s1 agent-aW-2-2222.jsonl plain 20000 50000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  [ "$output" = "$first" ]
  # TTL を 0 にすればキャッシュは効かない
  run env SUBAGENT_CONTEXT_AUDIT_TTL=0 "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["count"]==2, d'
}

@test "cache: --refresh ignores the TTL and rewrites the cache file" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  make_agent p1 s1 agent-aW-2-2222.jsonl plain 20000 50000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --refresh
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["count"]==2, d'
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["count"]==2, d' "$CACHE"
}

@test "cache: SUBAGENT_CONTEXT_AUDIT_CACHE env sets the default cache path" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  run env SUBAGENT_CONTEXT_AUDIT_CACHE="${WORK}/env-cache" "$SCRIPT" --projects "$PROJECTS"
  [ "$status" -eq 0 ]
  [ -f "${WORK}/env-cache" ]
}
