# destructive-git-hook Specification

## Purpose

`rules/destructive-git-guard.md` の一覧にある破壊的 git 操作を、dev-workflow の PreToolUse hook が Bash の実行前に止め、主に確認を回す。判定の対象・守備範囲・モード別の ask / deny・逃げ道、ルール本文との分担、wt-clean のブランチ削除が止められたときの扱いを定義する。

## Requirements

### Requirement: 破壊的 git 操作を Bash の実行前に検出する

dev-workflow は PreToolUse の command hook `scripts/git-destructive-guard.sh` を持ち、`hooks/hooks.json` の PreToolUse 配列の末尾に `matcher: "Bash"` で登録しなければならない（MUST）。hooks.json の `command` は `"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh"` のように引用符で囲む（MUST）。対象の絞り込みは hooks.json の `if` で行わず、スクリプトが判定する（MUST。一覧を 1 か所に置き、bats で検査できるようにするため）。

スクリプトは payload を stdin から読み、`tool_input.command` に次のいずれかが含まれるとき、`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":<ask|deny|allow>,"permissionDecisionReason":...}}` を stdout に出して exit 0 としなければならない（MUST。`allow` は、要件「子への拒否を記録し、親が 1 回だけ通せるようにする」の条件を満たす子の呼び出しに限る）:

1. `git checkout` で `--` の後ろにパスがある、または引数が `.` だけ（作業の破棄）
2. `git restore`（`--staged` / `-S` だけを付けて `--worktree` / `-W` を付けないものを除く）
3. `git reset --hard`
4. `git clean` で `-f` / `--force`（`-fd` `-xdf` のようにまとめた短いオプションを含む）があり、dry-run でない（dry-run かどうかの決め方は下の「dry-run の決め方」）
5. `git push` の送り先が `main` / `master`（`main`、`+main`、`refs/heads/main`、`HEAD:main`、`<src>:main`、`:main`、`--delete main` を含む。master も同じ。remote 名は問わない）。dry-run のものは除く（remote を変えないため）
6. `git push` に `--force` / `-f`（まとめた短いオプションを含む）/ `--force-with-lease[=...]` がある、または `+` で始まる refspec がある。dry-run のものは除く
7. `git branch -D`、または `-d` / `--delete` と `-f` / `--force` の組み合わせ（`-df` を含む）
8. git のサブコマンドに `--no-verify` がある、または `git commit` の短いオプションに `n` がある。まとめた短いオプション（`-an`、`-anm x`）も含み、引数を取る短いオプション（`-m` `-F` `-c` `-C` `-t`）より後ろの文字は、その引数として扱って見ない（`-mn` はメッセージ `n` なので当たらない）
9. git のサブコマンドに `--no-gpg-sign` がある

dry-run の決め方: `git push` / `git clean` の引数をオプションとして左から読み、最後に効いているもので決めなければならない（MUST）。`-n`（まとめた短いオプションを含む）と `--dry-run` は dry-run にし、`--no-dry-run` と、`--no-d` 以上の長さでその先頭と一致する省略形（`--no-dry` など）は dry-run を打ち消す。`git push -n --no-dry-run origin main` は dry-run でなく、`git push --no-dry-run -n origin main` は dry-run である。

判定は単純コマンドごとに行い、次の形の中も同じ判定にかけなければならない（MUST）: `&&` `||` `;` `|` `&` 改行で連結したコマンド、`$(...)` とバッククォートの中、`bash` / `sh` / `zsh` の `-c` の引数、`eval` の引数。単純コマンドの先頭の環境変数代入と `command` / `env` / `sudo` / `nohup` / `time` は読み飛ばし（`env` の値を取るオプション `-u` / `--unset`、`-C` / `--chdir`、`-P`、`-a` / `--argv0` は値ごと読み飛ばす。`env -u FOO git reset --hard` の `FOO` はコマンド名ではない。`-S` / `--split-string` は値を取るものとして読まない。後ろの字句がコマンドとして実行されるため）、git の大域オプション（`-C <path>`、`-c <k=v>`、`--git-dir`、`--work-tree`、`--namespace`、`--no-pager`、`-P` など）を読み飛ばしてサブコマンドを決めなければならない（MUST）。引用符の中の文字列や、git が単純コマンドの先頭に無いもの（`echo git reset --hard`）は対象にしてはならない（MUST NOT）。ヒアドキュメントの本文と、引用符の中の改行より後ろの行（commit メッセージや issue コメントの本文に書いた git の行）もコマンドとして読んではならない（MUST NOT）。ヒアドキュメントの終わりの行より後ろのコマンドは判定する。引数を取るオプション（`git push -o <値>`、`git commit --author <値>`、`git commit -m <値>` など）の次の字句は、そのオプションの値として読み飛ばし、送り先や短いオプションとして判定しない（MUST）。値を取る長いオプションは、一覧の中で一意に決まる省略形（`git push --push-opt <値>`、`git clean --excl <値>`）も同じオプションとして読む（MUST）。`--end-of-options` は `--` と同じく、それより後ろの字句をすべてオプションでない引数として読む（MUST。`git push --end-of-options -n origin main` の `-n` は dry-run ではなく送り先のリモート名で、`main` は refspec）。

守備範囲: この要件の目的は、ルールを読み飛ばした Claude が一覧の操作をそのまま打ったときに止めることで、セキュリティ境界ではない。受け取る入力は次の 2 つに限る。1 つ目は、Claude Code が PreToolUse で hook の stdin に渡す Bash 呼び出しの payload（`tool_name`、`tool_input.command`、`permission_mode`）で、`tool_input.command` はエージェント（本体やサブエージェント）が書く値である。2 つ目は、利用者が自分で設定する環境変数 `DEV_WORKFLOW_GIT_GUARD` と `DEV_WORKFLOW_GIT_GUARD_FORCE`、およびセッションを起動する側が付ける `DEV_WORKFLOW_UNATTENDED`（要件「確認画面が出るモードでだけ ask を返す」の守備範囲で足す）である。拾いたい誤りは、上の 9 種のいずれかを、コマンド文字列にそのまま書いて実行しようとすることである（連結・コマンド置換・`bash -c`・git の大域オプションを挟んだ形を含む）。次の入力は通ることを許す: 変数や置換でサブコマンドや引数を組み立てた形（`git $SUB --hard`、`SUB=reset; git $SUB --hard`）／git の alias（`git config alias.nuke 'reset --hard'` を定義したうえでの `git nuke`）や git を包むシェル関数・エイリアス／スクリプトファイル・Makefile・npm scripts の中で実行される git（`bash cleanup.sh`、`make clean`）／ブランチ名を書かない `git push` や `git push origin HEAD`（現在のブランチが main でも当たらない）／push 済みの `git commit --amend` と `git rebase -i`（リポジトリの状態を見ないと判定できない）／引用符の中の文字列（`git commit -m "--no-verify を外す"`）と、git が単純コマンドの先頭に無いもの（`echo git reset --hard`）／ヒアドキュメントの本文と引用符の中の改行より後ろの行に書いた git（`git commit -F - <<EOF` の本文や複数行の `-m "..."` の 2 行目以降。シェルはこれをコマンドとして実行しない）／python3 が無い・stdin が JSON として読めない・payload がオブジェクトでない・`tool_name` が `Bash` でない・`tool_input.command` が文字列でないときは判定せずに通す（fail-open）／`DEV_WORKFLOW_GIT_GUARD=off` のときはすべて通す／値を取らないオプションの省略形（`git reset --har`、`git clean --forc`）／`env` 以外の wrapper の値を取るオプション（`sudo -u root git reset --hard`）と、1 字句にクォートした `env -S 'git reset --hard'`／`--no-dry-run` 以外の打ち消し（`--no-force`、`--verify` など）は読まない（`git push --force --no-force origin feature-x` のように、止めすぎる向きに出るものを含む）。これらの穴を見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。穴のうちルール本文で補うもの（push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）は、要件「ルール本文と hook の分担」で本文に書く。

#### Scenario: 対象 9 種が止まる

- **WHEN** `git checkout -- a.txt`、`git restore a.txt`、`git reset --hard`、`git clean -fd`、`git push origin main`、`git push --force origin feature-x`、`git branch -D feature-x`、`git commit --no-verify -m x`、`git commit --no-gpg-sign -m x` をそれぞれ `tool_input.command` に入れた Bash の payload を hook に渡す
- **THEN** どれも exit 0 で、`permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 連結・置換・大域オプション・まとめた短いオプションも止まる

- **WHEN** `cd x && git reset --hard`、`echo $(git reset --hard)`、`bash -c 'git push -f origin x'`、`git -C repo reset --hard`、`git -c core.x=y push origin HEAD:master`、`FOO=1 git clean -xdf`、`git commit -an`、`git commit -anm x` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: dry-run の打ち消し・長いオプションの省略形・--end-of-options・env のオプションを git と同じに読む

- **WHEN** `env -u FOO git reset --hard`、`git push -n --no-dry-run origin main`、`git clean -n --no-dry-run -f`、`git push --dry-run --no-dry-run --force origin main`、`git push -n --no-dry origin main`、`git push --push-opt -n origin main`、`git clean --excl -n -f`、`git push --end-of-options -n origin main`、`env -S git reset --hard`、`git commit -n --no-dry-run -m x` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 本当の dry-run と env を挟んだ無害なコマンドは止めない

- **WHEN** `git push --no-dry-run -n origin main`、`git clean -f --no-dry-run -n`、`git push --dry-run --no-dry-run --dry-run --force origin main`、`git push --push-option=x -n origin main`、`env -u FOO git status`、`env -i -u FOO git push origin feature-x` を渡す
- **THEN** どれも exit 0 で、何も出力しない

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

payload の `agent_id` が空でない文字列のとき（サブエージェントから呼ばれたとき。`context-tripwire.sh` と同じ判定）は、`permission_mode` にも `DEV_WORKFLOW_GIT_GUARD_FORCE` にもよらず `deny` を返さなければならない（MUST）。ただし、要件「子への拒否を記録し、親が 1 回だけ通せるようにする」の一致する許可があるときは `allow` を返す。親は子の確認画面に応答できず、子が止まっていることも分からないので、子に `ask` を返してはならない（MUST NOT）。`agent_id` が無い・文字列でない・空のときは、以下の規則で決める。

環境変数 `DEV_WORKFLOW_GIT_GUARD_NO_ASK` は、画面を見ている人もチャンネルも無いセッション向けに、git ガードだけに効く印である。起動する側が hook のプロセスに引き継がれる環境に設定する。前後の空白を除いて未設定・空・`0` は印なし、それ以外は印ありとして扱わなければならない（MUST）。印のある主の呼び出しは、`permission_mode` と `DEV_WORKFLOW_GIT_GUARD_FORCE` によらず `deny` としなければならない（MUST）。子の呼び出しは上の段落の規則を維持し、一致する許可があれば `allow`、無ければ `deny` とし、主は子の許可を使ってはならない（MUST NOT）。両方の印がある主への理由文は NO_ASK の案内を優先しなければならない（MUST）。この印を develop の実行モードの決定に使ってはならない（MUST NOT）。

NO_ASK の印が無いとき、環境変数 `DEV_WORKFLOW_UNATTENDED` は「このセッションの画面を見ている人がいない」という印で、セッションを起動する側（flatmate の住人の `boot.sh` など）が claude の環境に入れる。値の前後の空白を除いたものが空（未設定を含む）か `0` なら印なし、それ以外の値はすべて印ありとして扱わなければならない（MUST。付け損ねた値で確認画面に戻らず、止めすぎる向きにだけ外れるため）。印のあるセッションでは、主の呼び出しにも `permission_mode` にも `DEV_WORKFLOW_GIT_GUARD_FORCE` にもよらず `deny` を返さなければならない（MUST）。画面を見ている人がいないので、確認画面は誰にも押されず、セッションが止まったままになるため。印のあるセッションでも、子の呼び出しは上の段落（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」の条件を満たす許可があるときは `allow`、無ければ `deny`）で決まり、要件「子への拒否を記録し、親が 1 回だけ通せるようにする」の許可は印のあるセッションの主の呼び出しには効かない。印の無いセッションでは、以下の `permission_mode` と `DEV_WORKFLOW_GIT_GUARD_FORCE` の規則で決める。

`permissionDecision` は payload の `permission_mode` で決めなければならない（MUST）: `default` / `acceptEdits` / `plan` / `bypassPermissions` は `ask`、それ以外（`dontAsk`・`auto`・未知の値・欠落）は `deny`。この対応は実機確認（design.md「`ask` と `deny` は payload の `permission_mode` で切り替える」の判定条件。対照実験を含む）で確定した: `-p` では `default` と `bypassPermissions` のどちらでも `ask` が実行を止め、対話セッションの `bypassPermissions` では `ask` で主が承認できる確認画面が出た。`ask` が `-p` で実行を止めない、または対話セッションで確認画面を出さないと分かったモードは、`deny` に戻さなければならない（MUST）。

環境変数 `DEV_WORKFLOW_GIT_GUARD_FORCE` が `ask` か `deny` のときは、`permission_mode` によらずその値を返さなければならない（MUST。実機確認と bats のための上書き）。ただし子の呼び出しと、いずれかの印のあるセッションの主の呼び出しには効かない（上の段落が先に決める）。

以下、`agent_id` が無い・空・文字列でない呼び出しを「主の呼び出し」、`agent_id` が空でない文字列の呼び出しを「子の呼び出し」と呼ぶ。`DEV_WORKFLOW_UNATTENDED` の印があるセッションを「無人のセッション」、どちらの印も無いセッションを「対話のセッション」と呼ぶ。NO_ASK の印がある主の呼び出しには「拒否理由は承認の取り方を案内する」の NO_ASK 用の規則を適用する。以下の既存 Scenario は、NO_ASK を指定しない限り、その印が無い状態とする。

守備範囲: 子と主の見分けは、要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲の入力に、Claude Code が PreToolUse で hook の stdin に渡す payload の `agent_id`（Claude Code が子の呼び出しに付ける値で、エージェントが書く `tool_input.command` とは別のフィールド）を足す。拾いたい誤りは、子が破壊的 git 操作を打ったときに主の確認画面が出て、親が応答も検知もできず、主が画面を見るまでワークフロー全体が止まることである。次の入力は通すこと（または今までどおり確認画面を出すこと）を許す: Claude Code の版や起動経路によって子の payload に `agent_id` が入らない呼び出し（主の呼び出しとして扱われ、`permission_mode` と `DEV_WORKFLOW_GIT_GUARD_FORCE` の規則に従う）／`DEV_WORKFLOW_GIT_GUARD=off` のセッションで子が打つもの（すべて通る）／要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲で通ることを許した形を子が打つもの（変数で組み立てた形やスクリプトファイル経由など）。止めすぎる向きでは、主が子に破壊的操作を任せた場合も、親が許可を書けるコマンド（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）以外は子では実行できず、親か主が打つことになるが、これは許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

守備範囲: 無人のセッションの見分けは、守備範囲の入力に hook のプロセスの環境変数 `DEV_WORKFLOW_UNATTENDED`（セッションを起動する側が付ける値で、payload とは別）を足す。拾いたい誤りは、画面を見ている人のいない `bypassPermissions` などの対話 TUI（flatmate の住人）で確認画面が出て、誰も押さずにセッションが止まり、セッション cron とチャンネルの受信も止まることである。次の入力は今までどおり確認画面を出すことを許す: 起動する側が印を付けなかったセッション（住人が tmux などで別に起動したセッションが、起動した側の環境を引き継がなかったものを含む）。止めすぎる向きでは、印のあるセッションをオーナーが Remote Control や tmux の画面で見ていても確認画面が出ず、オーナーが自分で実行することになるが、これは許す。これらの穴（印が届かないセッション）を塞ぎ切ることは、この要件の完了条件にしない。起動したセッションへの印の引き継ぎは #1123・#1126 で扱う。

守備範囲: hook の環境変数 `DEV_WORKFLOW_GIT_GUARD_NO_ASK` を入力に追加する。拾う誤りは、起動側がこの印を付けた別セッションで `ask` を返し、親が検知できない確認画面で止まることである。印を付け忘れたセッション、既存の検出範囲外のコマンド、`DEV_WORKFLOW_GIT_GUARD=off` と fail-open は既存のままとする。印の伝播を推測したり、すべての起動経路に強制したりして穴を塞ぐことは完了条件にしない。

#### Scenario: 確認画面が出るモードでは ask

- **WHEN** `agent_id` の無い payload で、`permission_mode` が `default` のもの、`permission_mode` が `bypassPermissions` のものに `git reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `ask` になる

#### Scenario: auto と不明なモードでは deny

- **WHEN** `agent_id` の無い payload で、`permission_mode` が `auto` のもの、`dontAsk` のもの、`permission_mode` が無いもの、`somethingNew` のものに `git reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 上書きの環境変数が効く

- **WHEN** `DEV_WORKFLOW_GIT_GUARD_FORCE=ask` を付けて、`agent_id` の無い、`permission_mode` が `auto` の payload で `git reset --hard` を渡す
- **THEN** `permissionDecision` が `ask` になる

#### Scenario: 子から呼ばれたら確認画面が出るモードでも deny

- **WHEN** 許可の無い空の `TMPDIR` で、`agent_id` が空でない文字列で `permission_mode` が `default` の payload、同じく `bypassPermissions` の payload に `git checkout -- a` を渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 子には上書きの環境変数が効かない

- **WHEN** `DEV_WORKFLOW_GIT_GUARD_FORCE=ask` を付けて、`agent_id` が空でない文字列で `permission_mode` が `default` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` になる

#### Scenario: agent_id が空なら主の呼び出しとして扱う

- **WHEN** `agent_id` が空文字の payload、`agent_id` が数値の payload で、`permission_mode` が `default` のものに `git checkout -- a` を渡す
- **THEN** どれも `permissionDecision` が `ask` になる

#### Scenario: 無人のセッションでは対象 9 種が deny

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` を付けて、`agent_id` の無い、`permission_mode` が `bypassPermissions` の payload で、要件「破壊的 git 操作を Bash の実行前に検出する」の Scenario「対象 9 種が止まる」のコマンドをそれぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 無人のセッションでは確認画面が出るモードでも上書きの環境変数でも deny

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` を付けて、`agent_id` の無い payload で `permission_mode` が `default` のもの、`acceptEdits` のもの、`plan` のものに `git reset --hard` を渡す。さらに `DEV_WORKFLOW_UNATTENDED=1` と `DEV_WORKFLOW_GIT_GUARD_FORCE=ask` を付けて、`permission_mode` が `bypassPermissions` の payload に `git reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 印の値の読み方

- **WHEN** `agent_id` の無い、`permission_mode` が `bypassPermissions` の payload に `git reset --hard` を、`DEV_WORKFLOW_UNATTENDED` を付けずに、空文字で、`0` で、` 0 ` で、`true` で、`yes` でそれぞれ渡す
- **THEN** 付けないもの・空文字・`0`・` 0 ` は `ask`、`true`・`yes` は `deny` になる

#### Scenario: 対話のセッションでは今までどおり ask

- **WHEN** `DEV_WORKFLOW_UNATTENDED` を付けずに、`agent_id` の無い、`permission_mode` が `bypassPermissions` の payload で、Scenario「対象 9 種が止まる」のコマンドをそれぞれ渡す
- **THEN** どれも `permissionDecision` が `ask` になる

#### Scenario: 無人のセッションの子は子の規則で決まる

- **WHEN** 許可の無い空の `TMPDIR` で、`DEV_WORKFLOW_UNATTENDED=1` を付けて、`agent_id` が空でない文字列で `permission_mode` が `bypassPermissions` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` は子への理由（「打ち直さず」と親に返す案内を含み、「チャンネル」を含まない）になる

#### Scenario: 無人のセッションでも主の呼び出しには許可が効かない

- **WHEN** 要件「子への拒否を記録し、親が 1 回だけ通せるようにする」の手順で子の呼び出しへの許可を書いたあと、`DEV_WORKFLOW_UNATTENDED=1` を付けて、同じ `session_id`・`cwd`・コマンドで `agent_id` の無い、`permission_mode` が `bypassPermissions` の payload を渡し、続けて元の子の payload を渡す
- **THEN** 主の呼び出しは `permissionDecision` が `deny` で許可のファイルが残り、子の呼び出しは `permissionDecision` が `allow` になる

#### Scenario: off は無人のセッションでも全許可

- **WHEN** `DEV_WORKFLOW_GIT_GUARD=off` と `DEV_WORKFLOW_UNATTENDED=1` を付けて `git reset --hard` を渡す
- **THEN** exit 0 で何も出力しない

#### Scenario: NO_ASK の主は対象 9 種をモードと FORCE によらず拒否する

- **WHEN** `DEV_WORKFLOW_GIT_GUARD_NO_ASK=1` で、主の payload に対象 9 種のコマンドを、`default` と `bypassPermissions` でそれぞれ渡す。`DEV_WORKFLOW_GIT_GUARD_FORCE=ask` も付けて同じ組を渡す
- **THEN** すべて exit 0 の JSON で `permissionDecision` が `deny` になる
- **AND** `acceptEdits`・`plan`・`auto`・`dontAsk`・未知・欠落のモードでも、FORCE が未設定・ask・deny のいずれでも主は `deny` になる

#### Scenario: NO_ASK の値は UNATTENDED と同じに読む

- **WHEN** UNATTENDED と FORCE の無い環境で、NO_ASK が未設定・空・空白だけ・`0`・` 0 `・`1`・` true `・`yes` のそれぞれについて、主の `git reset --hard` を `default` と `bypassPermissions` で渡す
- **THEN** 未設定・空・空白だけ・`0`・` 0 ` は `ask`、それ以外は `deny` になる

#### Scenario: NO_ASK の主の定義は既存の agent_id の判定と同じ

- **WHEN** NO_ASK=1 で、agent_id が無い・空文字・数値の payload に `git reset --hard` を渡す
- **THEN** どれも主として `deny` と NO_ASK 用の理由文を返し、子の拒否回数を数えず `continue: false` を返さない

#### Scenario: NO_ASK の子は拒否と一度限りの許可の規則を維持する

- **WHEN** NO_ASK=1 で、同じ session_id・空でない agent_id の子が許可なしで破壊的 git 操作を 2 回試みる
- **THEN** 親に返す既存の理由文で両方 `deny` となり、2 回目は `continue: false` になる
- **WHEN** 既存の手順で scratchpad 内のコマンドに子への有効な一度限りの許可を書き、同じ session_id・cwd・command の主の payload、元の子の payload、もう一度子の payload の順に渡す
- **THEN** 主は NO_ASK 用の理由で `deny` となり許可を残し、子は 1 回 `allow` となり許可を使い切り、その後は `deny` になる

#### Scenario: NO_ASK でも検出範囲と off は変わらない

- **WHEN** NO_ASK=1 で `git status` を渡す。また `DEV_WORKFLOW_GIT_GUARD=off` も付けて `git reset --hard` を渡す
- **THEN** どちらも exit 0・無出力となる

### Requirement: 拒否理由は承認の取り方を案内する

対話のセッションの主の呼び出し（`agent_id` が無い・空・文字列でない）への `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（9 種のどれか。複数当たればすべて）／規範の正本が `rules/destructive-git-guard.md` であること／実行せず主に承認を求めること／承認されたら主が自分で実行すること（Claude Code の入力欄で `!` を付けるか、自分の端末で。`ask` のときは、確認画面が出ないセッション（`claude -p` など）ではそうすること）／`ask` のときは、確認画面を出していること／言い換えたコマンドで再実行して hook を避けないこと。`!` の入力は PreToolUse hook を通らない（対話セッションで `! git reset --hard` が止められずに実行されることを確かめた）ので、`!` の案内を残す。コマンドに付けて hook を通す目印（環境変数の前置など）を案内してはならない（MUST NOT）。

NO_ASK の印が無い無人のセッションの主の呼び出しへの `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行していないこと／何を・なぜ・いつ実行するかをチャンネル（Discord など）でオーナーに伝えて承認を求めること（文字列「チャンネル」と「オーナー」を含む）／承認されたらオーナーが自分で実行すること／言い換えたコマンドで再実行して hook を避けないこと。無人のセッションへの理由に、確認画面の話（文字列「確認画面」）を書いてはならない（MUST NOT。出していない確認画面の操作を待って止まる余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

NO_ASK の印がある主への `permissionDecisionReason` は、当たった種類（判定しきれなかった入れ子ならその旨）・規範の正本・実行していないことに加え、コマンドの全文・対象・なぜ要るか・止まった理由を書いてオーナーへの承認を求め、ターンを終えることを案内しなければならない（MUST）。承認されてもこのセッションでは実行せず、オーナーが自分で実行すること、言い換えて再実行しないことも含めなければならない（MUST）。確認画面・入力欄の `!`・チャンネルや Discord の案内・hook を通す目印の付け方を書いてはならない（MUST NOT）。UNATTENDED も付いている場合はこの段落を優先しなければならない（MUST）。

子の呼び出し（`agent_id` が空でない文字列）への `deny` の `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行されないこと／打ち直さず、別の書き方も試さないこと（文字列「打ち直さず」を含む）／scratchpad の検証用 repo なら git で戻さず作り直すこと／それ以外は作業を止め、報告に次の 4 項目を書いて親に返すこと（打ちたかったコマンドの全文、対象のパス、その対象を自分で作ったか（作ったなら、作ったコマンド）、なぜ要るか。文字列「コマンドの全文」「対象のパス」「自分で作った」を含む）／親の許可を受けられる打ち方の例は、変数を使わず実パスで単独のコマンドとして打つこと（変数や置換を含む形は親が許可を書けない。ほかの形が許可を受けられないとは書かない）（1 文で書く。文字列「実パスで単独のコマンド」を含む。この文は打ち方を教えるもので、打ち直しを許すものではなく、「打ち直さず」の指示は変えない）／拒否の記録を書けたときは、そのパスと、親に返す報告にそのパスを書くこと。子への理由に、確認画面を出していること、`!` を付けて打つこと、許可を書くスクリプトの名前と使い方を書いてはならない（MUST NOT。主に上げるのも許可を書くのも親の役目で、子が自分で主に聞こうとしたり自分で許可を書こうとしたりする余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

#### Scenario: deny の理由に承認の取り方が書かれている

- **WHEN** `agent_id` の無い、`permission_mode` が `auto` の payload で `git push origin main` を渡す
- **THEN** `permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: ask の理由に確認画面と、画面が出ないときの取り方が書かれている

- **WHEN** `agent_id` の無い、`permission_mode` が `bypassPermissions` の payload で `git push origin main` を渡す
- **THEN** `permissionDecision` が `ask` で、`permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、確認画面を出していること、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: 無人のセッションの理由はチャンネルでオーナーに依頼するよう案内する

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` を付けて、`agent_id` の無い、`permission_mode` が `bypassPermissions` の payload で `git push origin main` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、実行していないこと、「チャンネル」と「オーナー」、オーナーが自分で実行すること、言い換えて再実行しないことが含まれ、「確認画面」と `DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: 子への理由は親に返すよう案内する

- **WHEN** `agent_id` が空でない文字列で `permission_mode` が `default` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecisionReason` に、許可を受けられる打ち方の 1 文（「実パスで単独のコマンド」と「変数」）、作業の破棄に当たったこと、`rules/destructive-git-guard.md`、「打ち直さず」、scratchpad の検証用 repo なら作り直すこと、報告に書く 4 項目（「コマンドの全文」「対象のパス」「自分で作った」「なぜ」）を書いて親に返すこと、拒否の記録のパスが含まれ、「確認画面」と `!` を付けて打つ案内と `git-guard-permit.sh` と `DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: NO_ASK の理由は承認を求めてターンを終えるよう案内する

- **WHEN** NO_ASK=1 の主が `git push origin main` を default と bypassPermissions で試みる。UNATTENDED=1 も併せた場合と FORCE=ask も付けた場合も同じ入力で試みる
- **THEN** すべて `deny` となり、理由には main / master への push、`rules/destructive-git-guard.md`、実行していないこと、コマンドの全文・対象・なぜ要るか・止まった理由、オーナーへの承認依頼、ターンを終える指示、承認後もこのセッションでは実行せずオーナーが自分で実行すること、言い換えて再実行しないことが含まれる
- **AND** 理由に「確認画面」・`!`・「チャンネル」・「Discord」・印を付け外しする案内は含まれない

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

`rules/destructive-git-guard.md` は、次の 4 点を「hook との分担」の節に持たなければならない（MUST）。節は「dev-workflow プラグインの hook が入っていれば」の条件つきで書き、hook が入っていない環境では一覧の操作もこのルールだけが止めることを書く（MUST）: 一覧の操作は dev-workflow の hook が実行前に止めること（止まったら言い換えて再実行せず主に聞く。拒否されたセッションでは承認後も主が自分で実行する）／hook はコマンド文字列しか見ないので、push 済みの `git commit --amend`、`git rebase -i`、ブランチ名を書かない `git push`、スクリプトファイル経由の git は止まらないこと／サブエージェントから呼ばれたときは確認画面を出さずに拒否され、子は打ち直さず作業を止めて親に返ること／画面を見ている人のいないセッション（起動時に無人の印を付けたセッション）でも確認画面を出さずに拒否されるので、チャンネルで主に承認を求めること。印の環境変数の名前はルール本文に書かなくてよい（MAY。起動する側の設定で、ルールを読む Claude が付け外しするものではないため）。ルール本文は、オーナーの環境のパス（`~/.claude/rules-archive/` など）を書いてはならない（MUST NOT）。それ以外の既存の文は外さず（`always-on-injection-scope` の「縮約は削除ではなく移設」と、一覧・目印を本文に残す要件のため）、目印「例外なく事前承認」を含む文は変えてはならない（MUST NOT）。`rules/README.md` の該当行はこの分担に合わせて直さなければならない（MUST）。`DEV_WORKFLOW_GIT_GUARD_FORCE` はルール本文に書いてはならない（MUST NOT）。

この要件の検査の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。入力の出どころは、テストの実行時点の `rules/destructive-git-guard.md` と `rules/README.md` の本文で、テストが自分で読む。拾う誤りは、「hook との分担」の節の語（サブエージェント・確認画面を出さず・打ち直さず・親に返る・画面を見ている人のいないセッション・チャンネル・主に承認を求める）の欠落、条件の語（「入っていれば」）の欠落、`rules-archive` と `DEV_WORKFLOW_GIT_GUARD_FORCE` の混入。通してよい具体例は、条件の文の言い回しの良し悪し、節の語は揃っているが事実が hook の実際の振る舞いとずれている文（hook 側の spec の検査と人のレビューが見る）。見つかる穴をすべて塞ぐことは完了条件にしない。

#### Scenario: ルール本文に hook との分担がある

- **WHEN** `rules/destructive-git-guard.md` を読む
- **THEN** hook が一覧の操作を止めること、拒否されたら承認後も主が実行すること、hook で止まらないもの（push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）、サブエージェントは確認画面を出さずに拒否されて親に返ること、画面を見ている人のいないセッションでも確認画面を出さずに拒否されてチャンネルで主に承認を求めることが書かれ、`tests/always-on-injection-scope.bats` の目印がすべて残っている

#### Scenario: hook が無い環境でも読める

- **WHEN** dev-workflow プラグインが入っていない環境で `rules/destructive-git-guard.md` を読む
- **THEN** 「hook との分担」の節が「hook が入っていれば」の条件つきで書かれ、hook が無ければ一覧の操作もこのルールだけが止めることが書かれている

#### Scenario: ルール本文にオーナーの環境のパスが無い

- **WHEN** `rules/destructive-git-guard.md` を `rules-archive` と `marketplaces/` で検索する
- **THEN** 見つからない

#### Scenario: 上書きの環境変数がルールに無い

- **WHEN** `rules/destructive-git-guard.md` を `DEV_WORKFLOW_GIT_GUARD_FORCE` で検索する
- **THEN** 見つからない

#### Scenario: README の該当行が子と無人のセッションの扱いに触れる

- **WHEN** `rules/README.md` の `destructive-git-guard.md` の行を読む
- **THEN** サブエージェントは確認画面を出さずに拒否されて親に返ること、画面を見ている人のいないセッションでも確認画面を出さずに拒否されてチャンネルで主に承認を求めることが書かれている

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

### Requirement: 同じ子への拒否の繰り返しを打ち切る

子（`agent_id` が空でない文字列）に `deny` を返すたびに、`session_id` と `agent_id` の組ごとの拒否の回数を、環境変数 `TMPDIR` が空でない文字列ならその下、未設定か空なら `/tmp` の下の `dev-workflow-git-guard/` にあるファイルに数えなければならない（MUST）。書き込めない `TMPDIR` を飛ばして別の場所に書いてはならない（MUST NOT。`tempfile.gettempdir()` の候補探しを使わない）。ファイル名は `session_id` と `agent_id` から導いたハッシュとし、`agent_id` や `session_id` をそのままパスに使ってはならない（MUST NOT）。回数のファイルを作れない・読めない・中身が整数でないときは、その呼び出しを 1 回目として扱い、`deny` は返さなければならない（MUST。数えられないことで通してはならない）。`allow` を返した呼び出しは数えてはならない（MUST NOT）。要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」の確かめを満たさないとき、および判定のファイル（`plugins/dev-workflow/scripts/git-guard-scratchpad.py`）を読めず確かめられないときは、回数のファイルを読みも書きもせず、その呼び出しを数えてはならない（MUST NOT。`deny` は返す。2 回目以降の扱いにもしない）。回数のファイルは symlink を辿らずに開かなければならない（MUST。symlink なら読めないものとして 1 回目に扱い、その先を書き換えない）。要件「子は Bash のコマンドで許可の置き場所を名指しできない」が止める呼び出しのうち、ほかの種類（破壊的 git 操作の 9 種・判定しきれなかったもの・許可を書くスクリプトの子からの呼び出し）に当たらないものは、数えてはならない（MUST NOT。`deny` は返す。2 回目以降の扱いにもせず、`"continue"` のキーも出さない）。ほかの種類にも当たるものは、今までどおり数える（MUST）。

親が許可を書くスクリプト（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）で許可を書いたときは、その子の回数を 0 に戻す（回数のファイルを消す）。許可のあとの最初の拒否は 1 回目として扱わなければならない（MUST）。

同じ組への 2 回目以降の `deny` では、`permissionDecisionReason` に「直ちに作業を終えて親に返す」を含め、出力のトップレベルに `"continue": false` と `stopReason` を含めなければならない（MUST）。この形は既存のコードの実機確認済みの決定を引き継いだもので、この change では決め直さない（子の中で `continue: false` を返すと子だけが終わり、親が子の結果を受け取って続けることを確かめた記録は、archive の `openspec/changes/archive/2026-10-19-subagent-git-guard-deny/design.md` の節「2 回目以降の拒否: 強い理由文は常に足し、`continue: false` は実機確認の結果で決める」にある）。1 回目の `deny` には `"continue"` のキーを出力してはならない（MUST NOT）。主の呼び出し（`agent_id` が無い・空・文字列でない）は数えず、出力も変えない（MUST）。

守備範囲: 受け取る入力は、Claude Code が PreToolUse で渡す payload の `agent_id` と `session_id`、環境変数 `TMPDIR`、その下の回数のファイルである。拾いたい誤りは、拒否された子が打ち直しや言い換えで同じ hook に繰り返し当たり続けることである。次の入力は打ち切らずに通す（1 回目として扱う）ことを許す: 同じ子が並列の Bash 呼び出しで同時に拒否され、回数の読み書きが重なったもの／回数のファイルを作れない・読めない・中身が整数でないとき（毎回 1 回目になる）／一時ディレクトリが片付けられたあとの拒否（0 から数え直す）／hook に当たらない書き方（要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲で通ることを許した形）で子が同じことを試みたもの（拒否にならないので数えない）／他のプロセスが回数のファイルを書き換えたもの／`<base>` を確かめられないときの拒否と、判定のファイルを読めないときの拒否（数えないので毎回 1 回目になり、打ち切られない）／要件「子は Bash のコマンドで許可の置き場所を名指しできない」だけに当たった拒否（要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の拒否は別の hook で、もともと数えない。ルールを読み飛ばした子を 1 回で打ち切らないため数えない。同じ子が何度打ち直しても毎回 1 回目として返るが、コマンドは実行されない）。止めすぎる向きでは、SendMessage で再開された子は同じ `agent_id` を持つので回数が再開をまたいで続き、前の工程で 1 回拒否され親が許可を書かなかった子は次の工程の最初の拒否で 2 回目として扱われるが、これは許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 1 回目は打ち切らない

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を 1 回渡す
- **THEN** `permissionDecision` が `deny` で、出力に `"continue"` のキーが無く、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無い

#### Scenario: 同じ子への 2 回目は強く返す

- **WHEN** 空の `TMPDIR` で、`session_id` が `s1`・`agent_id` が `a1` の payload に `git checkout -- a` を渡して 1 回拒否されたあと、同じ `TMPDIR` で `session_id` が `s1`・`agent_id` が `a1` の payload に `git checkout -- b` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が含まれ、出力のトップレベルに `"continue": false` と `stopReason` が含まれる

#### Scenario: 別の子は 1 回目として数える

- **WHEN** `agent_id` が `a1` の payload で 1 回拒否されたあと、同じ `TMPDIR` で `agent_id` が `a2` の payload に `git checkout -- a` を渡す
- **THEN** 出力に `"continue"` のキーが無く、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無い

#### Scenario: 回数を数えられなくても拒否する

- **WHEN** 書き込めないディレクトリを `TMPDIR` にして、`agent_id` が `a1` の payload に `git checkout -- a` を 2 回渡す
- **THEN** どちらも `permissionDecision` が `deny` になる

#### Scenario: 主の呼び出しは数えない

- **WHEN** 空の `TMPDIR` で、`agent_id` の無い payload と `agent_id` が空文字の payload（どちらも `permission_mode` が `auto`）に `git reset --hard` をそれぞれ 2 回渡す
- **THEN** どちらも出力に `"continue"` のキーが無く、`TMPDIR` の下に回数のファイルが作られない

#### Scenario: 親が許可を書いたら数え直す

- **WHEN** scratchpad の中の repo を `cwd` にした `agent_id` が `a1` の payload で `git checkout -- .` を渡して 1 回拒否され、その拒否の記録で親が許可を書き、同じ payload を渡して `allow` になったあと、同じ子の payload で `git reset --hard` を渡す
- **THEN** 最後の `permissionDecision` が `deny` で、出力に `"continue"` のキーが無く、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無い

### Requirement: 子の定義に検証用 repo の戻し方を書く

dev-workflow の `agents/reviewer.md`・`agents/worker.md`・`agents/gate-runner.md` の本文は、scratchpad の検証用 repo は git の破壊的操作で戻さず作り直すことを、文字列「作り直す」を含む文で書かなければならない（MUST）。同じ本文に、破壊的 git 操作を拒否されたら作業を止め、報告に 4 項目（コマンドの全文・対象のパス・その対象を自分で作ったか（作ったなら作ったコマンド）・なぜ要るか）を書いて返すことを、文字列「コマンドの全文」「対象のパス」「自分で作った」を含む文で書かなければならない（MUST。本体が許可を書くか決める材料が、報告に揃うようにするため）。hook が子の呼び出しを、コマンドの行き先（scratchpad の中かどうか）だけを見て許可してはならない（MUST NOT。コマンドの中で変数を作ってから使う形を hook は展開できず、行き先を判定できないため）。子の呼び出しを通すのは、`permits/` に一致する許可があり、かつ一時領域の判定を満たすとき（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」）に限る。一時領域の判定は、行き先を確定できる形のコマンドだけを受け付け（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）、許可を書く時点でスクリプトが、使う時点で hook が、同じファイルの判定で行う。

**守備範囲**: 入力の出どころは、子が自分の判断で打つ Bash のコマンド文字列と、子が自分の報告に書く 4 項目である（#1133 の境界を引き継ぐ。新しい防御は足さない）。拾いたい誤りは、子が拒否されたとき、親が許可を書くか決める材料（対象のパス・自分で作ったか）を報告に載せず、親が毎回オーナーの画面待ちで止まること、および子が許可の仕組みや別の書き方で拒否を避けようとすることである。通してよい具体例は、子が `git checkout -- .` を拒否され、scratchpad の中に自分で作った repo の戻しを 4 項目つきで報告し、親の許可のあとの再開で同じコマンドを 1 回だけ打つこと、および子が 4 項目の一部を欠いて報告し、親がそれを理由にオーナーに上げること（止めすぎる向きで許す）である。守らないものは、子が報告に偽の項目（作っていないものを作ったと書く）を書くことで、消えるのは hook の一時領域の判定を満たす scratchpad の中に限られる。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 3 つの定義に戻し方がある

- **WHEN** `plugins/dev-workflow/agents/reviewer.md`・`worker.md`・`gate-runner.md` の本文を読む
- **THEN** どれにも、scratchpad の検証用 repo は git の破壊的操作で戻さず作り直すことが「作り直す」を含む文で、拒否されたら報告に書く 4 項目が「コマンドの全文」「対象のパス」「自分で作った」を含む文で書かれている

#### Scenario: 許可が無ければ scratchpad の中でも子を通さない

- **WHEN** 許可の無い空の `TMPDIR` で、`cwd` が scratchpad の中の repo の、`agent_id` が `a1` の payload に `git checkout -- .` を渡す
- **THEN** `permissionDecision` が `deny` になる

### Requirement: 子への拒否を記録し、親が 1 回だけ通せるようにする

子の呼び出し（`agent_id` が空でない文字列）に `deny` を返すたびに、hook は拒否の記録を `<base>/denied/<key>.json` に書かなければならない（MUST）。`<base>` は要件「同じ子への拒否の繰り返しを打ち切る」の回数のファイルと同じ `dev-workflow-git-guard/`（環境変数 `TMPDIR` が空でない文字列ならその下、未設定か空なら `/tmp` の下）。`<key>` は payload の `session_id`・`agent_id`・`cwd`・`tool_input.command` を NUL でつないだ文字列の sha256 の 16 進とする（`session_id` と `cwd` が文字列でなければ空文字として扱う）。記録には `session_id`・`agent_id`・`cwd`・`command`（全文）・当たった種類・時刻を含めなければならない（MUST）。記録を書けなかったときも `deny` は返さなければならない（MUST）。`<base>` が要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」の確かめを満たさないときは、この段落と次の段落の手順（記録を書く・許可を探す・回数を数える）を一つも行わずに `deny` を返さなければならない（MUST）。要件「子は Bash のコマンドで許可の置き場所を名指しできない」が当たった呼び出しでは、ほかの種類にも当たるときも含めて、拒否の記録を書かず、許可を探さずに `deny` を返さなければならない（MUST。この段落と次の段落の記録と許可の手順より優先する。回数の扱いは要件「同じ子への拒否の繰り返しを打ち切る」）。

子の呼び出しで破壊的 git 操作を見つけたとき、hook は同じ規則で `<key>` を計算し、`<base>/permits/<key>.json`（許可）を自分だけが使えるように `rename` で取ってから読まなければならない（MUST）。取れた許可の `session_id`・`agent_id`・`cwd`・`command` がすべて payload と一致し、`expires_at` が今より後で、かつ payload の `session_id`・`cwd`・`tool_input.command` が要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」の判定（以下「一時領域の判定」）をその時点のファイルシステムで満たすときに限り、`permissionDecision` を `allow` にし、取った許可を消さなければならない（MUST）。このとき拒否の回数を数えてはならず、拒否の記録も書いてはならない（MUST NOT）。一時領域の判定は、hook と許可を書くスクリプトが `plugins/dev-workflow/scripts/` に置いた同じ 1 つのファイルを読んで行わなければならない（MUST。判定を 2 か所に書き分けない）。許可ファイルが担うのは親の同意だけで、一時領域の外へ通さないことは hook のこの判定が担う。許可が無い・取れない・読めない・どれかの値が一致しない・期限切れのときは、取った許可を消し、今までどおり `deny` を返して回数を数えなければならない（MUST）。許可の 4 つの値は一致し期限内だが一時領域の判定を満たさないときも、取った許可を消して `deny` を返し回数を数え、`permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含めなければならない（MUST）。判定のファイルを読めないときは `<key>` を出せないので、許可を探さず拒否の記録も書かずに `deny` を返さなければならない（MUST。許可は残り、期限で切れる）。このときは `<base>` を確かめられないので、回数も数えてはならない（MUST NOT。要件「同じ子への拒否の繰り返しを打ち切る」）。

hook と許可を書くスクリプトは、payload の `cwd` を、そのコマンドが実行されるディレクトリとして扱う（実機で確認済み: 子の Bash は呼び出しをまたいで作業ディレクトリを持ち越さず、`cd` だけを打った次の呼び出しの payload の `cwd` は起動ディレクトリのままで、コマンドが実行されるディレクトリと一致した。archive の design.md「cd のあとの payload の cwd」）。主の呼び出し（`agent_id` が無い・空・文字列でない）は許可を見てはならない（MUST NOT。今までどおり `ask` / `deny`）。`allow` の `permissionDecisionReason` には、親が書いた許可に一致したのでこの 1 回だけ通すことを書かなければならない（MUST）。

守備範囲: 受け取る入力は、要件「同じ子への拒否の繰り返しを打ち切る」の入力に payload の `cwd` と、`<base>` の下の `denied/` と `permits/` のファイルを足したものである。拾いたい誤りは、子が自分の scratchpad の検証用 repo を戻すだけの操作でも、親が代わりに打つと主の確認画面が出て、主が画面を押すまで作業が止まることである。次の入力は止めることを許す: 親が許可を書いたあと、子がコマンドを 1 文字でも変えて打ったもの・別の cwd から打ったもの／SendMessage で再開されずに新しい子として起こされ `agent_id` が変わったもの／期限が切れてから打ったもの。次の入力は通すことを許す: 子や他のプロセスが許可を書くスクリプトを経ずに `permits/` に直接書いた許可のうち、一時領域の判定を満たすもの（親の同意は経ないが、通るのは scratchpad の中の repo への操作だけに限られる）。子が書く形のうち、Write / Edit / NotebookEdit で書くものと、Bash のコマンドに置き場所の名前を 2 つとも書くものは、要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」と要件「子は Bash のコマンドで許可の置き場所を名指しできない」が書く前に止める。それ以外の書き方（要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲で通ることを許した形）で置かれた許可は、使う時点で区別できないので通る／hook が一時領域の判定を終えてからコマンドが実行されるまでの間に、scratchpad の中のディレクトリが外への symlink に差し替えられたもの。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 一致する許可があれば 1 回だけ通す

- **WHEN** 空の `TMPDIR` で、`session_id` が scratchpad の形に合うセッション・`agent_id` が `a1`・`cwd` が scratchpad の中の repo の payload に `git checkout -- .` を渡して拒否され、拒否の記録のパスで許可を書くスクリプトが exit 0 で終わったあと、同じ payload を 2 回渡す
- **THEN** 1 回目は `permissionDecision` が `allow`、2 回目は `deny` になる

#### Scenario: 許可のあとで行き先が外に変わったら通さない

- **WHEN** 上と同じく許可を書いたあと、その repo の `.git` を、scratchpad の外の repo の git ディレクトリを指す symlink に差し替えてから、元の payload を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「許可はあるが行き先を確かめられない」が含まれ、許可のファイルが残っていない

#### Scenario: 直接書いた許可でも外は通さない

- **WHEN** 許可を書くスクリプトを使わずに、`cwd` が scratchpad の外の repo で 4 つの値が payload と一致し期限内の許可を `permits/<key>.json` に直接書いてから、その payload に `git checkout -- .` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「許可はあるが行き先を確かめられない」が含まれる

#### Scenario: 一致しない呼び出しには許可を使わない

- **WHEN** 上と同じく許可を書いたあと、コマンドの末尾に空白を 1 つ足した payload、`agent_id` が `a2` の payload、`cwd` が違う payload をそれぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になり、そのあと元の payload を渡すと `allow` になる（一致しない呼び出しで許可が消えない）

#### Scenario: 期限切れの許可は使わない

- **WHEN** 許可を書いたあと、許可のファイルの `expires_at` を過去の時刻に書き換えてから、元の payload を渡す
- **THEN** `permissionDecision` が `deny` になり、許可のファイルが残っていない

#### Scenario: 主の呼び出しは許可を見ない

- **WHEN** 許可を書いたあと、同じ `session_id`・`cwd`・コマンドで `agent_id` の無い、`permission_mode` が `default` の payload を渡す
- **THEN** `permissionDecision` が `ask` になり、許可のファイルが残っている

#### Scenario: 拒否の記録が書かれる

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `TMPDIR` の下の `dev-workflow-git-guard/denied/` に、`session_id`・`agent_id`・`cwd`・コマンドの全文を含む記録が 1 つ作られ、`permissionDecisionReason` にそのパスが含まれる

#### Scenario: 判定のファイルを読めないときは許可を探さずに拒否する

- **WHEN** `git-guard-scratchpad.py` が無い場所に hook だけを置き、4 つの値が一致する許可を `permits/<key>.json` に置いてから、`agent_id` が `a1` の `git checkout -- a` の payload を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含まず、`denied/` は作られず、許可のファイルは残る。同じ payload をもう 1 回渡しても、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無く、回数のファイルが作られない

### Requirement: 許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する

`plugins/dev-workflow/scripts/git-guard-permit.sh` は、引数に拒否の記録のパスと理由（空でない文字列）を受け取り、次をすべて確かめたときだけ許可を書かなければならない（MUST）。どれかを確かめられなければ、許可を書かず、理由を stderr に書いて 0 以外で終わらなければならない（MUST）。終了コードは、許可を書いたら 0、引数の誤りは 2 とする。確かめられなかったときは、記録の `command` が一時領域の判定（次の 2 つ目の項目）を満たさず、かつその `command` が単独のコマンドの形でなければ 3、それ以外（記録の置き場所・中身の確かめに落ちたもの、単独のコマンドの形なのに判定を満たさないもの、判定のあとの書き込みに失敗したもの）は 1 で終わらなければならない（MUST）。単独のコマンドの形とは、`command` が、使う判定（git 用か rm 用か。次の 2 つ目の項目と同じ決め方）が許す文字だけでできていて、`;`・`&`・改行を 1 つも含まないことをいう。3 で終わるときは、判定の理由の行に加えて、実パスで単独のコマンドに打ち直せば判定し直せる形の理由で断ったことを stderr に 1 行書かなければならない（MUST）。3 か 1 かの振り分けは打ち直しを頼めるかの目安であって、許可を書くかどうかを変えてはならない（MUST NOT）。

- 記録が `<base>/denied/<key>.json` の形の場所にあり、`basename(<base>)` が `dev-workflow-git-guard` で、中身から計算し直した `<key>` がファイル名と一致する。`<base>` は記録のパスの 2 つ上とし、環境変数 `TMPDIR` を見てはならない（MUST NOT。hook と親の Bash で `TMPDIR` が違いうるため）
- 記録の `session_id`・`cwd`・`command` が、一時領域の判定を満たす。`command` の単純コマンド（`&&`・`;`・改行で区切ったもの）のどれかの先頭の語が `rm` なら、次の git 用の判定の代わりに要件「rm の一時領域の判定」（spec rm-permission-hook）を使い、それ以外は次の判定を使う（どちらを使うかは記録の `command` だけで決め、記録の他の項目は見ない）

git 用の一時領域の判定は、`session_id`・`cwd`・`command` の 3 つを入力とし、次をすべて満たすときに満たすとする。git 用の判定と rm の判定は `plugins/dev-workflow/scripts/` の 1 つのファイルに置き、許可を書くスクリプトと hook（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」と spec rm-permission-hook）がそれを読んで使わなければならない（MUST）。

- 判定する側（許可を書くスクリプト・hook）の環境変数に、`cd` や `git` の行き先・設定を変えるもの（`CDPATH`・`GIT_DIR`・`GIT_WORK_TREE`・`GIT_COMMON_DIR`・`GIT_INDEX_FILE`・`GIT_OBJECT_DIRECTORY`・`GIT_ALTERNATE_OBJECT_DIRECTORIES`・`GIT_NAMESPACE`・`GIT_CEILING_DIRECTORIES`・`GIT_DISCOVERY_ACROSS_FILESYSTEM`、および `GIT_CONFIG` で始まるもの）が 1 つも設定されていない（値が空でも設定されているものとして扱う。子の Bash は Claude Code の環境を受け継ぐので、hook の環境にあるものは子のコマンドにも効く）。ただし、一部の起動環境で Claude Code のセッションの Bash に渡される `GIT_CONFIG_COUNT`・`GIT_CONFIG_KEY_<n>`・`GIT_CONFIG_VALUE_<n>` の組は、次をすべて満たすときに限り、設定されていないものとして扱う（MUST）: `GIT_CONFIG_COUNT` が 10 進の非負整数（先頭の `0` の連続や符号を含まない）で、`GIT_CONFIG_KEY_0` から `GIT_CONFIG_KEY_<COUNT-1>` と `GIT_CONFIG_VALUE_0` から `GIT_CONFIG_VALUE_<COUNT-1>` がすべて設定され、すべての `GIT_CONFIG_KEY_<n>` の値が無害なキーの一覧（`credential.interactive`・`credential.guiPrompt`。大文字小文字まで完全一致）のどれかで、`GIT_CONFIG_COUNT` の範囲の外の番号の `GIT_CONFIG_KEY_*` / `GIT_CONFIG_VALUE_*` が 1 つも無い。`GIT_CONFIG_VALUE_<n>` の値は見ない。この組のどれか 1 つでも満たさなければ、`GIT_CONFIG` で始まる変数をすべて、今までどおり設定されているものとして扱う。`GIT_CONFIG`・`GIT_CONFIG_GLOBAL`・`GIT_CONFIG_SYSTEM`・`GIT_CONFIG_NOSYSTEM`・`GIT_CONFIG_PARAMETERS` など、この組以外の `GIT_CONFIG` で始まる変数は、組が揃っていても設定されているものとして扱う。無害なキーは「`cd` と `git` の行き先を変えず、判定が確かめた作業ツリー・git ディレクトリ以外へ git を向けない」と確かめたものだけを一覧に足し、足すときはこの要件を直す
- コマンドが英数字・空白・タブ・改行（LF だけ。CR は拒む）・`/ . _ , : = @ + % -`・`;`・`&&` だけでできている（変数・置換・引用符・リダイレクト・パイプ・グロブ・`~`・コメント・行継続を含まない）
- `&&`・`;`・改行で区切った単純コマンドがすべて、引数 1 つの `cd`（実在するディレクトリで、引数が `/`・`./`・`../` で始まるか `.`・`..` そのもの。シェルはそれ以外の引数を、オプション（`-P`・`--`）・ディレクトリスタックの番号（`+1`・`-1`）・zsh の `=` 展開・`CDPATH` や zsh の `cdpath` の探索として読みうるため）か、サブコマンドの前に `-C <パス>` だけを置いた `git`（`-C` は複数置けて、左から順に適用する）で、サブコマンドが `checkout`・`restore`・`reset`・`clean`・`branch`・`switch`・`status`・`add`・`commit`・`rev-parse` のどれかであり、`git` が 1 つ以上ある
- 各 `git` の作業ディレクトリ（`cwd` から `cd` と `-C` を順に適用し `realpath` で解決したもの）から親へ辿って見つかる `.git` について、作業ツリーの最上位・git ディレクトリ（`.git` がファイルなら `gitdir:` の先）・共通の git ディレクトリ（`commondir` があればその先）の `realpath` が、すべて `session_id` のセッションの scratchpad の中（scratchpad そのものを含む。scratchpad の直下に `.git` があれば scratchpad 全体を作業ツリーとする repo として中に数える）にある。scratchpad とは、`basename` が `scratchpad`、その親の `basename` が `session_id`、さらに 2 つ上の `basename` が `claude-<判定を動かすユーザーの uid>` のディレクトリで、かつその `claude-<uid>` の親の `realpath` が一時フォルダの置き場所（`/tmp`・`/private/tmp` と、hook では自分の環境変数 `TMPDIR` と Python の `tempfile.gettempdir()`、許可を書くスクリプトでは `<base>` の親（hook が `<base>` を置いた `TMPDIR`）の、`realpath` のどれか。hook と親の Bash で `TMPDIR` が違いうるので、スクリプトは自分の `TMPDIR` を数えず、hook と同じ候補で判定する）で、`claude-<uid>` がディレクトリで、所有者が判定を動かすユーザーの uid で、グループと他者に書き込み権が無いものである（作業ツリーの中などに同じ形のフォルダを作っても scratchpad に数えない）。`session_id` は英数字と `-` だけの空でない文字列でなければならない。scratchpad の中で `.git` が見つからないものは拒む
- 判定は単純コマンドを左から順に、実行前のファイルの配置で解く。前の単純コマンドが失敗したりファイルの配置を書き換えたりすると、判定が見た行き先と実際の行き先が割れるので、次をすべて満たす。これは判定から実行までの短い窓（判定のあとで別のものが配置を差し替える）とは別物で、コマンド自身の結果（`cd` の失敗、前の `git` による作業ツリーの書き換え）で起きる
  - `cd` を 1 つでも含むコマンドは、区切りが `&&` だけである（`;` と改行を 1 つも含まない。実行権限の無いディレクトリへの `cd` などが失敗すると、`;` や改行の後ろの `git` は元の `cwd` で走るため）
  - `cd` は最初の `git` より前にだけある（前の `git` が移り先を消したり、外への symlink に置き換えたりしうるため）
  - `git` が 2 つ以上あるコマンドでは、どの `git` にも `-C` が無い（前の `git` が `-C` の辿る道筋を書き換えうるため）
  - `git` が 2 つ以上あるコマンドでは、作業ディレクトリ（`cwd` から `cd` を辿った物理パス。`cd` が無ければ `cwd`）の `realpath` が、見つかった作業ツリーの最上位の `realpath` と一致する（作業ツリーの中のサブディレクトリは前の `git` に消されたり置き換えられたりしうるため）
- 見つかった `.git` を git が git ディレクトリとして受け入れる形である（git ディレクトリと共通の git ディレクトリと、共通の git ディレクトリの `objects` と `refs` がディレクトリで、どれにも判定を動かすユーザーが入れる（実行権限がある）。git ディレクトリの `HEAD` が `ref: refs/` で始まるか 40 桁か 64 桁の 16 進）。`.git` ファイルと `commondir` は、git と同じくファイル全体を読んで末尾の CR と LF だけを落とし、そのあとに CR・LF・NUL が残るもの（2 行以上ある・行の途中に改行文字がある）は拒む（git は受け入れない `.git` を飛ばして上の階層の repo を使い、改行を含んだままのパスを使うため）
- 作業ツリーの最上位より上のどの階層（scratchpad とその外を含め `/` まで）にも、`.git` も、git ディレクトリそのものの形（`HEAD` と、`objects` か `refs`）も無い（判定と git の受け入れ方がずれたときに、git が確かめていない repo や scratchpad の外に置かれた `.git` を使う余地を残さないため）
- git ディレクトリと共通の git ディレクトリの中に symlink が 1 つも無く、サブモジュールの git ディレクトリ（`modules`）も無く、作業ツリーの最上位に `.gitmodules` も無い（`refs`・`index`・`objects` などが外を指すと、中の repo への操作が外の repo を書き換え、サブモジュールへの再帰は `.git/modules/<name>` の先の repo を触るため）
- 共通の git ディレクトリの `config` と git ディレクトリの `config.worktree` に、`worktree` のキーも `[include` / `[includeIf` の節も `submodule` の文字列も無い（節名とキーは大文字小文字を区別せずに見る。git が区別しないため）

判定のために git を実行してはならない（MUST NOT。子が作った repo の設定でコマンドが動きうるため）。許可は `<base>/permits/<key>.json` に、`session_id`・`agent_id`・`cwd`・`command`・`scratchpad`・確かめた repo・理由・`created_at`・`expires_at`（書いた時刻の 15 分後の UNIX 秒）を入れて、一時ファイルからの `rename` で置かなければならない（MUST）。許可を書いたら、その子の回数のファイル（`<base>/<sha256(session_id + NUL + agent_id)>`）を消さなければならない（MUST。要件「同じ子への拒否の繰り返しを打ち切る」）。消せなかったときは stderr に書き、exit 0 で終わってよい。成功したときは、許可したコマンド・cwd・scratchpad・確かめた repo・期限を stdout に書かなければならない（MUST）。

守備範囲: 受け取る入力は、引数・拒否の記録・ファイルシステム上の scratchpad と repo の置き場所に加え、判定を動かすプロセスの環境変数（`CDPATH`・`GIT_DIR` など行き先を変えるものと、`GIT_CONFIG_COUNT`・`GIT_CONFIG_KEY_<n>`・`GIT_CONFIG_VALUE_<n>`。値は Claude Code が入れたものを含め呼び出し側が決める）である。拾いたい誤りは、親が「子が自分の一時領域を戻すだけ」と判断を誤って、一時領域の外のワークツリー・ホーム・他のリポジトリへの破壊的な操作を許可することである。次の入力は通す（許可を書く）ことを許す: 子が自分の Bash の中だけで `GIT_DIR` / `GIT_WORK_TREE` などを設定し、判定する側の環境には無いまま git が別の場所を触るもの（スクリプトと hook は子のシェルの中の環境を見られない。同じ呼び出しの中で代入する形は文字の制限と単純コマンドの制限で拒む）／scratchpad の中の、親の判断と違うファイルや repo を触るもの（守らないもの）。止めすぎる向きでは、引用符やグロブを使ったコマンド・許した以外の git のサブコマンドは scratchpad の中でも許可できないが、これは許す。`git -C X reset --hard && git -C X clean -fdx` のように `git` が 2 つ以上で `-C` を使うもの（`cd X && git reset --hard && git clean -fdx` に書き直す）・作業ツリーの中のサブディレクトリで `git` を 2 つ以上走らせるもの・末尾に改行や `;` がある `cd` 入りのコマンドも許可できないが、これも許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 一時領域の中の repo への操作は許可を書く

- **WHEN** `<tmp>/claude-<uid>/<slug>/<session_id>/scratchpad/repo` に repo を作り、`cwd` がそこで `git checkout -- .` の拒否の記録を作って、記録のパスと理由を渡す
- **THEN** exit 0 で終わり、`permits/` に許可が 1 つ作られ、stdout に scratchpad のパスが含まれる

#### Scenario: 一時領域の外を触る許可は書けない

- **WHEN** 拒否の記録の `cwd` が scratchpad の外の repo のもの、`cd` で scratchpad の外の repo に移ってから `git reset --hard` するもの、`git -C <外の repo> clean -fd` のもの、`.git` が外の git ディレクトリを指す repo のもの、`session_id` が別のセッションの scratchpad の中の repo のもの、共通の git ディレクトリの `config` に `[Core]` の節と `WorkTree = <外のパス>` のキーを大文字混じりで書いた repo のもの、をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られない

#### Scenario: git が受け入れない .git・git ディレクトリの中の symlink・サブモジュールがある repo には許可を書かない

- **WHEN** scratchpad の中の、`.git` が中身の無いディレクトリの repo・`commondir` が CR 付きの `..` の repo・`.git` ファイルが 2 行ある repo・`.git` ファイルの行の途中に CR がある repo・`commondir` が 2 行ある repo・`.git/objects` か `.git/refs` の実行権限を落とした repo・別の repo の作業ツリーの中に作った repo・scratchpad の親に `.git` ファイルを置いた scratchpad の中の repo・`.git` の `refs`・`index`・`packed-refs`・`HEAD`・`objects`・`refs/heads`・`logs` のどれかを外の repo の同じものへの symlink にした repo・`.git/modules/sub` を外の repo の `.git` への symlink にした repo・作業ツリーの最上位に `.gitmodules` がある repo・`config` に `[Submodule "sub"]` の節がある repo への操作の拒否の記録をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られず、外の repo の branch は残る

#### Scenario: 一時フォルダの外に作った同じ形のフォルダは scratchpad に数えない

- **WHEN** 一時フォルダの置き場所でないディレクトリ（作業ツリーの中など）の下に `claude-<uid>/<slug>/<session_id>/scratchpad/repo` を作り、`cwd` がそこで `git checkout -- .` の拒否の記録を渡す。また、同じ `cwd` とコマンドで 4 つの値が一致し期限内の許可を `permits/<key>.json` に直接書いてから、その payload を hook に渡す
- **THEN** スクリプトは 0 以外で終わって `permits/` に許可が作られず、hook は `permissionDecision` が `deny` で `permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含む

#### Scenario: Claude Code が入れる無害な GIT_CONFIG の組なら許可を書き、使う

- **WHEN** `GIT_CONFIG_COUNT=2`・`GIT_CONFIG_KEY_0=credential.interactive`・`GIT_CONFIG_VALUE_0=false`・`GIT_CONFIG_KEY_1=credential.guiPrompt`・`GIT_CONFIG_VALUE_1=false` を設定した環境で、一時領域の中の repo への `git checkout -- .` の拒否の記録をスクリプトに渡し、そのあと同じ環境で hook に元の payload を渡す
- **THEN** スクリプトは 0 で終わって `permits/` に許可が作られ、hook は `permissionDecision` が `allow` になる

#### Scenario: 無害でないキーや組の崩れがあれば許可を書かない

- **WHEN** 上の組の `GIT_CONFIG_KEY_1` を `core.worktree` に替えた環境、`GIT_CONFIG_COUNT=2` なのに `GIT_CONFIG_KEY_1` が無い環境、`GIT_CONFIG_COUNT=1` なのに `GIT_CONFIG_KEY_1` がある環境、上の組に `GIT_CONFIG_GLOBAL` か `GIT_CONFIG_PARAMETERS` を足した環境、`GIT_CONFIG_COUNT` が `abc` の環境で、それぞれ同じ拒否の記録をスクリプトに渡す
- **THEN** どれも 0 以外で終わり、理由に環境変数の名前が含まれ、`permits/` に許可が作られない

#### Scenario: 行き先を変える環境変数があれば許可を書かず、使わない

- **WHEN** 一時領域の中の repo への `git checkout -- .` の拒否の記録を、`GIT_DIR` を scratchpad の外の repo の git ディレクトリに向けた環境でスクリプトに渡す。また、その環境変数の無い環境で許可を書いたあと、`GIT_DIR` を外に向けた環境で hook に元の payload を渡す
- **THEN** スクリプトは 0 以外で終わって `permits/` に許可が作られず、hook は `permissionDecision` が `deny` で `permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含む

#### Scenario: 行き先を確定できないコマンドは許可を書かない

- **WHEN** コマンドが `cd "$D" && git checkout -- .`・`git reset --hard && rm -rf x`・`git push --force origin main`・`GIT_DIR=x git reset --hard`・`git checkout -- . > out`・`git init /x/outside`・CR を含む `git checkout -- .` の拒否の記録をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られない

#### Scenario: cd の移り先がパスの形で始まらないものは許可を書かず、使わない

- **WHEN** scratchpad の外の `cwd` に、scratchpad の中の repo を指す `-Z`・`-P`・`--`・`+1`・`=git`・`repo` という名前のリンクを置き、`cd -Z; git reset --hard`・`cd -P && git status`・`cd -- && git reset --hard`・`cd +1; git reset --hard`・`cd =git; git reset --hard`・`cd repo && git reset --hard` の拒否の記録をそれぞれ渡す。また、`cd -Z; git reset --hard` について 4 つの値が一致し期限内の許可を `permits/<key>.json` に直接書いてから、その payload を hook に渡す
- **THEN** スクリプトはどれも 0 以外で終わって `permits/` に許可が作られず、hook は `permissionDecision` が `deny` で `permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含む

#### Scenario: cd の失敗や前の git の書き換えで行き先が変わるコマンドは許可を書かず、使わない

- **WHEN** `cwd` が scratchpad の外の作業ツリーで、scratchpad の中の repo（`main` で `sub/f` を追跡し、ブランチ `evil` では `sub` が外への symlink。未追跡のディレクトリ `build` がある）と実行権限を落としたディレクトリ `locked` について、`cd <repo>/locked ; git reset --hard`・`;` を改行にした同じもの・`git -C <repo> clean -fdx ; cd <repo>/build ; git reset --hard`・`cd <repo> && git checkout evil && cd ./sub && git reset --hard`・`git -C <repo> checkout evil && git -C <repo>/sub reset --hard`・`cd <repo>/sub && git checkout evil && git reset --hard` の拒否の記録をそれぞれ渡す。また、`cwd` が repo で `cd <repo>; git reset --hard`・`git status && cd <repo> && git reset --hard` の記録を渡す。また、`cd <repo>/locked ; git reset --hard` について 4 つの値が一致し期限内の許可を `permits/<key>.json` に直接書いてから、その payload を hook に渡す
- **THEN** スクリプトはどれも 0 以外で終わって `permits/` に許可が作られず、hook は `permissionDecision` が `deny` で `permissionDecisionReason` に「許可はあるが行き先を確かめられない」を含む。`cd ./repo && git reset --hard && git clean -fdx`（`cwd` が scratchpad）は今までどおり許可を書く

#### Scenario: 置き場所や中身が合わない記録には許可を書かない

- **WHEN** 拒否の記録を `denied/` の外に写したもの、`dev-workflow-git-guard` でない名前のディレクトリの下の `denied/` に写したもの、中身のコマンドを書き換えたもの、理由を空にしたもの、をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られない

#### Scenario: スクリプトは TMPDIR ではなく記録の場所に許可を書く

- **WHEN** hook を `TMPDIR=A` で動かして `A` の下の scratchpad の repo への拒否の記録を作り、スクリプトを `TMPDIR=B` で動かしてから、同じ payload を `TMPDIR=A` の hook に渡す
- **THEN** 許可が `A` の下の `dev-workflow-git-guard/permits/` に作られ、`B` の下には何も作られず、hook は `permissionDecision` を `allow` にする

#### Scenario: スクリプトは自分の TMPDIR を一時フォルダの候補に数えない

- **WHEN** hook を `TMPDIR=A` で動かして、`B` の下にだけある scratchpad の repo への拒否の記録を作り、スクリプトを `TMPDIR=B` で動かす
- **THEN** 0 以外で終わり、`permits/` に許可が作られない（hook はこの scratchpad を数えないので、書いても使えない）

#### Scenario: rm のコマンドの記録には rm 用の判定で許可を書く

- **WHEN** `cwd` が scratchpad の中で、コマンドが `cd ./tbl; rm -rf x/*` の拒否の記録（`kinds` は `rm`）を渡す
- **THEN** exit 0 で終わり、`permits/` に許可が 1 つ作られる。同じ記録の `kinds` を `git` に書き換えても、判定は `command` だけで決まるので結果は変わらない

#### Scenario: 単独のコマンドの形でないために判定に落ちた記録は終了コード 3 で断る

- **WHEN** `cwd` が scratchpad の外の作業ツリーで、scratchpad の中の repo について、`mkdir -p <repo>/x && git -C <repo> checkout -- a.txt`・`git init <repo> && git -C <repo> checkout -- a.txt`・`R=<repo>; git -C $R checkout -- a.txt`・`git -C "<repo>" checkout -- a.txt`・`git -C <repo> checkout -- a.txt & git status` の拒否の記録をそれぞれ渡す。また、`cd <scratchpad の外の repo> && git reset --hard` の記録を渡す
- **THEN** どれも終了コード 3 で終わり、stderr に判定の理由の行と、単独のコマンドに打ち直せば判定し直せる旨の行があり、`permits/` に許可が作られない

#### Scenario: 単独のコマンドの形なのに判定に落ちた記録と、記録の確かめに落ちた記録は終了コード 1 で断る

- **WHEN** `git -C <scratchpad の外の repo> checkout -- a.txt`・`git push --force origin main`・`git -C <scratchpad の中の、まだ無いディレクトリ> checkout -- a.txt` の拒否の記録をそれぞれ渡す。また、`mkdir -p <repo>/x && git -C <repo> checkout -- a.txt` の記録の中身のコマンドを書き換えたもの（key がファイル名と一致しない）を渡す
- **THEN** どれも終了コード 1 で終わり、stderr に打ち直せば判定し直せる旨の行が無く、`permits/` に許可が作られない

#### Scenario: 打ち直した単独のコマンドが scratchpad の中なら許可を書く

- **WHEN** 同じ子について、`mkdir -p <repo>/x && git -C <repo> checkout -- a.txt` の拒否の記録で終了コード 3 を受けたあと、`git -C <repo> checkout -- a.txt` の拒否の記録を作って渡し、そのあと同じ payload を hook に渡す
- **THEN** スクリプトは exit 0 で終わって `permits/` に許可が 1 つ作られ、hook は `permissionDecision` を `allow` にする

### Requirement: 子は許可を書くスクリプトを呼べない

子の呼び出しで、`tool_input.command` の文字列のどこかに `git-guard-permit` が含まれるものに、hook は書き方（直接の呼び出し・シェル経由・`-c` のコマンド文字列の中・`BASH_ENV` / `ENV` の設定・`cat` などで読むだけのもの）を問わず `deny` を返さなければならない（MUST。大文字小文字は区別する）。シェルの書き方を 1 つずつ読み分けて止めると、塞ぐたびに別の書き方が出るため、コマンドの読み方に頼らない。子がこのスクリプトを読む用事は無いので、読むだけのものも止める。拒否理由・回数・拒否の記録は、破壊的 git 操作の拒否と同じに扱う（当たった種類は許可を書くスクリプトの子からの呼び出し）。ただし同じコマンドに要件「子は Bash のコマンドで許可の置き場所を名指しできない」も当たるときは、拒否の記録を書かない（その要件に従う。回数は数える）。この呼び出しには許可を使ってはならない（MUST NOT）。主の呼び出しは止めてはならない（MUST NOT）。

守備範囲: 受け取る入力は、Claude Code が PreToolUse で渡す payload の `tool_input.command`（子が書く値）と `agent_id` である。拾いたい誤りは、拒否された子が親に返らずに、コマンド文字列にスクリプトのパスを書いて自分で許可を書くことである。変数を組み合わせて名前を作る形・別名・グロブ・別のファイルの中から呼ぶ形など、コマンド文字列に名前が出ない書き方は通ることを許す。スクリプトを経ずに許可の置き場所へ直接書く形は、この要件では見ない（分かりやすい 2 つの書き方は要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」と要件「子は Bash のコマンドで許可の置き場所を名指しできない」が止め、残りは要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲で通ることを許す）。通っても、許可が効くのは使う時点の一時領域の判定（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」）を満たす scratchpad の中だけである。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 子がスクリプトを呼ぶと拒否する

- **WHEN** `agent_id` が `a1` の payload に `/x/scripts/git-guard-permit.sh /y/denied/k.json ok` と `bash /x/scripts/git-guard-permit.sh /y/denied/k.json ok` をそれぞれ渡す
- **THEN** どちらも `permissionDecision` が `deny` になる

#### Scenario: 書き方を問わず名前があれば拒否する

- **WHEN** `agent_id` が `a1` の payload に `bash -o errexit /x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`bash --rcfile /x/scripts/git-guard-permit.sh -i`・`zsh -O /x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`bash -c '/x/scripts/git-guard-permit.sh /y/denied/k.json ok'`・`BASH_ENV=/x/scripts/git-guard-permit.sh bash -c true`・`BASH_ENV[0]=/x/scripts/git-guard-permit.sh bash /x/y.sh`・`BASH_ENV+=/x/scripts/git-guard-permit.sh bash /x/y.sh`・`declare -x BASH_ENV=/x/scripts/git-guard-permit.sh; bash /x/y.sh`・`typeset -x ENV=/x/scripts/git-guard-permit.sh; sh -i`・`printf -v BASH_ENV %s /x/scripts/git-guard-permit.sh; export BASH_ENV; bash /x/y.sh`・`read BASH_ENV <<< /x/scripts/git-guard-permit.sh; export BASH_ENV; bash /x/y.sh`・`cat /x/scripts/git-guard-permit.sh` をそれぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 主の呼び出しは止めない

- **WHEN** `agent_id` の無い payload に `/x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`bash /x/scripts/git-guard-permit.sh /y/denied/k.json ok`・`BASH_ENV=/x/scripts/git-guard-permit.sh bash -c true`・`cat /x/scripts/git-guard-permit.sh` をそれぞれ渡す
- **THEN** どれも何も出力しない

### Requirement: 許可を書いたこと・使ったことを記録する

許可を書くスクリプトは、許可を書く前に `<base>/permit-log.jsonl` に、`event` が `permit` で、時刻・`session_id`・`agent_id`・`cwd`・`command`・`scratchpad`・確かめた repo・理由・`expires_at` を含む 1 行の JSON を追記しなければならない（MUST）。追記できなければ許可を書かずに 0 以外で終わらなければならない（MUST）。hook は許可を使ったとき `event` が `use`、期限切れの許可を捨てたとき `event` が `expired` の行を追記しなければならない（MUST）。hook の追記の失敗で判定を変えてはならない（MUST NOT）。

#### Scenario: 許可と使用が記録に残る

- **WHEN** 要件「子への拒否を記録し、親が 1 回だけ通せるようにする」の「一致する許可があれば 1 回だけ通す」の手順を行う
- **THEN** `permit-log.jsonl` に `event` が `permit` の行（理由とコマンドを含む）と `use` の行がこの順にある

### Requirement: 別セッションの子の停止検知の条件を案内する

`skills/develop/references/epic.md` の手順 5 は、NO_ASK の印を起動側が付けた子は git ガードの確認画面で止まらず、拒否後に承認を求めてターンを終えた止まりを、会話ログが読めるとき `wait --watch-stopped` が検知することを案内しなければならない（MUST）。印の無い子の確認画面や会話ログを読めない子は検知できないという注意を維持しなければならない（MUST）。

#### Scenario: 手順 5 が検知できる止まりと検知できない止まりを区別する

- **WHEN** `epic.md` の手順 5 を読む
- **THEN** NO_ASK の印の名前、拒否後に承認を求めてターンを終えた子は会話ログから検知されること、確認画面で止まった子とログを読めない子は検知できないことが書かれている

### Requirement: 拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う

hook と許可を書くスクリプトは、`<base>` とその下の `denied/`・`permits/` を使う前に、それぞれを lstat で見て、symlink でない・ディレクトリ・持ち主が自分の uid・グループと他者に書き込み権が無い、をすべて満たすか確かめなければならない（MUST）。無いものは 0700 で作ってから確かめる（MUST）。`<base>` の親が無ければ作らず、満たさないものとする（MUST）。既にあって満たすフォルダのモードは変えない（0755 でも使う）。確かめと作成は `git-guard-scratchpad.py` の 1 か所で行う（MUST）。

#### 守備範囲

受け取る入力は、環境変数 `TMPDIR`、`<base>`・`denied/`・`permits/` を lstat で見た結果（種類・持ち主の uid・モード）、hook と許可を書くスクリプトを動かしている自分の uid である。拾いたい誤りは、別の uid が `<base>`（またはその下の `denied/`・`permits/`）を先に作るか別の場所への symlink にしておき、そこへ偽の許可を置いて子のコマンドを通させる・hook に symlink の先のファイルを上書きさせる・拒否の記録（コマンドの全文と cwd）を読むことである。次の入力は通すことを許す: 同じ uid のプロセス（子のサブエージェントを含む）が作った・差し替えた `<base>` とその中身（子による許可の偽造は別の change で扱う）／確かめてから使うまでの間に同じ uid のプロセスが差し替えたもの／既にある 0755 の `<base>` と、その中の読み取り権付きの記録（別の uid に読まれうるが、書き換えや偽造にはつながらない）／root が作った・書き換えたもの／`<base>` の祖先（`TMPDIR`・`/tmp`・macOS の `/var` → `/private/var`）が symlink であるもの。止めすぎる向きでは、自分で 0775 や 0777 に変えた自分の `<base>` も満たさないものとして扱い、子の許可が通らなくなるが、これは許す（理由文に満たさなかった条件が出るので、主が手で直せる）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない（design.md「Non-Goals」）。

#### Scenario: 新しく作る `<base>` は所有者だけが使える

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`TMPDIR` の下の `dev-workflow-git-guard/` と `denied/` のモードが 0700 になる

#### Scenario: 既にある 0755 の `<base>` はそのまま使う

- **WHEN** `TMPDIR` の下に自分の持ち物の `dev-workflow-git-guard` をモード 0755 で作り、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`denied/` に拒否の記録が作られ、`dev-workflow-git-guard` のモードは 0755 のまま

#### Scenario: グループか他者が書ける `<base>` は使わない

- **WHEN** `TMPDIR` の下に `dev-workflow-git-guard` をモード 0777 で作り、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「拒否の記録を作れなかった」が含まれ、`dev-workflow-git-guard/` の下に何も作られない

#### Scenario: `denied/` や `permits/` が symlink なら使わない

- **WHEN** 確かめを満たす `<base>` の下の `denied/`（別の試行では `permits/`）を別のディレクトリへの symlink にして、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「拒否の記録を作れなかった」が含まれ、symlink の先に何も作られない

### Requirement: `<base>` の中のファイルを symlink を辿らずに開き、所有者だけのモードで作る

`<base>` の中のファイル（回数・拒否の記録・許可・`permit-log.jsonl`・一時ファイル）は symlink を辿らずに開かなければならない（MUST）。新しく作るファイルは、予測できない名前・既にあれば失敗する排他的な作成・0600 で作り、回数・拒否の記録・許可はその一時ファイルからの `rename` で置く（MUST）。`permit-log.jsonl` は symlink を辿らない追記で開き、無ければ 0600 で作る（MUST）。`rename` で取った許可と、許可を書くスクリプトが読む拒否の記録も symlink を辿らずに読み、symlink なら読めないものとして扱う（MUST。取った許可は消し、許可を書くスクリプトは 0 以外で終わる）。

#### 守備範囲

受け取る入力は、確かめを満たした `<base>` の中の名前（回数のファイル・`denied/<key>.json`・`permits/<key>.json`・`permit-log.jsonl`・一時ファイル）が symlink かどうかとその中身、許可を書くスクリプトに引数で渡された拒否の記録のパスである。拾いたい誤りは、`<base>` の中の名前が別のファイルへの symlink にされていて、hook や許可を書くスクリプトがその先のファイル（自分が書けるリポジトリのファイルなど）を上書き・追記すること、symlink の先の偽の許可や記録を読んで使うこと、予測できる一時ファイルの名前を先に作られてそこへ書くことである。次の入力は通すことを許す: 同じ uid のプロセスが symlink でない普通のファイルとして直接置いた許可・拒否の記録（子による偽造は別の change で扱う）／ハードリンク（`O_NOFOLLOW` はハードリンクを見分けないが、別の uid は確かめを満たす `<base>` の中に名前を作れない）／`rename` で置く直前やその直後に同じ uid のプロセスが置き先を差し替えたもの／既にある 0644 などのファイル（モードを締め直さない）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 許可のファイルが symlink なら使わず、先を書き換えない

- **WHEN** 確かめを満たす `<base>` の下で、4 つの値が payload と一致し期限内で一時領域の判定を満たす許可の中身を書いたファイル C を `<base>` の外に置き、`permits/<key>.json` を C への symlink にしてから、その payload に `git checkout -- .` を渡す
- **THEN** `permissionDecision` が `deny` で、C の中身が変わらず残っている

#### Scenario: 新しく作るファイルは 0600

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** 拒否の記録と回数のファイルのモードが 0600 になる

#### Scenario: `<base>` の中の symlink の先を書き換えない

- **WHEN** 確かめを満たす `<base>` の下で、回数のファイルを別のファイル A への symlink に、`permit-log.jsonl` を別のファイル B への symlink にし、期限切れの許可を `permits/<key>.json` に置いてから、`agent_id` が `a1` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、A と B の中身が変わっていない

#### Scenario: symlink の拒否の記録からは許可を書かない

- **WHEN** `denied/<key>.json` を、中身が正しい記録の別のファイルへの symlink にしてから、そのパスで許可を書くスクリプトを実行する
- **THEN** 終了コードが 0 以外で、`permits/` に許可が無い

### Requirement: `<base>` を確かめられない子の呼び出しには deny だけを返す

確かめを満たさないとき、hook は子の呼び出しで許可を探さず、拒否の記録を書かず、回数を数えずに（2 回目以降の扱いと `"continue"` のキーも出さない）、`permissionDecision` を `deny` にしなければならない（MUST）。`permissionDecisionReason` には子向けの文に加えて、文字列「拒否の記録を作れなかった」・`<base>` のパス・満たさなかった条件・親に返す報告にコマンドの全文を書くことを含める（MUST）。拒否の記録のパスは載せない。

#### 守備範囲

受け取る入力は、要件「拒否の記録・回数・許可の置き場所（`<base>`）を確かめてから使う」の確かめの結果（満たしたか・満たさなかった条件・パス）と、payload の `agent_id`・`tool_input.command` である。拾いたい誤りは、確かめを満たさない場所へ記録や回数を書いて symlink の先を書き換えること、そこに置かれた許可で子のコマンドを通すこと、子に落ち度の無い環境の問題で子を打ち切ること、の 3 つである。次の入力は止める・通すことを許す: 自分で 0777 に変えた `<base>` など確かめを満たさない環境では、子の破壊的 git 操作は親の許可で通せなくなる（止めすぎる向き。打ち切らないので子は親に返り、主の呼び出しは止まらない）／確かめを満たさないあいだ、子が同じコマンドを何度打ち直しても打ち切られず毎回 1 回目として返る（通しすぎる向き。拒否は返るのでコマンドは実行されない）。1 台の Mac を別のユーザーが同時に使い、そのユーザーが先に `/tmp/dev-workflow-git-guard` を作る形は想定しない（エピック #1476 の本文の節「条件の答え」）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: `<base>` が symlink なら記録も回数も書かず、置かれた許可も使わない

- **WHEN** `TMPDIR` の下の `dev-workflow-git-guard` を別のディレクトリへの symlink にし、その先の `permits/<key>.json` に 4 つの値が一致し期限内の許可を置いてから、scratchpad の中の repo を `cwd` にした `agent_id` が `a1` の payload に `git checkout -- .` を 2 回渡す
- **THEN** どちらも `permissionDecision` が `deny` で、`permissionDecisionReason` に「拒否の記録を作れなかった」と `<base>` のパスが含まれ、「直ちに作業を終えて親に返す」が無く、出力に `"continue"` のキーが無い。symlink の先には `denied/` も回数のファイルも作られず、置いた許可が残っている

### Requirement: 主の呼び出しは `<base>` を作りも確かめもしない

主の呼び出し（`agent_id` が無い・空・文字列でない）では、hook は `<base>` を作りも確かめもしてはならず（MUST NOT）、`<base>` の状態で `ask` / `deny` と理由文を変えてはならない（MUST NOT）。主の対話セッションの確認画面と、印のあるセッションの `deny` は、`<base>` が他人に作られていても今までどおり出る。

#### 守備範囲

受け取る入力は payload の `agent_id` だけで、`<base>` の状態は見ない。拾いたい誤りは、`<base>` が symlink や他人の持ち物であることで、主の確認画面が出なくなる・理由文が変わる・主の呼び出しで `<base>` が作られることである。次の入力は通すことを許す: 主の呼び出しが続くあいだは、`<base>` が確かめを満たさなくても hook は何も知らせない（気づくのは子の呼び出しの拒否の理由文から）。この穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 主の呼び出しは `<base>` の状態によらず今までどおり

- **WHEN** `TMPDIR` の下の `dev-workflow-git-guard` を別のディレクトリへの symlink にして、`agent_id` の無い `permission_mode` が `default` の payload に `git reset --hard` を渡す
- **THEN** `permissionDecision` が `ask` で、理由文が `<base>` が正常なときと同じで、symlink の先に何も作られない

### Requirement: 許可を書くスクリプトは確かめを満たさない `<base>` に書かない

許可を書くスクリプトは、拒否の記録のパスの 2 つ上を `<base>` として確かめ、満たさないときは許可も `permit-log.jsonl` の行も書かず、回数のファイルも消さずに、満たさなかった条件と場所を stderr に書いて 0 以外で終わらなければならない（MUST）。親はこれを今までどおり「許可を書くスクリプトが 0 以外で終わった」としてオーナーに上げる（`skills/develop/SKILL.md` の手順は変えない）。

#### 守備範囲

受け取る入力は、許可を書くスクリプトに引数で渡された拒否の記録のパスと、その 2 つ上のディレクトリ（`<base>`）と `denied/`・`permits/` を lstat で見た結果である。拾いたい誤りは、別の uid が作った・symlink にした `<base>` の中に許可や `permit-log.jsonl` の行を書き、偽の許可が使える場所に親の許可を置いたり symlink の先を書き換えたりすることである。次の入力は止める・通すことを許す: 自分で 0777 に変えた自分の `<base>` の記録からも許可を書けない（止めすぎる向き。親はオーナーに上げ、オーナーが直す）／確かめてから書くまでの間に同じ uid のプロセスが `<base>` を差し替えたものには書く（通しすぎる向き。同じ uid は守らない）。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 確かめを満たさない `<base>` に許可を書かない

- **WHEN** 拒否の記録を書かせたあと、`<base>` のモードを 0777 に変えてから、その記録のパスで許可を書くスクリプトを実行する
- **THEN** 終了コードが 0 以外で、stderr に `<base>` のパスが含まれ、`permits/` に許可が無く、`permit-log.jsonl` に `permit` の行が無い

### Requirement: 子は Write / Edit / NotebookEdit で許可の置き場所に書けない

hook `scripts/git-guard-base-write-guard.sh` は、子（`agent_id` が空でない文字列）の書き先（Write / Edit は `tool_input.file_path`、NotebookEdit は `tool_input.notebook_path`）の部品のどれかが、大文字小文字を区別せずに `<base>` の名前 `dev-workflow-git-guard` と一致すれば、`permissionDecision` が `deny` の JSON を出さなければならない（MUST。`permits/` に限らず `<base>` の中はすべて）。書き先は、相対なら payload の `cwd` を前に付け、`..` を畳んだパスと、既にある部分の symlink を辿ったパスの両方で見る（MUST）。この hook は `<base>` を作らず、回数・拒否の記録・許可に触れない（MUST NOT。数えない）。

#### 守備範囲

この要件と、要件「子は Bash のコマンドで許可の置き場所を名指しできない」「許可の置き場所への書き込みの拒否は親に返すよう案内する」の目的は、ルールを読み飛ばした子が許可の置き場所に分かりやすく書こうとしたときに止めることで、セキュリティ境界ではない。子・hook・親は同じ uid で動き、hook が読める秘密は子も読めるので、子が作れない印で許可を見分けることはできない。受け取る入力は、Claude Code が PreToolUse で渡す payload のうち、子が指定するツール入力（`tool_name`・`tool_input.file_path`・`tool_input.notebook_path`・`tool_input.command`）と、Claude Code が付ける識別情報（`agent_id`・`cwd`。子はこれらを直接は指定しない）、書き先のパスを辿った時点のファイルシステム、環境変数 `DEV_WORKFLOW_GIT_GUARD` である。拾いたい誤りは、拒否された子が親に返らずに、Write / Edit / NotebookEdit ツールか、置き場所の名前を書いた Bash のコマンドで、自分で許可を置くことである。次の入力は通すことを許す: 変数や置換で組み立てたパス（`d=dev-workflow-git-; "$TMPDIR/${d}guard/permits/k.json"`）／グロブ（`"$TMPDIR"/dev-workflow-*/permits/k.json`、`.../dev-workflow-git-guard/p*/k.json`）／置き場所に移ってから `permits` の名前を書かずに書くもの（`cd .../dev-workflow-git-guard/perm*` のあとの書き込み）／スクリプトファイル・Makefile・別のファイルの中から書くもの／大文字小文字を変えた名前の Bash のコマンド（大文字小文字を区別しないファイルシステムでは同じ場所に届く）／Write / Edit / NotebookEdit 以外のツール（MCP のファイル書き込みなど）で書くもの／hook が書き先を辿ってから書かれるまでの間に、途中のフォルダが置き場所への symlink に差し替えられたもの／主の呼び出しが書くもの。通っても、許可が効くのは使う時点の一時領域の判定（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」）を満たす scratchpad の中だけである。次の入力は止めることを許す（止めすぎる向き）: このガードの置き場所そのものを扱う開発で、子が 2 つの名前を両方含むコマンド（spec の書き換え・grep・偽造の確かめ）を打つもの（2026-11-10 時点の会話ログで Bash の呼び出し 109,484 件のうち 8 件。子は親に返り、親が打つ）／置き場所の名前の部品を持つ、置き場所でないフォルダへの書き込み。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: Write / Edit / NotebookEdit で `<base>` の中に書くと拒否する

- **WHEN** 空の `TMPDIR` を T として、`agent_id` が `a1` の Write の payload の `file_path` を `T/dev-workflow-git-guard/permits/k.json` に、Edit の payload の `file_path` を `T/dev-workflow-git-guard/<回数のファイルの名前>` に、NotebookEdit の payload の `notebook_path` を `T/dev-workflow-git-guard/x.ipynb` にして、それぞれ新しい hook に渡す
- **THEN** どれも `permissionDecision` が `deny` で、出力に `"continue"` のキーが無く、T の下に何も作られない

#### Scenario: 書き先の書き方を変えても拒否する

- **WHEN** `agent_id` が `a1` の Write の payload の `file_path` を、`T/Dev-Workflow-Git-Guard/permits/k.json`・`T/x/../dev-workflow-git-guard/permits/k.json`・`cwd` を T にした相対パス `dev-workflow-git-guard/permits/k.json`・`T/dev-workflow-git-guard` を指す symlink `T/link` を経た `T/link/permits/k.json` にして、それぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になる

### Requirement: 置き場所への書き込みを止める hook の配線と逃げ道

dev-workflow は `scripts/git-guard-base-write-guard.sh` を、`hooks/hooks.json` の PreToolUse に `matcher: "Write|Edit|NotebookEdit"` で、`command` を `"${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-base-write-guard.sh"` と引用符で囲み、`if` を付けずに登録しなければならない（MUST）。PreToolUse の末尾は git ガードの Bash のエントリのまま保つ（MUST）。この hook は、主の呼び出し（`agent_id` が無い・空・文字列でない）・部品が一致しない書き先・`DEV_WORKFLOW_GIT_GUARD=off`・python3 が無い・stdin が JSON でない・payload がオブジェクトでない・`tool_name` が 3 つのどれでもない・書き先が文字列でないときは、何も出さずに exit 0 としなければならない（MUST）。

#### 守備範囲

要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲と同じ。

#### Scenario: 主の呼び出しと置き場所の外への書き込みは止めない

- **WHEN** `agent_id` の無い Write の payload の `file_path` を `T/dev-workflow-git-guard/permits/k.json` にしたもの、`agent_id` が `a1` の Write の payload の `file_path` を `plugins/dev-workflow/tests/git-destructive-guard.bats` と `T/notes/dev-workflow-git-guard.md` にしたもの、`DEV_WORKFLOW_GIT_GUARD=off` で `agent_id` が `a1` の `file_path` を `T/dev-workflow-git-guard/permits/k.json` にしたもの、`tool_name` が `Bash` の payload、JSON でない文字列を、それぞれ新しい hook に渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: 新しい hook が hooks.json に登録されている

- **WHEN** `plugins/dev-workflow/hooks/hooks.json` の PreToolUse を読む
- **THEN** `matcher` が `Write|Edit|NotebookEdit` で `"${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-base-write-guard.sh"` の command hook を持ち `if` の無いエントリがあり、配列の末尾は git ガードの `matcher` が `Bash` のエントリのままである

### Requirement: 子は Bash のコマンドで許可の置き場所を名指しできない

git ガード（`scripts/git-destructive-guard.sh`）は、子の呼び出しの `tool_input.command` のどこかに `dev-workflow-git-guard` と `permits` の両方が含まれるとき（部分文字列で、大文字小文字を区別する）、書き方を読み分けずに `deny` を返さなければならない（MUST。当たった種類は「許可の置き場所を名指しするコマンド」）。拒否の記録を書かず、許可を探さない（MUST NOT）。ほかの種類（破壊的 git 操作の 9 種・判定しきれなかったもの・許可を書くスクリプトの子からの呼び出し）に当たらなければ、回数を数えず `<base>` を作りも確かめもしない（MUST NOT）。当たれば今までどおり数える（MUST）。主の呼び出しはこの判定で止めない（MUST NOT）。

#### 守備範囲

要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲と同じ。2 つの名前の選び方と止めすぎの頻度の根拠は、この change の design.md の決定 2。

#### Scenario: Bash のコマンドに 2 つの名前があれば拒否し、数えない

- **WHEN** 空の `TMPDIR` を T として、`agent_id` が `a1` の payload に `printf '{}' > T/dev-workflow-git-guard/permits/k.json` を 2 回、続けて `cd T/dev-workflow-git-guard && python3 -c "open('permits/k.json','w')"` を 1 回渡す
- **THEN** どれも `permissionDecision` が `deny` で、「直ちに作業を終えて親に返す」は無く、出力に `"continue"` のキーが無い。T の下に `dev-workflow-git-guard/` が作られない

#### Scenario: 名前が 1 つだけのコマンドと主の呼び出しは止めない

- **WHEN** `agent_id` が `a1` の payload に `cat T/dev-workflow-git-guard/denied/k.json` と `echo permits` を、`agent_id` の無い `permission_mode` が `default` の payload に `printf '{}' > T/dev-workflow-git-guard/permits/k.json` を、それぞれ渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: 破壊的 git 操作も含むなら数えるが、記録を書かず許可も使わない

- **WHEN** scratchpad の中の repo を `cwd` にした `agent_id` が `a1` の payload のコマンド C を `git checkout -- . ; ls T/dev-workflow-git-guard/permits` として、4 つの値が C の payload と一致し期限内の許可を `permits/<key>.json` に置いてから、C を 2 回渡す
- **THEN** どちらも `permissionDecision` が `deny` で、2 回目の出力のトップレベルに `"continue": false` があり、置いた許可が残っていて、`denied/` に記録が無い

### Requirement: 許可の置き場所への書き込みの拒否は親に返すよう案内する

要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」と「子は Bash のコマンドで許可の置き場所を名指しできない」の拒否の `permissionDecisionReason` は、「許可の置き場所」を含み、打ち直さず別の書き方も試さずに作業を止め、要るものを報告に書いて親に返すよう案内しなければならない（MUST）。Bash の拒否では、このコマンドには拒否の記録を作らないことを、文字列「拒否の記録を作らない」を含む文で書かなければならない（MUST）。どちらの理由文も `dev-workflow-git-guard` と `permits` を両方は含んではならない（MUST NOT。子が理由文を報告用のコマンドに写したとき、そのコマンドが止まらないようにするため）。

#### 守備範囲

要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲と同じ。理由文の中身で子の振る舞いを縛ることはできず、案内に従わない子は止められない（拒否は返るのでコマンドは実行されない）。

#### Scenario: 理由文が親に返すよう案内し、2 つの名前を並べない

- **WHEN** `agent_id` が `a1` の Write の payload の `file_path` を `T/dev-workflow-git-guard/permits/k.json` にして新しい hook に渡し、`agent_id` が `a1` の payload に `printf '{}' > T/dev-workflow-git-guard/permits/k.json` を git ガードに渡す
- **THEN** どちらの `permissionDecisionReason` にも「許可の置き場所」と「親に返す」が含まれ、`dev-workflow-git-guard` と `permits` の両方は含まれない。git ガードの理由文には「許可の置き場所を名指しするコマンド」と「拒否の記録を作らない」が含まれる
