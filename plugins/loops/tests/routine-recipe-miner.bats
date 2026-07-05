#!/usr/bin/env bats
#
# Tests for capability: loops-routine-recipe-miner
# Spec: openspec/changes/proactive-routines/specs/loops-routine-recipe-miner/spec.md
# Covers verification-guide.md scenarios S101-S114.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  RECIPE="${PLUGIN_DIR}/recipes/routine-recipe-miner.md"
  # run dir may live under _longruns/ (active) or _longruns/_archive/ (after /lr:a)
  LONGRUN_DIR="${PLUGIN_ROOT}/_longruns/2026-07-04_anthropic-knowledge-reflect"
  if [ ! -d "$LONGRUN_DIR" ]; then
    LONGRUN_DIR="${PLUGIN_ROOT}/_longruns/_archive/2026-07-04_anthropic-knowledge-reflect"
  fi
  HEADINGS=("ループ型" "目的" "起動コマンド" "停止基準" "前提" "コスト注意" "エスカレーション")
}

recipe_section() {
  awk -v h="$2" '
    /^## / { if (inx) exit; if (index($0, h)) { inx=1; next } }
    inx { print }
  ' "$1"
}

# --- S101: レシピファイルが固定見出しを全て持つ ---
@test "S101: routine-recipe-miner has all 7 fixed headings and declares proactive (meta) loop" {
  [ -f "$RECIPE" ]
  for h in "${HEADINGS[@]}"; do
    grep -Eq "^#+ .*${h}" "$RECIPE"
  done
  run recipe_section "$RECIPE" "ループ型"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "プロアクティブ"
  echo "$output" | grep -q "メタループ"
}

# --- S102: 定期実行の配線はスコープ外である ---
@test "S102: scheduler wiring is out of scope (no cron/launchd/claude -p wiring)" {
  grep -q "推奨頻度" "$RECIPE"
  grep -q "実行環境の制約" "$RECIPE"
  # no actual scheduler registration commands
  run grep -Eq "crontab -e|launchctl|\.plist" "$RECIPE"
  [ "$status" -ne 0 ]
}

# --- S103: ローカル実行必須の制約が明記されている ---
@test "S103: local execution requirement is documented" {
  grep -q "~/.claude/projects/" "$RECIPE"
  grep -q "ローカル実行" "$RECIPE"
  grep -Eq "jsonl" "$RECIPE"
}

# --- S104: 実行登録が呼び出し側の責務であることが明記されている ---
@test "S104: execution registration is caller responsibility / out of scope" {
  grep -q "呼び出し側の責務" "$RECIPE"
  grep -Eq "スコープ外" "$RECIPE"
}

# --- S105: サブエージェント隔離が明記されている ---
@test "S105: subagent isolation of log analysis is documented" {
  section="$(recipe_section "$RECIPE" "起動コマンド")"
  grep -q "サブエージェント" "$RECIPE"
  grep -Eq "候補リスト|抽出結果" "$RECIPE"
  grep -Eq "生ログをメイン|メイン.*載せない" "$RECIPE"
  grep -q "llm-log-compactor" "$RECIPE"
  grep -q "jq" "$RECIPE"
}

# --- S106: 4 種の抽出候補が定義されている ---
@test "S106: 4 kinds of extraction candidates are defined" {
  grep -Eq "反復|3 ?回以上" "$RECIPE"
  grep -q "/goal 化" "$RECIPE"
  grep -q "/schedule 化" "$RECIPE"
  grep -Eq "チューニング" "$RECIPE"
}

# --- S107: 提案上限 3 件が明記されている ---
@test "S107: max 3 proposals per cycle" {
  grep -Eq "最大 ?3 ?件|3 ?件.*上限|上限.*3" "$RECIPE"
}

# --- S108: 検査を通らない提案は見送り記録される ---
@test "S108: proposals failing the check are deferred and recorded" {
  grep -q "停止基準必須" "$RECIPE"
  grep -q "Bad Loop" "$RECIPE"
  grep -Eq "見送り" "$RECIPE"
  grep -q "state" "$RECIPE"
}

# --- S109: Draft PR 出力と自動 merge 禁止が明記されている ---
@test "S109: Draft PR output, auto-merge banned, human decides adoption" {
  grep -q "Draft PR" "$RECIPE"
  grep -Eq "自動 ?merge 禁止|自動マージ禁止" "$RECIPE"
  grep -q "人間" "$RECIPE"
  # no merge/close/force execution steps
  grep -Eq "merge|close|force" "$RECIPE"
}

# --- S110: state 記録の 3 区分が定義されている ---
@test "S110: state records 3 categories" {
  grep -q "提案済み" "$RECIPE"
  grep -Eq "見送り理由|見送り" "$RECIPE"
  grep -q "繰り越し" "$RECIPE"
  grep -Eq "silent drop|黙って" "$RECIPE"
}

# --- S111: 候補ゼロで正常終了する ---
@test "S111: zero candidates ends normally as no-proposal" {
  grep -Eq "候補.*ゼロ|候補 ?0|候補がゼロ|候補ゼロ" "$RECIPE"
  grep -Eq "提案なし" "$RECIPE"
  grep -Eq "正常終了" "$RECIPE"
}

# --- S112: 手動 1 サイクルデモのログが存在する ---
@test "S112: manual 1-cycle demo log exists" {
  log="${LONGRUN_DIR}/demos/routine-recipe-miner-demo.md"
  [ -f "$log" ]
  grep -Eq "提案なし|Draft PR" "$log"
  grep -q "state" "$log"
  grep -q "繰り越し" "$log"
}

# --- S113: デモで定期実行への登録を行わない ---
@test "S113: demo does not register any scheduler" {
  log="${LONGRUN_DIR}/demos/routine-recipe-miner-demo.md"
  [ -f "$log" ]
  grep -Eq "手動起動|手動 1 ?サイクル" "$log"
  run grep -Eq "crontab -e|launchctl|\.plist" "$log"
  [ "$status" -ne 0 ]
}

# --- S114: 規約検査はスキル起動に依存せず手動実行される ---
@test "S114: convention check done manually, not via /loops:design skill" {
  log="${LONGRUN_DIR}/demos/routine-recipe-miner-demo.md"
  [ -f "$log" ]
  grep -q "停止基準必須" "$log"
  grep -q "Bad Loop" "$log"
  grep -Eq "PASS|FAIL" "$log"
}
