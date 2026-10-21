## Why

セッションの途中でモデルを切り替えると、今のモデルのプロンプトキャッシュ（同じ前置きを安く再利用する仕組み）は使えなくなり、会話全体を切替先のモデルで読み直す費用がかかる（公式記事 What a task costs on Opus 5.5）。今のハーネスは切替の時点でこの費用を見せていない。Claude Code 2.1.251 以降の PreModelSwitch hook は、入力に読み直すトークン数（`context_tokens`）とキャッシュ書き込みの推定費用（`estimated_cache_write_usd`）を持つので、切替のたびにこれを表示する（issue #714 の概要 2）。

## What Changes

- dev-workflow の `hooks/hooks.json` に `PreModelSwitch` のエントリを足す（matcher なし＝どの切替先でも走る）。起動するのは新規スクリプト `scripts/model-switch-recache-notice.sh`
- 新規スクリプトは stdin の JSON を読み、読み直すトークン数と推定費用を 1 文にまとめて `{"systemMessage": "…"}` だけを返す。`decision`・`hookSpecificOutput`（`permissionDecision` を含む）・`continue` は返さない（切替を止めず、本体の確認画面も飛ばさない）
- 捨てるキャッシュが無い切替（`prompt_cache_warm` が `false`）と、読み直すものが無い切替（`context_tokens` が `0`）では何も出さない
- どの失敗でも標準出力なし・exit 0（タイムアウトと exit 2 は切替を止めるので、外部通信・ファイル読み書きをせず、失敗を切替に波及させない）
- hooks.json のキー集合を完全一致で検査している既存テストの期待値に `PreModelSwitch` を足す
- 変更の記録 `plugins/dev-workflow/changes/714.md` を書く

## Capabilities

### New Capabilities

- `dev-workflow-model-switch-recache-notice`: モデル切替の直前に、再キャッシュの推定トークン数と推定費用を表示する hook の入出力契約

### Modified Capabilities

（なし）

## Impact

- `plugins/dev-workflow/hooks/hooks.json`（自己統治物件。PR 本文で主の承認を求める）
- `plugins/dev-workflow/scripts/model-switch-recache-notice.sh`（新規）
- `plugins/dev-workflow/tests/model-switch-recache-notice.bats`（新規）
- `plugins/dev-workflow/tests/subagent-stop-guard.bats`（hooks.json のキー集合の期待値）
- `plugins/dev-workflow/changes/714.md`（新規）
- 常時注入の予算（`tests/injection-budget.bats`）: `plugin.json` の `description` を変えないので測定値は動かない
- モデル切替のたびに `python3` が 1 回起動する（切替 1 回あたり数十ミリ秒）
