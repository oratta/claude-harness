#!/usr/bin/env bats
# Passive collector contract; all fixtures and results live outside the repository.
setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  SCRIPT="$ROOT/plugins/dev-workflow/scripts/idle-compaction-observation.py"
  WORK="$(mktemp -d)"
  export LLM_LOG_DIR="$WORK/results"
  export OBS_WORK="$WORK"
  python3 - <<'PY'
import json, os
from pathlib import Path
p = Path(os.environ['OBS_WORK'])
records = [
 {'type':'system','subtype':'compact_boundary'},
 {'type':'assistant','message':{'content':'SECRET_FIXTURE', 'usage':{
  'input_tokens':50000,'cache_creation_input_tokens':50000,'cache_read_input_tokens':50000}}},
 {'type':'user','message':{'content':'compact_boundary SECRET_FIXTURE'}},
 {'type':'future-type','tool_output':'SECRET_FIXTURE'},
 {'type':'system','subtype':'compact_boundary'}]
(p/'log.jsonl').write_text(''.join(json.dumps(x)+'\n' for x in records))
meta = dict(role='parent', kind='idle', version='2.1.0', plugin_commit='a'*40,
 effective_idle='off', config_method='config', parent_before='on', parent_after='off',
 parent_application='live', child_idle_argument='unknown', start_line=2, end_line=4,
 start_time='2026-11-20T00:00:00Z', end_time='2026-11-20T01:00:00Z',
 last_request_time='2026-11-20T00:00:00Z', last_request_source='request-log',
 idle_threshold=150000, threshold_source='version-default', sleep='no',
 extra_requests='no', compact_kind='none', compact_source='unknown',
 hook_notice='not-performed', skill_read='not-performed', unknown_secret='SECRET_FIXTURE')
(p/'meta.json').write_text(json.dumps(meta))
PY
}
teardown() {
  rm -rf "$WORK"
}
mutate() {
  python3 - "$WORK/meta.json" "$1" <<'PY'
import json, sys
from pathlib import Path
p=Path(sys.argv[1]); d=json.loads(p.read_text()); d.update(json.loads(sys.argv[2])); p.write_text(json.dumps(d))
PY
}
collect() {
  run python3 "$SCRIPT" --transcript "$WORK/log.jsonl" --metadata "$WORK/meta.json"
}
assert_result() {
  [ "$status" -eq 0 ]
  [[ "$output" != *SECRET_FIXTURE* ]] || return 1
  python3 - "$LLM_LOG_DIR" "$1" "${2-}" <<'PY'
import json, sys
from pathlib import Path
p=max(Path(sys.argv[1]).glob('*.json'), key=lambda p:p.stat().st_mtime_ns)
s=p.read_text(); assert 'SECRET_FIXTURE' not in s
r=json.loads(s); assert r['result']==sys.argv[2], r
if sys.argv[3]: assert sys.argv[3] in r['reasons'], r
PY
}
@test "storage: unset and empty LLM_LOG_DIR stop before creating anything" {
  unset LLM_LOG_DIR
  collect
  [ "$status" -eq 1 ]; [[ "$output" == *LLM_LOG_DIR* ]] || return 1
  export LLM_LOG_DIR=''
  collect
  [ "$status" -eq 1 ]; [ ! -e "$WORK/results" ]
}
@test "storage: cwd repo, plugin repo and symlink destinations are rejected" {
  export LLM_LOG_DIR="$ROOT/forbidden-observation"
  collect
  [ "$status" -eq 1 ]; [ ! -e "$LLM_LOG_DIR" ]
  ln -s "$ROOT" "$WORK/link"
  export LLM_LOG_DIR="$WORK/link/forbidden-observation"
  collect
  [ "$status" -eq 1 ]; [ ! -e "$LLM_LOG_DIR" ]
  git init -q "$WORK/other"
  cd "$WORK/other"
  export LLM_LOG_DIR="$WORK/other/output"
  collect
  [ "$status" -eq 1 ]; [ ! -e "$LLM_LOG_DIR" ]
}
@test "privacy: allowlist, fixed errors, original log unchanged, exclusive new results" {
  cp "$WORK/log.jsonl" "$WORK/original"
  collect
  assert_result observed
  collect
  assert_result observed
  [ "$(find "$LLM_LOG_DIR" -name '*.json' | wc -l | tr -d ' ')" -eq 2 ]
  cmp "$WORK/log.jsonl" "$WORK/original"
  printf '{SECRET_FIXTURE' > "$WORK/meta.json"
  collect
  [ "$status" -eq 1 ]; [[ "$output" != *SECRET_FIXTURE* ]] || return 1
}
@test "metadata: invalid known types and enum values never echo input" {
  for patch in '{"sleep":"SECRET_FIXTURE"}' '{"start_line":true}' '{"version":"SECRET_FIXTURE"}' '{"idle_threshold":-1}' '{"role":{}}'; do
    cp "$WORK/meta.json" "$WORK/saved"
    mutate "$patch"
    collect
    [ "$status" -eq 1 ]; [[ "$output" != *SECRET_FIXTURE* ]] || return 1
    mv "$WORK/saved" "$WORK/meta.json"
  done
}
@test "interval: only JSON system compact_boundary in S < line <= E counts" {
  collect
  assert_result observed
  mutate '{"end_line":5}'
  collect
  assert_result unexpected-boundary
  python3 - "$LLM_LOG_DIR" <<'PY'
import json, sys
from pathlib import Path
r=json.loads(max(Path(sys.argv[1]).glob('*.json'),key=lambda p:p.stat().st_mtime_ns).read_text())
assert r['boundary_count']==1 and r['context_tokens']==150000 and r['elapsed_seconds']==3600, r
PY
}
@test "context: exit 0 and 2 are measurements; end usage cannot repair start" {
  export DEV_WORKFLOW_CONTEXT_CAP=100000
  collect
  assert_result observed
  export DEV_WORKFLOW_CONTEXT_CAP=200000
  mutate '{"idle_threshold":150001}'
  printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":999999}}}' >> "$WORK/log.jsonl"
  mutate '{"end_line":6}'
  collect
  assert_result unverified context-below-threshold
}
@test "context: no usage is unknown, never zero" {
  mutate '{"start_line":1}'
  collect
  assert_result unverified context-unavailable
}
@test "interval: malformed JSON, nonobject, incomplete line, truncation, unreadable log" {
  cp "$WORK/log.jsonl" "$WORK/saved"
  for line in '{SECRET_FIXTURE' 'null'; do
    head -n 2 "$WORK/saved" > "$WORK/log.jsonl"
    printf '%s\n' "$line" >> "$WORK/log.jsonl"
    collect
    assert_result unverified invalid-transcript
  done
  head -n 2 "$WORK/saved" > "$WORK/log.jsonl"
  printf '%s' '{"type":"user"}' >> "$WORK/log.jsonl"
  collect
  assert_result unverified incomplete-transcript
  head -n 2 "$WORK/saved" > "$WORK/log.jsonl"
  collect
  assert_result unverified truncated-transcript
  rm "$WORK/log.jsonl"
  collect
  assert_result unverified unreadable-transcript
}
@test "idle: 3599 seconds fails, 3600 seconds succeeds" {
  mutate '{"end_time":"2026-11-20T00:59:59Z"}'
  collect
  assert_result unverified idle-too-short
  mutate '{"end_time":"2026-11-20T01:00:00Z"}'
  collect
  assert_result observed
}
@test "idle: every unknown or contrary condition stays unverified" {
  for patch in '{"sleep":"yes"}' '{"sleep":"unknown"}' '{"extra_requests":"yes"}' '{"extra_requests":"unknown"}' '{"compact_kind":"manual"}' '{"compact_kind":"automatic"}' '{"compact_kind":"unknown"}' '{"effective_idle":"on"}' '{"effective_idle":"unknown"}' '{"config_method":"unknown"}' '{"threshold_source":"unknown"}' '{"idle_threshold":null}' '{"last_request_source":"unknown"}' '{"last_request_time":null}' '{"version":null}' '{"plugin_commit":null}' '{"role":"standalone"}'; do
    cp "$WORK/meta.json" "$WORK/saved"
    mutate "$patch"
    collect
    assert_result unverified
    mv "$WORK/saved" "$WORK/meta.json"
  done
}
@test "interval: inconsistent positions and times stay unverified" {
  for patch in '{"start_line":5,"end_line":2}' '{"start_line":null}' '{"start_time":"2026-11-20T02:00:00Z"}' '{"last_request_time":"2026-11-20T00:00:01Z"}' '{"start_time":null}' '{"end_time":"2026-99-20T00:00:00Z"}'; do
    cp "$WORK/meta.json" "$WORK/saved"
    mutate "$patch"
    collect
    assert_result unverified
    mv "$WORK/saved" "$WORK/meta.json"
  done
}
@test "config: standalone effective value needs no idle wait" {
  mutate '{"role":"standalone","kind":"config","start_time":null,"end_time":null,"last_request_time":null,"start_line":null,"end_line":null}'
  collect
  assert_result observed
  mutate '{"effective_idle":"unknown"}'
  collect
  assert_result unverified
}
@test "normal-compact: separate automatic boundary, notice and SKILL Read evidence" {
  mutate '{"kind":"normal-compact","end_line":5,"compact_kind":"automatic","compact_source":"session-observation","hook_notice":"yes","skill_read":"yes"}'
  collect
  assert_result observed
  for patch in '{"compact_kind":"manual"}' '{"hook_notice":"not-performed"}' '{"skill_read":"unknown"}' '{"compact_source":"unknown"}'; do
    cp "$WORK/meta.json" "$WORK/saved"
    mutate "$patch"
    collect
    assert_result unverified
    mv "$WORK/saved" "$WORK/meta.json"
  done
}
@test "documentation: published metadata and JSONL example collect outside repo" {
  python3 - "$ROOT/plugins/dev-workflow/skills/develop/references/idle-compaction-observation.md" "$WORK" <<'PY'
import re, sys
from pathlib import Path
text=Path(sys.argv[1]).read_text(); work=Path(sys.argv[2])
for lang, name in [('json','meta.json'), ('jsonl','log.jsonl')]:
    (work/name).write_text(re.search(r'```'+lang+r'\n(.*?)\n```', text, re.S)[1]+'\n')
PY
  collect
  assert_result observed
}
@test "failures: missing metadata, bad arguments and unsavable destination use fixed errors" {
  run python3 "$SCRIPT" --transcript "$WORK/SECRET_FIXTURE" --metadata "$WORK/SECRET_FIXTURE"
  [ "$status" -eq 1 ]; [[ "$output" != *SECRET_FIXTURE* ]] || return 1
  run python3 "$SCRIPT" --SECRET_FIXTURE
  [ "$status" -eq 1 ]; [[ "$output" != *SECRET_FIXTURE* ]] || return 1
  touch "$WORK/blocked"
  export LLM_LOG_DIR="$WORK/blocked/results"
  collect
  [ "$status" -eq 1 ]; [[ "$output" == collection-failed ]] || return 1
}
