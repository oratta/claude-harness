#!/usr/bin/env bats
#
# Tests for capability: loops-self-verification-reference
# Spec: openspec/changes/skill-verification/specs/loops-self-verification-reference/spec.md
# Covers verification-guide.md scenarios S36-S41.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  REF="${PLUGIN_DIR}/references/self-verification.md"
}

# --- S36: リファレンスが中核原則を含む ---
@test "S36: self-verification.md exists and states the core principle" {
  [ -f "$REF" ]
  grep -q "完了は主張であり証明ではない" "$REF"
  grep -q "evidence を提示してから完了を宣言する" "$REF"
}

# --- S37: evidence の 4 種別が列挙されている ---
@test "S37: the 4 evidence kinds are enumerated" {
  grep -q "テスト出力" "$REF"
  grep -q "exit code" "$REF"
  grep -Eq "生成物の実在" "$REF"
  grep -q "実行結果ログ" "$REF"
}

# --- S38: 記載ルールが明記されている ---
@test "S38: the skill-side authoring rule is documented" {
  # 1 行参照 + スキル固有手順のみ
  grep -Eq "1 ?行参照" "$REF"
  grep -Eq "固有" "$REF"
  # 共通原則本文のコピー禁止
  grep -Eq "コピー.{0,8}(してはならない|しない|禁止|禁じ)" "$REF"
}

# --- S39: 中核原則の文言が SKILL.md に重複していない ---
@test "S39: the core principle sentence does not appear in any SKILL.md" {
  run bash -c "grep -rl '完了は主張であり証明ではない' ${PLUGIN_ROOT}/plugins/*/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' '"
  [ "$output" = "0" ]
}

# --- S40: 棚卸しリストに最低 7 スキルの実パスが記録されている ---
@test "S40: the audit list records the real paths of at least 7 target skills" {
  grep -q "対象スキル一覧" "$REF"
  for p in \
    "plugins/longrun/skills/longrun-plan/SKILL.md" \
    "plugins/worktree/skills/wt-setup/SKILL.md" \
    "plugins/worktree/skills/wt-clean/SKILL.md" \
    "plugins/daily-report/skills/daily-report/SKILL.md" \
    "plugins/weekly-report/skills/weekly-report/SKILL.md" \
    "plugins/infra/skills/infra-setup/SKILL.md" \
    "plugins/experience-to-skill/skills/experience-to-skill/SKILL.md"; do
    grep -qF "$p" "$REF"
  done
}

# --- S40 (追加検証): e2s-distill をパスに含む存在しないパスが 0 件 ---
@test "S40b: no bogus path containing 'e2s-distill' as a skill directory" {
  run bash -c "grep -E 'skills/e2s-distill/' '${REF}' | wc -l | tr -d ' '"
  [ "$output" = "0" ]
}

# --- S41: 対象外スキルに理由が記録されている ---
@test "S41: out-of-scope skills each carry a judgment reason" {
  # 対象外エントリが存在し、理由キーワード（理由/既に/成果物）が同一行に付随する
  run bash -c "grep -E '対象外' '${REF}' | grep -Ec '理由|既に|成果物|委譲|委ね|設定|分類'"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
