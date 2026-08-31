#!/usr/bin/env bats
#
# pr-review-gate の仕様宣言（issue #191）
# 手順 3 の第 3 のコメント（仕様宣言）、手順 5 の 3 見出し実測と issue 記録との整合照合、
# spec-touch-check の参照、auto-merge 範囲外の明記を SKILL.md の記述として検証する。
# spec: dev-workflow-pr-review-gate

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PLUGIN_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  MARKETPLACE="${PLUGIN_ROOT}/.claude-plugin/marketplace.json"
}

head_sec() { awk '/^## 前提と理由/{f=1} /^## 手順/{f=0} f' "$SKILL"; }
step3() { awk '/^### 3\. /{f=1} /^### 4\. /{f=0} f' "$SKILL"; }
step5() { awk '/^### 5\. /{f=1} /^### 6\. /{f=0} f' "$SKILL"; }

# --- Requirement: 仕様宣言を通過の必須点に加える ---

@test "intro: required points list includes the spec declaration" {
  sed -n 1,20p "$SKILL" | grep -q '通過の必須' 
  sed -n 1,20p "$SKILL" | grep '通過の必須' | grep -q '仕様宣言'
}

@test "step 3: spec declaration heading with target-HEAD first line" {
  step3 | grep -q '^## 仕様宣言$'
  step3 | awk '/^## 仕様宣言$/{getline; print}' | grep -q '^対象 HEAD:'
}

@test "step 3: both forms (updated / no-change with reason) are templated" {
  step3 | grep -q '仕様: 更新した'
  step3 | grep -q '仕様: 変更なし'
  step3 | grep -q 'archive 済み'
  step3 | grep -q '仕様レビュー: APPROVE'
  step3 | grep -qE '変更なし.*理由'
}

@test "step 3: declaration is mandatory (not writing is not an option)" {
  step3 | grep -qE '仕様宣言.*(書かない.*選べない|必ず)'
}

# --- Requirement: 合格処理は仕様宣言の実在と issue 記録との整合を実測する ---

@test "step 5: SHA-bound listing must show all three headings" {
  step5 | grep -q '仕様宣言'
  step5 | grep -qE '3 ?(見出し|つ).*(すべて|全部|揃)'
  ! step5 | grep -q '見出しが両方'
}

@test "step 5: consistency table has yes / no / no-record rows" {
  step5 | grep -q '仕様化判断: する'
  step5 | grep -q '仕様化判断: しない'
  step5 | grep -q '記録なし'
  step5 | grep -qE 'archive.*実測|実測.*archive'
  step5 | grep -qE 'しない.*openspec.*(差分|矛盾)|差分.*しない.*矛盾'
  step5 | grep -q '仕様レビュー: APPROVE'
}

@test "step 5: issue is resolved from Closes/Fixes/Refs and issue side wins" {
  step5 | grep -qE 'Closes.*Fixes.*Refs'
  step5 | grep -qE 'issue 参照が無い場合に限|issue 側が正'
}

@test "step 5: no record -> no pass, record first" {
  step5 | grep -qE '記録なし.*(合格しない|合格処理をしない|不可)'
}

# 手順 5 に書かれた jq 式を SKILL.md から抜き出し、fixture で実行する（式が実際に「最新 1 件」を選ぶこと）
jq_prog() { step5 | grep -- "| jq -r" | grep "$1" | head -1 | sed -E "s/.*jq -r '([^']*)'.*/\\1/"; }
fixture_pages() {
  # --paginate --slurp の出力形（ページの配列）を模す
  printf '[[{"body":"仕様レビュー: APPROVE\\n1 周目"},{"body":"雑談"}],[{"body":"仕様レビュー: REQUEST_CHANGES\\n2 周目"},{"body":"仕様化判断: **する**"},{"body":"仕様化判断: しない\\n理由: x"}]]'
}

@test "step 5 jq: latest review result wins (stale APPROVE does not pass)" {
  prog="$(jq_prog '仕様レビュー')"
  [ -n "$prog" ]
  out="$(fixture_pages | jq -r "$prog")"
  [ "$out" = "仕様レビュー: REQUEST_CHANGES" ]
}

@test "step 5 jq: decision picks the latest exact-format comment across pages" {
  prog="$(jq_prog '仕様化判断')"
  [ -n "$prog" ]
  out="$(fixture_pages | jq -r "$prog")"
  [ "$out" = "仕様化判断: しない" ]
}

@test "step 5: comments are fetched with --paginate --slurp piped to jq (slurp is incompatible with --jq)" {
  step5 | grep '仕様' | grep -- '--paginate --slurp' | grep -q -- '| jq -r'
  ! step5 | grep '^gh api' | grep -- '--slurp' | grep -q -- '--jq'
}

# --- Requirement: spec-touch-check スクリプトが規範パス接触と openspec 差分を報告する ---

@test "step 5: runs spec-touch-check.sh and demands a reason on exit 2" {
  step5 | grep -q 'spec-touch-check.sh'
  step5 | grep -qE '(終了コード|exit) ?2'
  step5 | grep -qE '規範.*(言及|理由)'
}

# --- Requirement: auto-merge への組み込みは範囲外と明記する ---

@test "intro: auto-merge integration is explicitly out of scope (separate issue)" {
  head_sec | grep '仕様宣言' | grep -q 'auto-merge'
  head_sec | grep '仕様宣言' | grep -qE '別 issue|範囲外'
}

@test "intro: HEAD SHA paragraph names the spec declaration too" {
  head_sec | grep 'HEAD SHA' | grep -q '仕様宣言'
}

# --- 既存件数固定アサーションを壊さない ---

@test "keeps single occurrence of the cross-layer-contract and sanctuary/merge-permission phrases" {
  [ "$(grep -cF '層間契約' "$SKILL")" -eq 1 ]
  [ "$(grep -cF '聖域パス・マージ権限' "$SKILL")" -eq 1 ]
}

# --- 配布 ---

@test "manifest: version above 1.12.0, marketplace in sync, description mentions the spec declaration" {
  v="$(jq -r '.version' "$MANIFEST")"
  [ "$(printf '1.12.0\n%s\n' "$v" | sort -V | tail -1)" = "$v" ] && [ "$v" != "1.12.0" ]
  [ "$(jq -r '.plugins[] | select(.name=="dev-workflow") | .version' "$MARKETPLACE")" = "$v" ]
  jq -r '.description' "$MANIFEST" | grep -q '仕様宣言'
}

@test "skill frontmatter: version above 1.3.0" {
  v="$(awk '/^version:/{print $2; exit}' "$SKILL")"
  [ "$(printf '1.3.0\n%s\n' "$v" | sort -V | tail -1)" = "$v" ] && [ "$v" != "1.3.0" ]
}
