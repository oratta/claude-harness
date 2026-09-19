# agent-model-guard-hook — model 未指定の Agent spawn を PreToolUse で拒否する

## Why

rules/subagent-model-selection.md は「model は必ず明示」を規範にしているが、機械的なガードが無く、書き忘れや fork が親（Fable）を継承して週次枠を無言で消費していた（2026-09 の監査: fork 1 本で 271 USD 換算・コンテキスト 49 万トークン）。PR #235 でスクリプトを同梱し、この change で hooks.json に配線する。

## What Changes

- `hooks/hooks.json` に PreToolUse（matcher: Agent）→ `scripts/agent-model-guard.sh` を登録

## Capabilities

### Modified Capabilities

- `dev-workflow-execution-strategy`: Requirement「model 未指定の Agent spawn は hook が拒否する」を追加

## Impact

- `hooks/hooks.json`・CHANGELOG・version 2.4.1・tests/tripwire-hook.bats
