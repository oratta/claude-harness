#!/usr/bin/env bats
#
# Tests for capability: loops-goalify-skill
# Spec: openspec/changes/loops-plugin/specs/loops-goalify-skill/spec.md
# Covers verification-guide.md scenarios S9-S16 (static portions).

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  SKILL="${PLUGIN_DIR}/skills/loops-goalify/SKILL.md"
}

# --- S9/S10: テキスト / ファイルパス両入力 ---
@test "S9/S10: accepts both inline text and file path input" {
  [ -f "$SKILL" ]
  grep -q "テキスト" "$SKILL"
  grep -Eq "ファイルパス|ファイルの内容" "$SKILL"
}

# --- S11/S12: 不足分のみヒアリング、全揃えば 0 問 ---
@test "S11/S12: hears only missing among 4 aspects, 0 questions when complete" {
  grep -q "不足" "$SKILL"
  grep -q "AskUserQuestion" "$SKILL"
  grep -Eq "0 ?問|ゼロ問|質問しない|そのまま生成" "$SKILL"
  # 4 aspects
  grep -q "成功基準" "$SKILL"
  grep -q "停止条件" "$SKILL"
  grep -Eq "スコープ境界|スコープ" "$SKILL"
  grep -q "前提" "$SKILL"
}

# --- S13: goal ブリーフ 5 見出し ---
@test "S13: goal brief has 5 headings" {
  grep -q 'goals/<name>.goal.md' "$SKILL"
  for h in "目的" "成功基準" "制約" "参照パス" "エスカレーション条件"; do
    grep -q "$h" "$SKILL"
  done
}

# --- S14: 成功基準はコマンド + 期待値、主観禁止 ---
@test "S14: success criteria = command + expected value, subjective banned" {
  grep -Eq "コマンド" "$SKILL"
  grep -Eq "期待値" "$SKILL"
  grep -Eq "主観" "$SKILL"
}

# --- S15: /goal 起動コマンド 1 行 ---
@test "S15: emits a one-line /goal launch command" {
  grep -q "/goal" "$SKILL"
  grep -Eq "1 ?行" "$SKILL"
}

# --- S16: レシピ昇格の促し ---
@test "S16: prompts recipe promotion" {
  grep -Eq "昇格" "$SKILL"
  grep -q "recipes/" "$SKILL"
}

# --- interview methodology reference ---
@test "goalify references plan-interview-methodology.md" {
  grep -q 'plan-interview-methodology.md' "$SKILL"
}
