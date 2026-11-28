# Spec Delta

## MODIFIED Requirements

### Requirement: 一時領域は親の環境をそのまま引き継ぐ
worker は依頼のために子プロセス用の一時ディレクトリを新規作成してはならない（MUST NOT）。ただし 1 回の前景実行につき 1 つ作る runtime CODEX_HOME（認証情報への link、隔離設定と容量設定を持つ `config.toml`、選択済み account home からコピーした共通管理区画だけを持つ `AGENTS.md` を置く 0700 のディレクトリ）は、この禁止の対象外とする。App Server と子ツールの `TMPDIR` と `TMPPREFIX` は、role によらず worker を起動した親プロセスの値をそのまま引き継がなければならない（MUST）。親に値が無ければ子にも現れてはならず（MUST NOT）、worker が既定値を補ってはならない（MUST NOT）。runtime CODEX_HOME は、親に `TMPDIR` があればその配下に、無ければ実行環境の既定の一時領域に作らなければならない（MUST）。どちらの場合も、その置き場所を理由に子へ渡す `TMPDIR` / `TMPPREFIX` を作ったり書き換えたりしてはならない（MUST NOT）。同時に走る依頼の一時ファイルが同じ親の一時領域に混ざりうることと、依頼が残した一時ファイルの出どころを worker が記録しないことを明示しなければならない（MUST）。この追跡が必要になった場合は Codex 側だけに仕組みを戻してはならず（MUST NOT）、Claude のサブエージェント側にも同じ仕組みを入れて揃えなければならない（MUST）。

入力検査の守備範囲（共通区画の未配布・破損検査）: 入力元は既存の account 選択で決まった account home の `AGENTS.md` であり、worker は配布済みの管理区画を信頼する。AGENTS または管理区画の不在と、マーカーの欠落・逆順・重複を拾う。例えば、有効なマーカーを持つ区画内に意味的に矛盾するルールがあってもこの検査は通し、区画外に一時指示があっても通してコピー対象から除く。正本との鮮度比較や本文の意味検査はせず、コピー成功を Codex が読んで従った証拠としない。穴をすべて塞ぐことは完了条件にせず、未配布・破損時にターン開始前に止まり、有効な管理区画だけを継承できることを完了条件とする。

#### Scenario: 書く役の子が一時領域を見る
- **WHEN** implement の前景実行が開始され、子プロセスが `TMPDIR` と `TMPPREFIX` を読む
- **THEN** どちらも worker を起動した親プロセスの値と一致し、worker が作った子プロセス用の一時ディレクトリは存在しない（runtime CODEX_HOME は認証情報・隔離設定・容量設定・共通管理区画を置くためのものである）

#### Scenario: 親に一時領域の指定が無い
- **WHEN** 親環境に `TMPDIR` も `TMPPREFIX` も無く、選択済み account home に有効な共通管理区画がある状態で前景実行を開始する
- **THEN** 子の環境にもどちらも現れず、worker は一時領域の未指定を理由に開始を拒否せず、既定値を補って渡さない

#### Scenario: 親に一時領域の指定が無い状態で実行する
- **WHEN** 親環境に `TMPDIR` も `TMPPREFIX` も無い状態で前景実行を開始する
- **THEN** runtime CODEX_HOME は実行環境の既定の一時領域に作られ、子の環境には `TMPDIR` も `TMPPREFIX` も現れない

#### Scenario: 選択済み account home の共通区画だけを引き継ぐ
- **WHEN** 有効な管理区画と区画外の一時指示、および MCP 等の設定を持つ account home を選んで worker を起動する
- **THEN** fake app-server から観測する runtime の `AGENTS.md` はその管理区画だけと一致し、区画外の指示や親 config 全体は入らない
- **AND** `config.toml` は毎回 `project_doc_max_bytes = 131072` を生成し、認証リンクと既存の隔離設定を維持する

#### Scenario: 選択先に共通区画が未配布または破損している
- **WHEN** 選択済み account home の AGENTS が無い、管理区画が無い、またはマーカーが欠ける・逆順・重複している
- **THEN** worker は同期が必要だと分かるエラーを返し、ターン開始前に非0で止まり、共通ルール無しで依頼を開始しない
