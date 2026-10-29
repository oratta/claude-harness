# Proposal

## Why

チーム機能が無効な環境では、名前付きで起こした担当のログが `agent-<agentId>.jsonl` に保存され、`subagent-context.sh <名前>` が毎回 `transcript not found` になる。隣の metadata に残る名前を使い、再開前のコンテキスト計測を可能にする（issue #590）。

## What Changes

- `agent-<id>.meta.json` の `name` が指定名と完全一致する場合、対応する `agent-<id>.jsonl` を探索候補に加える。
- 従来のファイル名による探索を維持し、metadata の欠落・不一致・破損でも利用できるようにする。
- 候補の選択は従来どおり cwd 一致を優先し、その中でログの更新時刻が新しいものを選ぶ。
- 本文の受け入れ条件 1〜4 と triage コメントの条件 5 を bats で検証する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-execution-strategy`: 「サブエージェントのコンテキスト上限と手渡し」の名前探索に metadata 経路を加え、ファイル名だけでは探せないという制約を更新する。

## Impact

- 実装対象: `plugins/dev-workflow/scripts/subagent-context.sh`
- テスト対象: `plugins/dev-workflow/tests/subagent-context.bats`
- 新しい依存関係は不要。Python 標準ライブラリの既存利用範囲で実装する。
- version は上げない。途中計測 hook や他の監査スクリプトの変更は不要。
