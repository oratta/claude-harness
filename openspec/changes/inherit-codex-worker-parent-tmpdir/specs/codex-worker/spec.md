## ADDED Requirements

### Requirement: 書く役は親の一時領域をそのまま引き継ぐ
worker は workspace-write role（implement / spec-write）の job のために一時ディレクトリを新規作成してはならない（MUST NOT）。App Server と子ツールの `TMPDIR` と `TMPPREFIX` は、worker を起動した親プロセスの値をそのまま引き継がなければならない（MUST）。親に値が無ければ子にも現れてはならず（MUST NOT）、worker が既定値を補ってはならない（MUST NOT）。この結果として次の 2 つの性質が失われることを、仕様は明示しなければならない（MUST）: 同時に走る job の一時ファイルが同じ親の一時領域に混ざりうること、job が残した一時ファイルの出どころを worker が記録しないこと。この 2 つの追跡が必要になった場合は、Codex 側だけに仕組みを戻してはならず（MUST NOT）、Claude のサブエージェント側にも同じ仕組みを入れて揃えなければならない（MUST）。

#### Scenario: 書く役の子が一時領域を見る
- **WHEN** implement job が開始され、子プロセスが `TMPDIR` と `TMPPREFIX` を読む
- **THEN** どちらも worker を起動した親プロセスの値と一致し、worker が作った専用ディレクトリは存在しない

#### Scenario: 親に一時領域の指定が無い
- **WHEN** 親環境に `TMPDIR` も `TMPPREFIX` も無い状態で implement job を開始する
- **THEN** 子の環境にもどちらも現れず、worker は開始を拒否せず、既定値を補って渡さない

#### Scenario: 同じ run の次のジョブを開始する
- **WHEN** fresh job が受け付けられる
- **THEN** 前の job のために作られた領域も新しい領域も存在せず、両方の job が同じ親の一時領域を使う

#### Scenario: 素の mktemp を使う外部スクリプトを実行する
- **WHEN** implement job の子プロセスが `mktemp -d` で一時ディレクトリを作る外部スクリプトを実行する
- **THEN** 一時ディレクトリは親の一時領域の下に作られ、スクリプトは完走する

## REMOVED Requirements

### Requirement: workspace-write ジョブは専用の Git 管理外一時領域を使う
**Reason**: この要件が要ったのは、書く役の砂場（`workspace-write` ＋ `excludeSlashTmp` / `excludeTmpdirEnvVar`）が `/tmp` と呼び出し元 `TMPDIR` を塞いでいて、`writableRoots` に載る書ける一時領域を worker が用意しなければ子が一時ファイルを作れなかったためである。書く役は `danger-full-access` になり、砂場の項目そのものを渡さないことが仕様で決まったので（Requirement「書く役は worker の中でネットワークと Git 操作を自分で完了できる」）、塞ぐ主体が無くなった。専用領域は OS の強制を伴わない Codex 側だけの慣習として残っており、Claude のサブエージェントに対応物が無い。

**Migration**: Requirement「書く役は親の一時領域をそのまま引き継ぐ」に置き換える。`codex-worker.py` の `JobTmp` クラス、runtime への `job-tmp.json` の書き出し、`job_tmp_not_private` / `job_tmp_in_cwd` / `job_tmp_in_git` / `job_tmp_parent_not_directory` / `job_tmp_not_normalized` の `error_kind` を削除する。read-only role に `TMPDIR` / `TMPPREFIX` を渡さない扱いは Requirement「子へ渡す環境変数は親を引き継ぎ、渡してはならない変数だけ落とす」が引き続き定める。

### Requirement: 一時領域を別ジョブへ割り当てず確認済み終了後に片付ける
**Reason**: 片付けの対象（worker が作った専用領域）が無くなる。worker が作らない領域は別 job に割り当てようがなく、削除する責務も生じない。この Requirement の片付け条件（`turn_submitted` が偽か `execution_confirmed` が真のときだけ削除する）は、サーバーが `thread/start` / `turn/start` を id 付きエラーで拒否した job で領域を残す不具合を生んでいた（#333）。条件を直すのではなく、領域そのものを無くすことで発生源を消す。

**Migration**: `codex-worker.py` の `worker()` の `finally` にある cleanup 分岐と、`job_tmp_identity_changed` / `job_tmp_safe_cleanup_unavailable` / `job_tmp_cleanup_failed` の `error_kind` を削除する。停止未確認（unknown）の job について所有を保持する扱いは、一時領域ではなく作業ディレクトリと account slot の所有の話であり、台帳側の要件としてそのまま残る。

## MODIFIED Requirements

### Requirement: 書く役は worker の中でネットワークと Git 操作を自分で完了できる
workspace-write role（implement / spec-write）は OS の砂場なしで実行しなければならない（MUST）: `thread/start` の sandbox は `danger-full-access`、turn の sandboxPolicy は `{'type':'dangerFullAccess'}` とする。approvalPolicy は never を維持しなければならない（MUST）。砂場なしの policy は書き込み範囲とネットワークの項目を持たないので、この role に writableRoots・excludeSlashTmp・excludeTmpdirEnvVar・networkAccess を渡してはならない（MUST NOT）。この role が Claude のサブエージェントと同じく親の環境で cwd の外へも書けることは、Claude 側に対応する隔離が無いことの帰結であり、指示と記録先の証拠で担保する。

一時領域も同じ理由で親の環境を引き継ぐ。詳細は Requirement「書く役は親の一時領域をそのまま引き継ぐ」が定める。

#### Scenario: ループバックの待ち受けへ繋ぐ
- **WHEN** implement job の子プロセスが 127.0.0.1 の待ち受けポートへ HTTP する
- **THEN** 応答を受け取れ、砂場もネットワーク遮断も拒否しない

#### Scenario: linked worktree で commit する
- **WHEN** implement job が cwd（linked worktree）で git switch -c と git commit を実行する
- **THEN** `.git` ファイルが指す Git 共通ディレクトリ配下（`worktrees/<この worktree>/` の HEAD.lock / index.lock を含む）への書き込みが拒否されず、branch 作成と commit が成立する

### Requirement: 子へ渡す環境変数は親を引き継ぎ、渡してはならない変数だけ落とす
worker は job の子プロセスへ、worker を起動した親プロセスの環境変数を引き継がなければならない（MUST）。ただし次は落とさなければならない（MUST）: worker が自分で決める値（CODEX_HOME）、Codex 自身が認証に読み登録済み account 以外の課金経路へ移し得る値、および子の git 操作を cwd 以外の checkout へ向け得る値（GIT_DIR・GIT_WORK_TREE・GIT_COMMON_DIR・GIT_INDEX_FILE）。read-only role には TMPDIR も TMPPREFIX も渡してはならない（MUST NOT）: read-only role は書き込み許可を持たず一時ファイルを作れないので、一時領域の指定に意味が無く、渡さないことで「この役は書かない」が子の環境から読める。workspace-write role には TMPDIR も TMPPREFIX も親の値のまま渡さなければならない（MUST）。引き継ぎが Codex 側の環境変数ポリシーで絞られる場合は、job ごとの runtime 設定でその絞りを解かなければならない（MUST）。worker 自身の git 呼び出し（依頼の検査・runtime の場所の算出）は、親の環境をそのまま使って行ってはならず（MUST NOT）、固定 allowlist の最小環境で行わなければならない（MUST）。

#### Scenario: worker の中で GitHub を操作する
- **WHEN** implement job の子プロセスが gh コマンドで Draft PR を作り issue にコメントする
- **THEN** 認証が子に届いており、代理実行なしで完了する

#### Scenario: 親に別の認証変数がある
- **WHEN** 親環境に Codex 自身が認証に読む変数（API キー等）が設定された状態で job を開始する
- **THEN** その変数は子に現れず、account の identity 検査は登録済み account のまま通る

#### Scenario: 読む役に一時領域の指定が漏れない
- **WHEN** 親環境に TMPDIR / TMPPREFIX がある状態で read-only role の job を開始する
- **THEN** 子の環境にはどちらも現れない

#### Scenario: 書く役に一時領域の指定が届く
- **WHEN** 親環境に TMPDIR / TMPPREFIX がある状態で workspace-write role の job を開始する
- **THEN** 子の環境にはどちらも親と同じ値で現れる

#### Scenario: 親が Git のパスを指している
- **WHEN** 親環境に GIT_DIR / GIT_WORK_TREE / GIT_COMMON_DIR / GIT_INDEX_FILE が設定された状態で job を開始する
- **THEN** どれも子の環境に現れず、子の git 操作は cwd の linked worktree に向く。worker 自身の linked worktree 必須の検査もこれらの値で曲げられない

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
