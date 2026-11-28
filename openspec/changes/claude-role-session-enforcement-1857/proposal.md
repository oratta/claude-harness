# Proposal

## Why

`claude -p` で動く develop の役は独立セッションであり、`agent_id` と SubagentStart / SubagentStop を前提とする強制層から外れる。#1857 の G001 として hook の対象選択を拡張し、役の文脈上限・停止・破壊的 git の制約を先に成立させる。

## What Changes

- 有効な `agent_id` がなく、環境変数 `DEVELOP_ROLE` が空でないセッションを「マーカー付き役」として識別する。既存 subagent と印のない主の挙動を維持する。
- マーカー付き役の `transcript_path` 自身を途中計測し、既存の閾値・通知 / 強制停止・return 宣言を適用する。
- マーカー付き役の SessionStart では `TRIPWIRES_SCOPE=subagent-budget` の本文を役向けに注入する。
- Stop に背景タスクの停止ガードを配線し、自身が起動した未完了タスクを判定する。
- マーカー付き役の破壊的 git を実行前に常に deny する。`agent_id` の捏造や一回許可を使わず、必要な承認後の操作は主が実行する。
- fixture テストで対象選択と既存経路の回帰を固定し、`plugins/dev-workflow/changes/1857.md` に G001 の変更を記録する。

## Capabilities

### New Capabilities

なし。既存の強制層の適用対象を拡張する。

### Modified Capabilities

- `dev-workflow-execution-strategy`: マーカー付き役自身の会話ログを途中計測の対象に加える。
- `dev-workflow-escalation-tripwires`: SessionStart に役向け残量モードの配送経路を加える。
- `dev-workflow-subagent-waiting`: マーカー付き役の Stop に同じ背景タスク判定と拒否上限を適用する。
- `destructive-git-hook`: マーカー付き役を主の ask / 子の permit 経路から分離して常時 deny する。

## Impact

変更対象は dev-workflow の `context-tripwire.sh`、`session-tripwires.sh`、`subagent-stop-guard.sh`、git ガード 2 本、`hooks/hooks.json` と対応する Bats テスト。閾値・格の表や注入予算の値は変更しない。マーカーは起動環境から hook に継承される入力であり、ツール本文から採用しない。

根拠は [#1857](https://github.com/oratta/claude-harness/issues/1857) と [本体の G001 選定](https://github.com/oratta/claude-harness/issues/1857#issuecomment-7234084447)。G002 の起動スクリプト・PR トークン集計・実機記録は対象外。#1850・#1856・#1858 の範囲は扱わない。本 change は fixture で単独検証し、`claude -p` を起動する要件を持たない。
