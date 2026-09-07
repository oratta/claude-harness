#!/usr/bin/env bats
#
# 仕様化判断の記録と、書いた仕様の実装前レビュー（issue #191 → #203 で develop 構造に移行）
#
# develop スキルでは、W（references/roles/worker.md）が仕様化判断を固定書式で記録先に記録し、
# 本体の 1 ループ（SKILL.md）が W の /opsx:ff と W の再開（apply）の間に R1
# （references/roles/spec-reviewer.md）の仕様レビューを挟むことを検証する。
# 既存文（事前分類節・残量モード行）で偽合格しないよう、節を切り出してから grep する。
#
# spec: dev-workflow-spec-review

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/develop/SKILL.md"
  WORKER="${PLUGIN_DIR}/skills/develop/references/roles/worker.md"
  REF="${PLUGIN_DIR}/skills/develop/references/roles/spec-reviewer.md"
  CRITERIA="${PLUGIN_DIR}/skills/develop/references/decision-criteria.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

section() { awk -v h="## $2" 'index($0, h)==1 && $0 !~ /^### /{f=1; print; next} /^## /{f=0} f' "$1"; }
# worker.md の仕様化判断節
decision_sec() { section "$WORKER" '仕様化判断'; }
# SKILL.md の 1 ループ節
loop_sec() { section "$SKILL" '1 ループ'; }
# SKILL.md の実行モード節
mode_sec() { section "$SKILL" '実行モード'; }

# --- Requirement: 仕様化要否の判定結果を固定書式で issue に記録する ---

@test "worker: records decision with exact first-line regex" {
  decision_sec | grep -qF '^仕様化判断: (する|しない)$'
}

@test "worker: posts the record to the record target via gh" {
  decision_sec | grep -qE 'gh (issue|pr) comment'
}

@test "worker: forbids proceeding before the record" {
  decision_sec | grep -qE '記録(する|して)(前|まで)|記録せずに.*進(ま|んでは)'
}

@test "mode table / unmanned: decision record is not exempt" {
  mode_sec | grep -qE '(仕様化判断|判定の記録).*免除しない'
}

@test "references: latest-one rule and PR->issue resolution rule with PR-comment fallback" {
  [ -f "$REF" ]
  grep -q '最新' "$REF"
  grep -qE 'Closes.*Fixes.*Refs|Refs.*Closes' "$REF"
  grep -q 'PR 自身のコメント' "$REF"
}

@test "criteria: step B section points at the record format" {
  awk '/^## Step B/{f=1} /^## Step C/{f=0} f' "$CRITERIA" | grep -q '仕様化判断'
}

# --- Requirement: 書いた仕様は実装前に別コンテキストがレビューする ---

@test "loop: R1 review sits between W's /opsx:ff and W's apply" {
  loop_sec | grep -q '/opsx:ff'
  ff="$(loop_sec | grep -n '/opsx:ff' | head -1 | cut -d: -f1)"
  rev="$(loop_sec | grep -n '仕様レビュー' | head -1 | cut -d: -f1)"
  apply="$(loop_sec | grep -n 'apply' | head -1 | cut -d: -f1)"
  [ -n "$ff" ] && [ -n "$rev" ] && [ -n "$apply" ]
  [ "$ff" -lt "$rev" ] && [ "$rev" -lt "$apply" ]
}

@test "loop: references spec-reviewer.md and blocks apply until APPROVE is recorded" {
  loop_sec | grep -q 'references/roles/spec-reviewer.md'
  loop_sec | grep -q 'APPROVE'
  loop_sec | grep -qE 'まで.*(apply|実装).*(進まない|進んではならない|入らない|再開しない)'
}

@test "worker: degraded path (openspec CLI only) also returns for the review" {
  grep -A3 'openspec CLI だけある場合' "$WORKER" | grep -q '仕様レビュー'
  grep -A3 'openspec CLI だけある場合' "$WORKER" | grep -q 'return'
}

@test "loop: interactive multi-change handling reviews each change" {
  grep -qE 'change ごと.*仕様レビュー|仕様レビュー.*change ごと' "$SKILL" "$WORKER"
}

# --- Requirement: 仕様レビューの観点は既存 spec との整合と受け入れ条件の一意性を含む ---

@test "references: five review criteria are listed" {
  grep -q '一意' "$REF"
  grep -qE '既存.*openspec/specs' "$REF"
  grep -qE 'config|引数' "$REF"
  grep -qE '前提' "$REF"
  grep -qE 'proposal.*specs.*design.*tasks' "$REF"
  grep -qE 'spec.*パス.*要件名|要件名.*パス' "$REF"
}

@test "references: read-only reviewer and grep-first" {
  grep -qE '読み取り専用|変更しない' "$REF"
  grep -q 'grep' "$REF"
}

# --- Requirement: 仕様レビューは 2 周で確定し結果を issue に記録する ---

@test "review cap: 2 rounds, no third-round exception, needs-approval afterwards" {
  { loop_sec; cat "$REF"; } | grep -qE '2 ?周'
  { loop_sec; cat "$REF"; } | grep -q 'needs-approval'
  { loop_sec; cat "$REF"; } | grep -q 'AskUserQuestion'
  { loop_sec; cat "$REF"; } | grep -qE 'unmanned.*(サイクル|終了)'
  grep -qE '3 ?周目.*(例外|設けない)' "$REF"
}

@test "references: result comment format and posting steps live in spec-reviewer.md" {
  grep -qF '^仕様レビュー: (APPROVE|REQUEST_CHANGES)$' "$REF"
  grep -qE 'gh (issue|pr) comment' "$REF"
  grep -qE '周回|周目' "$REF"
}

# --- Requirement: 仕様レビュアーのモデルは役割で選ぶ ---

@test "review model: explicit model, default opus, fable via worker.md table" {
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -q 'model'
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -q '`opus`'
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -qE '事前分類.*fable|fable.*事前分類'
}

@test "review model: reserve only for automatic runs, exhausted for all paths" {
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -qE 'reserve.*自動実行'
  { section "$SKILL" 'モデル'; cat "$REF"; } | grep -qE 'exhausted.*(全経路|すべて)'
}

# --- 配布 ---

@test "manifest: plugin version at least 2.0.0 and matches marketplace" {
  v="$(jq -r '.version' "$MANIFEST")"
  printf '2.0.0\n%s\n' "$v" | sort -V -C
  mv="$(jq -r '.plugins[] | select(.name=="dev-workflow") | .version' "$MARKETPLACE")"
  [ "$mv" = "$v" ]
}

@test "manifest: description mentions the spec review step and develop" {
  jq -r '.description' "$MANIFEST" | grep -q '仕様レビュー'
  jq -r '.description' "$MANIFEST" | grep -q 'develop'
  ! jq -r '.description' "$MANIFEST" | grep -q 'github-''issue'
}

@test "skill frontmatter: description mentions spec review" {
  awk '/^description:/{print; exit}' "$SKILL" | grep -q '仕様レビュー'
}
