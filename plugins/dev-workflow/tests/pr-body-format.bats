#!/usr/bin/env bats
#
# pr-body-format: エージェントが書く PR / issue 本文フォーマット（issue #47。
# #205 で loops から dev-workflow/references へ移設）
#
# reference は実行コードではないため、仕様（5 セクション順・翻訳例・軽量モード・
# 2 節追加・参照配線）の記述が存在することを grep で検証する。
#
# spec: dev-workflow-shared-references（旧 loops-pr-body-format の reference 要件を引き継ぐ）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REF="${PLUGIN_DIR}/references/pr-body-format.md"
  ISSUEIFY="${PLUGIN_DIR}/skills/issueify/SKILL.md"
}

# --- Requirement: PR 本文フォーマット reference ---

@test "reference: pr-body-format.md exists" {
  [ -f "$REF" ]
}

@test "reference: 5 sections appear in the prescribed order" {
  python3 - "$REF" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
sections = [
    "位置づけ",
    "実装方針",
    "リスク（重い順）",
    "動作確認ポイント",
    "実装メモ",
]
pos = -1
for s in sections:
    i = text.find("## " + s)
    assert i >= 0, f"section heading missing: {s}"
    assert i > pos, f"section heading out of order: {s}"
    pos = i
PY
}

@test "reference: Closes trailer is part of the format" {
  grep -q 'Closes #' "$REF"
}

@test "reference: details collapse is restricted to regenerable output" {
  grep -q '<details>' "$REF"
  grep -q '再生成可能' "$REF"
  grep -E '設計判断.*(入れない|入れてはならない)' "$REF" >/dev/null
}

# --- Requirement: 二重読者のための設計原則 ---

@test "reference: same-information-once principle is stated" {
  grep -E '同じ情報を.?2.?回書かない' "$REF" >/dev/null
}

@test "reference: translation discipline has at least 3 good/bad example pairs" {
  python3 - "$REF" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
assert text.count("❌") >= 3, f"bad examples: {text.count('❌')}"
assert text.count("✅") >= 3, f"good examples: {text.count('✅')}"
PY
}

@test "reference: negative sections require a reason even when empty" {
  grep -q '根拠' "$REF"
  grep -q '「なし」' "$REF"
}

@test "reference: risk section requires likelihood and impact weighting" {
  grep -q '起きやすさ' "$REF"
  grep -q '起きたときの影響' "$REF"
  grep -E '高/中/低' "$REF" >/dev/null
  grep -q '戻し方' "$REF"
}

@test "reference: positioning section descends from product goal in 3 lines" {
  grep -q '上から降りる' "$REF"
  grep -E '目指していること' "$REF" >/dev/null
}

@test "reference: line limits are specified" {
  grep -E '最大.?[0-9]+.?(行|項目)' "$REF" >/dev/null
}

# --- Requirement: 誇張防止の検証紐付け制約 ---

@test "reference: claims must be verifiable via verification checklist (D-5)" {
  grep -E '動作確認ポイントで検証できないこと.*(書いてはならない|書かない)' "$REF" >/dev/null
}

@test "reference: verification items use operation-to-expected-result form" {
  grep -q '期待される結果' "$REF"
}

# --- Requirement: 軽量モードの規定 ---

@test "reference: lightweight mode defines the 2 mandatory sections" {
  grep -q '軽量モード' "$REF"
  python3 - "$REF" <<'PY'
import sys, re
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"軽量モード", text)
tail = text[m.start():]
assert "位置づけ" in tail, "lightweight mode must reference section 1"
assert "動作確認ポイント" in tail, "lightweight mode must reference verification section"
PY
}

@test "reference: lightweight mode requires a reason line in the PR body" {
  grep -E '軽量モード適用.*理由' "$REF" >/dev/null
}

@test "reference: when unsure, full format wins" {
  grep -E '迷った(ら|場合).*(5 ?節|フル)' "$REF" >/dev/null
}

# --- Requirement: issue ドラフトへの承認判断 2 節（正本は issueify） ---

@test "reference: issue body type names issueify's new path as the generation source" {
  grep -qF 'plugins/dev-workflow/skills/issueify/SKILL.md' "$REF"
  ! grep -q 'loops-issueify' "$REF"
  ! grep -q 'loops-dev-agent-install' "$REF"
}

@test "issueify: draft structure gains the 2 approval sections before existing 4" {
  python3 - "$ISSUEIFY" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
i_change = text.find("これで何が変わるか")
i_cost = text.find("やらないとどうなるか")
i_overview = text.find("**概要**")
assert i_change >= 0, "missing: これで何が変わるか"
assert i_cost >= 0, "missing: やらないとどうなるか"
assert i_overview >= 0, "existing 概要 section must remain"
assert i_change < i_overview and i_cost < i_overview, "new sections must precede 概要"
PY
}
