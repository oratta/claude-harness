## Why

`plugins/cost-ledger/pricing.json` はモデルごとに 1 組の単価しか持てない。claude-haiku-5-5 は 1 応答のプロンプト（入力 + キャッシュ書込 + キャッシュ読出）が 100,000 トークンを超えると全トークンの単価が 5 倍になるが（公式の料金ページ、2026-10-19 確認）、今は 100,000 トークン以下の単価だけを入れているため、サブエージェントの長い呼び出しが 1/5 の額で集計される（#1103、#1100 の持ち越し）。

## What Changes

- `pricing.json` のモデル行に、プロンプト長の閾値と閾値超の単価 5 種を任意で持たせられるようにする。claude-haiku-5-5 に 100,000 トークンと閾値超の単価を入れる
- 単価の計算は、1 応答のプロンプト長（入力 + キャッシュ書込 5m + キャッシュ書込 1h + キャッシュ読出）が閾値を**超える**とき、その応答の全トークンを閾値超の単価で計算する。閾値ちょうどは閾値以下の単価
- 同じ応答の後続行から作る補足の事実（出力の差分だけを持ち、入力・キャッシュは 0）にも同じ区分を効かせるため、補足の事実に応答のプロンプト長を新しい欄 `prompt_tokens` として保存する。欄の無い古い補足の事実は区分を判定できないので閾値以下の単価で計算する
- 段階単価を持たないモデルの計算結果は変えない

## Capabilities

### Modified Capabilities
- `cost-ledger-pricing`: 「トークン内訳からのコスト算出」に閾値超の単価の選び方を足し、料金表の置き場所の要件に任意の閾値欄を足す

## Impact

- `plugins/cost-ledger/pricing.json`、`plugins/cost-ledger/scripts/cost_ledger.py`（`Pricing`、補足の事実を作る箇所）、`plugins/cost-ledger/tests/pricing.bats`、`plugins/cost-ledger/README.md`、`plugins/cost-ledger/changes/1103.md`
- 台帳（ledger）の既存の行は書き換えない。既存の補足の事実は `prompt_tokens` を持たず、出力の差分が閾値以下の単価で出る（既知の取りこぼし）
