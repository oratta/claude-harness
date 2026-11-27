## ADDED Requirements

### Requirement: 仕様レビューまわりの要件が指す W の指示書の読み替え

この capability の既存要件が `references/roles/worker.md` と書いた箇所は、次のとおり読まなければならない（MUST。対応表の正本は `dev-workflow-develop`「既存要件が worker.md に置いた内容は移し先のファイルを指す」）:

- 「仕様化要否の判定結果を固定書式で issue に記録する」の worker.md の仕様化判断の節と、「書いた仕様は実装前に別コンテキストがレビューする」の worker.md の仕様化する場合の節は、`references/roles/worker/spec.md` の同じ節
- 「仕様レビュアーのモデルは役割で選ぶ」の `references/roles/worker.md` の「重要実装の事前分類」表は、`references/pre-classification.md` の同じ表

#### Scenario: 仕様化判断の記録手順の所在

- **WHEN** `references/roles/worker/spec.md` の仕様化判断の節を読む
- **THEN** 1 行目の正規表現 `^仕様化判断: (する|しない)$` と、記録するまで分割判定・実装へ進まないことが書かれている

#### Scenario: R1 のモデル選択が指す表

- **WHEN** `references/roles/spec-reviewer.md` のモデルの箇条を読む
- **THEN** 事前分類表の参照先が `references/pre-classification.md` である
