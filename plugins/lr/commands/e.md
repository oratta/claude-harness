---
name: e
description: "自律実行を開始する（/longrun:exec の短縮）"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Workflow, AskUserQuestion
---

`/longrun:exec` の短縮版。`longrun` プラグインの `commands/exec.md` を Read tool で読み込み、その指示に従ってメインセッションでインライン実行してください。

**Skill tool は使わないこと。** `longrun:exec` はコマンドであり Skill ではないため Skill tool では呼べない。exec.md は plan.md を読んで Workflow スクリプトを生成・起動する（Step 0 権限検査 → plan.md 読込 → workflow 生成・起動）。`/lr:e` は **ユーザーが起動した slash command** なので、Workflow 起動の追加確認は不要（詳細は exec.md の opt-in セクション）。

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
