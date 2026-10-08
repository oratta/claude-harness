#!/usr/bin/env bats
#
# SubagentStart hook: dev-workflow の 3 役（worker / reviewer / gate-runner）に、親セッションにしか
# 届いていなかった運用情報（Fable 残量モード・共有枠モード・途中計測の閾値）を注入する（issue #715）。
#
# spec: dev-workflow-escalation-tripwires（SubagentStart hook が dev-workflow の役に運用情報を注入する）
#
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  HOOKS_JSON="${PLUGIN_DIR}/hooks/hooks.json"
  SCRIPT="${PLUGIN_DIR}/scripts/subagent-start-context.sh"
  TRIPWIRES="${PLUGIN_DIR}/scripts/session-tripwires.sh"
  TMPD="$(mktemp -d)"
  # 実環境の ~/.claude と実 API を読まない（tripwire-hook.bats の setup と同じ隔離）
  export CLAUDE_ACCOUNTS_FILE="${TMPD}/accounts.json"
  export USAGE_SESSIONS_DIR="${TMPD}/.usage-sessions"
  export USAGE_PROBE_STATE="${TMPD}/.usage-probe-state"
  export USAGE_PROBE_LOCK="${TMPD}/.usage-probe.lock"
  export USAGE_SNAPSHOT="${TMPD}/snapshot.json"
  export USAGE_PROBE_RESPONSE_FILE="${TMPD}/nonexistent.json"
  export CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR"
  unset CLAUDE_SECURESTORAGE_CONFIG_DIR FABLE_BUDGET_MODE SHARED_BUDGET_MODE TRIPWIRES_SCOPE
  unset DEV_WORKFLOW_CONTEXT_CAP DEV_WORKFLOW_CONTEXT_HARD_CAP DEV_WORKFLOW_CONTEXT_TRIPWIRE
}

teardown() {
  rm -rf "$TMPD"
}

# run_hook <agent_type> — SubagentStart の入力を stdin に渡してスクリプトを実行する
run_hook() {
  printf '{"hook_event_name":"SubagentStart","session_id":"s1","agent_id":"a1","agent_type":"%s"}' "$1" \
    > "${TMPD}/payload.json"
  run bash -c "'$SCRIPT' < '${TMPD}/payload.json'"
}

# ctx_of — 直前の run の出力から additionalContext を取り出す（形も検査する）
ctx_of() {
  python3 - "$output" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
h = d["hookSpecificOutput"]
assert h["hookEventName"] == "SubagentStart", h
print(h["additionalContext"])
PY
}

# context-tripwire.sh の env_int の既定値（数値を二重に持たず、実物から読む）
default_of() {
  sed -n "s/^[a-z]* = env_int(\"$1\", \([0-9]*\))$/\1/p" "${PLUGIN_DIR}/scripts/context-tripwire.sh"
}

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "worker: returns SubagentStart additionalContext with budget modes and context thresholds" {
  run_hook "dev-workflow:worker"
  [ "$status" -eq 0 ]
  ctx="$(ctx_of)"
  [[ "$ctx" == *"FABLE_BUDGET_MODE"* ]] || return 1
  [[ "$ctx" == *"SHARED_BUDGET_MODE"* ]] || return 1
  [[ "$ctx" == *"DEV_WORKFLOW_CONTEXT_CAP"* ]] || return 1
  [[ "$ctx" == *"DEV_WORKFLOW_CONTEXT_HARD_CAP"* ]] || return 1
  [[ "$ctx" == *"decision-criteria.md"* ]] || return 1
  # 親向けの「再開前に測る」行は渡さない
  [[ "$ctx" != *"subagent-context.sh"* ]] || return 1
}

@test "Explore: returns nothing" {
  run_hook "Explore"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "decider and other plugins' agents: return nothing" {
  for t in "dev-workflow:decider" "casting:casting-arbiter" "general-purpose" "worker" "dev-workflow:worker2"; do
    run_hook "$t"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "reviewer: context thresholds only, no budget modes" {
  run_hook "dev-workflow:reviewer"
  [ "$status" -eq 0 ]
  ctx="$(ctx_of)"
  [[ "$ctx" == *"DEV_WORKFLOW_CONTEXT_CAP"* ]] || return 1
  [[ "$ctx" != *"FABLE_BUDGET_MODE"* ]] || return 1
  [[ "$ctx" != *"SHARED_BUDGET_MODE"* ]] || return 1
}

@test "gate-runner: explicit budget env reaches the subagent as-is" {
  export FABLE_BUDGET_MODE=reserve SHARED_BUDGET_MODE=throttled
  run_hook "dev-workflow:gate-runner"
  [ "$status" -eq 0 ]
  ctx="$(ctx_of)"
  [[ "$ctx" == *"FABLE_BUDGET_MODE: reserve（明示 env）"* ]] || return 1
  [[ "$ctx" == *"SHARED_BUDGET_MODE: throttled（明示 env）"* ]] || return 1
}

@test "thresholds: env override is shown, unset falls back to context-tripwire.sh defaults" {
  cap_default="$(default_of DEV_WORKFLOW_CONTEXT_CAP)"
  hard_default="$(default_of DEV_WORKFLOW_CONTEXT_HARD_CAP)"
  [ -n "$cap_default" ] && [ -n "$hard_default" ]

  run_hook "dev-workflow:worker"
  ctx="$(ctx_of)"
  [[ "$ctx" == *"DEV_WORKFLOW_CONTEXT_CAP=${cap_default}"* ]] || return 1
  [[ "$ctx" == *"DEV_WORKFLOW_CONTEXT_HARD_CAP=${hard_default}"* ]] || return 1

  export DEV_WORKFLOW_CONTEXT_CAP=90000
  run_hook "dev-workflow:worker"
  ctx="$(ctx_of)"
  [[ "$ctx" == *"DEV_WORKFLOW_CONTEXT_CAP=90000"* ]] || return 1
}

@test "thresholds: DEV_WORKFLOW_CONTEXT_TRIPWIRE=off is reported" {
  export DEV_WORKFLOW_CONTEXT_TRIPWIRE=off
  run_hook "dev-workflow:reviewer"
  [ "$status" -eq 0 ]
  ctx="$(ctx_of)"
  [[ "$ctx" == *"DEV_WORKFLOW_CONTEXT_TRIPWIRE=off"* ]] || return 1
}

@test "thresholds: HARD_CAP <= CAP is reported as forced stop not working" {
  # context-tripwire.sh は hard <= cap のとき PreToolUse（強制停止）を何もせず終える
  export DEV_WORKFLOW_CONTEXT_CAP=220000 DEV_WORKFLOW_CONTEXT_HARD_CAP=150000
  run_hook "dev-workflow:worker"
  [ "$status" -eq 0 ]
  ctx="$(ctx_of)"
  [[ "$ctx" == *"強制停止は働かない"* ]] || return 1

  export DEV_WORKFLOW_CONTEXT_CAP=150000 DEV_WORKFLOW_CONTEXT_HARD_CAP=150000
  run_hook "dev-workflow:worker"
  ctx="$(ctx_of)"
  [[ "$ctx" == *"強制停止は働かない"* ]] || return 1

  # 大小が正しければ注記は出ない
  export DEV_WORKFLOW_CONTEXT_CAP=90000 DEV_WORKFLOW_CONTEXT_HARD_CAP=150000
  run_hook "dev-workflow:worker"
  ctx="$(ctx_of)"
  [[ "$ctx" != *"働かない"* ]] || return 1
}

@test "thresholds: DEV_WORKFLOW_CONTEXT_TRIPWIRE with surrounding spaces is not treated as off" {
  # context-tripwire.sh は "off" との厳密比較なので、" off" では途中計測は働いたまま
  export DEV_WORKFLOW_CONTEXT_TRIPWIRE=" off"
  run_hook "dev-workflow:reviewer"
  [ "$status" -eq 0 ]
  ctx="$(ctx_of)"
  [[ "$ctx" != *"全解除"* ]] || return 1
  [[ "$ctx" == *"DEV_WORKFLOW_CONTEXT_CAP="* ]] || return 1
}

@test "broken input: non-JSON or missing agent_type exits 0 with no output" {
  printf 'not json' > "${TMPD}/bad.txt"
  run bash -c "'$SCRIPT' < '${TMPD}/bad.txt'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf '{"hook_event_name":"SubagentStart"}' > "${TMPD}/noagent.json"
  run bash -c "'$SCRIPT' < '${TMPD}/noagent.json'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "budget block failure still emits the threshold lines" {
  # CLAUDE_PLUGIN_ROOT 配下に session-tripwires.sh が無い構成（残量ブロックが作れない）
  mkdir -p "${TMPD}/root/scripts"
  export CLAUDE_PLUGIN_ROOT="${TMPD}/root"
  run_hook "dev-workflow:worker"
  [ "$status" -eq 0 ]
  ctx="$(ctx_of)"
  [[ "$ctx" == *"DEV_WORKFLOW_CONTEXT_CAP"* ]] || return 1
  [[ "$ctx" != *"FABLE_BUDGET_MODE"* ]] || return 1
}

@test "session-tripwires subagent-budget: budget block only, even without the template, no probe" {
  # テンプレートの無いルート（scripts/ だけ実物を指す）
  mkdir -p "${TMPD}/root"
  ln -s "${PLUGIN_DIR}/scripts" "${TMPD}/root/scripts"
  run env CLAUDE_PLUGIN_ROOT="${TMPD}/root" TRIPWIRES_SCOPE=subagent-budget "$TRIPWIRES"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Fable 残量モード"* ]] || return 1
  [[ "$output" == *"SHARED_BUDGET_MODE"* ]] || return 1
  [[ "$output" != *"subagent-context.sh"* ]] || return 1
  [[ "$output" != *"昇格トリップワイヤー"* ]] || return 1
  # probe の実行痕が無い
  [ ! -e "$USAGE_PROBE_STATE" ]
  [ ! -e "$USAGE_SNAPSHOT" ]
}

@test "session-tripwires subagent-budget: no probe even when the template exists" {
  # テンプレートありの構成。session の経路ならここで usage-probe が走り、試行が記録される
  [ -f "${CLAUDE_PLUGIN_ROOT}/templates/escalation-tripwires.md" ]
  run env TRIPWIRES_SCOPE=subagent-budget "$TRIPWIRES"
  [ "$status" -eq 0 ]
  [[ "$output" == "## Fable 残量モード"* ]] || return 1
  [ ! -e "$USAGE_PROBE_STATE" ]
  [ ! -e "$USAGE_SNAPSHOT" ]
}

@test "session-tripwires: session scope does run the probe (control for the test above)" {
  # 上のテストの assert が probe の実行を見分けられることの対照
  run env "$TRIPWIRES"
  [ "$status" -eq 0 ]
  [ -e "$USAGE_PROBE_STATE" ]
}

@test "session-tripwires: unknown TRIPWIRES_SCOPE keeps the legacy JSON output" {
  run env TRIPWIRES_SCOPE=something-else "$TRIPWIRES"
  [ "$status" -eq 0 ]
  python3 - "$output" <<'PY'
import json, sys
ctx = json.loads(sys.argv[1])["additionalContext"]
assert "昇格トリップワイヤー" in ctx
assert "subagent-context.sh" in ctx
PY
}

@test "hooks.json: SubagentStart entry runs subagent-start-context.sh for the three roles" {
  python3 - "$HOOKS_JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]
entries = d["SubagentStart"]
assert len(entries) == 1, entries
e = entries[0]
assert e["matcher"] == "^dev-workflow:(worker|reviewer|gate-runner)$", e.get("matcher")
assert e["hooks"][0]["type"] == "command"
assert e["hooks"][0]["command"] == '"${CLAUDE_PLUGIN_ROOT}/scripts/subagent-start-context.sh"', e["hooks"][0]
PY
}

@test "hooks.json: matcher and script agree on the target set" {
  # matcher の正規表現と同じ集合に当たるか（片方だけ直る事故を防ぐ）
  for t in dev-workflow:worker dev-workflow:reviewer dev-workflow:gate-runner; do
    run_hook "$t"
    [ -n "$output" ]
  done
  python3 - "$HOOKS_JSON" <<'PY'
import json, re, sys
m = json.load(open(sys.argv[1]))["hooks"]["SubagentStart"][0]["matcher"]
for t in ("dev-workflow:worker", "dev-workflow:reviewer", "dev-workflow:gate-runner"):
    assert re.search(m, t), t
for t in ("Explore", "dev-workflow:decider", "casting:casting-arbiter", "dev-workflow:worker2"):
    assert not re.search(m, t), t
PY
}
