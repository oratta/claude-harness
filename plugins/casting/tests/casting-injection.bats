#!/usr/bin/env bats
#
# casting-injection-map: 注入マップ正本（catalog/injection.md）の構造・整合要件
# spec: openspec/specs/casting-injection-map/spec.md
#   Requirement: 注入マップ正本の存在と構成 / 注入マップ行のタイミング語彙の固定 /
#                注入文書の置き場所規約 / SKILL.md からの参照 / カタログとの整合検査
#
# 観点名はハードコードせず catalog.md から実抽出して集合一致を検査する
# （カタログ改版時のドリフトを検出するため）。日本語語彙の照合は LC_ALL=C の
# grep -F / bash case のバイト列比較のみを使う（awk のマルチバイト比較は禁止）。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CATALOG="${PLUGIN_DIR}/catalog/catalog.md"
  INJECTION="${PLUGIN_DIR}/catalog/injection.md"
  SKILL="${PLUGIN_DIR}/skills/casting/SKILL.md"
}

# catalog.md の3グループ表（## グループ〜## 横断軸）から観点名（1列目セル）を抽出する
catalog_names() {
  sed -n '/^## グループ/,/^## 横断軸/p' "$CATALOG" \
    | LC_ALL=C grep '^|' \
    | cut -d'|' -f2 \
    | sed 's/^ *//; s/ *$//' \
    | LC_ALL=C grep -v '^-*$' \
    | LC_ALL=C grep -vxF '観点'
}

# injection.md の注入マップ表（## 14観点の注入マップ〜## 注入文書）から観点名を抽出する
map_names() {
  sed -n '/^## 14観点の注入マップ/,/^## 注入文書/p' "$INJECTION" \
    | LC_ALL=C grep '^|' \
    | cut -d'|' -f2 \
    | sed 's/^ *//; s/ *$//' \
    | LC_ALL=C grep -v '^-*$' \
    | LC_ALL=C grep -vxF '観点'
}

# 注入マップ表の行のうち観点行（ヘッダ・区切りを除く）を返す
map_rows() {
  sed -n '/^## 14観点の注入マップ/,/^## 注入文書/p' "$INJECTION" \
    | LC_ALL=C grep '^|' \
    | LC_ALL=C grep -v '^|---' \
    | LC_ALL=C grep -v '^| 観点 '
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

@test "injection: catalog extraction yields exactly 14 unique perspectives (sanity)" {
  [ "$(catalog_names | wc -l | tr -d ' ')" -eq 14 ]
  [ -z "$(catalog_names | LC_ALL=C sort | LC_ALL=C uniq -d)" ]
}

@test "injection: map rows equal the catalog perspective set (no missing, no extra, no dup)" {
  [ -z "$(map_names | LC_ALL=C sort | LC_ALL=C uniq -d)" ]
  diff <(catalog_names | LC_ALL=C sort) <(map_names | LC_ALL=C sort)
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
# タイミングセルを「＋」で分割し、各トークンが8語彙のいずれかと完全一致することを検査する
# （部分一致では「PR 時レンズ＋未定義」等が素通りするため）。

@test "injection: every map row's timing tokens exactly match the defined vocabulary" {
  while IFS= read -r row; do
    timing_cell=$(printf '%s' "$row" | cut -d'|' -f3 | sed 's/^ *//; s/ *$//')
    [ -n "$timing_cell" ]
    while IFS= read -r tok; do
      tok=$(printf '%s' "$tok" | sed 's/^ *//; s/ *$//')
      [ -n "$tok" ]
      case "$tok" in
        "常時"|"毎ターンの配役判定"|"PR 時レンズ"|"アクション直前ゲート"|"定期監査"|"注入しない"|"起票・選定時"|"設計時") ;;
        *) echo "undefined timing token: [$tok] in row: $row"; return 1 ;;
      esac
    done < <(printf '%s\n' "$timing_cell" | sed 's/＋/\n/g')
  done < <(map_rows)
}

# --- Scenario: マップ行の後ろ3列（タイミング・配線先・注入文書）が非空 ---

@test "injection: every map row has non-empty timing, wiring and document cells" {
  while IFS= read -r row; do
    for f in 3 4 5; do
      cell=$(printf '%s' "$row" | cut -d'|' -f$f | sed 's/^ *//; s/ *$//')
      if [ -z "$cell" ]; then
        echo "empty cell (field $f) in row: $row"
        return 1
      fi
    done
  done < <(map_rows)
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
