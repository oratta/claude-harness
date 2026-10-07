## Why

`/cost <issue番号>` は、その issue に帰属する区間の分だけを返す。issue を閉じた PR の分を合わせた合計は、`gh issue close` の hook が積むコメントの行でしか見られず、手で合計を見るには `cost_ledger.py issue <N> --closing-pr <番号>:<ブランチ>` に閉じた PR を自分で調べて渡す必要がある（#689 が `/cost` の `gh` の回数を増やさないため範囲外にした抜け）。

## What Changes

- 子 issue を持たない issue の `/cost <issue番号>` が、閉じた PR を GraphQL の `closedByPullRequestsReferences` で 1 回問い合わせ、見つかった PR を `--closing-pr` と同じ入力として `cmd_issue` に渡す。2 行目に合計と内訳（PR ごとの額と PR 外の額）が出る。
- 閉じた PR が 0 件なら出力は今と同じ。1 行目（`headline()`）は変えない（種別は `区間` のまま。PR に貼るのは 1 行目だけという運用と、`--closing-pr` 付きの既存の要件に合わせる）。
- 問い合わせが失敗した・読み切れないときは、合計を出さず区間の分だけを今までどおり返し、PR の分が入っていないことを 1 行で示す（終了コードは 0。エピックの経路のように 2 で止めない。区間の分は読めているため）。
- 要件「`/cost <番号>` の入力解釈」の「判別のための `gh` の呼び出しを増やさない」は判別に限る旨を明確にし、「子 issue の数が応答に無い」Scenario の「GraphQL の呼び出しは 0 回」を 1 回（閉じた PR の問い合わせ）に改める。判別の REST 2 回は増やさない。

`gate_report.py`（hook の動作・backfill）は変えない。閉じた PR の解釈は `cost_ledger.py` に既にある `_closing_refs()` を使う（`gate_report.py` の `closing_prs()` と同じ絞り方）。

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `cost-ledger-cost-command`: 子を持たない issue の `/cost <issue番号>` が閉じた PR を問い合わせて合計を出す。判別の呼び出しを増やさない要件の範囲と、GraphQL 0 回の Scenario を改める。

## Impact

- `plugins/cost-ledger/scripts/cost_ledger.py`（`cmd_cost` の issue 分岐、閉じた PR の問い合わせの関数を足す）
- `plugins/cost-ledger/commands/cost.md`（呼び方の表）、`plugins/cost-ledger/README.md`（該当があれば）
- `plugins/cost-ledger/tests/`（cost-command.bats ほか、偽の `gh` で検証）
- 実行時間と `gh` の回数: `/cost <issue番号>` 1 回あたり GraphQL が 1 回増える（0 → 1）。変更前後を実測して PR に書く。
