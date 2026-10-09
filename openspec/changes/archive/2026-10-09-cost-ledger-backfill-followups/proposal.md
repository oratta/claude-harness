## Why

PR #744（#691: auto-merge のマージと自動クローズの後追い）のレビューで、後追いに 2 つの不具合と、テストの取りこぼしが見つかった。いずれも後追いが黙って何もしない・窓がずれる形で、失敗が表に出ない。

- 台帳の場所を userConfig の `LEDGER_PATH`（`CLAUDE_PLUGIN_OPTION_LEDGER_PATH`）だけで設定した環境では、Stop hook は台帳に追記するのに、`backfill.sh` が `COST_LEDGER_PATH` しか見ないので後追いが毎回何もせず終わる（#760）。`cost-ledger-persistence` の「2 つの入口から解決し、前者が優先」に反する
- 控えは一覧が 1 件以上返った回にしか作られないので、一覧が空の回が続くと 24 時間の窓がセッションのたびにずれ、24 時間を超えて開かなかったリポジトリの auto-merge に行が付かない（#762）
- `backfill.bats` に、偽でも落ちない比較・並べ替えを固定していないテスト・使っていない stub の切り替えなどの取りこぼしが 6 件ある（#764）

## What Changes

- `plugins/cost-ledger/scripts/backfill.sh`: 台帳のパスを `${CLAUDE_PLUGIN_OPTION_LEDGER_PATH:-${COST_LEDGER_PATH:-}}` で解決し、`COST_LEDGER_PATH` に写して export する（`ledger-hook.sh` と同じ形）。`gate_report.py` と `cost_ledger.py` は変えない
- `plugins/cost-ledger/scripts/backfill.py`: `sweep()` で、一覧が成功して 0 件のとき、控えにそのリポジトリの値が無ければ今回の `since` を控えに書く。値があれば変えない
- spec `cost-ledger-backfill`: 「COST_LEDGER_PATH」を「解決した台帳のパス」に改め、userConfig だけを設定した Scenario と、一覧が空のときの控えの進め方（値が無ければ `since` を書く）を足す
- `plugins/cost-ledger/README.md` と `plugins/cost-ledger/changes/691.md` の文言を同じく直す。変更の記録は `plugins/cost-ledger/changes/760.md` に書く
- `plugins/cost-ledger/tests/backfill.bats`: userConfig だけを設定したテスト 1 本・一覧が空で値が無いテスト 1 本を足し、P5-F1〜F6 を直す
- 変更の前後で、SessionStart の後追い 1 回の所要時間と `gh` の呼び出し回数を実測し、PR 本文に書く（エピック #272 の全体の制約）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `cost-ledger-backfill`: 台帳のパスの解決を `cost-ledger-persistence` に合わせる（要件「後追いが動かない条件」「どこまで見たかを台帳の隣に記録する」「後追いは同時に 1 つだけ走らせる」）。一覧が空で値が無い回の控えの進め方を変える

## Impact

- 変えるファイル: `backfill.sh`・`backfill.py`・`backfill.bats`・`README.md`・`changes/691.md`・`changes/760.md`（新規）・spec `cost-ledger-backfill`
- 変えないファイル: `gate_report.py`・`cost_ledger.py`（並行して #703・#698 が触る）、`hooks.json`（反映に `/reload-plugins` は要らない）
- `gh` の呼び出し回数は増えない（`sweep()` の分岐が控えを書くだけ）。LLM のトークンは使わない。hook は出力を出さない
