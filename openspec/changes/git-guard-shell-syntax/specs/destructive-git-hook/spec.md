## ADDED Requirements

### Requirement: コマンド文字列をシェルと同じ単位で読む

`scripts/git-destructive-guard.sh` は、`tool_input.command` を単純コマンドと語に分けるとき、引用状態と「演算子か語か」の区別を保ち、次の構文をシェルと同じ単位で読まなければならない（MUST）。判定の 9 種・モード別の ask / deny・逃げ道・fail-open と、git のサブコマンドとオプションの解釈は、要件「破壊的 git 操作を Bash の実行前に検出する」ほかの既存要件のまま変えない。

1. `;` `&&` `||` `|` `&` `(` `)` と改行は、引用符の外にあるときだけ単純コマンドの区切りとする。引用符の中とバックスラッシュの後ろにある同じ文字は語の一部とする（MUST）
2. 引用符の外と二重引用符の中にあるバックスラッシュと改行の組（行継続）は取り除いて読む（MUST）。単一引用符の中では文字どおり残す
3. 引用符の外で語の境目にある `#` から行末までをコメントとして読み飛ばし、コメントの中の引用符で引用状態を変えない（MUST）。引用符の中の `#` と語の途中の `#` は語の一部とする
4. リダイレクト（`<` `>` `>>` `<>` `>|` `>&` `<&` `&>` `&>>`。直前に接した数字の fd を含む）とその対象の語は、単純コマンドを区切らずに取り除く（MUST）
5. ヒアドキュメント（`<<` / `<<-`）の区切り語は、引用除去後の語全体とする（MUST。`END-TAG` のようにハイフンを含む語も）。本文は区切り語と一致する行（`<<-` は先頭のタブを除いて一致する行）までで、本文の行はコマンドとして読まない。区切り語が引用されている（引用符かバックスラッシュを含む）ヒアドキュメントの本文からは、`$(...)` とバッククォートを置換として取り出さない（MUST NOT）。引用されていない本文の `$(...)` とバッククォートは、置換として中を判定する
6. `<<<`（here-string）はヒアドキュメントとして扱わず、次の語を通常の語として読む（MUST）
7. `$(...)` の終わりは、置換の中の引用符・入れ子の置換を追って、引用符の外にある対応する `)` で決める（MUST。`"$(printf ')'; git reset --hard)"` の `')'` を終わりにしない）
8. 引用符の中に改行を含む語も 1 つの語として残す（MUST）。`bash` / `sh` / `zsh` の `-c` の引数と `eval` の引数は、改行を含んでいても既存要件どおりコマンドとして判定し、その中の改行は連結として扱う。要件「破壊的 git 操作を Bash の実行前に検出する」の「引用符の中の改行より後ろの行もコマンドとして読んではならない（MUST NOT）」は、`-c` / `eval` の引数にならない位置の引用文字列（`git commit -m` の値、`echo` の引数など）に適用する

この要件は守備範囲を広げるものではない。bash の文法のうち上に挙げていない形（算術式 `$((...))` の中身、`${...}` の中の置換、プロセス置換 `<(...)` の中身、`case` の `)` など）の取りこぼしは、既存要件の守備範囲どおり通ることを許し、塞ぎ切ることを完了条件にしない。

#### Scenario: 改行を含む引数の中の git を判定する

- **WHEN** `bash -c '<改行>git reset --hard<改行>'`、`git -c core.x='first<改行>second' reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 複数行のメッセージは引き続き読まない

- **WHEN** `git commit -m "1 行目<改行>git branch -D x を止める"`、`echo "a<改行>git reset --hard"` を渡す
- **THEN** どれも exit 0 で、何も出力しない

#### Scenario: 置換の中の引用された閉じ括弧で置換を終わらせない

- **WHEN** `echo "$(printf ')'; git reset --hard)"`、`echo "$(echo "$(git reset --hard)")"` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: コメントの中の引用符で後ろの行を見失わない

- **WHEN** `# It's cleanup<改行>git reset --hard`、`ls # it's fine<改行>git reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: コメントの中の git と引用符の中の # は判定しない

- **WHEN** `ls # git reset --hard`、`echo "#"; git status` を渡す
- **THEN** どれも exit 0 で、何も出力しない

#### Scenario: リダイレクトで単純コマンドを割らない

- **WHEN** `git reset >/dev/null --hard`、`git reset 2>&1 --hard`、`>/dev/null git reset --hard`、`git reset --hard >/dev/null` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 行継続をつないで読む

- **WHEN** `git \<改行>reset --hard`、`git reset \<改行>  --hard` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 単一引用符の中のバックスラッシュと改行は行継続にしない

- **WHEN** `echo 'a \<改行>git reset --hard'` を渡す
- **THEN** exit 0 で、何も出力しない

#### Scenario: 引用された演算子で単純コマンドを区切らない

- **WHEN** `echo ';' git reset --hard`、`echo "|" git reset --hard`、`echo \& git reset --hard` を渡す
- **THEN** どれも exit 0 で、何も出力しない

#### Scenario: 引用されていない演算子では引き続き区切る

- **WHEN** `echo x; git reset --hard`、`echo x | git reset --hard`、`echo x & git reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 区切り語の全体と here-string を区別する

- **WHEN** `cat <<END-TAG<改行>body<改行>END-TAG<改行>git reset --hard`、`cat <<-'EOF'<改行><タブ>body<改行><タブ>EOF<改行>git reset --hard`、`cat <<< EOF<改行>git reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 引用されたヒアドキュメントの本文の置換は判定しない

- **WHEN** `cat <<'EOF'<改行>$(git reset --hard)<改行>EOF`、`` cat <<"EOF"<改行>`git reset --hard`<改行>EOF `` を渡す
- **THEN** どれも exit 0 で、何も出力しない

#### Scenario: 引用されていないヒアドキュメントの本文の置換は判定する

- **WHEN** `cat <<EOF<改行>$(git reset --hard)<改行>EOF` を渡す
- **THEN** `permissionDecision` が `ask` か `deny` の JSON が出る
