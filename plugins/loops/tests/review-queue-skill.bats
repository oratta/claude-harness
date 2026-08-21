#!/usr/bin/env bats
#
# Tests for capability: loops-review-queue の stale-wip（孤児 agent-wip）検出
# issue: oratta/claude-harness#155
#
# 何を守るテストか:
#   `agent-wip` は同一サイクル内の一時ラベル（plugins/loops/templates/agent-loop-template.md）で、
#   サイクル終了時に必ず外れる想定。しかしサイクル完了前にセッションが落ちると外れないまま残り、
#   templates/select-target.sh の実装モード選定（agent-ready ∧ ¬agent-wip）から永久に外れ、
#   review-queue の Step 3 フォールバック検索（agent-proposed / agent-blocked / needs-approval）
#   にも出てこない。この「見えない停止」を検出する記述が SKILL.md から消えないことを検査する。

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  SKILL="${PLUGIN_DIR}/skills/loops-review-queue/SKILL.md"
}

# Step 3（フォールバック検索）の本文だけを切り出す。
_step3_body() {
  awk '/^## Step 3:/{f=1;next} f&&/^## /{f=0} f{print}' "$SKILL"
}

# Step 4（優先順位付けと表示）の本文だけを切り出す。
_step4_body() {
  awk '/^## Step 4:/{f=1;next} f&&/^## /{f=0} f{print}' "$SKILL"
}

# 「してはならないこと」の本文だけを切り出す。
_forbidden_body() {
  awk '/^## してはならないこと/{f=1;next} f&&/^## /{f=0} f{print}' "$SKILL"
}

@test "S155-1: step 3 searches open issues labeled agent-wip" {
  _step3_body | grep -q 'agent-wip'
}

@test "S155-2: step 3 decides linked open PR via gh pr list in:body search" {
  body="$(_step3_body)"
  echo "$body" | grep -q 'gh pr list'
  echo "$body" | grep -q 'in:body'
  echo "$body" | grep -q -- '--state open'
}

@test "S155-3: step 3 computes staleness from updatedAt" {
  _step3_body | grep -q 'updatedAt'
}

@test "S155-4: staleness threshold is an env var with a default, not a hardcoded literal" {
  # レートガード（RATE_5H_MAX 等）と同じく環境変数 + 既定値の形にする
  _step3_body | grep -qE 'STALE_WIP_HOURS:-[0-9]+'
}

@test "S155-5: step 3 states the rationale for the threshold" {
  # 1 サイクル = 1h（loop-dev-agent の既定実行間隔）に対して十分長いこと、が根拠
  _step3_body | grep -q 'サイクル'
}

@test "S155-6: step 3 maps stale-wip into the label-to-State inference list" {
  _step3_body | grep -q 'stale-wip'
}

@test "S155-7: step 4 ranks stale-wip as an intervention-class row" {
  body="$(_step4_body)"
  echo "$body" | grep -q 'stale-wip'
  echo "$body" | grep -q '要介入'
}

@test "S155-8: skill stays read-only and forbids clearing agent-wip automatically" {
  _forbidden_body | grep -q 'agent-wip'
  grep -q '読み取り専用' "$SKILL"
}

@test "S155-9: issue #155 verification grep yields at least one hit" {
  run grep -c 'stale-wip\|agent-wip' "$SKILL"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
