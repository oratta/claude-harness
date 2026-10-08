# destructive-git-hook Specification

## Purpose

`rules/destructive-git-guard.md` の一覧にある破壊的 git 操作を、dev-workflow の PreToolUse hook が Bash の実行前に止め、主に確認を回す。判定の対象・守備範囲・モード別の ask / deny・逃げ道、ルール本文との分担、wt-clean のブランチ削除が止められたときの扱いを定義する。
## Requirements
### Requirement: 破壊的 git 操作を Bash の実行前に検出する

dev-workflow は PreToolUse の command hook `scripts/git-destructive-guard.sh` を持ち、`hooks/hooks.json` の PreToolUse 配列の末尾に `matcher: "Bash"` で登録しなければならない（MUST）。hooks.json の `command` は `"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh"` のように引用符で囲む（MUST）。対象の絞り込みは hooks.json の `if` で行わず、スクリプトが判定する（MUST。一覧を 1 か所に置き、bats で検査できるようにするため）。

スクリプトは payload を stdin から読み、`tool_input.command` に次のいずれかが含まれるとき、`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":<ask|deny>,"permissionDecisionReason":...}}` を stdout に出して exit 0 としなければならない（MUST）:

1. `git checkout` で `--` の後ろにパスがある、または引数が `.` だけ（作業の破棄）
2. `git restore`（`--staged` / `-S` だけを付けて `--worktree` / `-W` を付けないものを除く）
3. `git reset --hard`
4. `git clean` で `-f` / `--force`（`-fd` `-xdf` のようにまとめた短いオプションを含む）があり、`-n` / `--dry-run` が無い
5. `git push` の送り先が `main` / `master`（`main`、`+main`、`refs/heads/main`、`HEAD:main`、`<src>:main`、`:main`、`--delete main` を含む。master も同じ。remote 名は問わない）。`-n` / `--dry-run`（まとめた短いオプションを含む）があるものは除く（remote を変えないため）
6. `git push` に `--force` / `-f`（まとめた短いオプションを含む）/ `--force-with-lease[=...]` がある、または `+` で始まる refspec がある。`-n` / `--dry-run` があるものは除く
7. `git branch -D`、または `-d` / `--delete` と `-f` / `--force` の組み合わせ（`-df` を含む）
8. git のサブコマンドに `--no-verify` がある、または `git commit` の短いオプションに `n` がある。まとめた短いオプション（`-an`、`-anm x`）も含み、引数を取る短いオプション（`-m` `-F` `-c` `-C` `-t`）より後ろの文字は、その引数として扱って見ない（`-mn` はメッセージ `n` なので当たらない）
9. git のサブコマンドに `--no-gpg-sign` がある

判定は単純コマンドごとに行い、次の形の中も同じ判定にかけなければならない（MUST）: `&&` `||` `;` `|` `&` 改行で連結したコマンド、`$(...)` とバッククォートの中、`bash` / `sh` / `zsh` の `-c` の引数、`eval` の引数。単純コマンドの先頭の環境変数代入と `command` / `env` / `sudo` / `nohup` / `time` は読み飛ばし、git の大域オプション（`-C <path>`、`-c <k=v>`、`--git-dir`、`--work-tree`、`--namespace`、`--no-pager`、`-P` など）を読み飛ばしてサブコマンドを決めなければならない（MUST）。引用符の中の文字列や、git が単純コマンドの先頭に無いもの（`echo git reset --hard`）は対象にしてはならない（MUST NOT）。ヒアドキュメントの本文と、引用符の中の改行より後ろの行（commit メッセージや issue コメントの本文に書いた git の行）もコマンドとして読んではならない（MUST NOT）。ヒアドキュメントの終わりの行より後ろのコマンドは判定する。引数を取るオプション（`git push -o <値>`、`git commit --author <値>`、`git commit -m <値>` など）の次の字句は、そのオプションの値として読み飛ばし、送り先や短いオプションとして判定しない（MUST）。

守備範囲: この要件の目的は、ルールを読み飛ばした Claude が一覧の操作をそのまま打ったときに止めることで、セキュリティ境界ではない。受け取る入力は次の 2 つに限る。1 つ目は、Claude Code が PreToolUse で hook の stdin に渡す Bash 呼び出しの payload（`tool_name`、`tool_input.command`、`permission_mode`）で、`tool_input.command` はエージェント（本体やサブエージェント）が書く値である。2 つ目は、利用者が自分で設定する環境変数 `DEV_WORKFLOW_GIT_GUARD` と `DEV_WORKFLOW_GIT_GUARD_FORCE` である。拾いたい誤りは、上の 9 種のいずれかを、コマンド文字列にそのまま書いて実行しようとすることである（連結・コマンド置換・`bash -c`・git の大域オプションを挟んだ形を含む）。次の入力は通ることを許す: 変数や置換でサブコマンドや引数を組み立てた形（`git $SUB --hard`、`SUB=reset; git $SUB --hard`）／git の alias（`git config alias.nuke 'reset --hard'` を定義したうえでの `git nuke`）や git を包むシェル関数・エイリアス／スクリプトファイル・Makefile・npm scripts の中で実行される git（`bash cleanup.sh`、`make clean`）／ブランチ名を書かない `git push` や `git push origin HEAD`（現在のブランチが main でも当たらない）／push 済みの `git commit --amend` と `git rebase -i`（リポジトリの状態を見ないと判定できない）／引用符の中の文字列（`git commit -m "--no-verify を外す"`）と、git が単純コマンドの先頭に無いもの（`echo git reset --hard`）／ヒアドキュメントの本文と引用符の中の改行より後ろの行に書いた git（`git commit -F - <<EOF` の本文や複数行の `-m "..."` の 2 行目以降。シェルはこれをコマンドとして実行しない）／python3 が無い・stdin が JSON として読めない・payload がオブジェクトでない・`tool_name` が `Bash` でない・`tool_input.command` が文字列でないときは判定せずに通す（fail-open）／`DEV_WORKFLOW_GIT_GUARD=off` のときはすべて通す。これらの穴を見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。穴のうちルール本文で補うもの（push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）は、要件「ルール本文と hook の分担」で本文に書く。

#### Scenario: 対象 9 種が止まる

- **WHEN** `git checkout -- a.txt`、`git restore a.txt`、`git reset --hard`、`git clean -fd`、`git push origin main`、`git push --force origin feature-x`、`git branch -D feature-x`、`git commit --no-verify -m x`、`git commit --no-gpg-sign -m x` をそれぞれ `tool_input.command` に入れた Bash の payload を hook に渡す
- **THEN** どれも exit 0 で、`permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 連結・置換・大域オプション・まとめた短いオプションも止まる

- **WHEN** `cd x && git reset --hard`、`echo $(git reset --hard)`、`bash -c 'git push -f origin x'`、`git -C repo reset --hard`、`git -c core.x=y push origin HEAD:master`、`FOO=1 git clean -xdf`、`git commit -an`、`git commit -anm x` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 対象外のコマンドは何も出さない

- **WHEN** `git status`、`git push origin feature-x`、`git push -u origin feature/x`、`git push -n origin main`、`git push --dry-run --force origin feature-x`、`git checkout feature-x`、`git restore --staged a.txt`、`git clean -n`、`git branch -d feature-x`、`git commit -mn`、`git commit -m "--no-verify を外す"`、`echo git reset --hard`、`ls` を渡す
- **THEN** どれも exit 0 で、何も出力しない

#### Scenario: メッセージの本文はコマンドとして読まない

- **WHEN** ヒアドキュメントの本文に `git reset --hard` の行がある `git commit -m "$(cat <<'EOF' ... EOF)"`、複数行の `git commit -m "1 行目\ngit branch -D x を止める"`、`git push -o main origin feature-x` を渡す
- **THEN** どれも exit 0 で、何も出力しない

#### Scenario: ヒアドキュメントの後ろのコマンドは判定する

- **WHEN** `cat <<EOF > note.txt`、本文、`EOF` の行のあとに `git reset --hard` の行がある command を渡す
- **THEN** `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: hooks.json に登録されている

- **WHEN** `plugins/dev-workflow/hooks/hooks.json` の PreToolUse を読む
- **THEN** 配列の末尾が `matcher` が `Bash` のエントリで、`"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh"` の command hook を持ち、そのエントリに `if` が無い。配列の先頭は従来どおり `matcher` が `Agent` のエントリである

### Requirement: 確認画面が出るモードでだけ ask を返す

`permissionDecision` は payload の `permission_mode` で決めなければならない（MUST）: `default` / `acceptEdits` / `plan` / `bypassPermissions` は `ask`、それ以外（`dontAsk`・`auto`・未知の値・欠落）は `deny`。この対応は実機確認（design.md「`ask` と `deny` は payload の `permission_mode` で切り替える」の判定条件。対照実験を含む）で確定した: `-p` では `default` と `bypassPermissions` のどちらでも `ask` が実行を止め、対話セッションの `bypassPermissions` では `ask` で主が承認できる確認画面が出た。`ask` が `-p` で実行を止めない、または対話セッションで確認画面を出さないと分かったモードは、`deny` に戻さなければならない（MUST）。

環境変数 `DEV_WORKFLOW_GIT_GUARD_FORCE` が `ask` か `deny` のときは、`permission_mode` によらずその値を返さなければならない（MUST。実機確認と bats のための上書き）。

#### Scenario: 確認画面が出るモードでは ask

- **WHEN** `permission_mode` が `default` の payload、`permission_mode` が `bypassPermissions` の payload で `git reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `ask` になる

#### Scenario: auto と不明なモードでは deny

- **WHEN** `permission_mode` が `auto` の payload、`permission_mode` が `dontAsk` の payload、`permission_mode` が無い payload、`permission_mode` が `somethingNew` の payload で `git reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 上書きの環境変数が効く

- **WHEN** `DEV_WORKFLOW_GIT_GUARD_FORCE=ask` を付けて、`permission_mode` が `auto` の payload で `git reset --hard` を渡す
- **THEN** `permissionDecision` が `ask` になる

### Requirement: 拒否理由は承認の取り方を案内する

`permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（9 種のどれか。複数当たればすべて）／規範の正本が `rules/destructive-git-guard.md` であること／実行せず主に承認を求めること／承認されたら主が自分で実行すること（Claude Code の入力欄で `!` を付けるか、自分の端末で。`ask` のときは、確認画面が出ないセッション（`claude -p` など）ではそうすること）／`ask` のときは、確認画面を出していること／言い換えたコマンドで再実行して hook を避けないこと。`!` の入力は PreToolUse hook を通らない（対話セッションで `! git reset --hard` が止められずに実行されることを確かめた）ので、`!` の案内を残す。コマンドに付けて hook を通す目印（環境変数の前置など）を案内してはならない（MUST NOT）。

#### Scenario: deny の理由に承認の取り方が書かれている

- **WHEN** `permission_mode` が `auto` の payload で `git push origin main` を渡す
- **THEN** `permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: ask の理由に確認画面と、画面が出ないときの取り方が書かれている

- **WHEN** `permission_mode` が `bypassPermissions` の payload で `git push origin main` を渡す
- **THEN** `permissionDecision` が `ask` で、`permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、確認画面を出していること、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

### Requirement: 逃げ道と fail-open

`DEV_WORKFLOW_GIT_GUARD=off` のときは何も出さずに exit 0 としなければならない（MUST）。`tool_name` が `Bash` でない、`tool_input.command` が文字列でない、stdin が JSON として読めない、python3 が無いときは fail-open（exit 0・無出力）としなければならない（MUST）。`shlex` が引用符の不整合で字句に分けられないときは、空白で割った字句に同じ判定をかけなければならない（MUST。判定を諦めて素通りにしない）。

負荷を抑えるため、stdin の payload 全体に `git` の文字列も `\u00`（JSON のエスケープ表記。`git` をエスケープして書いた payload を取りこぼさないため）も無ければ python3 を起動せずに exit 0 としてよい（MAY。`context-tripwire.sh` の早期 exit と同じ形）。この早期 exit の誤りは、`git` を含む payload で余計に python3 を起動する向きにしか起きず、判定の結果は変わらない。外から観測できる違いが無いので、この早期 exit には Scenario を置かない。

#### Scenario: off で全許可

- **WHEN** `DEV_WORKFLOW_GIT_GUARD=off` を付けて `git reset --hard` を渡す
- **THEN** exit 0 で何も出力しない

#### Scenario: 読めない入力は素通り

- **WHEN** 空の stdin、JSON でない文字列、`tool_name` が `Edit` の payload を渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: 引用符が閉じていなくても判定する

- **WHEN** `git reset --hard && echo "oops` を渡す
- **THEN** `permissionDecision` が `ask` か `deny` の JSON が出る

### Requirement: ルール本文と hook の分担

`rules/destructive-git-guard.md` は既存の文を外さず（`always-on-injection-scope` の「縮約は削除ではなく移設」と、一覧・目印を本文に残す要件のため）、次の 2 点を足さなければならない（MUST）: 一覧の操作は dev-workflow の hook が実行前に止めること（止まったら言い換えて再実行せず主に聞く。拒否されたセッションでは承認後も主が自分で実行する）／hook はコマンド文字列しか見ないので、push 済みの `git commit --amend`、`git rebase -i`、ブランチ名を書かない `git push`、スクリプトファイル経由の git は止まらないこと。目印「例外なく事前承認」を含む文は変えてはならない（MUST NOT）。`rules/README.md` の該当行はこの分担に合わせて直さなければならない（MUST）。`DEV_WORKFLOW_GIT_GUARD_FORCE` はルール本文に書いてはならない（MUST NOT）。

#### Scenario: ルール本文に hook との分担がある

- **WHEN** `rules/destructive-git-guard.md` を読む
- **THEN** hook が一覧の操作を止めること、拒否されたら承認後も主が実行すること、hook で止まらないもの（push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）が書かれ、変更前の本文の文がすべて残り、`tests/always-on-injection-scope.bats` の目印がすべて残っている

#### Scenario: 上書きの環境変数がルールに無い

- **WHEN** `rules/destructive-git-guard.md` を `DEV_WORKFLOW_GIT_GUARD_FORCE` で検索する
- **THEN** 見つからない

### Requirement: wt-clean のブランチ削除が拒否されても黙って壊れない

worktree プラグインの `skills/wt-clean/SKILL.md` は、`git branch -D`（squash 済みの 🟢/🟡 の削除と 🔴 の破棄削除）がこの hook に止められたときの扱いを書かなければならない（MUST）。主の対話セッション（`cld` を含む）では確認画面が出て、主が承認すれば削除される。確認画面で断られたとき、または確認画面が出ないセッション（cron の `claude -p` など）で止まったときは: 言い換えて再実行せず、worktree の削除までで止めてそのブランチを `HELD` に入れ、完了レポートに主が打つコマンド（`git -C <メインリポ> branch -D <ブランチ>`）を載せる。cron への載せ方の節には、無人運用のジョブの環境に `DEV_WORKFLOW_GIT_GUARD=off` を入れること（入れなければ squash 済みブランチの削除が拒否され、完了レポートの保留に載る）を書かなければならない（MUST）。

#### Scenario: wt-clean に拒否時の扱いがある

- **WHEN** `plugins/worktree/skills/wt-clean/SKILL.md` を読む
- **THEN** `git branch -D` が拒否されたら `HELD` に入れて完了レポートに主が打つコマンドを載せること、cron の節に `DEV_WORKFLOW_GIT_GUARD=off` が書かれている

### Requirement: コマンド文字列をシェルと同じ単位で読む

`scripts/git-destructive-guard.sh` は、`tool_input.command` を単純コマンドと語に分けるとき、引用状態と「演算子か語か」の区別を保ち、次の構文をシェルと同じ単位で読まなければならない（MUST）。判定の 9 種・モード別の ask / deny・逃げ道・fail-open と、git のサブコマンドとオプションの解釈は、要件「破壊的 git 操作を Bash の実行前に検出する」ほかの既存要件のまま変えない。

1. `;` `&&` `||` `|` `&` `(` `)` と改行は、引用符の外にあるときだけ単純コマンドの区切りとする。引用符の中とバックスラッシュの後ろにある同じ文字は語の一部とする（MUST）
2. 引用符の外と二重引用符の中にあるバックスラッシュと改行の組（行継続）は取り除いて読む（MUST）。単一引用符の中では文字どおり残す
3. 引用符の外で語の境目にある `#` から行末までをコメントとして読み飛ばし、コメントの中の引用符で引用状態を変えない（MUST）。引用符の中の `#` と語の途中の `#` は語の一部とする
4. リダイレクト（`<` `>` `>>` `<>` `>|` `>&` `<&` `&>` `&>>`。直前に接した数字の fd を含む）とその対象の語は、単純コマンドを区切らずに取り除く（MUST）
5. ヒアドキュメント（`<<` / `<<-`）の区切り語は、引用除去後の語全体とする（MUST。`END-TAG` のようにハイフンを含む語も）。本文は区切り語と一致する行（`<<-` は先頭のタブを除いて一致する行）までで、本文の行はコマンドとして読まない。区切り語が引用されている（引用符かバックスラッシュを含む）ヒアドキュメントの本文からは、`$(...)` とバッククォートを置換として取り出さない（MUST NOT）。引用されていない本文の `$(...)` とバッククォートは、置換として中を判定する。要件「破壊的 git 操作を Bash の実行前に検出する」の「ヒアドキュメントの本文…もコマンドとして読んではならない（MUST NOT）」は、本文の行を単純コマンドとして読まないことを指す。引用されていない本文の `$(...)` とバッククォートはシェルが実行するので、この MUST NOT に当たらない
6. `<<<`（here-string）はヒアドキュメントとして扱わず、次の語を通常の語として読む（MUST）
7. `$(...)` の終わりは、置換の中の引用符・入れ子の置換を追って、引用符の外にある対応する `)` で決める（MUST。`"$(printf ')'; git reset --hard)"` の `')'` を終わりにしない）
8. 引用符の中に改行を含む語も 1 つの語として残す（MUST）。`bash` / `sh` / `zsh` の `-c` の引数と `eval` の引数は、改行を含んでいても既存要件どおりコマンドとして判定し、その中の改行は連結として扱う。要件「破壊的 git 操作を Bash の実行前に検出する」の「引用符の中の改行より後ろの行もコマンドとして読んではならない（MUST NOT）」は、`-c` / `eval` の引数にならない位置の引用文字列（`git commit -m` の値、`echo` の引数など）に適用する
9. 引用符が閉じていない入力は、空白と改行で割った字句に同じ判定をかける（MUST。判定を諦めて素通りにしない）。要件「逃げ道と fail-open」の「`shlex` が引用符の不整合で字句に分けられないとき」は、この字句読みが引用符の閉じていない入力を受けたときと読む

守備範囲: この要件は、要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲を広げるものではない。受け取る入力は同じで、Claude Code が PreToolUse で渡す Bash 呼び出しの payload の `tool_input.command`（エージェントが書く値）である。拾いたい誤りは 2 つある。1 つ目は、対象の 9 種を、改行・コメント・行継続・途中のリダイレクト・引用された演算子・ヒアドキュメントや here-string を挟んで書いた形を取りこぼすこと。2 つ目は、引用された演算子や引用されたヒアドキュメントの本文の置換のように、シェルが実行しない文字列を git の操作と読んで止めること。次の入力は通ることを許す: bash の文法のうち上に挙げていない形（算術式 `$((...))` の中身、`${...}` の中の置換、プロセス置換 `<(...)` の中身、`case` の `)` など）／予約語や記号が単純コマンドの先頭に来る形（`for f in *; do git checkout -- "$f"; done` の `do`、`if true; then git reset --hard; fi` の `then`、`{ git reset --hard; }`、`! git reset --hard`。変更の前も後も取りこぼす）。上に挙げていない形を読み違えて止める側に倒れる場合は、止まってよい（ask / deny が出るだけで、確認画面か主の実行で通せる）。これらの穴を見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。

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

