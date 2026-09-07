## MODIFIED Requirements

### Requirement: 昇格トリップワイヤー3本の定義
dev-workflow プラグインは、作業役（develop スキルの W、または hook 注入を読む本体自身）が手を止める条件を定義する常駐ルールテンプレートを配布しなければならない（SHALL）。テンプレートは以下のトリップワイヤーを、行為ベースの数えられる条件として定義する:

1. **規模超過 → 分割**: 編集対象ファイルが5個を超えた、または着手前の見積もりから作業項目が2回増えた。W として起動されている場合は本体に return し、本体が change / 子 issue（develop スキルのエピック化）に分割する。それ以外（本体自身が読んでいる場合）は develop のエピック化、または /lr:e 系の workflow 実行スキルに切り替える
2. **失敗ループ → モデル昇格**: 同じテストが2連続で落ちた、または同じ箇所を2回書き直した（昇格は1段ずつ: Sonnet → Opus → Fable。`FABLE_BUDGET_MODE=reserve` の自動実行、および `exhausted`（全経路）では Opus 上限）
3. **仕様の発明検知 → plan/質問**: ユーザーの指示に書かれていない仕様上の決定を自分で埋めた回数が2回に達した
4. **rate-limit 実エラー → reactive 降格**: Fable 実行が rate-limit / weekly-limit の実エラーを返したら、その場で Opus に降格して作業を継続し、usage snapshot を更新する

閾値は初期値であり運用調整前提であることをテンプレートに明記しなければならない（SHALL）。「あと少しで終わるから」を乗り換えない理由にしないことを明記する。

#### Scenario: 規模超過での乗り換え
- **WHEN** 作業中に編集対象ファイルが6個目に達する
- **THEN** その場で手を止め、W なら本体に return して分割を委ね、本体自身なら develop のエピック化または /lr:e 系のスキルに切り替える

#### Scenario: 失敗ループでの昇格
- **WHEN** 同じテストが2連続で落ちる
- **THEN** 実行役のモデルを1段昇格して続行する

#### Scenario: exhausted では昇格が Opus 上限
- **WHEN** `FABLE_BUDGET_MODE=exhausted` のセッションで失敗ループのトリップワイヤーを踏む
- **THEN** interactive / unmanned を問わず昇格は Opus までに留まり、Fable へは昇格しない

#### Scenario: 仕様の発明での停止
- **WHEN** ユーザーの指示に無い仕様決定（例:「DB は SQLite でいいだろう」）を自分で埋めた回数が2回に達する
- **THEN** 手を止めて埋めた決定を列挙し、局所的なら AskUserQuestion、構造に及ぶなら plan 系スキルの起動、unmanned なら Discord 質問 + needs-approval でサイクル終了する

#### Scenario: rate-limit 実エラーでの reactive 降格
- **WHEN** Fable 実行が rate-limit / weekly-limit の実エラー（429・weekly limit reached 等）を返す
- **THEN** 予測的な閾値判定とは別系統として、その場で Opus に降格し成果を引き継いで作業を継続し、usage snapshot を更新して以降のセッションの導出に反映する

### Requirement: 2段構えの配線
常駐ルールテンプレートは「いつ手を止めるか」（トリップワイヤー条件）のみを含み、発火時のアクションはスキル呼び出し（/lr:e、/lr:p 等の名前）または「develop の本体への return」で表現しなければならない（SHALL）。テンプレートは Workflow ツールやサブエージェント起動の直接的な操作手順を含んではならない（MUST NOT）。

#### Scenario: テンプレートにツール直接操作が無い
- **WHEN** 配布されたテンプレートの内容を検査する
- **THEN** 発火時のアクションはスキル/コマンド名の呼び出しと本体への return のみで、Workflow ツールやサブエージェント起動の直接呼び出し指示は含まれない

### Requirement: 乗り換え時の成果引き継ぎ
トリップワイヤー発火による乗り換え・昇格の際、それまでの成果（編集済みファイル・通ったテスト・埋めた決定の列挙）を破棄せず引き継ぐことをテンプレートが指示しなければならない（SHALL）。

#### Scenario: 分割への引き継ぎ
- **WHEN** 規模超過トリップワイヤーが発火して本体に return する、または workflow 型に乗り換える
- **THEN** ここまでの編集内容と判明した事実を引き継ぎ情報として渡し、作業をやり直さない
