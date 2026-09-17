## 1. 調査・仕様
- [x] 1.1 現行Harness待ち契約とローカルcompanion内部transportを確認する
- [x] 1.2 ローカルhelp/schemaを確認し、PoC範囲と受入条件を書く
- [x] 1.3 ユーザー側の仕様レビューを受け、指摘を反映する

## 2. 仕様レビュー後のPoC
- [ ] 2.1 実使用companion版・停止ログを同定し、原因分類と未確定点を記録する
- [x] 2.2 fixtureと最小clientを用意し、現在profileの帰属をaccount/readと照合する（限界はRESULTS.md）
- [ ] 2.3 design.mdの検証表を実施し、受付・進捗・結果・中断を実測する
- [ ] 2.4 exec/companion/App Serverの差、既存broker再利用可否、Go判定を報告する
- [x] 2.5 #706/#707へ制約と採用候補を渡す（本番workerはここで実装しない）

- [x] 2.6 非競合の所有turnでinterruptedを最低1回実測する（Go必須。競合completed/unknownは代替不可）

実測証拠・未検証項目・総合Go保留: [RESULTS.md](RESULTS.md)。2.3は基本接続成功だが障害表未完のため未チェック。

- [x] 2.7 timeout/切断/auth-quota/未対応要求のfake protocol試験を完了し、実測との差を記録する
