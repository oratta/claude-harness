## Why

公開リポジトリの cost-ledger の spec とテストに、このリポジトリでも架空の `acme/...`・`example-org/...` でもない、実在しうるリポジトリ名が例として残っていた。別のリポジトリの名前が誰でも読める場所に残るので、架空の名前に置き換える（#800）。

## What Changes

- `cost-ledger-cost-command` の要件「出力の 1 行目は固定書式」の書式の例で、括弧内のブランチ名の例を架空の名前に置き換える
- `cost-ledger-gate-report` の要件「ラベル付与コマンドの判定と対象 PR の取り出し」の Scenario で、`GH_REPO=` の前置きと `R=` の代入に使う例のリポジトリ名を `acme/...` の架空の名前に置き換える
- `plugins/cost-ledger/tests/gate-report.bats` の例のリポジトリ名を、同じ旧名に同じ新名を対応させる 1 本の対応表で置き換える
- 規範の文（SHALL / MUST の内容）と、テストの期待値の構造は変えない。振る舞いの変更は無い

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-cost-command`: 「出力の 1 行目は固定書式」の書式の例の名前だけを置き換える
- `cost-ledger-gate-report`: 「ラベル付与コマンドの判定と対象 PR の取り出し」の Scenario の例の名前だけを置き換える

## Impact

- `openspec/specs/cost-ledger-cost-command/spec.md`・`openspec/specs/cost-ledger-gate-report/spec.md`（例の名前のみ）
- `plugins/cost-ledger/tests/gate-report.bats`（例の名前のみ）
- `plugins/cost-ledger/changes/800.md`（変更記録）
- スクリプト本体は触らない。版は上げない
