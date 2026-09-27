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

# --by-role 検証用: meta.json（agentType / description）だけを持つ空トランスクリプトを作る。
# 本体の行は呼び出し側が rl_user / rl_asst / rl_asst_tool で追記する。
#   make_role_agent <slug> <sess> <fname> <agentType> <description>
make_role_agent() {
  local slug="$1" sess="$2" fname="$3" agent_type="$4" desc="$5"
  local dir="${PROJECTS}/${slug}/${sess}/subagents"
  mkdir -p "$dir"
  local f="${dir}/${fname}"
  : > "$f"
  python3 -c 'import json,sys; print(json.dumps({"agentType": sys.argv[1], "description": sys.argv[2]}))' \
    "$agent_type" "$desc" > "${dir}/${fname%.jsonl}.meta.json"
  echo "$f"
}

# timestamp 付き user レコード 1 行（$1 が空なら timestamp キーを付けない）
rl_user() {
  if [ -n "$1" ]; then
    printf '{"type":"user","timestamp":"%s","message":{"role":"user","content":"hi"}}\n' "$1"
  else
    printf '{"type":"user","message":{"role":"user","content":"hi"}}\n'
  fi
}

# usage だけを持つ assistant レコード 1 行（コンテキスト量 $1）
rl_asst() {
  printf '{"type":"assistant","message":{"usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s,"output_tokens":1}}}\n' "$1"
}

# tool_use を 1 つ含む assistant レコード（usage $1、ツール名 $2、file_path $3。$3 省略なら input:{}）
rl_asst_tool() {
  local usage="$1" name="$2" fp="${3-}"
  if [ -n "$fp" ]; then
    printf '{"type":"assistant","message":{"usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s,"output_tokens":1},"content":[{"type":"tool_use","name":"%s","input":{"file_path":"%s"}}]}}\n' "$usage" "$name" "$fp"
  else
    printf '{"type":"assistant","message":{"usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s,"output_tokens":1},"content":[{"type":"tool_use","name":"%s","input":{}}]}}\n' "$usage" "$name"
  fi
}

# 担当分類（agentType 優先 / description 先頭トークン / unknown）を確かめるための
# 7 体の混在 fixture（W / R1 / G / Reviewer / decider / unknown x2）を作る。
seed_role_mix() {
  local f
  f="$(make_role_agent p1 s1 agent-w1.jsonl general-purpose "W: #552 impl")"
  rl_asst 1000 >> "$f"; rl_asst 2000 >> "$f"

  f="$(make_role_agent p1 s1 agent-r1.jsonl general-purpose "R1: 仕様レビュー #552")"
  rl_asst 1000 >> "$f"; rl_asst 2000 >> "$f"

  f="$(make_role_agent p1 s1 agent-g1.jsonl general-purpose "G: gate for #552")"
  rl_asst 1000 >> "$f"; rl_asst 2000 >> "$f"

  f="$(make_role_agent p1 s1 agent-reviewer1.jsonl general-purpose "Reviewer: code review for #552")"
  rl_asst 1000 >> "$f"; rl_asst 2000 >> "$f"

  # agentType が decider を示せば description が R1 の体裁でも decider に分類される（D1）
  f="$(make_role_agent p1 s1 agent-decider1.jsonl dev-workflow:decider "R1: 仕様レビュー")"
  rl_asst 1000 >> "$f"; rl_asst 2000 >> "$f"

  # コロンはあるが先頭トークンがどれとも一致しない → unknown
  f="$(make_role_agent p1 s1 agent-unknown-desc.jsonl general-purpose "note: something")"
  rl_asst 1000 >> "$f"; rl_asst 2000 >> "$f"

  # meta.json 自体が無い → unknown
  make_agent p1 s1 agent-unknown-nometa.jsonl none 1000 2000 >/dev/null
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

@test "fail-open: an unreadable projects dir keeps the previous cache instead of caching an empty result" {
  [ "$(id -u)" -ne 0 ] || skip "root には chmod 000 が効かない"
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --refresh
  [ "$status" -eq 0 ]
  good="$output"
  chmod 000 "$PROJECTS"
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --refresh
  st="$status"; out="$output"
  chmod 755 "$PROJECTS"
  [ "$st" -eq 0 ]
  echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["count"]==0, d; assert d.get("note"), d'
  # 走査できなかった空の結果でキャッシュを上書きしない（TTL のあいだ配られてしまうため）
  [ "$(cat "$CACHE")" = "$good" ]
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["count"]==1, d' "$CACHE"
}

@test "fail-open: an unreadable subdirectory yields a partial result that is not cached" {
  [ "$(id -u)" -ne 0 ] || skip "root には chmod 000 が効かない"
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  make_agent p2 s1 agent-aW-2-2222.jsonl plain 20000 50000 >/dev/null
  chmod 000 "${PROJECTS}/p2"
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --refresh
  st="$status"; out="$output"
  chmod 755 "${PROJECTS}/p2"
  [ "$st" -eq 0 ]
  echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["count"]==1, d; assert d.get("note"), d'
  [ ! -e "$CACHE" ]
}

@test "fail-open: usage values that are not real token counts do not abort the run" {
  f="$(make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000)"
  # JSON としては妥当だが実在しないトークン数。末尾に置いて last_ctx 側で踏ませる
  printf '{"type":"assistant","message":{"usage":{"input_tokens":1e999,"cache_read_input_tokens":0}}}\n' >> "$f"
  printf '{"type":"assistant","message":{"usage":{"input_tokens":NaN,"cache_read_input_tokens":0}}}\n' >> "$f"
  make_agent p1 s1 agent-aW-2-2222.jsonl plain 20000 50000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["count"] == 2, d
# inf / NaN の行は usage 無しとして飛ばし、その手前の妥当な行（40000）が最終値になる。
# 0 として数えていれば last_median は 20000 に落ちる。
assert d["last_median"] == 45000, d
assert d["last_max"] == 50000, d
assert d["first_max"] == 20000, d
PY
}

@test "window: a usage line sitting exactly on the 4 MiB window boundary is still found" {
  dir="${PROJECTS}/p1/s1/subagents"
  mkdir -p "$dir"
  python3 - "${dir}/agent-aW-1-1111.jsonl" <<'PY'
import sys
# 最終 usage 行の先頭から EOF までをちょうど 4 MiB（窓の倍加上限）にする。窓の左端が
# 行頭と一致するので、先頭行を無条件に捨てる実装だとこの行を落として last が None になる。
usage = ('{"type":"assistant","message":{"usage":{"input_tokens":0,'
         '"cache_creation_input_tokens":0,"cache_read_input_tokens":123456,'
         '"output_tokens":1}}}\n')
head = '{"type":"user","message":{"role":"user","content":"start"}}\n'
tail_len = 4 * 1024 * 1024 - len(usage)
assert tail_len > 0
with open(sys.argv[1], "w", encoding="utf-8") as f:
    f.write(head)
    f.write(usage)
    f.write("x" * (tail_len - 1) + "\n")  # usage を持たない詰め物
PY
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["count"] == 1, d
assert d["first_max"] == 123456, d
assert d["last_max"] == 123456, d
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

# mtime を読む `stat` の実装差を再現するシム。$1 が受け付ける形式でだけ mtime を返し、
# もう一方の形式では実物と同じ「mtime ではない結果」を返す。シムを置いたディレクトリを echo する。
#   gnu: `-c %Y` が mtime。`-f` はファイルシステム情報の表示になり、stdout に非数値を残す
#   bsd: `-f %m` が mtime。`-c` は不正オプションとして stderr に出して非0終了する
make_stat_shim() {
  local kind="$1" dir="${WORK}/shim-${kind}"
  mkdir -p "$dir"
  {
    printf '#!/usr/bin/env bash\nkind=%s\n' "$kind"
    cat <<'SHIM'
mtime() { python3 -c 'import os,sys; print(int(os.path.getmtime(sys.argv[1])))' "$1"; }
if [ "$kind" = gnu ]; then
  case "$1" in
    -c) mtime "$3"; exit 0 ;;
    -f) echo "  File: \"$3\"    ID: 0 Namelen: 255     Type: ext2/ext3"; exit 0 ;;
  esac
else
  case "$1" in
    -f) mtime "$3"; exit 0 ;;
    -c) echo "stat: illegal option -- c" >&2; exit 1 ;;
  esac
fi
exit 1
SHIM
  } > "${dir}/stat"
  chmod +x "${dir}/stat"
  echo "$dir"
}

@test "portability: the TTL check reads the cache mtime with either GNU or BSD stat" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  for kind in gnu bsd; do
    shim="$(make_stat_shim "$kind")"
    c="${WORK}/cache-${kind}"
    run env PATH="${shim}:${PATH}" "$SCRIPT" --projects "$PROJECTS" --cache "$c"
    [ "$status" -eq 0 ]
    first="$output"
    # 間で 1 体増やしても TTL 内なら出力が変わらない＝mtime が読めてキャッシュが効いている。
    # mtime が読めないと走査に落ちて件数が変わり、算術展開が壊れると非0終了する。
    make_agent "p-${kind}" s1 agent-aW-9-9999.jsonl plain 20000 50000 >/dev/null
    run env PATH="${shim}:${PATH}" "$SCRIPT" --projects "$PROJECTS" --cache "$c"
    [ "$status" -eq 0 ]
    [ "$output" = "$first" ]
  done
}

# ---- --by-role（openspec/changes/context-audit-by-role） ----

@test "by-role: default invocation (no --by-role) output is unchanged" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  make_agent p1 s1 agent-aW-2-2222.jsonl plain 20000 50000 >/dev/null
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "by_role" not in d, d'
}

@test "by-role: agentType decider overrides description, leading token maps roles, rest fall to unknown" {
  seed_role_mix
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --by-role
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
br = d["by_role"]
assert br["W"]["count"] == 1, br
assert br["R1"]["count"] == 1, br
assert br["G"]["count"] == 1, br
assert br["Reviewer"]["count"] == 1, br
# agentType: dev-workflow:decider が description の "R1:" 見た目より優先される
assert br["decider"]["count"] == 1, br
assert br["unknown"]["count"] == 2, br  # note: something / meta 無し
PY
}

@test "by-role: role counts sum to the overall count and only W carries reread_pct" {
  seed_role_mix
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --by-role
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
br = d["by_role"]
roles = ("W", "R1", "G", "Reviewer", "decider", "unknown")
assert sum(br[r]["count"] for r in roles) == d["count"], (br, d["count"])
for r in roles:
    for k in ("count", "first_median", "docs_median", "last_median", "over_cap_pct"):
        assert k in br[r], (r, k)
    if r == "W":
        assert "reread_pct" in br[r], br[r]
    else:
        assert "reread_pct" not in br[r], br[r]
PY
}

@test "by-role: zero transcripts still fills all 6 roles with null/0.0 (python3 present)" {
  mkdir -p "$PROJECTS"
  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --by-role
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["count"] == 0, d
br = d["by_role"]
for role in ("W", "R1", "G", "Reviewer", "decider", "unknown"):
    r = br[role]
    assert r["count"] == 0, (role, r)
    assert r["first_median"] is None, (role, r)
    assert r["docs_median"] is None, (role, r)
    assert r["last_median"] is None, (role, r)
    assert r["over_cap_pct"] == 0.0, (role, r)
assert br["W"]["reread_pct"] is None, br["W"]
PY
}

@test "docs_median: per-individual hop diffs are summed, then medianed across W individuals" {
  fa="$(make_role_agent p1 s1 agent-docs-a.jsonl general-purpose "W: docs test A")"
  rl_user "2026-09-01T00:00:00Z" >> "$fa"
  rl_asst_tool 10000 Read "plugins/cache/oratta-claude-harness/df824c26439f/skills/develop/references/roles/worker.md" >> "$fa"
  rl_asst 13000 >> "$fa"                 # ホップ1: 10000 -> 13000 (diff 3000)
  rl_asst_tool 13000 Skill "" >> "$fa"
  rl_asst 15000 >> "$fa"                 # ホップ2: 13000 -> 15000 (diff 2000, 合計 5000)

  fb="$(make_role_agent p1 s1 agent-docs-b.jsonl general-purpose "W: docs test B")"
  rl_user "2026-09-01T00:00:00Z" >> "$fb"
  rl_asst 5000 >> "$fb"
  rl_asst 8000 >> "$fb"                  # 対象ホップ無し（合計 0）

  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --by-role
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
# 個体 A の合計 5000 と個体 B の合計 0 の中央値 = 2500
assert d["by_role"]["W"]["docs_median"] == 2500, d["by_role"]["W"]
PY
}

@test "reread_pct: a later W re-reading a basename the earlier W already read" {
  f1="$(make_role_agent p1 s1 agent-w-first.jsonl general-purpose "W: #552 first")"
  rl_user "2026-09-01T00:00:00Z" >> "$f1"
  rl_asst_tool 1000 Read "/Users/oratta/wtA/fileA.md" >> "$f1"
  rl_asst_tool 1000 Read "/Users/oratta/wtA/fileB.md" >> "$f1"
  rl_asst 2000 >> "$f1"

  # ディレクトリが違っても末尾のファイル名（ベースネーム）が一致すれば読み直しに数える
  f2="$(make_role_agent p1 s1 agent-w-second.jsonl general-purpose "W: #552 second")"
  rl_user "2026-09-02T00:00:00Z" >> "$f2"
  rl_asst_tool 3000 Read "/Users/oratta/wtB/fileA.md" >> "$f2"
  rl_asst 4000 >> "$f2"

  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --by-role
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
# 先行が fileA.md/fileB.md、後続が fileA.md のみ -> 1/2 = 50.0
assert d["by_role"]["W"]["reread_pct"] == 50.0, d["by_role"]["W"]
PY
}

@test "reread_pct: group leader and #N-less W are excluded, leftmost #N is used for grouping" {
  # 自分だけの単独グループ（先行なし）→ 母数から除かれる
  fL="$(make_role_agent p1 s1 agent-w-leader-only.jsonl general-purpose "W: #700 only")"
  rl_user "2026-09-01T00:00:00Z" >> "$fL"
  rl_asst_tool 1000 Read "/tmp/x/onlyfile.md" >> "$fL"
  rl_asst 2000 >> "$fL"

  # #N が取れない → 対象から除かれる
  fN="$(make_role_agent p1 s1 agent-w-nonum.jsonl general-purpose "W: 何かをする")"
  rl_user "2026-09-01T01:00:00Z" >> "$fN"
  rl_asst_tool 1000 Read "/tmp/x/otherfile.md" >> "$fN"
  rl_asst 2000 >> "$fN"

  # #400 のグループ最初
  f1="$(make_role_agent p1 s1 agent-w-400-first.jsonl general-purpose "W: #400 initial")"
  rl_user "2026-09-01T02:00:00Z" >> "$f1"
  rl_asst_tool 1000 Read "/tmp/x/fileC.md" >> "$f1"
  rl_asst 2000 >> "$f1"

  # description に #N が 2 つ（#400, #288）。最も左の #400 でグループ化されれば
  # #400-first の後続として fileC.md を 100% 読み直したことになる。
  # #288（最も右）でグループ化されると単独グループ（先行なし）になり母数から消える。
  f2="$(make_role_agent p1 s1 agent-w-400-second.jsonl general-purpose "W: gate for PR #400 (#288)")"
  rl_user "2026-09-01T03:00:00Z" >> "$f2"
  rl_asst_tool 3000 Read "/tmp/x/fileC.md" >> "$f2"
  rl_asst 4000 >> "$f2"

  run "$SCRIPT" --projects "$PROJECTS" --cache "$CACHE" --by-role
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
assert d["by_role"]["W"]["reread_pct"] == 100.0, d["by_role"]["W"]
PY
}

@test "cache: --by-role uses a separate default cache file with a .by-role suffix" {
  make_agent p1 s1 agent-aW-1-1111.jsonl plain 10000 40000 >/dev/null
  default_cache="${WORK}/default-cache"
  run env SUBAGENT_CONTEXT_AUDIT_CACHE="$default_cache" "$SCRIPT" --projects "$PROJECTS"
  [ "$status" -eq 0 ]
  [ -f "$default_cache" ]
  [ ! -f "${default_cache}.by-role" ]
  run env SUBAGENT_CONTEXT_AUDIT_CACHE="$default_cache" "$SCRIPT" --projects "$PROJECTS" --by-role --refresh
  [ "$status" -eq 0 ]
  [ -f "${default_cache}.by-role" ]
  ! grep -q '"by_role"' "$default_cache" || return 1
  grep -q '"by_role"' "${default_cache}.by-role"
}
