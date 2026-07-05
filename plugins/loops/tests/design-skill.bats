#!/usr/bin/env bats
#
# Tests for capability: loops-design-skill
# Spec: openspec/changes/loops-plugin/specs/loops-design-skill/spec.md
# Covers verification-guide.md scenarios S1-S8 (static portions).

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  SKILL="${PLUGIN_DIR}/skills/loops-design/SKILL.md"
}

# --- S1: 選択フレームワークの 4 手放す対象 x 4 タイプ ---
@test "S1: selection framework maps 4 relinquish targets to 4 loop types" {
  [ -f "$SKILL" ]
  for t in "検証ステップ" "停止条件" "トリガー" "プロンプト自体"; do
    grep -q "$t" "$SKILL"
  done
  for lt in "ターンベース" "ゴールベース" "タイムベース" "プロアクティブ"; do
    grep -q "$lt" "$SKILL"
  done
}

# --- S2: loop-types リファレンスを参照している ---
@test "S2: references loop-types.md" {
  grep -q 'references/loop-types.md' "$SKILL"
}

# --- S4: 停止基準必須ゲートが明記されている ---
@test "S4: stop-criteria mandatory output gate documented" {
  grep -q "停止基準" "$SKILL"
  grep -Eq "確定.*(まで|しない).*(出力|レシピ)|出力しない" "$SKILL"
}

# --- S5: Bad Loop 検査 4 項目が定義されている ---
@test "S5: Bad Loop check with 4 items documented" {
  grep -q "停止基準の欠如" "$SKILL"
  grep -q "検証なき成功宣告" "$SKILL"
  grep -q "報酬ハッキング" "$SKILL"
  grep -q "過剰な実行頻度" "$SKILL"
}

# --- S7: 出力レシピが 7 見出し準拠を指示 ---
@test "S7: output recipe must follow the 7 headings" {
  for h in "ループ型" "目的" "起動コマンド" "停止基準" "前提" "コスト注意" "エスカレーション"; do
    grep -q "$h" "$SKILL"
  done
  grep -q 'references/recipe-format.md' "$SKILL"
}

# --- S8: 起動コマンドはネイティブプリミティブ / 独自 CLI 禁止 ---
@test "S8: startup command is native primitive, custom CLI banned" {
  grep -q "/goal" "$SKILL"
  grep -q "/loop" "$SKILL"
  grep -q "/schedule" "$SKILL"
  grep -Eq "独自 ?CLI|ラッパー" "$SKILL"
}
