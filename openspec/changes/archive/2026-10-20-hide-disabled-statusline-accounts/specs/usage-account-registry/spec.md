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
  ],
  "codex": { "enabled": false }
}
```

- `schema`: 整数。省略時は `1` とみなす
- `accounts`: スロットの配列（必須）
- `codex`: Codex の設定のオブジェクト（任意）。`codex.enabled` が JSON の `false` のとき Codex は「オフ」で、意味は要件「Codex を codex.enabled でオフにできる」に従う。`accounts` のスロットとは独立で、スロットの配列には何も加えない。このキーを足しても `schema` は `1` のまま変えない
- スロットの `id`: snapshot のキーになる識別子。`^[A-Za-z0-9-]{1,32}$` に一致しなければならない（SHALL）
- スロットの `label`: statusline に表示する短いラベル。省略時は `id` を用いる。**端末上の表示幅**（East Asian Width が W / F の文字を 2 桁と数える）が 8 を超える場合は 8 桁に切り詰める（SHALL）。全角 4 文字ぶんにあたる。文字数ではなく表示幅で扱うのは、日本語のラベル（`仕事` など）でも列が揃うようにするため。切り詰めはスロットを捨てる扱いにはしない（長すぎる label は表示上の行き過ぎであって、そのアカウントの行を消すほどの問題ではない）
- スロットの `securestorage`: そのアカウントの `CLAUDE_SECURESTORAGE_CONFIG_DIR` の値。`null` または空文字は既定アカウント（`CLAUDE_SECURESTORAGE_CONFIG_DIR` 未設定の状態）を意味する
- スロットの `enabled`: 真偽値。省略時は `true` とみなす。`false` のスロットは「オフ」で、意味は要件「スロットを enabled でオフにできる」に従う。このフィールドを足しても `schema` は `1` のまま変えない（省略時の意味が従来と同じで、古い読み手は未知のキーとして読み飛ばすため）

`codex` の読み取りが扱う入力の守備範囲は、要件「Codex を codex.enabled でオフにできる」に従う。

`accounts` を読む処理は、`codex` を含む未知のトップレベルのキーを無視しなければならない（SHALL）。`accounts-init.sh` は文書を読んで書き戻すとき、`codex` を含むトップレベルのキーを消してはならない（MUST NOT）。

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

#### Scenario: codex を書いたレジストリのスロットは変わらずに読まれる
- **WHEN** `{"schema":1,"accounts":[{"id":"a","label":"A","securestorage":null}],"codex":{"enabled":false}}` を与えて読み取り処理を実行する
- **THEN** スロットは `a` の 1 つだけが得られ、`codex` はスロットとして数えられない

#### Scenario: accounts-init.sh は codex を消さない
- **WHEN** `"codex": {"enabled": false}` を持つレジストリに対して `accounts-init.sh --id a --label A2` を実行する
- **THEN** `a` の `label` は `A2` に変わり、トップレベルの `codex` は `{"enabled": false}` のまま残る

### Requirement: スロットを enabled でオフにできる
スロットの `enabled` が JSON の `false` であるとき、そのスロットは「オフ」として扱わなければならない（SHALL）。`enabled` が省略されているとき、および `true` のときは「オン」とする。`enabled` が真偽値でない（文字列の `"false"`、数値の `0`、`null` など）ときもオンとして扱わなければならず（SHALL）、そのスロットを捨ててはならない（MUST NOT）。オフにするのは利用者が明示したときだけにし、書き損じでアカウントが黙って候補から消えないようにするため。書き損じた場合もオンとして行が残る。この判定が扱う入力は、手で編集した `accounts.json`、`accounts-init.sh` の出力、`accounts.sh on|off` の出力の 3 つである。`false` 以外の書き損じを見つけて報告することはこの要件の範囲外で、新しい書き損じの形が見つかっても判定を増やさない（オフになる条件は `false` との一致 1 つのままにする）。

オフのスロットは次のように扱わなければならない（SHALL）:

- 起動時の自動選択の候補にしない（要件「古い・欠測・短期枠逼迫のスロットを候補から外す」）
- 明示選択を拒否する（要件「登録済みスロットを明示選択できる」）
- 使用量を取得しない（要件「オフのスロットは使用量を取得しない」）
- ステータスラインでは非 active の行を出さず、active ならライブ値で描く（`statusline-multi-account-usage` capability）

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

### Requirement: Codex を codex.enabled でオフにできる
レジストリのトップレベルの `codex.enabled` が JSON の `false` であるとき、Codex は「オフ」として扱わなければならない（SHALL）。`codex` が無い、オブジェクトでない、`enabled` が無い、`true`、真偽値でない値（文字列の `"false"`、数値の `0`、`null` など）のときはオンとする。レジストリが無い・読めない・トップレベルが配列のときもオンとする。オフにするのは利用者が明示したときだけにし、書き損じで Codex が黙って止まらないようにするため。オフになる条件は `false` との一致 1 つのままにし、`false` 以外の書き損じを検出して報告することはこの要件の範囲外とする。

**守備範囲（`codex` の読み取りが扱う入力）。** 入力の出どころは、手で編集した `accounts.json` と `accounts-init.sh` の出力の 2 つに限る。拾いたい誤りは「止めるつもりで書いたのに Codex が止まらない」ことではなく、「止めるつもりが無いのに Codex が黙って止まる」ことである（後者は無言でレビューや投げ先が外れ、気づきにくい）。そのため、オフになる条件は `false` との一致 1 つだけにする。通ることを許す入力（オンと読む）の例は、`"codex"` の欠落、`"codex": false`、`"enabled": "false"`、`"enabled": 0`、`"enabled": null`、壊れた JSON、トップレベルが配列のレジストリ。これらを検出して報告したり、オフと解釈したりしない。書き損じの形が新しく見つかるたびに判定を増やして防ぎ切ることは、この変更の完了条件にしない。書き損じた場合も、Codex が利用可能なら通常の行が残る。

Codex のオフは、Codex の提供元全体に対する設定であり、Codex のアカウントごとには持たない。オフの意味は次のとおり（SHALL）:

- develop の投げ先の自動選択は Codex を候補にしない（`dev-workflow-develop` capability）
- pr-review-gate の従来モードは、full でも Codex を試さない（`dev-workflow-pr-review-gate` capability）
- ステータスラインは Codex の行を出さず、使用量を取得しない（`statusline-multi-account-usage` capability）

読み取りは次の 2 つの実装が行い、どちらも同じ意味で `codex.enabled` を読まなければならない（SHALL）。`plugins/dev-workflow/scripts/usage_view.py` の `read_codex_enabled`（`codex-develop.py` と、CLI の `--codex-enabled`、すなわち pr-review-gate の G が使う）と、`plugins/statusline/scripts/statusline-codex.py`（他プラグインのスクリプトを実行時に読まないため、自分で実装する）。登録簿の場所は要件「アカウントレジストリの所在と形状」に従う。

`usage_view.py --codex-enabled` は、`on` か `off` のどちらか 1 行だけを標準出力に出し、常に exit 0 で終わらなければならない（SHALL）。

#### Scenario: false だけがオフになる
- **WHEN** `codex.enabled` が `false`、`true`、省略、文字列 `"false"`、数値 `0`、`null` の 6 つのレジストリと、`codex` がオブジェクトでないレジストリ（`"codex": false`）を順に与えて読み取り処理を実行する
- **THEN** `codex.enabled` が `false` のレジストリだけがオフと読まれ、残りの 6 つはオンと読まれる

#### Scenario: 設定が無い環境はオン
- **WHEN** レジストリのファイルが無い環境、壊れた JSON、トップレベルが裸の配列のレジストリのそれぞれで読み取り処理を実行する
- **THEN** どれもオンと読まれる

#### Scenario: CLI は on か off を 1 行出す
- **WHEN** `codex.enabled` が `false` のレジストリと、`codex` の無いレジストリのそれぞれで `usage_view.py --codex-enabled` を実行する
- **THEN** 前者は標準出力が `off` の 1 行、後者は `on` の 1 行で、どちらも exit 0 になる

#### Scenario: statusline の読み取りも同じ意味になる
- **WHEN** 上の 6 つの `codex.enabled` の値を `statusline-codex.py` に順に与える
- **THEN** `false` のときだけオフと読まれる
