## MODIFIED Requirements

### Requirement: 登録（--register）は書き込み用 SA 経由で命名規約を機械検証して行う

`fmtoken.sh --register <item>` は、値を stdin から受け取り（argv で受けてはならない — transcript / ps への露出防止）、書き込み用 SA トークン（claude-agents-rw）を env `OP_SERVICE_ACCOUNT_TOKEN_RW` → `~/.config/op-sa/claude-agents-rw.token`（600 権限）→ Keychain `op-sa-claude-agents-rw` の順で解決して `op item create --vault agents`（フィールド `credential`）を実行しなければならない（SHALL）。受け取った値を `op` の argv に載せてはならない（MUST NOT）— JSON テンプレートを `op` の stdin に渡す形で受け渡し、argv に載せてよいのはアイテム名（秘密でない）だけとする。値を環境変数で子プロセスに渡してはならない（MUST NOT）（同一ユーザーからは argv と同程度に見えるため）。argv 経路へのフォールバックを設けてはならない（MUST NOT）— 値を渡す経路を組み立てられない場合は登録せずに非 0 で終了する。環境の `OP_SERVICE_ACCOUNT_TOKEN`（多くのマシンで read-only トークン）を登録に流用してはならない（MUST NOT）。アイテム名は命名規約 `<prefix>--<service>`（prefix は小文字のプロジェクト名またはエージェント名、区切り `--` はちょうど 1 回）に反する場合 exit 46 で拒否し（SHALL）、既に登録済みのアイテムは上書きせず exit 47 で止まる（SHALL）。rw トークンがどこにも無い場合は exit 43 で配布依頼の案内を返す。登録されるアイテムは category が API Credential・フィールド名が `credential` であり、`op://agents/<item>/credential` で参照できなければならない（SHALL）。

#### Scenario: プロジェクト名接頭辞のアイテムを登録する

- **WHEN** rw SA トークンが解決できるマシンで `printf '%s' "$VALUE" | fmtoken.sh --register newproj--newsvc` を実行する
- **THEN** rw トークンを使った `op item create` が実行され exit 0 となり、値は標準出力にも `op` の argv にも現れず、`op` の stdin に渡る JSON にのみ現れる

#### Scenario: 特殊文字を含む値が壊れずに登録される

- **WHEN** `"` `\` 改行 `$` `'` タブ を含む値を stdin から渡して `--register` を実行する
- **THEN** `op` の stdin に渡る JSON をパースした `credential` フィールドの値が、渡した値と完全一致する

#### Scenario: エージェント名接頭辞のアイテムを登録する

- **WHEN** `printf '%s' "$VALUE" | fmtoken.sh --register moko--TRELLO_TOKEN` を実行する
- **THEN** `<agent>--<SERVICE>` 形式として命名検証を通過し、登録が実行される

#### Scenario: 命名規約違反は登録前に弾かれる

- **WHEN** `--` 区切りを持たない名前や `--` を 2 回含む名前で `--register` を実行する
- **THEN** exit 46 となり、`op item create` は呼ばれない

#### Scenario: 登録済みアイテムへの二重登録

- **WHEN** agents 保管庫に既に存在するアイテム名で `--register` を実行する
- **THEN** exit 47 となり、上書きは行われない

#### Scenario: rw トークン未配布

- **WHEN** rw SA トークンが env・ファイル・Keychain のどこにも無いマシンで `--register` を実行する
- **THEN** ro トークンが環境にあっても流用されず、exit 43 で rw トークンの配布依頼の案内が出る
