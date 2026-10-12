## ADDED Requirements

### Requirement: スロットを enabled でオフにできる
スロットの `enabled` が JSON の `false` であるとき、そのスロットは「オフ」として扱わなければならない（SHALL）。`enabled` が省略されているとき、および `true` のときは「オン」とする。`enabled` が真偽値でない（文字列の `"false"`、数値の `0`、`null` など）ときもオンとして扱わなければならず（SHALL）、そのスロットを捨ててはならない（MUST NOT）。オフにするのは利用者が明示したときだけにし、書き損じでアカウントが黙って候補から消えないようにするため。書き損じた場合はステータスラインに `off` が出ないことで気づける。

オフのスロットは次のように扱わなければならない（SHALL）:

- 起動時の自動選択の候補にしない（要件「古い・欠測・短期枠逼迫のスロットを候補から外す」）
- 明示選択を拒否する（要件「登録済みスロットを明示選択できる」）
- 使用量を取得しない（要件「オフのスロットは使用量を取得しない」）
- ステータスラインでは行を残して `off` と表示する（`statusline-multi-account-usage` capability）

オフのスロットもレジストリのスロットであり続ける。宣言順、先頭 8 個までの上限、`id` の一意性、不正なスロットの除外、active スロットの判定は、オンのスロットと同じ規則で数えなければならない（SHALL）。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を手で設定してオフのスロットのアカウントで起動したセッションでは、そのスロットが active になる。`enabled` はアカウントの認証情報にも、セッション記録・snapshot に残っている値にも触れない。オンに戻せば、残っている値からそのまま再開する。

レジストリを読む 5 か所（`usage_view.py`、`select-account.sh`、`usage-probe.sh`、`statusline.sh`、`accounts-init.sh`）は、この同じ意味で `enabled` を読まなければならない（SHALL）。

#### Scenario: false だけがオフになる
- **WHEN** `enabled` が `false`、`true`、省略、文字列 `"false"`、数値 `0`、`null` の 6 スロットを与えて読み取り処理を実行する
- **THEN** `false` のスロットだけがオフとして読まれ、残りの 5 つはオンとして読まれる。6 つとも捨てられない

#### Scenario: オフのスロットも上限と順序に数える
- **WHEN** 先頭がオフのスロットである 9 スロットのレジストリを与えて読み取り処理を実行する
- **THEN** 先頭 8 スロットが宣言順に得られ、オフのスロットはその 1 番目に含まれる

#### Scenario: オフのスロットも active になりうる
- **WHEN** `enabled: false` のスロットの `securestorage` と `CLAUDE_SECURESTORAGE_CONFIG_DIR` が同一の文字列である状態で active を判定する
- **THEN** そのオフのスロットが active になる

### Requirement: オフのスロットは使用量を取得しない
`plugins/dev-workflow/scripts/usage-probe.sh` は、オフのスロットについて使用量を取得してはならない（MUST NOT）。認証情報の読み出し（Keychain と平文の credentials ファイル）も使用量 API の呼び出しも行わず、試行状態（`${USAGE_PROBE_STATE}`）にそのスロットの試行を記録しない。セッション記録や snapshot の値がどれだけ古くても、オフのスロットは叩く対象に入れない。

snapshot を書くとき、オフのスロットの項目は前回の値（`fetched_at` 込み）をそのまま引き継がなければならない（SHALL）。項目を消してはならない（MUST NOT）。オンに戻したときに、ステータスラインと自動選択が残っている値から再開できるようにするため。active スロットの判定と `--print-slots` の出力（`id` / `label` / `securestorage` / サービス名の 4 列）は `enabled` で変えない。

#### Scenario: オフのスロットの認証情報を読まず API も呼ばない
- **WHEN** 2 スロットのうち `b` が `enabled: false` で、両スロットとも値が古く叩く条件を満たす状態で、本番経路の probe を実行する
- **THEN** `b` のサービス名での Keychain の読み出しと `b` のための API 呼び出しは 1 回も起きず、`a` だけが取得される

#### Scenario: オフのスロットの前回値を引き継ぐ
- **WHEN** snapshot に `b` の前回値があり、`b` が `enabled: false` の状態で probe が `a` の新しい値を取得して snapshot を書く
- **THEN** snapshot の `accounts.b` は `fetched_at` を含めて前回値のまま残る

#### Scenario: 全スロットがオフなら何も取得しない
- **WHEN** 全スロットが `enabled: false` の状態で probe を実行する
- **THEN** 認証情報の読み出しも API 呼び出しも起きず、snapshot も試行状態も書き換えられず、exit 0 で終わる

### Requirement: 生成手段は既存スロットの enabled を保つ
`plugins/dev-workflow/scripts/accounts-init.sh` は、既にある `id` のスロットを上書きするとき、そのスロットに書かれていた `enabled` を同じ値のまま残さなければならない（SHALL）。ラベルや `securestorage` を登録し直しただけで、オフにしていたアカウントが黙ってオンに戻らないようにするため。新しい `id` を追加するとき、および上書き前のスロットに `enabled` が無いときは、`enabled` を書き足してはならない（MUST NOT）。

#### Scenario: オフのスロットを登録し直してもオフのまま
- **WHEN** `enabled: false` の `b` があるレジストリに対して `accounts-init.sh --id b --label B2` を実行する
- **THEN** `b` の `label` は `B2` に変わり、`enabled` は `false` のまま残る

#### Scenario: enabled の無いスロットには書き足さない
- **WHEN** `enabled` の無い `a` があるレジストリに対して `accounts-init.sh --id a --label A2` を実行し、続けて新しい id `c` を追加する
- **THEN** `a` と `c` のどちらにも `enabled` は書かれない

## MODIFIED Requirements

### Requirement: アカウントレジストリの所在と形状
使用量観測の対象となる Claude アカウントは、レジストリファイル `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json`（環境変数 `CLAUDE_ACCOUNTS_FILE` で上書き可能）に定義されなければならない（SHALL）。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を使う運用の前提が「`CLAUDE_CONFIG_DIR` は共有する」ことであるため、レジストリは `CLAUDE_CONFIG_DIR` 配下に置く。

レジストリのトップレベルは**オブジェクト**でなければならず（SHALL）、次の形状に固定する。トップレベルが裸の配列であってはならない（MUST NOT）:

```json
{
  "schema": 1,
  "accounts": [
    { "id": "a", "label": "A", "securestorage": null },
    { "id": "b", "label": "B", "securestorage": "/Users/example/.claude-b" }
  ]
}
```

- `schema`: 整数。省略時は `1` とみなす
- `accounts`: スロットの配列（必須）
- スロットの `id`: snapshot のキーになる識別子。`^[A-Za-z0-9-]{1,32}$` に一致しなければならない（SHALL）
- スロットの `label`: statusline に表示する短いラベル。省略時は `id` を用いる。**端末上の表示幅**（East Asian Width が W / F の文字を 2 桁と数える）が 8 を超える場合は 8 桁に切り詰める（SHALL）。全角 4 文字ぶんにあたる。文字数ではなく表示幅で扱うのは、日本語のラベル（`仕事` など）でも列が揃うようにするため。切り詰めはスロットを捨てる扱いにはしない（長すぎる label は表示上の行き過ぎであって、そのアカウントの行を消すほどの問題ではない）
- スロットの `securestorage`: そのアカウントの `CLAUDE_SECURESTORAGE_CONFIG_DIR` の値。`null` または空文字は既定アカウント（`CLAUDE_SECURESTORAGE_CONFIG_DIR` 未設定の状態）を意味する
- スロットの `enabled`: 真偽値。省略時は `true` とみなす。`false` のスロットは「オフ」で、意味は要件「スロットを enabled でオフにできる」に従う。このフィールドを足しても `schema` は `1` のまま変えない（省略時の意味が従来と同じで、古い読み手は未知のキーとして読み飛ばすため）

スロットの順序は宣言順を保たなければならない（SHALL）。リポジトリはレジストリの雛形または生成手段（コマンドか README の手順）を提供しなければならない（SHALL）。実ファイル自体はリポジトリに含めない。

#### Scenario: 複数スロットを読む
- **WHEN** `{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null},{"id":"b","label":"B","securestorage":"/tmp/cb"}]}` を与えて読み取り処理を実行する
- **THEN** 宣言順に 2 つのスロットが得られ、それぞれ `id` / `label` / `securestorage` を保つ

#### Scenario: 環境変数でレジストリの場所を上書きする
- **WHEN** `CLAUDE_ACCOUNTS_FILE` に別のパスを設定して読み取り処理を実行する
- **THEN** `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json` ではなく、指定されたパスのレジストリが読まれる

#### Scenario: CLAUDE_CONFIG_DIR に追随する
- **WHEN** `CLAUDE_CONFIG_DIR` を一時ディレクトリに設定し、`CLAUDE_ACCOUNTS_FILE` を設定せずに読み取り処理を実行する
- **THEN** レジストリは `$CLAUDE_CONFIG_DIR/accounts.json` から読まれ、`$HOME/.claude/accounts.json` は読まれない

#### Scenario: トップレベルが配列なら不正として扱う
- **WHEN** トップレベルが裸の配列 `[{"id":"a"}]` のレジストリを与えて読み取り処理を実行する
- **THEN** 不正なレジストリとして扱われ、既定アカウントを指すスロットが 1 つだけ得られる

#### Scenario: enabled を書いたスロットを読む
- **WHEN** `{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null},{"id":"b","label":"B","securestorage":"/tmp/cb","enabled":false}]}` を与えて読み取り処理を実行する
- **THEN** 宣言順に 2 つのスロットが得られ、`a` はオン、`b` はオフとして読まれる

### Requirement: 古い・欠測・短期枠逼迫のスロットを候補から外す
自動選択は、取得からの経過時間でスロットを候補から外してはならない（MUST NOT）。古さの扱いは実効値の規則（リセット時刻を過ぎた窓は 0%、過ぎていなければ下限として使う）に従う。実効値の `weekly_all_pct`、`weekly_resets_epoch`、`five_hour_pct` のいずれかが欠測であるスロット、および実効値の `five_hour_pct >= 90` のスロットを候補から外さなければならない（SHALL）。欠測かどうかの判定は `usage-session-records` の「記録と snapshot から実効値を求める」の規則と守備範囲に従い、この要件で独自の検査を足さない。理由行では欠測を `missing`、5 時間枠による除外を `five-hour>=90` と書く。オフのスロット（要件「スロットを enabled でオフにできる」）は、実効値にかかわらず候補から外さなければならず（SHALL）、理由行では `off` と書く。オフのスロットは実効値を調べる前に外し、`missing` にも `five-hour>=90` にも数えない。候補が 1 つも無い場合は既定アカウントを表す空の `securestorage` を選ばなければならない（SHALL）。このとき、レジストリに既定スロット（`securestorage` が `null` または空文字）があれば宣言順で最初のスロットの id を `selected` に出し、無ければ登録 id では使用できない `@unregistered-default` を出さなければならない（SHALL）。このときの `selected` の決め方は `enabled` を見ない（縮退先は常に既定アカウントであり、`selected` はその起動先を指すスロットを報告するため）。理由は、オンのスロットが 1 つも無ければ `default-due-to-all-off`、オンのスロットに `missing` による除外が 1 つでもあれば `default-due-to-missing-usage`、オンのスロットがすべて `five-hour>=90` だけで除外された場合は `default-due-to-five-hour-limit` としなければならない（SHALL）。

#### Scenario: 古いがリセット前の値で選ぶ
- **WHEN** 片方のスロットの値が 1 日前に取得され、リセット時刻がまだ来ておらず、もう片方より週次余裕が大きい
- **THEN** selector は古い方のスロットを候補に含め、週次余裕が大きい方として選ぶ

#### Scenario: リセット時刻を過ぎた値は 0% として比べる
- **WHEN** スロット `a` の値が週次 95%・リセット時刻が現在より前で、スロット `b` の値が週次 30%・リセット時刻が現在より後である
- **THEN** selector は `a` の週次を 0% として週次余裕を求め、`a` を候補に含める

#### Scenario: 全スロットが欠測のときは登録済み既定スロットへ縮退する
- **WHEN** id が `a` の既定スロットを含む全スロットで、セッション記録も snapshot の値も無い
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=a reason=default-due-to-missing-usage` と各スロットの `missing` を含める
- **AND** その値で起動したセッションでは環境変数が unset され、statusline の active も `a` になる

#### Scenario: 既定スロットが未登録なら sentinel を表示する
- **WHEN** 全スロットが明示的な非空の `securestorage` を持ち、かつ全スロットが欠測である
- **THEN** selector は空の `securestorage` を出力し、理由行に `selected=@unregistered-default reason=default-due-to-missing-usage` を含める
- **AND** `@unregistered-default` は実在する登録 id として扱われない

#### Scenario: 5 時間枠が 90 パーセントなら候補から外す
- **WHEN** 週次余裕が最大のスロットの実効値の `five_hour_pct` が 90 で、別のスロットが 90 未満である
- **THEN** selector は週次余裕が最大のスロットを候補から外し、別のスロットを選ぶ

#### Scenario: 全スロットの 5 時間枠が逼迫したときは原因を区別する
- **WHEN** 全スロットの実効値は欠測が無いが、`five_hour_pct` がすべて 90 以上である
- **THEN** selector は空の `securestorage` を出力し、理由行に `reason=default-due-to-five-hour-limit` と各スロットの `five-hour>=90` を含める
- **AND** 理由行に `reason=default-due-to-missing-usage` を含めない

#### Scenario: 選択に必要な値が欠測している
- **WHEN** スロットの実効値のうち選択に必要な 3 項目のいずれかが欠測である
- **THEN** selector はそのスロットを候補から外し、理由行に `missing` を含める

#### Scenario: 使用量 API が 429 を返し続けても記録で選ぶ
- **WHEN** usage-probe が全スロットで 429 を受けて snapshot を更新できず、A と B のセッション記録がある
- **THEN** selector は記録から求めた実効値で選び、理由行に `missing` を含めない

#### Scenario: オフのスロットは週次余裕が最大でも選ばない
- **WHEN** スロット `a` がオンで週次余裕が 10、スロット `b` が `enabled: false` で実効値から求めた週次余裕が 90 である
- **THEN** selector は `a` の `securestorage` を出力し、理由行は `selected=a reason=max-weekly-margin` と `margins=a:10.00,b:off` を含む

#### Scenario: enabled を書いていない登録簿では選択が変わらない
- **WHEN** どのスロットにも `enabled` が無い登録簿と、この変更の前と同じセッション記録・snapshot を与える
- **THEN** stdout と理由行はこの変更の前と同じになる

#### Scenario: 全スロットがオフなら既定アカウントへ縮退する
- **WHEN** id が `a` の既定スロットを含む全スロットが `enabled: false` である
- **THEN** selector は空の `securestorage` を出力して exit 0 で終わり、理由行は `selected=a reason=default-due-to-all-off` と各スロットの `off` を含む

#### Scenario: オンのスロットが欠測でオフのスロットに値があるとき
- **WHEN** 既定スロット `a` がオンで欠測、スロット `b` が `enabled: false` で実効値が揃っている
- **THEN** selector は `b` を選ばず、空の `securestorage` を出力し、理由行は `selected=a reason=default-due-to-missing-usage` と `margins=a:missing,b:off` を含む

### Requirement: 登録済みスロットを明示選択できる
`select-account.sh <slot-id>` は usage snapshot を読まず、レジストリに登録されたオンのスロットの id の `securestorage` を返さなければならない（SHALL）。id が未登録、または引数が 2 個以上なら stdout に値を出さず exit 2 で終了しなければならない（SHALL）。id がオフのスロット（要件「スロットを enabled でオフにできる」）を指す場合も stdout に値を出さず exit 2 で終了し、stderr の 1 行に、その id・オフであること・戻し方（読んだレジストリファイルのパスと、そのスロットの `enabled` を `true` にするか消すこと）を含めなければならない（SHALL）。未登録の診断と同じ文面にしてはならない（MUST NOT）。登録はあるのに使えない理由と直し方が、未登録の場合と違うため。

#### Scenario: 登録済み id を snapshot 無しで選ぶ
- **WHEN** 登録済み id を 1 個渡し、usage snapshot が存在しない
- **THEN** selector はそのスロットの `securestorage` を返し、exit 0 になる

#### Scenario: 未登録 id を拒否する
- **WHEN** レジストリに無い id を渡す
- **THEN** selector は stdout に値を出さず、stderr に診断を出して exit 2 になる

#### Scenario: オフのスロットの明示選択を拒否する
- **WHEN** `enabled: false` のスロットの id を 1 個渡す
- **THEN** selector は stdout に値を出さず exit 2 になり、stderr はその id、`enabled`、レジストリファイルのパスを含む 1 行である

### Requirement: 値と選択理由を別の出力ストリームで返す
成功時の selector は stdout に選んだ `securestorage` の実値だけを改行付きで出さなければならない（SHALL）。既定アカウントの stdout は空行とする。stderr には `selected=<id-or-sentinel> reason=<reason> margins=<entries>` の 1 行だけを出さなければならない（SHALL）。`selected` は選んだ登録スロットの実 id とし、登録されていない既定アカウントへの縮退だけは `@unregistered-default` とする。自動選択の `margins` は全登録スロットを宣言順に含み、候補は週次余裕を小数点以下 2 桁、候補外は `stale`、`missing`、`five-hour>=90`、`off` のいずれかで示さなければならない（SHALL）。オフのスロットも `margins` から省いてはならない（MUST NOT）。省くと、登録したはずのスロットが選ばれない理由を理由行から読めなくなる。

#### Scenario: shell は stdout だけを値として取り込める
- **WHEN** 自動選択の stdout を command substitution で取得し、stderr を端末へ残す
- **THEN** 変数には `securestorage` の実値だけが入り、選択 id・理由・全スロットの比較は stderr の 1 行で確認できる

#### Scenario: 明示選択の理由を示す
- **WHEN** 登録済み id を明示して選ぶ
- **THEN** stderr は `reason=explicit` と `margins=-` を含む

#### Scenario: オフのスロットも margins に並ぶ
- **WHEN** 2 番目のスロットが `enabled: false` の登録簿で自動選択する
- **THEN** stderr の `margins` は宣言順に 2 スロットを含み、2 番目は `<id>:off` である
