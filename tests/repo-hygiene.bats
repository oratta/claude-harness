#!/usr/bin/env bats
#
# リポジトリ衛生のガード。生成物が git 追跡下に入るのを機械で止める。
#
# 背景（Python バイトコード）:
#   このリポジトリは Claude Code の plugin 自動更新で dir ごと再 clone される
#   marketplace dir として展開される。.pyc はヘッダに元 .py の mtime を持つため、
#   clone のたびに「追跡下の .pyc」と「clone 直後の .py の mtime」が食い違い、
#   誰の作業ツリーでも理由なく dirty になる（git status の汚れ、worktree の
#   クリーン判定の誤動作）。
#
#   #171 で tests/lib/scan-multibyte-expansion.py を置いた際、実行で生成された
#   tests/lib/__pycache__/*.pyc をそのままコミットして PR レビューで落ちた。
#   .gitignore に足すだけでは「足したこと」を誰も検査しないので、追跡下に
#   バイトコードが無いことと、ignore が実際に効いていることの両方を検査する。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "hygiene: no compiled Python bytecode is tracked" {
  cd "$REPO_ROOT"
  run git ls-files -- '*.pyc' '*.pyo' '*/__pycache__/*' '__pycache__/*'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hygiene: .gitignore actually ignores Python bytecode" {
  cd "$REPO_ROOT"

  # 実在しないパスでよい（check-ignore は ignore ルールだけを見る）。
  # ディレクトリ形（__pycache__/）と拡張子形（*.pyc）の両方を確認する。
  run git check-ignore -q tests/lib/__pycache__/scan-multibyte-expansion.cpython-311.pyc
  [ "$status" -eq 0 ]

  run git check-ignore -q scripts/anywhere.pyc
  [ "$status" -eq 0 ]
}
