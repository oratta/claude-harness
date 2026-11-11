## MODIFIED Requirements

### Requirement: 残量モードの導出

`request` は明示 env を最優先に、無ければ起動 account の実効値から残量モードを導出しなければならない（MUST）。導出の式は `usage_view.py` の 1 か所の実装を使い、`session-tripwires.sh` が注入するモードの正規化後の値と同じにしなければならない（MUST）。一致させるのは正規化後のモードで、`session-tripwires.sh` が提示する値ではない（未知の明示値 `foo` は、注入では `foo` と提示され、正規化後のモードは `conserve` である）。値が読めないときは止まらず `conserve`・`ok` として進めなければならない（MUST）。明示 env が未知の値なら、`FABLE_BUDGET_MODE` は `conserve`、`SHARED_BUDGET_MODE` は `throttled` として扱わなければならない（MUST）。

守備範囲: 残量モードの導出の入力の出どころ・拾いたい誤り・通してよい入力・完了条件は、`dev-workflow-escalation-tripwires` の要件「SessionStart で残量モードを自動導出注入」の守備範囲の段落に従う（式が 1 か所なので守備範囲も 1 か所に置く）。

#### Scenario: 明示 env が勝つ

- **WHEN** `SHARED_BUDGET_MODE=ok` を明示し、実効値の `weekly_all_pct` が 95 である
- **THEN** 共有枠モードは `ok` である

#### Scenario: 実効値から導出する

- **WHEN** env が無く、`now` を固定し、実効値の `fable_weekly_pct` が 95、`weekly_all_pct` が 60、`weekly_resets_epoch` が `now` の 6 日後である
- **THEN** `budget_modes` は `exhausted` と `throttled` になる

#### Scenario: usage データが無い

- **WHEN** env が無く、実効値が読めない
- **THEN** `budget_modes` は `conserve` と `ok` で、`request` は止まらない

#### Scenario: 未知の明示値

- **WHEN** `FABLE_BUDGET_MODE=foo`、`SHARED_BUDGET_MODE=bar` で解決する
- **THEN** 格は `conserve` と `throttled` のときと同じである

#### Scenario: 注入されるモードと同じ値

- **WHEN** env が無く、同じ snapshot と `now` で `session-tripwires.sh`（`TRIPWIRES_SCOPE=subagent-budget`）と `read_budget_modes` を実行する
- **THEN** 注入されるモード（明示 env が無いので提示する値と正規化後のモードは同じ）は `budget_modes` の値と一致する
