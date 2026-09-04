# dev-workflow-escalation-tripwires Specification

## Purpose
TBD - created by archiving change dev-workflow-execution-strategy. Update Purpose after archive.
## Requirements
### Requirement: 昇格トリップワイヤー3本の定義
dev-workflow プラグインは、作業役（develop スキルの W、または hook 注入を読む本体自身）が手を止める条件を定義する常駐ルールテンプレートを配布しなければならない（SHALL）。テンプレートは以下のトリップワイヤーを、行為ベースの数えられる条件として定義する:

1. **規模超過 → 分割**: 編集対象ファイルが5個を超えた、または着手前の見積もりから作業項目が2回増えた。W として起動されている場合は本体に return し、本体が change / 子 issue（develop スキルのエピック化）に分割する。それ以外（本体自身が読んでいる場合）は develop のエピック化、またはネイティブ Workflow 実行（型は `plugins/dev-workflow/references/workflow-execution.md`。スクリプトは `workflow-authoring` スキルを読んで書く）に切り替える
2. **失敗ループ → モデル昇格**: 同じテストが2連続で落ちた、または同じ箇所を2回書き直した（昇格は1段ずつ: Sonnet → Opus → Fable。`FABLE_BUDGET_MODE=reserve` の自動実行、および `exhausted`（全経路）では Opus 上限）
3. **仕様の発明検知 → 壁打ち/質問**: ユーザーの指示に書かれていない仕様上の決定を自分で埋めた回数が2回に達した。局所的なら AskUserQuestion、構造に及ぶなら `/opsx:explore` で壁打ちに戻す
4. **rate-limit 実エラー → reactive 降格**: Fable 実行が rate-limit / weekly-limit の実エラーを返したら、その場で Opus に降格して作業を継続し、usage snapshot を更新する

閾値は初期値であり運用調整前提であることをテンプレートに明記しなければならない（SHALL）。「あと少しで終わるから」を乗り換えない理由にしないことを明記する。

#### Scenario: 規模超過での乗り換え
- **WHEN** 作業中に編集対象ファイルが6個目に達する
- **THEN** その場で手を止め、W なら本体に return して分割を委ね、本体自身なら develop のエピック化またはネイティブ Workflow 実行（`references/workflow-execution.md`）に切り替える

#### Scenario: 失敗ループでの昇格
- **WHEN** 同じテストが2連続で落ちる
- **THEN** 実行役のモデルを1段昇格して続行する

#### Scenario: exhausted では昇格が Opus 上限
- **WHEN** `FABLE_BUDGET_MODE=exhausted` のセッションで失敗ループのトリップワイヤーを踏む
- **THEN** interactive / unmanned を問わず昇格は Opus までに留まり、Fable へは昇格しない

#### Scenario: 仕様の発明での停止
- **WHEN** ユーザーの指示に無い仕様決定（例:「DB は SQLite でいいだろう」）を自分で埋めた回数が2回に達する
- **THEN** 手を止めて埋めた決定を列挙し、局所的なら AskUserQuestion、構造に及ぶなら `/opsx:explore` で壁打ちに戻し、unmanned なら Discord 質問 + needs-approval でサイクル終了する

#### Scenario: rate-limit 実エラーでの reactive 降格
- **WHEN** Fable 実行が rate-limit / weekly-limit の実エラー（429・weekly limit reached 等）を返す
- **THEN** 予測的な閾値判定とは別系統として、その場で Opus に降格し成果を引き継いで作業を継続し、usage snapshot を更新して以降のセッションの導出に反映する

### Requirement: 2段構えの配線
常駐ルールテンプレートは「いつ手を止めるか」（トリップワイヤー条件）のみを含み、発火時のアクションはスキル呼び出し（`/opsx:explore` 等の名前）・型を定めた reference への参照（`references/workflow-execution.md`）・「develop の本体への return」で表現しなければならない（SHALL）。テンプレートは Workflow ツールやサブエージェント起動の直接的な操作手順を含んではならない（MUST NOT）。

#### Scenario: テンプレートにツール直接操作が無い
- **WHEN** 配布されたテンプレートの内容を検査する
- **THEN** 発火時のアクションはスキル/コマンド名の呼び出し・reference への参照・本体への return のみで、Workflow ツールやサブエージェント起動の直接呼び出し指示は含まれない

### Requirement: テンプレートの配布と導入手順
常駐ルールテンプレートは `plugins/dev-workflow/templates/` 配下に配置され、導入手順を README またはテンプレート冒頭に記載しなければならない（SHALL）。interactive 層への配布は SessionStart hook による自動注入を既定とし、手動コピー（グローバルルールまたはプロジェクト CLAUDE.md）はプラグイン未導入環境・閾値カスタマイズ向けのオプションとして記載する。unmanned では各リポに配備済みの loop-dev-agent 憲法（`docs/agent-loop.md`。flatmate が保守する正本で、harness はテンプレートを持たない）が同じ条件を組み込んでいることを記載する。

#### Scenario: interactive への導入
- **WHEN** dev-workflow プラグインを導入済みのユーザーが新しいセッションを開始する
- **THEN** トリップワイヤーは hook により自動で文脈に載り、手動コピーは不要である

#### Scenario: 手動コピーのオプションが残っている
- **WHEN** ユーザーがテンプレート冒頭の導入手順を読む
- **THEN** プラグイン未導入環境や閾値カスタマイズ向けに手動コピーの手順が記載されている

#### Scenario: unmanned の組み込み先が憲法側と書かれている
- **WHEN** ユーザーがテンプレート冒頭の導入手順の unmanned の項を読む
- **THEN** 組み込み先は各リポの `docs/agent-loop.md`（flatmate 保守）で、harness 側にテンプレートや再生成手順が無いことが書かれている

### Requirement: 乗り換え時の成果引き継ぎ
トリップワイヤー発火による乗り換え・昇格の際、それまでの成果（編集済みファイル・通ったテスト・埋めた決定の列挙）を破棄せず引き継ぐことをテンプレートが指示しなければならない（SHALL）。

#### Scenario: 分割への引き継ぎ
- **WHEN** 規模超過トリップワイヤーが発火して本体に return する、または workflow 型に乗り換える
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
dev-workflow プラグインは `plugins/dev-workflow/scripts/usage-probe.sh` を配布しなければならない（SHALL）。probe はアカウントレジストリ（`usage-account-registry` capability）の全スロットをループし、スロットごとに導出した Keychain サービス名で認証情報を取得して OAuth usage API（`/api/oauth/usage`）をフェッチし、`~/.claude/.usage-snapshot`（`USAGE_SNAPSHOT` で上書き可）に JSON を書く。

snapshot は **schema 2** であり、次の構造でなければならない（SHALL）。snapshot は生産者（dev-workflow）と消費者（statusline）が別のタイミングで更新されうる層間契約であるため、**キー名を以下に固定する**:

```json
{
  "schema": 2,
  "active": "a",
  "fetched_at": 1757000000,
  "fable_weekly_pct": 94,
  "fable_active": true,
  "weekly_all_pct": 74,
  "weekly_resets_at": "2026-09-06T00:00:00Z",
  "weekly_resets_epoch": 1757116800,
  "five_hour_pct": 55,
  "five_hour_resets_at": "2026-09-04T12:00:00Z",
  "five_hour_resets_epoch": 1756987200,
  "accounts": {
    "a": {
      "label": "A",
      "securestorage": null,
      "fetched_at": 1757000000,
      "five_hour_pct": 55,
      "five_hour_resets_at": "2026-09-04T12:00:00Z",
      "five_hour_resets_epoch": 1756987200,
      "weekly_all_pct": 74,
      "weekly_resets_at": "2026-09-06T00:00:00Z",
      "weekly_resets_epoch": 1757116800,
      "fable_weekly_pct": 94,
      "fable_active": true
    }
  }
}
```

- `schema`: `2`
- `active`: 現在アクティブなスロットの id。判定規則は `usage-account-registry` capability の「active スロットの判定規則」に従う
- `accounts`: スロット id をキーとするオブジェクト。各スロットの値フィールドのキー名は上記に固定する（`label` / `securestorage` / `fetched_at` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `fable_weekly_pct` / `fable_active`）。値が得られないフィールドは `null` とする
- スロットの `fetched_at`: **そのスロットの値を実際に取得できた時刻**（epoch 秒）。fail-open で前回値を引き継いだスロットは、前回の `fetched_at` をそのまま保たなければならない（SHALL）。probe の実行時刻を書いてはならない（MUST NOT）
- トップレベルの `fetched_at` / `fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch`: **active スロットの同名フィールドをミラーしたもの**でなければならない（SHALL）。既存の読み手（`scripts/session-tripwires.sh` の `FABLE_BUDGET_MODE` 導出、および statusline の Fable 表示と 6 時間鮮度ゲート）を無改修で動かすための後方互換であり、独立に計算してはならない（MUST NOT）。特にトップレベル `fetched_at` は probe の実行時刻ではなく active スロットの取得時刻である（statusline の鮮度ゲートがこの値を読むため、実行時刻を書くと古い数字が新鮮な顔で表示される）

snapshot が TTL（既定 300 秒、`USAGE_PROBE_TTL` で上書き可）以内に更新済みなら再フェッチしてはならない（SHALL NOT）。

**fail-open はスロット単位で行う**（SHALL）。あるスロットの認証取得・通信・パースが失敗した場合、そのスロットの値は既存 snapshot の同スロットの前回値（`fetched_at` を含む）を引き継いで保持し、他スロットの新しい値は書く。非 active アカウントは OAuth アクセストークンの期限切れでフェッチが落ちるのが常態であるため、1 スロットの失敗が snapshot 全体の更新を止めてはならない（MUST NOT）。今回も取れず前回値も無いスロットは、全フィールドが `null` の欠測スロットとして `accounts` に載せる。

どのスロットからも新しい値が得られなかった場合、または snapshot の組み立て・書き込みが失敗した場合は、exit 0 で終了し snapshot を書いてはならない（MUST NOT）（既存 snapshot を破壊しない）。probe はいかなる失敗でも非 0 で終了してはならない（MUST NOT）。

probe は `refresh_token` を用いたアクセストークンの更新を行ってはならない（MUST NOT）。Claude Code 本体のリフレッシュと競合してトークンを無効化する危険があるため意図的に非対応とし、その理由をコードコメントに残さなければならない（SHALL）。

#### Scenario: snapshot に必須フィールドを書く
- **WHEN** 有効な usage API レスポンスを与えて probe を実行する
- **THEN** snapshot は valid JSON で、`schema` が 2、`accounts` にスロットごとの値、`active` に現在のスロット id を含み、トップレベルに Fable 週次消費率 `fable_weekly_pct` と `fable_active` を含む

#### Scenario: 複数スロットをそれぞれフェッチする
- **WHEN** 2 スロットのレジストリと、スロットごとに異なる usage API レスポンスを与えて probe を実行する
- **THEN** `accounts` に 2 スロット分の `five_hour_pct` / `weekly_all_pct` / `fable_weekly_pct` が、それぞれのレスポンスの値で入る

#### Scenario: トップレベルは active スロットのミラー
- **WHEN** 2 スロットのレジストリで、active でない方のスロットの値が active スロットと異なる状態で probe を実行する
- **THEN** トップレベルの `fetched_at` / `fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch` は `accounts` の active スロットの同名フィールドと一致する

#### Scenario: fetched_at は取得時刻であって実行時刻ではない
- **WHEN** active スロットのフェッチが失敗し、既存 snapshot の同スロットに前回の `fetched_at` がある状態で probe を実行する
- **THEN** そのスロットの `fetched_at` とトップレベルの `fetched_at` はどちらも前回の取得時刻のままであり、probe の実行時刻に更新されない

#### Scenario: 5 分キャッシュ
- **WHEN** TTL 以内に更新された snapshot が既に存在する状態で probe を実行する
- **THEN** API を再フェッチせず、既存 snapshot を維持する

#### Scenario: スロット単位 fail-open で前回値が残る
- **WHEN** 2 スロットのうち片方のフェッチが失敗し、既存 snapshot にそのスロットの前回値がある状態で probe を実行する
- **THEN** 失敗したスロットは前回値と前回の `fetched_at` を保ったまま残り、成功したスロットは新しい値に更新される

#### Scenario: 前回値も無いスロットは欠測として載る
- **WHEN** あるスロットのフェッチが失敗し、既存 snapshot にもそのスロットの値が無い状態で probe を実行する
- **THEN** そのスロットは全フィールドが `null` の欠測スロットとして `accounts` に載る

#### Scenario: 全スロット失敗時は fail-open
- **WHEN** 全スロットで認証取得または API 取得が失敗する
- **THEN** exit code 0 で終了し、新しい snapshot を書かない（既存 snapshot があればそのまま残す）

#### Scenario: スロットが 1 つのときは現行と同じ形に落ちる
- **WHEN** レジストリが存在しない状態で有効な usage API レスポンスを与えて probe を実行する
- **THEN** `accounts` は既定スロット 1 つだけを持ち、トップレベルの従来キー（`fetched_at` を含む）は変更前と同じ値になる（既存の読み手が無改修で動く）

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

