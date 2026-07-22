## MODIFIED Requirements

### Requirement: 昇格トリップワイヤー3本の定義
dev-workflow プラグインは、solo からの離脱条件を定義する常駐ルールテンプレートを配布しなければならない（SHALL）。テンプレートは以下のトリップワイヤーを、行為ベースの数えられる条件として定義する:

1. **規模超過 → workflow 型**: 編集対象ファイルが5個を超えた、または着手前の見積もりから作業項目が2回増えた
2. **失敗ループ → モデル昇格**: 同じテストが2連続で落ちた、または同じ箇所を2回書き直した（昇格は1段ずつ: Sonnet → Opus → Fable。`FABLE_BUDGET_MODE=reserve` の自動実行、および `exhausted`（全経路）では Opus 上限）
3. **仕様の発明検知 → plan/質問**: ユーザーの指示に書かれていない仕様上の決定を自分で埋めた回数が2回に達した
4. **rate-limit 実エラー → reactive 降格**: Fable 実行が rate-limit / weekly-limit の実エラーを返したら、その場で Opus に降格して作業を継続し、usage snapshot を更新する

閾値は初期値であり運用調整前提であることをテンプレートに明記しなければならない（SHALL）。「あと少しで終わるから」を乗り換えない理由にしないことを明記する。

#### Scenario: 規模超過での乗り換え
- **WHEN** solo 作業中に編集対象ファイルが6個目に達する
- **THEN** その場で手を止め、workflow 型の実行スキルに乗り換える

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

## ADDED Requirements

### Requirement: usage-probe と snapshot 契約
dev-workflow プラグインは `plugins/dev-workflow/scripts/usage-probe.sh` を配布しなければならない（SHALL）。probe は OAuth usage API（`/api/oauth/usage`）を取得し、`~/.claude/.usage-snapshot`（`USAGE_SNAPSHOT` で上書き可）に少なくとも `fable_weekly_pct` と `fable_active` を含む JSON を書く。snapshot が TTL（既定 300 秒、`USAGE_PROBE_TTL` で上書き可）以内に更新済みなら再フェッチしてはならない（SHALL NOT）。認証取得・通信・パースのいずれが失敗しても exit 0 で終了し、snapshot を書いてはならない（MUST NOT）（fail-open: 既存 snapshot を破壊しない）。

#### Scenario: snapshot に必須フィールドを書く
- **WHEN** 有効な usage API レスポンスを与えて probe を実行する
- **THEN** snapshot は valid JSON で、Fable 週次消費率 `fable_weekly_pct` と `fable_active` を含む

#### Scenario: 5 分キャッシュ
- **WHEN** TTL 以内に更新された snapshot が既に存在する状態で probe を実行する
- **THEN** API を再フェッチせず、既存 snapshot を維持する

#### Scenario: フェッチ失敗時は fail-open
- **WHEN** 認証取得または API 取得が失敗する
- **THEN** exit code 0 で終了し、新しい snapshot を書かない（既存 snapshot があればそのまま残す）

### Requirement: SessionStart で残量モードを自動導出注入
`scripts/session-tripwires.sh` は SessionStart 時に usage-probe を best-effort 実行し、snapshot から導出した残量モードと Fable 残量% を additionalContext に含めなければならない（SHALL）。導出モードのブロックはトリップワイヤー節と併せて注入する。明示 env `FABLE_BUDGET_MODE` があるときはそれを優先し、導出値ではなく明示値を提示する。probe やパースが失敗しても、トリップワイヤー注入自体は従来どおり行われなければならない（SHALL）(probe 失敗が hook 全体を壊さない)。

#### Scenario: 導出モードと残量% を注入する
- **WHEN** 有効な snapshot がある状態で SessionStart スクリプトを実行する
- **THEN** additionalContext に導出された残量モードと Fable 残量%（100 − `fable_weekly_pct`）が含まれる

#### Scenario: 明示 env が導出を上書きする
- **WHEN** `FABLE_BUDGET_MODE` を明示設定して SessionStart スクリプトを実行する
- **THEN** additionalContext は導出値ではなく明示された値を現在モードとして提示する

#### Scenario: probe 失敗でもトリップワイヤーは載る
- **WHEN** snapshot が無い / probe が失敗する状態で SessionStart スクリプトを実行する
- **THEN** 昇格トリップワイヤー節は従来どおり注入され、残量モードは conserve 既定として提示される
