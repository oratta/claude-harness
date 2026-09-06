#!/usr/bin/env bats
#
# agent-model-guard.sh: PreToolUse（Agent）で model 未指定の spawn を拒否する。
# 規範: rules/subagent-model-selection.md（model は必ず明示。fork は最上位ティアの仕事だけ）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/agent-model-guard.sh"
  WORK="$(mktemp -d)"
}

teardown() {
  rm -rf "$WORK"
}

call() {  # $1 = JSON payload on stdin
  run env USAGE_SNAPSHOT="${WORK}/none.json" "$SCRIPT" <<<"$1"
}

denied() { echo "$output" | grep -q '"permissionDecision": "deny"'; }

@test "script: is executable" {
  [ -x "$SCRIPT" ]
}

@test "other tools: no output, exit 0" {
  call '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Agent with explicit model: allowed silently" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","model":"sonnet","prompt":"x"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Agent without model (general-purpose): denied with a reason naming the rule" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}'
  [ "$status" -eq 0 ]
  denied
  echo "$output" | grep -q 'subagent-model-selection'
  echo "$output" | grep -q 'sonnet'
}

@test "Agent without model and without subagent_type: denied" {
  call '{"tool_name":"Agent","tool_input":{"prompt":"x"}}'
  denied
}

@test "Agent of a plugin-defined type without model: allowed (the definition carries the model)" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"casting:casting-specialist","prompt":"x"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fork: allowed when the shared budget mode is ok (no snapshot)" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"fork","prompt":"x"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "fork: denied when SHARED_BUDGET_MODE is throttled or depleted (explicit env)" {
  run env SHARED_BUDGET_MODE=throttled "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"fork","prompt":"x"}}'
  denied
  echo "$output" | grep -q 'throttled'
  run env SHARED_BUDGET_MODE=depleted "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"fork","prompt":"x"}}'
  denied
}

@test "fork: denied even when a model is passed (fork ignores model and inherits the parent)" {
  run env SHARED_BUDGET_MODE=depleted "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"fork","model":"sonnet","prompt":"x"}}'
  denied
}

@test "fork: weekly_all_pct above 90 is depleted even without a reset time in the snapshot" {
  echo '{"weekly_all_pct": 95}' > "${WORK}/snap.json"
  run env USAGE_SNAPSHOT="${WORK}/snap.json" "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"fork","prompt":"x"}}'
  denied
  echo "$output" | grep -q 'depleted'
}

@test "large payload: a multi-megabyte prompt is still judged (no ARG_MAX failure)" {
  big="$(head -c 3000000 /dev/zero | tr '\0' 'a')"
  printf '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"%s"}}' "$big" > "${WORK}/big.json"
  run "$SCRIPT" < "${WORK}/big.json"
  [ "$status" -eq 0 ]
  denied
}

@test "fork: derives throttled from the snapshot (weekly_all_pct above week-elapsed)" {
  now=1000000000
  resets=$(( now + 2 * 86400 ))   # 週経過 ≈ 71%
  cat > "${WORK}/snap.json" <<JSON
{ "schema": 1, "fetched_at": ${now}, "fable_weekly_pct": 30, "weekly_all_pct": 80,
  "weekly_resets_at": "iso", "weekly_resets_epoch": ${resets} }
JSON
  run env USAGE_SNAPSHOT="${WORK}/snap.json" USAGE_PROBE_NOW="$now" "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"fork","prompt":"x"}}'
  denied
  # 週経過より遅ければ ok
  sed -i.bak 's/"weekly_all_pct": 80/"weekly_all_pct": 40/' "${WORK}/snap.json"
  run env USAGE_SNAPSHOT="${WORK}/snap.json" USAGE_PROBE_NOW="$now" "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"fork","prompt":"x"}}'
  [ -z "$output" ]
}

@test "escape hatch: DEV_WORKFLOW_MODEL_GUARD=off allows everything" {
  run env DEV_WORKFLOW_MODEL_GUARD=off "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"prompt":"x"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "malformed stdin: fail-open (exit 0, no output)" {
  run "$SCRIPT" <<<'not json'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
