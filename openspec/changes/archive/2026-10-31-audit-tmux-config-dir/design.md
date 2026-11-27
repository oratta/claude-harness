## Context

#1231（PR #1489）が `subagent-context.sh` と `pr-token-budget.sh` に入れた探索先の順をそのまま使う。

## Decisions

- 順は `CLAUDE_PROJECTS_DIR`、次に `CLAUDE_CONFIG_DIR` の下の `projects`、最後に `$HOME/.claude/projects`。他の 2 本と揃え、新しい環境変数は足さない。
- cache の既定は `CLAUDE_CONFIG_DIR` の下。`SUBAGENT_CONTEXT_AUDIT_CACHE` と `--cache` の明示は従来どおり優先する。
- 採らなかった案: 共通の関数に切り出す。1 行の既定値で、スクリプト間で source し合う依存が増えるほうが重いため。
