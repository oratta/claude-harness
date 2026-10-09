## MODIFIED Requirements

### Requirement: 破壊的 git 操作を Bash の実行前に検出する

dev-workflow は PreToolUse の command hook `scripts/git-destructive-guard.sh` を持ち、`hooks/hooks.json` の PreToolUse 配列の末尾に `matcher: "Bash"` で登録しなければならない（MUST）。hooks.json の `command` は `"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh"` のように引用符で囲む（MUST）。対象の絞り込みは hooks.json の `if` で行わず、スクリプトが判定する（MUST。一覧を 1 か所に置き、bats で検査できるようにするため）。

スクリプトは payload を stdin から読み、`tool_input.command` に次のいずれかが含まれるとき、`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":<ask|deny>,"permissionDecisionReason":...}}` を stdout に出して exit 0 としなければならない（MUST）:

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

守備範囲: この要件の目的は、ルールを読み飛ばした Claude が一覧の操作をそのまま打ったときに止めることで、セキュリティ境界ではない。受け取る入力は次の 2 つに限る。1 つ目は、Claude Code が PreToolUse で hook の stdin に渡す Bash 呼び出しの payload（`tool_name`、`tool_input.command`、`permission_mode`）で、`tool_input.command` はエージェント（本体やサブエージェント）が書く値である。2 つ目は、利用者が自分で設定する環境変数 `DEV_WORKFLOW_GIT_GUARD` と `DEV_WORKFLOW_GIT_GUARD_FORCE` である。拾いたい誤りは、上の 9 種のいずれかを、コマンド文字列にそのまま書いて実行しようとすることである（連結・コマンド置換・`bash -c`・git の大域オプションを挟んだ形を含む）。次の入力は通ることを許す: 変数や置換でサブコマンドや引数を組み立てた形（`git $SUB --hard`、`SUB=reset; git $SUB --hard`）／git の alias（`git config alias.nuke 'reset --hard'` を定義したうえでの `git nuke`）や git を包むシェル関数・エイリアス／スクリプトファイル・Makefile・npm scripts の中で実行される git（`bash cleanup.sh`、`make clean`）／ブランチ名を書かない `git push` や `git push origin HEAD`（現在のブランチが main でも当たらない）／push 済みの `git commit --amend` と `git rebase -i`（リポジトリの状態を見ないと判定できない）／引用符の中の文字列（`git commit -m "--no-verify を外す"`）と、git が単純コマンドの先頭に無いもの（`echo git reset --hard`）／ヒアドキュメントの本文と引用符の中の改行より後ろの行に書いた git（`git commit -F - <<EOF` の本文や複数行の `-m "..."` の 2 行目以降。シェルはこれをコマンドとして実行しない）／python3 が無い・stdin が JSON として読めない・payload がオブジェクトでない・`tool_name` が `Bash` でない・`tool_input.command` が文字列でないときは判定せずに通す（fail-open）／`DEV_WORKFLOW_GIT_GUARD=off` のときはすべて通す／値を取らないオプションの省略形（`git reset --har`、`git clean --forc`）／`env` 以外の wrapper の値を取るオプション（`sudo -u root git reset --hard`）と、1 字句にクォートした `env -S 'git reset --hard'`／`--no-dry-run` 以外の打ち消し（`--no-force`、`--verify` など）は読まない（`git push --force --no-force origin feature-x` のように、止めすぎる向きに出るものを含む）。これらの穴を見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。穴のうちルール本文で補うもの（push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）は、要件「ルール本文と hook の分担」で本文に書く。

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

