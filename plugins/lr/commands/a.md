---
name: a
description: "完了したロングラン実行をアーカイブする（/longrun:archive の短縮）"
allowed-tools: Read, Write, Edit, Bash, Glob
---

/longrun:archive コマンドと同じ動作をしてください。
引数: $ARGUMENTS

ランディレクトリを特定し（引数 or `_longrun/` 内の最新）、OpenSpec changeのアーカイブ → ランディレクトリのアーカイブ → worktreeクリーンアップ → コミットを実行してください。
