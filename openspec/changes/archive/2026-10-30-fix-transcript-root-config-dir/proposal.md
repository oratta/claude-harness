# Proposal

## Why

`subagent-context.sh` と `pr-token-budget.sh` は会話記録の探索先を `${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}` で決めていて、`CLAUDE_CONFIG_DIR` を見ない。`~/.claude` 以外の設定で動くセッションでは、前者が `transcript not found`（exit 1）で失敗し、後者が Claude 側の消費を 0 と数えるので、コンテキスト上限の手渡しと PR トークン上限の判定がどちらも効かない（#1231。#1127 の公開版確認で発覚）。

## What Changes

- 両スクリプトの既定の探索先を `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}` にする。`--projects` の指定はこれまでどおり最優先
- 既定の `~/.claude` だけを使う環境の動きは変わらない
- `CLAUDE_CONFIG_DIR` を指定したセッションでは、これまで 0 だった `claude_tokens` が実際の値になる。PR トークン上限の判定が初めて効くので、上限超の exit 2 が出るようになる（意図した変化）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-execution-strategy`: 要件「サブエージェントのコンテキスト上限と手渡し」の探索先の文を変える
- `dev-workflow-pr-token-budget`: 要件「出力と exit code」の走査対象の文を変える

## Impact

- `plugins/dev-workflow/scripts/subagent-context.sh` と `plugins/dev-workflow/scripts/pr-token-budget.sh`（既定の探索先と、それを説明するヘッダのコメント）
- `plugins/dev-workflow/tests/subagent-context.bats` と `plugins/dev-workflow/tests/pr-token-budget.bats`
- `subagent-context.sh` を `--file` で呼ぶ `epic-dispatch.sh` は影響を受けない
- 同じ書き方の `subagent-context-audit.sh` と `epic-launch-tmux.sh` は #1231 の対象外で、#1481 で直す（design.md の Non-Goals）
