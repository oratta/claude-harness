# dev-workflow-execution-strategy Specification (Delta)

## ADDED Requirements

### Requirement: 実行戦略の判定表
`references/decision-criteria.md` は、Step B・Step C の既存の表に加えて、実行戦略の判定表を提供しなければならない（SHALL）。判定表は4象限モデル（縦軸: 実行が吸収するトークン量、横軸: 判断の分布）に基づき、決定論的シグナルと残量モードから solo / delegate+verify / workflow 型のいずれかを導く。判定表にはモード不変ルール2本（「結果が変わらない大量トークン仕事は常に安いモデル」「判断が集中する場所は常に賢いモデル」）を明記しなければならない（SHALL）。

#### Scenario: issue 着手時に実行戦略が同時に決まる
- **WHEN** github-issue スキルが Step B/C で issue を分類する
- **THEN** 同じ読み込みの中で実行戦略ラベル（solo / delegate+verify / workflow 型）が決まり、追加の判定専用 Step やサブエージェント呼び出しは発生しない

#### Scenario: 小タスクは分業しない
- **WHEN** 吸収トークン量が小さい issue（typo・明白なバグの数行修正）を判定する
- **THEN** 判断の濃さに関わらず戦略は solo になる（委譲のコーディネーションコストが常に損のため）

### Requirement: 決定論的シグナルの前処理
判定表は、script で機械的に収集できるシグナル（issue 本文の長さ・受け入れ条件チェックリストの有無・size 系ラベル・言及ファイル数）と、その収集コマンド例を定義しなければならない（SHALL）。シグナルは判定の入力であり、最終判定はその場のセッションが判定表に従って下す。

#### Scenario: シグナル収集が判定に先行する
- **WHEN** 実行戦略を判定する
- **THEN** 判定表に記載された bash コマンドで決定論的シグナルを収集してから、表に当てはめて戦略を仮決めする

### Requirement: Step D の実行戦略分岐
`SKILL.md` の Step D は、実行戦略ラベルに応じた3分岐を定義しなければならない（SHALL）: solo（メインセッションが現行手順のまま実行）、delegate+verify（安い実行役サブエージェントまたは codex が実装し、賢いモデルが受け入れ条件とテスト結果を verify する）、workflow 型（/lr:e 系のスキル呼び出しで Workflow 実行に委ねる）。全分岐で TDD（テスト先行）と証拠付き完了宣言の大原則を維持しなければならない（SHALL）。

#### Scenario: delegate+verify の実行
- **WHEN** 実行戦略が delegate+verify と判定される
- **THEN** 安い実行役がテスト先行で実装し、実行役とは別の賢いモデルが受け入れ条件・テスト exit code を確認してから完了を宣言する

#### Scenario: workflow 型の実行
- **WHEN** 実行戦略が workflow 型と判定される
- **THEN** Step D はスキル呼び出し（/lr:e 系）で workflow 実行に委ね、Workflow ツールを常駐ルールから直接呼ばない

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

### Requirement: reserve モードでは自動実行が Fable を使わない
`FABLE_BUDGET_MODE=reserve` のとき、自動実行（unmanned モード・cron・loop 経由の無人セッション）は Fable をいかなる役割（solo / verify / checkpoint）でも使ってはならない（MUST NOT）。無人時の昇格ラダーは Opus を上限とし、Opus でも解決しない問題は needs-approval で人間に返す。interactive セッションでは conserve と同じ扱いとし、人間の Fable 利用は妨げない。

#### Scenario: reserve 中の unmanned 昇格
- **WHEN** `FABLE_BUDGET_MODE=reserve` の unmanned サイクルで失敗ループのトリップワイヤーを踏む
- **THEN** 実行役は Opus までしか昇格せず、Opus でも2連続失敗が続く場合は issue に needs-approval を付けて経緯をコメントしサイクルを終了する

#### Scenario: reserve 中の interactive は制限されない
- **WHEN** `FABLE_BUDGET_MODE=reserve` の interactive セッションでユーザーが作業する
- **THEN** 判定は conserve と同一に振る舞い、ユーザー自身の Fable 利用（/model 切替等）を妨げる指示を出さない

### Requirement: Step B 基準の重心移動
`references/decision-criteria.md` の Step B（仕様化要否）は、「設計判断・トレードオフを含むか（= 意図と決定の記録価値があるか)」を一次基準としなければならない（SHALL）。受け入れ条件が issue に明記された機械的な振る舞い変更は、issue とテストを記録として spec 化を省略できる。テスト作成の必須性はいかなる判定でも緩めてはならない（MUST NOT）。unmanned モードの「迷ったら spec 化に倒す」は維持する。

#### Scenario: 機械的な振る舞い変更は spec を省略できる
- **WHEN** 受け入れ条件が issue に明記され、設計判断（トレードオフの選択）を含まない振る舞い変更を interactive で判定する
- **THEN** spec 化を省略してコード直行し、テストは必ず先に書く

#### Scenario: unmanned は安全側を維持
- **WHEN** unmanned モードで spec 化要否の判断がつかない
- **THEN** spec 化する側に倒す

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
