## MODIFIED Requirements

### Requirement: 役割のモデルは事前分類と残量モードで決める
SKILL.md は役割ごとのモデルを次のとおり規定しなければならない（MUST）: W は既定 `sonnet`、記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含むか失敗ループの昇格で `opus`、`worker.md` の「重要実装の事前分類」表に当たれば `fable`。R1 / G は既定 `opus`、仕様やゲートがマージ条件・聖域・層間契約に触れれば `fable`。残量モード（`FABLE_BUDGET_MODE`）は `references/decision-criteria.md` の表に従い、`abundant` は R1 / G の既定だけを 1 段上げてよく W は上げない、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限とする（MUST）。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が役割の既定モデルの下限を決め、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定とし、Fable 残量モードと食い違えば共有枠モードが勝つ（MUST）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した → 1 段昇格）は W の再開時のモデル選択として残す（SHALL）。本体は W / G を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測り、`DEV_WORKFLOW_CONTEXT_CAP`（既定 150000 tokens）を超えていたら再開せず、前回の return を渡して新しい W / G を spawn しなければならない（MUST。手渡し。モデルは変えない）。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W の既定が `sonnet`、R1 / G の既定が `opus`、事前分類・マージ条件・聖域・層間契約で `fable`、`abundant` は W を上げない、`reserve` は自動実行のみ・`exhausted` は全経路で `opus` 上限、`SHARED_BUDGET_MODE` の `throttled` / `depleted` で `sonnet` 起点、と書かれている

#### Scenario: 再開前にコンテキスト量を測る
- **WHEN** SKILL.md の「1 ループ」節を読む
- **THEN** W / G を SendMessage で再開する前に `subagent-context.sh` で測り、上限超なら再開せず手渡し（新しい W / G を spawn）すること、G の再開も同じであることが書かれている

#### Scenario: 実行戦略の 3 分岐が消えている
- **WHEN** `skills/develop/` 配下の全ファイルを grep する
- **THEN** 「delegate+verify」「workflow 型」の戦略分岐と、`gh issue view ... | length` 等の決定論的シグナル収集コマンドが存在しない
