#!/usr/bin/env bats
#
# コマンド本文の探索ループが、本文の読み込み時に置換される形の先頭候補を使うこと（issue #793）。
#
# Claude Code がコマンド本文で絶対パスに置き換えるのは ${CLAUDE_PLUGIN_ROOT} の字面だけで、
# Bash 実行には環境変数 CLAUDE_PLUGIN_ROOT が渡らない。"${CLAUDE_PLUGIN_ROOT:+...}" の形だと
# 内側だけ置換され、外側の :+ が残って実行時に空になり、marketplace の自動更新コピーが選ばれる。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "no command body uses the \${CLAUDE_PLUGIN_ROOT:+ form" {
  run git -C "$REPO_ROOT" grep -n 'CLAUDE_PLUGIN_ROOT:+' -- 'plugins/*/commands/*.md'
  [ "$status" -eq 1 ] || { echo "$output"; return 1; }
}
