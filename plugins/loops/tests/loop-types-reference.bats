#!/usr/bin/env bats
#
# Tests for capability: loops-loop-types-reference
# Spec: openspec/changes/loops-plugin/specs/loops-loop-types-reference/spec.md
# Covers verification-guide.md scenarios S17-S20.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  REF="${PLUGIN_DIR}/references/loop-types.md"
}

# --- S17: 4 タイプ表 + 手放す対象 + ネイティブプリミティブ ---
@test "S17: 4-type table with relinquish targets and native primitives" {
  [ -f "$REF" ]
  for lt in "ターンベース" "ゴールベース" "タイムベース" "プロアクティブ"; do
    grep -q "$lt" "$REF"
  done
  for t in "検証ステップ" "停止条件" "トリガー" "プロンプト自体"; do
    grep -q "$t" "$REF"
  done
  grep -q "/goal" "$REF"
  grep -q "/loop" "$REF"
  grep -q "/schedule" "$REF"
}

# --- S18: 使い分けと具体例 ---
@test "S18: selection criteria and concrete examples present" {
  grep -Eq "使い分け|どういう業務|選ぶ" "$REF"
  grep -Eq "PR" "$REF"
  grep -Eq "テスト全 ?PASS|全 ?PASS|Lighthouse" "$REF"
}

# --- S19: 責務分離の節 + 宣言範囲 4 項目 ---
@test "S19: separation-of-concerns section with 4 declaration items" {
  grep -Eq "責務分離" "$REF"
  grep -q "発火時" "$REF"
  grep -q "推奨頻度" "$REF"
  grep -q "停止基準" "$REF"
  grep -q "実行環境の制約" "$REF"
}

# --- S20: 定期実行の配線がスコープ外 ---
@test "S20: scheduling wiring declared out of scope / caller responsibility" {
  grep -q "スケジューラ" "$REF"
  grep -q "呼び出し側の責務" "$REF"
  grep -Eq "実行方法非依存" "$REF"
}
