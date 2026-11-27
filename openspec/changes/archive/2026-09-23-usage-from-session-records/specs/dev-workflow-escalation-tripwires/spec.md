## MODIFIED Requirements

### Requirement: usage-probe と snapshot 契約
dev-workflow プラグインは `plugins/dev-workflow/scripts/usage-probe.sh` を配布しなければならない（SHALL）。probe は使用量の補助の情報源であり（主な情報源は `usage-session-records` capability のセッション記録）、アカウントレジストリ（`usage-account-registry` capability）のスロットのうち下記の実行条件を満たすものだけについて、スロットごとに導出した Keychain サービス名で認証情報を取得して OAuth usage API（`/api/oauth/usage`）をフェッチし、`~/.claude/.usage-snapshot`（`USAGE_SNAPSHOT` で上書き可）に JSON を書く。

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
- トップレベルの `fetched_at` / `fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` / `five_hour_pct` / `five_hour_resets_at` / `five_hour_resets_epoch`: **active スロットの同名フィールドをミラーしたもの**でなければならない（SHALL）。既存の読み手（statusline の Fable 表示と 6 時間鮮度ゲート、および外部の読み手）を無改修で動かすための後方互換であり、独立に計算してはならない（MUST NOT）。特にトップレベル `fetched_at` は probe の実行時刻ではなく active スロットの取得時刻である（statusline の鮮度ゲートがこの値を読むため、実行時刻を書くと古い数字が新鮮な顔で表示される）

**実行条件**: probe はスロットごとに、次のすべてを満たすときだけ API をフェッチしなければならない（SHALL）。満たさないスロットはフェッチせず、スロット単位 fail-open と同じく前回値を保つ。snapshot の mtime による TTL で判定してはならない（MUST NOT）（全スロットが失敗すると mtime が進まず、呼ばれるたびに叩き直すため）。`USAGE_PROBE_TTL` は読まない。

- 次のどちらかに当たる: そのスロットのセッション記録が無い、または記録の `observed_at` が `USAGE_PROBE_STALE` 秒（既定 10800）より古い／snapshot の同スロットの `fetched_at` が `USAGE_PROBE_STALE` 秒より古い（同スロットや `fetched_at` が無い場合を含む）。後者を含めるのは、Fable 週次がセッション記録に入らず probe からしか得られないため（会話中のアカウントでも Fable の値と statusline の 6 時間鮮度ゲートが止まらないようにする）
- 試行状態ファイル（`USAGE_PROBE_STATE`、既定 `~/.claude/.usage-probe-state`）にあるそのスロットの前回の試行時刻から `USAGE_PROBE_INTERVAL` 秒（既定 10800）以上経っている
- そのスロットが 429 による待ち時間の中にいない

probe はフェッチを試みたスロットごとに、結果（200・429・その他の失敗）にかかわらず試行時刻を試行状態ファイルに記録しなければならない（SHALL）。HTTP 429 を受けたスロットは連続 429 回数を 1 増やし、前回の試行から `USAGE_PROBE_INTERVAL × 2^(回数-1)` 秒（上限 86400 秒）経つまで次の試行をしてはならない（MUST NOT）。200 を受けたら連続 429 回数を 0 に戻す。試行状態ファイルは一時ファイルからの置き換えで書き、読めない・壊れているときは全スロットを未試行として扱う。

**マシン全体で 1 本**: probe はフェッチの前に `USAGE_PROBE_LOCK`（既定 `~/.claude/.usage-probe.lock`）をディレクトリ作成で取らなければならない（SHALL）。取れなければ何もせず exit 0 で終わる。ロックが 120 秒より古いときは前の probe が異常終了したとみなして取り直してよい（MAY）。終了時（失敗時を含む）にロックを外さなければならない（SHALL）。実行条件を満たすスロットが 1 つも無いときは、API を叩かず snapshot を書かずに exit 0 で終わる。

**fail-open はスロット単位で行う**（SHALL）。あるスロットの認証取得・通信・パースが失敗した場合、そのスロットの値は既存 snapshot の同スロットの前回値（`fetched_at` を含む）を引き継いで保持し、他スロットの新しい値は書く。

**API のエラーレスポンスは失敗として扱わなければならない**（SHALL）。HTTP 401 / 429 / 5xx でも API は正しい JSON のオブジェクト（`{"type":"error", ...}`）を返すため、JSON として読めたことを成功の判定に使ってはならない（MUST NOT）。使用量の数字（`five_hour` / `seven_day` / モデル別 weekly）が 1 つも取れなかったレスポンスは失敗とし、そのスロットの前回値を全 `null` で上書きしてはならない（MUST NOT）。非 active アカウントは OAuth アクセストークンの期限切れでこの経路に入るのが常態であり、ここを塞がなければスロット単位 fail-open が機能しない。非 active アカウントは OAuth アクセストークンの期限切れでフェッチが落ちるのが常態であるため、1 スロットの失敗が snapshot 全体の更新を止めてはならない（MUST NOT）。今回も取れず前回値も無いスロットは、全フィールドが `null` の欠測スロットとして `accounts` に載せる。

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
- **WHEN** 全スロットで認証取得または API 取得が失敗する
- **THEN** exit code 0 で終了し、新しい snapshot を書かない（既存 snapshot があればそのまま残す）

#### Scenario: スロットが 1 つのときは現行と同じ形に落ちる
- **WHEN** レジストリが存在しない状態で有効な usage API レスポンスを与えて probe を実行する
- **THEN** `accounts` は既定スロット 1 つだけを持ち、トップレベルの従来キー（`fetched_at` を含む）は変更前と同じ値になる（既存の読み手が無改修で動く）

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
