---
name: memory-refresh
description: メモリを見直して減らす（memory-refresh スキルを起動する）
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

`memory-refresh` スキルの薄いラッパー。手順の正本は **`skills/memory-refresh/SKILL.md` の 1 箇所にのみ存在する**。このコマンドはそれを Read tool で読み込み、その指示に従ってメインセッションでそのまま実行する。

**Skill tool は使わないこと。** この command は既に「ユーザーが起動した slash command」なので、Read tool で SKILL.md を読み込み、この command の frontmatter（`allowed-tools`）の範囲でインライン実行する。

## ファイル特定

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/skills/memory-refresh}" \
  ~/.claude/plugins/marketplaces/*/plugins/dev-workflow/skills/memory-refresh \
  ~/.claude/plugins/installed/*/dev-workflow/skills/memory-refresh; do
  [ -n "$dir" ] && [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
done
```

見つかった SKILL.md を Read で読み、手順 1 から始める。削除・短縮の適用は、手順 2 の一覧に主の承認を得てからにする。
