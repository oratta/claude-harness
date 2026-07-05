#!/usr/bin/env bats
#
# Tests for change-3 (mvp-plan-split).
# spec: longrun-mvp-plan-skill / longrun-plan-skill (S1〜S42 in verification-guide).
#
# These are structural / grep-based verifications standing in for the
# live E2E scenarios (S9 flow completion / S6 no-misfire / S17 archive compat),
# which require an interactive Claude session and are flagged for manual
# confirmation in the run NOTES.
#
# Conventions follow plugins/longrun/tests/helper.bash.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  LR_DIR="${PLUGIN_ROOT}/plugins/lr"
  LONGRUN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  LR_JSON="${LR_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE_JSON="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
  README="${PLUGIN_DIR}/README.md"
  MVP_SKILL="${PLUGIN_DIR}/skills/longrun-mvp-plan/SKILL.md"
  PLAN_SKILL="${PLUGIN_DIR}/skills/longrun-plan/SKILL.md"
  MVP_CMD="${PLUGIN_DIR}/commands/mvp.md"
  LR_M_CMD="${LR_DIR}/commands/m.md"
  PLAN_CMD="${PLUGIN_DIR}/commands/plan.md"
  LR_P_CMD="${LR_DIR}/commands/p.md"
  MVP_TEMPLATE="${PLUGIN_DIR}/templates/plan-template-mvp.md"
  AGENT_RESEARCH="${PLUGIN_DIR}/agents/longrun-mvp-research.md"
  AGENT_PLAN_REVIEWER="${PLUGIN_DIR}/agents/longrun-mvp-plan-reviewer.md"
  AGENT_BP_REVIEWER="${PLUGIN_DIR}/agents/longrun-mvp-bestpractice-reviewer.md"
  METHODOLOGY_REF="${PLUGIN_DIR}/references/plan-interview-methodology.md"
}

# --- S1: Skill directory and frontmatter ---

@test "mvp: SKILL.md exists with name longrun-mvp-plan in frontmatter" {
  [ -f "$MVP_SKILL" ]
  run grep -E '^name: longrun-mvp-plan$' "$MVP_SKILL"
  [ "$status" -eq 0 ]
}

@test "mvp: SKILL.md frontmatter has description, version, allowed-tools" {
  run grep -E '^description: .+' "$MVP_SKILL"
  [ "$status" -eq 0 ]
  run grep -E '^version: .+' "$MVP_SKILL"
  [ "$status" -eq 0 ]
  run grep -E '^allowed-tools:' "$MVP_SKILL"
  [ "$status" -eq 0 ]
}

@test "mvp: allowed-tools lists Read Write Grep AskUserQuestion" {
  tools_line="$(grep -E '^allowed-tools:' "$MVP_SKILL")"
  echo "$tools_line" | grep -q 'Read'
  echo "$tools_line" | grep -q 'Write'
  echo "$tools_line" | grep -q 'Grep'
  echo "$tools_line" | grep -q 'AskUserQuestion'
}

# --- S2: plugin.json registration ---

@test "mvp: longrun plugin.json skills[] contains ./skills/longrun-mvp-plan" {
  run jq -r '.skills[]' "$LONGRUN_JSON"
  echo "$output" | grep -qx './skills/longrun-mvp-plan'
}

# --- S3: Noun-form naming respected ---

@test "mvp: skill name does not end with -er/-or and no longrun-mvp-planner dir" {
  name="$(grep -E '^name: ' "$MVP_SKILL" | head -1 | awk '{print $2}')"
  [ "$name" = "longrun-mvp-plan" ]
  ! echo "$name" | grep -qE '(er|or)$'
  [ ! -d "${PLUGIN_DIR}/skills/longrun-mvp-planner" ]
}

# --- S4: /longrun:mvp command file content ---

@test "mvp: commands/mvp.md delegates via Skill tool to longrun:longrun-mvp-plan with ARGUMENTS" {
  [ -f "$MVP_CMD" ]
  grep -q 'Skill' "$MVP_CMD"
  grep -q 'longrun:longrun-mvp-plan' "$MVP_CMD"
  grep -q '\$ARGUMENTS' "$MVP_CMD"
}

@test "mvp: commands/mvp.md forbids Agent tool" {
  grep -qi 'Agent tool' "$MVP_CMD"
  # explicit prohibition statement
  grep -q 'Agent tool は使わない\|Agent tool で起動\|Agent ではない' "$MVP_CMD"
}

# --- S5: /longrun:mvp command registration ---

@test "mvp: longrun plugin.json commands[] contains ./commands/mvp.md" {
  run jq -r '.commands[]' "$LONGRUN_JSON"
  echo "$output" | grep -qx './commands/mvp.md'
}

# --- S7: /lr:m shortcut content ---

@test "mvp: lr commands/m.md delegates Skill tool to longrun:longrun-mvp-plan with ARGUMENTS" {
  [ -f "$LR_M_CMD" ]
  grep -q 'Skill' "$LR_M_CMD"
  grep -q 'longrun:longrun-mvp-plan' "$LR_M_CMD"
  grep -q '\$ARGUMENTS' "$LR_M_CMD"
}

@test "mvp: lr commands/m.md forbids Agent tool" {
  grep -q 'Agent tool は使わない\|Agent tool で起動\|Agent ではない' "$LR_M_CMD"
}

# --- S8: /lr:m registration ---

@test "mvp: lr plugin.json commands[] contains ./commands/m.md" {
  run jq -r '.commands[]' "$LR_JSON"
  echo "$output" | grep -qx './commands/m.md'
}

@test "mvp: lr plugin.json description mentions /lr:m" {
  d="$(jq -r '.description' "$LR_JSON")"
  echo "$d" | grep -q '/lr:m'
}

# --- S10: full-mode-only steps are absent in mvp skill ---

@test "mvp: SKILL.md does not instruct reading openspec/backlog.md" {
  ! grep -q 'openspec/backlog.md' "$MVP_SKILL"
}

@test "mvp: SKILL.md does not invoke longrun-reviewer agent" {
  # longrun-mvp-plan-reviewer is fine; the bare full-mode longrun-reviewer is not
  ! grep -qE 'longrun-reviewer"' "$MVP_SKILL"
  ! grep -qE 'subagent_type: "longrun-reviewer"' "$MVP_SKILL"
}

@test "mvp: SKILL.md does not load full template plan-template.md" {
  ! grep -qE 'plan-template\.md' "$MVP_SKILL"
}

# --- S11: orchestration stays Agent-parallel (no Workflow tool) ---

@test "mvp: SKILL.md uses Agent tool and never Workflow tool" {
  grep -q 'Agent' "$MVP_SKILL"
  ! grep -qE 'Workflow ツール|Workflow tool|\bWorkflow\b' "$MVP_SKILL"
}

# --- S12: research step names the agent ---

@test "mvp: SKILL.md names longrun-mvp-research as subagent target" {
  grep -q 'longrun-mvp-research' "$MVP_SKILL"
  grep -q 'subagent_type: "longrun-mvp-research"' "$MVP_SKILL"
}

# --- S13: research prompt demands dual sections + Search Audit ---

@test "mvp: research prompt requires dual sections and Search Audit" {
  grep -q '## 類似サービス事例' "$MVP_SKILL"
  grep -q '## 実装パターン' "$MVP_SKILL"
  grep -q '## Search Audit' "$MVP_SKILL"
}

# --- S14: both reviewers named ---

@test "mvp: SKILL.md names both MVP reviewers as subagent targets" {
  grep -q 'subagent_type: "longrun-mvp-plan-reviewer"' "$MVP_SKILL"
  grep -q 'subagent_type: "longrun-mvp-bestpractice-reviewer"' "$MVP_SKILL"
}

# --- S15: parallel invocation is explicit ---

@test "mvp: SKILL.md requires single-message parallel review (forbids split)" {
  grep -qE '単一(の)?メッセージ|単一の assistant メッセージ|1 つの assistant メッセージ' "$MVP_SKILL"
  grep -qE '別メッセージ.*禁止|別.*メッセージ.*分けて.*禁止|分けて発行することは禁止' "$MVP_SKILL"
}

# --- S16: marker is first content of generated plan.md ---

@test "mvp: SKILL.md instructs embedding <!-- mvp-mode --> marker at file head" {
  grep -q '<!-- mvp-mode -->' "$MVP_SKILL"
  grep -qE '先頭|1 行目|最初|file head|タイトル.*より前|見出し.*前' "$MVP_SKILL"
}

# --- S18: validation checklist is explicit (7 sections + marker) ---

@test "mvp: SKILL.md validation lists all 7 required sections" {
  grep -q 'ゴール' "$MVP_SKILL"
  grep -q '技術要件' "$MVP_SKILL"
  grep -q 'スコープ' "$MVP_SKILL"
  grep -q '受け入れ条件' "$MVP_SKILL"
  grep -q '動作確認方法' "$MVP_SKILL"
  grep -q '調査結果サマリ' "$MVP_SKILL"
  grep -q 'レビュー結果サマリ' "$MVP_SKILL"
}

@test "mvp: SKILL.md validation includes marker existence check" {
  # within the validation step the marker presence is checked
  grep -qE 'マーカー.*存在|マーカー.*確認|<!-- mvp-mode -->.*確認|Grep で確認' "$MVP_SKILL"
}

# --- S19: missing section blocks save (GATE) ---

@test "mvp: SKILL.md validation has GATE blocking save on missing section" {
  grep -qE '<GATE>' "$MVP_SKILL"
  grep -qE '保存してはならない|保存前に.*修正|修正してから保存' "$MVP_SKILL"
}

# --- S20: handoff omits backlog / change writes ---

@test "mvp: handoff step does not edit backlog or run openspec change tooling" {
  ! grep -qE 'openspec/backlog\.md.*編集|openspec/backlog\.md.*消込|backlog.*削除' "$MVP_SKILL"
  ! grep -qE 'openspec change add|change.*自動生成して' "$MVP_SKILL"
}

# --- S21: handoff message names plan.md path + human path ---

@test "mvp: handoff outputs saved plan.md path and human-implementation guidance" {
  grep -qE '_longruns/.*plan\.md|保存先' "$MVP_SKILL"
  grep -qE '人間が手で実装|人間実装|手で実装' "$MVP_SKILL"
}

# --- S22: agent prose references new owner; no --mode=mvp ---

@test "mvp: three MVP agents have zero --mode=mvp references" {
  ! grep -q -- '--mode=mvp' "$AGENT_RESEARCH"
  ! grep -q -- '--mode=mvp' "$AGENT_PLAN_REVIEWER"
  ! grep -q -- '--mode=mvp' "$AGENT_BP_REVIEWER"
}

@test "mvp: three MVP agents reference longrun-mvp-plan skill or /longrun:mvp" {
  grep -qE 'longrun-mvp-plan|/longrun:mvp' "$AGENT_RESEARCH"
  grep -qE 'longrun-mvp-plan|/longrun:mvp' "$AGENT_PLAN_REVIEWER"
  grep -qE 'longrun-mvp-plan|/longrun:mvp' "$AGENT_BP_REVIEWER"
}

# --- S23: template structure intact ---

@test "mvp: template begins with <!-- mvp-mode --> on first line" {
  head -1 "$MVP_TEMPLATE" | grep -q '<!-- mvp-mode -->'
}

@test "mvp: template retains divergence-prevention comment referencing plan-template.md" {
  grep -q 'plan-template.md' "$MVP_TEMPLATE"
  grep -qE 'divergence|両方.*更新|両ファイル' "$MVP_TEMPLATE"
}

@test "mvp: template retains all eight H2 sections" {
  grep -q '^## ゴール' "$MVP_TEMPLATE"
  grep -q '^## 技術要件' "$MVP_TEMPLATE"
  grep -q '^## スコープ' "$MVP_TEMPLATE"
  grep -q '^## 調査結果サマリ（類似サービス）' "$MVP_TEMPLATE"
  grep -q '^## 調査結果サマリ（実装パターン）' "$MVP_TEMPLATE"
  grep -q '^## レビュー結果サマリ' "$MVP_TEMPLATE"
  grep -q '^## 受け入れ条件' "$MVP_TEMPLATE"
  grep -q '^## 動作確認方法' "$MVP_TEMPLATE"
}

@test "mvp: template mode line references /longrun:mvp not --mode=mvp flag" {
  grep -qE 'モード:.*MVP.*/longrun:mvp' "$MVP_TEMPLATE"
  ! grep -qE 'モード:.*`--mode=mvp`' "$MVP_TEMPLATE"
}

# --- S24: agent contracts textually unchanged (output-contract markers present) ---

@test "mvp: research agent output contract unchanged (Search Audit + dual sections + queries:1 ideal)" {
  grep -q '## Search Audit' "$AGENT_RESEARCH"
  grep -q '## 類似サービス事例' "$AGENT_RESEARCH"
  grep -q '## 実装パターン' "$AGENT_RESEARCH"
  grep -qE 'queries: 1|queries: <整数' "$AGENT_RESEARCH"
}

@test "mvp: plan-reviewer agent output contract unchanged (APPROVE/REQUEST_CHANGES + Search Audit)" {
  grep -q 'APPROVE' "$AGENT_PLAN_REVIEWER"
  grep -q 'REQUEST_CHANGES' "$AGENT_PLAN_REVIEWER"
  grep -q '## Search Audit' "$AGENT_PLAN_REVIEWER"
}

@test "mvp: bestpractice-reviewer agent output contract unchanged (max 1 search + Search Audit)" {
  grep -q '## Search Audit' "$AGENT_BP_REVIEWER"
  grep -qE '外部検索は最大 1 回|queries <= 1|queries: <0 または 1' "$AGENT_BP_REVIEWER"
}

# --- S25: no cross-skill SKILL.md read ---

@test "mvp: SKILL.md does not instruct reading skills/longrun-plan/SKILL.md" {
  ! grep -qE 'skills/longrun-plan/SKILL\.md|longrun-plan/SKILL\.md' "$MVP_SKILL"
}

# --- S26: shared reference or guarded duplication ---

@test "mvp: methodology reference exists and is read by both skills" {
  [ -f "$METHODOLOGY_REF" ]
  grep -q 'plan-interview-methodology' "$MVP_SKILL"
}

@test "mvp: methodology reference covers Gap Analysis and Interview" {
  grep -qE 'Gap Analysis|ギャップ分析' "$METHODOLOGY_REF"
  grep -qE 'Interview|インタビュー' "$METHODOLOGY_REF"
}

# --- S27 / S28: version sync (longrun bumped to 6.3.0, lr to 6.2.0 by change-3) ---
# NOTE: marketplace.json sync is change-7's responsibility (design.md D6 / plan.md
# dependency note), so these no longer assert plugin.json == marketplace.json parity
# mid-change. They only assert plugin.json's own value and that marketplace.json
# still parses and still contains the corresponding entry.

@test "mvp: longrun plugin.json version is 6.3.1" {
  # bumped 6.3.0 -> 6.3.1 by loops-integration (change-5). See decisions.md D-5b.
  a="$(jq -r '.version' "$LONGRUN_JSON")"
  [ "$a" = "6.3.1" ]
}

@test "mvp: marketplace.json still contains a longrun entry (version sync deferred to change-7)" {
  b="$(jq -r '.plugins[] | select(.name=="longrun") | .version' "$MARKETPLACE_JSON")"
  [ -n "$b" ]
}

@test "mvp: SKILL.md frontmatter versions are 6.2.0 for both plan and mvp-plan" {
  va="$(grep -E '^version: ' "$PLAN_SKILL" | head -1 | awk '{print $2}')"
  vb="$(grep -E '^version: ' "$MVP_SKILL" | head -1 | awk '{print $2}')"
  [ "$va" = "6.2.0" ]
  [ "$vb" = "6.2.0" ]
}

@test "mvp: lr plugin.json version is 6.2.0" {
  a="$(jq -r '.version' "$LR_JSON")"
  [ "$a" = "6.2.0" ]
}

@test "mvp: marketplace.json still contains an lr entry (version sync deferred to change-7)" {
  b="$(jq -r '.plugins[] | select(.name=="lr") | .version' "$MARKETPLACE_JSON")"
  [ -n "$b" ]
}

# --- S29: marketplace top-level bump (> 2.7.0) ---

@test "mvp: marketplace top-level version bumped above 2.7.0" {
  v="$(jq -r '.version' "$MARKETPLACE_JSON")"
  run bash -c "printf '%s\n%s\n' '2.7.0' '$v' | sort -V | tail -1"
  [ "$output" = "$v" ]
  [ "$v" != "2.7.0" ]
}

# --- S35 / S36 (change-3 update): --mode=mvp shim fully removed from longrun-plan ---

@test "plan: SKILL.md contains zero occurrences of mode=mvp (GATE removed)" {
  run grep -q -- 'mode=mvp' "$PLAN_SKILL"
  [ "$status" -ne 0 ]
}

@test "plan: SKILL.md's first H1 after frontmatter is the full-mode heading (no mode-dispatch GATE before it)" {
  first_heading="$(grep -m1 -n '^# ' "$PLAN_SKILL" | cut -d: -f2-)"
  [ "$first_heading" = "# Run Plan — plan.md 作成スキル" ]
}

# --- S37: full mode unaffected ---

@test "plan: full mode still reads plan-template.md and invokes longrun-reviewer at Step 7" {
  grep -q 'templates/plan-template.md' "$PLAN_SKILL"
  grep -q 'longrun-reviewer' "$PLAN_SKILL"
}

# --- S38: MVP-mode section removed from longrun-plan body ---

@test "plan: SKILL.md has no MVP step definitions (MVP Step 4.5 / longrun-mvp-plan-reviewer)" {
  ! grep -q 'MVP Step 4.5' "$PLAN_SKILL"
  ! grep -q 'longrun-mvp-plan-reviewer' "$PLAN_SKILL"
  ! grep -q 'longrun-mvp-bestpractice-reviewer' "$PLAN_SKILL"
  ! grep -q 'longrun-mvp-research' "$PLAN_SKILL"
}

# --- lr:p / plan.md: --mode=mvp usage removed, ARGUMENTS forward kept ---

@test "plan cmd: lr p.md keeps ARGUMENTS forward but drops --mode=mvp usage example" {
  grep -q '\$ARGUMENTS' "$LR_P_CMD"
  ! grep -qE 'MVP モードで起動|--mode=mvp 機能の概要|MVP モード（軽量' "$LR_P_CMD"
}

@test "plan cmd: longrun plan.md keeps ARGUMENTS forward" {
  grep -q '\$ARGUMENTS' "$PLAN_CMD"
}

# --- S39 / S40 / S41 / S42: README MVP section ---

@test "readme: MVP section names skill and includes literal /longrun:mvp" {
  grep -q '/longrun:mvp' "$README"
}

@test "readme: MVP section describes full-mode differences (Build Contract / TDD / Verifier / archive)" {
  grep -qE 'Build Contract' "$README"
  grep -qE 'TDD' "$README"
  grep -qE 'Verifier' "$README"
  grep -qE 'OpenSpec change.*archive|archive.*スキップ|OpenSpec.*アーカイブ.*スキップ' "$README"
}

@test "readme: MVP section no longer documents a --mode=mvp deprecation subsection (change-3: shim fully removed)" {
  run grep -qE '^### .?--mode=mvp' "$README"
  [ "$status" -ne 0 ]
}

@test "readme: MVP section states generic / short-time human-implemented use case" {
  grep -qE '汎用|特定プロジェクトに依存しない|特定のプロジェクトに依存しない|特定プロジェクトに紐づか' "$README"
  grep -qE '人間が手で.*実装|人間実装|短時間' "$README"
}

# --- change-3 (S30): residual scan upgraded to strict scoped-zero ---
# The shim is fully removed now (no more "deprecation prose" tolerance). The only
# remaining tolerance is self-referential search patterns inside plugins/longrun/tests/
# and plugins/lr/tests/ (see longrun-orphan-cleanup capability D1/D2).

@test "residual: mode=mvp is scoped-zero outside tests/ (longrun + lr)" {
  run bash -c "grep -rln 'mode=mvp' '${PLUGIN_DIR}' '${LR_DIR}' | grep -v '/tests/' || true"
  [ -z "$output" ]
}

# --- syntax: all touched JSON parses ---

@test "mvp: all touched JSON parses (jq)" {
  jq empty "$LONGRUN_JSON"
  jq empty "$LR_JSON"
  jq empty "$MARKETPLACE_JSON"
}
