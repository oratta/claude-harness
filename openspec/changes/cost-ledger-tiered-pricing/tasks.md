# Tasks

行番号は仕様作成時点の案内。編集前に各範囲を読み直す。実装開始には記録先 #1103 の R1 APPROVE が必要。

## 1. 料金表と計算

- [ ] 1.1 `tests/pricing.bats` に、閾値ちょうど（100,000 は以下の単価）・超え（100,001 は全トークンが超過単価）・閾値なしモデルの不変・補足の事実が応答の区分で計算されること・超過単価が欠けた料金表が読み込みで失敗することを固定する。変更前に落ちることを確認する。触る範囲: plugins/cost-ledger/tests/pricing.bats（末尾に追加）
- [ ] 1.2 `pricing.json` の claude-haiku-5-5 に `long_prompt`（閾値 100000、入力 0.5・出力 2.5・5m 書込 0.625・1h 書込 1・読み 0.05）を足し、`_comment` に形を書く。触る範囲: plugins/cost-ledger/pricing.json:1-25
- [ ] 1.3 `Pricing.__init__` で `long_prompt` を検証し（5 種と閾値がそろっていなければ SystemExit）、`Pricing.cost` でプロンプト長を求めて区分を選ぶ。プロンプト長は補足の事実なら `prompt_tokens`、通常の事実なら 4 種の合計。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:95-135（`Pricing`）
- [ ] 1.4 補足の事実を作る箇所で、元の行の usage から合計を `prompt_tokens` に保存する。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:855-870（`facts_from_lines` の補足の事実）
- [ ] 1.5 全経路の確認: 単価を掛ける呼び出し（`summarise`・`compare_sessions`・`inferred_totals`・`price_intervals`・`cmd_report`）が事実 1 件ずつ `cost()` を呼ぶままであることを grep で確かめ、`bats plugins/cost-ledger/tests` が全部通ることを確認する。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:1713-1730、1804-1830、1969-1992、2480-2495（確認のみ）

## 2. 文書

- [ ] 2.1 README の単価の節に、閾値超の単価の形・判定（超える）・古い補足の事実の取りこぼしを書く。触る範囲: plugins/cost-ledger/README.md:95-112
- [ ] 2.2 変更記録を書く。バージョンは上げない。触る範囲: plugins/cost-ledger/changes/1103.md（新規）
- [ ] 2.3 `openspec validate cost-ledger-tiered-pricing --type change --strict` が通ることを確認する。
