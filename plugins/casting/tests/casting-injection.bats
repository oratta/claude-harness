#!/usr/bin/env bats
#
# casting-injection-map: 注入マップ正本（catalog/injection.md）の構造・整合要件
# spec: openspec/specs/casting-injection-map/spec.md
#   Requirement: 注入マップ正本の存在と構成 / 注入マップ行のタイミング語彙の固定 /
#                注入文書の置き場所規約 / SKILL.md からの参照 / カタログとの整合検査

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CATALOG="${PLUGIN_DIR}/catalog/catalog.md"
  INJECTION="${PLUGIN_DIR}/catalog/injection.md"
  SKILL="${PLUGIN_DIR}/skills/casting/SKILL.md"
}

# --- Scenario: 注入マップに catalog_version と14観点が入っている ---

@test "injection: file exists" {
  [ -f "$INJECTION" ]
}

@test "injection: catalog_version matches catalog version" {
  catalog_ver=$(head -5 "$CATALOG" | LC_ALL=C grep -E '^version: [0-9]+$' | cut -d' ' -f2)
  [ -n "$catalog_ver" ]
  head -5 "$INJECTION" | grep -qx "catalog_version: ${catalog_ver}"
}

@test "injection: all 14 perspectives appear as map rows" {
  local names=(
    "法的・規制" "財務・コスト" "信用・レピュテーション" "情報セキュリティ・プライバシー"
    "資産・回復可能性" "報告の正確性"
    "事業方向性・戦略整合" "優先順位・資源配分" "開発スピード・機会損失" "運用工数・維持"
    "技術設計・品質" "ユーザー価値・市場"
    "美意識・ブランド感覚" "感情的受容度"
  )
  for n in "${names[@]}"; do
    LC_ALL=C grep -qF -- "| ${n} " "$INJECTION"
  done
}

# --- Scenario: タイミング語彙の8分類が定義されている ---

@test "injection: vocabulary section defines all 8 timings" {
  local timings=(
    "常時" "毎ターンの配役判定" "PR 時レンズ" "アクション直前ゲート"
    "定期監査" "注入しない" "起票・選定時" "設計時"
  )
  for t in "${timings[@]}"; do
    LC_ALL=C grep -qF -- "$t" "$INJECTION"
  done
}

# --- Scenario: 全行のタイミングが定義済み語彙に収まる ---
# 注入マップ表の行（1列目=観点名）の2列目を取り出し、定義済み8語彙のいずれかを
# 含むことを確認する。照合は grep -F のみ（awk のマルチバイト比較は使わない）。

@test "injection: every map row uses only defined timing vocabulary" {
  local names=(
    "法的・規制" "財務・コスト" "信用・レピュテーション" "情報セキュリティ・プライバシー"
    "資産・回復可能性" "報告の正確性"
    "事業方向性・戦略整合" "優先順位・資源配分" "開発スピード・機会損失" "運用工数・維持"
    "技術設計・品質" "ユーザー価値・市場"
    "美意識・ブランド感覚" "感情的受容度"
  )
  for n in "${names[@]}"; do
    row=$(LC_ALL=C grep -F -- "| ${n} " "$INJECTION" | head -1)
    [ -n "$row" ]
    timing_cell=$(printf '%s' "$row" | cut -d'|' -f3)
    matched=0
    for t in "常時" "毎ターンの配役判定" "PR 時レンズ" "アクション直前ゲート" \
             "定期監査" "注入しない" "起票・選定時" "設計時"; do
      if printf '%s' "$timing_cell" | LC_ALL=C grep -qF -- "$t"; then
        matched=1
        break
      fi
    done
    [ "$matched" -eq 1 ]
  done
}

# --- Scenario: 5節の存在 ---

@test "injection: carries the five required sections" {
  LC_ALL=C grep -qF -- "タイミングの語彙" "$INJECTION"
  LC_ALL=C grep -qF -- "注入マップ" "$INJECTION"
  LC_ALL=C grep -qF -- "置き場所" "$INJECTION"
  LC_ALL=C grep -qF -- "実装済み" "$INJECTION"
  LC_ALL=C grep -qF -- "未実装" "$INJECTION"
}

# --- Scenario: policies 規約と slug 対応表がある ---

@test "injection: documents the policies path convention and slugs" {
  LC_ALL=C grep -qF -- ".claude/casting/policies/" "$INJECTION"
  for slug in "regulation" "budget" "brand" "phase" "priority" "maintenance"; do
    LC_ALL=C grep -qF -- "$slug" "$INJECTION"
  done
}

# --- Scenario: SKILL.md にポインタがある ---

@test "skill: references injection.md as the injection-design source of truth" {
  LC_ALL=C grep -qF -- "catalog/injection.md" "$SKILL"
}
