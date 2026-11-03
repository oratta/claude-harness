## 1. 実装

- [x] 1.1 `render_breakdown()` の未知モデルの部分を `render_unknown_models()` に切り出し、branch の出力が変わらないことを既存の bats（`pricing.bats`・`drift.bats`）で確かめる 触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:2287-2308
- [x] 1.2 `assign_epic_rows()` の戻り値に `unknown_models`（`summarise(counted, pricing)["unknown_models"]`）を足す 触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:2738-2755
- [x] 1.3 `cmd_issue` に `unknown_models`（`matched` の各行の `facts` を `summarise`）を足し、`--json` の payload に入れ、通常出力の区間の行・リポジトリ不明の行のあと・`render_inferred` の出力の前で出す 触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:2884-2945
- [x] 1.4 `cmd_epic` の `--json` に `unknown_models` を入れ、通常出力の `数えていない子 issue:` の行のあと・`リポジトリ不明` の行の前で出す 触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:3018-3050
- [x] 1.5 `commands/cost.md` の「出力の扱い」に未知モデルの行を見せる一文を足し、`<synthetic>` だけなら額に影響しない旨を添える 触る範囲: plugins/cost-ledger/commands/cost.md:60-66

## 2. テスト（bats）

- [x] 2.1 issue 経路・epic 経路で名前と行数の行が出ること、未知モデルが無いと出ないこと、`--json` の `unknown_models` を固定する。文言は branch 経路と同じ文字列で比べる。epic は、ヘッドブランチ上で区間に属さない行を数える・区間とヘッドブランチの両方に属する行は 1 回・リポジトリ不明の行は数えない、の 3 つも固定する 触る範囲: plugins/cost-ledger/tests/（新規 unknown-model.bats。epic の準備は tests/epic.bats を参照）
- [x] 2.2 cost.md の指示の有無を grep で固定する 触る範囲: plugins/cost-ledger/tests/unknown-model.bats

## 3. 記録

- [x] 3.1 変更の記録を書く 触る範囲: plugins/cost-ledger/changes/1102.md（新規）
