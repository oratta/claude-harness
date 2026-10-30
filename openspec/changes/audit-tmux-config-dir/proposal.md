## Why

`CLAUDE_CONFIG_DIR` で `~/.claude` 以外の設定を使うセッションで、`subagent-context-audit.sh` は別の設定の会話記録を集計し、`epic-launch-tmux.sh` は送った文が会話ログに現れたかを確かめられない。#1231 で `subagent-context.sh` と `pr-token-budget.sh` を直した残りの 2 本である（issue #1481）。

## What Changes

- `subagent-context-audit.sh` の走査対象の既定を `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}` にする
- `subagent-context-audit.sh` の cache の既定を `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.subagent-context-audit` にする
- `epic-launch-tmux.sh` の `log_has_prompt` の探索先を同じ順にする（コメントも）
- 上の 2 要件の文を実装に合わせる（MODIFIED）

## Capabilities

### Modified Capabilities

- `dev-workflow-execution-strategy`: 要件「サブエージェントのコンテキスト量の母集団集計」の走査対象と cache の既定
- `dev-workflow-epic-state`: 要件「tmux の部品は子を独立した Claude Code のセッションとして tmux のウィンドウに起動する」の会話ログの場所

## Impact

`plugins/dev-workflow/scripts/subagent-context-audit.sh`、`plugins/dev-workflow/scripts/epic-launch-tmux.sh`、`tests/`。`CLAUDE_CONFIG_DIR` 未設定時の挙動は変わらない。
