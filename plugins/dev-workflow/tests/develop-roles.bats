#!/usr/bin/env bats
#
# develop スキルの役割別指示書（W / R1 / G）の構造検証（issue #203）
#
#   references/roles/worker.md        W: 仕様化判断の記録・Draft PR 記録先の作成順序・事前分類表・TDD
#   references/roles/spec-reviewer.md R1: 5 観点・読み取り専用・2 周キャップ・結果書式・判断記録の契約
#   references/roles/gate-runner.md   G: pr-review-gate 手順 1〜5・Codex の呼び方・needs-reviewer・failed の原因分類
#
# spec: dev-workflow-develop, dev-workflow-spec-review

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  ROLES="${PLUGIN_DIR}/skills/develop/references/roles"
  WORKER="${ROLES}/worker.md"
  REVIEWER="${ROLES}/spec-reviewer.md"
  GATE="${ROLES}/gate-runner.md"
}

section() { awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$1"; }

@test "roles: all three role files exist" {
  [ -f "$WORKER" ]
  [ -f "$REVIEWER" ]
  [ -f "$GATE" ]
}

# ===== worker.md =====

@test "worker: records the spec decision with the exact first-line regex via gh, and does not proceed before" {
  grep -qF '^仕様化判断: (する|しない)$' "$WORKER"
  grep -qE 'gh (issue|pr) comment' "$WORKER"
  grep -qE '記録(する|して)(前|まで)|記録せずに.*進(ま|んでは)' "$WORKER"
}

@test "worker: also carries the spec review result format for the record target" {
  grep -qF '^仕様レビュー: (APPROVE|REQUEST_CHANGES)$' "$WORKER"
}

@test "worker: Draft PR record target is created (empty commit -> push -> draft) before the spec decision" {
  grep -q 'git commit --allow-empty' "$WORKER"
  grep -q 'git push' "$WORKER"
  grep -q 'gh pr create --draft' "$WORKER"
  draft="$(grep -n 'gh pr create --draft' "$WORKER" | head -1 | cut -d: -f1)"
  decision="$(grep -nF '^仕様化判断: (する|しない)$' "$WORKER" | head -1 | cut -d: -f1)"
  [ "$draft" -lt "$decision" ]
}

@test "worker: PR body carries acceptance criteria and no Closes/Fixes/Refs when the PR is the record target" {
  grep -qE '受け入れ条件.*PR 本文|PR 本文.*受け入れ条件' "$WORKER"
  grep -qE '(Closes|Fixes|Refs).*(書かない|書いてはならない)' "$WORKER"
}

@test "worker: never creates a worktree itself (main prepares it)" {
  grep -qE 'worktree.*(切らない|作らない)' "$WORKER"
  ! grep -q 'git worktree add' "$WORKER"
}

@test "worker: pre-classification table names all 4 categories and is the single source" {
  grep -qF '重要実装の事前分類' "$WORKER"
  grep -qF '聖域パス' "$WORKER"
  grep -qF 'マージ権限' "$WORKER"
  grep -qF '層間契約' "$WORKER"
  grep -qF '課金/法務' "$WORKER"
  grep -q '正本' "$WORKER"
}

@test "worker: fable from the first round, AGENT_MODEL unchanged, budget modes cap escalation" {
  grep -qF '`model: fable`' "$WORKER"
  grep -q '最初から' "$WORKER"
  grep -qF 'AGENT_MODEL' "$WORKER"
  grep -qF 'FABLE_BUDGET_MODE=reserve' "$WORKER"
  grep -qF 'exhausted' "$WORKER"
}

@test "worker: fallback record format points back to pr-review-gate" {
  grep -qF 'pr-review-gate' "$WORKER"
}

@test "worker: openspec CLI degraded path returns to main for the same spec review" {
  grep -A3 'openspec CLI だけある場合' "$WORKER" | grep -q '仕様レビュー'
  grep -A3 'openspec CLI だけある場合' "$WORKER" | grep -q 'return'
}

@test "worker: spec path returns after /opsx:ff and does not apply before R1 APPROVE" {
  grep -q '/opsx:ff' "$WORKER"
  grep -q '/opsx:apply' "$WORKER"
  grep -qE 'APPROVE.*(まで|前).*(apply|実装).*(進まない|進んではならない|入らない)|(apply|実装).*APPROVE.*(まで|前)' "$WORKER"
}

@test "worker: TDD with evidence-backed completion, no execution-strategy branches" {
  grep -q 'Red' "$WORKER"
  grep -q 'Green' "$WORKER"
  grep -q 'exit code' "$WORKER"
  ! grep -q 'delegate+verify' "$WORKER"
  ! grep -q 'workflow 型' "$WORKER"
  ! grep -q 'solo' "$WORKER"
}

@test "worker: split judgement is based on the issue text, and unmanned splits into child issues with blocked_by" {
  grep -q 'dependencies/blocked_by' "$WORKER"
  grep -q 'references/decision-criteria.md' "$WORKER"
}

# ===== spec-reviewer.md =====

@test "reviewer: five review criteria are listed with spec path + requirement name on conflict" {
  grep -q '一意' "$REVIEWER"
  grep -qE '既存.*openspec/specs' "$REVIEWER"
  grep -qE 'config|引数' "$REVIEWER"
  grep -q '前提' "$REVIEWER"
  grep -qE 'proposal.*specs.*design.*tasks' "$REVIEWER"
  grep -qE 'spec.*パス.*要件名|要件名.*パス' "$REVIEWER"
}

@test "reviewer: read-only and grep-first" {
  grep -qE '読み取り専用|変更しない' "$REVIEWER"
  grep -q 'grep' "$REVIEWER"
}

@test "reviewer: two-round cap, no third round, needs-approval / AskUserQuestion / unmanned cycle end" {
  grep -qE '2 ?周' "$REVIEWER"
  grep -qE '3 ?周目.*(例外|設けない)' "$REVIEWER"
  grep -q 'needs-approval' "$REVIEWER"
  grep -q 'AskUserQuestion' "$REVIEWER"
  grep -qE 'unmanned.*(サイクル|終了)' "$REVIEWER"
}

@test "reviewer: result comment format and posting steps" {
  grep -qF '^仕様レビュー: (APPROVE|REQUEST_CHANGES)$' "$REVIEWER"
  grep -qE 'gh (issue|pr) comment' "$REVIEWER"
  grep -qE '周回|周目' "$REVIEWER"
}

@test "reviewer: decision-record contract (latest one wins, Closes/Fixes/Refs, PR comments fallback)" {
  section "$REVIEWER" '判断記録の契約' | grep -q '最新'
  section "$REVIEWER" '判断記録の契約' | grep -qE 'Closes.*Fixes.*Refs|Refs.*Closes'
  section "$REVIEWER" '判断記録の契約' | grep -q 'PR 自身のコメント'
  section "$REVIEWER" '判断記録の契約' | grep -qF '^仕様化判断: (する|しない)$'
}

@test "reviewer: spawned with explicit model, default opus, fable via worker.md pre-classification" {
  grep -q 'model' "$REVIEWER"
  grep -q '`opus`' "$REVIEWER"
  grep -qE '事前分類.*fable|fable.*事前分類' "$REVIEWER"
  grep -q 'worker.md' "$REVIEWER"
}

@test "reviewer: reserve only for automatic runs, exhausted for all paths" {
  grep -qE 'reserve.*自動実行' "$REVIEWER"
  grep -qE 'exhausted.*(全経路|すべて)' "$REVIEWER"
}

@test "reviewer: return format has Spec Review Result with BLOCKER / SHOULD_FIX / NOTE" {
  grep -q 'Spec Review Result' "$REVIEWER"
  grep -q 'BLOCKER' "$REVIEWER"
  grep -q 'SHOULD_FIX' "$REVIEWER"
}

# ===== gate-runner.md =====

@test "gate-runner: reads pr-review-gate and runs steps 1-5" {
  grep -q 'pr-review-gate' "$GATE"
  grep -qE '手順 ?1 ?〜 ?5|1〜5' "$GATE"
}

@test "gate-runner: Codex is invoked from Bash (codex exec with flags or codex-companion.mjs), not via slash/subagent" {
  grep -qF 'codex exec -c approval_policy=never -c model_reasoning_effort=medium' "$GATE"
  grep -qF 'codex-companion.mjs' "$GATE"
  grep -q '/codex:adversarial-review' "$GATE"
  grep -q 'codex:codex-rescue' "$GATE"
  grep -qE '(使えない|使わない|呼べない)' "$GATE"
}

@test "gate-runner: needs-reviewer return payload (light/full + reason, PR + HEAD SHA, model + reason, acceptance criteria location)" {
  n="$(section "$GATE" 'needs-reviewer')"
  echo "$n" | grep -q 'light'
  echo "$n" | grep -q 'full'
  echo "$n" | grep -q '根拠'
  echo "$n" | grep -q 'HEAD SHA'
  echo "$n" | grep -q 'PR 番号'
  echo "$n" | grep -q '推奨モデル'
  echo "$n" | grep -q '受け入れ条件の所在'
}

@test "gate-runner: spawned by name, resumed with the reviewer summary via SendMessage, and G posts the reviewer line" {
  grep -q '名前付き' "$GATE"
  grep -q 'SendMessage' "$GATE"
  grep -qF 'レビュー実行者:' "$GATE"
  grep -qE 'レビュー実行者:.*G が|G が.*レビュー実行者:' "$GATE"
}

@test "gate-runner: failed return carries the step 2-2 cause classification" {
  grep -q '実装品質起因' "$GATE"
  grep -q '仕様が曖昧' "$GATE"
  grep -q '誤検出' "$GATE"
}

@test "gate-runner: return formats cover passed / failed / on-hold" {
  grep -q 'passed' "$GATE"
  grep -q 'failed' "$GATE"
  grep -q '保留' "$GATE"
}

@test "gate-runner: G itself defaults to sonnet; the reviewer defaults to opus, fable for merge conditions / cross-layer contracts" {
  grep -q 'G の既定は `sonnet`' "$GATE"
  grep -q '`opus`' "$GATE"
  ! grep -q 'マージ条件・聖域・層間契約' "$GATE"
  ! grep -q '聖域・層間契約による' "$GATE"
  grep -q '`fable`' "$GATE"
  grep -q 'マージ条件' "$GATE"
  grep -q '聖域' "$GATE"
  grep -q '層間契約' "$GATE"
}
