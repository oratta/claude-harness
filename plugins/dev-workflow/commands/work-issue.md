---
name: work-issue
description: GitHub issue に取り組む標準開発ワークフローを起動する
argument-hint: "[issue番号|issueURL|自然文の依頼]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

`github-issue` スキルの薄いラッパー。手順の正（Step A〜D の本体）は **`skills/github-issue/SKILL.md` の 1 箇所にのみ存在する**。このコマンドはそれを Read tool で読み込み、その指示に従ってメインセッションで interactive モードのままインライン実行する。

**Skill tool は使わないこと。** この command は既に「ユーザーが起動した slash command」であり、Read tool で SKILL.md 本文（および必要なら `references/decision-criteria.md`）を読み込み、この command の frontmatter（`allowed-tools`）配下でそのままインライン実行する。

## ファイル特定

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/skills/github-issue}" \
  ~/.claude/plugins/marketplaces/*/plugins/dev-workflow/skills/github-issue \
  ~/.claude/plugins/installed/*/dev-workflow/skills/github-issue; do
  [ -n "$dir" ] && [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
done
```

特定した絶対パス（`skills/github-issue/SKILL.md`）を Read tool で読み込み、Step A〜D に従って実行する。**interactive モード**（デフォルト）で実行する。`--unmanned` は loop-dev-agent の憲法ファイル（`docs/agent-loop.md`）からサブエージェント経由で呼ばれる時専用であり、このコマンドから human が起動した場合には使わない。

## 引数の解釈

`$ARGUMENTS` から対象 issue を特定する:

- 数字のみ（例: `42`）→ カレントリポジトリの issue #42
- GitHub issue URL → そこから owner/repo/番号を抽出
- 自然文（例: `issue#12 のログイン不具合を直して`）→ 記述から issue 番号を推測し `gh issue view <番号>` で存在確認する。番号が特定できなければ `gh issue list` で候補を提示して選んでもらう
- 引数なし → `gh issue list --state open` で開いている issue を一覧し、どれに取り組むか聞く

特定した issue 番号を SKILL.md の実行にそのまま渡す。

引数 (`$ARGUMENTS`) の内容: $ARGUMENTS
