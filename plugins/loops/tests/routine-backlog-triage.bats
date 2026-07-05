#!/usr/bin/env bats
#
# Tests for capability: loops-routine-backlog-triage
# Spec: openspec/changes/proactive-routines/specs/loops-routine-backlog-triage/spec.md
# Covers verification-guide.md scenarios S75-S85.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  RECIPE="${PLUGIN_DIR}/recipes/routine-backlog-triage.md"
  # run dir may live under _longruns/ (active) or _longruns/_archive/ (after /lr:a)
  LONGRUN_DIR="${PLUGIN_ROOT}/_longruns/2026-07-04_anthropic-knowledge-reflect"
  if [ ! -d "$LONGRUN_DIR" ]; then
    LONGRUN_DIR="${PLUGIN_ROOT}/_longruns/_archive/2026-07-04_anthropic-knowledge-reflect"
  fi
  HEADINGS=("ループ型" "目的" "起動コマンド" "停止基準" "前提" "コスト注意" "エスカレーション")
}

# Extract the body of a level-2 (##) markdown section whose heading contains $2.
recipe_section() {
  awk -v h="$2" '
    /^## / { if (inx) exit; if (index($0, h)) { inx=1; next } }
    inx { print }
  ' "$1"
}

# --- S75: レシピファイルが固定見出しを全て持つ ---
@test "S75: routine-backlog-triage has all 7 fixed headings and declares proactive loop type" {
  [ -f "$RECIPE" ]
  for h in "${HEADINGS[@]}"; do
    grep -Eq "^#+ .*${h}" "$RECIPE"
  done
  run recipe_section "$RECIPE" "ループ型"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "プロアクティブ"
}

# --- S76: 起動コマンドがネイティブプリミティブのみである ---
@test "S76: startup command is native primitives only, no custom scripts" {
  section="$(recipe_section "$RECIPE" "起動コマンド")"
  echo "$section" | grep -Eq "/schedule |/goal |/loop "
  # no custom driver script path / custom CLI
  run grep -Eq "bash .*loop.*\.sh|\./build-loop|driver\.sh" "$RECIPE"
  [ "$status" -ne 0 ]
  run grep -Eq "claude-[a-z0-9]" "$RECIPE"
  [ "$status" -ne 0 ]
}

# --- S77: 停止基準が定量的に宣言されている ---
@test "S77: stop criteria declares /goal quantitative termination" {
  section="$(recipe_section "$RECIPE" "停止基準")"
  [ -n "$(echo "$section" | tr -d '[:space:]')" ]
  echo "$section" | grep -q "/goal"
  echo "$section" | grep -Eq "Draft PR|凍結"
  echo "$section" | grep -q "到達"
}

# --- S78: Draft PR までの非破壊制約が明記されている ---
@test "S78: non-destructive constraint (Draft PR ceiling) and merge/close/force ban listed" {
  grep -Eq "Draft PR まで|Draft PR / issue|Draft PR まで|上限" "$RECIPE"
  grep -q "Draft PR" "$RECIPE"
  grep -q "merge" "$RECIPE"
  grep -Eq "close|クローズ" "$RECIPE"
  grep -Eq "force" "$RECIPE"
}

# --- S79: マージは人間へエスカレーションされる ---
@test "S79: merge is escalated to human" {
  section="$(recipe_section "$RECIPE" "エスカレーション")"
  echo "$section" | grep -Eq "マージ|merge"
  echo "$section" | grep -q "人間"
}

# --- S80: 処理数上限が数値で記載されている ---
@test "S80: processing cap is a concrete number" {
  grep -Eq "上限|最大" "$RECIPE"
  # a discovery cap with a concrete numeral
  grep -Eq "最大 ?[0-9]+ ?件|上限.*[0-9]+|[0-9]+ ?件" "$RECIPE"
}

# --- S81: 繰り越し記録の手順がある ---
@test "S81: carry-over recording step exists with silent drop ban" {
  grep -q "繰り越し" "$RECIPE"
  grep -q "state" "$RECIPE"
  grep -Eq "silent drop|silent-drop|黙って" "$RECIPE"
}

# --- S82: state 更新が 3 区分をカバーする ---
@test "S82: state update covers 3 categories" {
  grep -q "処理済み" "$RECIPE"
  grep -q "繰り越し" "$RECIPE"
  grep -q "引き継ぎ待ち" "$RECIPE"
}

# --- S83: 2 連続失敗の凍結条件が記載されている ---
@test "S83: 2 consecutive failures freeze + escalate" {
  grep -Eq "2 ?連続" "$RECIPE"
  grep -q "凍結" "$RECIPE"
  grep -q "エスカレーション" "$RECIPE"
}

# --- S84: デモ実行ログが存在する ---
@test "S84: backlog-triage 1-cycle demo log exists with required evidence" {
  log="${LONGRUN_DIR}/demos/routine-backlog-triage-demo.md"
  [ -f "$log" ]
  grep -q "Draft PR" "$log"
  grep -q "state" "$log"
  grep -q "繰り越し" "$log"
}

# --- S85: 規約検査はスキル起動に依存せず手動実行される ---
@test "S85: convention check is done manually, not via /loops:design skill" {
  log="${LONGRUN_DIR}/demos/routine-backlog-triage-demo.md"
  [ -f "$log" ]
  grep -q "停止基準必須" "$log"
  grep -q "Bad Loop" "$log"
  grep -Eq "PASS|FAIL" "$log"
}
