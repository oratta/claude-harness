# Proposal

## Why

孫を持つエピックへ続けてコメントすると、`epic_tree()` は変わっていない部分木にも毎回 GraphQL を呼ぶ。issue #882 の受け入れ条件と親 #272 の回数制約に合わせ、前回取得した部分木を子ごとの変更信号で再利用する。

## What Changes

- ルートの GraphQL は毎回 1 回呼び、子の `updatedAt`・`subIssuesSummary.total / completed`・閉じた PR の一覧が前回と同じなら、その子の保存済み部分木を使う。変わった子と未保存の子だけ子孫を再取得する。
- 部分木と確認時刻を対象別に、安全なロック用ディレクトリの検査済み fd を基準として、対象のロック下で読み書きする。保存が使えなければ全件取得に戻り、取得成功時だけ保存する。
- 実際の GraphQL は 1 行 5 回まで。取得失敗時の `None` と `子 issue 照会失敗` の表示を維持する。
- 子より深い変更が子の信号に出ない場合の取りこぼしを「穴を許す」範囲として明記し、`/cost <番号>` の全件取得で正しい額を確認できることを残す。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `cost-ledger-timeline`: 「`gh` の呼び出し回数」「子 issue を持つ issue に積む行は子 issue の分を含む」の回数・部分木再利用・失敗時の扱いを更新する。

## Impact

- 実装対象: `plugins/cost-ledger/scripts/gate_report.py` の `lock()`、`SUB_ISSUES_QUERY`、`epic_tree()` とその呼び出し経路。
- テスト対象: `plugins/cost-ledger/tests/epic-timeline.bats` と新規 `plugins/cost-ledger/tests/epic-timeline-cache.bats`。偽 `gh` の記録と合成ログで 4 つの受け入れ条件を検証する。
- `cost_ledger.py` の `ISSUE_RE` と `attribution.bats` は変更しない。`/cost` は全件取得のまま。
- 単一 capability・4 条件・部分木の再利用という 1 つの設計判断に閉じるため、単一 change とする。

## 仕様化判断の記録

仕様化判断: する

理由: decision-criteria.md Step B の設計判断・トレードオフ、および既存 capability の要件変更に該当する。問い合わせ削減と信号に出ない変更の取りこぼしを選ぶ変更なので、文言合わせの通し方は適用しない。

記録先: https://github.com/oratta/claude-harness/issues/882#issuecomment-6505502985
