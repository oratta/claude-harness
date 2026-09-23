# codex-worker Specification

## Purpose
Codex の job を Claude Code のサブエージェントと同じ担い手として走らせるための実行基盤を定める。1 件の依頼につき専用の runtime CODEX_HOME を作り、role（implement / spec-write / review / spec-review / impl-review / decider）ごとに砂場と取得経路を決め、認証帰属の照合を行い、1 回の前景実行の結果を標準出力の 1 行 JSON で返す。永続的な台帳・所有権・受領は持たない。

権限の範囲は「Claude のサブエージェントが自分で完了できる作業を、worker の中の担当者も自分で完了できる」ことを基準に決める。書く役は砂場なし（danger-full-access）で動き、Claude のサブエージェントと同じく親の環境で commit・push・GitHub 操作を自分で完了する。読む役は書き込み許可を持たず、取得経路だけを Claude 側の同じ役に揃える。書く役を砂場なしにした根拠と、揃えられなかった項目は実測の証跡とともに記録する。ここで扱うのは実行と隔離であって品質承認ではなく、job の完了は develop 側の仕様承認・テスト証拠・レビューゲートを代替しない。
## Requirements
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
worker は依頼を受け取ったとき、optional effort の非空文字列、許可キー、定義済み role、`auth.json` を含む CODEX_HOME を静的に検証しなければならない（MUST）。モデル名と effort の対応は initialize 後かつ thread/start 前に、指定された CODEX_HOME で起動した account の model/list を使って検証しなければならない（MUST）。系統名を要求したときは、解決後のモデルの supportedReasoningEfforts に対して effort を検証しなければならない（MUST）。固定 enum で対応を推測してはならない（MUST NOT）。

#### Scenario: 静的に不正な request を渡す
- **WHEN** effort が空/非文字列、role が未定義、未知フィールドがある、または CODEX_HOME が利用できない
- **THEN** App Server に turn を送る前に拒否し、同じ形の失敗 JSON と非ゼロ終了コードを返す

#### Scenario: モデル固有の effort が非対応である
- **WHEN** model/list が luna に ultra を広告していないのに luna/ultra を要求する
- **THEN** 非対応 effort を `error_kind` に入れ、thread/start と turn/start を一度も呼ばず、非ゼロで終了する

#### Scenario: 系統名の effort を解決後のモデルで検証する
- **WHEN** model/list が `gpt-5.6-sol` には high を広告し、`gpt-6-sol` には high を広告しない状態で sol/high を要求する
- **THEN** 解決後の `gpt-6-sol` に対して検証し、`unsupported_model_effort` で止まり、旧版の `gpt-5.6-sol` に倒さない

#### Scenario: 一覧に無いモデルまたは一覧取得失敗
- **WHEN** 完全なモデル ID または系統名を要求し、includeHidden=true の全ページに該当する一意なモデルがない（完全 ID は model フィールドの完全一致、系統名は解決規則による）、一覧が不正、または model/list の取得に失敗する
- **THEN** 開始前に原因を返し、既定モデルや別の実行先へ fallback しない。一覧の不正は `model_list_invalid`、取得失敗は `model_list_unavailable` で、系統名でも完全 ID と同じ理由になる

#### Scenario: 広告された新しい effort または hidden モデル
- **WHEN** 明示指定した完全なモデル ID が一覧にあり、その supportedReasoningEfforts の reasoningEffort に要求値が含まれる
- **THEN** 固定 enum や hidden 属性を理由に拒否せず、指定モデルと effort を使用する

### Requirement: effort は turn start のみに渡す
worker は model を thread/start と turn/start の双方へ渡し、明示された effort を turn/start の effort にのみ渡さなければならない（MUST）。系統名を要求したときに両 RPC へ渡す model は解決後のモデル ID とし、request の payload の model は書き換えてはならない（MUST NOT）。effort が省略された依頼では送信時も省略し、payload を補完してはならない（MUST NOT）。指定 CODEX_HOME の identity、role ごとの sandbox・networkAccess、writableRoots を持たない readOnly policy を維持しなければならない（MUST）。explore / summarize は本体が汎用サブエージェントとして起こす read-only role なので、review 系と同じく networkAccess=true としなければならない（MUST）。

#### Scenario: 明示 effort を送信する
- **WHEN** model=sol の request で sol/high の検証が成功し、sol が gpt-6-sol に解決される
- **THEN** 両 RPC の model は gpt-6-sol、turn/start.effort は high となり、thread/start の effort や config に effort を追加しない

#### Scenario: effort がない request
- **WHEN** model のみを指定した依頼を実行する
- **THEN** model/list で model を照合または解決し、turn/start に effort を載せず、要求値を補完しない

### Requirement: 要求設定と実効設定を ID と共に公開する
worker は execution.version=1 形式で role/requested/effective/evidence を payload と別に保持し、thread_id と turn_id に結び付けなければならない（MUST）。execution には model の解決結果 `model_resolution: {requested, kind, resolved, source}` も入れなければならない（MUST）。`kind` は `family`（系統名）か `exact`（完全なモデル ID）、`resolved` は model/list で選んだモデル ID、`source` は `model/list` とし、解決の前に失敗したときや解決できなかったときは `resolved` を null、`source` を `unavailable` としなければならない（MUST）。公開先は標準出力の 1 行 JSON だけとし、worker が結果をファイルや永続 store に保存してはならない（MUST NOT）。要求値、解決結果、model/list の default を実効値として補完してはならない（MUST NOT）。

#### Scenario: 実効設定を観測できる
- **WHEN** account 照合が成功し、RPC 応答または通知で model/effort を取得する
- **THEN** executor/account/model/effort の要求値と実効値、観測元を別々に JSON に入れ、turn 観測を thread 観測より優先する。worker は差異を理由に失敗扱い・自動再送をせず、差異の判定は JSON を受け取った本体が行う

#### Scenario: 系統名の要求値と解決後の ID を両方公開する
- **WHEN** model=sol の request が gpt-6-sol に解決されて実行される
- **THEN** `execution.requested.model` は `sol`、`execution.model_resolution` は `{requested: "sol", kind: "family", resolved: "gpt-6-sol", source: "model/list"}` となり、`execution.effective.model` は RPC 応答で観測した値だけを持つ

#### Scenario: 実効値または ID が取得できない
- **WHEN** API が effort を返さない、または thread/turn 作成前に失敗する
- **THEN** 不明な実効値/ID は null、観測元は unavailable とし、取得できた role/要求設定/ID だけを返す。解決の前に失敗した場合は `model_resolution.resolved` も null とする

#### Scenario: 前景経路で実効設定を公開する
- **WHEN** 前景実行が完走または失敗して結果を返す
- **THEN** role/requested/effective/evidence/model_resolution と取得できた ID が標準出力の JSON に入り、ファイルへ保存されない

### Requirement: 前景実行はアカウントを依頼された CODEX_HOME で固定する
前景実行は、依頼に載せられた CODEX_HOME を実行アカウントとして固定しなければならない（MUST）。account 名を CODEX_HOME へ解決するために永続 registry を読んではならない（MUST NOT）。依頼の account 名は結果の記録に使うラベルであり、照合の材料にしてはならない（MUST NOT）。照合は、app-server が返した実行中アカウントが、渡された CODEX_HOME の認証情報と一致することで行わなければならない（MUST）。前景実行は 1 件ごとに runtime CODEX_HOME を作り、認証情報への link が実行中に差し替えられていないことを確認し、終了時にその link を外して片付けなければならない（MUST）。runtime CODEX_HOME は、親に `TMPDIR` があればその配下、無ければ実行環境の既定の一時領域にある、所有者だけが読み書きできるディレクトリに置かなければならず（MUST）、app-server とその子に渡す `TMPDIR` / `TMPPREFIX` を変えてはならない（MUST NOT）。結果の `effective.account` には app-server が返した実行中アカウントを入れなければならず（MUST）、依頼の account 名をそのまま写してはならない（MUST NOT）。依頼の account 名は `requested.account` にだけ残さなければならない（MUST）。どの CODEX_HOME を使うかは呼び出し側の責任であることを仕様は明示しなければならない（MUST）。

#### Scenario: 渡された認証情報と実行中アカウントが食い違う
- **WHEN** app-server が返した実行中アカウントが、依頼の CODEX_HOME の認証情報と一致しない
- **THEN** ターンを開始せず、理由を示して終了し、別のアカウントへ切り替えない

#### Scenario: 実行中に認証情報の link が差し替えられる
- **WHEN** ターンの待機中に runtime の認証情報への link が別の場所を指すようになる
- **THEN** ターンの中断を要求し、その理由を結果に残す

#### Scenario: 対応表が指す CODEX_HOME が要求名と食い違う
- **WHEN** 依頼の account 名が意図したものとは別の CODEX_HOME が依頼に載り、そのまま完走する
- **THEN** 結果の実効アカウントには app-server が返した実行中アカウントが入り、依頼の account 名は要求側にだけ残る

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

### Requirement: 前景実行だけを入口にする
worker は依頼ファイルを受け取って 1 回のターンを実行し終了する `run` だけを公開実行入口として持たなければならない（MUST）。この入口は app-server への接続、指定 CODEX_HOME によるアカウント固定、model と effort の検証、role ごとの砂場の決定、ターン開始前の利用枠確認、ターンの完走を 1 プロセス内で行わなければならない（MUST）。job や account の永続 store、ownership、run directory を作成・参照してはならず（MUST NOT）、それらのパスを指定する引数や lifecycle subcommand を受け取ってはならない（MUST NOT）。

#### Scenario: 永続状態を作らずに完走する
- **WHEN** 偽の app-server を使って `run` の依頼を完走させる
- **THEN** SQLite、run JSON、ownership、job directory のいずれも作られず、コマンドは 1 行 JSON を出して終了する

#### Scenario: 廃止済み lifecycle command を指定する
- **WHEN** `register`、`submit`、`status`、`result`、`cancel`、`ack`、`send`、`reap` のいずれかを指定する
- **THEN** 引数解析で拒否し、永続状態を作らず、`run` へ暗黙変換しない

### Requirement: 系統名は委譲の直前に model/list から最新版へ解決する
worker は request の model が正規表現 `^[a-z]+$` に一致するとき、それを系統名として扱い、initialize と account 照合の後かつ thread/start の前に、指定された CODEX_HOME で起動した account の model/list（`includeHidden: true`、全ページ）から実際のモデル ID に解決しなければならない（MUST）。候補は `hidden` が `true` でなく、`model` フィールドが `^gpt-<版>-<系統名>$`（`<版>` は `[0-9]+(\.[0-9]+)*`）に完全一致する entry とし、版を数値の並びとして末尾の 0 を除いて比べ、最も新しい 1 件を選ばなければならない（MUST）。候補が 0 件なら `model_not_available`、最も新しい版の entry が 2 件以上なら `model_not_unique` で止まり、thread/start と turn/start を一度も呼ばず、別モデル・別 account・別 provider に fallback してはならない（MUST NOT）。系統名の固定の列挙を持ってはならない（MUST NOT）。model が `^[a-z]+$` に一致しないときは完全なモデル ID として、従来どおり `model` フィールドの完全一致で照合しなければならない（MUST）。経路（系統名・完全 ID）を問わず、model/list の全ページに `hidden` が真偽値以外の entry が 1 件でもあれば、その entry が照合対象かどうかにかかわらず `model_list_invalid` で止まらなければならない（MUST）。`hidden` キーが無い entry は表示扱いとする。系統名の経路でも、候補 0 件・非一意以外の失敗（一覧が不正・一覧の取得に失敗）は完全 ID と同じ `model_list_invalid` / `model_list_unavailable` で止まらなければならない（MUST）。

守備範囲: `model` は、組み込み役割表・外部 profile-file・旧形式 `--model` のいずれかから resolver がそのまま写した値で、利用者自身が書く設定である（外部からの信頼できない入力ではない）。この要件が拾いたい誤りは、要求した系統に表示モデルが無いこと、最新版が 1 件に決まらないこと、一覧が不正または取得できないことの 3 つで、いずれも別モデルに倒さず止める。通ることを許す入力は、`sol` / `luna` / `astra`、列挙していない系統名（`terra` 等）、版を固定した完全 ID（`gpt-5.6-sol`）、hidden のモデルの完全 ID 指定（`gpt-reserve`）である。守らないものは次のとおり: 系統名の打ち間違いと提供されていない系統は区別せず、どちらも同じ `model_not_available` とする。OpenAI が `gpt-<版>-<系統名>` の形を変えた場合は、利用者が完全 ID を書くか規則を直して対処する。英小文字だけの完全 ID が将来現れた場合に系統名と誤分類されることは受け入れる。新しく見つかった照合の穴を塞ぎ切ることを、この要件の完了条件にしない。

#### Scenario: 現在の一覧で三つの系統名を解決する
- **WHEN** model/list が `gpt-6-astra`、`gpt-6-sol`、`gpt-6-luna`、`gpt-5.6-sol`、`gpt-5.6-terra`、`gpt-5.6-luna`、`gpt-5.5` を表示し、`gpt-reserve` と `codex-auto-review` を hidden で返すフィクスチャで、model=sol、luna、astra の request をそれぞれ実行する
- **THEN** それぞれ `gpt-6-sol`、`gpt-6-luna`、`gpt-6-astra` に解決され、thread/start と turn/start の model には解決後の ID が渡る

#### Scenario: 該当する系統のモデルが無い
- **WHEN** model/list に `gpt-<版>-sol` の形の表示モデルが 1 件も無い（hidden の `gpt-7-sol` だけがある場合を含む）状態で model=sol を要求する
- **THEN** `error_kind` を `model_not_available` とし、thread/start と turn/start を呼ばず、非ゼロで終了する

#### Scenario: 最新版が 1 件に決まらない
- **WHEN** model/list に `gpt-6-sol` が 2 件ある、または `gpt-6-sol` と `gpt-6.0-sol` が並存する状態で model=sol を要求する
- **THEN** `error_kind` を `model_not_unique` とし、thread/start と turn/start を呼ばず、非ゼロで終了する

#### Scenario: 版を数値として比べる
- **WHEN** model/list に `gpt-5.9-sol` と `gpt-5.10-sol` があり、`gpt-6-sol-mini` もある状態で model=sol を要求する
- **THEN** `gpt-5.10-sol` に解決し、後ろに語が続く `gpt-6-sol-mini` は候補にしない

#### Scenario: 完全なモデル ID は従来どおり照合する
- **WHEN** model=gpt-5.6-sol、または hidden の `gpt-reserve` を要求する
- **THEN** 系統名の解決を行わず、`model` フィールドの完全一致で 1 件を選び、hidden でも受理する

