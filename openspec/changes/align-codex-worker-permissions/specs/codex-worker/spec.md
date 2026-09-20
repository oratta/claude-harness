## ADDED Requirements

### Requirement: 書く役は worker の中でネットワークと Git 操作を自分で完了できる
workspace-write role（implement / spec-write）の turn では networkAccess を true にしなければならない（MUST）。writableRoots は cwd・当該 job の専用一時領域・cwd の Git 共通ディレクトリ（`git rev-parse --path-format=absolute --git-common-dir` の値）の 3 つだけでなければならず（MUST）、これ以外の場所を追加してはならない（MUST NOT）。excludeSlashTmp と excludeTmpdirEnvVar は true、approvalPolicy は never を維持しなければならない（MUST）。

#### Scenario: ループバックの待ち受けへ繋ぐ
- **WHEN** implement job の子プロセスが 127.0.0.1 の待ち受けポートへ HTTP する
- **THEN** 応答を受け取れ、砂場もネットワーク遮断も拒否しない

#### Scenario: linked worktree で commit する
- **WHEN** implement job が cwd（linked worktree）で git commit を実行する
- **THEN** `.git` ファイルが指す Git 共通ディレクトリ配下への書き込みが許可され、commit が成立する

#### Scenario: 許可外へ書き込もうとする
- **WHEN** Codex ツールが cwd・専用領域・Git 共通ディレクトリの外である /tmp/<一意名> および呼び出し元 TMPDIR/<一意名> に書き込む
- **THEN** どちらも砂場で拒否され、許可された 3 か所への同じ操作だけが成功する

### Requirement: 読む役は書き込みを増やさず取得経路だけ Claude 側の同じ役に揃える
read-only role（review / spec-review / impl-review / decider）は readOnly policy と approvalPolicy never を維持しなければならない（MUST）。read-only role に writableRoots を与えてはならない（MUST NOT）。networkAccess は Claude 側の対応する役が持つ取得手段に合わせなければならない（MUST）: 本体が汎用サブエージェントとして起こす役（review / spec-review / impl-review）は true、読み取り専用ツールだけを持ちシェルを持たない役（decider）は false とする。

#### Scenario: 独立レビューの役を実行する
- **WHEN** review / spec-review / impl-review job が開始される
- **THEN** readOnly policy と approvalPolicy never を保ったまま networkAccess=true で動き、書き込み許可は得ない

#### Scenario: 決める役を実行する
- **WHEN** decider job が開始される
- **THEN** readOnly policy・networkAccess=false・approvalPolicy never で動き、書き込み許可も取得経路も得ない

### Requirement: 子へ渡す環境変数は親を引き継ぎ、渡してはならない変数だけ落とす
worker は job の子プロセスへ、worker を起動した親プロセスの環境変数を引き継がなければならない（MUST）。ただし次は落とさなければならない（MUST）: worker が自分で決める値（CODEX_HOME・TMPDIR・TMPPREFIX）と、Codex 自身が認証に読み登録済み account 以外の課金経路へ移し得る値。read-only role には TMPDIR も TMPPREFIX も渡してはならない（MUST NOT）。引き継ぎが Codex 側の環境変数ポリシーで絞られる場合は、job ごとの runtime 設定でその絞りを解かなければならない（MUST）。

#### Scenario: worker の中で GitHub を操作する
- **WHEN** implement job の子プロセスが gh コマンドで Draft PR を作り issue にコメントする
- **THEN** 認証が子に届いており、代理実行なしで完了する

#### Scenario: 親に別の認証変数がある
- **WHEN** 親環境に Codex 自身が認証に読む変数（API キー等）が設定された状態で job を開始する
- **THEN** その変数は子に現れず、account の identity 検査は登録済み account のまま通る

#### Scenario: 読む役に一時領域の指定が漏れない
- **WHEN** 親環境に TMPDIR / TMPPREFIX がある状態で read-only role の job を開始する
- **THEN** 子の環境にはどちらも現れない

### Requirement: 砂場を緩める判断は段階順で、各段の採否を実測の証跡とともに記録する
実装は緩める段を順に試さなければならない（MUST）。第 1 段は workspace-write + networkAccess true + Git 共通ディレクトリの追加、第 2 段はその role だけを砂場なし（danger-full-access）にすることである。第 2 段は workspace-write role にしか適用できず、read-only role を砂場なしにしてはならない（MUST NOT）。段の判断は workspace-write role ごとに独立に行わなければならず（MUST）、ある role の不足を理由に他の role を緩めてはならない（MUST NOT）。

第 2 段へ進める条件は、第 1 段で完了できなかった操作について（a）失敗したコマンド・出力・exit code が記録されており（MUST）、（b）その失敗が砂場の拒否によるものであると確認できていること（MUST）の両方である。環境変数が子シェルに届いていないことによる失敗、テストスクリプト自体の不具合、一時的な通信失敗は（b）に該当しない（MUST NOT）。原因の切り分けは、環境変数の引き継ぎが効いていることを確認したうえで行わなければならない（MUST）。実測の証跡なしに砂場なしを既定にしてはならない（MUST NOT）。

#### Scenario: 第 1 段で足りる
- **WHEN** 第 1 段の設定で受け入れ対象の操作がすべて完了する
- **THEN** その role は第 1 段のままとし、砂場なしへ落とさない

#### Scenario: 第 1 段で足りない
- **WHEN** 環境変数の引き継ぎが効いていることを確認済みの workspace-write role で完了できない操作があり、失敗したコマンド・出力・exit code と、その失敗が砂場の拒否によるものだと確認した根拠が記録されている
- **THEN** その role だけを砂場なしにしてよく、緩めた role と理由が記録に残る

#### Scenario: 失敗の原因が砂場ではない
- **WHEN** 第 1 段の失敗が、環境変数が子シェルに届いていないこと・テストスクリプト自体の不具合・一時的な通信失敗によるものである
- **THEN** 砂場なしへ進まず、その原因を先に直してから第 1 段で再実測する

#### Scenario: 証跡がないまま緩める
- **WHEN** 第 1 段の失敗の記録、または砂場の拒否であることの確認が無い状態で砂場なしの設定を入れようとする
- **THEN** その変更は受け入れられない

#### Scenario: 読む役を砂場なしにしようとする
- **WHEN** read-only role で完了できない操作を理由に、その role を砂場なしにしようとする
- **THEN** その変更は受け入れられない（read-only role は readOnly policy を維持する）

### Requirement: 揃えられなかった項目を項目ごとに記録する
Claude のサブエージェントと同じ作業を worker の中で完了できない項目が残った場合、項目ごとに「試したこと・失敗の出力・揃えられない理由」を変更の記録先と CODEX-WORKER.md に残さなければならない（MUST）。揃っていない項目を、揃ったものとして docs や references に書いてはならない（MUST NOT）。

#### Scenario: 一部の操作が揃わないまま終える
- **WHEN** 第 2 段まで試しても完了できない操作が残る
- **THEN** その項目ごとに試したこと・失敗の出力・揃えられない理由が記録され、本体の代理実行が必要な操作としてその項目だけが docs に残る

## MODIFIED Requirements

### Requirement: 実 Codex のテスト完走と拒否の証拠を残す
実装は fake 回帰試験に加え、実 Codex implement role で scripts/test.sh 全件の成功件数・総件数・exit code と対象 HEAD を記録しなければならない（MUST）。加えて、worker の中から 127.0.0.1 の待ち受けへの HTTP 到達、git commit と feature branch への git push、Draft PR 作成と記録先へのコメント、ローカルサーバーを立てる外部リポのテストスクリプトの完走を実測し、それぞれのコマンド・出力・exit code を記録しなければならない（MUST）。書き込み拒否プローブ、終了時削除も実環境で確認し、CODEX-WORKER.md に実際の範囲と制約を反映しなければならない（MUST）。

#### Scenario: 実環境の受け入れ結果を記録する
- **WHEN** 対象 HEAD の scripts/test.sh と境界プローブが完了する
- **THEN** 全件成功・exit 0、許可先での成功、許可外での拒否とそのコマンド/出力/exit code、0700、終了後の領域不在を記録する。件数は過去の1465件を固定せず対象 HEAD の実測値を使う

#### Scenario: 代理実行なしの完走を記録する
- **WHEN** implement role の worker がループバックへの HTTP・git commit・git push・Draft PR 作成・記録先へのコメント・外部リポのテストスクリプトを自分で実行する
- **THEN** 各操作のコマンド・出力・exit code と対象 HEAD が記録され、本体が代理実行した操作は残っていない

## REMOVED Requirements

### Requirement: 一時領域の追加許可以外の砂場を維持する
**Reason**: 「networkAccess は false を維持しなければならない」「read-only role の許可を拡大したり danger-full-access に変更したりしてはならない」という禁止が、Codex の worker だけ本体の代理実行を必要にしていた原因である。禁止を残したまま権限を揃えることはできないため、この要件を取り下げて置き換える。
**Migration**: 残すべき内容は置き換え先の要件へ引き継いでいる。writableRoots の限定・excludeSlashTmp / excludeTmpdirEnvVar=true・approvalPolicy never・許可外への書き込みが拒否されることは「書く役は worker の中でネットワークと Git 操作を自分で完了できる」へ、read-only role に書き込みを追加しないことは「読む役は書き込みを増やさず取得経路だけ Claude 側の同じ役に揃える」へ移した。
