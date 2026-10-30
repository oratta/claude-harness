#!/usr/bin/env bats
#
# 実装モデルのエスカレーションポリシー（issue #84 → #203 で develop 構造に移行）
#
# 「レビュー不合格の修正・重要実装（聖域/マージ権限/層間契約/課金・法務）は Fable 担当」という
# 運用判断を、セッション内の心がけから dev-workflow の機械的ルールへ昇格させたもの。
# 事前分類の正本は develop スキルの references/pre-classification.md にあり（#556 で W の指示書から移した）、
# 正本の置き場所が1箇所であること（重複記述を作らないこと）も検証する。
#
# spec: dev-workflow-model-escalation-policy, dev-workflow-develop

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  DECLARATIONS="${PLUGIN_DIR}/skills/pr-review-gate/declarations.md"
  PREPARE="${PLUGIN_DIR}/skills/pr-review-gate/stages/prepare.md"
  REVIEW_RUN="${PLUGIN_DIR}/skills/pr-review-gate/stages/review-run.md"
  REVIEWER_BRIEF="${PLUGIN_DIR}/skills/pr-review-gate/stages/reviewer-brief.md"
  TRIAGE="${PLUGIN_DIR}/skills/pr-review-gate/stages/triage.md"
  PASS_STAGE="${PLUGIN_DIR}/skills/pr-review-gate/stages/pass.md"
  HOLD="${PLUGIN_DIR}/skills/pr-review-gate/stages/hold.md"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  DEV_SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  PRE="${PLUGIN_DIR}/skills/develop/references/pre-classification.md"
  GATE_SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  CRITERIA="${PLUGIN_DIR}/skills/develop/references/decision-criteria.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

# --- ルール1: 事前分類（1周目から Fable）は develop の pre-classification.md にある ---

@test "pre-classification: section lives in develop pre-classification.md" {
  grep -qF '重要実装の事前分類' "$PRE"
}

@test "pre-classification: names all 4 categories" {
  grep -qF '聖域パス' "$PRE"
  grep -qF 'マージ権限' "$PRE"
  grep -qF '層間契約' "$PRE"
  grep -qF '課金/法務' "$PRE"
}

@test "pre-classification: the first-round column has no fable (the worker's cap is opus)" {
  tbl="$(awk '/^## 重要実装の事前分類/{f=1} f && /^\| /{print} /^## 昇格トリップワイヤー/{f=0}' "$PRE")"
  [ -n "$tbl" ]
  ! echo "$tbl" | grep -qF '`fable`' || return 1
  echo "$tbl" | grep -qF '`opus`'
  grep -q '最初から' "$PRE"
  grep -qF 'W の上限は `opus`' "$PRE"
}

@test "pre-classification: reviewers that hit the table are spawned as dev-workflow:decider" {
  grep -qF 'dev-workflow:decider' "$PRE"
  grep -qF '`general-purpose` に `model: fable` を付けない' "$PRE"
}

@test "pre-classification: session model (AGENT_MODEL) is left unchanged" {
  grep -qF 'AGENT_MODEL' "$PRE"
}

# 残量モード表の abundant / conserve 行は「事前分類の fable 行」を前提に書かれていて、
# 事前分類表から fable 行が消えた後も旧前提のまま残っていた（PR #252 の指摘）。
@test "budget modes: the abundant / conserve rows route Fable through the decider type" {
  for row in abundant conserve; do
    line="$(grep -F "| \`${row}\`" "$CRITERIA")"
    [ -n "$line" ]
    echo "$line" | grep -qF 'dev-workflow:decider'
  done
  grep -qF '実行役（W）はどの分類でも `opus` 止まり' "$CRITERIA"
}

# 退役した言い回しがプラグインのどこかに残ると、配布される指示文がガードの deny する
# 手順を案内することになる。文書・スクリプトを横断で見る（CHANGELOG は変更の記録なので対象外）。
@test "retired wording: no live instruction still points at the removed fable row" {
  offenders="$(grep -rn '事前分類の `\?fable`\? 行\|Fable は verify / checkpoint のみ' \
      --include='*.md' --include='*.sh' --include='*.json' "$PLUGIN_DIR" \
      | grep -v '/tests/' | grep -v '/CHANGELOG.md:' || true)"
  if [ -n "$offenders" ]; then
    echo "退役した『事前分類の fable 行』の言い回しが残っている:"
    echo "$offenders"
    false
  fi
}

@test "pre-classification: the table feeds --pre-class and the sacred path alone does not raise a review" {
  grep -qF '`--pre-class`' "$PRE"
  grep -qF '聖域パスだけではレビューを上げない' "$PRE"
  grep -qF 'マージ権限・層間契約・課金/法務に当たるときは' "$PRE"
  line="$(grep -F '| `conserve`' "$CRITERIA")"
  echo "$line" | grep -qF 'マージ権限・層間契約・課金/法務に当たる'
  echo "$line" | grep -qF '聖域パスだけでは上げない'
}

@test "spec reviewer: the spawn uses the model and role request returned, keeping the wording of the spec" {
  R1_DOC="${PLUGIN_DIR}/skills/develop/references/roles/spec-reviewer.md"
  sec="$(awk '/^## R1 の spawn/{f=1; next} /^## /{f=0} f' "$R1_DOC")"
  echo "$sec" | grep -qF '`codex-develop.py request --phase spec-review` が返す `model`'
  echo "$sec" | grep -qF '`role: decider`'
  echo "$sec" | grep -qF '`model: opus`'
  echo "$sec" | grep -qF 'references/pre-classification.md'
  echo "$sec" | grep -qF '聖域パスだけでは上げない'
  echo "$sec" | grep -qF '`reserve` は自動実行のみ'
  echo "$sec" | grep -qF '`exhausted` は全経路で `opus` 上限'
  echo "$sec" | grep -qF '`sonnet` 上限'
  ! echo "$sec" | grep -qF '`sonnet` 固定' || return 1
}

@test "shared budget: depleted is a Sonnet cap and haiku stays haiku under both modes" {
  grep -F '| `depleted`' "$CRITERIA" | grep -qF 'Sonnet 上限'
  ! grep -F '| `depleted`' "$CRITERIA" | grep -qF 'Sonnet 固定' || return 1
  grep -qF '`haiku` の役割（explore と summarize）は `throttled` でも `depleted` でも `haiku` のまま' "$CRITERIA"
  grep -qF '`sonnet` 上限' "$PRE"
}

@test "pre-classification: budget mode still caps escalation" {
  grep -qF 'FABLE_BUDGET_MODE=reserve' "$PRE"
  grep -qF 'exhausted' "$PRE"
}

# --- ルール2: エスカレーション（failed → 修正実装）は pr-review-gate にある ---

@test "escalation: fix-cycle model section lives in step 2 of the gate" {
  # 手順 2 の中の 2-2 として triage.md にあり、索引の対応表もそこを指す
  grep -qE '^#### 2-2\. 修正サイクルのモデル昇格' "$TRIAGE"
  grep -qF '| 2-2 | 2-2. 修正サイクルのモデル昇格' "$GATE_SKILL"
  grep -F '| 2-2 |' "$GATE_SKILL" | grep -qF 'stages/triage.md'
}

@test "escalation: implementation-quality failures raise the decider or the executor, never both" {
  sec="$(awk '/^#### 2-2\. /{f=1} /^### 3\. /{f=0} f' "${TRIAGE}")"
  echo "$sec" | grep -qF '実装品質起因'
  echo "$sec" | grep -qF '決める役'
  echo "$sec" | grep -qF '実行役'
  echo "$sec" | grep -qF '一方だけ'
  echo "$sec" | grep -qF 'dev-workflow:decider'
  # 旧ラダー（実行役を 1 段ずつ sonnet → opus → fable）は残さない
  ! echo "$sec" | grep -qF '`sonnet` → `opus` → `fable`' || return 1
  # 旧ラダーの表記「...で spawn する」だけを拒否する。現行文は同じ語順で
  # 「...で spawn しない」と続くため、"する" まで含めないと現行文自体に誤爆する。
  ! echo "$sec" | grep -qF '修正実装を `model: fable` で spawn する' || return 1
  grep -qF '昇格は実装品質起因のときだけ' "${TRIAGE}"
}

@test "escalation: the executor is capped at opus and never spawned as fable" {
  sec="$(awk '/^#### 2-2\. /{f=1} /^### 3\. /{f=0} f' "${TRIAGE}")"
  echo "$sec" | grep -qF '実行役の上限は `opus`'
  echo "$sec" | grep -qF 'agent-model-guard.sh'
}

@test "escalation: the two-round cap is given as the reason for raising on the first failed" {
  sec="$(awk '/^#### 2-2\. /{f=1} /^### 3\. /{f=0} f' "${TRIAGE}")"
  echo "$sec" | grep -qF '2 周キャップ'
  echo "$sec" | grep -qF '既定の最終周'
  echo "$sec" | grep -qF '1 回目の failed'
  echo "$sec" | grep -qF '直し方の判定'
}

@test "escalation: ambiguous spec and reviewer false positives are not escalated" {
  grep -q '仕様が曖昧' "${TRIAGE}"
  grep -q '誤検出' "${TRIAGE}"
  grep -q '反証' "${TRIAGE}"
}

# --- ルール3: フォールバック（Fable が使えないとき） ---

@test "fallback: falls back to the previous model and records one PR comment line" {
  grep -qF 'Fable が使えないときのフォールバック' "${TRIAGE}"
  grep -qF '決める役モデル: opus' "${TRIAGE}"
  grep -qF 'dev-workflow:decider のまま' "${TRIAGE}"
  grep -qF 'レート制限' "${TRIAGE}"
}

# --- ルール4: 2周キャップ（収束ルール）との関係 ---

@test "convergence: relation to the two-round cap is stated" {
  grep -qF '2周キャップ' "${TRIAGE}"
  grep -qF '最終周' "${TRIAGE}"
}

# --- 重複を作らない: 正本はどちらか一方、他方は参照 ---

@test "single source: the 4-category table is not duplicated into the gate skill" {
  # pr-review-gate は分類名を1行で挙げるだけで、分類表の中身（判定材料）は再掲せず
  # develop の pre-classification.md を正本として参照する
  grep -qF 'develop スキルの references/pre-classification.md が正本' "${TRIAGE}"
  for f in "$GATE_SKILL" "$DECLARATIONS" "$PREPARE" "$REVIEW_RUN" "$REVIEWER_BRIEF" "$TRIAGE" "$PASS_STAGE" "$HOLD"; do
    ! grep -q 'github-''issue' "$f" || return 1
  done
  # 4分類の名前が出るのは正本を指す1行だけ（表として再掲していない）
  [ "$(grep -cF '層間契約' "${TRIAGE}")" -eq 1 ]
  [ "$(grep -cF '聖域パス・マージ権限' "${TRIAGE}")" -eq 1 ]
}

@test "single source: the fallback record format points back to pr-review-gate" {
  grep -qF 'pr-review-gate' "$PRE"
  grep -q '正本' "$PRE"
}

@test "single source: develop SKILL.md model section defers the table to pre-classification.md" {
  awk 'index($0,"## モデル")==1{f=1; next} /^## /{f=0} f' "$DEV_SKILL" | grep -q 'pre-classification.md'
}

# --- develop の「モデル」節は規則の説明と request への参照（model-tier-resolution, #614） ---

model_section() {
  awk 'index($0,"## モデル")==1{f=1; next} /^## /{f=0} f' "$DEV_SKILL"
}

@test "model section: the role table states tiers with the Claude value in parentheses" {
  sec="$(model_section)"
  echo "$sec" | grep -F '| W（実行役。' | grep -qF '| 中位（`sonnet`） | 上位（`opus`）:'
  echo "$sec" | grep -F '| R1（読んで判断する役） |' | grep -qF '| 上位（`opus`） |'
  echo "$sec" | grep -F '| G（`dev-workflow:gate-runner`） |' | grep -qF '| 中位（`sonnet`） |'
  echo "$sec" | grep -F '| G が要求するレビュアー' | grep -qF '| 上位（`opus`） |'
  echo "$sec" | grep -qF 'W の上限は `opus`'
  echo "$sec" | grep -F '| R1（読んで判断する役） |' | grep -qF 'dev-workflow:decider'
  echo "$sec" | grep -F '| G が要求するレビュアー' | grep -qF 'dev-workflow:decider'
}

@test "model section: V and the carryover judge do not go through request" {
  sec="$(model_section)"
  echo "$sec" | grep -F '| V（画面確認役。' | grep -F '中位（`sonnet`）' | grep -qF '`request` を通らない'
  echo "$sec" | grep -F '| 引き継ぎの判定役' | grep -F '上位（`opus`）' | grep -qF '`request` を通らず'
}

@test "model section: new spawns use the model request returned and are not recalculated" {
  sec="$(model_section)"
  echo "$sec" | grep -qF 'codex-develop.py request'
  echo "$sec" | grep -qF '新しい起動の `model` を文章の規則で計算し直さない'
}

@test "model section: budget modes are named but their value-by-value effects stay in decision-criteria" {
  sec="$(model_section)"
  echo "$sec" | grep -qF 'FABLE_BUDGET_MODE'
  echo "$sec" | grep -qF 'SHARED_BUDGET_MODE'
  echo "$sec" | grep -qF 'references/decision-criteria.md'
  ! echo "$sec" | grep -qE 'abundant|reserve|exhausted|throttled|depleted' || return 1
}

@test "model section: no route-by-route model names per configuration" {
  [ "$(model_section | grep -cE 'claude-write-codex-review|codex-standard')" -eq 0 ]
}

@test "role profile section: request gets the tier inputs on every route, including Claude default" {
  sec="$(awk 'index($0,"## Role profile の選択")==1{f=1; next} /^## /{f=0} f' "$DEV_SKILL")"
  echo "$sec" | grep -qF 'Claude 既定の経路を含む全経路'
  for flag in '--pre-class' '--design-judgment' '--failure' '--unmanned'; do
    echo "$sec" | grep -qF -- "$flag" || { echo "missing $flag"; return 1; }
  done
  echo "$sec" | grep -qF '`role: decider`'
  for field in requested_model tier_reason executed_tier tier_cap; do
    echo "$sec" | grep -qF "\`$field\`" || { echo "missing $field"; return 1; }
  done
}

@test "role profile section: a resume calls request again and compares tiers without reselecting" {
  sec="$(awk 'index($0,"## Role profile の選択")==1{f=1; next} /^## /{f=0} f' "$DEV_SKILL")"
  echo "$sec" | grep -qF '同じ phase と入力で `request` を呼び直し'
  echo "$sec" | grep -qF 'thread の格'
  echo "$sec" | grep -qF '選び直しには使わない'
}

# --- バージョン ---

@test "skills: develop SKILL.md is at least 2.0.0 and gate SKILL.md is above 1.4.0" {
  v="$(awk -F': ' '/^version:/{print $2; exit}' "$DEV_SKILL")"
  [ -n "$v" ]
  printf '2.0.0\n%s\n' "$v" | sort -V -C
  g="$(awk -F': ' '/^version:/{print $2; exit}' "$GATE_SKILL")"
  [ -n "$g" ]
  [ "$g" != "1.4.0" ]
  printf '1.4.0\n%s\n' "$g" | sort -V -C
}
