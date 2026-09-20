## ADDED Requirements

### Requirement: 台帳を使わない前景実行の入口を持つ
worker は 1 回のターンを実行して終了する前景実行の入口を持たなければならない（MUST）。この入口は依頼ファイルを受け取り、app-server への接続・アカウントの固定・model と effort の検証・役割ごとの砂場の決定・ターン開始前の利用枠の確認・ターンの完走までを台帳経路と同じ手順で行わなければならない（MUST）。前景実行は job の台帳（`ledger.sqlite`）と所有権の記録（`ownership.sqlite`）を作ってはならず、読んでもならない（MUST NOT）。台帳のパスを指定する引数を前景実行が受け取ってはならない（MUST NOT）。ターン実行の本体は記録先を差し替えられる形でなければならず、前景経路と台帳経路は同じターン実行を通らなければならない（MUST）。

#### Scenario: 台帳を作らずに完走する
- **WHEN** 偽の app-server を使って前景実行の依頼を完走させる
- **THEN** `ledger.sqlite` と `ownership.sqlite` はどこにも作られず、コマンドは結果を出して終了する

#### Scenario: 台帳経路は前景実行の追加後も変わらない
- **WHEN** 既存の台帳経路（受け付け・実行・状態照会・結果回収・受領）のテストを実行する
- **THEN** すべて従来どおり成功し、job の状態遷移・所有権の予約・cwd の排他は変わらない

### Requirement: 前景実行はアカウントを依頼された CODEX_HOME で固定する
前景実行は、依頼に載せられた CODEX_HOME を実行アカウントとして固定しなければならない（MUST）。account 名を CODEX_HOME へ解決するために台帳を読んではならない（MUST NOT）。依頼の account 名は結果の記録に使うラベルであり、照合の材料にしてはならない（MUST NOT）。照合は、app-server が返した実行中アカウントが、渡された CODEX_HOME の認証情報と一致することで行わなければならない（MUST）。前景実行は 1 件ごとに runtime の CODEX_HOME を自分で作り、認証情報への link が実行中に差し替えられていないことを確認し、終了時にその link を外して片付けなければならない（MUST）。この runtime の CODEX_HOME は一時領域（`TMPDIR`）配下の所有者だけが読み書きできるディレクトリに置かなければならず（MUST）、app-server とその子に渡す一時領域の指定（`TMPDIR` / `TMPPREFIX`）を変えてはならない（MUST NOT）。これは job のための一時領域を新規に作らず親の環境を引き継ぐという既存の要件とは別のもので、その要件を緩めるものではない。この結果として、登録済み account だけに実行先を縛る性質は前景経路には無く、どの CODEX_HOME を使うかは呼び出し側の責任になることを仕様は明示しなければならない（MUST）。

#### Scenario: 渡された認証情報と実行中アカウントが食い違う
- **WHEN** app-server が返した実行中アカウントが、依頼の CODEX_HOME の認証情報と一致しない
- **THEN** ターンを開始せず、理由を示して終了し、別のアカウントへ切り替えない

#### Scenario: 実行中に認証情報の link が差し替えられる
- **WHEN** ターンの待機中に runtime の認証情報への link が別の場所を指すようになる
- **THEN** ターンの中断を要求し、その理由を結果に残す

### Requirement: 前景実行は呼んだプロセスと一緒に終わる
前景実行は、起動時に控えた**祖先の連鎖のいずれか**が消えたことを検知しなければならない（MUST）。連鎖は起動時の親から辿れる祖先すべてを控え、一定間隔で辿り直して控えと突き合わせなければならない（MUST）。直接の親だけを見て判定してはならない（MUST NOT。呼び出し側と前景実行のあいだに shell の wrapper が挟まるため、直接の親は呼び出し元と一致しない）。検知したら実行中のターンの中断を要求し、app-server の子プロセスを含めて終了しなければならない（MUST）。親の消失から、コマンド自身と app-server の両方が終了するまでは 30 秒以内でなければならない（MUST）。app-server の子プロセスを、コマンドと別のセッションで起こしてはならない（MUST NOT）。中断の確認を待つ猶予は、中断要求そのものの応答待ちと検知と後始末の時間を足しても、この 30 秒に収まる長さでなければならない（MUST）。停止要求は、ターンの待機中だけでなく app-server へのすべての要求の直前に確認しなければならない（MUST）。

#### Scenario: 呼び出し元が終了する
- **WHEN** 前景実行と呼び出し元のあいだに shell の wrapper が 1 段ある状態で、その wrapper の親（呼び出し元に当たるプロセス）を、ターンの実行中に終了させる
- **THEN** wrapper が残っていても消失を検知し、コマンドと app-server の両方のプロセスが 30 秒以内に存在しなくなる

#### Scenario: 親が生きている間は走り続ける
- **WHEN** 親プロセスが生きたままターンが続いている
- **THEN** 前景実行は中断を要求せず、ターンの完了まで待つ

### Requirement: 前景実行は停止の合図でターンを中断してから終わる
前景実行は SIGTERM と SIGINT を受けたら、実行中のターンに中断を要求してから終了しなければならない（MUST）。app-server の子プロセスを残してはならない（MUST NOT）。シグナルを受け取った文脈から app-server へ直接要求を送ってはならず（MUST NOT）、停止の合図は親の消失・シグナル・サーバーからの想定外要求のいずれも同じ 1 つの停止要求として扱わなければならない（MUST）。猶予の中で中断の確認が返らない場合は、その旨を結果に残して終了しなければならない（MUST）。

#### Scenario: SIGTERM を受ける
- **WHEN** ターンの実行中の前景実行に SIGTERM を送る
- **THEN** app-server に `turn/interrupt` が届き、コマンドと app-server の両方のプロセスが残らない

#### Scenario: 中断の確認が返らない
- **WHEN** 中断を要求したあと、猶予の中で終了の通知が返らない
- **THEN** 中断未確認であることを結果に残し、app-server を段階的に終了させてコマンドを終える

### Requirement: 前景実行の結果は 1 行の JSON で返す
前景実行は結果を標準出力の 1 行の JSON で返さなければならない（MUST）。成功と失敗で形を変えてはならない（MUST NOT）。JSON は次のキーを含まなければならない（MUST）: 最終回答のテキスト `text`、ターンの終了状態 `status`、使用量 `usage`、要求設定と実効設定を収めた `execution`（既存の `execution.version=1` 形式の `role` / `requested` / `effective` / `evidence`。`requested` は executor / account / model / effort、`effective` と `evidence` は観測した model / effort とその観測元）、thread の ID `thread_id`、turn の ID `turn_id`、失敗の理由 `error_kind`。取得できなかった項目は `null` とし、要求値や既定値で補完してはならない（MUST NOT）。失敗した実行は非ゼロの終了コードで終わらなければならない（MUST）。最終回答が一意に定まらない場合は、実行が終端に達していても成功として返してはならない（MUST NOT）。

#### Scenario: ターンが完走する
- **WHEN** 前景実行のターンが完了する
- **THEN** 標準出力の 1 行 JSON に最終回答・終了状態・使用量・要求設定・観測した model / effort と観測元・thread と turn の ID が入り、終了コードは 0 になる

#### Scenario: ターン開始前に失敗する
- **WHEN** 利用枠の確認やアカウントの照合で失敗し、ターンが始まらない
- **THEN** 同じ形の 1 行 JSON に失敗の理由が入り、観測できなかった項目は `null` のままで、終了コードは非ゼロになる

### Requirement: 前景実行は同時実行の枠管理と作業ディレクトリの排他を持たない
前景実行は account ごとの同時実行上限を判定してはならず（MUST NOT）、作業ディレクトリの排他を取ってはならない（MUST NOT）。ターン開始前の利用枠の確認は行わなければならず（MUST）、同時に走っている件数は 1 として扱い、余裕率は依頼の指定（既定値あり）を使わなければならない（MUST）。この結果として失われる 2 つの性質を仕様は明示しなければならない（MUST）: 同じ account へ同時に投げられる件数を worker が制限しないこと、同じ作業ディレクトリへ同時に投げられることを worker が拒まないこと。この 2 つは呼び出し側が作業ディレクトリを 1 件ずつ割り当てることで担保し、Codex 側だけに仕組みを戻してはならない（MUST NOT）。必要になった場合は Claude のサブエージェント側にも同じ仕組みを入れて揃えなければならない（MUST）。

#### Scenario: 利用枠を使い切っている
- **WHEN** ターン開始前の利用枠の確認で、余裕率を足すと上限を超える
- **THEN** ターンを開始せず、理由を示して終了する

#### Scenario: 同じ作業ディレクトリへ 2 件投げる
- **WHEN** 同じ作業ディレクトリを指す前景実行を 2 件起動する
- **THEN** worker はどちらも拒まず、排他の判定を行わない

## MODIFIED Requirements

### Requirement: 要求設定と実効設定を ID と共に公開する
worker は design の execution.version=1 形式で role/requested/effective/evidence を payload と別に保持し、実行経路ごとの公開先と job_id/thread_id/turn_id に結び付けなければならない（MUST）。公開先は台帳経路では保存された status/result、前景経路では標準出力の 1 行 JSON とする（MUST）。develop は台帳経路の同じ記録を run history に保持しなければならない（MUST）。前景経路は run history を持たないので、記録の保持先は呼び出し側が受け取った JSON だけであり、worker がそれを保存してはならない（MUST NOT）。要求値や model/list の default を実効値として補完してはならない（MUST NOT）。

#### Scenario: 実効設定を観測できる
- **WHEN** account 照合が成功し、RPC 応答または通知で model/effort を取得する
- **THEN** executor/account/model/effort の要求値と実効値、観測元を別々に記録し、turn 観測を thread 観測より優先する。差異があれば受け入れ不一致として残し自動再送しない

#### Scenario: 実効値または ID が取得できない
- **WHEN** API が effort を返さない、thread/turn 作成前に失敗する、または旧台帳行である
- **THEN** 不明な実効値/ID は null、観測元は unavailable とし、取得できた role/要求設定/ID は保持する。旧 payload/hash は変更しない

#### Scenario: 前景経路で実効設定を公開する
- **WHEN** 前景実行が完走または失敗して結果を返す
- **THEN** 同じ role/requested/effective/evidence と job に相当する ID 群が標準出力の JSON に入り、台帳にもファイルにも保存されない
