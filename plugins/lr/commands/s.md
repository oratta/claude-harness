---
name: s
description: "ロングラン実行の進捗状況を確認する（/longrun:status の短縮）"
allowed-tools: Read, Glob, Bash
---

/longrun:status コマンドと同じ動作をしてください。
引数: $ARGUMENTS

ランディレクトリを特定し（引数 or `_longrun/` 内の最新）、progress.md + `openspec list` + git状態を表示してください。
