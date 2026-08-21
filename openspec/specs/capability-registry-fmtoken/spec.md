# capability-registry-fmtoken Specification

## Purpose
1Password agents 保管庫のトークン取得・登録ラッパー fmtoken.sh。読み取りは read-only SA 経由（プロジェクトスコープ導出、または `--name` による明示名参照）、登録は書き込み用 SA（claude-agents-rw）経由の `--register` で命名規約を機械検証して行う。未配布・値が無い時だけ人間への依頼文を返す。
## Requirements
### Requirement: fmtoken.sh がプラグイン内から動作する
プラグインは `scripts/fmtoken.sh` を同梱し、以下の振る舞いを提供しなければならない（SHALL）: プロジェクト名を `git remote get-url origin` のリポジトリ名（URL 末尾の `.git` を除いた最終パス要素を小文字化したもの）から機械導出し、1Password の agents 保管庫のアイテム `<project>--<service>`（フィールド `credential`）を read-only Service Account 経由で読む。導出はディレクトリ名に依存しないため、メイン repo・worktree・flatmate 住人の作業リポ（`workspace/<住人>/repo`）のすべてで同じプロジェクト名に解決される。スキルや hook からは `${CLAUDE_PLUGIN_ROOT}/scripts/fmtoken.sh` で参照できること。

#### Scenario: トークンの取得
- **WHEN** origin remote を持つ登録済みプロジェクトで `fmtoken.sh <service>` を実行する
- **THEN** `op://agents/<project>--<service>/credential` の値が標準出力に返り exit 0 となる

#### Scenario: flatmate 住人の作業リポからの導出
- **WHEN** git root のディレクトリ名が `repo`（`workspace/<住人>/repo` 構造）で、origin が `https://github.com/genetta-inc/suimei.git` を指すリポで `fmtoken.sh` を実行する
- **THEN** プロジェクト名は `suimei` に解決され、ディレクトリ名 `repo` は参照されない

#### Scenario: SSH 形式の remote URL
- **WHEN** origin が `git@github.com:oratta/traore.git`（SSH scp 形式）のリポで `fmtoken.sh` を実行する
- **THEN** プロジェクト名は HTTPS 形式と同じ `traore` に解決される

#### Scenario: worktree 配下からの導出
- **WHEN** メイン repo から作成した worktree のディレクトリ内で `fmtoken.sh` を実行する
- **THEN** メイン repo で実行した場合と同じプロジェクト名に解決される

### Requirement: SA トークンは env → 600 ファイル → Keychain の順で解決する（無人経路優先）
fmtoken.sh は `OP_SERVICE_ACCOUNT_TOKEN` 環境変数 → `~/.config/op-sa/claude-agents-ro.token`（600 権限ファイル）→ macOS Keychain `op-sa-claude-agents-ro` の順で SA トークンを解決しなければならない（SHALL）。Keychain は ACL 次第で読み出しごとに生体認証ダイアログを出し、無人文脈（cron・常駐・SSH）ではそこでブロックするため、対話マシン用の最終フォールバックに置く。ファイルが配布済みのマシンでは Keychain に一切触れないこと。どこにも無い場合は exit 43 で「主に SA トークンの配布を依頼する」案内を stderr に返し、ブラウザでのログイン代行に誘導しない。

#### Scenario: 600 ファイルが Keychain より優先される
- **WHEN** Keychain にも 600 ファイルにも SA トークンがあるマシンで `fmtoken.sh <service>` を実行する
- **THEN** ファイルのトークンが使われ、Keychain（`security find-generic-password`）は呼ばれない

#### Scenario: 未セットアップマシン
- **WHEN** SA トークンが env にも Keychain にもファイルにも無いマシンで `fmtoken.sh <service>` を実行する
- **THEN** exit 43 となり、stderr に「主に『SA トークンをこのマシンに配布して』と依頼すること」の案内が出る

### Requirement: 未登録サービスは exit 44 で自己登録経路か登録依頼を返す
要求されたサービスが agents 保管庫に未登録の場合、fmtoken.sh は exit 44 で終了し、stderr に「ブラウザに行かず、値が手元にあるなら `--register` で自分で登録し、値が無ければ主に登録を依頼する」案内を返さなければならない（SHALL）。

#### Scenario: 未登録サービスの要求
- **WHEN** agents 保管庫に `<project>--<service>` が存在しない状態で `fmtoken.sh <service>` を実行する
- **THEN** exit 44 となり、stderr に登録依頼の案内（アイテム名とフィールド名を含む）が出る

#### Scenario: 存在確認モード
- **WHEN** `fmtoken.sh --check <service>` を実行する
- **THEN** トークン値を出力せず、登録済みなら exit 0、未登録なら exit 44 で返る

### Requirement: remote 導出不能時は専用エラーで停止する
`git remote get-url origin` が失敗する場合（git リポジトリでない・origin remote が未設定）、fmtoken.sh は誤ったアイテム参照を組み立てず exit 45 で終了しなければならない（SHALL）。stderr には origin remote が無いためプロジェクトを特定できない旨を出力し、未登録時（exit 44）の登録依頼メッセージには誘導しないこと（導出不能と未登録の混同が、存在するトークンへの登録依頼という誤誘導を生むため）。

#### Scenario: origin remote が無いリポでの実行
- **WHEN** remote 未設定の git リポジトリで `fmtoken.sh <service>` を実行する
- **THEN** exit 45 となり、stderr に origin remote が無くプロジェクトを特定できない旨が出て、登録依頼の案内は出ない

#### Scenario: git リポジトリ外での実行
- **WHEN** git リポジトリでないディレクトリで `fmtoken.sh <service>` を実行する
- **THEN** exit 45 となる（旧実装の cwd フォールバックで誤った参照を組み立てない）

### Requirement: 明示名参照（--name）はプロジェクト導出を経由しない
`fmtoken.sh --name <item>` は、渡されたアイテム名をそのまま `op://agents/<item>/credential` の参照に使い、read-only SA 経由で読まなければならない（SHALL）。この経路では origin remote の有無を要求してはならない（MUST NOT）— エージェント名接頭辞のアイテム（例: `moko--TRELLO_TOKEN`）はプロジェクト導出（flatmate 住人は全員 `flatmate` に解決される）では引けないため。`--check --name <item>` は値を出力せず 0/44 で返すこと。未登録の場合は exit 44 で、stderr に `--register` による自己登録経路を案内する。

#### Scenario: エージェント名接頭辞のアイテムを明示名で読む
- **WHEN** agents 保管庫に `moko--TRELLO_TOKEN` が登録済みの状態で `fmtoken.sh --name moko--TRELLO_TOKEN` を実行する
- **THEN** `op://agents/moko--TRELLO_TOKEN/credential` の値が標準出力に返り exit 0 となる

#### Scenario: git リポジトリ外でも明示名参照は動く
- **WHEN** git リポジトリでないディレクトリで `fmtoken.sh --name <登録済みアイテム>` を実行する
- **THEN** exit 45 にはならず、値が返る

### Requirement: 登録（--register）は書き込み用 SA 経由で命名規約を機械検証して行う

`fmtoken.sh --register <item>` は、値を stdin から受け取り（argv で受けてはならない — transcript / ps への露出防止）、書き込み用 SA トークン（claude-agents-rw）を env `OP_SERVICE_ACCOUNT_TOKEN_RW` → `~/.config/op-sa/claude-agents-rw.token`（600 権限）→ Keychain `op-sa-claude-agents-rw` の順で解決して `op item create --vault agents`（フィールド `credential`）を実行しなければならない（SHALL）。受け取った値を `op` の argv に載せてはならない（MUST NOT）— JSON テンプレートを `op` の stdin に渡す形で受け渡し、argv に載せてよいのはアイテム名（秘密でない）だけとする。値を環境変数で子プロセスに渡してはならない（MUST NOT）（同一ユーザーからは argv と同程度に見えるため）。値をシェル変数に載せてはならない（MUST NOT）— 変数は参照が終わったあとも残るため、呼び出し側が設定した `PS4` の展開を経由して xtrace の stderr に漏れうる（xtrace の on/off では塞げない。秘密の代入区間だけ `set +x` にしても、変数が残っている限り以降のトレース行のプレフィックスとして出る）。加えて bash 変数は NUL バイトを保持できず、値が黙って縮む。stdin の読み取りから JSON 化までを 1 プロセス内で完結させ、値は「読み取ったプロセス → `op`」のパイプの中だけを通すこと。stdin が空の場合の exit 46 は、この構成でも二重登録の判定（`op item list`）・読み取り用 SA の解決・`op item create` のいずれよりも前に返さなければならない（SHALL）。argv 経路へのフォールバックを設けてはならない（MUST NOT）— 値を渡す経路を組み立てられない場合は登録せずに非 0 で終了する。環境の `OP_SERVICE_ACCOUNT_TOKEN`（多くのマシンで read-only トークン）を登録に流用してはならない（MUST NOT）。アイテム名は命名規約 `<prefix>--<service>`（prefix は小文字のプロジェクト名またはエージェント名、区切り `--` はちょうど 1 回）に反する場合 exit 46 で拒否し（SHALL）、既に登録済みのアイテムは上書きせず exit 47 で止まる（SHALL）。二重登録の判定は読み取り用 SA（claude-agents-ro。解決順は読み取り経路と同じ env → 600 ファイル → Keychain）による `op item list --vault agents` の title 完全一致で行わなければならず（SHALL）、rw SA の read 権に依存させてはならない（MUST NOT — read 権が無い構成では判定が「未登録」側に倒れ、1Password は同名アイテムの作成を許すため重複ができる）。判定を `credential` フィールドの有無に依存させてもならない（MUST NOT — フィールド欠落アイテムを「未登録」と誤判定して同名重複を作らないため）。読み取り用 SA が解決できない、`op item list` が失敗する、またはその出力を解析できず判定が不能な場合は、`op item create` を実行せず exit 48 で終了し（SHALL — fail-closed。解析失敗を「未登録」と同じ扱いにしてはならない（MUST NOT）— 判定できていないまま作成に進むため）、stderr に「ro トークンをこのマシンに配布する」か「rw SA に agents 保管庫の read 権を付ける」かの選択肢を案内する。rw トークンがどこにも無い場合は exit 43 で配布依頼の案内を返す。登録されるアイテムは category が API Credential・フィールド名が `credential` であり、`op://agents/<item>/credential` で参照できなければならない（SHALL）。

#### Scenario: プロジェクト名接頭辞のアイテムを登録する

- **WHEN** rw SA トークンが解決できるマシンで `printf '%s' "$VALUE" | fmtoken.sh --register newproj--newsvc` を実行する
- **THEN** rw トークンを使った `op item create` が実行され exit 0 となり、値は標準出力にも `op` の argv にも現れず、`op` の stdin に渡る JSON にのみ現れる

#### Scenario: 特殊文字を含む値が壊れずに登録される

- **WHEN** `"` `\` 改行 `$` `'` タブ を含む値を stdin から渡して `--register` を実行する
- **THEN** `op` の stdin に渡る JSON をパースした `credential` フィールドの値が、渡した値と完全一致する

#### Scenario: NUL バイトを含む値がバイト単位で保存される

- **WHEN** `printf 'A\0B\n'`（4 バイト）を stdin から渡して `--register` を実行する
- **THEN** `op` の stdin に渡る JSON の `credential` フィールドが 4 バイトのまま一致する（値をシェル変数に載せる実装では NUL が落ちて 3 バイトになる）

#### Scenario: 呼び出し側のカスタム PS4 でも値が stderr に出ない

- **WHEN** `PS4` に fmtoken.sh の内部変数名の展開を含めた状態で `bash -x` 配下から `--register` を実行する
- **THEN** トレース自体は出ているが、値は stderr に一度も現れない（成功経路でも、二重登録などの早期 exit 経路でも同じ）

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

#### Scenario: アイテム一覧を解析できないなら登録しない（fail-closed）

- **WHEN** `op item list` が exit 0 のまま解析できない出力を返す状態で `--register` を実行する
- **THEN** exit 48 となり、`op item create` は呼ばれず、stderr に判定不能の理由と上記の選択肢が出る

#### Scenario: rw トークン未配布

- **WHEN** rw SA トークンが env・ファイル・Keychain のどこにも無いマシンで `--register` を実行する
- **THEN** ro トークンが環境にあっても流用されず、exit 43 で rw トークンの配布依頼の案内が出る

