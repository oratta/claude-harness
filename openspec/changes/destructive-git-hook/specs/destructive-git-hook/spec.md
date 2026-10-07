## ADDED Requirements

### Requirement: 破壊的 git 操作を Bash の実行前に検出する

dev-workflow は PreToolUse の command hook `scripts/git-destructive-guard.sh` を持ち、`hooks/hooks.json` の PreToolUse に `matcher: "Bash"` で登録しなければならない（MUST）。hooks.json の `command` は `"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh"` のように引用符で囲む（MUST）。対象の絞り込みは hooks.json の `if` で行わず、スクリプトが判定する（MUST。一覧を 1 か所に置き、bats で検査できるようにするため）。

スクリプトは payload を stdin から読み、`tool_input.command` に次のいずれかが含まれるとき、`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":<ask|deny>,"permissionDecisionReason":...}}` を stdout に出して exit 0 としなければならない（MUST）:

1. `git checkout` で `--` の後ろにパスがある、または引数が `.` だけ（作業の破棄）
2. `git restore`（`--staged` / `-S` だけを付けて `--worktree` / `-W` を付けないものを除く）
3. `git reset --hard`
4. `git clean` で `-f` / `--force`（`-fd` `-xdf` のようにまとめた短いオプションを含む）があり、`-n` / `--dry-run` が無い
5. `git push` の送り先が `main` / `master`（`main`、`+main`、`refs/heads/main`、`HEAD:main`、`<src>:main`、`:main`、`--delete main` を含む。master も同じ。remote 名は問わない）
6. `git push` に `--force` / `-f`（まとめた短いオプションを含む）/ `--force-with-lease[=...]` がある、または `+` で始まる refspec がある
7. `git branch -D`、または `-d` / `--delete` と `-f` / `--force` の組み合わせ（`-df` を含む）
8. git のサブコマンドに `--no-verify` がある、または `git commit -n`
9. git のサブコマンドに `--no-gpg-sign` がある

判定は単純コマンドごとに行い、次の形の中も同じ判定にかけなければならない（MUST）: `&&` `||` `;` `|` `&` 改行で連結したコマンド、`$(...)` とバッククォートの中、`bash` / `sh` / `zsh` の `-c` の引数、`eval` の引数。単純コマンドの先頭の環境変数代入と `command` / `env` / `sudo` / `nohup` / `time` は読み飛ばし、git の大域オプション（`-C <path>`、`-c <k=v>`、`--git-dir`、`--work-tree`、`--namespace`、`--no-pager`、`-P` など）を読み飛ばしてサブコマンドを決めなければならない（MUST）。引用符の中の文字列や、git が単純コマンドの先頭に無いもの（`echo git reset --hard`）は対象にしてはならない（MUST NOT）。

#### Scenario: 対象 9 種が止まる

- **WHEN** `git checkout -- a.txt`、`git restore a.txt`、`git reset --hard`、`git clean -fd`、`git push origin main`、`git push --force origin feature-x`、`git branch -D feature-x`、`git commit --no-verify -m x`、`git commit --no-gpg-sign -m x` をそれぞれ `tool_input.command` に入れた Bash の payload を hook に渡す
- **THEN** どれも exit 0 で、`permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 連結・置換・大域オプションの中も止まる

- **WHEN** `cd x && git reset --hard`、`echo $(git reset --hard)`、`bash -c 'git push -f origin x'`、`git -C repo reset --hard`、`git -c core.x=y push origin HEAD:master`、`FOO=1 git clean -xdf` を渡す
- **THEN** どれも `permissionDecision` が `ask` か `deny` の JSON が出る

#### Scenario: 対象外のコマンドは何も出さない

- **WHEN** `git status`、`git push origin feature-x`、`git push -u origin oratta/issue-710`、`git checkout feature-x`、`git restore --staged a.txt`、`git clean -n`、`git branch -d feature-x`、`git commit -m "--no-verify を外す"`、`echo git reset --hard`、`ls` を渡す
- **THEN** どれも exit 0 で、何も出力しない

#### Scenario: hooks.json に登録されている

- **WHEN** `plugins/dev-workflow/hooks/hooks.json` の PreToolUse を読む
- **THEN** `matcher` が `Bash` のエントリに `"${CLAUDE_PLUGIN_ROOT}/scripts/git-destructive-guard.sh"` の command hook があり、そのエントリに `if` が無い

### Requirement: 確認画面が出るモードでだけ ask を返す

`permissionDecision` は payload の `permission_mode` で決めなければならない（MUST）: `default` / `acceptEdits` / `plan` は `ask`、それ以外（`bypassPermissions`・`dontAsk`・`auto`・未知の値・欠落）は `deny`。この対応は実装の最初の実機確認（design.md「`ask` と `deny` は payload の `permission_mode` で切り替える」の判定条件）の結果で確定し、`-p` の `default` で `ask` が実行を止めないと分かった場合は全モードを `deny` にしなければならない（MUST）。bypassPermissions を `ask` に移してよいのは、対話セッションで確認画面が出ることを確かめたときだけである（MUST）。

環境変数 `DEV_WORKFLOW_GIT_GUARD_FORCE` が `ask` か `deny` のときは、`permission_mode` によらずその値を返さなければならない（MUST。実機確認と bats のための上書き）。

#### Scenario: 確認画面が出るモードでは ask

- **WHEN** `permission_mode` が `default` の payload で `git reset --hard` を渡す
- **THEN** `permissionDecision` が `ask` になる

#### Scenario: bypassPermissions と不明なモードでは deny

- **WHEN** `permission_mode` が `bypassPermissions` の payload、`permission_mode` が無い payload、`permission_mode` が `somethingNew` の payload で `git reset --hard` を渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 上書きの環境変数が効く

- **WHEN** `DEV_WORKFLOW_GIT_GUARD_FORCE=ask` を付けて、`permission_mode` が `bypassPermissions` の payload で `git reset --hard` を渡す
- **THEN** `permissionDecision` が `ask` になる

### Requirement: 拒否理由は承認の取り方を案内する

`permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（9 種のどれか。複数当たればすべて）／規範の正本が `rules/destructive-git-guard.md` であること／実行せず主に承認を求めること／`deny` のときは、承認されたら主が自分で実行すること（Claude Code の入力欄で `!` を付けるか、自分の端末で）／言い換えたコマンドで再実行して hook を避けないこと。実機確認で `!` の入力も PreToolUse hook に止められると分かった場合は、`!` の案内を外さなければならない（MUST）。コマンドに付けて hook を通す目印（環境変数の前置など）を案内してはならない（MUST NOT）。

#### Scenario: deny の理由に承認の取り方が書かれている

- **WHEN** `permission_mode` が `bypassPermissions` の payload で `git push origin main` を渡す
- **THEN** `permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

### Requirement: 逃げ道と fail-open

`DEV_WORKFLOW_GIT_GUARD=off` のときは何も出さずに exit 0 としなければならない（MUST）。`tool_name` が `Bash` でない、`tool_input.command` が文字列でない、stdin が JSON として読めない、python3 が無いときは fail-open（exit 0・無出力）としなければならない（MUST）。`tool_input.command` に `git` の文字列が含まれないときは python3 を起動せずに exit 0 としなければならない（MUST。Bash 呼び出しごとの負荷を抑えるため）。`shlex` が引用符の不整合で字句に分けられないときは、空白で割った字句に同じ判定をかけなければならない（MUST。判定を諦めて素通りにしない）。

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

`rules/destructive-git-guard.md` は、承認なしに実行しない操作の一覧と既存の目印（`always-on-injection-scope` の要件）を短い形で残したうえで、次の 2 点を本文に書かなければならない（MUST）: 一覧の操作は dev-workflow の hook が実行前に止めること（止まったら言い換えて再実行せず主に聞く）／hook はコマンド文字列しか見ないので、push 済みの `git commit --amend`、`git rebase -i`、ブランチ名を書かない `git push`、スクリプトファイル経由の git は止まらないこと。`rules/README.md` の該当行はこの分担に合わせて直さなければならない（MUST）。`DEV_WORKFLOW_GIT_GUARD_FORCE` はルール本文に書いてはならない（MUST NOT）。

#### Scenario: ルール本文に hook との分担がある

- **WHEN** `rules/destructive-git-guard.md` を読む
- **THEN** hook が一覧の操作を止めることと、hook で止まらないもの（push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）が書かれ、`tests/always-on-injection-scope.bats` の目印がすべて残っている

#### Scenario: 上書きの環境変数がルールに無い

- **WHEN** `rules/destructive-git-guard.md` を `DEV_WORKFLOW_GIT_GUARD_FORCE` で検索する
- **THEN** 見つからない
