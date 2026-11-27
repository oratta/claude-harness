## MODIFIED Requirements

### Requirement: 明示指定が無い工程では provider の週次余裕から構成を選ぶ
develop role resolver は、profile と旧 account/model のどちらも明示されない各 canonical phase の開始時に、Claude 起動 account と登録 Codex accounts の週次余裕を評価しなければならない（MUST）。Claude 起動 account は `usage-account-registry` capability の「active スロットの判定規則」で起動環境から解決し、そのスロットの実効値（`usage-session-records` capability の「記録と snapshot から実効値を求める」。セッション記録と schema 2 snapshot の対応する `accounts` entry から求める）を読まなければならない（MUST）。余裕は reset までの週経過率から週次使用率を引いた未丸め値とし、0 以上を余裕あり、負値または欠測を詰まりとして design の選択表を適用しなければならない（MUST）。工程途中の role を切り替えてはならず、次工程で再評価しなければならない（MUST）。

各工程の自動選択は dev-workflow 同梱の `usage-probe.sh` を有限 timeout で best-effort 実行してから Claude の実効値を読み取らなければならない（MUST）。probe と reader は同じ `USAGE_SNAPSHOT` を使う。probe がフェッチしなかった・失敗した・timeout した場合も、既存の記録と snapshot から求めた実効値で評価しなければならない（MUST）。

#### Scenario: 両 provider に余裕がある
- **WHEN** Claude margin が +20、最良 Codex margin が +10 で profile を明示せず工程を開始する
- **THEN** `claude-write-codex-review` を選び、書く役と補助役は Claude、レビュー役と decider は Codex の系統名 astra に解決する

#### Scenario: Codex が詰まっている
- **WHEN** Claude margin が 0 以上で、最良 Codex margin が -5、欠測、または stale のいずれかである
- **THEN** coordinator の全役割 Claude 既定構成を選ぶ

#### Scenario: Claude だけが詰まっている
- **WHEN** Claude margin が -5 で最良 Codex margin が +30 である
- **THEN** `codex-standard` を選び、全 Codex role を代表 account に束縛する

#### Scenario: 両 provider が詰まっている
- **WHEN** Claude と最良 Codex の margin がともに -5、または双方が欠測である
- **THEN** 既に coordinator が動作している全役割 Claude 既定構成を選ぶ

#### Scenario: 明示 profile は自動選択を迂回する
- **WHEN** `--profile NAME` を明示して工程を開始する
- **THEN** Claude/Codex の snapshot を読み取らず、指定 profile の検証済み role tuple を返す

#### Scenario: 起動 account と snapshot.active が食い違う
- **WHEN** 起動時の `CLAUDE_SECURESTORAGE_CONFIG_DIR` から導出したサービス名がスロット A に一致し、schema 2 snapshot の `active` とトップレベルのミラーがスロット B を指す
- **THEN** `usage-account-registry` の優先順位に従ってスロット A の実効値から Claude margin を求め、スロット B のトップレベル値へフォールバックしない

#### Scenario: 使用量 API が 429 を返し続けてもセッション記録で評価する
- **WHEN** profile を明示せず canonical phase を開始し、probe が 429 で snapshot を更新できず、起動 account の鍵のセッション記録が 1 時間前の週次 20%（リセット時刻は現在より後）である
- **THEN** Claude margin をその記録から求め、欠測として扱わない。証跡の `fetched_at` には記録の `observed_at` を載せる

### Requirement: snapshot の鮮度と週次窓を fail-safe に検証する
Codex の自動選択は `fetched_at` が整数で `0 <= now - fetched_at <= 300`、週次使用率が有限の 0..100、reset が現在より後かつ 7 日以内の snapshot だけを fresh としなければならない（MUST）。Codex は `minutes=10080` の有効な window だけを週次比較に使い、5 時間窓や reset credit を代用してはならない（MUST NOT）。不正、未来時刻、301 秒以上古い値、期限切れ reset は欠測として扱わなければならない（MUST）。Claude 側は取得からの経過時間で判定せず、`usage-session-records` の実効値の規則（リセット時刻を過ぎた窓は 0%、過ぎていなければ下限）に従わなければならない（MUST）。Claude の実効値の週次使用率が有限の 0..100 でない、または週次のリセット時刻が求まらないときは欠測として扱わなければならない（MUST）。

#### Scenario: Codex の freshness 境界を判定する
- **WHEN** 同じ Codex snapshot の age を 300 秒と 301 秒にして評価する
- **THEN** 300 秒は fresh、301 秒は欠測となり、古い側を余っている provider/account として選ばない

#### Scenario: Claude の古い値はリセット前なら使う
- **WHEN** Claude の起動 account の値が 1 日前に取得され、週次のリセット時刻が現在より後である
- **THEN** その値から Claude margin を求め、欠測として扱わない

#### Scenario: 週次ではない Codex window を除外する
- **WHEN** Codex snapshot に fresh な 5 時間 window だけがある
- **THEN** Codex provider を欠測とし、その使用率を週次 margin に使わない
