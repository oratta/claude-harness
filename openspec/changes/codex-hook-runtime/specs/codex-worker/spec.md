## MODIFIED Requirements

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
