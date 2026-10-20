## MODIFIED Requirements

### Requirement: 拒否理由は承認の取り方を案内する

対話のセッションの主の呼び出し（`agent_id` が無い・空・文字列でない）への `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（9 種のどれか。複数当たればすべて）／規範の正本が `rules/destructive-git-guard.md` であること／実行せず主に承認を求めること／承認されたら主が自分で実行すること（Claude Code の入力欄で `!` を付けるか、自分の端末で。`ask` のときは、確認画面が出ないセッション（`claude -p` など）ではそうすること）／`ask` のときは、確認画面を出していること／言い換えたコマンドで再実行して hook を避けないこと。`!` の入力は PreToolUse hook を通らない（対話セッションで `! git reset --hard` が止められずに実行されることを確かめた）ので、`!` の案内を残す。コマンドに付けて hook を通す目印（環境変数の前置など）を案内してはならない（MUST NOT）。

無人のセッションの主の呼び出しへの `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行していないこと／何を・なぜ・いつ実行するかをチャンネル（Discord など）でオーナーに伝えて承認を求めること（文字列「チャンネル」と「オーナー」を含む）／承認されたらオーナーが自分で実行すること／言い換えたコマンドで再実行して hook を避けないこと。無人のセッションへの理由に、確認画面の話（文字列「確認画面」）を書いてはならない（MUST NOT。出していない確認画面の操作を待って止まる余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

子の呼び出し（`agent_id` が空でない文字列）への `deny` の `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行されないこと／打ち直さず、別の書き方も試さないこと（文字列「打ち直さず」を含む）／scratchpad の検証用 repo なら git で戻さず作り直すこと／それ以外は作業を止め、報告に次の 4 項目を書いて親に返すこと（打ちたかったコマンドの全文、対象のパス、その対象を自分で作ったか（作ったなら、作ったコマンド）、なぜ要るか。文字列「コマンドの全文」「対象のパス」「自分で作った」を含む）／拒否の記録を書けたときは、そのパスと、親に返す報告にそのパスを書くこと。子への理由に、確認画面を出していること、`!` を付けて打つこと、許可を書くスクリプトの名前と使い方を書いてはならない（MUST NOT。主に上げるのも許可を書くのも親の役目で、子が自分で主に聞こうとしたり自分で許可を書こうとしたりする余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

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
- **THEN** `permissionDecisionReason` に、作業の破棄に当たったこと、`rules/destructive-git-guard.md`、「打ち直さず」、scratchpad の検証用 repo なら作り直すこと、報告に書く 4 項目（「コマンドの全文」「対象のパス」「自分で作った」「なぜ」）を書いて親に返すこと、拒否の記録のパスが含まれ、「確認画面」と `!` を付けて打つ案内と `git-guard-permit.sh` と `DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

### Requirement: 子の定義に検証用 repo の戻し方を書く

dev-workflow の `agents/reviewer.md`・`agents/worker.md`・`agents/gate-runner.md` の本文は、scratchpad の検証用 repo は git の破壊的操作で戻さず作り直すことを、文字列「作り直す」を含む文で書かなければならない（MUST）。同じ本文に、破壊的 git 操作を拒否されたら作業を止め、報告に 4 項目（コマンドの全文・対象のパス・その対象を自分で作ったか（作ったなら作ったコマンド）・なぜ要るか）を書いて返すことを、文字列「コマンドの全文」「対象のパス」「自分で作った」を含む文で書かなければならない（MUST。本体が許可を書くか決める材料が、報告に揃うようにするため）。hook が子の呼び出しを、コマンドの行き先（scratchpad の中かどうか）だけを見て許可してはならない（MUST NOT。コマンドの中で変数を作ってから使う形を hook は展開できず、行き先を判定できないため）。子の呼び出しを通すのは、`permits/` に一致する許可があり、かつ一時領域の判定を満たすとき（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」）に限る。一時領域の判定は、行き先を確定できる形のコマンドだけを受け付け（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）、許可を書く時点でスクリプトが、使う時点で hook が、同じファイルの判定で行う。

#### Scenario: 3 つの定義に戻し方がある

- **WHEN** `plugins/dev-workflow/agents/reviewer.md`・`worker.md`・`gate-runner.md` の本文を読む
- **THEN** どれにも、scratchpad の検証用 repo は git の破壊的操作で戻さず作り直すことが「作り直す」を含む文で、拒否されたら報告に書く 4 項目が「コマンドの全文」「対象のパス」「自分で作った」を含む文で書かれている

#### Scenario: 許可が無ければ scratchpad の中でも子を通さない

- **WHEN** 許可の無い空の `TMPDIR` で、`cwd` が scratchpad の中の repo の、`agent_id` が `a1` の payload に `git checkout -- .` を渡す
- **THEN** `permissionDecision` が `deny` になる
