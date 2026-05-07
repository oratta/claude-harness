---
name: a
description: "完了した実行をアーカイブする（/longrun:archive の短縮）"
allowed-tools: Read, Write, Edit, Bash, Glob
---

`/longrun:archive` の短縮版。`longrun` プラグインの `commands/archive.md` を Read tool で読み込み、その指示に従ってメインセッションでインライン実行してください。

**Skill tool は使わないこと。** `longrun:archive` はコマンドであり Skill ではないため Skill tool では呼べない。

## ファイル特定

```bash
for dir in \
  ~/.claude/plugins/marketplaces/*/plugins/longrun/commands \
  ~/.claude/plugins/installed/*/longrun/commands; do
  [ -f "$dir/archive.md" ] && echo "$dir/archive.md" && break
done
```

特定した絶対パスを Read tool で読み込み、引数 `$ARGUMENTS` を受け渡してインライン実行する。
