## MODIFIED Requirements

### Requirement: 残量モードによる閾値調整
実行戦略の判定は環境変数 `FABLE_BUDGET_MODE`（`abundant` / `conserve` / `reserve` / `exhausted`）を参照しなければならない（SHALL）。未設定時は usage snapshot からの自動導出結果を用い、snapshot も無ければ `conserve` として扱う。明示的に設定された `FABLE_BUDGET_MODE` は自動導出より優先されなければならない（SHALL）。モードが変えるのは solo の推奨モデルと委譲閾値・昇格上限のみであり、判定の構造・トリップワイヤー・モード不変ルールは変えない。`exhausted` は Fable 週次枠を実質使い切った状態を表し、`reserve` と異なり interactive を含む全経路で Fable をいかなる役割でも使わず、昇格ラダーを Opus 上限とする。

#### Scenario: 未設定かつ snapshot 無しは conserve
- **WHEN** `FABLE_BUDGET_MODE` が未設定で usage snapshot も存在しないまま実行戦略を判定する
- **THEN** conserve（solo = Opus、Fable は verify / checkpoint のみ）として判定する

#### Scenario: 明示 env は自動導出より優先
- **WHEN** `FABLE_BUDGET_MODE` が明示設定されており、かつ usage snapshot も存在する
- **THEN** 自動導出結果を無視して明示された値を用いる

#### Scenario: abundant では solo が Fable に倒れる
- **WHEN** `FABLE_BUDGET_MODE=abundant` で判断の濃いタスクを solo 判定する
- **THEN** solo の推奨モデルは Fable になり、委譲は「結果が変わらない機械的な大量仕事」かつ self-contained なタスクに限定される

#### Scenario: exhausted は全経路で Fable を使わない
- **WHEN** `FABLE_BUDGET_MODE=exhausted`（明示または自動導出）のセッションで実行戦略・昇格を判定する
- **THEN** interactive / unmanned を問わず Fable をいかなる役割でも使わず、昇格ラダーは Opus を上限とする

## ADDED Requirements

### Requirement: usage snapshot からの残量モード自動導出
`FABLE_BUDGET_MODE` が明示設定されていないとき、残量モードは usage snapshot（`fable_weekly_pct` / `fable_active` / 週次リセット時刻を含む）から自動導出されなければならない（SHALL）。導出ルールは `references/decision-criteria.md` に定義し、次の優先順位に従う: ① `fable_weekly_pct` が読めない/snapshot 無し → `conserve` ② `fable_weekly_pct > 90` → `exhausted` ③ `fable_weekly_pct <= 週経過%`（週次リセット時刻から算出）→ `abundant` ④ それ以外 → `conserve`。導出は「Fable の消費ペースが週の経過ペースを上回るか」のバーンレート比較であることを明記する。

#### Scenario: 消費が週経過より遅ければ abundant
- **WHEN** snapshot の `fable_weekly_pct` が週経過% 以下で、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは abundant に導出される

#### Scenario: 消費が週経過を上回れば conserve
- **WHEN** snapshot の `fable_weekly_pct` が週経過% を超え、かつ 90 以下で、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは conserve に導出される

#### Scenario: 90% 超は exhausted
- **WHEN** snapshot の `fable_weekly_pct` が 90 を超え、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは exhausted に導出される

### Requirement: abundant の委譲は self-contained タスクに限定
`references/decision-criteria.md` は、abundant モードでの委譲（delegate+verify）を「self-contained（クリーンなハンドオフが成立する）タスク」に限定する条件を定義しなければならない（SHALL）。self-contained の基準は、① 委譲側が再文脈化なしに検証できる受け入れ条件が明確 ② 実装中の追加ヒアリング（往復）を要しない ③ 入力・出力が着手前に確定していること、とする。これを満たさないタスクは abundant でも solo に留める（ハンドオフの固定コストが便益を上回るため）。

#### Scenario: self-contained タスクは委譲する
- **WHEN** abundant モードで、受け入れ条件が明確・往復不要・入出力が確定した大量トークンの機械的タスクを判定する
- **THEN** delegate+verify で安い実行役に委譲し、賢いモデルが検証する

#### Scenario: 非 self-contained タスクは solo に留める
- **WHEN** abundant モードだが、実装中に仕様の往復や再文脈化が必要なタスクを判定する
- **THEN** 委譲せず solo に留める
