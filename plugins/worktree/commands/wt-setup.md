---
name: wt-setup
description: Git worktreeの開発環境セットアップ
argument-hint: "[--with-pr] [セットアップ完了後に続けて実行する作業指示（任意）]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

`wt-setup` スキルの薄いラッパー。セットアップ手順の正（Step 1〜6 の本体）は **`skills/wt-setup/SKILL.md` の 1 箇所にのみ存在する**。このコマンドはそれを Read tool で読み込み、その指示に従ってメインセッションでインライン実行する。

**Skill tool は使わないこと。** この command は既に「ユーザーが起動した slash command」であり、Read tool で SKILL.md 本文を読み込み、この command の frontmatter（`allowed-tools`）配下でそのままインライン実行する。

## ファイル特定

`CLAUDE_PLUGIN_ROOT` を第一候補に、marketplace / installed 配下を探索して SKILL.md の絶対パスを特定する。

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/skills/wt-setup}" \
  ~/.claude/plugins/marketplaces/*/plugins/worktree/skills/wt-setup \
  ~/.claude/plugins/installed/*/worktree/skills/wt-setup; do
  [ -n "$dir" ] && [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
done
```

特定した絶対パス（`skills/wt-setup/SKILL.md`）を Read tool で読み込み、その手順（Step 1〜6）に従って実行する。

## 引数の透過

`$ARGUMENTS` を SKILL.md の実行にそのまま渡す。`--with-pr` フラグと後続作業指示の解釈はすべて SKILL.md 側の定義に従い、この command で意味を再定義・上書きしない。

引数 (`$ARGUMENTS`) の内容: $ARGUMENTS
