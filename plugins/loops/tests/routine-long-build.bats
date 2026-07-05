#!/usr/bin/env bats
#
# Tests for capability: loops-routine-long-build
# Spec: openspec/changes/proactive-routines/specs/loops-routine-long-build/spec.md
# Covers verification-guide.md scenarios S86-S100.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  RECIPE="${PLUGIN_DIR}/recipes/routine-long-build.md"
  FMT="${PLUGIN_DIR}/references/feature-list-format.md"
  LONGRUN_DIR="${PLUGIN_ROOT}/_longruns/2026-07-04_anthropic-knowledge-reflect"
  HEADINGS=("ループ型" "目的" "起動コマンド" "停止基準" "前提" "コスト注意" "エスカレーション")
}

recipe_section() {
  awk -v h="$2" '
    /^## / { if (inx) exit; if (index($0, h)) { inx=1; next } }
    inx { print }
  ' "$1"
}

# --- S86: レシピファイルが固定見出しを全て持つ ---
@test "S86: routine-long-build has all 7 fixed headings and declares proactive loop type" {
  [ -f "$RECIPE" ]
  for h in "${HEADINGS[@]}"; do
    grep -Eq "^#+ .*${h}" "$RECIPE"
  done
  run recipe_section "$RECIPE" "ループ型"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "プロアクティブ"
}

# --- S87: 前提節が外部状態ファイルを宣言している ---
@test "S87: prerequisites declare feature-list.json and claude-progress.md" {
  section="$(recipe_section "$RECIPE" "前提")"
  echo "$section" | grep -q "feature-list.json"
  echo "$section" | grep -q "claude-progress.md"
}

# --- S88: 起動コマンドがネイティブプリミティブのみである ---
@test "S88: startup command is native primitives only, no custom driver" {
  section="$(recipe_section "$RECIPE" "起動コマンド")"
  echo "$section" | grep -Eq "/schedule |/goal |手動再起動|手動"
  echo "$section" | grep -q "/goal"
  run grep -Eq "bash .*loop.*\.sh|\./build-loop|driver\.sh" "$RECIPE"
  [ "$status" -ne 0 ]
  # no model id (claude-progress.md is a legitimate state file, not a model id)
  run grep -Eq "claude-(opus|sonnet|haiku|[0-9])" "$RECIPE"
  [ "$status" -ne 0 ]
}

# --- S89: 1 サイクル 1 項目が明記されている ---
@test "S89: exactly one item per cycle" {
  grep -Eq "passes:false" "$RECIPE"
  grep -Eq "先頭 ?1 ?項目|1 ?項目のみ" "$RECIPE"
}

# --- S90: サイクルは smoke check から始まる ---
@test "S90: cycle begins with smoke check before implementation" {
  # smoke check line number must precede the implementation line
  smoke=$(grep -n "smoke" "$RECIPE" | head -1 | cut -d: -f1)
  impl=$(grep -nE "先頭 ?1 ?項目|1 ?項目のみ.*実装" "$RECIPE" | head -1 | cut -d: -f1)
  [ -n "$smoke" ]
  [ -n "$impl" ]
  [ "$smoke" -lt "$impl" ]
}

# --- S91: サイクルは commit と progress 追記で終わる ---
@test "S91: cycle ends with commit and progress append after passes update" {
  passes=$(grep -n "passes:true" "$RECIPE" | head -1 | cut -d: -f1)
  commit=$(grep -nE "commit|コミット" "$RECIPE" | tail -1 | cut -d: -f1)
  prog=$(grep -n "progress" "$RECIPE" | tail -1 | cut -d: -f1)
  [ -n "$passes" ]
  [ "$commit" -gt "$passes" ]
  [ "$prog" -gt "$passes" ]
}

# --- S92: evidence 必須の passes 更新条件が記載されている ---
@test "S92: passes:true update requires exit 0 evidence" {
  grep -q "exit 0" "$RECIPE"
  grep -Eq "evidence|エビデンス" "$RECIPE"
  grep -q "passes:true" "$RECIPE"
}

# --- S93: 自己申告更新の禁止がルーチンプロンプトに含まれる ---
@test "S93: self-report ban is in the trigger prompt" {
  section="$(recipe_section "$RECIPE" "起動コマンド")"
  echo "$section" | grep -Eq "自己申告|evidence なし|証拠なし|without evidence"
}

# --- S94: 停止基準に凍結条件が含まれる ---
@test "S94: stop criteria has full quantitative goal and 2-fail freeze" {
  section="$(recipe_section "$RECIPE" "停止基準")"
  echo "$section" | grep -q "passes:true"
  echo "$section" | grep -Eq "全項目"
  echo "$section" | grep -Eq "2 ?連続"
  echo "$section" | grep -q "凍結"
  echo "$section" | grep -q "人間"
}

# --- S95: 凍結項目は削除ではなく記録される ---
@test "S95: frozen items are recorded not deleted" {
  grep -Eq "削除しない|削除せず|削除禁止" "$RECIPE"
  grep -q "progress" "$RECIPE"
}

# --- S96: リファレンスが feature-list の形式を定義している ---
@test "S96: feature-list-format.md defines the 4 keys, default false, delete ban" {
  [ -f "$FMT" ]
  for k in "id" "description" "verification" "passes"; do
    grep -q "$k" "$FMT"
  done
  grep -Eq "passes.*false|false.*初期" "$FMT"
  grep -Eq "削除禁止|削除しない|削除せず" "$FMT"
}

# --- S97: schema による強制が存在しない ---
@test "S97: no JSON schema file enforces feature-list" {
  # No *.schema.json referencing feature-list under plugins/loops
  run bash -c 'find "'"${PLUGIN_DIR}"'" -name "*.schema.json" | xargs -r grep -l "feature" 2>/dev/null'
  [ -z "$output" ]
  # feature-list-format is markdown, not a schema file
  run bash -c 'ls "'"${PLUGIN_DIR}"'"/references/feature-list*.schema.json 2>/dev/null'
  [ "$status" -ne 0 ]
}

# --- S98: 2 サイクル以上の完走デモログが存在する ---
@test "S98: 2+ cycle completion demo log exists with per-cycle records" {
  log="${LONGRUN_DIR}/demos/routine-long-build-demo.md"
  [ -f "$log" ]
  grep -Eq "サイクル ?1|Cycle 1" "$log"
  grep -Eq "サイクル ?2|Cycle 2" "$log"
  grep -q "smoke" "$log"
  grep -Eq "exit code|exit 0|exit 1" "$log"
  grep -q "passes" "$log"
  grep -q "progress" "$log"
}

# --- S99: 故意の失敗で凍結とエスカレーションが機能する ---
@test "S99: intentional 2-fail triggers freeze + escalation in demo" {
  log="${LONGRUN_DIR}/demos/routine-long-build-demo.md"
  [ -f "$log" ]
  grep -q "凍結" "$log"
  grep -Eq "2 ?連続" "$log"
  grep -q "エスカレーション" "$log"
  grep -Eq "削除しない|削除せず|削除されない" "$log"
}

# --- S100: 規約検査はスキル起動に依存せず手動実行される ---
@test "S100: convention check done manually, not via /loops:design skill" {
  log="${LONGRUN_DIR}/demos/routine-long-build-demo.md"
  [ -f "$log" ]
  grep -q "停止基準必須" "$log"
  grep -q "Bad Loop" "$log"
  grep -Eq "PASS|FAIL" "$log"
}
