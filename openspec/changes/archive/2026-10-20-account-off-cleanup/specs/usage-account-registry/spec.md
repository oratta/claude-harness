## MODIFIED Requirements
### Requirement: 登録済みスロットを明示選択できる
`select-account.sh <slot-id>` は usage snapshot を読まず、レジストリに登録されたオンのスロットの id の `securestorage` を返さなければならない（SHALL）。id が未登録、または引数が 2 個以上なら stdout に値を出さず exit 2 で終了しなければならない（SHALL）。id がオフのスロット（要件「スロットを enabled でオフにできる」）を指す場合も stdout に値を出さず exit 2 で終了し、stderr の 1 行に、その id・オフであること・戻し方（読んだレジストリファイルのパスと、`accounts.sh on <id>` を実行すること）を含めなければならない（SHALL）。未登録の診断と同じ文面にしてはならない（MUST NOT）。登録はあるのに使えない理由と直し方が、未登録の場合と違うため。

#### Scenario: 登録済み id を snapshot 無しで選ぶ
- **WHEN** 登録済み id を 1 個渡し、usage snapshot が存在しない
- **THEN** selector はそのスロットの `securestorage` を返し、exit 0 になる

#### Scenario: 未登録 id を拒否する
- **WHEN** レジストリに無い id を渡す
- **THEN** selector は stdout に値を出さず、stderr に診断を出して exit 2 になる

#### Scenario: オフのスロットの明示選択を拒否する
- **WHEN** `enabled: false` のスロットの id を 1 個渡す
- **THEN** selector は stdout に値を出さず exit 2 になり、stderr はその id、`enabled`、レジストリファイルのパス、`accounts.sh on <id>` を含む 1 行である


### Requirement: スロットを enabled でオフにできる
スロットの `enabled` が JSON の `false` であるとき、そのスロットは「オフ」として扱わなければならない（SHALL）。`enabled` が省略されているとき、および `true` のときは「オン」とする。`enabled` が真偽値でない（文字列の `"false"`、数値の `0`、`null` など）ときもオンとして扱わなければならず（SHALL）、そのスロットを捨ててはならない（MUST NOT）。オフにするのは利用者が明示したときだけにし、書き損じでアカウントが黙って候補から消えないようにするため。書き損じた場合はステータスラインに `off` が出ないことで気づける。この判定が扱う入力は、手で編集した `accounts.json`、`accounts-init.sh` の出力、`accounts.sh on|off` の出力の 3 つである。`false` 以外の書き損じを見つけて報告することはこの要件の範囲外で、新しい書き損じの形が見つかっても判定を増やさない（オフになる条件は `false` との一致 1 つのままにする）。

オフのスロットは次のように扱わなければならない（SHALL）:

- 起動時の自動選択の候補にしない（要件「古い・欠測・短期枠逼迫のスロットを候補から外す」）
- 明示選択を拒否する（要件「登録済みスロットを明示選択できる」）
- 使用量を取得しない（要件「オフのスロットは使用量を取得しない」）
- ステータスラインでは行を残して `off` と表示する（`statusline-multi-account-usage` capability）

オフのスロットもレジストリのスロットであり続ける。宣言順、先頭 8 個までの上限、`id` の一意性、不正なスロットの除外、active スロットの判定は、オンのスロットと同じ規則で数えなければならない（SHALL）。`CLAUDE_SECURESTORAGE_CONFIG_DIR` を手で設定してオフのスロットのアカウントで起動したセッションでは、そのスロットが active になる。`enabled` はアカウントの認証情報にも、セッション記録・snapshot に残っている値にも触れない。オンに戻せば、残っている値からそのまま再開する。

レジストリを読む 6 か所（`usage_view.py`、`select-account.sh`、`usage-probe.sh`、`statusline.sh`、`accounts-init.sh`、`accounts.sh list`）は、この同じ意味で `enabled` を読まなければならない（SHALL）。

#### Scenario: false だけがオフになる
- **WHEN** `enabled` が `false`、`true`、省略、文字列 `"false"`、数値 `0`、`null` の 6 スロットを与えて読み取り処理を実行する
- **THEN** `false` のスロットだけがオフとして読まれ、残りの 5 つはオンとして読まれる。6 つとも捨てられない

#### Scenario: オフのスロットも上限と順序に数える
- **WHEN** 先頭がオフのスロットである 9 スロットのレジストリを与えて読み取り処理を実行する
- **THEN** 先頭 8 スロットが宣言順に得られ、オフのスロットはその 1 番目に含まれる

#### Scenario: オフのスロットも active になりうる
- **WHEN** `enabled: false` のスロットの `securestorage` と `CLAUDE_SECURESTORAGE_CONFIG_DIR` が同一の文字列である状態で active を判定する
- **THEN** そのオフのスロットが active になる
