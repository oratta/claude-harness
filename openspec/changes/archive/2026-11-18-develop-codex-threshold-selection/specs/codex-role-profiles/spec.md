## MODIFIED Requirements

### Requirement: 明示指定が無い工程では provider の週次余裕から構成を選ぶ
develop role resolver は、profile と旧 account/model のどちらも明示されない各 canonical phase の開始時に、Claude 起動 account と登録 Codex accounts の週次余裕を評価しなければならない（MUST）。Claude 起動 account は `usage-account-registry` capability の「active スロットの判定規則」で起動環境から解決しなければならない（MUST）。余裕（margin）は `dev-workflow-headroom` capability の行の `margin`（週の経過率 − 週次の使用率の未丸め値）を使わなければならない（MUST）: Claude は `headroom.claude_rows(now, snapshot_path)` の起動 account の行、Codex は `read_codex_usages` が認証の主体を照合した各 account の cache を `headroom.codex_row(account, cache, now)` に渡した行で、行の `status` が `ok` のときだけその `margin` を使い、それ以外は欠測とする。起動 account がオフ（`enabled: false`）のスロットなら行は `off` で、Claude の margin は欠測になる。resolver は経過率と使用率から margin を数え直してはならない（MUST NOT）。工程途中の role を切り替えてはならず、次工程で再評価しなければならない（MUST）。

構成は、最良 Codex margin（代表 Codex account の margin）と Claude margin から次の表で選ばなければならない（MUST）。表は上の行から順に当て、最初に当たった行を使う。「基準」は環境変数 `DEVELOP_ALL_CODEX_MIN_MARGIN_PCT` の値（未設定・空白だけなら既定 10）で、比較はどれも「以上」（基準ちょうど・0 ちょうどは以上の側）とする。欠測は 0 未満と同じ側に置く。

| Codex margin | Claude margin | 構成 | 理由コード |
|---|---|---|---|
| Codex オフ（`dev-workflow-develop` の要件「Codex がオフのとき自動選択は Claude だけの構成を返し、明示指定は拒否する」） | 問わない | 全役割 Claude 既定構成（`claude-default`） | `codex-off` |
| 基準以上 | 問わない | `codex-standard` | `codex-headroom-meets-threshold` |
| 0 以上・基準未満 | 0 以上 | `claude-write-codex-review` | `both-providers-have-headroom` |
| 0 以上・基準未満 | 0 未満か欠測 | `codex-standard` | `only-codex-has-headroom` |
| 0 未満か欠測 | 0 以上 | 全役割 Claude 既定構成 | `only-claude-has-headroom` |
| 0 未満か欠測 | 0 未満か欠測 | 全役割 Claude 既定構成 | `no-provider-has-headroom` |

`codex-standard` を選んだときは、全 Codex role を代表 Codex account に束縛しなければならない（MUST）。

headroom の設定（`HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY`）が不正で行を数えられないとき、または基準の設定 `DEVELOP_ALL_CODEX_MIN_MARGIN_PCT` が不正（数として読めない・有限でない・0 未満・100 超）なときは、自動選択を欠測や既定値で進めてはならず（MUST NOT）、`{"status": "blocked", "error": <設定の名前を含む文>}` を出して終了コード 2 で止まらなければならない（MUST）。基準の設定は自動選択のときだけ読み、明示 profile と旧形式では読んではならない（MUST NOT）。

**守備範囲（設定の不正で止める判定）**: ①入力の出どころは、develop を起動した利用者の環境変数 `HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY`・`DEVELOP_ALL_CODEX_MIN_MARGIN_PCT` だけである。headroom の 2 つの値の検査は headroom（`dev-workflow-headroom` の要件「設定は headroom の中で 1 か所から解決する」）が行い、resolver はその例外を `blocked` に写す。基準の値の検査は resolver が同じ範囲（0〜100）で行う。Claude の実効値と Codex の cache を欠測にする判定は要件「snapshot の鮮度と週次窓を fail-safe に検証する」の守備範囲に従う。②拾いたい誤りは、数でない・範囲の外の設定値が「余りが無い」や既定の基準に見えて、構成選択が利用者の意図と違う側へ黙って倒れることである。③通してよい入力は、未設定・空文字（既定値で数える）、0 と 100 ちょうど、小数の値である。基準 0 は「Codex が 0 以上なら常に全役割 Codex」の設定として通す。範囲内の値が利用者の意図と違っても検知しない。④この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

各工程の自動選択は dev-workflow 同梱の `usage-probe.sh` を有限 timeout で best-effort 実行してから Claude の実効値を読み取らなければならない（MUST）。probe と reader は同じ `USAGE_SNAPSHOT` を使う。probe がフェッチしなかった・失敗した・timeout した場合も、既存の記録と snapshot から求めた実効値で評価しなければならない（MUST）。

#### Scenario: Codex の余裕が基準以上なら Claude に余裕があっても全役割 Codex
- **WHEN** 基準が既定（10）で、Claude margin が +6.9、最良 Codex margin が +65.3 で profile を明示せず工程を開始する
- **THEN** `codex-standard` を選び、理由コードは `codex-headroom-meets-threshold`（`both-providers-have-headroom` ではない）で、全 Codex role を代表 account に束縛する

#### Scenario: Codex の余裕が基準以上なら Claude が詰まっていても同じ理由
- **WHEN** 基準が既定で、Claude margin が -5、最良 Codex margin が +65.3 である
- **THEN** `codex-standard` を選び、理由コードは `codex-headroom-meets-threshold`

#### Scenario: 両 provider に余裕がある
- **WHEN** 基準が既定で、Claude margin が +6.9、最良 Codex margin が +5 で profile を明示せず工程を開始する
- **THEN** `claude-write-codex-review` を選び、理由コードは `both-providers-have-headroom`。書く役と補助役は Claude、レビュー役は Codex の系統名 sol、decider は astra に解決する

#### Scenario: Claude だけが詰まっている
- **WHEN** 基準が既定で、Claude margin が -5、最良 Codex margin が +5 である
- **THEN** `codex-standard` を選び、理由コードは `only-codex-has-headroom`。全 Codex role を代表 account に束縛する

#### Scenario: Codex が詰まっている
- **WHEN** Claude margin が +6.9 で、最良 Codex margin が -1 または欠測である
- **THEN** coordinator の全役割 Claude 既定構成を選び、理由コードは `only-claude-has-headroom`

#### Scenario: 両 provider が詰まっている
- **WHEN** Claude と最良 Codex の margin がともに -5、または双方が欠測である
- **THEN** 既に coordinator が動作している全役割 Claude 既定構成を選び、理由コードは `no-provider-has-headroom`

#### Scenario: 基準を設定で変える
- **WHEN** `DEVELOP_ALL_CODEX_MIN_MARGIN_PCT` が `30` で、Claude margin が +6.9、最良 Codex margin が +20 である
- **THEN** `claude-write-codex-review` を選び、理由コードは `both-providers-have-headroom`

#### Scenario: 基準ちょうどは基準以上の側
- **WHEN** 基準が既定で、Claude margin が +6.9、最良 Codex margin がちょうど 10 である
- **THEN** `codex-standard` を選び、理由コードは `codex-headroom-meets-threshold`

#### Scenario: 基準の設定が不正なら止まる
- **WHEN** `DEVELOP_ALL_CODEX_MIN_MARGIN_PCT` が `abc`、`-1`、`101`、`nan` のいずれかで profile を明示せず工程を開始する
- **THEN** 構成を選ばず、`status: blocked` と `DEVELOP_ALL_CODEX_MIN_MARGIN_PCT` を含むエラーを出して終了コード 2 で終わる。既定の 10 で選んだ結果を返さない

#### Scenario: 明示 profile は自動選択を迂回する
- **WHEN** `--profile NAME` を明示して工程を開始する（`DEVELOP_ALL_CODEX_MIN_MARGIN_PCT` が不正な値でも同じ）
- **THEN** 構成の選択には Claude/Codex の snapshot と基準の設定を使わず、usage probe も実行せず、指定 profile の検証済み role 設定を返す。残量モードの導出には `model-tier-resolution` のとおり Claude の実効値を読む

#### Scenario: 起動 account と snapshot.active が食い違う
- **WHEN** 起動時の `CLAUDE_SECURESTORAGE_CONFIG_DIR` から導出したサービス名がスロット A に一致し、schema 2 snapshot の `active` とトップレベルのミラーがスロット B を指す
- **THEN** `usage-account-registry` の優先順位に従ってスロット A の headroom の行から Claude margin を取り、スロット B のトップレベル値へフォールバックしない

#### Scenario: 使用量 API が 429 を返し続けてもセッション記録で評価する
- **WHEN** profile を明示せず canonical phase を開始し、probe が 429 で snapshot を更新できず、起動 account の鍵のセッション記録が 1 時間前の週次 20%（リセット時刻は現在より後）である
- **THEN** Claude margin をその記録から数えた headroom の行から取り、欠測として扱わない。証跡の `fetched_at` には記録の `observed_at` を載せる

#### Scenario: margin は headroom の行から取る
- **WHEN** `headroom.claude_rows` と `headroom.codex_row` が、週の経過率と使用率からは出ない margin（Claude 12.345・Codex 6.789）を持つ `status: ok` の行を返すようにして、基準が既定のまま自動選択する
- **THEN** 証跡の Claude margin が 12.345、Codex margin が 6.789 になり、`claude-write-codex-review` を選ぶ

#### Scenario: headroom の設定が不正なら止まる
- **WHEN** `HEADROOM_7D_CAP_PCT` が `abc` で profile を明示せず工程を開始する
- **THEN** 構成を選ばず、`status: blocked` と `HEADROOM_7D_CAP_PCT` を含むエラーを出して終了コード 2 で終わる
