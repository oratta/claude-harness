#!/usr/bin/env bats
#
# Tests for change-2 (longrun-browser-verify-restore) — 一次ソース
# workflow-tool-reference.md の配布物内同梱.
#
# spec: longrun-workflow-reference-bundle S10-S13
#   S10 reference が references ディレクトリ配下に存在する
#   S11 plugins 配下に旧 run ディレクトリ（2026-06 起点）参照が残っていない
#   S12 参照元 3 箇所が配布物内パスを指す
#   S13 元パスに移動先を示すスタブが残る
#
# 注意: この bats 自身が探すマーカー文字列を「隣接文字列リテラルの連結」で組み立て、
# ファイルのバイト列に連続した該当文字列が現れないようにしている（S11 の受け入れ
# grep が自分自身にヒットしてしまうのを防ぐため）。

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  lr_setup_paths
  # 隣接リテラル連結でマーカーを組み立てる（ファイル内に連続実体を残さない）。
  MARK='_longruns/2026-06''-12'
  RUN_DIR_NAME="${MARK}_harness-workflow-overhaul"
  REF="${PLUGIN_DIR}/references/workflow-tool-reference.md"
  EXEC="${PLUGIN_DIR}/commands/exec.md"
  BV_TPL="${PLUGIN_DIR}/templates/workflow/build-verify.workflow.js"
  REVIEW_TPL="${PLUGIN_DIR}/templates/workflow/review.workflow.js"
  MODEL_TIERS="${PLUGIN_DIR}/references/model-tiers.md"
  STUB="${PLUGIN_ROOT}/${RUN_DIR_NAME}/workflow-tool-reference.md"
}

# --- S10: reference bundled under references/ ---

@test "S10: workflow-tool-reference.md exists under references/" {
  [ -f "$REF" ]
}

@test "S10: bundled reference documents Workflow tool signatures/constraints" {
  # signature/constraint evidence (agent(), budget, resumeFromRunId) present
  grep -q 'agent(' "$REF"
  grep -qE 'budget|resumeFromRunId' "$REF"
}

# --- S11: no dated run-dir reference remains under plugins/ ---

@test "S11: no dated run-dir reference remains under plugins/" {
  run grep -rn "$MARK" "${PLUGIN_ROOT}/plugins/"
  [ "$status" -ne 0 ]
}

# --- S12: three reference sites point at the bundled path ---

@test "S12: exec.md references the bundled reference path" {
  grep -q 'references/workflow-tool-reference.md' "$EXEC"
  ! grep -q "$MARK" "$EXEC"
}

@test "S12: build-verify template comment references the bundled path" {
  grep -q 'plugins/longrun/references/workflow-tool-reference.md' "$BV_TPL"
  ! grep -q "$MARK" "$BV_TPL"
}

@test "S12: review template comment references the bundled path" {
  grep -q 'plugins/longrun/references/workflow-tool-reference.md' "$REVIEW_TPL"
  ! grep -q "$MARK" "$REVIEW_TPL"
}

@test "S12: model-tiers.md references the bundled path (not the run dir)" {
  grep -q 'references/workflow-tool-reference.md' "$MODEL_TIERS"
  ! grep -q "$MARK" "$MODEL_TIERS"
}

# --- S13: a pointer stub remains at the original run-dir path ---

@test "S13: original run-dir path retains a move-pointer stub" {
  [ -f "$STUB" ]
  grep -q 'plugins/longrun/references/workflow-tool-reference.md' "$STUB"
}
