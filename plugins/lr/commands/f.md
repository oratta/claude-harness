---
name: f
description: "フィードバックを受け付ける（/longrun:feedback の短縮）"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Task
---

`/longrun:feedback` の短縮版。`longrun` プラグインの `commands/feedback.md` を Read tool で読み込み、その指示に従ってメインセッションでインライン実行してください。

**Skill tool は使わないこと。** `longrun:feedback` はコマンドであり Skill ではないため Skill tool では呼べない。なお feedback.md の本体処理は `longrun-feedback` Skill に委譲する設計になっているが、これは feedback.md 内の手順に従って実行される（短縮版から直接 Skill を呼ぶ必要はない）。

## ファイル特定

```bash
for dir in \
  ~/.claude/plugins/marketplaces/*/plugins/longrun/commands \
  ~/.claude/plugins/installed/*/longrun/commands; do
  [ -f "$dir/feedback.md" ] && echo "$dir/feedback.md" && break
done
```

特定した絶対パスを Read tool で読み込み、引数 `$ARGUMENTS` を受け渡してインライン実行する。
