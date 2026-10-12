## ADDED Requirements

### Requirement: 登録簿を一覧・追加・オン・オフするコマンド
`plugins/dev-workflow/scripts/accounts.sh` は、サブコマンド `list`、`add <id> [--label <label>]`、`off <id>`、`on <id>` を持たなければならない（SHALL）。登録簿の場所は `accounts-init.sh` と同じ規則（`CLAUDE_ACCOUNTS_FILE`、無ければ `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json`）で決める。id と label の検査は `accounts-init.sh` と同じ（id は英数字とハイフン 1〜32 文字、label は制御文字を含まない 16 文字以下、省略時は id）。

- `list` は登録簿を変えず、スロットごとに `<id>`・`<label>`・`on` または `off`・`<securestorage>`（`null` は `-`）をタブ区切りで 1 行ずつ、宣言順に stdout へ出さなければならない（SHALL）。オフの判定は要件「スロットを enabled でオフにできる」に従う
- `add <id>` は、認証情報の置き場所 `<基点>/<id>` を作り、末尾に `{"id", "label", "securestorage"}` のスロットを足さなければならない（SHALL）。`securestorage` には作ったディレクトリの絶対パスを書く。基点は環境変数 `CLAUDE_ACCOUNTS_HOME`（既定 `$HOME/.claude-accounts`）で、絶対パスでなければ exit 2。`enabled` は書かない。完了時に stdout へ、ログインするコマンドを 1 行（`CLAUDE_SECURESTORAGE_CONFIG_DIR=<絶対パス> claude`）出さなければならない（SHALL）
- `off <id>` / `on <id>` は、そのスロットの `enabled` を JSON の `false` / `true` に書き換えなければならない（SHALL）。`label`・`securestorage`・スロットの順序・未知のキーは変えてはならない（MUST NOT）。認証情報の置き場所は消してはならない（MUST NOT）
- 既にある id の `add`、登録簿に無い id の `on` / `off`、未知のサブコマンド、必須引数の欠落は、stderr に理由を出して exit 2 で終わり、登録簿を変えてはならない（MUST NOT）。`add` が exit 2 で終わるとき、認証情報の置き場所を新しく作ってはならない（MUST NOT）
- 登録簿を書き換えるサブコマンド（`add` / `on` / `off`）は、書き換える前に既存の登録簿を `<登録簿>.bak` に控えなければならない（SHALL）。登録簿が JSON として読めない、または `accounts` が配列でないときは、何も書かず、stderr に理由を出して exit 1 で終わらなければならない（SHALL）。壊れた登録簿の上に書くと、既定アカウント 1 つへの縮退（要件「レジストリ不在時は既定スロット 1 つに縮退する」）で気づきにくくなるため
- `accounts-init.sh` の挙動は変えてはならない（MUST NOT）

#### Scenario: 空の登録簿に追加する
- **WHEN** `{"schema":1,"accounts":[]}` の登録簿と `CLAUDE_ACCOUNTS_HOME=<一時ディレクトリ>` で `accounts.sh add b --label B` を実行する
- **THEN** exit 0、登録簿のスロットが 1 つ増え、その `securestorage` は `<一時ディレクトリ>/b` の絶対パスで、そのディレクトリが存在する。stdout にログインコマンドが 1 行出る

#### Scenario: 既にある id の追加を拒否する
- **WHEN** id `b` が登録済みの登録簿に `accounts.sh add b` を実行する
- **THEN** exit 2 で、登録簿の内容は変わらず、`<基点>/b` も新しく作られない

#### Scenario: オフにしてオンに戻す
- **WHEN** `enabled` の無いスロット `b` を持つ登録簿に `accounts.sh off b`、続けて `accounts.sh on b` を実行する
- **THEN** `b` の `enabled` は `false`、続けて `true` になり、どちらの時点でも `label`・`securestorage`・スロットの順序は変わらない

#### Scenario: 存在しない id のオン・オフを拒否する
- **WHEN** 登録簿に無い id `z` に `accounts.sh off z` と `accounts.sh on z` を実行する
- **THEN** どちらも exit 2 で、登録簿の内容は変わらない

#### Scenario: 一覧にオフが出る
- **WHEN** `b` が `enabled: false` の登録簿に `accounts.sh list` を実行する
- **THEN** `b` の行の 3 列目が `off`、オンのスロットの行は `on` で、登録簿は変わらない

#### Scenario: 壊れた登録簿は書き換えない
- **WHEN** JSON として読めない登録簿に `accounts.sh off b` を実行する
- **THEN** exit 1 で、登録簿の内容は 1 バイトも変わらない

#### Scenario: 書き換える前に控えを取る
- **WHEN** 既存の登録簿に `accounts.sh off b` を実行する
- **THEN** `<登録簿>.bak` が実行前の登録簿と同じ内容で存在する

#### Scenario: このコマンドでオフにしたスロットは自動選択で選ばれない
- **WHEN** 週次余裕が最大のスロット `b` を `accounts.sh off b` でオフにして `select-account.sh` を実行する
- **THEN** `b` は選ばれず、理由行の `margins` に `b:off` が出る
