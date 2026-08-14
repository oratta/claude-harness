# capability-registry-fmtoken Specification (Delta)

## ADDED Requirements

### Requirement: 明示名参照（--name）はプロジェクト導出を経由しない
`fmtoken.sh --name <item>` は、渡されたアイテム名をそのまま `op://agents/<item>/credential` の参照に使い、read-only SA 経由で読まなければならない（SHALL）。この経路では origin remote の有無を要求してはならない（MUST NOT）— エージェント名接頭辞のアイテム（例: `moko--TRELLO_TOKEN`）はプロジェクト導出（flatmate 住人は全員 `flatmate` に解決される）では引けないため。`--check --name <item>` は値を出力せず 0/44 で返すこと。未登録の場合は exit 44 で、stderr に `--register` による自己登録経路を案内する。

#### Scenario: エージェント名接頭辞のアイテムを明示名で読む
- **WHEN** agents 保管庫に `moko--TRELLO_TOKEN` が登録済みの状態で `fmtoken.sh --name moko--TRELLO_TOKEN` を実行する
- **THEN** `op://agents/moko--TRELLO_TOKEN/credential` の値が標準出力に返り exit 0 となる

#### Scenario: git リポジトリ外でも明示名参照は動く
- **WHEN** git リポジトリでないディレクトリで `fmtoken.sh --name <登録済みアイテム>` を実行する
- **THEN** exit 45 にはならず、値が返る

### Requirement: 登録（--register）は書き込み用 SA 経由で命名規約を機械検証して行う
`fmtoken.sh --register <item>` は、値を stdin から受け取り（argv で受けてはならない — transcript / ps への露出防止）、書き込み用 SA トークン（claude-agents-rw）を env `OP_SERVICE_ACCOUNT_TOKEN_RW` → `~/.config/op-sa/claude-agents-rw.token`（600 権限）→ Keychain `op-sa-claude-agents-rw` の順で解決して `op item create --vault agents`（フィールド `credential`）を実行しなければならない（SHALL）。環境の `OP_SERVICE_ACCOUNT_TOKEN`（多くのマシンで read-only トークン）を登録に流用してはならない（MUST NOT）。アイテム名は命名規約 `<prefix>--<service>`（prefix は小文字のプロジェクト名またはエージェント名、区切り `--` はちょうど 1 回）に反する場合 exit 46 で拒否し（SHALL）、既に登録済みのアイテムは上書きせず exit 47 で止まる（SHALL）。rw トークンがどこにも無い場合は exit 43 で配布依頼の案内を返す。

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
- **THEN** exit 47 となり、上書きは行われない

#### Scenario: rw トークン未配布
- **WHEN** rw SA トークンが env・ファイル・Keychain のどこにも無いマシンで `--register` を実行する
- **THEN** ro トークンが環境にあっても流用されず、exit 43 で rw トークンの配布依頼の案内が出る

## MODIFIED Requirements

### Requirement: 未登録サービスは exit 44 で自己登録経路か登録依頼を返す
要求されたサービスが agents 保管庫に未登録の場合、fmtoken.sh は exit 44 で終了し、stderr に「ブラウザに行かず、値が手元にあるなら `--register` で自分で登録し、値が無ければ主に登録を依頼する」案内を返さなければならない（SHALL）。

#### Scenario: 未登録サービスの要求
- **WHEN** agents 保管庫に `<project>--<service>` が存在しない状態で `fmtoken.sh <service>` を実行する
- **THEN** exit 44 となり、stderr に登録依頼の案内（アイテム名とフィールド名を含む）が出る

#### Scenario: 存在確認モード
- **WHEN** `fmtoken.sh --check <service>` を実行する
- **THEN** トークン値を出力せず、登録済みなら exit 0、未登録なら exit 44 で返る
