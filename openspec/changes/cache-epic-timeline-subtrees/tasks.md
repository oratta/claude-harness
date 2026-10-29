# Tasks

実装は issue #882 の最新の仕様レビューが APPROVE になってから開始する。行番号は仕様作成時点の案内であり、編集前に該当範囲を読む。`cost_ledger.py` の `ISSUE_RE` と `attribution.bats` は変更しない。

## 1. 安全な保存とロック資源の寿命

- [ ] 1.1 対象ロック中に検査済みディレクトリ fd を保持し、対象別の保存の読取・検査・成功時だけの置換・解放を実装する。通常 hook と後追いの両方を対応させる。新規 bats の `cache: storage` ケースを同時に作り、保存の欠落・破損・読取不能・形式や対象の不一致では全件取得へ戻ること、リンクを辿らないこと、保存失敗だけでは正常な結果を捨てないことを検証する。`bats --filter 'cache: storage' plugins/cost-ledger/tests/epic-timeline-cache.bats` が exit 0。触る範囲: plugins/cost-ledger/scripts/gate_report.py:760-796（lock と保存ヘルパー）、plugins/cost-ledger/scripts/gate_report.py:998-1088（stack / work）、plugins/cost-ledger/scripts/backfill.py:197-213（stack_one）、plugins/cost-ledger/tests/epic-timeline-cache.bats（新規）

## 2. 信号による部分木の再利用と受け入れ条件

- [ ] 2.1 GraphQL に子の `updatedAt`・`subIssuesSummary.completed` を追加し、既存の合成応答にも有効な信号を足す。`epic_tree()` を毎回のルート取得と子ごとの信号比較に変更し、変わった子だけを取得、同じ子は完全な保存済み部分木から統合する。偽 `gh` の記録を別プロセスの連続 hook 呼び出しで比較する bats を同時に追加し、全子未変更の 3 回→1 回、1 子だけ変更の 3 回→2 回、各信号単独の変化、PR 一覧の順番だけの違い、子の増減・葉への変化で呼出先と子孫集合が正しいことを確認する。`bats plugins/cost-ledger/tests/epic-timeline-cache.bats plugins/cost-ledger/tests/epic-timeline.bats` が exit 0。触る範囲: plugins/cost-ledger/scripts/gate_report.py:863-995（SUB_ISSUES_QUERY / epic_tree）、plugins/cost-ledger/scripts/gate_report.py:998-1025（stack）、plugins/cost-ledger/tests/epic-timeline.bats:73-87（child / gql）、plugins/cost-ledger/tests/epic-timeline.bats:325-519、plugins/cost-ledger/tests/epic-timeline-cache.bats（新規）
- [ ] 2.2 変更された子の新しい孫と PR の分が 1 回だけ累計に入る bats、木の未変更・変更の両方で合計行の額が全件取得の `cost_ledger.py cost <エピック番号>` の 1 行目と一致する bats を追加する。保存した関連情報に手元のログだけ増えた場合も再集計し、関連の重複や付け替えで欠落・二重計上しないことを検証する。`bats plugins/cost-ledger/tests/epic-timeline-cache.bats` が exit 0。触る範囲: plugins/cost-ledger/tests/epic-timeline-cache.bats（新規）
- [ ] 2.3 保存がある回の取得不能・JSON 不正・形の崩れ・100 件超でも `None` と失敗表示が変わらず、合計行を積まず途中結果を保存しないことを bats で検証する。実際の問い合わせだけを 5 回に数えて 6 回目を呼ばないこと、省略した問い合わせを数えないこと、再利用した木にも深さ制限が効くことを検証する。`bats plugins/cost-ledger/tests/epic-timeline-cache.bats plugins/cost-ledger/tests/epic-timeline.bats` が exit 0。触る範囲: plugins/cost-ledger/scripts/gate_report.py:924-1025（epic_tree / stack）、plugins/cost-ledger/tests/epic-timeline-cache.bats（新規）
- [ ] 2.4 子の信号に出ない深い変更では保存を再利用し `/cost` の全件取得で正しい額を確認できることを bats で固定し、変更記録に問い合わせ削減・保存の扱い・この取りこぼしを書く。`bats plugins/cost-ledger/tests/epic-timeline-cache.bats` が exit 0、変更記録が差分にあることを確認する。触る範囲: plugins/cost-ledger/tests/epic-timeline-cache.bats（新規）、plugins/cost-ledger/changes/882.md（新規）

## 3. 統合確認

- [ ] 3.1 `bats plugins/cost-ledger/tests/epic-timeline-cache.bats plugins/cost-ledger/tests/epic-timeline.bats plugins/cost-ledger/tests/timeline.bats plugins/cost-ledger/tests/backfill.bats` を実行し exit 0 を確認する。通常 hook と後追いのロック解放、子無し issue と PR の回数と引数の不変を含む。偽 `gh` の初回・未変更・変更時の回数を実測値として控える。`git diff --check` が exit 0、禁止対象に変更が無いことも確認する。触る範囲: plugins/cost-ledger/tests/epic-timeline-cache.bats（新規）、plugins/cost-ledger/tests/epic-timeline.bats:224-519、plugins/cost-ledger/tests/timeline.bats:1-510、plugins/cost-ledger/tests/backfill.bats:1-1334

## Workflow follow-up

- 本体が独立した R1 を起こし、本 change の仕様レビューを issue #882 に記録する。実装後の verify、archive、PR、仕様宣言と遷移も本体の担当工程で行う。この spec 段では実装・push・PR 作成を行わない。
