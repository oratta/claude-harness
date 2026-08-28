#!/usr/bin/env bats
#
# 仕様化判断の記録と、書いた仕様の実装前レビュー（issue #191）
#
# github-issue SKILL.md が Step B で判定結果を固定書式で issue に記録し、
# Step D で /opsx:ff と /opsx:apply の間に別コンテキストの仕様レビューを挟むことを検証する。
# 既存文（Step D の事前分類節・残量モード行）で偽合格しないよう、仕様レビュー節を切り出してから grep する。
#
# spec: dev-workflow-spec-review

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/github-issue/SKILL.md"
  REF="${PLUGIN_DIR}/skills/github-issue/references/spec-review.md"
  CRITERIA="${PLUGIN_DIR}/skills/github-issue/references/decision-criteria.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

# Step B 節（### Step B 〜 次の ### まで）
step_b() { awk '/^### Step B/{f=1} /^### Step C/{f=0} f' "$SKILL"; }
# Step D の仕様レビュー小節（#### 仕様レビュー 〜 コード直行の見出しまで）
review_sec() { awk '/^#### 仕様レビュー/{f=1} /^\*\*コード直行する場合/{f=0} f' "$SKILL"; }

# --- Requirement: 仕様化要否の判定結果を固定書式で issue に記録する ---

@test "step B: records decision with exact first-line regex" {
  step_b | grep -qF '^仕様化判断: (する|しない)$'
}

@test "step B: posts the record to the issue via gh" {
  step_b | grep -q 'gh issue comment'
}

@test "step B: forbids proceeding before the record" {
  step_b | grep -qE '記録(する|して)(前|まで)|記録せずに.*進(ま|んでは)'
}

@test "mode table / unmanned: decision record is not exempt" {
  grep -qE 'unmanned.*(仕様化判断|判定の記録|記録).*(免除しない|必須|同じ)' "$SKILL" || \
    awk '/^## 実行モード/{f=1} /^## パイプライン/{f=0} f' "$SKILL" | grep -q '仕様化判断'
}

@test "references: latest-one rule and PR→issue resolution rule" {
  [ -f "$REF" ]
  grep -q '最新' "$REF"
  grep -qE 'Closes.*Fixes.*Refs|Refs.*Closes' "$REF"
}

@test "criteria: step B section points at the record format" {
  awk '/^## Step B/{f=1} /^## Step C/{f=0} f' "$CRITERIA" | grep -q '仕様化判断'
}

# --- Requirement: 書いた仕様は実装前に別コンテキストがレビューする ---

# Step D「仕様化する場合」のコマンドブロック（``` で囲まれた ff〜archive の列）だけを切り出す
step_d_block() { awk '/^\*\*仕様化する場合/{f=1} f&&/^```/{c++} f&&c==1{print} f&&c==2{exit}' "$SKILL"; }

@test "step D: review sits between ff and apply inside the opsx command block" {
  step_d_block | grep -q '/opsx:ff'
  ff="$(step_d_block | grep -n '/opsx:ff' | head -1 | cut -d: -f1)"
  rev="$(step_d_block | grep -n '仕様レビュー' | head -1 | cut -d: -f1)"
  apply="$(step_d_block | grep -n '/opsx:apply' | head -1 | cut -d: -f1)"
  [ -n "$ff" ] && [ -n "$rev" ] && [ -n "$apply" ]
  [ "$ff" -lt "$rev" ] && [ "$rev" -lt "$apply" ]
}

@test "step D: review section references spec-review.md and blocks until APPROVE" {
  review_sec | grep -q 'references/spec-review.md'
  review_sec | grep -q 'APPROVE'
  review_sec | grep -qE 'まで.*(apply|実装).*(進まない|進んではならない|入らない)'
}

@test "step D: degraded path (openspec CLI only) also reviews" {
  grep -A3 'openspec CLI だけある場合' "$SKILL" | grep -q '仕様レビュー'
}

@test "step D: workflow strategy substitutes longrun Build Contract" {
  { review_sec; cat "$REF"; } | grep -q 'Build Contract'
}

@test "step C: interactive change loop includes the review" {
  awk '/^### Step C/{f=1} /^### Step D/{f=0} f' "$SKILL" | grep -q '仕様レビュー'
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
  { review_sec; cat "$REF"; } | grep -qE '2 ?周'
  { review_sec; cat "$REF"; } | grep -q 'needs-approval'
  { review_sec; cat "$REF"; } | grep -q 'AskUserQuestion'
  { review_sec; cat "$REF"; } | grep -qE 'unmanned.*(サイクル|終了)'
}

@test "step D: result comment format and posting steps live in SKILL.md" {
  review_sec | grep -qF '^仕様レビュー: (APPROVE|REQUEST_CHANGES)$'
  review_sec | grep -q 'gh issue comment'
  review_sec | grep -qE '周回|周目'
}

# --- Requirement: 仕様レビュアーのモデルは役割で選ぶ ---

@test "review model: explicit model, default opus, fable via Step D table" {
  review_sec | grep -qE 'model'
  review_sec | grep -q 'opus'
  review_sec | grep -qE '事前分類.*fable|fable.*事前分類'
}

@test "review model: reserve only for automatic runs, exhausted for all paths" {
  { review_sec; cat "$REF"; } | grep -qE 'reserve.*自動実行'
  { review_sec; cat "$REF"; } | grep -qE 'exhausted.*(全経路|すべて)'
}

# --- 配布 ---

@test "manifest: plugin version bumped above 1.11.1 and matches marketplace" {
  v="$(jq -r '.version' "$MANIFEST")"
  [ "$(printf '1.11.1\n%s\n' "$v" | sort -V | tail -1)" = "$v" ] && [ "$v" != "1.11.1" ]
  mv="$(jq -r '.plugins[] | select(.name=="dev-workflow") | .version' "$MARKETPLACE")"
  [ "$mv" = "$v" ]
}

@test "manifest: description mentions the spec review step" {
  jq -r '.description' "$MANIFEST" | grep -q '仕様レビュー'
}

@test "skill frontmatter: version bumped and description mentions spec review" {
  v="$(awk '/^version:/{print $2; exit}' "$SKILL")"
  [ "$v" != "1.2.0" ]
  awk '/^description:/{print; exit}' "$SKILL" | grep -q '仕様レビュー'
}
