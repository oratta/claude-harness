#!/usr/bin/env bats
#
# Tests for capability: loops-state-convention
# Spec: openspec/changes/loops-plugin/specs/loops-state-convention/spec.md
# Covers verification-guide.md scenarios S32-S35.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  REF_DIR="${PLUGIN_DIR}/references"
  TMPL="${PLUGIN_DIR}/templates/state-template.md"
}

# --- S32: State 規約が 4 節を定義している ---
@test "S32: state convention defines path and 4 sections" {
  # placement convention appears somewhere under references
  grep -rq 'loops/state/<name>\.state\.md' "$REF_DIR"
  for s in "現在の作業" "前回の試行と結果" "人間への引き継ぎ待ち" "繰り越しタスク"; do
    grep -rq "$s" "$REF_DIR"
  done
}

# --- S33: 永続化の設計原則が明記されている ---
@test "S33: persistence principle documented" {
  grep -rq "エージェントは忘れるが、リポジトリは記憶する" "$REF_DIR"
}

# --- S34: テンプレートが 4 見出しを持つ ---
@test "S34: state-template.md has all 4 headings" {
  [ -f "$TMPL" ]
  for h in "現在の作業" "前回の試行と結果" "人間への引き継ぎ待ち" "繰り越しタスク"; do
    grep -Eq "^#+ .*${h}" "$TMPL"
  done
}

# --- S35: silent drop 禁止の注記がある ---
@test "S35: carryover section notes silent drop prohibition" {
  grep -q "silent drop" "$TMPL"
  grep -q "繰り越し" "$TMPL"
}
