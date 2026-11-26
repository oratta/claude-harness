## MODIFIED Requirements

### Requirement: 明示指定が無い工程では provider の週次余裕から構成を選ぶ
develop role resolver は、profile と旧 account/model のどちらも明示されない各 canonical phase の開始時に、Claude 起動 account と登録 Codex accounts の週次余裕を評価しなければならない（MUST）。Claude 起動 account は `usage-account-registry` capability の「active スロットの判定規則」で起動環境から解決しなければならない（MUST）。余裕（margin）は `dev-workflow-headroom` capability の行の `margin`（週の経過率 − 週次の使用率の未丸め値）を使わなければならない（MUST）: Claude は `headroom.claude_rows(now, snapshot_path)` の起動 account の行、Codex は `read_codex_usages` が認証の主体を照合した各 account の cache を `headroom.codex_row(account, cache, now)` に渡した行で、行の `status` が `ok` のときだけその `margin` を使い、それ以外は欠測とする。起動 account がオフ（`enabled: false`）のスロットなら行は `off` で、Claude の margin は欠測になる。resolver は経過率と使用率から margin を数え直してはならない（MUST NOT）。0 以上を余裕あり、負値または欠測を詰まりとして design の選択表を適用しなければならない（MUST）。工程途中の role を切り替えてはならず、次工程で再評価しなければならない（MUST）。

headroom の設定（`HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY`）が不正で行を数えられないときは、自動選択を欠測として進めてはならず（MUST NOT）、`{"status": "blocked", "error": <設定の名前を含む文>}` を出して終了コード 2 で止まらなければならない（MUST）。

**守備範囲（headroom の設定の不正で止める判定）**: ①入力の出どころは、develop を起動した利用者の環境変数 `HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY` だけで、値の検査は headroom（`dev-workflow-headroom` の要件「設定は headroom の中で 1 か所から解決する」）が行い、resolver はその例外を `blocked` に写す。Claude の実効値と Codex の cache を欠測にする判定は要件「snapshot の鮮度と週次窓を fail-safe に検証する」の守備範囲に従う。②拾いたい誤りは、数でない・0〜100 の外の設定値が「余りが無い」に見えて構成選択が黙って Claude 既定に倒れることである。③通してよい入力は、未設定・空文字（既定値で数える）、0 と 100 ちょうど、小数の値である。margin は天井とペースによらないので、値が利用者の意図と違っても範囲内なら構成選択は変わらず、検知しない。④この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

各工程の自動選択は dev-workflow 同梱の `usage-probe.sh` を有限 timeout で best-effort 実行してから Claude の実効値を読み取らなければならない（MUST）。probe と reader は同じ `USAGE_SNAPSHOT` を使う。probe がフェッチしなかった・失敗した・timeout した場合も、既存の記録と snapshot から求めた実効値で評価しなければならない（MUST）。

#### Scenario: 両 provider に余裕がある
- **WHEN** Claude margin が +20、最良 Codex margin が +10 で profile を明示せず工程を開始する
- **THEN** `claude-write-codex-review` を選び、書く役と補助役は Claude、レビュー役は Codex の系統名 sol、decider は astra に解決する

#### Scenario: Codex が詰まっている
- **WHEN** Claude margin が 0 以上で、最良 Codex margin が負値または欠測である
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
- **THEN** `usage-account-registry` の優先順位に従ってスロット A の headroom の行から Claude margin を取り、スロット B のトップレベル値へフォールバックしない

#### Scenario: 使用量 API が 429 を返し続けてもセッション記録で評価する
- **WHEN** profile を明示せず canonical phase を開始し、probe が 429 で snapshot を更新できず、起動 account の鍵のセッション記録が 1 時間前の週次 20%（リセット時刻は現在より後）である
- **THEN** Claude margin をその記録から数えた headroom の行から取り、欠測として扱わない。証跡の `fetched_at` には記録の `observed_at` を載せる

#### Scenario: margin は headroom の行から取る
- **WHEN** `headroom.claude_rows` と `headroom.codex_row` が、週の経過率と使用率からは出ない margin（Claude 12.345・Codex 6.789）を持つ `status: ok` の行を返すようにして自動選択する
- **THEN** 証跡の Claude margin が 12.345、Codex margin が 6.789 になり、`claude-write-codex-review` を選ぶ

#### Scenario: headroom の設定が不正なら止まる
- **WHEN** `HEADROOM_7D_CAP_PCT` が `abc` で profile を明示せず工程を開始する
- **THEN** 構成を選ばず、`status: blocked` と `HEADROOM_7D_CAP_PCT` を含むエラーを出して終了コード 2 で終わる

### Requirement: snapshot の鮮度と週次窓を fail-safe に検証する
Codex の自動選択は、取得からの経過時間で値を捨ててはならない（MUST NOT）。`fetched_at` が整数、週次使用率が有限の 0..100、reset が整数の snapshot について、Claude 側と同じ実効値の規則で読まなければならない（MUST）。リセット時刻を過ぎた窓は使用率 0%・リセット時刻は 1 週間単位で現在より先へ送った値とし、過ぎていなければ取得した使用率を下限としてそのまま使う。リセット時刻が現在から 7 日より先でも欠測にせず、週経過率が負になって余裕が負になるだけとする。Codex は `minutes=10080` の有効な window だけを週次比較に使い、5 時間窓や reset credit を代用してはならない（MUST NOT）。不正な値、週次窓が無い snapshot は欠測として扱わなければならない（MUST）。取得時刻の未来の扱いは Claude・Codex とも `dev-workflow-headroom` の 60 秒の規則に従わなければならない（MUST）: 今より 60 秒以内の未来は時計のずれとしてそのまま使い、60 秒を超えて未来なら欠測とする（headroom の行の `status` が `stale`）。Claude 側は取得からの経過時間で判定せず、`usage-session-records` の実効値の規則（リセット時刻を過ぎた窓は 0%、過ぎていなければ下限）に従わなければならない（MUST）。Claude の実効値の週次使用率が有限の 0..100 でない、または週次のリセット時刻が求まらないときは欠測として扱わなければならない（MUST）。これらの判定は headroom の行の `status` が担い、resolver で独自の検査を足してはならない（MUST NOT）。

**守備範囲（Claude の実効値と Codex の cache から margin を欠測にする判定）**: ①入力の出どころは 2 つである。Codex は、dev-workflow 同梱の resolver が各 CODEX_HOME の quota 取得結果から作る account ごとの cache（取得成功時の値、または取得失敗時に保持された前回値。`read_codex_usages` が認証の主体の食い違う cache を `None` にしたもの）。Claude は、`build_view` が `snapshot_path` の `.usage-snapshot` とステータスラインのセッション記録から作る起動 account の週次の実効値（`headroom.claude_rows` 経由）。どちらも、値を欠測にするかの判定は headroom の行の `status`（`dev-workflow-headroom` の要件「余りの計算を headroom.py の 1 か所に置く」の公開関数の守備範囲）が担い、resolver が担うのは `status` が `ok` でない行を欠測に写すことだけである。headroom の設定の不正は要件「明示指定が無い工程では provider の週次余裕から構成を選ぶ」の守備範囲で扱う。②拾いたい誤りは、Codex の cache の破損・手書きによる型や範囲の誤り（`fetched_at` やリセット時刻が整数でない、使用率が有限の 0..100 でない、週次窓が無い）、Claude の実効値の週次使用率が有限の 0..100 でない・週次のリセット時刻が求まらないこと、時計のずれを超える未来の取得時刻（Codex は `fetched_at`、Claude は週次の実効値の `observed_at` が今より 60 秒超）であり、これらは欠測にして余っている provider として選ばない。③通してよい入力は、取得から数分〜数日たった値でリセット時刻がまだ先のもの（下限として使う）、リセット時刻を過ぎた値（0% で読む）、リセット時刻が現在から 7 日より先の値（余裕が負になるだけ）、60 秒以内の未来の取得時刻である。取得時刻が古いことは誤りとして扱わない。値が実際の使用量より低い（取得後に使われた分を反映していない）ことは下限として許容し、検知しない。④この検査は入力の穴が見つかるたびに塞ぎ切ることを完了条件にしない。

#### Scenario: Codex の古い値はリセット前なら下限として使う
- **WHEN** Codex の週次 snapshot が 301 秒以上前（例: 1 日前）に取得され、リセット時刻が現在より後である
- **THEN** 取得した使用率を下限としてそのまま使い、欠測として扱わない

#### Scenario: Codex のリセットを過ぎた窓は 0% で読む
- **WHEN** Codex の週次 snapshot のリセット時刻が現在以前である
- **THEN** 使用率を 0%、リセット時刻を 1 週間単位で現在より先へ送った値として margin を求める

#### Scenario: Codex のリセット時刻が 7 日より先でも欠測にしない
- **WHEN** Codex の週次 snapshot のリセット時刻が現在から 7 日より先である
- **THEN** 欠測にせず、週経過率が負になる margin を求める。余裕が負なので Codex は選ばれない

#### Scenario: 60 秒を超えて未来の取得時刻は欠測にする
- **WHEN** Codex snapshot の `fetched_at` が現在より 61 秒後である
- **THEN** 欠測として扱う。現在より 60 秒後の `fetched_at` は欠測にせず margin を求める

#### Scenario: Claude の週次の実効値の取得時刻が 60 秒を超えて未来なら欠測にする
- **WHEN** 起動 account の週次の実効値の `observed_at` が現在より 61 秒後である
- **THEN** Claude margin を欠測とする。60 秒後なら欠測にせず margin を求める

#### Scenario: Claude の古い値はリセット前なら使う
- **WHEN** Claude の起動 account の値が 1 日前に取得され、週次のリセット時刻が現在より後である
- **THEN** その値から Claude margin を求め、欠測として扱わない

#### Scenario: 週次ではない Codex window を除外する
- **WHEN** Codex snapshot に fresh な 5 時間 window だけがある
- **THEN** Codex provider を欠測とし、その使用率を週次 margin に使わない
