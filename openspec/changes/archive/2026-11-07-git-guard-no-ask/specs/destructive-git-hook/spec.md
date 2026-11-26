# Spec Delta

## MODIFIED Requirements

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


## ADDED Requirements

### Requirement: 別セッションの子の停止検知の条件を案内する

`skills/develop/references/epic.md` の手順 5 は、NO_ASK の印を起動側が付けた子は git ガードの確認画面で止まらず、拒否後に承認を求めてターンを終えた止まりを、会話ログが読めるとき `wait --watch-stopped` が検知することを案内しなければならない（MUST）。印の無い子の確認画面や会話ログを読めない子は検知できないという注意を維持しなければならない（MUST）。

#### Scenario: 手順 5 が検知できる止まりと検知できない止まりを区別する

- **WHEN** `epic.md` の手順 5 を読む
- **THEN** NO_ASK の印の名前、拒否後に承認を求めてターンを終えた子は会話ログから検知されること、確認画面で止まった子とログを読めない子は検知できないことが書かれている
