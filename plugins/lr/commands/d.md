---
name: d
description: "意思決定一覧を確認する（/longrun:decisions の短縮）"
allowed-tools: Read, Glob, Bash
---

`/longrun:decisions` の短縮版。`longrun` プラグインの `commands/decisions.md` を Read tool で読み込み、その指示に従ってメインセッションでインライン実行してください。

**Skill tool は使わないこと。** `longrun:decisions` はコマンドであり Skill ではないため Skill tool では呼べない。

## ファイル特定

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/../longrun/commands}" \
  ~/.claude/plugins/marketplaces/*/plugins/longrun/commands \
  ~/.claude/plugins/installed/*/longrun/commands; do
  [ -n "$dir" ] && [ -f "$dir/decisions.md" ] && echo "$dir/decisions.md" && break
done
```

特定した絶対パスを Read tool で読み込み、引数 `$ARGUMENTS` を受け渡してインライン実行する。
