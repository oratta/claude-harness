## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: 実 Codex のテスト完走と拒否の証拠を残す
実装は fake 回帰試験に加え、実 Codex implement role で scripts/test.sh 全件の成功件数・総件数・exit code と対象 HEAD を記録しなければならない（MUST）。加えて、worker の中から 127.0.0.1 の待ち受けへの HTTP 到達、git commit と feature branch への git push、Draft PR 作成と記録先へのコメント、ローカルサーバーを立てる外部リポのテストスクリプトの完走を実測し、それぞれのコマンド・出力・exit code を記録しなければならない（MUST）。専用一時領域の 0700 と終了時削除も実環境で確認しなければならない（MUST）。砂場なしにした role では cwd の外への書き込みが OS に止められないことを境界プローブで確かめ、その結果を記録しなければならない（MUST）。CODEX-WORKER.md に実際の範囲と制約を反映しなければならない（MUST）。

#### Scenario: 実環境の受け入れ結果を記録する
- **WHEN** 対象 HEAD の scripts/test.sh と境界プローブが完了する
- **THEN** 全件成功・exit 0、各操作のコマンド/出力/exit code、砂場なしの role で cwd の外への書き込みが通ること、0700、終了後の領域不在を記録する。件数は過去の1465件を固定せず対象 HEAD の実測値を使う

#### Scenario: 代理実行なしの完走を記録する
- **WHEN** implement role の worker がループバックへの HTTP・git commit・git push・Draft PR 作成・記録先へのコメント・外部リポのテストスクリプトを自分で実行する
- **THEN** 各操作のコマンド・出力・exit code と対象 HEAD が記録され、本体が代理実行した操作は残っていない

## REMOVED Requirements

### Requirement: 一時領域の追加許可以外の砂場を維持する
**Reason**: 「networkAccess は false を維持しなければならない」「read-only role の許可を拡大したり danger-full-access に変更したりしてはならない」という禁止が、Codex の worker だけ本体の代理実行を必要にしていた原因である。禁止を残したまま権限を揃えることはできないため、この要件を取り下げて置き換える。
**Migration**: 残すべき内容は置き換え先の要件へ引き継いでいる。approvalPolicy never と専用一時領域の維持は「書く役は worker の中でネットワークと Git 操作を自分で完了できる」へ、read-only role に書き込みを追加しないことは「読む役は書き込みを増やさず取得経路だけ Claude 側の同じ役に揃える」へ移した。writableRoots の限定・excludeSlashTmp / excludeTmpdirEnvVar=true・許可外への書き込みが拒否されることは引き継いでいない: 書く役は砂場なしで動くのでこれらの項目自体が無くなる（Claude のサブエージェントに対応する隔離が無く、linked worktree の `$GIT_DIR` が workspace-write では読み取り専用に保たれて commit が成立しないため）。
