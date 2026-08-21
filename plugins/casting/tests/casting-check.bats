#!/usr/bin/env bats
#
# casting-catalog / casting-project-files: casting-check.sh の4検出項目
# spec: openspec/changes/casting-plugin/specs/casting-project-files/spec.md
#   Requirement: casting-check.sh の検出項目

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/casting-check.sh"
  CATALOG="${PLUGIN_DIR}/catalog/catalog.md"
  FIXTURES="${PLUGIN_DIR}/tests/fixtures"
}

# --- Scenario: 問題のないフィクスチャで exit 0 ---

@test "ok fixture: exits 0 with no findings" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [ "$status" -eq 0 ]
}

# --- Scenario: 4種の検出がそれぞれ報告される ---

@test "unknown-vocab fixture: reports the unknown perspective name and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/unknown-vocab"
  [ "$status" -eq 1 ]
  [[ "$output" == *"謎の観点"* ]]
  [[ "$output" == *"project.md"* ]]
}

@test "catalog-external-precedent fixture: reports the out-of-catalog precedent and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/catalog-external-precedent"
  [ "$status" -eq 1 ]
  [[ "$output" == *"カタログ外"* ]]
  [[ "$output" == *"precedents.md"* ]]
}

@test "repeated-not-issue fixture: reports the perspective repeated as not-an-issue and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/repeated-not-issue"
  [ "$status" -eq 1 ]
  [[ "$output" == *"信用・レピュテーション"* ]]
  [[ "$output" == *"論点じゃなかった"* ]]
}

@test "version-mismatch fixture: reports the catalog_version mismatch and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/version-mismatch"
  [ "$status" -eq 1 ]
  [[ "$output" == *"catalog_version"* ]]
  [[ "$output" == *"project.md"* ]]
}

# --- 補足: 未知語彙のフィクスチャは version 不一致など他項目を誤検出しない ---

@test "unknown-vocab fixture: does not also report a version mismatch" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/unknown-vocab"
  [[ "$output" != *"version-mismatch"* ]]
}

@test "ok fixture: catalog_version matches so no version-mismatch finding" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [[ "$output" != *"version-mismatch"* ]]
}

# --- 回帰: 1周目レビューの blocking 指摘（シェル堅牢性） ---

@test "missing-version fixture: reports the missing catalog_version instead of dying silently" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/missing-version"
  [ "$status" -eq 1 ]
  [[ "$output" == *"catalog_version が front matter に無い"* ]]
}

@test "no-front-matter fixture: treated as missing catalog_version without misparsing the body" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/no-front-matter"
  [ "$status" -eq 1 ]
  [[ "$output" == *"catalog_version が front matter に無い"* ]]
  [[ "$output" != *"unknown-vocab"* ]]
}

@test "tight-pipes fixture: rows without a space after the pipe are still linted" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/tight-pipes"
  [ "$status" -eq 1 ]
  [[ "$output" == *"謎のタイト観点"* ]]
  [[ "$output" != *"財務・コスト"* ]]
}

@test "trailing-space fixture: trailing spaces do not cause a false unknown-vocab" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/trailing-space"
  [ "$status" -eq 0 ]
}

@test "multi-perspective fixture: comma-separated perspectives are each validated" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/multi-perspective"
  [ "$status" -eq 0 ]
}

@test "malformed-row fixture: a row with fewer than 5 columns is reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/malformed-row"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed-row"* ]]
  [[ "$output" == *"5列未満"* ]]
}

# --- 検出5: 相談判例（経路「相談の上自走した」）の事後報告5要素 ---

@test "consultation-missing-element fixture: reports the missing report elements and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/consultation-missing-element"
  [ "$status" -eq 1 ]
  [[ "$output" == *"consultation-missing-element"* ]]
  # ブロック見出しと、欠けている要素名（各人格の主張・根拠・判例リンク）が列挙される
  [[ "$output" == *"相談を経たが事後報告が欠けた判例"* ]]
  [[ "$output" == *"各人格の主張"* ]]
  [[ "$output" == *"判例リンク"* ]]
}

# ラベルの存在だけを見る実装では、値が空のラベルを5つ並べただけのブロックが通ってしまう
# （実質的な事後報告を欠いた判例が無言で配布される fail-open）。fixture は空値・半角空白のみ・
# 全角スペースのみの3種を1ブロックに混ぜてあり、どれも欠落として数えることを固定する。
# 全角スペースを別建てにするのは、LC_ALL=C の [[:space:]] がこれを空白と見なさないため。
@test "consultation-empty-value fixture: labels present but with empty values are reported and exits 1" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/consultation-empty-value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"consultation-missing-element"* ]]
  [[ "$output" == *"5要素のラベルはあるが値が空の判例"* ]]
  # 5要素すべてが欠落として列挙される（半角空白のみの「- 根拠:」と全角スペースのみの「- 裁定:」を含む）
  [[ "$output" == *"論点"* ]]
  [[ "$output" == *"各人格の主張"* ]]
  [[ "$output" == *"裁定"* ]]
  [[ "$output" == *"根拠"* ]]
  [[ "$output" == *"判例リンク"* ]]
}

# 空白除去は「値が空か」の判定にだけ効かせる。値の先頭に全角スペースが混ざっていても、
# 実質的な中身があれば有効な値として扱う（過剰検出の回帰よけ）。
@test "consultation block: a value padded with a full-width space but carrying content passes" {
  local dir="${BATS_TEST_TMPDIR}/fullwidth-padded"
  mkdir -p "${dir}/.claude/casting"
  cat > "${dir}/.claude/casting/precedents.md" <<'PRECEDENTS'
---
catalog_version: 1
---

# 判例台帳

### 2026-08-21 全角スペースで字下げされた値

- 観点: 技術設計・品質
- 経路: 相談の上自走した
- 帰結: 論点じゃなかった（意見が一致し合意で確定）
- 還元: なし
- 論点: 　実装方式Aか方式Bか
- 各人格の主張: 　メインセッション「方式A」／見張りのハト「方式Aを支持」
- 裁定: 合意（方式A）
- 根拠: 判断基準の互換性優先の定め
- 判例リンク: 「2026-08-17 API の月額プランを Pro に上げるか」
PRECEDENTS
  run "$SCRIPT" --catalog "$CATALOG" "$dir"
  [ "$status" -eq 0 ]
  [[ "$output" != *"consultation-missing-element"* ]]
}

@test "ok fixture: a compliant consultation block and a note block without a route line pass" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [ "$status" -eq 0 ]
  [[ "$output" != *"consultation-missing-element"* ]]
}

# --- 回帰: macOS の sort/uniq がロケール照合で異なる日本語観点列を同一視する（LC_ALL=C 強制） ---

@test "distinct-not-issue fixture: two different multi-perspective strings are not merged into a repeated-not-issue" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/distinct-not-issue"
  [ "$status" -eq 0 ]
  [[ "$output" != *"repeated-not-issue"* ]]
}
