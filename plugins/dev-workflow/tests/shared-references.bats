#!/usr/bin/env bats
#
# dev-workflow プラグイン直下 references/ に置く共有契約 4 本の構造検証（issue #205）
#
# spec: dev-workflow-shared-references
#
# reference は実行コードではないため、規定の記述が存在することを grep で検証する。
# テスト名は ASCII のみ。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  REFS="${PLUGIN_DIR}/references"
  SELFV="${REFS}/self-verification.md"
  PRBODY="${REFS}/pr-body-format.md"
  TIERS="${REFS}/model-tiers.md"
  WFEXEC="${REFS}/workflow-execution.md"
  README="${PLUGIN_DIR}/README.md"
  TRIPWIRES="${PLUGIN_DIR}/templates/escalation-tripwires.md"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  RULE="${REPO_ROOT}/rules/subagent-model-selection.md"
  CONSUMERS=(
    "plugins/infra/skills/infra-setup/SKILL.md"
    "plugins/weekly-report/skills/weekly-report/SKILL.md"
    "plugins/daily-report/skills/daily-report/SKILL.md"
    "plugins/experience-to-skill/skills/experience-to-skill/SKILL.md"
    "plugins/worktree/skills/wt-setup/SKILL.md"
    "plugins/worktree/skills/wt-clean/SKILL.md"
    "plugins/worktree/references/wt-clean-verification.md"
    "plugins/dev-workflow/skills/push-guard-setup/SKILL.md"
  )
}

# --- Requirement: 共有契約はプラグイン直下 references/ に置く ---

@test "the four shared contracts exist under plugins/dev-workflow/references" {
  [ -f "$SELFV" ]
  [ -f "$PRBODY" ]
  [ -f "$TIERS" ]
  [ -f "$WFEXEC" ]
}

@test "plugin README has a references section naming all four files" {
  grep -qE '^##+ .*references/' "$README"
  for f in self-verification.md pr-body-format.md model-tiers.md workflow-execution.md; do
    grep -q "$f" "$README" || { echo "README does not mention ${f}"; return 1; }
  done
}

# --- Requirement: 自己検証の共通原則は解散プラグインの記述を除いて引き継ぐ ---

@test "self-verification keeps the core principle and the four evidence kinds" {
  grep -q '完了は主張であり証明ではない' "$SELFV"
  grep -q 'evidence を提示してから完了を宣言する' "$SELFV"
  grep -q 'テスト出力' "$SELFV"
  grep -q 'exit code' "$SELFV"
  grep -q '生成物の実在' "$SELFV"
  grep -q '実行結果ログ' "$SELFV"
}

@test "self-verification authoring rule points skills at the new path" {
  grep -qF 'plugins/dev-workflow/references/self-verification.md' "$SELFV"
  ! grep -q 'plugins/loops/' "$SELFV"
  ! grep -q 'plugins/longrun/' "$SELFV"
}

@test "self-verification audit list has the seven live skills and no retired ones" {
  grep -q '対象スキル一覧' "$SELFV"
  for p in \
    "plugins/worktree/skills/wt-setup/SKILL.md" \
    "plugins/worktree/skills/wt-clean/SKILL.md" \
    "plugins/daily-report/skills/daily-report/SKILL.md" \
    "plugins/weekly-report/skills/weekly-report/SKILL.md" \
    "plugins/infra/skills/infra-setup/SKILL.md" \
    "plugins/experience-to-skill/skills/experience-to-skill/SKILL.md" \
    "plugins/dev-workflow/skills/push-guard-setup/SKILL.md"; do
    grep -qF "$p" "$SELFV" || { echo "missing ${p}"; return 1; }
  done
  ! grep -q 'longrun-plan\|loops-design\|loops-goalify\|longrun-feedback\|longrun-mvp' "$SELFV"
}

@test "all eight consumers reference the new self-verification path and none the old" {
  for rel in "${CONSUMERS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    grep -qF 'plugins/dev-workflow/references/self-verification.md' "$f" || { echo "${rel} lacks new path"; return 1; }
    if grep -qF 'plugins/loops/references/self-verification.md' "$f"; then echo "${rel} still has old path"; return 1; fi
  done
}

# --- Requirement: PR / issue 本文の型は内容を維持して引き継ぐ ---
# （5 セクション・設計原則・軽量モード等の詳細は pr-body-format.bats が担う）

@test "pr-body-format names issueify's new path as the generation source and no retired paths" {
  grep -qF 'plugins/dev-workflow/skills/issueify/SKILL.md' "$PRBODY"
  ! grep -q 'loops-issueify\|loops-dev-agent-install\|agent-loop-template' "$PRBODY"
}

# --- Requirement: モデルティアはロール別の対応表と降格規則だけを引き継ぐ ---

@test "model-tiers has the four-tier table with alias values" {
  grep -qE '^\|.*`haiku`' "$TIERS"
  grep -qE '^\|.*`sonnet`' "$TIERS"
  grep -qE '^\|.*`fable`' "$TIERS"
  grep -qE '^\|.*`inherit`' "$TIERS"
  grep -q 'エイリアス' "$TIERS"
  grep -q 'opts.model' "$TIERS"
}

@test "model-tiers explains inherit as omitting the opts.model key" {
  grep -qE 'inherit.*(省略|渡さない)' "$TIERS"
}

@test "model-tiers keeps the budget-mode demotion and points at decision-criteria" {
  grep -q 'FABLE_BUDGET_MODE' "$TIERS"
  grep -q 'reserve' "$TIERS"
  grep -q 'exhausted' "$TIERS"
  grep -q 'decision-criteria.md' "$TIERS"
}

@test "model-tiers carries no longrun-specific machinery" {
  ! grep -q 'LONGRUN' "$TIERS"
  ! grep -q 'resolve-model-allocation' "$TIERS"
  ! grep -q 'plan.md\|plan-template' "$TIERS"
}

@test "rules/subagent-model-selection points at model-tiers in one line without growing" {
  grep -qF 'plugins/dev-workflow/references/model-tiers.md' "$RULE"
  ! grep -q 'plugins/longrun/' "$RULE"
  [ "$(grep -cF 'plugins/dev-workflow/references/model-tiers.md' "$RULE")" = "1" ]
  [ "$(wc -l < "$RULE" | tr -d ' ')" -le 43 ]
}

# --- Requirement: Workflow 実行の型を 1 ファイルで定める ---

@test "workflow-execution describes the three phases and the Build Contract review" {
  grep -q 'Review' "$WFEXEC"
  grep -q 'Build' "$WFEXEC"
  grep -q 'Verify' "$WFEXEC"
  grep -q 'meta.phases' "$WFEXEC"
  grep -q 'Build Contract' "$WFEXEC"
}

@test "workflow-execution keeps the verifier posture with thresholds and schema reports" {
  grep -q '100%' "$WFEXEC"
  grep -q '80%' "$WFEXEC"
  grep -q 'schema' "$WFEXEC"
  grep -qE 'FAIL' "$WFEXEC"
}

@test "workflow-execution defers to workflow-authoring and model-tiers, and mentions resumeFromRunId" {
  grep -q 'workflow-authoring' "$WFEXEC"
  grep -q 'model-tiers.md' "$WFEXEC"
  grep -q 'resumeFromRunId' "$WFEXEC"
}

@test "workflow-execution has no longrun exec or plan.md leftovers" {
  ! grep -qF '/lr:e' "$WFEXEC"
  ! grep -q 'longrun:exec' "$WFEXEC"
  ! grep -q 'plan.md' "$WFEXEC"
}

@test "tripwires and develop SKILL.md route large work to workflow-execution instead of /lr:e" {
  grep -q 'workflow-execution.md' "$TRIPWIRES"
  grep -q 'workflow-execution.md' "$SKILL"
  ! grep -qF '/lr:' "$TRIPWIRES"
  ! grep -qF '/lr:' "$SKILL"
  ! grep -q 'longrun' "$SKILL"
}
