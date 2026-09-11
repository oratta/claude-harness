#!/usr/bin/env bats
#
# memory-refresh スキルとコマンド（#295）: 登録と、手順の欠かせない要素が本文にあること

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SKILL="${PLUGIN_DIR}/skills/memory-refresh/SKILL.md"
  COMMAND="${PLUGIN_DIR}/commands/memory-refresh.md"
  MANIFEST="${PLUGIN_DIR}/.claude-plugin/plugin.json"
}

@test "skill and command exist" {
  [ -f "$SKILL" ]
  [ -f "$COMMAND" ]
}

@test "manifest: memory-refresh is registered in skills and commands" {
  python3 - "$MANIFEST" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert "./skills/memory-refresh" in d["skills"], d["skills"]
assert "./commands/memory-refresh.md" in d["commands"], d["commands"]
PY
}

@test "command: is a thin wrapper that reads the skill instead of repeating it" {
  grep -q 'skills/memory-refresh/SKILL.md' "$COMMAND"
  grep -q 'Skill tool は使わないこと' "$COMMAND"
}

@test "skill: classifies into the four kinds and shows file / kind / reason before applying" {
  for kw in 削除 統合 短縮 維持; do grep -q "| ${kw} |" "$SKILL"; done
  grep -q 'ファイル名 / 分類 / 理由' "$SKILL"
  grep -q '適用前に 1 回だけ承認を取る' "$SKILL"
}

@test "skill: takes a whole-directory backup before applying and reports its location" {
  grep -q 'cp -R "\$M"' "$SKILL"
  grep -q '控えの場所を主に報告' "$SKILL"
}

@test "skill: checks that index entries match the files and reports the numbers" {
  grep -qF "grep -c '^- \\['" "$SKILL"
  grep -q 'no orphan/missing' "$SKILL"
  grep -q '総バイト数' "$SKILL"
}

@test "skill: carries the first cleanup of claude-harness as its example" {
  grep -q '## 例: claude-harness プロジェクトの初回整理' "$SKILL"
  grep -q 'project_capability-registry-not-installed' "$SKILL"
}

@test "skill: points at the detector and keeps its thresholds in one place" {
  grep -q 'memory-tripwire.sh' "$SKILL"
  run grep -c 'DEV_WORKFLOW_MEMORY_FILE_BYTES' "$SKILL"
  [ "$output" -eq 0 ]
}
