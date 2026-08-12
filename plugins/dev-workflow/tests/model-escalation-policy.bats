#!/usr/bin/env bats
#
# 実装モデルのエスカレーションポリシー（issue #84）
#
# 「レビュー不合格の修正・重要実装（聖域/マージ権限/層間契約/課金・法務）は Fable 担当」という
# 運用判断を、セッション内の心がけから dev-workflow の機械的ルールへ昇格させたもの。
# 正本の置き場所が1箇所であること（重複記述を作らないこと）も検証する。
#
# spec: dev-workflow-model-escalation-policy

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  ISSUE_SKILL="${PLUGIN_DIR}/skills/github-issue/SKILL.md"
  GATE_SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

# --- ルール1: 事前分類（1周目から Fable）は github-issue の Step D にある ---

@test "pre-classification: section lives in github-issue Step D" {
  grep -qF '重要実装の事前分類' "$ISSUE_SKILL"
  sec="$(grep -n '重要実装の事前分類' "$ISSUE_SKILL" | head -1 | cut -d: -f1)"
  stepd="$(grep -n '^### Step D' "$ISSUE_SKILL" | head -1 | cut -d: -f1)"
  [ "$sec" -gt "$stepd" ]
}

@test "pre-classification: names all 4 categories" {
  grep -qF '聖域パス' "$ISSUE_SKILL"
  grep -qF 'マージ権限' "$ISSUE_SKILL"
  grep -qF '層間契約' "$ISSUE_SKILL"
  grep -qF '課金/法務' "$ISSUE_SKILL"
}

@test "pre-classification: spawns with model fable from the first round" {
  grep -qF '`model: fable`' "$ISSUE_SKILL"
  grep -q '最初から' "$ISSUE_SKILL"
}

@test "pre-classification: session model (AGENT_MODEL) is left unchanged" {
  grep -qF 'AGENT_MODEL' "$ISSUE_SKILL"
}

@test "pre-classification: budget mode still caps escalation" {
  grep -qF 'FABLE_BUDGET_MODE=reserve' "$ISSUE_SKILL"
  grep -qF 'exhausted' "$ISSUE_SKILL"
}

# --- ルール2: エスカレーション（failed → 修正実装）は pr-review-gate にある ---

@test "escalation: fix-cycle model section lives in step 2 of the gate" {
  grep -qF '修正サイクルのモデル昇格' "$GATE_SKILL"
  sec="$(grep -n '修正サイクルのモデル昇格' "$GATE_SKILL" | head -1 | cut -d: -f1)"
  step2="$(grep -n '^### 2\. レビュー' "$GATE_SKILL" | head -1 | cut -d: -f1)"
  step3="$(grep -n '^### 3\. リスク宣言' "$GATE_SKILL" | head -1 | cut -d: -f1)"
  [ "$sec" -gt "$step2" ]
  [ "$sec" -lt "$step3" ]
}

@test "escalation: only implementation-quality failures escalate to fable" {
  grep -qF '実装品質起因' "$GATE_SKILL"
  grep -qF '`model: fable`' "$GATE_SKILL"
  grep -qF '昇格は実装品質起因のときだけ' "$GATE_SKILL"
}

@test "escalation: ambiguous spec and reviewer false positives are not escalated" {
  grep -q '仕様が曖昧' "$GATE_SKILL"
  grep -q '誤検出' "$GATE_SKILL"
  grep -q '反証' "$GATE_SKILL"
}

# --- ルール3: フォールバック（Fable が使えないとき） ---

@test "fallback: falls back to the previous model and records one PR comment line" {
  grep -qF 'フォールバック' "$GATE_SKILL"
  grep -qF '修正実装モデル: opus' "$GATE_SKILL"
  grep -qF 'レート制限' "$GATE_SKILL"
}

# --- ルール4: 2周キャップ（収束ルール）との関係 ---

@test "convergence: relation to the two-round cap is stated" {
  grep -qF '2周キャップ' "$GATE_SKILL"
  grep -qF '最終周' "$GATE_SKILL"
}

# --- 重複を作らない: 正本はどちらか一方、他方は参照 ---

@test "single source: the 4-category table is not duplicated into the gate skill" {
  # pr-review-gate は分類名を1行で挙げるだけで、分類表の中身（判定材料）は再掲せず
  # github-issue を正本として参照する
  grep -qF 'github-issue スキルの Step D が正本' "$GATE_SKILL"
  # 4分類の名前が出るのは正本を指す1行だけ（表として再掲していない）
  [ "$(grep -cF '層間契約' "$GATE_SKILL")" -eq 1 ]
  [ "$(grep -cF '聖域パス・マージ権限' "$GATE_SKILL")" -eq 1 ]
}

@test "single source: the fallback record format points back to pr-review-gate" {
  grep -qF 'pr-review-gate' "$ISSUE_SKILL"
  grep -q '正本' "$ISSUE_SKILL"
}

# --- バージョン ---

@test "manifest: dev-workflow version bumped above 1.8.1" {
  v="$(jq -r '.version' "$MANIFEST")"
  [ "$v" != "1.8.1" ]
  highest="$(printf '1.8.1\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

@test "manifest: marketplace dev-workflow entry matches plugin.json" {
  v="$(jq -r '.version' "$MANIFEST")"
  m="$(jq -r '.plugins[] | select(.name == "dev-workflow") | .version' "$MARKETPLACE")"
  [ "$m" = "$v" ]
}

@test "manifest: marketplace top-level version bumped above 2.38.0" {
  v="$(jq -r '.version' "$MARKETPLACE")"
  [ "$v" != "2.38.0" ]
  highest="$(printf '2.38.0\n%s\n' "$v" | sort -V | tail -1)"
  [ "$highest" = "$v" ]
}

@test "skills: both edited skills bumped their frontmatter version above 1.1.0" {
  for f in "$ISSUE_SKILL" "$GATE_SKILL"; do
    v="$(awk -F': ' '/^version:/{print $2; exit}' "$f")"
    [ -n "$v" ]
    [ "$v" != "1.1.0" ]
    highest="$(printf '1.1.0\n%s\n' "$v" | sort -V | tail -1)"
    [ "$highest" = "$v" ]
  done
}
