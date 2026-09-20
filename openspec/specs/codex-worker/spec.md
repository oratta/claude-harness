# codex-worker Specification

## Purpose
Codex の job を Claude Code のサブエージェントと同じ担い手として走らせるための実行基盤を定める。1 件の依頼につき専用の runtime CODEX_HOME と Git 管理外の専用一時領域を作り、role（implement / spec-write / review / spec-review / impl-review / decider）ごとに砂場と取得経路を決め、アカウントと作業ディレクトリの排他・認証帰属の照合・結果の受領（ack）までを台帳で管理する。

権限の範囲は「Claude のサブエージェントが自分で完了できる作業を、worker の中の担当者も自分で完了できる」ことを基準に決める。書く役は砂場なし（danger-full-access）で動き、Claude のサブエージェントと同じく親の環境で commit・push・GitHub 操作を自分で完了する。読む役は書き込み許可を持たず、取得経路だけを Claude 側の同じ役に揃える。書く役を砂場なしにした根拠と、揃えられなかった項目は実測の証跡とともに記録する。ここで扱うのは実行と隔離であって品質承認ではなく、job の完了は develop 側の仕様承認・テスト証拠・レビューゲートを代替しない。

アカウント単位の同時実行数の決め方は capability `codex-worker-concurrency` が定める。
## Requirements
### Requirement: workspace-write ジョブは専用の Git 管理外一時領域を使う
worker は implement/spec-write の job ごとに一つの新規専用ディレクトリを所有者一致・0700 で作り、その正規化済み絶対パスを App Server と子ツールの TMPDIR に渡さなければならない（MUST）。TMPDIR を見ない一時ファイル設定も同じ領域へ向けなければならない（MUST）。領域は cwd と Git 管理領域の外でなければならず（MUST）、同じ run の別 job と共有してはならない（MUST NOT）。

#### Scenario: Git 管理外を前提とするテストを実行する
- **WHEN** implement job が TMPDIR に一時ディレクトリを作る
- **THEN** 作成に成功し、その場所の git rev-parse --show-toplevel は失敗する。cwd 内への TMPDIR 上書きは不要である

#### Scenario: zsh の here-document を使うテストを実行する
- **WHEN** implement job の子プロセスが zsh の here-document を使う
- **THEN** 一時ファイルは専用領域の中に作られ、砂場に拒否されない。read-only role には TMPDIR も TMPPREFIX も渡らない

#### Scenario: 同じ run の次のジョブを開始する
- **WHEN** fresh job が受け付けられる
- **THEN** 前の job の一時領域を再利用せず、異なる専用領域を使う

### Requirement: 一時領域を別ジョブへ割り当てず確認済み終了後に片付ける
専用領域を別 job に割り当てたり再利用したりしてはならない（MUST NOT）。確認済み終了後には ack を待たず削除しなければならず（MUST）、削除失敗を隠してはならない（MUST NOT）。停止未確認の unknown は終了とみなさず、領域の所有を保持しなければならない（MUST）。

#### Scenario: 別ジョブに一時領域を割り当てる
- **WHEN** 同一 run 内を含む別 job に一時領域を割り当てる
- **THEN** 実行中・停止未確認・終了済みの job の領域を割り当てたり再利用したりせず、新規の専用領域を使う

#### Scenario: 確認済み終了の後を観測する
- **WHEN** 成功、失敗、確認済み取消、または開始前失敗の worker が cleanup を終える
- **THEN** 専用領域は存在せず、cwd・認証元・親領域・symlink 参照先は削除されない。削除できなければ失敗が記録される

#### Scenario: 終了を確認できない
- **WHEN** turn 開始後に切断または worker 喪失で unknown になる
- **THEN** 停止済みと推測せず既存の unknown 所有・再投入禁止を保ち、削除完了を主張しない

### Requirement: 実 Codex のテスト完走と拒否の証拠を残す
実装は fake 回帰試験に加え、実 Codex implement role で scripts/test.sh 全件の成功件数・総件数・exit code と対象 HEAD を記録しなければならない（MUST）。加えて、worker の中から 127.0.0.1 の待ち受けへの HTTP 到達、git commit と feature branch への git push、Draft PR 作成と記録先へのコメント、ローカルサーバーを立てる外部リポのテストスクリプトの完走を実測し、それぞれのコマンド・出力・exit code を記録しなければならない（MUST）。専用一時領域の 0700 と終了時削除も実環境で確認しなければならない（MUST）。砂場なしにした role では cwd の外への書き込みが OS に止められないことを境界プローブで確かめ、その結果を記録しなければならない（MUST）。CODEX-WORKER.md に実際の範囲と制約を反映しなければならない（MUST）。

#### Scenario: 実環境の受け入れ結果を記録する
- **WHEN** 対象 HEAD の scripts/test.sh と境界プローブが完了する
- **THEN** 全件成功・exit 0、各操作のコマンド/出力/exit code、砂場なしの role で cwd の外への書き込みが通ること、0700、終了後の領域不在を記録する。件数は過去の1465件を固定せず対象 HEAD の実測値を使う

#### Scenario: 代理実行なしの完走を記録する
- **WHEN** implement role の worker がループバックへの HTTP・git commit・git push・Draft PR 作成・記録先へのコメント・外部リポのテストスクリプトを自分で実行する
- **THEN** 各操作のコマンド・出力・exit code と対象 HEAD が記録され、本体が代理実行した操作は残っていない

### Requirement: 書く役は worker の中でネットワークと Git 操作を自分で完了できる
workspace-write role（implement / spec-write）は OS の砂場なしで実行しなければならない（MUST）: `thread/start` の sandbox は `danger-full-access`、turn の sandboxPolicy は `{'type':'dangerFullAccess'}` とする。approvalPolicy は never を維持しなければならない（MUST）。砂場なしの policy は書き込み範囲とネットワークの項目を持たないので、この role に writableRoots・excludeSlashTmp・excludeTmpdirEnvVar・networkAccess を渡してはならない（MUST NOT）。この role が Claude のサブエージェントと同じく親の環境で cwd の外へも書けることは、Claude 側に対応する隔離が無いことの帰結であり、指示と記録先の証拠で担保する。

job の専用一時領域の作成・TMPDIR / TMPPREFIX の差し替え・終了時の削除は維持しなければならない（MUST）。砂場が無くなったので OS による強制は伴わず、これは Codex 側だけにある差分として残る。

#### Scenario: ループバックの待ち受けへ繋ぐ
- **WHEN** implement job の子プロセスが 127.0.0.1 の待ち受けポートへ HTTP する
- **THEN** 応答を受け取れ、砂場もネットワーク遮断も拒否しない

#### Scenario: linked worktree で commit する
- **WHEN** implement job が cwd（linked worktree）で git switch -c と git commit を実行する
- **THEN** `.git` ファイルが指す Git 共通ディレクトリ配下（`worktrees/<この worktree>/` の HEAD.lock / index.lock を含む）への書き込みが拒否されず、branch 作成と commit が成立する

#### Scenario: 専用一時領域が残る
- **WHEN** implement job が開始され、子プロセスが TMPDIR を読む
- **THEN** worker が作った 0700 の専用領域を指しており、job の終了後にその領域は存在しない

### Requirement: 読む役は書き込みを増やさず取得経路だけ Claude 側の同じ役に揃える
read-only role（review / spec-review / impl-review / decider）は readOnly policy と approvalPolicy never を維持しなければならない（MUST）。read-only role に writableRoots を与えてはならない（MUST NOT）。networkAccess は Claude 側の対応する役が持つ取得手段に合わせなければならない（MUST）: 本体が汎用サブエージェントとして起こす役（review / spec-review / impl-review）は true、読み取り専用ツールだけを持ちシェルを持たない役（decider）は false とする。

#### Scenario: 独立レビューの役を実行する
- **WHEN** review / spec-review / impl-review job が開始される
- **THEN** readOnly policy と approvalPolicy never を保ったまま networkAccess=true で動き、書き込み許可は得ない

#### Scenario: 決める役を実行する
- **WHEN** decider job が開始される
- **THEN** readOnly policy・networkAccess=false・approvalPolicy never で動き、書き込み許可も取得経路も得ない

### Requirement: 子へ渡す環境変数は親を引き継ぎ、渡してはならない変数だけ落とす
worker は job の子プロセスへ、worker を起動した親プロセスの環境変数を引き継がなければならない（MUST）。ただし次は落とさなければならない（MUST）: worker が自分で決める値（CODEX_HOME・TMPDIR・TMPPREFIX）、Codex 自身が認証に読み登録済み account 以外の課金経路へ移し得る値、および子の git 操作を cwd 以外の checkout へ向け得る値（GIT_DIR・GIT_WORK_TREE・GIT_COMMON_DIR・GIT_INDEX_FILE）。read-only role には TMPDIR も TMPPREFIX も渡してはならない（MUST NOT）。引き継ぎが Codex 側の環境変数ポリシーで絞られる場合は、job ごとの runtime 設定でその絞りを解かなければならない（MUST）。worker 自身の git 呼び出し（依頼の検査・runtime の場所の算出・一時領域の場所の検査）は、親の環境をそのまま使って行ってはならず（MUST NOT）、固定 allowlist の最小環境で行わなければならない（MUST）。

#### Scenario: worker の中で GitHub を操作する
- **WHEN** implement job の子プロセスが gh コマンドで Draft PR を作り issue にコメントする
- **THEN** 認証が子に届いており、代理実行なしで完了する

#### Scenario: 親に別の認証変数がある
- **WHEN** 親環境に Codex 自身が認証に読む変数（API キー等）が設定された状態で job を開始する
- **THEN** その変数は子に現れず、account の identity 検査は登録済み account のまま通る

#### Scenario: 読む役に一時領域の指定が漏れない
- **WHEN** 親環境に TMPDIR / TMPPREFIX がある状態で read-only role の job を開始する
- **THEN** 子の環境にはどちらも現れない

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
worker は design の execution.version=1 形式で role/requested/effective/evidence を payload と別に保存し、公開 status/result と job_id/thread_id/turn_id に結び付けなければならない（MUST）。develop は同じ記録を run history に保持しなければならない（MUST）。要求値や model/list の default を実効値として補完してはならない（MUST NOT）。

#### Scenario: 実効設定を観測できる
- **WHEN** account 照合が成功し、RPC 応答または通知で model/effort を取得する
- **THEN** executor/account/model/effort の要求値と実効値、観測元を別々に記録し、turn 観測を thread 観測より優先する。差異があれば受け入れ不一致として残し自動再送しない

#### Scenario: 実効値または ID が取得できない
- **WHEN** API が effort を返さない、thread/turn 作成前に失敗する、または旧台帳行である
- **THEN** 不明な実効値/ID は null、観測元は unavailable とし、取得できた role/要求設定/ID は保持する。旧 payload/hash は変更しない

