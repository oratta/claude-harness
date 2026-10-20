# dev-workflow-escalation-tripwires Specification

## Purpose
TBD - created by archiving change dev-workflow-execution-strategy. Update Purpose after archive.
## Requirements
### Requirement: 昇格トリップワイヤー3本の定義
dev-workflow プラグインは、作業役（develop スキルの W、または hook 注入を読む本体自身）が手を止める条件を定義する常駐ルールテンプレートを配布しなければならない（SHALL）。テンプレートは以下のトリップワイヤーを、行為ベースの数えられる条件として定義する:

1. **規模超過 → 分割**: 編集対象ファイルが5個を超えた、または着手前の見積もりから作業項目が2回増えた。W として起動されている場合は本体に return し、本体が change / 子 issue（develop スキルのエピック化）に分割する。それ以外（本体自身が読んでいる場合）は develop のエピック化、またはネイティブ Workflow 実行（型は `plugins/dev-workflow/references/workflow-execution.md`。スクリプトは `workflow-authoring` スキルを読んで書く）に切り替える
2. **失敗ループ → 決める役 / 実行役の分離ラダー**: 同じテストが2連続で落ちた、または同じ箇所を2回書き直した。実行役を1段ずつ上げるのではなく、失敗の原因が「決めた内容が間違っていた（判断側）」か「決めたとおりに実行できなかった（実行側）」かで、上げる相手を**一方だけ**決める（両方同時に上げない）。決める役は数ターンで終わるので先に上げ、実行役を上げるのは実行側が原因と分かったときだけとする（SHALL）。ラダーは次のとおり:

   | 段階 | 決める役 | 実行役 |
   |---|---|---|
   | 初回 | 仕様化判断と R1 レビューが担う（既存の流れ） | `sonnet` |
   | 1 回目の失敗 | `dev-workflow:decider` を `model: opus` で spawn（本体が opus 以上ならその場で）し、失敗の出力を読んで直す箇所・方法・確認するテストを具体的な指示にする | `sonnet` で再試行 |
   | 2 回目の失敗・指示どおりやって結果が違う | `dev-workflow:decider`（`model: opus`） | `opus` |
   | 2 回目の失敗・指示を解釈できなかった / 指示自体が外れていた | `dev-workflow:decider`（`model: fable`。本体が fable ならその場で） | `sonnet` または `opus` |
   | fable が決めて opus が実行しても落ちる | 人間へ（interactive は AskUserQuestion、unmanned は `needs-approval`） | — |

   決める役を spawn するときは、どの段階でも `subagent_type` を `dev-workflow:decider` に固定し `model` だけを切り替えなければならない（MUST。`general-purpose` に読み替えない）。実行役の上限は `opus` であり、実行役を Fable で spawn してはならない（MUST NOT。強制層は `plugins/dev-workflow/scripts/agent-model-guard.sh`）。`FABLE_BUDGET_MODE=reserve` の自動実行、および `exhausted`（全経路）では決める役も `model: opus` 止まりとする（種別は `dev-workflow:decider` のまま）。共有枠モード `SHARED_BUDGET_MODE` の下限が先に効く（`depleted` は昇格なし、`throttled` は Opus 上限）
3. **仕様の発明検知 → 壁打ち/質問**: ユーザーの指示に書かれていない仕様上の決定を自分で埋めた回数が2回に達した。局所的なら AskUserQuestion、構造に及ぶなら `/opsx:explore` で壁打ちに戻す
4. **rate-limit 実エラー → reactive 降格**: Fable 実行が rate-limit / weekly-limit の実エラーを返したら、その場で Opus に降格して作業を継続し、usage snapshot を更新する

閾値は初期値であり運用調整前提であることをテンプレートに明記しなければならない（SHALL）。「あと少しで終わるから」を乗り換えない理由にしないことを明記する。

#### Scenario: 規模超過での乗り換え
- **WHEN** 作業中に編集対象ファイルが6個目に達する
- **THEN** その場で手を止め、W なら本体に return して分割を委ね、本体自身なら develop のエピック化またはネイティブ Workflow 実行（`references/workflow-execution.md`）に切り替える

#### Scenario: 1 回目の失敗では誰も上げない
- **WHEN** 同じテストが2連続で落ちて 1 回目の失敗として扱う
- **THEN** 実行役は `sonnet` のまま再試行し、`subagent_type: dev-workflow:decider` を `model: opus` で立てた決める役が失敗の出力を読んで直す箇所・方法・確認するテストを具体的な指示にする

#### Scenario: 実行側が原因なら実行役だけ上げる
- **WHEN** 2 回目の失敗で、実行役が指示どおりやったのに結果が違うと分類される
- **THEN** 実行役を `opus` に上げ、決める役は `opus` のままで Fable には上げない

#### Scenario: 判断側が原因なら決める役だけ上げる
- **WHEN** 2 回目の失敗で、実行役が指示を解釈できなかった、または指示自体が外れていたと分類される
- **THEN** 決める役を `dev-workflow:decider`（`fable`）に上げ、実行役は `sonnet` または `opus` のままとする

#### Scenario: 実行役は Fable にならない
- **WHEN** 昇格ラダーのどの段階かにかかわらず実行役のモデルを決める
- **THEN** 上限は `opus` で、`model: fable` の実行役 spawn は `agent-model-guard.sh` に拒否される

#### Scenario: exhausted では昇格が Opus 上限
- **WHEN** `FABLE_BUDGET_MODE=exhausted` のセッションで失敗ループのトリップワイヤーを踏む
- **THEN** interactive / unmanned を問わず昇格は Opus までに留まり、決める役は `dev-workflow:decider` のまま `model: opus` で立てられる（種別は変えない）

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
dev-workflow プラグインは `hooks/hooks.json` を配布し、SessionStart イベント（matcher: `startup|clear|compact`）で注入スクリプトを起動しなければならない（SHALL）。コマンドパスは `${CLAUDE_PLUGIN_ROOT}` を使用する。スクリプトは `templates/escalation-tripwires.md` の「## 昇格トリップワイヤー」節を抽出し、`{"additionalContext": "<節の本文>"}` の JSON を stdout に出力する（single source of truth: 本文の複製を hook 側に持たない）。`TRIPWIRES_SCOPE` が未設定のとき、テンプレートが見つからない・節が抽出できない場合は無出力・exit 0 で終了しなければならない（MUST NOT block session start）。`TRIPWIRES_SCOPE=subagent-budget` のときの出力は要件「SubagentStart hook が dev-workflow の役に運用情報を注入する」が定める。

#### Scenario: 注入 JSON が節を含む
- **WHEN** `CLAUDE_PLUGIN_ROOT` をプラグインルートに設定してスクリプトを実行する
- **THEN** stdout は valid JSON で、`additionalContext` に「昇格トリップワイヤー」「規模超過」「失敗ループ」「仕様の発明」を含む

#### Scenario: テンプレート欠損時は fail-soft
- **WHEN** `TRIPWIRES_SCOPE` 未設定で、`CLAUDE_PLUGIN_ROOT` をテンプレートの無いディレクトリに設定してスクリプトを実行する
- **THEN** exit code 0 で出力は空である

#### Scenario: hooks.json の構造
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` をパースする
- **THEN** SessionStart エントリが存在し、matcher が `startup|clear|compact`、command が `${CLAUDE_PLUGIN_ROOT}` 経由でスクリプトを指している

### Requirement: usage-probe と snapshot 契約
dev-workflow プラグインは `plugins/dev-workflow/scripts/usage-probe.sh` を配布しなければならない（SHALL）。probe は使用量の補助の情報源であり（主な情報源は `usage-session-records` capability のセッション記録）、アカウントレジストリ（`usage-account-registry` capability）のスロットのうち下記の実行条件を満たすものだけについて、スロットごとに導出した Keychain サービス名で認証情報を取得して OAuth usage API（既定の取得先は `https://api.anthropic.com/api/oauth/usage?cedar_ember=1&skip_spend=1`。`USAGE_PROBE_ENDPOINT` で上書き可）をフェッチし、`~/.claude/.usage-snapshot`（`USAGE_SNAPSHOT` で上書き可）に JSON を書く。

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
      "fable_active": true,
      "reset_grants": [
        {"resets_left": 1, "ends_at": "2026-11-02T03:00:00.123Z", "paused": false}
      ]
    }
  }
}
```

- `schema`: `2`
- `active`: 現在アクティブなスロットの id。判定規則は `usage-account-registry` capability の「active スロットの判定規則」に従う
- `accounts`: スロット id をキーとするオブジェクト。各スロットの値フィールドのキー名は上記に固定する（`label` / `securestorage` / `fetched_at` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `fable_weekly_pct` / `fable_active`）。値が得られないフィールドは `null` とする。ただし任意の欄 `reset_grants` はこの限りでなく、得られないときは `null` にせずキーごと出さない
- `reset_grants`（任意）: そのスロットのリセット権。応答の `cedar_ember.grants` の各束から `resets_left`・`ends_at`・`paused` の 3 つだけを、値を変えずに写した配列でなければならない（SHALL）。`ends_at` は epoch に直さず、ISO 8601 の文字列か `null` のまま渡す。束は選り分けない（`paused` が true の束や `resets_left` が 0 の束も写す。数え方は読み手が持つ）。元の束に無い欄は省いても `null` にしてもよい。`cedar_ember` が無い・`null`、`eligible` が true でない、`grants` が配列でない、のいずれかのときは欄を出さない（SHALL）。`grants` が元から空の配列なら `[]` を出す。`grants` が空でないのに、すべての要素が束（オブジェクト）でなく写せる束が 1 つも無いときは、確定した 0 回と区別するため欄を出さない（一部だけ不正なときは、写せる束だけを出す）。層間契約であり、読み手はダッシュボード（genetta-inc/flatmate#1654）と statusline
- スロットの `fetched_at`: **そのスロットの値を実際に取得できた時刻**（epoch 秒）。fail-open で前回値を引き継いだスロットは、前回の `fetched_at` をそのまま保たなければならない（SHALL）。probe の実行時刻を書いてはならない（MUST NOT）
- トップレベルの `fetched_at` / `fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch`: **active スロットの同名フィールドをミラーしたもの**でなければならない（SHALL）。既存の読み手（statusline の Fable 表示と 6 時間鮮度ゲート、および外部の読み手）を無改修で動かすための後方互換であり、独立に計算してはならない（MUST NOT）。特にトップレベル `fetched_at` は probe の実行時刻ではなく active スロットの取得時刻である（statusline の鮮度ゲートがこの値を読むため、実行時刻を書くと古い数字が新鮮な顔で表示される）

**実行条件**: probe はスロットごとに、次のすべてを満たすときだけ API をフェッチしなければならない（SHALL）。満たさないスロットはフェッチせず、スロット単位 fail-open と同じく前回値を保つ。snapshot の mtime による TTL で判定してはならない（MUST NOT）（全スロットが失敗すると mtime が進まず、呼ばれるたびに叩き直すため）。`USAGE_PROBE_TTL` は読まない。

- 次のどちらかに当たる: そのスロットのセッション記録が無い、または記録の `observed_at` が `USAGE_PROBE_STALE` 秒（既定 10800）より古い／snapshot の同スロットの `fetched_at` が `USAGE_PROBE_STALE` 秒より古い（同スロットや `fetched_at` が無い場合を含む）。後者を含めるのは、Fable 週次がセッション記録に入らず probe からしか得られないため（会話中のアカウントでも Fable の値と statusline の 6 時間鮮度ゲートが止まらないようにする）
- 試行状態ファイル（`USAGE_PROBE_STATE`、既定 `~/.claude/.usage-probe-state`）にあるそのスロットの前回の試行時刻から `USAGE_PROBE_INTERVAL` 秒（既定 10800）以上経っている
- そのスロットが 429 による待ち時間の中にいない
- そのスロットがオフ（`accounts.json` の `enabled: false`）でない。オフのスロットはセッション記録や snapshot がどれだけ古くてもフェッチせず、前回値を保つ（正本は `usage-account-registry` capability の要件「オフのスロットは使用量を取得しない」）

probe はフェッチを試みたスロットごとに、結果（200・429・その他の失敗）にかかわらず試行時刻を試行状態ファイルに記録しなければならない（SHALL）。HTTP 429 を受けたスロットは連続 429 回数を 1 増やし、前回の試行から `USAGE_PROBE_INTERVAL × 2^(回数-1)` 秒（上限 86400 秒）経つまで次の試行をしてはならない（MUST NOT）。200 を受けたら連続 429 回数を 0 に戻す。試行状態ファイルは一時ファイルからの置き換えで書き、読めない・壊れているときは全スロットを未試行として扱う。

**マシン全体で 1 本**: probe はフェッチの前に `USAGE_PROBE_LOCK`（既定 `~/.claude/.usage-probe.lock`）をディレクトリ作成で取らなければならない（SHALL）。取れなければ何もせず exit 0 で終わる。ロックが 120 秒より古いときは前の probe が異常終了したとみなして取り直してよい（MAY）。終了時（失敗時を含む）にロックを外さなければならない（SHALL）。実行条件を満たすスロットが 1 つも無いときは、API を叩かず snapshot を書かずに exit 0 で終わる。

**fail-open はスロット単位で行う**（SHALL）。あるスロットの認証取得・通信・パースが失敗した場合、そのスロットの値は既存 snapshot の同スロットの前回値（`fetched_at` を含む）を引き継いで保持し、他スロットの新しい値は書く。

**API のエラーレスポンスは失敗として扱わなければならない**（SHALL）。HTTP 401 / 429 / 5xx でも API は正しい JSON のオブジェクト（`{"type":"error", ...}`）を返すため、JSON として読めたことを成功の判定に使ってはならない（MUST NOT）。使用量の数字（`five_hour` / `seven_day` / モデル別 weekly）が 1 つも取れなかったレスポンスは失敗とし、そのスロットの前回値を全 `null` で上書きしてはならない（MUST NOT）。非 active アカウントは OAuth アクセストークンの期限切れでこの経路に入るのが常態であり、ここを塞がなければスロット単位 fail-open が機能しない。非 active アカウントは OAuth アクセストークンの期限切れでフェッチが落ちるのが常態であるため、1 スロットの失敗が snapshot 全体の更新を止めてはならない（MUST NOT）。今回も取れず前回値も無いスロットは、全フィールドが `null` の欠測スロットとして `accounts` に載せる。

**`reset_grants` の寿命**は次のとおりでなければならない（SHALL）。取得に成功しパースできたスロットは、その応答から作り直す（条件を満たさなければ欄を出さない）。フェッチを試みて失敗したスロット（通信・認証・パースの失敗、API のエラーレスポンスを含む）は欄を出さず、前回の値を写し直さない（MUST NOT）。フェッチを試みなかったスロット（実行条件を満たさない・オフ）は、他の値フィールドと同じく前回の `reset_grants` を `fetched_at` と一緒に保つ。

**全スロットの取得が失敗したときの例外**: 新しい値が 1 つも得られず snapshot を書かない既存の規則（下記）のままでは、試みて失敗したスロットの前回の `reset_grants` が残ってしまう。そこで、新しい値が 1 つも得られなかった場合でも、既存 snapshot が読めて、フェッチを試みて失敗したスロットに `reset_grants` があるときに限り、probe はその欄だけを除いた snapshot を書かなければならない（SHALL）。使用率・`fetched_at`・`label` などの他のフィールド、トップレベルのミラー、フェッチを試みなかったスロットの欄は 1 バイトも変えない（MUST NOT）。除く欄が 1 つも無い、または既存 snapshot が無い・読めないときは、従来どおり何も書かない。

どのスロットからも新しい値が得られなかった場合は、上の `reset_grants` の例外に当たるときを除き、exit 0 で終了し snapshot を書いてはならない（MUST NOT）。snapshot の組み立て・書き込みが失敗した場合も、exit 0 で終了し snapshot を書いてはならない（MUST NOT）（既存 snapshot を破壊しない）。probe はいかなる失敗でも非 0 で終了してはならない（MUST NOT）。

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

#### Scenario: セッション記録が新しいスロットはフェッチしない
- **WHEN** 2 スロットのうち A の鍵のセッション記録が 10 分前で A の snapshot の `fetched_at` も 10 分前、B の記録が無く、どちらも未試行の状態で probe を実行する
- **THEN** B だけをフェッチし、A は API を叩かず前回値を保つ

#### Scenario: 記録は新しいが snapshot が古いスロットはフェッチする
- **WHEN** A の鍵のセッション記録が 10 分前、A の snapshot の `fetched_at` が 4 時間前（または A が snapshot に無い）で、A が未試行の状態で probe を実行する
- **THEN** A をフェッチし、snapshot の A の `fable_weekly_pct` と `fetched_at` が新しい値になる

#### Scenario: 間隔内の再実行はフェッチしない
- **WHEN** 試行状態ファイルに全スロットの試行時刻が 1 時間前と記録された状態で、既定の間隔で probe を実行する
- **THEN** どのスロットもフェッチせず、snapshot を書かずに exit 0 で終わる

#### Scenario: 全スロット失敗でも呼ばれるたびに叩き直さない
- **WHEN** 全スロットのフェッチが失敗した直後に、もう一度 probe を実行する
- **THEN** 2 回目はどのスロットもフェッチしない

#### Scenario: 429 が続くと間隔を空ける
- **WHEN** あるスロットが 2 回続けて 429 を受け、前回の試行から `USAGE_PROBE_INTERVAL` の 1.5 倍の時間が経った状態で probe を実行する
- **THEN** そのスロットはフェッチされない（待ち時間は間隔の 2 倍）
- **AND** 前回の試行から間隔の 2 倍以上経ったあとの実行ではフェッチされる

#### Scenario: 200 で 429 の回数が戻る
- **WHEN** 連続 429 回数が 3 のスロットが 200 を受ける
- **THEN** 試行状態ファイルのそのスロットの連続 429 回数は 0 になる

#### Scenario: ロックが取れなければ何もしない
- **WHEN** 60 秒前に作られたロックがある状態で probe を実行する
- **THEN** API を叩かず snapshot も試行状態ファイルも変えずに exit 0 で終わる

#### Scenario: 古いロックは取り直す
- **WHEN** 300 秒前に作られたロックが残った状態で、実行条件を満たすスロットがある probe を実行する
- **THEN** ロックを取り直してフェッチし、終了時にロックを外す

#### Scenario: スロット単位 fail-open で前回値が残る
- **WHEN** 2 スロットのうち片方のフェッチが失敗し、既存 snapshot にそのスロットの前回値がある状態で probe を実行する
- **THEN** 失敗したスロットは前回値と前回の `fetched_at` を保ったまま残り、成功したスロットは新しい値に更新される

#### Scenario: 前回値も無いスロットは欠測として載る
- **WHEN** あるスロットのフェッチが失敗し、既存 snapshot にもそのスロットの値が無い状態で probe を実行する
- **THEN** そのスロットは全フィールドが `null` の欠測スロットとして `accounts` に載る

#### Scenario: API エラーレスポンスは失敗として扱う
- **WHEN** あるスロットの API が `{"type":"error", ...}` のエラーボディを返し、既存 snapshot にそのスロットの前回値がある状態で probe を実行する
- **THEN** そのスロットは前回値と前回の `fetched_at` を保ち、全 `null` で上書きされない

#### Scenario: 全スロット失敗時は fail-open
- **WHEN** 全スロットで認証取得または API 取得が失敗し、既存 snapshot に削除対象の `reset_grants`（試みて失敗したスロットの欄）が無い
- **THEN** exit code 0 で終了し、新しい snapshot を書かない（既存 snapshot があればそのまま残す）

#### Scenario: スロットが 1 つのときは現行と同じ形に落ちる
- **WHEN** レジストリが存在しない状態で有効な usage API レスポンスを与えて probe を実行する
- **THEN** `accounts` は既定スロット 1 つだけを持ち、トップレベルの従来キー（`fetched_at` を含む）は変更前と同じ値になる（既存の読み手が無改修で動く）

#### Scenario: reset_grants を束の値を変えずに写す
- **WHEN** 応答の `cedar_ember` が `eligible: true` で、`grants` に `paused` が true の束と `resets_left` が 0 の束と `ends_at` が null の束を含み、各束に他の欄（`id` / `type` など）もある状態で probe を実行する
- **THEN** snapshot の該当スロットの `reset_grants` は同じ順序の配列で、各要素は `resets_left` / `ends_at` / `paused` だけを持ち、値は応答と同じ（`ends_at` は ISO 8601 の文字列か null のまま）

#### Scenario: eligible でないときは reset_grants を出さない
- **WHEN** 応答の `cedar_ember` が無い、`null`、`eligible: false`、`grants` が配列でない、のいずれかである
- **THEN** そのスロットに `reset_grants` のキーは無く、他の値フィールドは通常どおり書かれる

#### Scenario: 空の grants は空配列
- **WHEN** 応答の `cedar_ember` が `eligible: true` で `grants` が `[]` である
- **THEN** そのスロットの `reset_grants` は `[]` である

#### Scenario: 取得に失敗したスロットは前回の reset_grants を写し直さない
- **WHEN** 既存 snapshot のスロットに `reset_grants` があり、そのスロットのフェッチを試みて失敗する（429 またはエラーボディ）
- **THEN** そのスロットの他の値フィールドは前回値を保つが、`reset_grants` のキーは無い

#### Scenario: 全スロットが失敗しても失敗したスロットの reset_grants だけを除く
- **WHEN** 既存 snapshot の 2 スロットがどちらも `reset_grants` と使用率を持ち、両方のフェッチが失敗する（429 またはエラーボディ）
- **THEN** snapshot は書き直され、両スロットの `reset_grants` のキーが無く、使用率・`fetched_at`・トップレベルのミラーは前回のまま変わらない

#### Scenario: 一部失敗と未試行が混ざる
- **WHEN** 3 スロットのうち A が成功、B が失敗、C は間隔内で未試行で、既存 snapshot の B と C に `reset_grants` がある
- **THEN** A は応答から作り直され、B の `reset_grants` は無く、C の `reset_grants` は前回のまま残る

#### Scenario: 全件失敗で除く欄が無ければ何も書かない
- **WHEN** 全スロットのフェッチが失敗し、既存 snapshot のどのスロットにも `reset_grants` が無い
- **THEN** snapshot は書き換えられない（ファイルの内容が変わらない）

#### Scenario: 全要素が不正な grants は欄を出さない
- **WHEN** 応答の `cedar_ember` が `eligible: true` で `grants` が `[null, 3]` である
- **THEN** そのスロットに `reset_grants` のキーは無い（元から空の `[]` とは区別される）

#### Scenario: 一部だけ不正な grants は写せる束だけを出す
- **WHEN** `grants` が `[null, {"resets_left": 1, "ends_at": null, "paused": false}]` である
- **THEN** `reset_grants` は後者の 1 要素だけの配列である

#### Scenario: cedar_ember だけで使用率が無い応答は失敗として扱う
- **WHEN** 応答が `cedar_ember` だけを持ち `five_hour` / `seven_day` / モデル別 weekly のどれも無い
- **THEN** そのスロットは失敗扱いで、使用率は前回値のまま、`reset_grants` のキーは無い

#### Scenario: 使用率が一部だけ欠ける応答は従来どおり欠けた分が null になる
- **WHEN** 応答に `seven_day` だけがあり `five_hour` が無く、`cedar_ember` が有効である
- **THEN** 従来（`cedar_ember` なしの応答）と同じ規則で `five_hour_pct` は `null`、`weekly_all_pct` は値が入り、`reset_grants` も書かれる

#### Scenario: 試みなかったスロットは前回の reset_grants を保つ
- **WHEN** 2 スロットのうち片方だけが実行条件を満たしてフェッチされ、もう片方の既存 snapshot に `reset_grants` がある
- **THEN** フェッチされなかったスロットの `reset_grants` は前回のまま残る

#### Scenario: 既定の取得先にクエリが付く
- **WHEN** `USAGE_PROBE_ENDPOINT` を設定せずに probe のスクリプトを調べる
- **THEN** 既定の取得先は `https://api.anthropic.com/api/oauth/usage?cedar_ember=1&skip_spend=1` である

**`reset_grants` の守備範囲**（この要件の `reset_grants` の抽出と寿命に限る）
- 入力の出どころ: 本物の Anthropic usage API の応答（認証済みの自分のアカウント）と、テスト用の応答ファイルだけ。外部の第三者が入力を作る経路は無い
- 拾う誤り: 型の崩れ（`cedar_ember` が dict でない、`grants` が配列でない、要素がオブジェクトでない）と、欄の条件を満たさない形。これらは欄を出さない（要素の一部だけが不正なら写せる束だけを出す）
- 意図的に通す入力: 未知のキー（捨てる）、`resets_left` / `ends_at` / `paused` の欠落や null や意味の合わない値（そのまま写す。値の意味の検証と数え方は読み手が持つ）、`paused` が true の束と `resets_left` が 0 の束（選り分けない）
- 未知の穴を塞ぎ切ることをこの要件の完了条件にしない。非公開の呼び方で予告なく形が変わりうるので、想定外の形は「欄を出さない」に倒し、使用率の取得を止めない

### Requirement: SessionStart で残量モードを自動導出注入
`scripts/session-tripwires.sh` は SessionStart 時に usage-probe を best-effort 実行し、active スロットの実効値（`usage-session-records` capability の「記録と snapshot から実効値を求める」。active スロットは `usage-account-registry` の active スロットの判定規則で起動環境から求める）から導出した残量モードと Fable 残量% を additionalContext に含めなければならない（SHALL）。snapshot のトップレベルのミラーを導出に使ってはならない（MUST NOT）。導出の式と優先順位（明示 env > データ無し > 90% 超 > 週経過との比較）は変えない。導出モードのブロックはトリップワイヤー節と併せて注入する。明示 env `FABLE_BUDGET_MODE` があるときはそれを優先し、導出値ではなく明示値を提示する。probe やパースが失敗しても、トリップワイヤー注入自体は従来どおり行われなければならない（SHALL）(probe 失敗が hook 全体を壊さない)。

`scripts/agent-model-guard.sh` の fork 拒否判定で使う共有枠モードも、active スロットの実効値から同じ式で導出しなければならない（SHALL）。

#### Scenario: 導出モードと残量% を注入する
- **WHEN** active スロットの実効値が求まる状態で SessionStart スクリプトを実行する
- **THEN** additionalContext に導出された残量モードと Fable 残量%（100 − 実効値の `fable_weekly_pct`）が含まれる

#### Scenario: 明示 env が導出を上書きする
- **WHEN** `FABLE_BUDGET_MODE` を明示設定して SessionStart スクリプトを実行する
- **THEN** additionalContext は導出値ではなく明示された値を現在モードとして提示する

#### Scenario: probe 失敗でもトリップワイヤーは載る
- **WHEN** snapshot もセッション記録も無い / probe が失敗する状態で SessionStart スクリプトを実行する
- **THEN** 昇格トリップワイヤー節は従来どおり注入され、残量モードは conserve 既定として提示される

#### Scenario: 使用量 API が 429 を返し続けても共有枠モードはセッション記録から導出する
- **WHEN** snapshot が無く、active スロットの鍵のセッション記録に週次 95% がある状態で SessionStart スクリプトを実行する
- **THEN** additionalContext の共有枠モードは `depleted`（自動導出）になる

#### Scenario: 古い snapshot の Fable 値はリセット時刻で読む
- **WHEN** 2 日前に取得した snapshot の active スロットが Fable 95%・リセット時刻が現在より前である状態で SessionStart スクリプトを実行する
- **THEN** Fable を 0% として導出し、`exhausted` にならない

#### Scenario: fork の共有枠判定もセッション記録を使う
- **WHEN** snapshot が無く、active スロットの鍵のセッション記録に週次 95% がある状態で、`SHARED_BUDGET_MODE` 未設定のまま `subagent_type: fork` の Agent 呼び出しを agent-model-guard に渡す
- **THEN** guard は共有枠モード `depleted` として fork を拒否する

### Requirement: セッション途中のプラグイン更新を CLAUDE_PLUGIN_ROOT の変化で検知して再注入する

`plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh`（UserPromptSubmit hook）は、プラグインの更新の検知に `plugin.json` の `version` を使ってはならない（MUST NOT。issue #447 で撤去したため）。代わりに `CLAUDE_PLUGIN_ROOT` の値（キャッシュの版名＝commit SHA をディレクトリ名に含むパス）をセッションごとの状態ファイルに記録し、記録済みの値と異なるときだけ昇格トリップワイヤー＋残量モードの本文を再注入しなければならない（MUST）。毎プロンプト走る一致時の経路では、今と同じく python3 と find を起動せず、`plugin.json` を読むための処理も足さずに無出力で終わらなければならない（MUST）。`plugin.json` に `version` が無くても、あっても、動作は同じでなければならない（MUST）。既存の契約（セッションの初回は記録だけで注入しない・状態のセッション単位の分離・30 日より古い状態の掃除・全経路 fail-soft で exit 0）は変えない。`CLAUDE_PLUGIN_ROOT` が同じまま中身が変わる経路（`--plugin-dir` での開発中など）は検知しない。旧方式でも版を変えない限り同じく検知しなかったので、対象外とする。キャッシュのパスには版が入るので、旧方式の版の変化と新方式のパスの変化は同じ事象を見ており、検知できる範囲は狭まらない。状態ファイルは `CLAUDE_PLUGIN_ROOT` の外に置くので、パスが変わっても引き継がれる。

#### Scenario: version の無い plugin.json で初回は記録だけする

- **WHEN** `version` の無い `plugin.json` を持つ `CLAUDE_PLUGIN_ROOT` で、状態ファイルの無いセッションの最初のプロンプトを送る
- **THEN** 無出力で exit 0 し、状態ファイルに `CLAUDE_PLUGIN_ROOT` の値が記録される

#### Scenario: 同じ CLAUDE_PLUGIN_ROOT の間は無出力

- **WHEN** 記録済みと同じ `CLAUDE_PLUGIN_ROOT` で次のプロンプトを送る
- **THEN** 無出力で exit 0 する

#### Scenario: CLAUDE_PLUGIN_ROOT が変わったら再注入する

- **WHEN** プラグインの更新で `CLAUDE_PLUGIN_ROOT` が別のディレクトリ（例: `.../dev-workflow/<旧SHA>` から `.../dev-workflow/<新SHA>`）に変わった後にプロンプトを送る
- **THEN** `hookSpecificOutput.additionalContext` に本文を出力し、状態ファイルが新しい値に更新される

#### Scenario: 旧方式の状態ファイルからの移行

- **WHEN** 状態ファイルに旧方式の版番号（例: `2.13.38`）が記録されているセッションでプロンプトを送る
- **THEN** 記録と一致しないので 1 回だけ再注入し、以後は `CLAUDE_PLUGIN_ROOT` の値で比較する

### Requirement: SubagentStart hook が dev-workflow の役に運用情報を注入する

dev-workflow プラグインは `hooks/hooks.json` に SubagentStart のエントリを持ち、matcher `^dev-workflow:(worker|reviewer|gate-runner)$` で `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-start-context.sh` を起動しなければならない（SHALL）。

スクリプトは stdin の hook 入力の `agent_type` を自分でも照合し、`dev-workflow:worker` / `dev-workflow:reviewer` / `dev-workflow:gate-runner` のどれでもなければ何も出力せず exit 0 で終わらなければならない（MUST）。対象のときは `{"hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": "<本文>"}}` を stdout に出す（SHALL）。本文は役ごとに次の行を含む:

- worker と gate-runner: Fable 残量モードと共有枠モード（現在値・出どころ・効果）、途中計測の閾値の現在値
- reviewer: 途中計測の閾値の現在値だけ（Fable 残量モードと共有枠モードを含めてはならない（MUST NOT））

残量モードの導出は `scripts/session-tripwires.sh` と同じ式・同じ優先順位で行い、式を別の場所に複製してはならない（MUST NOT）。`session-tripwires.sh` は環境変数 `TRIPWIRES_SCOPE=subagent-budget` のとき残量モードのブロックだけを本文のテキストで出し、その範囲では usage-probe を実行しない（SHALL）。`subagent-budget` のときの出力範囲は、`## Fable 残量モード（自動導出）` の見出しから共有枠モードの効果の行までで、親向けの「W を SendMessage で再開する前に `subagent-context.sh` で測る」行・メモリ索引の検知行・昇格トリップワイヤー節を含めてはならない（MUST NOT）。この範囲はテンプレートが無くても出す（SHALL）。`TRIPWIRES_SCOPE` が未設定、または `subagent-budget` 以外の値のときの `session-tripwires.sh` の出力は従来と変えない（SHALL）。

途中計測の行は、hook 実行時の `DEV_WORKFLOW_CONTEXT_CAP` / `DEV_WORKFLOW_CONTEXT_HARD_CAP` の実効値（未設定なら `scripts/context-tripwire.sh` と同じ既定値）と、`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` で全解除されているかを示し、扱いの規則は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」を読むよう案内する（SHALL）。規則の言い換えを本文に書いてはならない（MUST NOT）。

照合の守備範囲は、matcher が効かない・手で実行された・別の設定から流用された経路で対象外の役に返さないことまでとする。Agent Teams の teammate 化で `agent_type` が変わる経路、将来の命名変更、SubagentStart hook がそもそも発火しない経路は守らない。実機で `agent_type` が違う形で届くと判明したら照合と matcher をその形に合わせ、それ以外の穴を塞ぎ切ることは完了条件にしない。

python3 が無い・入力が JSON でない・`agent_type` が無い・残量ブロックの生成が失敗した、のどの場合もサブエージェントの起動を止めてはならず、exit 0 で終わらなければならない（MUST）。残量ブロックが作れなくても途中計測の行は出す。

#### Scenario: worker の入力に運用情報を返す
- **WHEN** `{"hook_event_name":"SubagentStart","agent_type":"dev-workflow:worker"}` を stdin に渡してスクリプトを実行する
- **THEN** stdout は valid JSON で、`hookSpecificOutput.hookEventName` が `SubagentStart`、`hookSpecificOutput.additionalContext` に `FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE`・途中計測の閾値の値・`decision-criteria.md` への案内が含まれる

#### Scenario: Explore の入力には何も返さない
- **WHEN** `{"hook_event_name":"SubagentStart","agent_type":"Explore"}` を stdin に渡してスクリプトを実行する
- **THEN** exit code 0 で stdout は空である

#### Scenario: decider と他プラグインのエージェントにも何も返さない
- **WHEN** `agent_type` が `dev-workflow:decider` または `casting:casting-arbiter` の入力を渡してスクリプトを実行する
- **THEN** exit code 0 で stdout は空である

#### Scenario: reviewer には残量モードを渡さない
- **WHEN** `agent_type` が `dev-workflow:reviewer` の入力を渡してスクリプトを実行する
- **THEN** `additionalContext` に途中計測の閾値の値が含まれ、`FABLE_BUDGET_MODE` と `SHARED_BUDGET_MODE` は含まれない

#### Scenario: 明示 env の残量モードがそのまま届く
- **WHEN** `FABLE_BUDGET_MODE=reserve` と `SHARED_BUDGET_MODE=throttled` を設定し、`agent_type` が `dev-workflow:gate-runner` の入力を渡してスクリプトを実行する
- **THEN** `additionalContext` は Fable 残量モード `reserve`（明示 env）と共有枠モード `throttled`（明示 env）を提示する

#### Scenario: 閾値の env 上書きと既定値
- **WHEN** `DEV_WORKFLOW_CONTEXT_CAP=90000` を設定して worker の入力を渡す／未設定で渡す
- **THEN** 前者の本文は 90000 を、後者は `context-tripwire.sh` の既定値と同じ値を提示する

#### Scenario: 壊れた入力でも起動を止めない
- **WHEN** JSON でない文字列、または `agent_type` の無い JSON を stdin に渡してスクリプトを実行する
- **THEN** exit code 0 で stdout は空である

#### Scenario: subagent-budget はテンプレートが無くても残量ブロックだけを出す
- **WHEN** テンプレートの無いディレクトリを `CLAUDE_PLUGIN_ROOT` にし（`scripts/` だけは実物を指す構成で）、`TRIPWIRES_SCOPE=subagent-budget` で `session-tripwires.sh` を実行する
- **THEN** stdout は `## Fable 残量モード` で始まる本文テキストで、`subagent-context.sh` を含まず、usage-probe の実行痕（probe の状態ファイル・snapshot の書き込み）が残らない

#### Scenario: SessionStart の出力は変わらない
- **WHEN** `TRIPWIRES_SCOPE` を設定せずに `session-tripwires.sh` を実行する
- **THEN** 出力は従来どおり `additionalContext` に昇格トリップワイヤー節と残量モードのブロックを含む JSON である

#### Scenario: hooks.json の SubagentStart エントリ
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` をパースする
- **THEN** SubagentStart エントリが存在し、matcher が `^dev-workflow:(worker|reviewer|gate-runner)$`、command が `${CLAUDE_PLUGIN_ROOT}` 経由で `scripts/subagent-start-context.sh` を指している

