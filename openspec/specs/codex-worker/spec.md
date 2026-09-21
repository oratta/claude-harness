# codex-worker Specification

## Purpose
Codex の job を Claude Code のサブエージェントと同じ担い手として走らせるための実行基盤を定める。1 件の依頼につき専用の runtime CODEX_HOME を作り、role（implement / spec-write / review / spec-review / impl-review / decider）ごとに砂場と取得経路を決め、アカウントと作業ディレクトリの排他・認証帰属の照合・結果の受領（ack）までを台帳で管理する。

権限の範囲は「Claude のサブエージェントが自分で完了できる作業を、worker の中の担当者も自分で完了できる」ことを基準に決める。書く役は砂場なし（danger-full-access）で動き、Claude のサブエージェントと同じく親の環境で commit・push・GitHub 操作を自分で完了する。読む役は書き込み許可を持たず、取得経路だけを Claude 側の同じ役に揃える。書く役を砂場なしにした根拠と、揃えられなかった項目は実測の証跡とともに記録する。ここで扱うのは実行と隔離であって品質承認ではなく、job の完了は develop 側の仕様承認・テスト証拠・レビューゲートを代替しない。

アカウント単位の同時実行数の決め方は capability `codex-worker-concurrency` が定める。
## Requirements
### Requirement: 一時領域は親の環境をそのまま引き継ぐ
worker は job のために一時ディレクトリを新規作成してはならない（MUST NOT）。ただし前景実行が 1 件につき 1 つ作る runtime CODEX_HOME（認証情報への link と `config.toml` だけを置く 0700 のディレクトリ）は、台帳経路が state-dir の下に作っているものの置き場所を変えただけなので、この禁止の対象外とする。App Server と子ツールの `TMPDIR` と `TMPPREFIX` は、role によらず worker を起動した親プロセスの値をそのまま引き継がなければならない（MUST）。親に値が無ければ子にも現れてはならず（MUST NOT）、worker が既定値を補ってはならない（MUST NOT）。前景実行の runtime CODEX_HOME は、親に `TMPDIR` があればその配下に、無ければ実行環境の既定の一時領域に作らなければならない（MUST）。どちらの場合も、その置き場所を理由に子へ渡す `TMPDIR` / `TMPPREFIX` を作ったり書き換えたりしてはならない（MUST NOT）。この結果として次の 2 つの性質が失われることを、仕様は明示しなければならない（MUST）: 同時に走る job の一時ファイルが同じ親の一時領域に混ざりうること、job が残した一時ファイルの出どころを worker が記録しないこと。この 2 つの追跡が必要になった場合は、Codex 側だけに仕組みを戻してはならず（MUST NOT）、Claude のサブエージェント側にも同じ仕組みを入れて揃えなければならない（MUST）。

#### Scenario: 書く役の子が一時領域を見る
- **WHEN** implement job が開始され、子プロセスが `TMPDIR` と `TMPPREFIX` を読む
- **THEN** どちらも worker を起動した親プロセスの値と一致し、worker が作った作業用の一時ディレクトリは存在しない（runtime CODEX_HOME は認証情報を置くためのもので、子の一時領域ではない）

#### Scenario: 親に一時領域の指定が無い
- **WHEN** 親環境に `TMPDIR` も `TMPPREFIX` も無い状態で implement job を開始する
- **THEN** 子の環境にもどちらも現れず、worker は開始を拒否せず、既定値を補って渡さない

#### Scenario: 親に一時領域の指定が無い状態で前景実行する
- **WHEN** 親環境に `TMPDIR` が無い状態で前景実行を開始する
- **THEN** runtime CODEX_HOME は実行環境の既定の一時領域に作られ、子の環境には `TMPDIR` も `TMPPREFIX` も現れない

### Requirement: 実 Codex のテスト完走と拒否の証拠を残す
実装は fake 回帰試験に加え、実 Codex implement role で scripts/test.sh 全件の成功件数・総件数・exit code と対象 HEAD を記録しなければならない（MUST）。加えて、worker の中から 127.0.0.1 の待ち受けへの HTTP 到達、git commit と feature branch への git push、Draft PR 作成と記録先へのコメント、ローカルサーバーを立てる外部リポのテストスクリプトの完走を実測し、それぞれのコマンド・出力・exit code を記録しなければならない（MUST）。子シェルの TMPDIR が worker を起動した親の TMPDIR と一致することと、素の mktemp -d を使う外部スクリプトが worker の中で完走することも、実環境で実測して記録しなければならない（MUST）。砂場なしにした role では cwd の外への書き込みが OS に止められないことを境界プローブで確かめ、その結果を記録しなければならない（MUST）。CODEX-WORKER.md に実際の範囲と制約を反映しなければならない（MUST）。

#### Scenario: 実環境の受け入れ結果を記録する
- **WHEN** 対象 HEAD の scripts/test.sh と境界プローブが完了する
- **THEN** 全件成功・exit 0、各操作のコマンド/出力/exit code、砂場なしの role で cwd の外への書き込みが通ることを記録する。件数は過去の1465件を固定せず対象 HEAD の実測値を使う

#### Scenario: 一時領域の引き継ぎを実環境で確かめる
- **WHEN** implement role の worker の中で子シェルが TMPDIR を出力し、mktemp -d を使う外部スクリプトを実行する
- **THEN** 出力された TMPDIR が worker を起動した親の TMPDIR と一致し、スクリプトが完走したこと（コマンド・出力・exit code）が記録される

#### Scenario: 代理実行なしの完走を記録する
- **WHEN** implement role の worker がループバックへの HTTP・git commit・git push・Draft PR 作成・記録先へのコメント・外部リポのテストスクリプトを自分で実行する
- **THEN** 各操作のコマンド・出力・exit code と対象 HEAD が記録され、本体が代理実行した操作は残っていない

### Requirement: 書く役は worker の中でネットワークと Git 操作を自分で完了できる
workspace-write role（implement / spec-write）は OS の砂場なしで実行しなければならない（MUST）: `thread/start` の sandbox は `danger-full-access`、turn の sandboxPolicy は `{'type':'dangerFullAccess'}` とする。approvalPolicy は never を維持しなければならない（MUST）。砂場なしの policy は書き込み範囲とネットワークの項目を持たないので、この role に writableRoots・excludeSlashTmp・excludeTmpdirEnvVar・networkAccess を渡してはならない（MUST NOT）。この role が Claude のサブエージェントと同じく親の環境で cwd の外へも書けることは、Claude 側に対応する隔離が無いことの帰結であり、指示と記録先の証拠で担保する。

一時領域も同じ理由で親の環境を引き継ぐ。詳細は Requirement「一時領域は親の環境をそのまま引き継ぐ」が定める。

#### Scenario: ループバックの待ち受けへ繋ぐ
- **WHEN** implement job の子プロセスが 127.0.0.1 の待ち受けポートへ HTTP する
- **THEN** 応答を受け取れ、砂場もネットワーク遮断も拒否しない

#### Scenario: linked worktree で commit する
- **WHEN** implement job が cwd（linked worktree）で git switch -c と git commit を実行する
- **THEN** `.git` ファイルが指す Git 共通ディレクトリ配下（`worktrees/<この worktree>/` の HEAD.lock / index.lock を含む）への書き込みが拒否されず、branch 作成と commit が成立する

### Requirement: 読む役は書き込みを増やさず取得経路だけ Claude 側の同じ役に揃える
read-only role（review / spec-review / impl-review / decider）は readOnly policy と approvalPolicy never を維持しなければならない（MUST）。read-only role に writableRoots を与えてはならない（MUST NOT）。networkAccess は Claude 側の対応する役が持つ取得手段に合わせなければならない（MUST）: 本体が汎用サブエージェントとして起こす役（review / spec-review / impl-review）は true、読み取り専用ツールだけを持ちシェルを持たない役（decider）は false とする。

#### Scenario: 独立レビューの役を実行する
- **WHEN** review / spec-review / impl-review job が開始される
- **THEN** readOnly policy と approvalPolicy never を保ったまま networkAccess=true で動き、書き込み許可は得ない

#### Scenario: 決める役を実行する
- **WHEN** decider job が開始される
- **THEN** readOnly policy・networkAccess=false・approvalPolicy never で動き、書き込み許可も取得経路も得ない

### Requirement: 子へ渡す環境変数は親を引き継ぎ、渡してはならない変数だけ落とす
worker は job の子プロセスへ、worker を起動した親プロセスの環境変数を引き継がなければならない（MUST）。ただし次は落とさなければならない（MUST）: worker が自分で決める値（CODEX_HOME）、Codex 自身が認証に読み登録済み account 以外の課金経路へ移し得る値、および子の git 操作を cwd 以外の checkout へ向け得る値（GIT_DIR・GIT_WORK_TREE・GIT_COMMON_DIR・GIT_INDEX_FILE）。TMPDIR と TMPPREFIX は落としてはならず（MUST NOT）、role によらず親の値のまま子へ渡さなければならない（MUST）。引き継ぎが Codex 側の環境変数ポリシーで絞られる場合は、job ごとの runtime 設定でその絞りを解かなければならない（MUST）。worker 自身の git 呼び出し（依頼の検査・runtime の場所の算出）は、親の環境をそのまま使って行ってはならず（MUST NOT）、固定 allowlist の最小環境で行わなければならない（MUST）。

#### Scenario: worker の中で GitHub を操作する
- **WHEN** implement job の子プロセスが gh コマンドで Draft PR を作り issue にコメントする
- **THEN** 認証が子に届いており、代理実行なしで完了する

#### Scenario: 親に別の認証変数がある
- **WHEN** 親環境に Codex 自身が認証に読む変数（API キー等）が設定された状態で job を開始する
- **THEN** その変数は子に現れず、account の identity 検査は登録済み account のまま通る

#### Scenario: どの役にも一時領域の指定が親の値のまま届く
- **WHEN** 親環境に TMPDIR / TMPPREFIX がある状態で workspace-write role と read-only role の job をそれぞれ開始する
- **THEN** どちらの子の環境にも両方が親と同じ値で現れる

#### Scenario: 親が Git のパスを指している
- **WHEN** 親環境に GIT_DIR / GIT_WORK_TREE / GIT_COMMON_DIR / GIT_INDEX_FILE が設定された状態で job を開始する
- **THEN** どれも子の環境に現れず、子の git 操作は cwd の linked worktree に向く。worker 自身の linked worktree 必須の検査もこれらの値で曲げられない

### Requirement: 書く役を砂場なしにした根拠は実測の証跡とともに記録する
書く役を砂場なしにした根拠（第 1 段 = workspace-write ＋ `networkAccess: true` ＋ Git 共通ディレクトリで失敗したコマンド・出力・exit code と、それが砂場の拒否であることの確認）は、変更の記録先に残っていなければならない（MUST）。read-only role を砂場なしにしてはならない（MUST NOT）。role の砂場の水準を変える変更は、実測の証跡を伴わなければならない（MUST）。

#### Scenario: 証跡がないまま緩める
- **WHEN** 第 1 段の失敗の記録、または砂場の拒否であることの確認が無い状態で砂場なしの設定を入れようとする
- **THEN** その変更は受け入れられない

#### Scenario: 読む役を砂場なしにしようとする
- **WHEN** read-only role で完了できない操作を理由に、その role を砂場なしにしようとする
- **THEN** その変更は受け入れられない（read-only role は readOnly policy を維持する）

### Requirement: 揃えられなかった項目を項目ごとに記録する
Claude のサブエージェントと同じ作業を worker の中で完了できない項目が残った場合、項目ごとに「試したこと・失敗の出力・揃えられない理由」を変更の記録先と CODEX-WORKER.md に残さなければならない（MUST）。揃っていない項目を、揃ったものとして docs や references に書いてはならない（MUST NOT）。

#### Scenario: 一部の操作が揃わないまま終える
- **WHEN** 砂場なしでも完了できない操作が残る
- **THEN** その項目ごとに試したこと・失敗の出力・揃えられない理由が記録され、本体の代理実行が必要な操作としてその項目だけが docs に残る

### Requirement: effort を二段階で検証してから実行する
worker は optional effort の非空文字列検証、許可キー、未定義 role、未登録 account の拒否を submit の静的検証で実施しなければならない（MUST）。モデル名と effort の対応は initialize 後・thread/start 前・turn_submitted を立てる前に指定 account の model/list で検証しなければならない（MUST）。固定 enum で対応を推測してはならない（MUST NOT）。

#### Scenario: 静的に不正な request を投入する
- **WHEN** effort が空/非文字列、未定義 role、未登録 account、または未知フィールドがある
- **THEN** job 投入前に拒否し、App Server に turn を送らない

#### Scenario: モデル固有の effort が非対応である
- **WHEN** model/list が luna に ultra を広告していないのに luna/ultra を要求する
- **THEN** failed と非対応 effort の error_kind を保存し、thread/start と turn/start は一度も呼ばず、unknown にしない

#### Scenario: 一覧に無いモデルまたは一覧取得失敗
- **WHEN** includeHidden=true の全ページに model フィールド完全一致の一意なモデルがない、一覧が不正、または model/list の取得に失敗する
- **THEN** 開始前に failed と原因を記録し、既定モデル/実行先への fallback をしない

#### Scenario: 広告された新しい effort または hidden モデル
- **WHEN** 明示指定モデルが一覧にあり、その supportedReasoningEfforts の reasoningEffort に要求値が含まれる
- **THEN** 固定 enum や hidden 属性を理由に拒否せず、指定モデルと effort を使用する

### Requirement: effort は turn start のみに渡す
worker は model を thread/start と turn/start の双方へ渡し、明示された effort を turn/start の effort にのみ渡さなければならない（MUST）。旧 request の effort 省略は送信時も省略し、payload を補完してはならない（MUST NOT）。既存 account identity、role ごとの sandbox・networkAccess、writableRoots を持たない readOnly policy、unknown の所有権契約を維持しなければならない（MUST）。explore / summarize は本体が汎用サブエージェントとして起こす read-only role なので、review 系と同じく networkAccess=true としなければならない（MUST）。

#### Scenario: 明示 effort を送信する
- **WHEN** sol/high の検証が成功する
- **THEN** 両 RPC の model は gpt-5.6-sol、turn/start.effort は high となり、thread/start の effort や config に effort を追加しない

#### Scenario: 旧 request の effort がない
- **WHEN** model のみ指定した旧 request を初めて実行する
- **THEN** model/list で model を照合し、turn/start に effort を載せず、保存 request/hash を変えない

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

### Requirement: 台帳を使わない前景実行の入口を持つ
worker は 1 回のターンを実行して終了する前景実行の入口を持たなければならない（MUST）。この入口は依頼ファイルを受け取り、app-server への接続・アカウントの固定・model と effort の検証・役割ごとの砂場の決定・ターン開始前の利用枠の確認・ターンの完走までを台帳経路と同じ手順で行わなければならない（MUST）。前景実行は job の台帳（`ledger.sqlite`）と所有権の記録（`ownership.sqlite`）を作ってはならず、読んでもならない（MUST NOT）。台帳のパスを指定する引数を前景実行が受け取ってはならない（MUST NOT）。ターン実行の本体は記録先を差し替えられる形でなければならず、前景経路と台帳経路は同じターン実行を通らなければならない（MUST）。

#### Scenario: 台帳を作らずに完走する
- **WHEN** 偽の app-server を使って前景実行の依頼を完走させる
- **THEN** `ledger.sqlite` と `ownership.sqlite` はどこにも作られず、コマンドは結果を出して終了する

#### Scenario: 台帳経路は前景実行の追加後も変わらない
- **WHEN** 既存の台帳経路（受け付け・実行・状態照会・結果回収・受領）のテストを実行する
- **THEN** すべて従来どおり成功し、job の状態遷移・所有権の予約・cwd の排他は変わらない

### Requirement: 前景実行はアカウントを依頼された CODEX_HOME で固定する
前景実行は、依頼に載せられた CODEX_HOME を実行アカウントとして固定しなければならない（MUST）。account 名を CODEX_HOME へ解決するために台帳を読んではならない（MUST NOT）。依頼の account 名は結果の記録に使うラベルであり、照合の材料にしてはならない（MUST NOT）。照合は、app-server が返した実行中アカウントが、渡された CODEX_HOME の認証情報と一致することで行わなければならない（MUST）。前景実行は 1 件ごとに runtime の CODEX_HOME を自分で作り、認証情報への link が実行中に差し替えられていないことを確認し、終了時にその link を外して片付けなければならない（MUST）。この runtime の CODEX_HOME は一時領域（`TMPDIR`）配下の所有者だけが読み書きできるディレクトリに置かなければならず（MUST）、app-server とその子に渡す一時領域の指定（`TMPDIR` / `TMPPREFIX`）を変えてはならない（MUST NOT）。これは job のための一時領域を新規に作らず親の環境を引き継ぐという既存の要件とは別のもので、その要件を緩めるものではない。結果に載せる実効アカウント（`effective.account`）には、app-server が返した**実行中アカウント**（email かその digest）を入れなければならず（MUST）、依頼の account 名をそのまま写してはならない（MUST NOT）。依頼の account 名は `requested.account` にだけ残さなければならない（MUST）。これは、呼び出し側の対応表が誤っていて名前と CODEX_HOME が食い違う場合に、その食い違いを結果から事後に検知できるようにするためである。この結果として、登録済み account だけに実行先を縛る性質は前景経路には無く、どの CODEX_HOME を使うかは呼び出し側の責任になることを仕様は明示しなければならない（MUST）。

#### Scenario: 渡された認証情報と実行中アカウントが食い違う
- **WHEN** app-server が返した実行中アカウントが、依頼の CODEX_HOME の認証情報と一致しない
- **THEN** ターンを開始せず、理由を示して終了し、別のアカウントへ切り替えない

#### Scenario: 実行中に認証情報の link が差し替えられる
- **WHEN** ターンの待機中に runtime の認証情報への link が別の場所を指すようになる
- **THEN** ターンの中断を要求し、その理由を結果に残す

#### Scenario: 対応表が指す CODEX_HOME が要求名と食い違う
- **WHEN** 依頼の account 名が指すはずのアカウントとは別のアカウントの CODEX_HOME が依頼に載っており、そのまま完走する
- **THEN** 結果の実効アカウントには app-server が返した実行中アカウントが入り、依頼の account 名は要求側にだけ残るので、両者を比べると食い違いが分かる

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
前景実行は結果を標準出力の 1 行の JSON で返さなければならない（MUST）。成功と失敗で形を変えてはならない（MUST NOT）。JSON は次のキーを含まなければならない（MUST）: 最終回答のテキスト `text`、ターンの終了状態 `status`、使用量 `usage`、要求設定と実効設定を収めた `execution`（既存の `execution.version=1` 形式の `role` / `requested` / `effective` / `evidence`。`requested` は executor / account / model / effort、`effective` と `evidence` は観測した account / model / effort とその観測元。`effective.account` は app-server が返した実行中アカウントであり、`requested.account` の写しであってはならない（MUST NOT））、thread の ID `thread_id`、turn の ID `turn_id`、失敗の理由 `error_kind`。取得できなかった項目は `null` とし、要求値や既定値で補完してはならない（MUST NOT）。失敗した実行は非ゼロの終了コードで終わらなければならない（MUST）。app-server がスレッドまたはターンの開始をエラー応答で拒否した場合は、そのサーバーのエラーコードを含む理由を `error_kind` に入れて非ゼロで終わらなければならず（MUST）、自動で再試行してはならず（MUST NOT）、別のアカウントへ振り替えてはならない（MUST NOT）。応答が得られないまま切断・タイムアウトした場合も、受理されたかどうかを判断できないことを示す理由を `error_kind` に入れて非ゼロで終わらなければならない（MUST）。前景経路は所有権の記録を持たないので、この場合に保持する所有は無い。最終回答が一意に定まらない場合は、実行が終端に達していても成功として返してはならない（MUST NOT）。

#### Scenario: ターンが完走する
- **WHEN** 前景実行のターンが完了する
- **THEN** 標準出力の 1 行 JSON に最終回答・終了状態・使用量・要求設定・観測した model / effort と観測元・thread と turn の ID が入り、終了コードは 0 になる

#### Scenario: ターン開始前に失敗する
- **WHEN** 利用枠の確認やアカウントの照合で失敗し、ターンが始まらない
- **THEN** 同じ形の 1 行 JSON に失敗の理由が入り、観測できなかった項目は `null` のままで、終了コードは非ゼロになる

#### Scenario: サーバーが開始をエラー応答で拒否する
- **WHEN** スレッドまたはターンの開始の要求に対して app-server がエラー応答を返す
- **THEN** そのエラーコードを含む理由が `error_kind` に入った同じ形の 1 行 JSON を出し、再試行も別アカウントへの振り替えもせずに非ゼロで終わる

### Requirement: 前景実行は同時実行の枠管理と作業ディレクトリの排他を持たない
前景実行は account ごとの同時実行上限を判定してはならず（MUST NOT）、作業ディレクトリの排他を取ってはならない（MUST NOT）。ターン開始前の利用枠の確認は行わなければならず（MUST）、同時に走っている件数は 1 として扱い、余裕率は依頼の指定（既定値あり）を使わなければならない（MUST）。この結果として失われる 2 つの性質を仕様は明示しなければならない（MUST）: 同じ account へ同時に投げられる件数を worker が制限しないこと、同じ作業ディレクトリへ同時に投げられることを worker が拒まないこと。この 2 つは呼び出し側が作業ディレクトリを 1 件ずつ割り当てることで担保し、Codex 側だけに仕組みを戻してはならない（MUST NOT）。必要になった場合は Claude のサブエージェント側にも同じ仕組みを入れて揃えなければならない（MUST）。

#### Scenario: 利用枠を使い切っている
- **WHEN** ターン開始前の利用枠の確認で、余裕率を足すと上限を超える
- **THEN** ターンを開始せず、理由を示して終了する

#### Scenario: 同じ作業ディレクトリへ 2 件投げる
- **WHEN** 同じ作業ディレクトリを指す前景実行を 2 件起動する
- **THEN** worker はどちらも拒まず、排他の判定を行わない

