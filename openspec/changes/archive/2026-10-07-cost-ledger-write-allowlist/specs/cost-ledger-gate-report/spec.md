## RENAMED Requirements

- FROM: `### Requirement: 有効・無効の設定を持たず、緊急停止だけを持つ`
- TO: `### Requirement: 有効にする手段は許可の一覧だけで、緊急停止を別に持つ`

## MODIFIED Requirements

### Requirement: 有効にする手段は許可の一覧だけで、緊急停止を別に持つ
システムは、GitHub への書き込みを有効にする手段として、`cost-ledger-write-allowlist` の定める許可の一覧だけを持 MUST つ。環境変数やプラグインの userConfig の値で書き込みを有効にする設定項目を持ってはなら MUST NOT ない。一覧が空のとき（既定）は何も書き込まない。

緊急停止用に、環境変数 `COST_LEDGER_GATE_REPORT=off` のときは何もせず `exit 0` MUST する。この停止は、ゲート通過の行だけでなく、`cost-ledger-timeline` の定めるすべてのきっかけに効 MUST く。緊急停止は許可の一覧より先に効き、一覧に載っているリポジトリでも書き込まない。

#### Scenario: 緊急停止
- **WHEN** `COST_LEDGER_GATE_REPORT=off` を付けて付与コマンドの hook JSON を流す
- **THEN** `gh` は一度も呼ばれず、stdout は空で、終了コードは 0

#### Scenario: 緊急停止はコメントのきっかけにも効く
- **WHEN** `COST_LEDGER_GATE_REPORT=off` を付けて `gh pr comment 300 --body x` の hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout は空で、終了コードは 0

#### Scenario: 一覧が空なら付与コマンドでも書かない
- **WHEN** 許可の一覧のファイルが無い状態で、`COST_LEDGER_GATE_REPORT` を付けずに付与コマンドの hook JSON を流す
- **THEN** `gh` と `python3` は一度も呼ばれず、stdout は空で、終了コードは 0
