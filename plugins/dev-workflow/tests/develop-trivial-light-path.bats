#!/usr/bin/env bats
# #1584: 本体が通す軽い修正の契約と、文書中の照合コマンドの実測。
setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CRITERIA="$PLUGIN_DIR/skills/develop/references/decision-criteria.md"
  REVIEWER="$PLUGIN_DIR/skills/develop/references/roles/spec-reviewer.md"
  SKILL="$PLUGIN_DIR/skills/develop/SKILL.md"
  GATE="$PLUGIN_DIR/skills/develop/references/roles/gate-runner.md"
  PREPARE="$PLUGIN_DIR/skills/pr-review-gate/stages/prepare.md"
  PASS="$PLUGIN_DIR/skills/pr-review-gate/stages/pass.md"
}
light_section() {
  LC_ALL=C awk '/^### /{f=0} index($0,"### 仕様化しないが軽く通す（軽い通し方）")==1{f=1} f' "$CRITERIA"
}
@test "criteria: six kinds distinguish unchanged behavior from an unambiguous bug fix" {
  light_section | grep -q '既存のテストかチェック'
  light_section | grep -q 'どれか 1 つ'
  for kind in typo lint コメント フォーマット 設定値; do
    light_section | grep "$kind" | grep -q '挙動を変えない'
  done
  light_section | grep 'ワンライナー fix' | grep -q '直し方に選択肢がない'
  light_section | grep 'ワンライナー fix' | grep -q '挙動が変わることを条件外の理由にしない'
}
@test "criteria: main agent preserves the record and gate in seven steps" {
  [ "$(light_section | grep -cE '^[1-7]\. ')" -eq 7 ]
  light_section | grep -q '新しいテストと W の起動'
  light_section | grep -q '記録先・判断の記録・pr-review-gate'
  light_section | grep -q '整理 → 判定 → Draft PR → 判断の記録'
  light_section | grep -q '当てないなら Draft PR を作らず'
  light_section | grep -q 'unmanned.*agent-review:pending'
  light_section | grep -q '迷ったら当てず.*主に聞かない'
}
@test "criteria: fallbacks start a new spec worker and recheck gate prerequisites" {
  light_section | grep -q '途中.*commit.*段: spec'
  light_section | grep -q '原因: 軽い通し方の条件外'
  light_section | grep -q '通常のレビュー.*failed'
  light_section | grep -q '通し方:.*投稿し直さない'
  light_section | grep -q '前提確認と重さ判定'
  grep 'テスト作成は全経路で必須' "$CRITERIA" | grep -q '軽い通し方だけ'
  grep 'テスト作成は全経路で必須' "$CRITERIA" | grep -q 'W が起こされる経路'
}
@test "decision contract: main posts the three exact lines and prepare reads the latest decision" {
  row="$(grep '^| 軽い通し方の行' "$REVIEWER")"
  printf '%s\n' "$row" | grep -qF '^通し方: 軽い$'
  printf '%s\n' "$row" | grep -qF '^種類: (typo|lint|コメント|フォーマット|ワンライナー fix|設定値)$'
  printf '%s\n' "$row" | grep -qF '^確かめ方: .+'
  for phrase in 本体 最新の仕様化判断 前提確認 'R1 は起こされない'; do
    printf '%s\n' "$row" | grep -q "$phrase"
  done
}
