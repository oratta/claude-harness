#!/usr/bin/env bats
#
# agent-model-guard.sh: PreToolUse（Agent）で model 未指定の spawn を拒否する。
# 規範: rules/subagent-model-selection.md（model は必ず明示。fork は最上位ティアの仕事だけ）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/agent-model-guard.sh"
  WORK="$(mktemp -d)"
  # 共有枠の導出は active スロットの実効値（レジストリ・セッション記録・snapshot）を読むので、
  # 実環境の ~/.claude と実行中セッションのアカウントを読まないよう一時ディレクトリへ向ける
  export CLAUDE_ACCOUNTS_FILE="${WORK}/accounts.json"
  export USAGE_SESSIONS_DIR="${WORK}/.usage-sessions"
  export USAGE_PROBE_STATE="${WORK}/.usage-probe-state"
  export USAGE_PROBE_LOCK="${WORK}/.usage-probe.lock"
  unset CLAUDE_SECURESTORAGE_CONFIG_DIR
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

@test "new executor types reject Fable and worker accepts sonnet, opus and omitted model" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:worker","model":"fable","prompt":"x"}}'
  denied
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:gate-runner","model":"claude-fable-5-1","prompt":"x"}}'
  denied
  for payload in '{"model":"sonnet"}' '{"model":"opus"}' '{}'; do
    model_part="${payload#\{}"; model_part="${model_part%\}}"
    [ -z "$model_part" ] || model_part=",$model_part"
    call "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"dev-workflow:worker\",\"prompt\":\"x\"$model_part}}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "reviewer type rejects Fable and accepts sonnet, opus and omitted model" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:reviewer","model":"fable","prompt":"x"}}'
  denied
  for model_part in ',"model":"sonnet"' ',"model":"opus"' ''; do
    call "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"dev-workflow:reviewer\",\"prompt\":\"x\"$model_part}}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
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

@test "fork: weekly_all_pct above 90 is depleted even at the start of the week" {
  now=1000000000
  cat > "${WORK}/snap.json" <<JSON
{ "schema": 2, "accounts": { "default": { "fetched_at": ${now}, "weekly_all_pct": 95,
  "weekly_resets_epoch": $(( now + 7 * 86400 - 60 )) } } }
JSON
  run env USAGE_SNAPSHOT="${WORK}/snap.json" USAGE_PROBE_NOW="$now" "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"fork","prompt":"x"}}'
  denied
  echo "$output" | grep -q 'depleted'
}

@test "fork: the shared mode comes from the active slot's session record without a snapshot" {
  now=1000000000
  mkdir -p "$USAGE_SESSIONS_DIR"
  printf '{"schema":1,"key":"default","observed_at":%s,"five_hour_pct":10,"five_hour_resets_epoch":null,"weekly_all_pct":95,"weekly_resets_epoch":%s}\n' \
    "$((now - 60))" "$((now + 2 * 86400))" > "${USAGE_SESSIONS_DIR}/default.json"
  run env USAGE_SNAPSHOT="${WORK}/none.json" USAGE_PROBE_NOW="$now" "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"fork","prompt":"x"}}'
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
{ "schema": 2, "accounts": { "default": { "fetched_at": ${now}, "fable_weekly_pct": 30,
  "weekly_all_pct": 80, "weekly_resets_at": "iso", "weekly_resets_epoch": ${resets} } } }
JSON
  run env USAGE_SNAPSHOT="${WORK}/snap.json" USAGE_PROBE_NOW="$now" "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"fork","prompt":"x"}}'
  denied
  # 週経過より遅ければ ok
  sed -i.bak 's/"weekly_all_pct": 80,/"weekly_all_pct": 40,/' "${WORK}/snap.json"
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

# ===== Fable は決める役の種別でだけ spawn できる（issue #250） =====

@test "fable: general-purpose with model fable is denied, naming the decider type and the alternatives" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","model":"fable","prompt":"x"}}'
  [ "$status" -eq 0 ]
  denied
  echo "$output" | grep -q 'dev-workflow:decider'
  echo "$output" | grep -q 'sonnet'
  echo "$output" | grep -q 'opus'
  echo "$output" | grep -q 'subagent-model-selection'
}

@test "fable: the full model id (claude-fable-*) is denied the same way" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","model":"claude-fable-5-1","prompt":"x"}}'
  denied
  echo "$output" | grep -q 'dev-workflow:decider'
}

@test "fable: case and surrounding spaces do not slip through" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","model":" Fable ","prompt":"x"}}'
  denied
}

@test "fable: denied for a missing subagent_type, Explore, Plan and other plugin types" {
  call '{"tool_name":"Agent","tool_input":{"model":"fable","prompt":"x"}}'
  denied
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"Explore","model":"fable","prompt":"x"}}'
  denied
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"Plan","model":"fable","prompt":"x"}}'
  denied
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"casting:casting-arbiter","model":"fable","prompt":"x"}}'
  denied
}

@test "fable: dev-workflow:decider with model fable is allowed silently" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:decider","model":"fable","prompt":"x"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "decider: opus and an omitted model are allowed (the type is fixed, only the model changes)" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:decider","model":"opus","prompt":"x"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:decider","prompt":"x"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "non-fable models on general-purpose keep passing" {
  for m in opus sonnet haiku; do
    call "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"general-purpose\",\"model\":\"$m\",\"prompt\":\"x\"}}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "escape hatch: DEV_WORKFLOW_MODEL_GUARD=off also allows fable on general-purpose" {
  run env DEV_WORKFLOW_MODEL_GUARD=off "$SCRIPT" <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","model":"fable","prompt":"x"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "model-unspecified denial no longer advertises fable for the four classifications" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}'
  denied
  ! echo "$output" | grep -q 'fable（最終 verify' || return 1
  echo "$output" | grep -q 'dev-workflow:decider'
}

# ===== 実行役の種別は対応表の上限を超える格で起こせない（#615） =====

@test "role cap: worker with fable is denied naming the roles, the tiers and the decider type" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:worker","model":"fable","prompt":"x"}}'
  [ "$status" -eq 0 ]
  denied
  for word in 'spec-write' 'implement' '最上位' '上位' 'dev-workflow:decider' 'role_caps' 'subagent-model-selection'; do
    echo "$output" | grep -q -- "$word"
  done
}

@test "role cap: gate-runner with the full Fable id is denied naming implement and the tiers" {
  call '{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:gate-runner","model":"claude-fable-5-1","prompt":"x"}}'
  denied
  for word in 'implement' '最上位' '上位' 'role_caps'; do
    echo "$output" | grep -q -- "$word"
  done
}

@test "role cap: worker with haiku, sonnet, opus, an unknown name or no model passes" {
  for model_part in ',"model":"haiku"' ',"model":"sonnet"' ',"model":"opus"' ',"model":"fabel"' ''; do
    call "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"dev-workflow:worker\",\"prompt\":\"x\"$model_part}}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

copy_plugin() {  # $1 = destination; copies scripts and references, the table the guard reads
  mkdir -p "$1"
  cp -R "${PLUGIN_DIR}/scripts" "${PLUGIN_DIR}/references" "$1/"
}

@test "role cap: a broken table skips the cap check, so worker fable is still denied by the Fable check and opus passes" {
  copy_plugin "${WORK}/copy"
  echo '{not json' > "${WORK}/copy/references/model-tier-map.json"
  run env USAGE_SNAPSHOT="${WORK}/none.json" "${WORK}/copy/scripts/agent-model-guard.sh" \
    <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:worker","model":"fable","prompt":"x"}}'
  denied
  ! echo "$output" | grep -q 'role_caps' || return 1
  echo "$output" | grep -q 'dev-workflow:decider'
  run env USAGE_SNAPSHOT="${WORK}/none.json" "${WORK}/copy/scripts/agent-model-guard.sh" \
    <<<'{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:worker","model":"opus","prompt":"x"}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "role cap: lowering the cap in one table changes both the guard and codex-develop.py request" {
  copy_plugin "${WORK}/copy"
  python3 - "${WORK}/copy/references/model-tier-map.json" <<'PY'
import json, sys
path = sys.argv[1]
table = json.load(open(path, encoding='utf-8'))
table['role_caps'] = {'spec-write': '中位', 'implement': '中位'}
json.dump(table, open(path, 'w', encoding='utf-8'), ensure_ascii=False)
PY
  repo="${WORK}/repo"
  git init -q "$repo"
  git -C "$repo" -c user.name=Test -c user.email=test@example.invalid commit --allow-empty -qm fixture
  echo 'Do only this phase.' > "${WORK}/input.txt"
  worker_opus='{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:worker","model":"opus","prompt":"x"}}'
  request() {  # $1 = plugin dir whose codex-develop.py is run
    run env CLAUDE_CONFIG_DIR="$WORK" USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json" \
      FABLE_BUDGET_MODE=abundant SHARED_BUDGET_MODE=ok \
      python3 "$1/scripts/codex-develop.py" request --profile claude-default --phase implement \
      --pre-class contract --input "${WORK}/input.txt" --cwd "$repo" --out "${WORK}/request-$2.json"
  }

  # The bundled table lets both through.
  run env USAGE_SNAPSHOT="${WORK}/none.json" FABLE_BUDGET_MODE=abundant SHARED_BUDGET_MODE=ok "$SCRIPT" <<<"$worker_opus"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  request "$PLUGIN_DIR" bundled
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '上位'

  # The lowered copy refuses both.
  run env USAGE_SNAPSHOT="${WORK}/none.json" FABLE_BUDGET_MODE=abundant SHARED_BUDGET_MODE=ok \
    "${WORK}/copy/scripts/agent-model-guard.sh" <<<"$worker_opus"
  denied
  echo "$output" | grep -q '中位'
  request "${WORK}/copy" copy
  [ "$status" -ne 0 ]
  for word in 'implement' '上位' '中位'; do
    echo "$output" | grep -q -- "$word"
  done
}
