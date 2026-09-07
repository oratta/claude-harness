#!/usr/bin/env bats
#
# 実装モデルのエスカレーションポリシー（issue #84 → #203 で develop 構造に移行）
#
# 「レビュー不合格の修正・重要実装（聖域/マージ権限/層間契約/課金・法務）は Fable 担当」という
# 運用判断を、セッション内の心がけから dev-workflow の機械的ルールへ昇格させたもの。
# 事前分類の正本は develop スキルの W の指示書（references/roles/worker.md）にあり、
# 正本の置き場所が1箇所であること（重複記述を作らないこと）も検証する。
#
# spec: dev-workflow-model-escalation-policy, dev-workflow-develop

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  DEV_SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  WORKER="${PLUGIN_DIR}/skills/develop/references/roles/worker.md"
  GATE_SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

# --- ルール1: 事前分類（1周目から Fable）は develop の worker.md にある ---

@test "pre-classification: section lives in develop worker.md" {
  grep -qF '重要実装の事前分類' "$WORKER"
}

@test "pre-classification: names all 4 categories" {
  grep -qF '聖域パス' "$WORKER"
  grep -qF 'マージ権限' "$WORKER"
  grep -qF '層間契約' "$WORKER"
  grep -qF '課金/法務' "$WORKER"
}

@test "pre-classification: spawns with model fable from the first round" {
  grep -qF '`model: fable`' "$WORKER"
  grep -q '最初から' "$WORKER"
}

@test "pre-classification: session model (AGENT_MODEL) is left unchanged" {
  grep -qF 'AGENT_MODEL' "$WORKER"
}

@test "pre-classification: budget mode still caps escalation" {
  grep -qF 'FABLE_BUDGET_MODE=reserve' "$WORKER"
  grep -qF 'exhausted' "$WORKER"
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

@test "escalation: implementation-quality failures escalate one rung (sonnet → opus → fable), never straight to fable" {
  sec="$(awk '/^#### 2-2\. /{f=1} /^### 3\. /{f=0} f' "$GATE_SKILL")"
  echo "$sec" | grep -qF '実装品質起因'
  echo "$sec" | grep -qF '1 段上'
  echo "$sec" | grep -qF '`sonnet` → `opus` → `fable`'
  ! echo "$sec" | grep -qF '修正実装を `model: fable` で spawn'
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
  # develop の worker.md を正本として参照する
  grep -qF 'develop スキルの references/roles/worker.md が正本' "$GATE_SKILL"
  ! grep -q 'github-''issue' "$GATE_SKILL"
  # 4分類の名前が出るのは正本を指す1行だけ（表として再掲していない）
  [ "$(grep -cF '層間契約' "$GATE_SKILL")" -eq 1 ]
  [ "$(grep -cF '聖域パス・マージ権限' "$GATE_SKILL")" -eq 1 ]
}

@test "single source: the fallback record format points back to pr-review-gate" {
  grep -qF 'pr-review-gate' "$WORKER"
  grep -q '正本' "$WORKER"
}

@test "single source: develop SKILL.md model section defers the table to worker.md" {
  awk 'index($0,"## モデル")==1{f=1; next} /^## /{f=0} f' "$DEV_SKILL" | grep -q 'worker.md'
}

# --- バージョン ---

@test "manifest: dev-workflow version is at least 2.0.0" {
  v="$(jq -r '.version' "$MANIFEST")"
  printf '2.0.0\n%s\n' "$v" | sort -V -C
}

@test "manifest: marketplace dev-workflow entry matches plugin.json" {
  v="$(jq -r '.version' "$MANIFEST")"
  m="$(jq -r '.plugins[] | select(.name == "dev-workflow") | .version' "$MARKETPLACE")"
  [ "$m" = "$v" ]
}

@test "skills: develop SKILL.md is at least 2.0.0 and gate SKILL.md is above 1.4.0" {
  v="$(awk -F': ' '/^version:/{print $2; exit}' "$DEV_SKILL")"
  [ -n "$v" ]
  printf '2.0.0\n%s\n' "$v" | sort -V -C
  g="$(awk -F': ' '/^version:/{print $2; exit}' "$GATE_SKILL")"
  [ -n "$g" ]
  [ "$g" != "1.4.0" ]
  printf '1.4.0\n%s\n' "$g" | sort -V -C
}
