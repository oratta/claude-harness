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
