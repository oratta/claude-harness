## 1. gate_report.py

- [x] 1.1 `closing_prs()` が、問い合わせの失敗（`gh` の失敗・JSON でない・期待する形でない・1 件でも形が崩れている・`hasNextPage` が真）で `None` を返し、成功では今までどおり `[]` か `[(番号, ヘッドブランチ)]` を返す。docstring を直す。触る範囲: plugins/cost-ledger/scripts/gate_report.py:811-841（`closing_prs()`）
- [x] 1.2 `stack()` が、`issue クローズ` を含む issue で `closing_prs()` が `None` を返したときだけ、`--trigger` に使う名前の列の最後に `PR 照会失敗` を足す（`"+".join(names)` の結果が `issue クローズ+PR 照会失敗` の形になる）。成功のときは名前も `--closing-pr` も今までと同じ。触る範囲: plugins/cost-ledger/scripts/gate_report.py:844-858（`stack()`）

## 2. テスト（`plugins/cost-ledger/tests/gate-report.bats`。`attribution.bats` は触らない）

- [x] 2.1 stub の `timeline` が受け取った `--trigger` の値を返すヘルパー（`closing_args` と同じ形）を足す。触る範囲: plugins/cost-ledger/tests/gate-report.bats:346-365
- [x] 2.2 失敗の印が付くテスト: `FAKE_GRAPHQL_FAIL=1`・GraphQL の応答が JSON でない・`FAKE_CLOSING_NEXT=1`（100 件超）・形の崩れた要素のそれぞれで `--trigger` が `issue クローズ+PR 照会失敗`。コメントと同時のクローズでは `issue コメント+issue クローズ+PR 照会失敗`。触る範囲: plugins/cost-ledger/tests/gate-report.bats:1825-1884（既存の失敗系のテストの近く）
- [x] 2.3 印が付かないテスト: 1 件以上・0 件・別のリポジトリや fork の PR だけが返った回で `--trigger` が `issue クローズ` のまま、`gh` が 4 回（受け入れ条件。既存の 4 回のテストを壊さない）。触る範囲: plugins/cost-ledger/tests/gate-report.bats:1656-1706、:1841-1858
- [x] 2.4 本物の `cost_ledger.py` を使い、失敗した回と 0 件の回のコメントが違うこと（1 行目のきっかけの欄だけが違い、金額・入出力・キャッシュ・1 行目は同じ、合計の行はどちらにも無い）を確かめるテストを足す（受け入れ条件）。触る範囲: plugins/cost-ledger/tests/gate-report.bats:1927-1960（既存の本物の timeline のテストの近く）
- [x] 2.5 後追いが印付きの行を補わないテスト: 本文にきっかけ `issue クローズ+PR 照会失敗` の行があるとき、`timeline --backfill --trigger "issue クローズ"` が本文をそのまま返す（`timeline_has_trigger_near()` の確認）。`cost_ledger.py` を呼ぶテストなので `attribution.bats` ではなく `gate-report.bats` か `backfill.bats` に置く。触る範囲: plugins/cost-ledger/tests/backfill.bats（本物の timeline を呼ぶテストの近く）

## 3. 文書

- [x] 3.1 README の「合計の行が付かない場合」の「（0 件と失敗は見分けが付かない）」を、失敗のときだけ `issue クローズ+PR 照会失敗` と印が付くこと、手動で合計を確認する手段は `/cost <issue番号>`（再表示するだけで既存コメントの行は補わない）、に直す。触る範囲: plugins/cost-ledger/README.md:298-299
- [x] 3.2 `plugins/cost-ledger/changes/737.md` を書く（印の形・後追いは補わないこと・`gh` の回数と待ち時間の前後の値）。触る範囲: plugins/cost-ledger/changes/737.md（新規）

## 4. 検証と実測

- [ ] 4.1 `cost-ledger` の bats を全件実行して通ることを確かめる。`git diff --stat` で `cost_ledger.py` と `attribution.bats` を変えていないことを確かめる
- [ ] 4.2 エピック #272 の全体の制約: 変更の前後で、`gate_report.py` の裏の処理 1 回の所要時間と `gh` の呼び出し回数（`gh` を記録するラッパーで数える。成功した回は 4 回のまま、失敗した回も 4 回）を測り PR 本文に書く。LLM のトークンを使わないこと（hook は出力しない・スキル本文に手順を足していない）も書く。上限値は置かず結果を記録する
- [ ] 4.3 範囲外の問題を見つけたら直さず PR 本文に書く
