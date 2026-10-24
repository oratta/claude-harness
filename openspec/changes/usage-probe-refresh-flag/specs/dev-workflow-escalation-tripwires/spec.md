## MODIFIED Requirements

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

**手動の取り直し（`--refresh`）**: probe は引数 `--refresh` を受け付けなければならない（SHALL）。`--refresh` を付けて実行したときは、上の実行条件のうち 1 つ目（セッション記録と snapshot の鮮度）と 2 つ目（前回の試行から `USAGE_PROBE_INTERVAL` 秒）を判定に使ってはならず（MUST NOT）、3 つ目（429 による待ち時間の中にいない）と 4 つ目（オフでない）は引数なしのときと同じく満たすことを求めなければならない（SHALL）。429 の待ち時間の長さは `--refresh` の有無で変えてはならない（MUST NOT）（下の段落の式で、同じ `USAGE_PROBE_INTERVAL` を基準に測る）。待ち時間の中にいるスロットはフェッチせず、試行状態ファイルのそのスロットの試行時刻と連続 429 回数を変えてはならない（MUST NOT）。連続 429 回数が 1 以上でも、待ち時間が明けているスロットは待ち時間の中にいないものとして扱う。`--refresh` はその 1 回の実行にだけ効き、試行状態ファイルにも snapshot にも残さない。ロック・試行の記録・スロット単位 fail-open・snapshot の組み立ては引数なしのときと同じである。手で取り直す呼び出し元（ダッシュボードの取り直しボタンなど）のための指定であり、`USAGE_PROBE_INTERVAL=0` で間隔を外すと 429 の待ちも 0 になって待ち中のアカウントを叩いてしまうため、待ちを残したまま鮮度と間隔だけを外す手段として置く。

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

#### Scenario: --refresh は待ち中でないスロットを間隔内でも取り直す
- **WHEN** 2 スロットとも snapshot の `fetched_at` とセッション記録の `observed_at` が 10 分前、試行状態ファイルの試行時刻が 1 時間前、連続 429 回数が 0 の状態で、既定の間隔のまま `--refresh` を付けて probe を実行する
- **THEN** 両スロットをフェッチし、snapshot の各スロットの `fetched_at` は実行時刻になる
- **AND** 試行状態ファイルの両スロットの試行時刻は実行時刻になる

#### Scenario: --refresh でも 429 の待ち中のスロットは取りに行かない
- **WHEN** スロット a は連続 429 回数が 2 で前回の試行が `USAGE_PROBE_INTERVAL` の 1.5 倍前（待ち時間は間隔の 2 倍なので待ち中）、スロット b は連続 429 回数が 0 で前回の試行が 1 時間前の状態で、`--refresh` を付けて probe を実行する
- **THEN** スロット a はフェッチされず、snapshot のスロット a の値は前回値（`fetched_at` 込み）のまま残る
- **AND** 試行状態ファイルのスロット a の試行時刻と連続 429 回数（2）は変わらない
- **AND** スロット b はフェッチされ、snapshot のスロット b の `fetched_at` は実行時刻になる

#### Scenario: --refresh でも待ちが明けたスロットは取り直す
- **WHEN** 連続 429 回数が 2 で前回の試行が `USAGE_PROBE_INTERVAL` の 2 倍より前のスロットの snapshot の `fetched_at` が 10 分前の状態で、`--refresh` を付けて probe を実行し 200 を受ける
- **THEN** そのスロットをフェッチし、試行状態ファイルの連続 429 回数は 0 になる

#### Scenario: --refresh でもオフのスロットは取りに行かない
- **WHEN** スロット b が `enabled: false` の状態で `--refresh` を付けて probe を実行する
- **THEN** スロット b はフェッチせず、試行状態ファイルにも記録しない

#### Scenario: 引数なしの振る舞いは変わらない
- **WHEN** 試行状態ファイルに全スロットの試行時刻が 1 時間前と記録された状態で、引数なしで probe を実行する
- **THEN** どのスロットもフェッチせず、snapshot を書かずに exit 0 で終わる

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
