# dev-workflow-escalation-tripwires Specification

## Purpose
TBD - created by archiving change dev-workflow-execution-strategy. Update Purpose after archive.
## Requirements

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

### Requirement: 2段構えの配線
常駐ルールテンプレートは「いつ手を止めるか」（トリップワイヤー条件）のみを含み、発火時のアクションはすべてスキル呼び出し（/lr:e、/lr:p 等の名前）で表現しなければならない（SHALL）。テンプレートは Workflow ツールやサブエージェント起動の直接的な操作手順を含んではならない（MUST NOT）。

#### Scenario: テンプレートにツール直接操作が無い
- **WHEN** 配布されたテンプレートの内容を検査する
- **THEN** 発火時のアクションはスキル/コマンド名の呼び出しのみで、Workflow ツールの直接呼び出し指示は含まれない

### Requirement: テンプレートの配布と導入手順
常駐ルールテンプレートは `plugins/dev-workflow/templates/` 配下に配置され、導入手順を README またはテンプレート冒頭に記載しなければならない（SHALL）。interactive 層への配布は SessionStart hook による自動注入を既定とし、手動コピー（グローバルルールまたはプロジェクト CLAUDE.md）はプラグイン未導入環境・閾値カスタマイズ向けのオプションとして記載する。unmanned は loop-dev-agent 憲法への組み込み（loop-dev-agent-tripwires）で行われることを記載する。

#### Scenario: interactive への導入
- **WHEN** dev-workflow プラグインを導入済みのユーザーが新しいセッションを開始する
- **THEN** トリップワイヤーは hook により自動で文脈に載り、手動コピーは不要である

#### Scenario: 手動コピーのオプションが残っている
- **WHEN** ユーザーがテンプレート冒頭の導入手順を読む
- **THEN** プラグイン未導入環境や閾値カスタマイズ向けに手動コピーの手順が記載されている

### Requirement: 乗り換え時の成果引き継ぎ
トリップワイヤー発火による乗り換え・昇格の際、それまでの成果（編集済みファイル・通ったテスト・埋めた決定の列挙）を破棄せず引き継ぐことをテンプレートが指示しなければならない（SHALL）。

#### Scenario: workflow 型への引き継ぎ
- **WHEN** 規模超過トリップワイヤーが発火して workflow 型に乗り換える
- **THEN** ここまでの編集内容と判明した事実を引き継ぎ情報として渡し、作業をやり直さない

### Requirement: SessionStart hook がトリップワイヤーを常駐注入する
dev-workflow プラグインは `hooks/hooks.json` を配布し、SessionStart イベント（matcher: `startup|clear|compact`）で注入スクリプトを起動しなければならない（SHALL）。コマンドパスは `${CLAUDE_PLUGIN_ROOT}` を使用する。スクリプトは `templates/escalation-tripwires.md` の「## 昇格トリップワイヤー」節を抽出し、`{"additionalContext": "<節の本文>"}` の JSON を stdout に出力する（single source of truth: 本文の複製を hook 側に持たない）。テンプレートが見つからない・節が抽出できない場合は無出力・exit 0 で終了しなければならない（MUST NOT block session start）。

#### Scenario: 注入 JSON が節を含む
- **WHEN** `CLAUDE_PLUGIN_ROOT` をプラグインルートに設定してスクリプトを実行する
- **THEN** stdout は valid JSON で、`additionalContext` に「昇格トリップワイヤー」「規模超過」「失敗ループ」「仕様の発明」を含む

#### Scenario: テンプレート欠損時は fail-soft
- **WHEN** `CLAUDE_PLUGIN_ROOT` をテンプレートの無いディレクトリに設定してスクリプトを実行する
- **THEN** exit code 0 で出力は空である

#### Scenario: hooks.json の構造
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` をパースする
- **THEN** SessionStart エントリが存在し、matcher が `startup|clear|compact`、command が `${CLAUDE_PLUGIN_ROOT}` 経由でスクリプトを指している

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
