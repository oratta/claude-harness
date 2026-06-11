---
name: s
description: "進捗状況を確認する（/longrun:status の短縮）"
allowed-tools: Read, Glob, Bash
---

`/longrun:status` の短縮版。`longrun` プラグインの `commands/status.md` を Read tool で読み込み、その指示に従ってメインセッションでインライン実行してください。

**Skill tool は使わないこと。** `longrun:status` はコマンドであり Skill ではないため Skill tool では呼べない。

## ファイル特定

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/../longrun/commands}" \
  ~/.claude/plugins/marketplaces/*/plugins/longrun/commands \
  ~/.claude/plugins/installed/*/longrun/commands; do
  [ -n "$dir" ] && [ -f "$dir/status.md" ] && echo "$dir/status.md" && break
done
```

特定した絶対パスを Read tool で読み込み、引数 `$ARGUMENTS` を受け渡してインライン実行する。
