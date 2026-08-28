#!/usr/bin/env bats
#
# loop-dev-agent-tripwires: 憲法テンプレートの昇格トリップワイヤー (#26 v2)
#
# 検証対象:
#   - agent-loop-template.md の Step 3 にトリップワイヤー3本（数値条件 + unmanned 写像）
#   - reserve 時の Opus 上限 + needs-approval 返し
#   - 配線側環境変数（LONGRUN_AUTOMATED / FABLE_BUDGET_MODE）の前提記載
#   - Workflow ツール直接操作の不在
#   - loops-dev-agent-install SKILL.md の env 解説
#
# spec: loop-dev-agent-tripwires

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TEMPLATE="${PLUGIN_DIR}/templates/agent-loop-template.md"
  INSTALL_SKILL="${PLUGIN_DIR}/skills/loops-dev-agent-install/SKILL.md"
}

@test "template: has tripwire section with three wires" {
  grep -q '昇格トリップワイヤー' "$TEMPLATE"
  grep -q '規模超過' "$TEMPLATE"
  grep -q '失敗ループ' "$TEMPLATE"
  grep -q '仕様の発明' "$TEMPLATE"
}

@test "template: tripwires use countable thresholds" {
  grep -Eq '5個を超え|5 個を超え' "$TEMPLATE"
  grep -q '2連続' "$TEMPLATE"
  grep -Eq '2回に達し|2 回に達し' "$TEMPLATE"
}

@test "template: reserve caps escalation at Opus and returns needs-approval" {
  grep -q 'FABLE_BUDGET_MODE=reserve' "$TEMPLATE"
  grep -Eq 'Opus.*上限' "$TEMPLATE"
  # ② の reserve 上限到達は needs-approval（agent-blocked ではない）
  grep -Eq 'Opus でも.*needs-approval' "$TEMPLATE"
}

@test "template: documents wiring-side env prerequisites" {
  grep -q 'LONGRUN_AUTOMATED=1' "$TEMPLATE"
  grep -q 'FABLE_BUDGET_MODE' "$TEMPLATE"
}

@test "template: tripwire actions do not invoke Workflow tool directly" {
  # トリップワイヤー節に「Workflow ツール」の直接操作指示が無い
  ! sed -n '/昇格トリップワイヤー/,/^### /p' "$TEMPLATE" | grep -q 'Workflow ツール'
}

@test "template: references dev-workflow escalation template" {
  grep -q 'escalation-tripwires' "$TEMPLATE"
}

@test "install-skill: documents LONGRUN_AUTOMATED / FABLE_BUDGET_MODE as wiring-side env" {
  grep -q 'LONGRUN_AUTOMATED' "$INSTALL_SKILL"
  grep -q 'FABLE_BUDGET_MODE' "$INSTALL_SKILL"
}

# --- #203: Step 3 の委譲先は develop、メインが develop の本体を務める ---

@test "template/recipe: github-issue no longer appears, develop is the delegate" {
  RECIPE="${PLUGIN_DIR}/recipes/loop-dev-agent.md"
  ! grep -q 'github-issue' "$TEMPLATE"
  ! grep -q 'github-issue' "$RECIPE"
  grep -q 'develop' "$TEMPLATE"
  grep -q '`develop`' "$RECIPE"
}

@test "template: Step 3 says main acts as develop's orchestrator and spawns W / R1 with --unmanned" {
  step3="$(awk '/^### Step 3/{f=1} /^### Step 4/{f=0} f' "$TEMPLATE")"
  echo "$step3" | grep -q 'メインが develop の本体'
  echo "$step3" | grep -qE 'W / R1.*spawn'
  echo "$step3" | grep -q -- '--unmanned'
  echo "$step3" | grep -q 'agent-review:pending'
  echo "$step3" | grep -qE 'G.*Step 1'
}

@test "template: dispatcher section no longer delegates Step 3 to a subagent" {
  disp="$(awk '/^## コンテキスト管理/{f=1} /^## ラベル定義/{f=0} f' "$TEMPLATE")"
  [ -n "$disp" ]
  ! echo "$disp" | grep -q 'Step 3 の実装'
  echo "$disp" | grep -q 'Step 3'
  echo "$disp" | grep -q 'develop'
}

@test "template: tripwire 1 routes W back to main for sub-issue split" {
  w1="$(sed -n '/昇格トリップワイヤー/,/^### /p' "$TEMPLATE" | grep '規模超過' | head -1)"
  echo "$w1" | grep -q '本体'
  echo "$w1" | grep -q 'return'
  ! echo "$w1" | grep -q 'workflow 型'
}

@test "template: env section points FABLE_BUDGET_MODE to develop's decision-criteria" {
  grep 'FABLE_BUDGET_MODE' "$TEMPLATE" | grep 'decision-criteria' | grep -q 'develop'
}

@test "plugin.json: description names develop and version is at least 0.25.0" {
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  jq -r '.description' "$MANIFEST" | grep -q 'develop'
  ! jq -r '.description' "$MANIFEST" | grep -q 'github-issue'
  printf '0.25.0\n%s\n' "$(jq -r .version "$MANIFEST")" | sort -V -C
}
