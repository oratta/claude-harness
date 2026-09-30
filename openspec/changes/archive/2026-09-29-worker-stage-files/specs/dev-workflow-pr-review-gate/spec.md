## ADDED Requirements

### Requirement: 順 3 の一覧を書かせる W の指示書の読み替え

この capability の既存要件「W の指示書が一覧の表と今直す記録を持つ」「一覧の一致で閉じる（順 3）」「指摘を受け取った G は仕分け表の順に当てる」が `skills/develop/references/roles/worker.md`（「worker.md」と書いたものを含む）と書いた箇所は、`skills/develop/references/roles/worker/implement.md` と読まなければならない（MUST。対応表の正本は `dev-workflow-develop`「既存要件が worker.md に置いた内容は移し先のファイルを指す」）。1 周目のモデルを上げる事前分類の正本を「develop スキルの references/roles/worker.md」と書いた箇所は、`skills/develop/references/pre-classification.md` と読まなければならない（MUST）。

#### Scenario: 順 3 の一覧の段落の所在

- **WHEN** `worker/implement.md` の順 3 の一覧の段落を読む
- **THEN** 修正前 SHA・検索コマンド・補助表 `### 書き換えた該当しない行` と、書式の正本が pr-review-gate の順 3 であることが書かれており、列の並びは再掲されていない

#### Scenario: triage が指す事前分類の正本

- **WHEN** pr-review-gate の `stages/triage.md` の事前分類に触れる段落を読む
- **THEN** 正本として `skills/develop/references/pre-classification.md` を指している
