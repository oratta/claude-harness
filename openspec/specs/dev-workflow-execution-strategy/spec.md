# dev-workflow-execution-strategy Specification

## Purpose
TBD - created by archiving change dev-workflow-execution-strategy. Update Purpose after archive.
## Requirements
### Requirement: 残量モードによる閾値調整
役割のモデル選択は環境変数 `FABLE_BUDGET_MODE`（`abundant` / `conserve` / `reserve` / `exhausted`）を参照しなければならない（SHALL）。定義表は develop スキルの `references/decision-criteria.md` に置く（SHALL）。未設定時は usage snapshot からの自動導出結果を用い、snapshot も無ければ `conserve` として扱う。明示的に設定された `FABLE_BUDGET_MODE` は自動導出より優先されなければならない（SHALL）。モードが変えるのは役割（W / R1 / G）の既定モデルと昇格上限のみであり、1 ループの構造・トリップワイヤーは変えない。`exhausted` は Fable 週次枠を実質使い切った状態を表し、`reserve` と異なり interactive を含む全経路で Fable をいかなる役割でも使わず、昇格ラダーを Opus 上限とする。

#### Scenario: 未設定かつ snapshot 無しは conserve
- **WHEN** `FABLE_BUDGET_MODE` が未設定で usage snapshot も存在しないまま役割のモデルを決める
- **THEN** conserve（W / R1 / G = Opus 既定。事前分類に当たる場合のみ Fable）として判定する

#### Scenario: 明示 env は自動導出より優先
- **WHEN** `FABLE_BUDGET_MODE` が明示設定されており、かつ usage snapshot も存在する
- **THEN** 自動導出結果を無視して明示された値を用いる

#### Scenario: abundant では役割の既定を 1 段上げてよい
- **WHEN** `FABLE_BUDGET_MODE=abundant` で判断の濃い仕事の役割を決める
- **THEN** W / R1 / G の既定モデルを Fable に倒してよい。結果が変わらない機械的な大量仕事（fan-out ワーカー・機械的編集）は安いモデルのまま

#### Scenario: exhausted は全経路で Fable を使わない
- **WHEN** `FABLE_BUDGET_MODE=exhausted`（明示または自動導出）のセッションで役割・昇格を判定する
- **THEN** interactive / unmanned を問わず Fable をいかなる役割でも使わず、昇格ラダーは Opus を上限とする

### Requirement: reserve モードでは自動実行が Fable を使わない
`FABLE_BUDGET_MODE=reserve` のとき、自動実行（unmanned モード・cron・loop 経由の無人セッション）は Fable をいかなる役割（W / R1 / G）でも使ってはならない（MUST NOT）。無人時の昇格ラダーは Opus を上限とし、Opus でも解決しない問題は needs-approval で人間に返す。interactive セッションでは conserve と同じ扱いとし、人間の Fable 利用は妨げない。

#### Scenario: reserve 中の unmanned 昇格
- **WHEN** `FABLE_BUDGET_MODE=reserve` の unmanned サイクルで失敗ループのトリップワイヤーを踏む
- **THEN** W は Opus までしか昇格せず、Opus でも2連続失敗が続く場合は記録先に needs-approval を付けて経緯をコメントしサイクルを終了する

#### Scenario: reserve 中の interactive は制限されない
- **WHEN** `FABLE_BUDGET_MODE=reserve` の interactive セッションでユーザーが作業する
- **THEN** 判定は conserve と同一に振る舞い、ユーザー自身の Fable 利用（/model 切替等）を妨げる指示を出さない

### Requirement: Step B 基準の重心移動
develop スキルの `references/decision-criteria.md` の仕様化要否（Step B）は、「設計判断・トレードオフを含むか（= 意図と決定の記録価値があるか)」を一次基準としなければならない（SHALL）。受け入れ条件が記録先（issue または Draft PR 本文）に明記された機械的な振る舞い変更は、記録先とテストを記録として spec 化を省略できる。テスト作成の必須性はいかなる判定でも緩めてはならない（MUST NOT）。unmanned モードの「迷ったら spec 化に倒す」は維持する。

#### Scenario: 機械的な振る舞い変更は spec を省略できる
- **WHEN** 受け入れ条件が記録先に明記され、設計判断（トレードオフの選択）を含まない振る舞い変更を interactive で判定する
- **THEN** spec 化を省略してコード直行し、テストは必ず先に書く

#### Scenario: unmanned は安全側を維持
- **WHEN** unmanned モードで spec 化要否の判断がつかない
- **THEN** spec 化する側に倒す

### Requirement: usage snapshot からの残量モード自動導出
`FABLE_BUDGET_MODE` が明示設定されていないとき、残量モードは usage snapshot（`fable_weekly_pct` / `fable_active` / 週次リセット時刻を含む）から自動導出されなければならない（SHALL）。導出ルールは develop スキルの `references/decision-criteria.md` に定義し、次の優先順位に従う: ① `fable_weekly_pct` が読めない/snapshot 無し → `conserve` ② `fable_weekly_pct > 90` → `exhausted` ③ `fable_weekly_pct <= 週経過%`（週次リセット時刻から算出）→ `abundant` ④ それ以外 → `conserve`。導出は「Fable の消費ペースが週の経過ペースを上回るか」のバーンレート比較であることを明記する。

#### Scenario: 消費が週経過より遅ければ abundant
- **WHEN** snapshot の `fable_weekly_pct` が週経過% 以下で、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは abundant に導出される

#### Scenario: 消費が週経過を上回れば conserve
- **WHEN** snapshot の `fable_weekly_pct` が週経過% を超え、かつ 90 以下で、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは conserve に導出される

#### Scenario: 90% 超は exhausted
- **WHEN** snapshot の `fable_weekly_pct` が 90 を超え、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは exhausted に導出される

