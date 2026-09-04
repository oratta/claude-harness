## MODIFIED Requirements

### Requirement: usage-probe と snapshot 契約
dev-workflow プラグインは `plugins/dev-workflow/scripts/usage-probe.sh` を配布しなければならない（SHALL）。probe はアカウントレジストリ（`usage-account-registry` capability）の全スロットをループし、スロットごとに導出した Keychain サービス名で認証情報を取得して OAuth usage API（`/api/oauth/usage`）をフェッチし、`~/.claude/.usage-snapshot`（`USAGE_SNAPSHOT` で上書き可）に JSON を書く。

snapshot は **schema 2** であり、次を含まなければならない（SHALL）:

- `schema`: `2`
- `accounts`: スロット id をキーとするオブジェクト。各スロットは少なくとも `five_hour`（消化率・`resets_at`）・`seven_day`（消化率・`resets_at`）・Fable weekly の消化率と `is_active`・そのスロットの取得時刻を持つ
- `active`: 現在アクティブなスロットの id（`CLAUDE_SECURESTORAGE_CONFIG_DIR` から判定する）
- トップレベルの従来キー `fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch`。これらは **active スロットの値をミラーしたもの**でなければならない（SHALL）。既存の読み手（`scripts/session-tripwires.sh` の `FABLE_BUDGET_MODE` 導出）を無改修で動かすための後方互換であり、独立に計算してはならない（MUST NOT）

snapshot が TTL（既定 300 秒、`USAGE_PROBE_TTL` で上書き可）以内に更新済みなら再フェッチしてはならない（SHALL NOT）。

**fail-open はスロット単位で行う**（SHALL）。あるスロットの認証取得・通信・パースが失敗した場合、そのスロットの値は既存 snapshot の同スロットの前回値（取得時刻ごと）を引き継いで保持し、他スロットの新しい値は書く。非 active アカウントは OAuth アクセストークンの期限切れでフェッチが落ちるのが常態であるため、1 スロットの失敗が snapshot 全体の更新を止めてはならない（MUST NOT）。

どのスロットからも新しい値が得られなかった場合、または snapshot の組み立て・書き込みが失敗した場合は、exit 0 で終了し snapshot を書いてはならない（MUST NOT）（既存 snapshot を破壊しない）。probe はいかなる失敗でも非 0 で終了してはならない（MUST NOT）。

probe は `refresh_token` を用いたアクセストークンの更新を行ってはならない（MUST NOT）。Claude Code 本体のリフレッシュと競合してトークンを無効化する危険があるため意図的に非対応とし、その理由をコードコメントに残さなければならない（SHALL）。

#### Scenario: snapshot に必須フィールドを書く
- **WHEN** 有効な usage API レスポンスを与えて probe を実行する
- **THEN** snapshot は valid JSON で、`schema` が 2、`accounts` にスロットごとの値、`active` に現在のスロット id を含み、トップレベルに Fable 週次消費率 `fable_weekly_pct` と `fable_active` を含む

#### Scenario: 複数スロットをそれぞれフェッチする
- **WHEN** 2 スロットのレジストリと、スロットごとに異なる usage API レスポンスを与えて probe を実行する
- **THEN** `accounts` に 2 スロット分の `five_hour` / `seven_day` / Fable weekly が、それぞれのレスポンスの値で入る

#### Scenario: トップレベルは active スロットのミラー
- **WHEN** 2 スロットのレジストリで、active でない方のスロットの値が active スロットと異なる状態で probe を実行する
- **THEN** トップレベルの `fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch` は `accounts` の active スロットの値と一致する

#### Scenario: 5 分キャッシュ
- **WHEN** TTL 以内に更新された snapshot が既に存在する状態で probe を実行する
- **THEN** API を再フェッチせず、既存 snapshot を維持する

#### Scenario: スロット単位 fail-open で前回値が残る
- **WHEN** 2 スロットのうち片方のフェッチが失敗し、既存 snapshot にそのスロットの前回値がある状態で probe を実行する
- **THEN** 失敗したスロットは前回値と前回の取得時刻を保ったまま残り、成功したスロットは新しい値に更新される

#### Scenario: 全スロット失敗時は fail-open
- **WHEN** 全スロットで認証取得または API 取得が失敗する
- **THEN** exit code 0 で終了し、新しい snapshot を書かない（既存 snapshot があればそのまま残す）

#### Scenario: スロットが 1 つのときは現行と同じ形に落ちる
- **WHEN** レジストリが存在しない状態で有効な usage API レスポンスを与えて probe を実行する
- **THEN** `accounts` は既定スロット 1 つだけを持ち、トップレベルの従来キーは変更前と同じ値になる（既存の読み手が無改修で動く）
