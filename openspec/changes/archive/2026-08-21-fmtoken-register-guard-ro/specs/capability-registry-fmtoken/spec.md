## MODIFIED Requirements

### Requirement: 登録（--register）は書き込み用 SA 経由で命名規約を機械検証して行う

`fmtoken.sh --register <item>` は、値を stdin から受け取り（argv で受けてはならない — transcript / ps への露出防止）、書き込み用 SA トークン（claude-agents-rw）を env `OP_SERVICE_ACCOUNT_TOKEN_RW` → `~/.config/op-sa/claude-agents-rw.token`（600 権限）→ Keychain `op-sa-claude-agents-rw` の順で解決して `op item create --vault agents`（フィールド `credential`）を実行しなければならない（SHALL）。環境の `OP_SERVICE_ACCOUNT_TOKEN`（多くのマシンで read-only トークン）を登録に流用してはならない（MUST NOT）。アイテム名は命名規約 `<prefix>--<service>`（prefix は小文字のプロジェクト名またはエージェント名、区切り `--` はちょうど 1 回）に反する場合 exit 46 で拒否し（SHALL）、既に登録済みのアイテムは上書きせず exit 47 で止まる（SHALL）。二重登録の判定は読み取り用 SA（claude-agents-ro。解決順は読み取り経路と同じ env → 600 ファイル → Keychain）による `op item list --vault agents` の title 完全一致で行わなければならず（SHALL）、rw SA の read 権に依存させてはならない（MUST NOT — read 権が無い構成では判定が「未登録」側に倒れ、1Password は同名アイテムの作成を許すため重複ができる）。判定を `credential` フィールドの有無に依存させてもならない（MUST NOT — フィールド欠落アイテムを「未登録」と誤判定して同名重複を作らないため）。読み取り用 SA が解決できない、または `op item list` が失敗して判定が不能な場合は、`op item create` を実行せず exit 48 で終了し（SHALL — fail-closed）、stderr に「ro トークンをこのマシンに配布する」か「rw SA に agents 保管庫の read 権を付ける」かの選択肢を案内する。rw トークンがどこにも無い場合は exit 43 で配布依頼の案内を返す。

#### Scenario: プロジェクト名接頭辞のアイテムを登録する

- **WHEN** rw SA トークンが解決できるマシンで `printf '%s' "$VALUE" | fmtoken.sh --register newproj--newsvc` を実行する
- **THEN** rw トークンを使った `op item create` が実行され exit 0 となり、値は標準出力に現れない

#### Scenario: エージェント名接頭辞のアイテムを登録する

- **WHEN** `printf '%s' "$VALUE" | fmtoken.sh --register moko--TRELLO_TOKEN` を実行する
- **THEN** `<agent>--<SERVICE>` 形式として命名検証を通過し、登録が実行される

#### Scenario: 命名規約違反は登録前に弾かれる

- **WHEN** `--` 区切りを持たない名前や `--` を 2 回含む名前で `--register` を実行する
- **THEN** exit 46 となり、`op item create` は呼ばれない

#### Scenario: 登録済みアイテムへの二重登録

- **WHEN** agents 保管庫に既に存在するアイテム名で `--register` を実行する
- **THEN** 読み取り用 SA による title 完全一致の判定が登録済みを検出し、exit 47 となって上書きは行われない

#### Scenario: rw SA に read 権が無くても二重登録は止まる

- **WHEN** rw トークンでの `op read` が全て失敗する（rw SA に read 権が無い）構成で、既に存在するアイテム名に `--register` を実行する
- **THEN** 判定は読み取り用 SA で行われるため exit 47 となり、`op item create` は呼ばれない

#### Scenario: 二重登録の判定が不能なら登録しない（fail-closed）

- **WHEN** 読み取り用 SA トークンが env・ファイル・Keychain のどこからも解決できない状態で `--register` を実行する
- **THEN** exit 48 となり、`op item create` は呼ばれず、stderr に ro トークンの配布または rw SA への read 権付与の選択肢が出る

#### Scenario: rw トークン未配布

- **WHEN** rw SA トークンが env・ファイル・Keychain のどこにも無いマシンで `--register` を実行する
- **THEN** ro トークンが環境にあっても流用されず、exit 43 で rw トークンの配布依頼の案内が出る
