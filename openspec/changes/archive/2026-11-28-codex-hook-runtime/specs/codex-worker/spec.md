## MODIFIED Requirements

### Requirement: 子へ渡す環境変数は親を引き継ぎ、渡してはならない変数だけ落とす
worker は依頼の子プロセスへ、worker を起動した親プロセスの環境変数を引き継がなければならない（MUST）。ただし worker が自分で決める `CODEX_HOME`、Codex 自身が認証に読み指定された CODEX_HOME 以外の課金経路へ移し得る値、および子の git 操作を cwd 以外の checkout へ向け得る `GIT_DIR`・`GIT_WORK_TREE`・`GIT_COMMON_DIR`・`GIT_INDEX_FILE` は落とさなければならない（MUST）。追加の例外として、`DEV_WORKFLOW_CODEX_GUARD_DIR`・`DEV_WORKFLOW_CODEX_GIT_GUARD`・`DEV_WORKFLOW_CODEX_SECRET_GUARD`・`DEV_WORKFLOW_CODEX_ASK_GUARD` は親の指定を引き継がず、配布 helper の実体から解決した repo の adapter ディレクトリと git/secret/ask の各依存 script の絶対パスへ固定しなければならない（MUST）。この4変数は親に無い場合も同じ固定値を設定しなければならない（MUST）。`DEV_WORKFLOW_UNATTENDED` と既存 off 設定はこの例外に含めず、親の値と意味を保持しなければならない（MUST）。TMPDIR と TMPPREFIX は落としてはならず（MUST NOT）、role によらず親の値のまま子へ渡さなければならない（MUST）。引き継ぎが Codex 側の環境変数ポリシーで絞られる場合は、依頼ごとの runtime 設定でその絞りを解かなければならない（MUST）。worker 自身の git 呼び出しは親の環境をそのまま使って行ってはならず（MUST NOT）、固定 allowlist の最小環境で行わなければならない（MUST）。

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

#### Scenario: guard のパスだけを配布元へ固定する
- **WHEN** 親に4つの guard パス変数が無い場合と別の配置を指す値がある場合に、それぞれ書込役と読取役を起動する
- **THEN** 両方の子に `DEV_WORKFLOW_CODEX_GUARD_DIR` と git/secret/ask の3変数が配布元の絶対パスで設定され、親の指定先は使われず、無人の印・既存 off 設定・TMPDIR/TMPPREFIX とその他の継承対象は親のまま届く

### Requirement: 一時領域は親の環境をそのまま引き継ぐ
worker は依頼のために子プロセス用の一時ディレクトリを新規作成してはならない（MUST NOT）。ただし 1 回の前景実行につき 1 つ作る runtime CODEX_HOME（認証情報への link・最小 `config.toml` と、既存 Codex 拒否判定の配布・信頼に必要な hook 設定を置く 0700 のディレクトリ）は、この禁止の対象外とする。App Server と子ツールの `TMPDIR` と `TMPPREFIX` は、role によらず worker を起動した親プロセスの値をそのまま引き継がなければならない（MUST）。親に値が無ければ子にも現れてはならず（MUST NOT）、worker が既定値を補ってはならない（MUST NOT）。runtime CODEX_HOME は、親に `TMPDIR` があればその配下に、無ければ実行環境の既定の一時領域に作らなければならない（MUST）。どちらの場合も、その置き場所を理由に子へ渡す `TMPDIR` / `TMPPREFIX` を作ったり書き換えたりしてはならない（MUST NOT）。同時に走る依頼の一時ファイルが同じ親の一時領域に混ざりうることと、依頼が残した一時ファイルの出どころを worker が記録しないことを明示しなければならない（MUST）。この追跡が必要になった場合は Codex 側だけに仕組みを戻してはならず（MUST NOT）、Claude のサブエージェント側にも同じ仕組みを入れて揃えなければならない（MUST）。

#### Scenario: 書く役の子が一時領域を見る
- **WHEN** implement の前景実行が開始され、子プロセスが `TMPDIR` と `TMPPREFIX` を読む
- **THEN** どちらも worker を起動した親プロセスの値と一致し、worker が作った子プロセス用の一時ディレクトリは存在しない（runtime CODEX_HOME は認証情報を置くためのものである）

#### Scenario: 親に一時領域の指定が無い
- **WHEN** 親環境に `TMPDIR` も `TMPPREFIX` も無い状態で前景実行を開始する
- **THEN** 子の環境にもどちらも現れず、worker は開始を拒否せず、既定値を補って渡さない

#### Scenario: 親に一時領域の指定が無い状態で実行する
- **WHEN** 親環境に `TMPDIR` が無い状態で前景実行を開始する
- **THEN** runtime CODEX_HOME は実行環境の既定の一時領域に作られ、子の環境には `TMPDIR` も `TMPPREFIX` も現れない

#### Scenario: hook 設定を含む runtime を片付ける
- **WHEN** hook を配布した前景実行が成功・失敗・中断で終了する
- **THEN** runtime 内の hook 設定も既存の終了処理で除去され、指定された認証元の hooks/config/requirements と ~/.claude は変更されず、子の TMPDIR/TMPPREFIX の扱いも変わらない
