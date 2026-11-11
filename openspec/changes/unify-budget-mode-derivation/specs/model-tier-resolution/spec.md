## MODIFIED Requirements

### Requirement: 残量モードの導出

`request` は明示 env を最優先に、無ければ起動 account の実効値から残量モードを導出しなければならない（MUST）。導出の式は `usage_view.py` の 1 か所の実装を使い、`session-tripwires.sh` が注入するモードと同じ値にしなければならない（MUST）。値が読めないときは止まらず `conserve`・`ok` として進めなければならない（MUST）。明示 env が未知の値なら、`FABLE_BUDGET_MODE` は `conserve`、`SHARED_BUDGET_MODE` は `throttled` として扱わなければならない（MUST）。

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
- **THEN** 注入される `FABLE_BUDGET_MODE` と `SHARED_BUDGET_MODE` は `budget_modes` の値と一致する
