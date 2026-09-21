## RENAMED Requirements

- FROM: `台帳を使わない前景実行の入口を持つ`
- TO: `前景実行だけを入口にする`

## MODIFIED Requirements

### Requirement: 一時領域は親の環境をそのまま引き継ぐ
worker は依頼のために子プロセス用の一時ディレクトリを新規作成してはならない（MUST NOT）。ただし 1 回の前景実行につき 1 つ作る runtime CODEX_HOME（認証情報への link と `config.toml` だけを置く 0700 のディレクトリ）は、この禁止の対象外とする。App Server と子ツールの `TMPDIR` と `TMPPREFIX` は、role によらず worker を起動した親プロセスの値をそのまま引き継がなければならない（MUST）。親に値が無ければ子にも現れてはならず（MUST NOT）、worker が既定値を補ってはならない（MUST NOT）。runtime CODEX_HOME は、親に `TMPDIR` があればその配下に、無ければ実行環境の既定の一時領域に作らなければならない（MUST）。どちらの場合も、その置き場所を理由に子へ渡す `TMPDIR` / `TMPPREFIX` を作ったり書き換えたりしてはならない（MUST NOT）。同時に走る依頼の一時ファイルが同じ親の一時領域に混ざりうることと、依頼が残した一時ファイルの出どころを worker が記録しないことを明示しなければならない（MUST）。この追跡が必要になった場合は Codex 側だけに仕組みを戻してはならず（MUST NOT）、Claude のサブエージェント側にも同じ仕組みを入れて揃えなければならない（MUST）。

#### Scenario: 書く役の子が一時領域を見る
- **WHEN** implement の前景実行が開始され、子プロセスが `TMPDIR` と `TMPPREFIX` を読む
- **THEN** どちらも worker を起動した親プロセスの値と一致し、worker が作った子プロセス用の一時ディレクトリは存在しない（runtime CODEX_HOME は認証情報を置くためのものである）

#### Scenario: 親に一時領域の指定が無い
- **WHEN** 親環境に `TMPDIR` も `TMPPREFIX` も無い状態で前景実行を開始する
- **THEN** 子の環境にもどちらも現れず、worker は開始を拒否せず、既定値を補って渡さない

#### Scenario: 親に一時領域の指定が無い状態で実行する
- **WHEN** 親環境に `TMPDIR` が無い状態で前景実行を開始する
- **THEN** runtime CODEX_HOME は実行環境の既定の一時領域に作られ、子の環境には `TMPDIR` も `TMPPREFIX` も現れない

### Requirement: 子へ渡す環境変数は親を引き継ぎ、渡してはならない変数だけ落とす
worker は依頼の子プロセスへ、worker を起動した親プロセスの環境変数を引き継がなければならない（MUST）。ただし worker が自分で決める `CODEX_HOME`、Codex 自身が認証に読み指定された CODEX_HOME 以外の課金経路へ移し得る値、および子の git 操作を cwd 以外の checkout へ向け得る `GIT_DIR`・`GIT_WORK_TREE`・`GIT_COMMON_DIR`・`GIT_INDEX_FILE` は落とさなければならない（MUST）。TMPDIR と TMPPREFIX は落としてはならず（MUST NOT）、role によらず親の値のまま子へ渡さなければならない（MUST）。引き継ぎが Codex 側の環境変数ポリシーで絞られる場合は、依頼ごとの runtime 設定でその絞りを解かなければならない（MUST）。worker 自身の git 呼び出しは親の環境をそのまま使って行ってはならず（MUST NOT）、固定 allowlist の最小環境で行わなければならない（MUST）。

#### Scenario: worker の中で GitHub を操作する
- **WHEN** implement の子プロセスが gh コマンドで Draft PR を作り issue にコメントする
- **THEN** 認証が子に届いており、代理実行なしで完了する

#### Scenario: 親に別の認証変数がある
- **WHEN** 親環境に Codex 自身が認証に読む変数が設定された状態で依頼を開始する
- **THEN** その変数は子に現れず、実行中 account と指定された CODEX_HOME の identity 検査が通る

#### Scenario: どの役にも一時領域の指定が親の値のまま届く
- **WHEN** 親環境に TMPDIR / TMPPREFIX がある状態で workspace-write role と read-only role の依頼をそれぞれ開始する
- **THEN** どちらの子の環境にも両方が親と同じ値で現れる

#### Scenario: 親が Git のパスを指している
- **WHEN** 親環境に GIT_DIR / GIT_WORK_TREE / GIT_COMMON_DIR / GIT_INDEX_FILE が設定された状態で依頼を開始する
- **THEN** どれも子の環境に現れず、子の git 操作は cwd の linked worktree に向き、worker 自身の linked worktree 必須検査も曲げられない

### Requirement: effort を二段階で検証してから実行する
worker は依頼を受け取ったとき、optional effort の非空文字列、許可キー、定義済み role、絶対パスで存在する CODEX_HOME を静的に検証しなければならない（MUST）。モデル名と effort の対応は initialize 後かつ thread/start 前に、指定された CODEX_HOME で起動した account の model/list を使って検証しなければならない（MUST）。固定 enum で対応を推測してはならない（MUST NOT）。

#### Scenario: 静的に不正な request を渡す
- **WHEN** effort が空/非文字列、role が未定義、未知フィールドがある、または CODEX_HOME が利用できない
- **THEN** App Server に turn を送る前に拒否し、同じ形の失敗 JSON と非ゼロ終了コードを返す

#### Scenario: モデル固有の effort が非対応である
- **WHEN** model/list が luna に ultra を広告していないのに luna/ultra を要求する
- **THEN** 非対応 effort を `error_kind` に入れ、thread/start と turn/start を一度も呼ばず、非ゼロで終了する

#### Scenario: 一覧に無いモデルまたは一覧取得失敗
- **WHEN** includeHidden=true の全ページに model フィールド完全一致の一意なモデルがない、一覧が不正、または model/list の取得に失敗する
- **THEN** 開始前に原因を返し、既定モデルや別の実行先へ fallback しない

#### Scenario: 広告された新しい effort または hidden モデル
- **WHEN** 明示指定モデルが一覧にあり、その supportedReasoningEfforts の reasoningEffort に要求値が含まれる
- **THEN** 固定 enum や hidden 属性を理由に拒否せず、指定モデルと effort を使用する

### Requirement: effort は turn start のみに渡す
worker は model を thread/start と turn/start の双方へ渡し、明示された effort を turn/start の effort にのみ渡さなければならない（MUST）。effort が省略された依頼では送信時も省略し、payload を補完してはならない（MUST NOT）。指定 CODEX_HOME の identity、role ごとの sandbox・networkAccess、writableRoots を持たない readOnly policy を維持しなければならない（MUST）。explore / summarize は本体が汎用サブエージェントとして起こす read-only role なので、review 系と同じく networkAccess=true としなければならない（MUST）。

#### Scenario: 明示 effort を送信する
- **WHEN** sol/high の検証が成功する
- **THEN** 両 RPC の model は gpt-5.6-sol、turn/start.effort は high となり、thread/start の effort や config に effort を追加しない

#### Scenario: effort がない request
- **WHEN** model のみを指定した依頼を実行する
- **THEN** model/list で model を照合し、turn/start に effort を載せず、要求値を補完しない

### Requirement: 要求設定と実効設定を ID と共に公開する
worker は execution.version=1 形式で role/requested/effective/evidence を payload と別に保持し、thread_id と turn_id に結び付けなければならない（MUST）。公開先は標準出力の 1 行 JSON だけとし、worker が結果をファイルや永続 store に保存してはならない（MUST NOT）。要求値や model/list の default を実効値として補完してはならない（MUST NOT）。

#### Scenario: 実効設定を観測できる
- **WHEN** account 照合が成功し、RPC 応答または通知で model/effort を取得する
- **THEN** executor/account/model/effort の要求値と実効値、観測元を別々に記録し、turn 観測を thread 観測より優先する。差異があれば受け入れ不一致として返し自動再送しない

#### Scenario: 実効値または ID が取得できない
- **WHEN** API が effort を返さない、または thread/turn 作成前に失敗する
- **THEN** 不明な実効値/ID は null、観測元は unavailable とし、取得できた role/要求設定/ID だけを返す

#### Scenario: 前景経路で実効設定を公開する
- **WHEN** 前景実行が完走または失敗して結果を返す
- **THEN** role/requested/effective/evidence と取得できた ID が標準出力の JSON に入り、ファイルへ保存されない

### Requirement: 前景実行だけを入口にする
worker は依頼ファイルを受け取って 1 回のターンを実行し終了する `run` だけを公開実行入口として持たなければならない（MUST）。この入口は app-server への接続、指定 CODEX_HOME によるアカウント固定、model と effort の検証、role ごとの砂場の決定、ターン開始前の利用枠確認、ターンの完走を 1 プロセス内で行わなければならない（MUST）。job や account の永続 store、ownership、run directory を作成・参照してはならず（MUST NOT）、それらのパスを指定する引数や lifecycle subcommand を受け取ってはならない（MUST NOT）。

#### Scenario: 永続状態を作らずに完走する
- **WHEN** 偽の app-server を使って `run` の依頼を完走させる
- **THEN** SQLite、run JSON、ownership、job directory のいずれも作られず、コマンドは 1 行 JSON を出して終了する

#### Scenario: 廃止済み lifecycle command を指定する
- **WHEN** `register`、`submit`、`status`、`result`、`cancel`、`ack`、`send`、`reap` のいずれかを指定する
- **THEN** 引数解析で拒否し、永続状態を作らず、`run` へ暗黙変換しない

### Requirement: 前景実行はアカウントを依頼された CODEX_HOME で固定する
前景実行は、依頼に載せられた CODEX_HOME を実行アカウントとして固定しなければならない（MUST）。account 名を CODEX_HOME へ解決するために永続 registry を読んではならない（MUST NOT）。依頼の account 名は結果の記録に使うラベルであり、照合の材料にしてはならない（MUST NOT）。照合は、app-server が返した実行中アカウントが、渡された CODEX_HOME の認証情報と一致することで行わなければならない（MUST）。前景実行は 1 件ごとに runtime CODEX_HOME を作り、認証情報への link が実行中に差し替えられていないことを確認し、終了時にその link を外して片付けなければならない（MUST）。runtime CODEX_HOME は `TMPDIR` 配下の所有者だけが読み書きできるディレクトリに置かなければならず（MUST）、app-server とその子に渡す `TMPDIR` / `TMPPREFIX` を変えてはならない（MUST NOT）。結果の `effective.account` には app-server が返した実行中アカウントを入れなければならず（MUST）、依頼の account 名をそのまま写してはならない（MUST NOT）。依頼の account 名は `requested.account` にだけ残さなければならない（MUST）。どの CODEX_HOME を使うかは呼び出し側の責任であることを仕様は明示しなければならない（MUST）。

#### Scenario: 渡された認証情報と実行中アカウントが食い違う
- **WHEN** app-server が返した実行中アカウントが、依頼の CODEX_HOME の認証情報と一致しない
- **THEN** ターンを開始せず、理由を示して終了し、別のアカウントへ切り替えない

#### Scenario: 実行中に認証情報の link が差し替えられる
- **WHEN** ターンの待機中に runtime の認証情報への link が別の場所を指すようになる
- **THEN** ターンの中断を要求し、その理由を結果に残す

#### Scenario: 対応表が指す CODEX_HOME が要求名と食い違う
- **WHEN** 依頼の account 名が意図したものとは別の CODEX_HOME が依頼に載り、そのまま完走する
- **THEN** 結果の実効アカウントには app-server が返した実行中アカウントが入り、依頼の account 名は要求側にだけ残る
