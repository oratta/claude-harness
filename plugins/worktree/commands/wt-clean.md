---
name: wt-clean
description: Git worktree の安全なクリーンアップ（自動処理 → 判断バッチのみ対話の 2 パス）。配下で claude 等のプロセスが稼働中／当日のセッションログがある worktree は自動削除せず判断バッチに回す。`wt-clean [<path|branch>…] [--keep] [--no-sync]`、引数なしは全 worktree を対象。「worktree整理」「ワークツリークリーン」「worktree削除」「worktree再利用」「PRマージ後の整理」「プルリク後の片付け」「未マージworktreeのマージ」で起動。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

`wt-clean` スキルの薄いラッパー。診断分類・squash マージ検出・破壊操作の絶対禁則を含む**実行フローの正は `skills/wt-clean/SKILL.md` の 1 箇所にのみ存在する**。このコマンドはそれを Read tool で読み込み、その指示に従ってメインセッションでインライン実行する。

**Skill tool は使わないこと。** この command は既に「ユーザーが起動した slash command」という起動コンテキストを持つ。ここから Skill tool で同名 skill を再起動すると、AskUserQuestion のターン制御（回答到着後の別ターンで破壊操作を実行する絶対禁則）に余計な間接層を挟む。Read tool で SKILL.md 本文を読み込み、この command の frontmatter（`allowed-tools`）配下でそのままインライン実行する。

## ファイル特定

`CLAUDE_PLUGIN_ROOT` を第一候補に、marketplace / installed 配下を探索して SKILL.md の絶対パスを特定する。

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/skills/wt-clean}" \
  ~/.claude/plugins/marketplaces/*/plugins/worktree/skills/wt-clean \
  ~/.claude/plugins/installed/*/worktree/skills/wt-clean; do
  [ -n "$dir" ] && [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
done
```

特定した絶対パス（`skills/wt-clean/SKILL.md`）を Read tool で読み込み、その手順（Step 0 同期 → Step A TARGETS 確定 → Step B 遅延診断 → Step C レポート）に一言一句従って実行する。

## 引数の透過

`$ARGUMENTS` を SKILL.md の実行にそのまま渡す。位置引数（`<path|branch> …`）・`--keep`・`--no-sync` の解釈はすべて SKILL.md 側の定義に従い、この command で意味を再定義・上書きしない。

引数 (`$ARGUMENTS`) の内容: $ARGUMENTS
