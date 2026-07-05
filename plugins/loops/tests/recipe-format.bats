#!/usr/bin/env bats
#
# Tests for capability: loops-recipe-format
# Spec: openspec/changes/loops-plugin/specs/loops-recipe-format/spec.md
# Covers verification-guide.md scenarios S26-S31.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  FMT="${PLUGIN_DIR}/references/recipe-format.md"
  TMPL="${PLUGIN_DIR}/templates/recipe-template.md"
}

# --- S26: 規約文書が固定見出し 7 項目を列挙している ---
@test "S26: recipe-format.md lists the 7 fixed headings" {
  [ -f "$FMT" ]
  for h in "ループ型" "目的" "起動コマンド" "停止基準" "前提" "コスト注意" "エスカレーション"; do
    grep -q "$h" "$FMT"
  done
}

# --- S27: 停止基準が必須項目として明記されている ---
@test "S27: stop criteria is documented as mandatory with 3 forms" {
  grep -q "停止基準" "$FMT"
  grep -Eq "必須" "$FMT"
  grep -q "最大試行数" "$FMT"
  grep -q "時間" "$FMT"
  grep -q "定量ゴール" "$FMT"
}

# --- S28: テンプレートが 7 見出しを持つ ---
@test "S28: recipe-template.md has all 7 headings" {
  [ -f "$TMPL" ]
  for h in "ループ型" "目的" "起動コマンド" "停止基準" "前提" "コスト注意" "エスカレーション"; do
    grep -Eq "^#+ .*${h}" "$TMPL"
  done
}

# --- S29: 起動コマンド節にネイティブプリミティブの注記がある ---
@test "S29: template startup section notes native primitives and bans custom CLI" {
  grep -q "/goal" "$TMPL"
  grep -q "/loop" "$TMPL"
  grep -q "/schedule" "$TMPL"
  grep -Eq "独自 ?CLI|ラッパー" "$TMPL"
}

# --- S30: 宣言範囲の 4 項目が規約に定義されている ---
@test "S30: recipe-format.md defines the 4 declaration-scope items" {
  grep -q "発火時" "$FMT"
  grep -q "推奨頻度" "$FMT"
  grep -q "停止基準" "$FMT"
  grep -q "実行環境の制約" "$FMT"
}

# --- S31: スケジューラ登録が呼び出し側の責務とされている ---
@test "S31: scheduler registration declared as caller responsibility" {
  grep -q "スケジューラ" "$FMT"
  grep -q "呼び出し側の責務" "$FMT"
  grep -Eq "スコープ外" "$FMT"
}
