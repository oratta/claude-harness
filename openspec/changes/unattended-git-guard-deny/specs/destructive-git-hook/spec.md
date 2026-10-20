## MODIFIED Requirements

### Requirement: 確認画面が出るモードでだけ ask を返す

payload の `agent_id` が空でない文字列のとき（サブエージェントから呼ばれたとき。`context-tripwire.sh` と同じ判定）は、`permission_mode` にも `DEV_WORKFLOW_GIT_GUARD_FORCE` にもよらず `deny` を返さなければならない（MUST）。親は子の確認画面に応答できず、子が止まっていることも分からないので、子に `ask` を返してはならない（MUST NOT）。`agent_id` が無い・文字列でない・空のときは、以下の規則で決める。

環境変数 `DEV_WORKFLOW_UNATTENDED` は「このセッションの画面を見ている人がいない」という印で、セッションを起動する側（flatmate の住人の `boot.sh` など）が claude の環境に入れる。値の前後の空白を除いたものが空（未設定を含む）か `0` なら印なし、それ以外の値はすべて印ありとして扱わなければならない（MUST。付け損ねた値で確認画面に戻らず、止めすぎる向きにだけ外れるため）。印のあるセッションでは、主の呼び出しにも `permission_mode` にも `DEV_WORKFLOW_GIT_GUARD_FORCE` にもよらず `deny` を返さなければならない（MUST）。画面を見ている人がいないので、確認画面は誰にも押されず、セッションが止まったままになるため。印の無いセッションでは、以下の `permission_mode` と `DEV_WORKFLOW_GIT_GUARD_FORCE` の規則で決める。

`permissionDecision` は payload の `permission_mode` で決めなければならない（MUST）: `default` / `acceptEdits` / `plan` / `bypassPermissions` は `ask`、それ以外（`dontAsk`・`auto`・未知の値・欠落）は `deny`。この対応は実機確認（design.md「`ask` と `deny` は payload の `permission_mode` で切り替える」の判定条件。対照実験を含む）で確定した: `-p` では `default` と `bypassPermissions` のどちらでも `ask` が実行を止め、対話セッションの `bypassPermissions` では `ask` で主が承認できる確認画面が出た。`ask` が `-p` で実行を止めない、または対話セッションで確認画面を出さないと分かったモードは、`deny` に戻さなければならない（MUST）。

環境変数 `DEV_WORKFLOW_GIT_GUARD_FORCE` が `ask` か `deny` のときは、`permission_mode` によらずその値を返さなければならない（MUST。実機確認と bats のための上書き）。ただし子の呼び出しと、印のあるセッションの主の呼び出しには効かない（上の段落が先に決める）。

以下、`agent_id` が無い・空・文字列でない呼び出しを「主の呼び出し」、`agent_id` が空でない文字列の呼び出しを「子の呼び出し」と呼ぶ。`DEV_WORKFLOW_UNATTENDED` の印があるセッションを「無人のセッション」、印の無いセッションを「対話のセッション」と呼ぶ。

守備範囲: 子と主の見分けは、要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲の入力に、Claude Code が PreToolUse で hook の stdin に渡す payload の `agent_id`（Claude Code が子の呼び出しに付ける値で、エージェントが書く `tool_input.command` とは別のフィールド）を足す。拾いたい誤りは、子が破壊的 git 操作を打ったときに主の確認画面が出て、親が応答も検知もできず、主が画面を見るまでワークフロー全体が止まることである。次の入力は通すこと（または今までどおり確認画面を出すこと）を許す: Claude Code の版や起動経路によって子の payload に `agent_id` が入らない呼び出し（主の呼び出しとして扱われ、`permission_mode` と `DEV_WORKFLOW_GIT_GUARD_FORCE` の規則に従う）／`DEV_WORKFLOW_GIT_GUARD=off` のセッションで子が打つもの（すべて通る）／要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲で通ることを許した形を子が打つもの（変数で組み立てた形やスクリプトファイル経由など）。止めすぎる向きでは、主が子に破壊的操作を任せた場合も子では実行できず、親か主が打つことになるが、これは許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

守備範囲: 無人のセッションの見分けは、守備範囲の入力に hook のプロセスの環境変数 `DEV_WORKFLOW_UNATTENDED`（セッションを起動する側が付ける値で、payload とは別）を足す。拾いたい誤りは、画面を見ている人のいない `bypassPermissions` などの対話 TUI（flatmate の住人）で確認画面が出て、誰も押さずにセッションが止まり、セッション cron とチャンネルの受信も止まることである。次の入力は今までどおり確認画面を出すことを許す: 起動する側が印を付けなかったセッション（住人が tmux などで別に起動したセッションが、起動した側の環境を引き継がなかったものを含む）。止めすぎる向きでは、印のあるセッションをオーナーが Remote Control や tmux の画面で見ていても確認画面が出ず、オーナーが自分で実行することになるが、これは許す。これらの穴（印が届かないセッション）を塞ぎ切ることは、この要件の完了条件にしない。起動したセッションへの印の引き継ぎは #1123・#1126 で扱う。

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

- **WHEN** `DEV_WORKFLOW_UNATTENDED=1` を付けて、`agent_id` が空でない文字列で `permission_mode` が `bypassPermissions` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` は子への理由（「打ち直さず」と親に返す案内を含み、「チャンネル」を含まない）になる

#### Scenario: off は無人のセッションでも全許可

- **WHEN** `DEV_WORKFLOW_GIT_GUARD=off` と `DEV_WORKFLOW_UNATTENDED=1` を付けて `git reset --hard` を渡す
- **THEN** exit 0 で何も出力しない

### Requirement: 拒否理由は承認の取り方を案内する

対話のセッションの主の呼び出し（`agent_id` が無い・空・文字列でない）への `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（9 種のどれか。複数当たればすべて）／規範の正本が `rules/destructive-git-guard.md` であること／実行せず主に承認を求めること／承認されたら主が自分で実行すること（Claude Code の入力欄で `!` を付けるか、自分の端末で。`ask` のときは、確認画面が出ないセッション（`claude -p` など）ではそうすること）／`ask` のときは、確認画面を出していること／言い換えたコマンドで再実行して hook を避けないこと。`!` の入力は PreToolUse hook を通らない（対話セッションで `! git reset --hard` が止められずに実行されることを確かめた）ので、`!` の案内を残す。コマンドに付けて hook を通す目印（環境変数の前置など）を案内してはならない（MUST NOT）。

無人のセッションの主の呼び出しへの `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行していないこと／何を・なぜ・いつ実行するかをチャンネル（Discord など）でオーナーに伝えて承認を求めること（文字列「チャンネル」と「オーナー」を含む）／承認されたらオーナーが自分で実行すること／言い換えたコマンドで再実行して hook を避けないこと。無人のセッションへの理由に、確認画面の話（文字列「確認画面」）を書いてはならない（MUST NOT。出していない確認画面の操作を待って止まる余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

子の呼び出し（`agent_id` が空でない文字列）への `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行されないこと／打ち直さず、別の書き方も試さないこと（文字列「打ち直さず」を含む）／scratchpad の検証用 repo なら git で戻さず作り直すこと／それ以外は作業を止め、何を・なぜ実行したかったかを報告に書いて親に返すこと。子への理由に、確認画面を出していること、`!` を付けて打つことを書いてはならない（MUST NOT。主に上げるのは親の役目で、子が自分で主に聞こうとして止まる余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

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
- **THEN** `permissionDecisionReason` に、作業の破棄に当たったこと、`rules/destructive-git-guard.md`、「打ち直さず」、scratchpad の検証用 repo なら作り直すこと、何を・なぜを報告に書いて親に返すことが含まれ、「確認画面」と `!` を付けて打つ案内と `DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

### Requirement: ルール本文と hook の分担

`rules/destructive-git-guard.md` は既存の文を外さず（`always-on-injection-scope` の「縮約は削除ではなく移設」と、一覧・目印を本文に残す要件のため）、次の 4 点を足さなければならない（MUST）: 一覧の操作は dev-workflow の hook が実行前に止めること（止まったら言い換えて再実行せず主に聞く。拒否されたセッションでは承認後も主が自分で実行する）／hook はコマンド文字列しか見ないので、push 済みの `git commit --amend`、`git rebase -i`、ブランチ名を書かない `git push`、スクリプトファイル経由の git は止まらないこと／サブエージェントから呼ばれたときは確認画面を出さずに拒否され、子は打ち直さず作業を止めて親に返ること／画面を見ている人のいないセッション（起動時に無人の印を付けたセッション）でも確認画面を出さずに拒否されるので、チャンネルで主に承認を求めること。印の環境変数の名前はルール本文に書かなくてよい（MAY。起動する側の設定で、ルールを読む Claude が付け外しするものではないため）。目印「例外なく事前承認」を含む文は変えてはならない（MUST NOT）。`rules/README.md` の該当行はこの分担に合わせて直さなければならない（MUST）。`DEV_WORKFLOW_GIT_GUARD_FORCE` はルール本文に書いてはならない（MUST NOT）。

#### Scenario: ルール本文に hook との分担がある

- **WHEN** `rules/destructive-git-guard.md` を読む
- **THEN** hook が一覧の操作を止めること、拒否されたら承認後も主が実行すること、hook で止まらないもの（push 済みの `--amend`、`rebase -i`、ブランチ名を書かない push、スクリプト経由）、サブエージェントは確認画面を出さずに拒否されて親に返ること、画面を見ている人のいないセッションでも確認画面を出さずに拒否されてチャンネルで主に承認を求めることが書かれ、変更前の本文の文がすべて残り、`tests/always-on-injection-scope.bats` の目印がすべて残っている

#### Scenario: 上書きの環境変数がルールに無い

- **WHEN** `rules/destructive-git-guard.md` を `DEV_WORKFLOW_GIT_GUARD_FORCE` で検索する
- **THEN** 見つからない

#### Scenario: README の該当行が子と無人のセッションの扱いに触れる

- **WHEN** `rules/README.md` の `destructive-git-guard.md` の行を読む
- **THEN** サブエージェントは確認画面を出さずに拒否されて親に返ること、画面を見ている人のいないセッションでも確認画面を出さずに拒否されてチャンネルで主に承認を求めることが書かれている

