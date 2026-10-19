## MODIFIED Requirements

### Requirement: 確認画面が出るモードでだけ ask を返す

payload の `agent_id` が空でない文字列のとき（サブエージェントから呼ばれたとき。`context-tripwire.sh` と同じ判定）は、`permission_mode` にも `DEV_WORKFLOW_GIT_GUARD_FORCE` にもよらず `deny` を返さなければならない（MUST）。親は子の確認画面に応答できず、子が止まっていることも分からないので、子に `ask` を返してはならない（MUST NOT）。`agent_id` が無い・文字列でない・空のときは、以下の規則で決める。

`permissionDecision` は payload の `permission_mode` で決めなければならない（MUST）: `default` / `acceptEdits` / `plan` / `bypassPermissions` は `ask`、それ以外（`dontAsk`・`auto`・未知の値・欠落）は `deny`。この対応は実機確認（design.md「`ask` と `deny` は payload の `permission_mode` で切り替える」の判定条件。対照実験を含む）で確定した: `-p` では `default` と `bypassPermissions` のどちらでも `ask` が実行を止め、対話セッションの `bypassPermissions` では `ask` で主が承認できる確認画面が出た。`ask` が `-p` で実行を止めない、または対話セッションで確認画面を出さないと分かったモードは、`deny` に戻さなければならない（MUST）。

環境変数 `DEV_WORKFLOW_GIT_GUARD_FORCE` が `ask` か `deny` のときは、`permission_mode` によらずその値を返さなければならない（MUST。実機確認と bats のための上書き）。ただし子の呼び出しには効かない（上の段落が先に決める）。

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

- **WHEN** `agent_id` が空でない文字列で `permission_mode` が `default` の payload、同じく `bypassPermissions` の payload に `git checkout -- a` を渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: 子には上書きの環境変数が効かない

- **WHEN** `DEV_WORKFLOW_GIT_GUARD_FORCE=ask` を付けて、`agent_id` が空でない文字列で `permission_mode` が `default` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` になる

#### Scenario: agent_id が空なら主の呼び出しとして扱う

- **WHEN** `agent_id` が空文字の payload、`agent_id` が数値の payload で、`permission_mode` が `default` のものに `git checkout -- a` を渡す
- **THEN** どれも `permissionDecision` が `ask` になる

### Requirement: 拒否理由は承認の取り方を案内する

`agent_id` の無い呼び出しへの `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（9 種のどれか。複数当たればすべて）／規範の正本が `rules/destructive-git-guard.md` であること／実行せず主に承認を求めること／承認されたら主が自分で実行すること（Claude Code の入力欄で `!` を付けるか、自分の端末で。`ask` のときは、確認画面が出ないセッション（`claude -p` など）ではそうすること）／`ask` のときは、確認画面を出していること／言い換えたコマンドで再実行して hook を避けないこと。`!` の入力は PreToolUse hook を通らない（対話セッションで `! git reset --hard` が止められずに実行されることを確かめた）ので、`!` の案内を残す。コマンドに付けて hook を通す目印（環境変数の前置など）を案内してはならない（MUST NOT）。

子（`agent_id` が空でない文字列）への `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行されないこと／打ち直さず、別の書き方も試さないこと（文字列「打ち直さず」を含む）／scratchpad の検証用 repo なら git で戻さず作り直すこと／それ以外は作業を止め、何を・なぜ実行したかったかを報告に書いて親に返すこと。子への理由に、確認画面を出していること、`!` を付けて打つことを書いてはならない（MUST NOT。主に上げるのは親の役目で、子が自分で主に聞こうとして止まる余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

#### Scenario: deny の理由に承認の取り方が書かれている

- **WHEN** `agent_id` の無い、`permission_mode` が `auto` の payload で `git push origin main` を渡す
- **THEN** `permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: ask の理由に確認画面と、画面が出ないときの取り方が書かれている

- **WHEN** `agent_id` の無い、`permission_mode` が `bypassPermissions` の payload で `git push origin main` を渡す
- **THEN** `permissionDecision` が `ask` で、`permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、確認画面を出していること、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: 子への理由は親に返すよう案内する

- **WHEN** `agent_id` が空でない文字列で `permission_mode` が `default` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecisionReason` に、作業の破棄に当たったこと、`rules/destructive-git-guard.md`、「打ち直さず」、scratchpad の検証用 repo なら作り直すこと、何を・なぜを報告に書いて親に返すことが含まれ、「確認画面」と `!` を付けて打つ案内と `DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

### Requirement: ルール本文と hook の分担

`rules/destructive-git-guard.md` は既存の文を外さず（`always-on-injection-scope` の「縮約は削除ではなく移設」と、一覧・目印を本文に残す要件のため）、次の 3 点を足さなければならない（MUST）: 一覧の操作は dev-workflow の hook が実行前に止めること（止まったら言い換えて再実行せず主に聞く。拒否されたセッションでは承認後も主が自分で実行する）／hook はコマンド文字列しか見ないので、push 済みの `git commit --amend`、`git rebase -i`、ブランチ名を書かない `git push`、スクリプトファイル経由の git は止まらないこと／サブエージェントから呼ばれたときは確認画面を出さずに拒否され、子は打ち直さず作業を止めて親に返ること。目印「例外なく事前承認」を含む文は変えてはならない（MUST NOT）。`rules/README.md` の該当行はこの分担に合わせて直さなければならない（MUST）。`DEV_WORKFLOW_GIT_GUARD_FORCE` はルール本文に書いてはならない（MUST NOT）。

#### Scenario: ルール本文に hook との分担がある

- **WHEN** `rules/destructive-git-guard.md` を読む
- **THEN** hook が一覧の操作を止めること、拒否されたら承認後も主が実行すること、hook で止まらないもの（push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）、サブエージェントは確認画面を出さずに拒否されて親に返ることが書かれ、変更前の本文の文がすべて残り、`tests/always-on-injection-scope.bats` の目印がすべて残っている

#### Scenario: 上書きの環境変数がルールに無い

- **WHEN** `rules/destructive-git-guard.md` を `DEV_WORKFLOW_GIT_GUARD_FORCE` で検索する
- **THEN** 見つからない

#### Scenario: README の該当行が子の扱いに触れる

- **WHEN** `rules/README.md` の `destructive-git-guard.md` の行を読む
- **THEN** サブエージェントは確認画面を出さずに拒否されて親に返ることが書かれている

## ADDED Requirements

### Requirement: 同じ子への拒否の繰り返しを打ち切る

子（`agent_id` が空でない文字列）に `deny` を返すたびに、`session_id` と `agent_id` の組ごとの拒否の回数を一時ディレクトリ（`TMPDIR`）の下のファイルに数えなければならない（MUST）。ファイル名は `session_id` と `agent_id` から導いたハッシュとし、`agent_id` や `session_id` をそのままパスに使ってはならない（MUST NOT）。回数のファイルを作れない・読めない・中身が整数でないときは、その呼び出しを 1 回目として扱い、`deny` は返さなければならない（MUST。数えられないことで通してはならない）。

同じ組への 2 回目以降の `deny` では、`permissionDecisionReason` に「直ちに作業を終えて親に返す」を含めなければならない（MUST）。加えて、出力のトップレベルに `"continue": false` と `stopReason` を含めるかは実装段の実機確認（design.md「2 回目以降の拒否」）の結果で決める:

- 子の中で `continue: false` を返すと子だけが終わり、親が子の結果を受け取って続けると確かめた場合は、`"continue": false` と `stopReason` を含めなければならない（MUST）
- 親まで止まると分かった場合、または確かめられなかった場合は、`"continue"` のキーを出力してはならない（MUST NOT）

どちらに決めたかと実機確認の結果は、この change の design.md と PR 本文に記録しなければならない（MUST）。1 回目の `deny` には `"continue"` のキーを出力してはならない（MUST NOT）。`agent_id` の無い呼び出しは数えず、出力も変えない（MUST）。

#### Scenario: 1 回目は打ち切らない

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を 1 回渡す
- **THEN** `permissionDecision` が `deny` で、出力に `"continue"` のキーが無く、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無い

#### Scenario: 同じ子への 2 回目は強く返す

- **WHEN** 同じ `TMPDIR` で、`agent_id` が `a1` で同じ `session_id` の payload に `git checkout -- b` を続けて渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が含まれ、実機確認で子だけが終わると確かめた場合は出力のトップレベルに `"continue": false` と `stopReason` が含まれ、そうでない場合は `"continue"` のキーが無い

#### Scenario: 別の子は 1 回目として数える

- **WHEN** `agent_id` が `a1` の payload で 1 回拒否されたあと、同じ `TMPDIR` で `agent_id` が `a2` の payload に `git checkout -- a` を渡す
- **THEN** 出力に `"continue"` のキーが無く、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無い

#### Scenario: 回数を数えられなくても拒否する

- **WHEN** 書き込めないディレクトリを `TMPDIR` にして、`agent_id` が `a1` の payload に `git checkout -- a` を 2 回渡す
- **THEN** どちらも `permissionDecision` が `deny` になる

#### Scenario: 主の呼び出しは数えない

- **WHEN** 空の `TMPDIR` で、`agent_id` の無い、`permission_mode` が `auto` の payload に `git reset --hard` を 2 回渡す
- **THEN** どちらも出力に `"continue"` のキーが無く、`TMPDIR` の下に回数のファイルが作られない

### Requirement: 子の定義に検証用 repo の戻し方を書く

dev-workflow の `agents/reviewer.md`・`agents/worker.md`・`agents/gate-runner.md` の本文は、scratchpad の検証用 repo は git の破壊的操作で戻さず作り直すことを、文字列「作り直す」を含む文で書かなければならない（MUST）。scratchpad 内の repo への破壊的操作を hook が許可する仕組みを足してはならない（MUST NOT。コマンドの中で変数を作ってから使う形を hook は展開できず、行き先を判定できないため）。

#### Scenario: 3 つの定義に戻し方がある

- **WHEN** `plugins/dev-workflow/agents/reviewer.md`・`worker.md`・`gate-runner.md` の本文を読む
- **THEN** どれにも、scratchpad の検証用 repo は git の破壊的操作で戻さず作り直すことが「作り直す」を含む文で書かれている
