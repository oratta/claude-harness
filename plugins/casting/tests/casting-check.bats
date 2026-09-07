#!/usr/bin/env bats
#
# casting-catalog / casting-project-files: casting-check.sh の7検出項目
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

# --- Scenario: 宣言ファイル delegation.md は check の対象外（issue #207） ---

@test "ok fixture: a delegation.md with a 3-column tools table is not reported as malformed-row" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [ -f "${FIXTURES}/ok/.claude/casting/delegation.md" ]
  [ "$status" -eq 0 ]
  [[ "$output" != *"delegation.md"* ]]
}

# --- Scenario: 7種の検出がそれぞれ報告される（⓪malformed-row はファイル末尾） ---

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

# --- 回帰: #139（check モードでも同じ経路を検出する） ---

@test "over-column fixture: a row that splits into more than 5 columns is reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/over-column"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed-row"* ]]
  [[ "$output" == *"6列以上"* ]]
}

@test "unclosed-comment fixture: an unbalanced HTML comment is reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/unclosed-comment"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unclosed-comment"* ]]
  [[ "$output" == *"project.md"* ]]
}

@test "local-malformed fixture: a broken local.md is reported with its own path" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/local-malformed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed-row"* ]]
  [[ "$output" == *"local.md"* ]]
}

@test "ok fixture: a balanced HTML comment is not reported as unclosed" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/ok"
  [[ "$output" != *"unclosed-comment"* ]]
}

@test "template project.md: the commented-out example is balanced and not reported" {
  REPO="${BATS_TEST_TMPDIR}/template-repo"
  mkdir -p "${REPO}/.claude/casting"
  cp "${PLUGIN_DIR}/templates/project.md" "${REPO}/.claude/casting/project.md"
  run "$SCRIPT" --catalog "$CATALOG" "$REPO"
  [ "$status" -eq 0 ]
}

# --- 回帰: #145 レビュー（開閉の「個数」判定と stripped_copy の行範囲走査のずれ） ---
#
# 個数比較は (A) HTML コメントを1つも持たず本文に `-->` があるだけの正常な配役表を
# 止め、(B) 対応の無い `-->` と本物の閉じ忘れ `<!--` が釣り合うと検出を落とし、
# (C) 1行で閉じたコメントが以降を EOF まで飲み込む事故を報告しない。
# 判定は「開いた `<!--` が閉じられているか」で行い、対応の無い `-->` は無視する。

@test "stray-close-arrow fixture: a lone --> with no HTML comment is not reported" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/stray-close-arrow"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unclosed-comment"* ]]
}

@test "stray-close-arrow fixture: resolve keeps the human-written row" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/stray-close-arrow"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト |"*"| 主 | project |"* ]]
}

@test "stray-close-plus-unclosed fixture: an unclosed <!-- is reported even when a stray --> balances the count" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/stray-close-plus-unclosed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unclosed-comment"* ]]
  [[ "$output" == *"project.md"* ]]
}

@test "stray-close-plus-unclosed fixture: resolve refuses instead of silently dropping the swallowed row" {
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/stray-close-plus-unclosed"
  [ "$status" -eq 1 ]
  [[ "$output" != *"| project |"* ]]
}

@test "inline-comment fixture: a comment closed on its own line does not swallow the rows after it" {
  run "$SCRIPT" --catalog "$CATALOG" "${FIXTURES}/inline-comment"
  [ "$status" -eq 0 ]
  run "$SCRIPT" resolve --catalog "$CATALOG" "${FIXTURES}/inline-comment"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| 財務・コスト |"*"| 主 | project |"* ]]
}
