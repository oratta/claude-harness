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
  PATH_LINT="${PLUGIN_DIR}/tests/lib/template-path-lint.awk"
  FIXTURES="${PLUGIN_DIR}/tests/fixtures/template-paths"
}

# テンプレのパス表記検査。違反 0 件で exit 0、1 件以上で違反行を出して exit 1。
# LC_ALL=C はマルチバイトの扱いを awk 実装差から切り離すため（macOS awk 対策）。
lint_template_paths() {
  LC_ALL=C awk -f "$PATH_LINT" "$@"
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
# issue #116: プラグイン内相対のパス表記（scripts/… skills/… plugins/casting/…）は
# /casting:init の生成先 repo ルートから解決できないため、テンプレに含めない
# issue #137: 検出をコードスパンの先頭からスパン内の任意位置に広げる。検査ロジックは
# tests/lib/template-path-lint.awk に切り出し、下のフィクスチャで検査自体を検証する

@test "templates: no plugin-internal relative path notation in code spans" {
  run lint_template_paths "${PLUGIN_DIR}"/templates/*.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "path lint: flags a plugin-internal path that is not at the head of the code span" {
  run lint_template_paths "${FIXTURES}/violation-mid-span.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"scripts/casting-check.sh"* ]]
}

@test "path lint: flags a plugin-internal path inside a fenced code block" {
  run lint_template_paths "${FIXTURES}/violation-fenced-block.md"
  [ "$status" -eq 1 ]
  [[ "$output" == *"plugins/casting/scripts/casting-check.sh"* ]]
}

@test "path lint: passes install-path notation that contains the plugin directory names" {
  run lint_template_paths "${FIXTURES}/ok-install-path.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "path lint: passes forbidden tokens that sit in plain text outside code spans" {
  run lint_template_paths "${FIXTURES}/ok-plain-text-outside-span.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- marketplace 登録 ---

@test "marketplace: casting plugin is registered" {
  M="${REPO_ROOT}/.claude-plugin/marketplace.json"
  LC_ALL=C grep -qF -- '"name": "casting"' "$M"
  [ -f "${PLUGIN_DIR}/.claude-plugin/plugin.json" ]
}
