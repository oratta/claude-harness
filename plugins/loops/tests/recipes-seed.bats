#!/usr/bin/env bats
#
# Tests for capabilities: loops-goal-recipes, loops-time-recipes
# Spec: openspec/changes/goal-time-recipes/specs/loops-goal-recipes/spec.md
#       openspec/changes/goal-time-recipes/specs/loops-time-recipes/spec.md
# Covers verification-guide.md scenarios S51-S74.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  RECIPES="${PLUGIN_DIR}/recipes"
  GOAL_RECIPES=(goal-tests-green goal-acceptance-pass goal-lighthouse)
  TIME_RECIPES=(loop-pr-babysit cron-daily-report cron-weekly-report)
  HEADINGS=("ループ型" "目的" "起動コマンド" "停止基準" "前提" "コスト注意" "エスカレーション")
}

# Extract the body of a level-2 (##) markdown section whose heading contains $2.
recipe_section() {
  awk -v h="$2" '
    /^## / { if (inx) exit; if (index($0, h)) { inx=1; next } }
    inx { print }
  ' "$1"
}

# ============================================================
# loops-goal-recipes
# ============================================================

# --- S51: goal レシピ 3 ファイルが存在する ---
@test "S51: three goal recipe files exist" {
  for r in "${GOAL_RECIPES[@]}"; do
    [ -f "${RECIPES}/${r}.md" ]
  done
}

# --- S52: 固定見出し 7 種が grep で確認できる ---
@test "S52: each goal recipe has all 7 fixed headings" {
  for r in "${GOAL_RECIPES[@]}"; do
    f="${RECIPES}/${r}.md"
    for h in "${HEADINGS[@]}"; do
      grep -Eq "^#+ .*${h}" "$f"
    done
  done
}

# --- S53: ループ型がゴールベースと明記されている ---
@test "S53: each goal recipe declares goal-based loop type" {
  for r in "${GOAL_RECIPES[@]}"; do
    f="${RECIPES}/${r}.md"
    run recipe_section "$f" "ループ型"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "ゴールベース"
  done
}

# --- S54: goal-tests-green の成功基準がコマンド + 期待値 ---
@test "S54: goal-tests-green stop criteria has bats command and exit 0 / all pass" {
  f="${RECIPES}/goal-tests-green.md"
  run recipe_section "$f" "停止基準"
  [ "$status" -eq 0 ]
  echo "$output" | grep -Fq "find plugins -name '*.bats' -print0 | xargs -0 bats"
  echo "$output" | grep -Eq "exit 0|全 ?PASS|全て ?PASS"
}

# --- S55: goal-acceptance-pass の成功基準がコマンド + 期待値 ---
@test "S55: goal-acceptance-pass stop criteria references plan.md acceptance conditions" {
  f="${RECIPES}/goal-acceptance-pass.md"
  run recipe_section "$f" "停止基準"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "受け入れ条件"
  echo "$output" | grep -Eq "全て ?PASS|全 ?PASS"
  # 各項目をコマンド + 期待値として読み取る手順
  echo "$output" | grep -Eq "コマンド.*期待値|期待値"
}

# --- S56: goal-lighthouse の成功基準がスコア閾値 + 公式例 ---
@test "S56: goal-lighthouse stop criteria has score threshold 90 and 5 tries" {
  f="${RECIPES}/goal-lighthouse.md"
  run recipe_section "$f" "停止基準"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "90"
  echo "$output" | grep -Eq "5"
}

# --- S57: 主観基準が存在しない ---
@test "S57: no subjective success criteria in goal recipe stop sections" {
  for r in "${GOAL_RECIPES[@]}"; do
    f="${RECIPES}/${r}.md"
    section="$(recipe_section "$f" "停止基準")"
    for bad in "良くなったら" "十分に" "改善したら" "きれいに"; do
      if echo "$section" | grep -q "$bad"; then
        echo "subjective term '$bad' found in ${r}.md stop criteria"
        return 1
      fi
    done
  done
}

# --- S58: 各 goal レシピに最大試行数のデフォルト値 + 変更方法 ---
@test "S58: each goal recipe has a numeric max-tries default and change method" {
  for r in "${GOAL_RECIPES[@]}"; do
    f="${RECIPES}/${r}.md"
    section="$(recipe_section "$f" "停止基準")"
    # 具体的な数値のデフォルト（最大試行数 or 時間上限）
    echo "$section" | grep -Eq "最大試行数|stop after|時間上限"
    echo "$section" | grep -Eq "[0-9]+"
    # 変更方法の明記（起動コマンド中のどこを書き換えるか）
    echo "$section" | grep -Eq "変更|書き換え"
  done
}

# --- S59: 打ち切り条件の無い goal レシピが 0 件 ---
@test "S59: no goal recipe lacks a termination condition" {
  for f in "${RECIPES}"/goal-*.md; do
    section="$(recipe_section "$f" "停止基準")"
    [ -n "$(echo "$section" | tr -d '[:space:]')" ]
    echo "$section" | grep -Eq "最大試行数|stop after|時間上限|回|tries"
  done
}

# --- S60: 起動コマンドがコピペ可能な /goal 文字列 ---
@test "S60: each goal recipe startup command is a copy-pasteable /goal string" {
  for r in "${GOAL_RECIPES[@]}"; do
    f="${RECIPES}/${r}.md"
    section="$(recipe_section "$f" "起動コマンド")"
    echo "$section" | grep -Eq "/goal "
    # 最大試行数（stop after / 回）が起動コマンド文字列に埋め込まれている
    echo "$section" | grep -Eq "stop after|回|tries"
  done
}

# --- S61: 独自ランタイム・モデル ID への参照が無い（goal） ---
@test "S61: goal recipes have no custom driver script or model id" {
  for f in "${RECIPES}"/goal-*.md; do
    run grep -Eq "bash .*loop.*\.sh" "$f"
    [ "$status" -ne 0 ]
    run grep -Eq "claude-[a-z0-9]" "$f"
    [ "$status" -ne 0 ]
  done
}

# ============================================================
# loops-time-recipes
# ============================================================

# --- S62: time レシピ 3 ファイルが存在する ---
@test "S62: three time recipe files exist" {
  for r in "${TIME_RECIPES[@]}"; do
    [ -f "${RECIPES}/${r}.md" ]
  done
}

# --- S63: 固定見出し 7 種が grep で確認できる（time） ---
@test "S63: each time recipe has all 7 fixed headings" {
  for r in "${TIME_RECIPES[@]}"; do
    f="${RECIPES}/${r}.md"
    for h in "${HEADINGS[@]}"; do
      grep -Eq "^#+ .*${h}" "$f"
    done
  done
}

# --- S64: ループ型がタイムベースと明記されている ---
@test "S64: each time recipe declares time-based loop type" {
  for r in "${TIME_RECIPES[@]}"; do
    f="${RECIPES}/${r}.md"
    run recipe_section "$f" "ループ型"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "タイムベース"
  done
}

# --- S65: /loop 起動コマンドと保守的な間隔デフォルト ---
@test "S65: loop-pr-babysit has /loop command with 5-10m default and change method" {
  f="${RECIPES}/loop-pr-babysit.md"
  section="$(recipe_section "$f" "起動コマンド")"
  echo "$section" | grep -Eq "/loop "
  echo "$section" | grep -Eq "5m|5〜10|5-10|10m|分"
  echo "$section" | grep -Eq "変更|書き換え"
}

# --- S66: 非破壊制約とエスカレーションが明記されている ---
@test "S66: loop-pr-babysit documents non-destructive constraints and escalation" {
  f="${RECIPES}/loop-pr-babysit.md"
  grep -q "マージ" "$f"
  grep -q "Ready for Review" "$f"
  grep -Eq "main.*push|main への" "$f"
  grep -q "エスカレーション" "$f"
}

# --- S67: PR 終了時の停止基準がある ---
@test "S67: loop-pr-babysit stop criteria detects PR merge or close" {
  f="${RECIPES}/loop-pr-babysit.md"
  section="$(recipe_section "$f" "停止基準")"
  echo "$section" | grep -q "マージ"
  echo "$section" | grep -Eq "クローズ|close"
}

# --- S68: 発火時プロンプトと推奨頻度が定義されている（cron） ---
@test "S68: cron recipes define trigger prompt and recommended frequency" {
  f_daily="${RECIPES}/cron-daily-report.md"
  f_weekly="${RECIPES}/cron-weekly-report.md"
  sd="$(recipe_section "$f_daily" "起動コマンド")"
  sw="$(recipe_section "$f_weekly" "起動コマンド")"
  echo "$sd" | grep -q "/daily-report"
  echo "$sw" | grep -q "/weekly-report"
  echo "$sd" | grep -q "日次"
  echo "$sw" | grep -q "週次"
  echo "$sd" | grep -Eq "変更|書き換え"
  echo "$sw" | grep -Eq "変更|書き換え"
}

# --- S69: ローカル実行必須の制約が明記されている ---
@test "S69: cron recipes require local execution in prerequisites section" {
  for r in cron-daily-report cron-weekly-report; do
    f="${RECIPES}/${r}.md"
    section="$(recipe_section "$f" "前提")"
    echo "$section" | grep -Eq "ローカル実行"
    echo "$section" | grep -Eq "Vault|jsonl"
  done
}

# --- S70: スケジューラ登録が呼び出し側の責務と明記されている ---
@test "S70: cron recipes declare scheduler registration as caller responsibility" {
  for r in cron-daily-report cron-weekly-report; do
    f="${RECIPES}/${r}.md"
    grep -q "スケジューラ" "$f"
    grep -q "呼び出し側の責務" "$f"
    grep -Eq "スコープ外" "$f"
    # 特定スケジューラへの登録「手順」（実コマンド構文）を含まない。
    # スコープ外の言及として名前を挙げるのは可。実際の登録コマンドが無いことを確認する。
    run grep -Eq "crontab -e|launchctl|\.plist" "$f"
    [ "$status" -ne 0 ]
  done
}

# --- S71: 既存レポートプラグインの本文が変更されていない ---
@test "S71: daily-report and weekly-report plugins are unchanged by this change" {
  # このテストは実装で両プラグインに触れないことを保証する意図。
  # git 追跡下で、両プラグイン配下に本 change 由来の差分が無いことを確認。
  cd "$PLUGIN_ROOT"
  run git diff --name-only HEAD -- plugins/daily-report plugins/weekly-report
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- S72: 停止基準の無い time レシピが 0 件 ---
@test "S72: no time recipe lacks a stop criteria" {
  for f in "${RECIPES}"/loop-*.md "${RECIPES}"/cron-*.md; do
    section="$(recipe_section "$f" "停止基準")"
    [ -n "$(echo "$section" | tr -d '[:space:]')" ]
    echo "$section" | grep -Eq "完了|検知|キャンセル|マージ|クローズ|期間"
  done
}

# --- S73: コスト注意にトークン管理該当項目がある ---
@test "S73: each time recipe cost section mentions frequency minimization" {
  for r in "${TIME_RECIPES[@]}"; do
    f="${RECIPES}/${r}.md"
    section="$(recipe_section "$f" "コスト注意")"
    echo "$section" | grep -Eq "頻度.*最小|必要最小限"
    echo "$section" | grep -Eq "スクリプト化|パイロット"
  done
}

# --- S74: 独自ランタイム・モデル ID への参照が無い（time） ---
@test "S74: time recipes have no custom driver script or model id" {
  for f in "${RECIPES}"/loop-*.md "${RECIPES}"/cron-*.md; do
    run grep -Eq "bash .*loop.*\.sh" "$f"
    [ "$status" -ne 0 ]
    run grep -Eq "claude-[a-z0-9]" "$f"
    [ "$status" -ne 0 ]
  done
}
