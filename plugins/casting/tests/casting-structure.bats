#!/usr/bin/env bats
#
# casting-catalog / casting-project-files: 構成物の構造要件
# spec: openspec/specs/casting-catalog/spec.md
#   Requirement: カタログ正本の存在と構成 / 常時ロード層の返信前チェック rule
# spec: openspec/specs/casting-project-files/spec.md
#   Requirement: 3層デフォルトの配置規約 / 判例台帳の形式

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  CATALOG="${PLUGIN_DIR}/catalog/catalog.md"
}

# --- Scenario: カタログに version と14観点が入っている ---

@test "catalog: front matter declares version 1" {
  head -5 "$CATALOG" | grep -qx 'version: 1'
}

@test "catalog: all 14 perspectives are present" {
  local names=(
    "法的・規制" "財務・コスト" "信用・レピュテーション" "情報セキュリティ・プライバシー"
    "資産・回復可能性" "報告の正確性"
    "事業方向性・戦略整合" "優先順位・資源配分" "開発スピード・機会損失" "運用工数・維持"
    "技術設計・品質" "ユーザー価値・市場"
    "美意識・ブランド感覚" "感情的受容度"
  )
  for n in "${names[@]}"; do
    LC_ALL=C grep -qF -- "| ${n} " "$CATALOG"
  done
}

# --- Scenario: 列定義がカタログ内に存在する ---

@test "catalog: legend defines all five column names" {
  for col in "観点" "この観点が要る論点の条件" "判断基準の出どころ" "移譲に必要な文書" "既定の担い手"; do
    LC_ALL=C grep -qF -- "$col" "$CATALOG"
  done
}

# --- Scenario: 変更手続きの2ルートが明記されている ---

@test "catalog: documents both change routes" {
  LC_ALL=C grep -qF -- "軽量ルート" "$CATALOG"
  LC_ALL=C grep -qF -- "重量ルート" "$CATALOG"
  LC_ALL=C grep -qF -- "変更記録" "$CATALOG"
}

# --- Scenario: rule が薄く保たれている / README の一覧に載っている ---

@test "rule: perspective-casting.md stays within 30 lines and keeps the 5 steps" {
  RULE="${REPO_ROOT}/rules/perspective-casting.md"
  [ -f "$RULE" ]
  [ "$(wc -l < "$RULE" | tr -d ' ')" -le 30 ]
  LC_ALL=C grep -qF -- "聖域" "$RULE"
  LC_ALL=C grep -qF -- "判例台帳" "$RULE"
  LC_ALL=C grep -qF -- "plugins/casting/catalog/catalog.md" "$RULE"
}

@test "rule: listed in rules/README.md" {
  LC_ALL=C grep -qF -- "perspective-casting.md" "${REPO_ROOT}/rules/README.md"
}

# --- Scenario: 3層の配置と判例台帳形式が定義されている ---

@test "skill: defines the three layers and the session declaration" {
  SKILL="${PLUGIN_DIR}/skills/casting/SKILL.md"
  LC_ALL=C grep -qF -- "project.md" "$SKILL"
  LC_ALL=C grep -qF -- "local.md" "$SKILL"
  LC_ALL=C grep -qF -- "セッション" "$SKILL"
}

@test "templates: both carry catalog_version 1 front matter" {
  head -3 "${PLUGIN_DIR}/templates/project.md" | grep -qx 'catalog_version: 1'
  head -3 "${PLUGIN_DIR}/templates/precedents.md" | grep -qx 'catalog_version: 1'
}

@test "template precedents: example carries the four fields" {
  T="${PLUGIN_DIR}/templates/precedents.md"
  for f in "観点" "経路" "帰結" "還元"; do
    LC_ALL=C grep -qF -- "- ${f}: " "$T"
  done
}

# --- Scenario: テンプレのパス表記が生成先 repo ルートから解決できる ---
# issue #116: プラグイン内相対のパス表記（`scripts/…` `skills/…` `plugins/casting/…`）は
# /casting:init の生成先 repo ルートから解決できないため、テンプレに含めない

@test "templates: no plugin-internal relative path notation in backticks" {
  local bt='`'
  for t in "${PLUGIN_DIR}"/templates/*.md; do
    run grep -nE "${bt}(scripts/|skills/|plugins/casting/)" "$t"
    [ "$status" -ne 0 ]
  done
}

# --- marketplace 登録 ---

@test "marketplace: casting plugin is registered" {
  M="${REPO_ROOT}/.claude-plugin/marketplace.json"
  LC_ALL=C grep -qF -- '"name": "casting"' "$M"
  [ -f "${PLUGIN_DIR}/.claude-plugin/plugin.json" ]
}

# --- 検出項目数の表記と実装の一致 ---
#
# spec: openspec/specs/casting-project-files/spec.md
#   Requirement: 検出項目数の表記と実装の一致
#
# 検出0（malformed-row）を後から足したときに、文書側が「4項目」のまま取り残された
# 事故（#141）の再発防止。実装が報告する検出カテゴリ（report の第1引数）の異なり数を
# スクリプトから機械的に数え、「N項目」と書いている文書がその数と一致するかを見る。

# 実装が持つ検出カテゴリの異なり数を casting-check.sh から数える。
detection_category_count() {
  LC_ALL=C grep -oE 'report "[a-z-]+"' "${PLUGIN_DIR}/scripts/casting-check.sh" \
    | LC_ALL=C sed -E 's/report "(.*)"/\1/' \
    | LC_ALL=C sort -u \
    | wc -l | tr -d ' '
}

@test "check: detection categories in casting-check.sh are the documented five" {
  local expected=(
    "catalog-external-precedent" "malformed-row" "repeated-not-issue"
    "unknown-vocab" "version-mismatch"
  )
  local actual
  actual="$(LC_ALL=C grep -oE 'report "[a-z-]+"' "${PLUGIN_DIR}/scripts/casting-check.sh" \
    | LC_ALL=C sed -E 's/report "(.*)"/\1/' | LC_ALL=C sort -u | tr '\n' ' ')"
  [ "$actual" = "${expected[*]} " ]
}

@test "docs: item-count wording in README, SKILL, script and plugin.json matches the implementation" {
  local n
  n="$(detection_category_count)"
  [ "$n" -ge 1 ]

  local docs=(
    "${PLUGIN_DIR}/README.md"
    "${PLUGIN_DIR}/skills/casting/SKILL.md"
    "${PLUGIN_DIR}/scripts/casting-check.sh"
    "${PLUGIN_DIR}/.claude-plugin/plugin.json"
  )
  local d
  for d in "${docs[@]}"; do
    # 実装の数と同じ「N項目」が書かれていること。
    if ! LC_ALL=C grep -qF -- "${n}項目" "$d"; then
      echo "実装の検出カテゴリ数は ${n} だが ${d} に「${n}項目」が無い" >&2
      LC_ALL=C grep -nE '[0-9]+項目' "$d" >&2 || true
      return 1
    fi
    # 別の数の「M項目」が残っていないこと（片側だけ直した状態を落とす）。
    # 1行に複数の表記が混ざる場合があるので、行ではなく出現単位で数える。
    local stale
    stale="$(LC_ALL=C grep -oE '[0-9]+項目' "$d" | LC_ALL=C grep -vF -- "${n}項目" || true)"
    if [ -n "$stale" ]; then
      echo "実装の検出カテゴリ数は ${n} だが ${d} に古い表記が残っている: ${stale}" >&2
      return 1
    fi
  done
}

@test "docs: marketplace.json casting description matches the category count" {
  local n
  n="$(detection_category_count)"
  local desc
  desc="$(python3 - "${REPO_ROOT}/.claude-plugin/marketplace.json" <<'PY'
import json, sys
mk = json.load(open(sys.argv[1], encoding="utf-8"))
for p in mk["plugins"]:
    if p.get("name") == "casting":
        print(p["description"])
        break
else:
    raise SystemExit("casting entry not found in marketplace.json")
PY
)"
  [ -n "$desc" ]
  printf '%s\n' "$desc" | LC_ALL=C grep -qF -- "${n}項目"
  # 別の数が残っていないこと（出現単位で数える）。
  local stale
  stale="$(printf '%s\n' "$desc" | LC_ALL=C grep -oE '[0-9]+項目' | LC_ALL=C grep -vF -- "${n}項目" || true)"
  [ -z "$stale" ]
}
