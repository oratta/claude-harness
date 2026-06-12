---
name: e
description: "自律実行を開始する（/longrun:exec の短縮）"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

`/longrun:exec` の短縮版。`longrun` プラグインの `commands/exec.md` を Read tool で読み込み、その指示に従ってメインセッションでインライン実行してください。

**Skill tool は使わないこと。** `longrun:exec` はコマンドであり Skill ではないため Skill tool では呼べない。また、その先で呼ばれる `longrun-orchestrator` も `disable-model-invocation: true` で Skill tool から呼べない設計。

## ファイル特定

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/../longrun/commands}" \
  ~/.claude/plugins/marketplaces/*/plugins/longrun/commands \
  ~/.claude/plugins/installed/*/longrun/commands; do
  [ -n "$dir" ] && [ -f "$dir/exec.md" ] && echo "$dir/exec.md" && break
done
```

特定した絶対パスを Read tool で読み込み、引数 `$ARGUMENTS` を受け渡してインライン実行する。
