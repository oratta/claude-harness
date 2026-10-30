## 1. 実装

- [ ] 1.1 `render_breakdown()` の未知モデルの部分を `render_unknown_models()` に切り出し、branch の出力が変わらないことを既存の bats（`pricing.bats`・`drift.bats`）で確かめる 触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:2287-2308
- [ ] 1.2 `assign_epic_rows()` の戻り値に `unknown_models`（`summarise(counted, pricing)["unknown_models"]`）を足す 触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:2738-2755
- [ ] 1.3 `cmd_issue` に `unknown_models`（`matched` の各行の `facts` を `summarise`）を足し、`--json` の payload に入れ、通常出力の区間の行・リポジトリ不明の行のあと・推定の注記の前で出す 触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:2884-2945
- [ ] 1.4 `cmd_epic` の `--json` に `unknown_models` を入れ、通常出力の子 issue の行のあと・リポジトリ不明の前で出す 触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:3018-3050
- [ ] 1.5 `commands/cost.md` の「出力の扱い」に未知モデルの行を見せる一文を足す 触る範囲: plugins/cost-ledger/commands/cost.md:60-66

## 2. テスト（bats）

- [ ] 2.1 issue 経路・epic 経路で名前と行数の行が出ること、未知モデルが無いと出ないこと、`--json` の `unknown_models` を固定する。文言は branch 経路と同じ文字列で比べる 触る範囲: plugins/cost-ledger/tests/（新規 unknown-model.bats。epic の準備は tests/epic.bats を参照）
- [ ] 2.2 cost.md の指示の有無を grep で固定する 触る範囲: plugins/cost-ledger/tests/cost-command.bats

## 3. 記録

- [ ] 3.1 変更の記録を書く 触る範囲: plugins/cost-ledger/changes/1102.md（新規）
