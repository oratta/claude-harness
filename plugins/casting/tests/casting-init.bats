#!/usr/bin/env bats
#
# casting-project-files: /casting:init の生成手順
# spec: openspec/changes/casting-plugin/specs/casting-project-files/spec.md
#   Requirement: /casting:init による生成
#
# commands/init.md の「## 生成スクリプト」以下にある ```sh ブロックを実際に抽出して
# 実行し、初回生成・非上書き・gitignore 冪等追記を検証する。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  INIT_CMD="${PLUGIN_DIR}/commands/init.md"
  TEMPLATES_DIR="${PLUGIN_DIR}/templates"

  TMP="$BATS_TEST_TMPDIR"
  SCRIPT="${TMP}/casting-init-gen.sh"
  extract_gen_script "$INIT_CMD" "$SCRIPT"

  REPO="${TMP}/repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
}

# commands/init.md の "## 生成スクリプト" 以降にある最初の ```sh ブロックを取り出す
extract_gen_script() {
  python3 - "$1" "$2" <<'PY'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
i = text.find("## 生成スクリプト")
assert i >= 0, "生成スクリプト heading not found"
m = re.search(r"```sh\n(.*?)```", text[i:], re.S)
assert m, "sh code block not found under 生成スクリプト"
open(dst, "w", encoding="utf-8").write(m.group(1))
PY
  chmod +x "$2"
}

run_init() {
  sh "$SCRIPT" "$REPO" "$TEMPLATES_DIR"
}

# --- Scenario: 初回実行で一式が生成される ---

@test "first run: creates project.md and precedents.md" {
  run run_init
  [ "$status" -eq 0 ]
  [ -f "${REPO}/.claude/casting/project.md" ]
  [ -f "${REPO}/.claude/casting/precedents.md" ]
  diff "${REPO}/.claude/casting/project.md" "${TEMPLATES_DIR}/project.md"
  diff "${REPO}/.claude/casting/precedents.md" "${TEMPLATES_DIR}/precedents.md"
}

@test "first run: appends exactly one local.md line to .gitignore" {
  run run_init
  [ "$status" -eq 0 ]
  [ "$(grep -cxF '.claude/casting/local.md' "${REPO}/.gitignore")" -eq 1 ]
}

# --- Scenario: 再実行しても上書きされない ---

@test "second run: does not overwrite an edited project.md" {
  run_init
  printf '\n主が手で編集した行\n' >> "${REPO}/.claude/casting/project.md"
  cp "${REPO}/.claude/casting/project.md" "${TMP}/edited-project.md"

  run run_init
  [ "$status" -eq 0 ]
  diff "${REPO}/.claude/casting/project.md" "${TMP}/edited-project.md"
}

@test "second run: does not duplicate the .gitignore entry" {
  run_init
  run run_init
  [ "$status" -eq 0 ]
  [ "$(grep -cxF '.claude/casting/local.md' "${REPO}/.gitignore")" -eq 1 ]
}

# --- 回帰: 既存 .gitignore の末尾に改行が無い場合 ---

@test "no trailing newline in .gitignore: entry still lands on its own line" {
  printf 'node_modules' > "${REPO}/.gitignore"
  run run_init
  [ "$status" -eq 0 ]
  [ "$(grep -cxF 'node_modules' "${REPO}/.gitignore")" -eq 1 ]
  [ "$(grep -cxF '.claude/casting/local.md' "${REPO}/.gitignore")" -eq 1 ]

  run run_init
  [ "$status" -eq 0 ]
  [ "$(grep -cxF '.claude/casting/local.md' "${REPO}/.gitignore")" -eq 1 ]
}

@test "second run: does not overwrite precedents.md" {
  run_init
  printf '\n追記した判例\n' >> "${REPO}/.claude/casting/precedents.md"
  cp "${REPO}/.claude/casting/precedents.md" "${TMP}/edited-precedents.md"

  run run_init
  [ "$status" -eq 0 ]
  diff "${REPO}/.claude/casting/precedents.md" "${TMP}/edited-precedents.md"
}
