## MODIFIED Requirements

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

#### Scenario: 5 分キャッシュ
- **WHEN** TTL 以内に更新された snapshot が既に存在する状態で probe を実行する
- **THEN** API を再フェッチせず、既存 snapshot を維持する

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
