## Context

`/cost <issue番号>` は `resolve_number()` が REST を 1〜2 回呼んで PR か issue かを判別し、子 issue を持たない issue は `cmd_issue()` に渡す。`cmd_issue()` は既に `closing_prs`（`[(番号, ブランチ)]`）を受けると `issue_combined_total()` で合計を出せる（#689）。足りないのは、`/cost` が閉じた PR を自分で調べて渡すことだけ。エピックの経路（`fetch_epic_tree`）は既に同じ形の GraphQL を呼び、`_closing_refs()` で絞っている。

## Decisions

1. **問い合わせの置き場所は `cost_ledger.py`。** `gate_report.py` の `closing_prs()` は import しない。#691 の PR #744 が `gate_report.py` を触っていて衝突しやすく、`_closing_refs()` が同じ絞り方（ベースが対象リポジトリ・クロスリポジトリでない・同じブランチは番号の小さい方）を既に持つ。代わりに、閉じた PR 専用の小さな問い合わせ（`issue(number) { _CLOSING_FIELDS }` と `nameWithOwner`）を `cost_ledger.py` に足す。`gate_report.py` との二重実装は、守る絞り方が `_closing_refs()` 側の 1 か所で済む点で許容する（hook 側を寄せるのは #744 が片付いたあとの別件）。
2. **呼ぶのは `cmd_cost` の issue 分岐（子 issue 無し）だけ。** `cost_ledger.py issue <N>` を直接呼ぶ経路（hook・timeline・テスト）は変えない。hook はすでに `--closing-pr` を渡すので、二重に問い合わせない。
3. **1 行目は変えない。** `headline()` は `区間` のまま。ゲート連携が貼る 1 行と書式を割らないため。合計は 2 行目（既存の `合計（閉じた PR 込み）:` の行）に出る。
4. **失敗は fail-open で、そのことを見せる。** GraphQL の失敗・JSON でない・形の崩れ・100 件超のときは、区間の分だけの今までの出力に（通常出力だけ。`--json` は標準出力を JSON のまま保ち、`closing_prs_error: true` で表す）、`  閉じた PR を読めなかったため、PR の分は合計に入っていません。` を足す（標準出力。終了コード 0）。区間の分は読めているので止めず、PR の分が抜けたまま合計に見えることだけを防ぐ。`--json` では `closing_prs` を空にし、`closing_prs_error: true` を足す。選ばなかった案: エピックと同じ終了コード 2。`/cost` を叩いたのに区間の額も見られなくなる損のほうが大きい。リスク: GitHub が不調のとき、利用者がこの 1 行を見落とすと区間だけの額を合計と読む。1 行目の種別が `区間` のままなので、見出しは今までと同じ意味を保つ。
5. **gh の回数。** 判別の REST（PR を見て、なければ issue を見る）は増やさない。増えるのは GraphQL 1 回（子を持たない issue のときだけ。PR 番号・エピックの経路・番号なしの `/cost` では呼ばない）。`owner`・`name` は既存の `{owner}` `{repo}` の置換で渡す。

## Risks / Trade-offs

- `/cost <issue番号>` が 1 回あたり GraphQL 1 回ぶん遅くなる（ネットワーク往復 1 回）。PR に実測を書く。
- Projects classic 廃止のエラーは `gh issue view` 等の GraphQL 経路で出るもので、`gh api graphql` に自前のクエリを渡す経路は影響を受けない（エピックの経路が同じ呼び方で動いている）。
