## Why

料金表に単価の無いモデル（未知モデル）が使われても、`cost_ledger.py issue <番号>` と子 issue を持つ issue の経路（`cmd_epic`）の出力にはその名前が出ず、額が黙って小さく出る（#1100 を起こした状況と同じ）。ブランチ・PR の経路だけが `render_breakdown()` で名前と行数を出している。branch 経路でも、`commands/cost.md` は 1 行目だけを利用者に見せるので、2 行目以降の未知モデルの行は利用者に届かない。

## What Changes

- `issue` 経路と epic 経路の通常出力に、branch 経路と同じ文言の `  未知モデル: <名前> N 行（料金表に単価が無いため 0 円として扱っている）` を出す（`render_breakdown()` の未知モデルの部分を共通の関数に切り出す）
- `--json` の出力に `unknown_models`（`{モデル名: 行数}`）を足す（branch の `--json` に既にある鍵と同じ形。足すだけで既存の鍵と 1 行目の書式は変えない）
- `commands/cost.md` に「`未知モデル:` の行があれば、1 行目に続けてその行も利用者に見せる」を足す

## Capabilities

### Modified Capabilities

- `cost-ledger-pricing`: 未知モデルの名前と行数を出す経路を issue・epic に広げる（要件を足す）
- `cost-ledger-cost-command`: cost.md が未知モデルの行を利用者に見せる（要件を足す）

## Impact

- `plugins/cost-ledger/scripts/cost_ledger.py`（`render_breakdown` の分割、`cmd_issue`、`cmd_epic`、`assign_epic_rows` の戻り値に鍵を 1 つ足す）
- `plugins/cost-ledger/commands/cost.md`、`plugins/cost-ledger/tests/`（新しい bats）
- Draft PR #1464（docstring と spec の文面）・#1465（`cmd_timeline` の 1 行）とは編集箇所が重ならない。spec は既存の要件を MODIFIED にせず新しい要件を ADDED にして、#1464 が変える要件の文との衝突を避ける
