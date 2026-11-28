# Spec Delta

## MODIFIED Requirements

### Requirement: 確認画面が出るモードでだけ ask を返す

有効な `agent_id`（空でない文字列）がなく、環境の `DEVELOP_ROLE` が空でない呼び出しはマーカー付き役とし、要件「マーカー付き役の破壊的 git は許可を渡さず拒否する」を先に適用する（MUST）。以下の既存規則と Scenario はマーカー付き役を除く呼び出しを対象とする。印があっても有効な `agent_id` がある呼び出しは既存の子の経路を優先する（MUST）。

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

### Requirement: 逃げ道と fail-open

**守備範囲**: 入力元は Claude Code の PreToolUse payload（`tool_name` / `tool_input.command` / `agent_id`）、hook の起動環境（`DEVELOP_ROLE` / `DEV_WORKFLOW_GIT_GUARD`）、python3 の利用可否である。拾う誤りは、役への明示 off を適用して検出対象を通すことと、読めない入力や非 Bash 入力で hook が実行を妨げることである。通してよい例は、python3 欠落・不正 JSON・非文字列 command の役呼び出し（無出力・exit 0）、印のない主と実在 subagent の明示 off、既存検出範囲外の別スクリプト経由の操作である。主へ印が誤継承された場合は役扱いを許容する。fail-open を deny の証拠にせず、入力や検出器の穴の完全封鎖を完了条件にしない。

マーカー付き役以外で `DEV_WORKFLOW_GIT_GUARD=off` のときは何も出さずに exit 0 としなければならない（MUST）。`tool_name` が `Bash` でない、`tool_input.command` が文字列でない、stdin が JSON として読めない、python3 が無いときは fail-open（exit 0・無出力）としなければならない（MUST）。`shlex` が引用符の不整合で字句に分けられないときは、空白で割った字句に同じ判定をかけなければならない（MUST。判定を諦めて素通りにしない）。

負荷を抑えるため、stdin の payload 全体に `git` の文字列も `\u00`（JSON のエスケープ表記。`git` をエスケープして書いた payload を取りこぼさないため）も無ければ python3 を起動せずに exit 0 としてよい（MAY。`context-tripwire.sh` の早期 exit と同じ形）。この早期 exit の誤りは、`git` を含む payload で余計に python3 を起動する向きにしか起きず、判定の結果は変わらない。外から観測できる違いが無いので、この早期 exit には Scenario を置かない。

#### Scenario: off で全許可

- **WHEN** マーカー付き役ではない呼び出しに `DEV_WORKFLOW_GIT_GUARD=off` を付けて `git reset --hard` を渡す
- **THEN** exit 0 で何も出力しない

#### Scenario: 読めない入力は素通り

- **WHEN** 空の stdin、JSON でない文字列、`tool_name` が `Edit` の payload を渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: 引用符が閉じていなくても判定する

- **WHEN** `git reset --hard && echo "oops` を渡す
- **THEN** `permissionDecision` が `ask` か `deny` の JSON が出る

### Requirement: 子は Write / Edit / NotebookEdit で許可の置き場所に書けない

hook `scripts/git-guard-base-write-guard.sh` は、子（`agent_id` が空でない文字列）とマーカー付き役の書き先（Write / Edit は `tool_input.file_path`、NotebookEdit は `tool_input.notebook_path`）の部品のどれかが、大文字小文字を区別せずに `<base>` の名前 `dev-workflow-git-guard` と一致すれば、`permissionDecision` が `deny` の JSON を出さなければならない（MUST。`permits/` に限らず `<base>` の中はすべて）。書き先は、相対なら payload の `cwd` を前に付け、`..` を畳んだパスと、既にある部分の symlink を辿ったパスの両方で見る（MUST）。この hook は `<base>` を作らず、回数・拒否の記録・許可に触れない（MUST NOT。数えない）。

#### 守備範囲

この要件と、要件「子は Bash のコマンドで許可の置き場所を名指しできない」「許可の置き場所への書き込みの拒否は親に返すよう案内する」の目的は、ルールを読み飛ばした子が許可の置き場所に分かりやすく書こうとしたときに止めることで、セキュリティ境界ではない。子・hook・親は同じ uid で動き、hook が読める秘密は子も読めるので、子が作れない印で許可を見分けることはできない。受け取る入力は、Claude Code が PreToolUse で渡す payload のうち、子が指定するツール入力（`tool_name`・`tool_input.file_path`・`tool_input.notebook_path`・`tool_input.command`）と、Claude Code が付ける識別情報（`agent_id`・`cwd`。子はこれらを直接は指定しない）、書き先のパスを辿った時点のファイルシステム、環境変数 `DEV_WORKFLOW_GIT_GUARD` である。拾いたい誤りは、拒否された子が親に返らずに、Write / Edit / NotebookEdit ツールか、置き場所の名前を書いた Bash のコマンドで、自分で許可を置くことである。次の入力は通すことを許す: 変数や置換で組み立てたパス（`d=dev-workflow-git-; "$TMPDIR/${d}guard/permits/k.json"`）／グロブ（`"$TMPDIR"/dev-workflow-*/permits/k.json`、`.../dev-workflow-git-guard/p*/k.json`）／置き場所に移ってから `permits` の名前を書かずに書くもの（`cd .../dev-workflow-git-guard/perm*` のあとの書き込み）／スクリプトファイル・Makefile・別のファイルの中から書くもの／大文字小文字を変えた名前の Bash のコマンド（大文字小文字を区別しないファイルシステムでは同じ場所に届く）／Write / Edit / NotebookEdit 以外のツール（MCP のファイル書き込みなど）で書くもの／hook が書き先を辿ってから書かれるまでの間に、途中のフォルダが置き場所への symlink に差し替えられたもの／マーカー付き役ではない主の呼び出しが書くもの。通っても、許可が効くのは使う時点の一時領域の判定（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」）を満たす scratchpad の中だけである。次の入力は止めることを許す（止めすぎる向き）: このガードの置き場所そのものを扱う開発で、子が 2 つの名前を両方含むコマンド（spec の書き換え・grep・偽造の確かめ）を打つもの（2026-11-10 時点の会話ログで Bash の呼び出し 109,484 件のうち 8 件。子は親に返り、親が打つ）／置き場所の名前の部品を持つ、置き場所でないフォルダへの書き込み。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: Write / Edit / NotebookEdit で `<base>` の中に書くと拒否する

- **WHEN** 空の `TMPDIR` を T として、`agent_id` が `a1` の Write の payload の `file_path` を `T/dev-workflow-git-guard/permits/k.json` に、Edit の payload の `file_path` を `T/dev-workflow-git-guard/<回数のファイルの名前>` に、NotebookEdit の payload の `notebook_path` を `T/dev-workflow-git-guard/x.ipynb` にして、それぞれ新しい hook に渡す
- **THEN** どれも `permissionDecision` が `deny` で、出力に `"continue"` のキーが無く、T の下に何も作られない

#### Scenario: 書き先の書き方を変えても拒否する

- **WHEN** `agent_id` が `a1` の Write の payload の `file_path` を、`T/Dev-Workflow-Git-Guard/permits/k.json`・`T/x/../dev-workflow-git-guard/permits/k.json`・`cwd` を T にした相対パス `dev-workflow-git-guard/permits/k.json`・`T/dev-workflow-git-guard` を指す symlink `T/link` を経た `T/link/permits/k.json` にして、それぞれ渡す
- **THEN** どれも `permissionDecision` が `deny` になる

#### Scenario: マーカー付き役は許可の置き場所にも書けない
- **WHEN** 有効な `agent_id` のない `DEVELOP_ROLE=worker` の Write / Edit / NotebookEdit を、既存の拒否例と同じ通常・相対・大小文字違い・symlink 経由の書き先で渡す
- **THEN** すべて exit 0 の deny JSON になり、置き場所・拒否回数・記録・許可を作成も変更もしない


### Requirement: 置き場所への書き込みを止める hook の配線と逃げ道

dev-workflow は `scripts/git-guard-base-write-guard.sh` を、`hooks/hooks.json` の PreToolUse に `matcher: "Write|Edit|NotebookEdit"` で、`command` を `"${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-base-write-guard.sh"` と引用符で囲み、`if` を付けずに登録しなければならない（MUST）。PreToolUse の末尾は git ガードの Bash のエントリのまま保つ（MUST）。この hook は、マーカー付き役ではない主の呼び出し（`agent_id` が無い・空・文字列でない）・部品が一致しない書き先・マーカー付き役以外の `DEV_WORKFLOW_GIT_GUARD=off`・python3 が無い・stdin が JSON でない・payload がオブジェクトでない・`tool_name` が 3 つのどれでもない・書き先が文字列でないときは、何も出さずに exit 0 としなければならない（MUST）。

#### 守備範囲

要件「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲と同じ。

#### Scenario: 主の呼び出しと置き場所の外への書き込みは止めない

- **WHEN** `DEVELOP_ROLE` が未設定か空の環境で、`agent_id` の無い Write の payload の `file_path` を `T/dev-workflow-git-guard/permits/k.json` にしたもの、`agent_id` が `a1` の Write の payload の `file_path` を `plugins/dev-workflow/tests/git-destructive-guard.bats` と `T/notes/dev-workflow-git-guard.md` にしたもの、`DEV_WORKFLOW_GIT_GUARD=off` で `agent_id` が `a1` の `file_path` を `T/dev-workflow-git-guard/permits/k.json` にしたもの、`tool_name` が `Bash` の payload、JSON でない文字列を、それぞれ新しい hook に渡す
- **THEN** どれも exit 0 で何も出力しない

#### Scenario: 新しい hook が hooks.json に登録されている

- **WHEN** `plugins/dev-workflow/hooks/hooks.json` の PreToolUse を読む
- **THEN** `matcher` が `Write|Edit|NotebookEdit` で `"${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-base-write-guard.sh"` の command hook を持ち `if` の無いエントリがあり、配列の末尾は git ガードの `matcher` が `Bash` のエントリのままである

## ADDED Requirements

### Requirement: マーカー付き役の破壊的 git は許可を渡さず拒否する

マーカー付き役で既存の検出対象に当たる Bash は、実行前に exit 0 の `permissionDecision: deny` を返さなければならない（MUST）。permission_mode・FORCE・NO_ASK・UNATTENDED・`DEV_WORKFLOW_GIT_GUARD=off`・既存 permit による ask / allow を認めず、agent_id を捏造しない（MUST NOT）。理由はコマンド全文・対象・必要な理由を本体に返し、承認後は主が実行するよう案内する（MUST）。role は permit 経路・子の拒否回数を使わない（MUST NOT）。

**守備範囲**: 入力元は Claude Code の PreToolUse payload の識別・ツール入力、hook の起動環境の `DEVELOP_ROLE` と既存 git ガードのモード・上書き値である。役の識別は空でない実在 `agent_id` を優先し、それがない場合だけ環境の印を使い、payload や command の同名文字列を印にしない。拾う誤りは、マーカー付き役の既存検出対象を ask / permit / off で通すこと、役へ ID を捏造して子の許可・回数を流用すること、既知の自己許可経路で本体への報告を省くことである。破壊的操作の検出範囲は既存要件「破壊的 git 操作を Bash の実行前に検出する」、自己許可の検出範囲は「子は Write / Edit / NotebookEdit で許可の置き場所に書けない」の守備範囲を共通に適用する。通してよい例は、安全な `git status`、変数で組み立てた git や別スクリプト経由など既存検出範囲外の操作、要件「逃げ道と fail-open」の欠測例である。逆に主の起動環境に空でない印が誤継承されれば、対象操作を役として deny することを許容する。同一 uid の起動環境を認証する境界ではなく、印の誤継承や検出器の穴の完全封鎖を完了条件にしない。

#### Scenario: モードと上書きと permit によらず対象操作を止める
- **WHEN** `DEVELOP_ROLE=worker` で有効な `agent_id` のない Bash payload に既存の対象 9 種を渡し、permission_mode を default / acceptEdits / plan / bypassPermissions / auto / dontAsk / 未知 / 欠落に、FORCE を未設定 / ask / deny に変える
- **THEN** すべて単一の PreToolUse deny JSON・exit 0 となる。NO_ASK / UNATTENDED / `DEV_WORKFLOW_GIT_GUARD=off` を併用しても ask / allow にしない
- **AND** 判定しきれない入れ子の git も既存と同様に deny する。安全な `git status` は無出力・exit 0 で通す

#### Scenario: 役を偽の子にして permit を流用しない
- **WHEN** 同じ session_id・cwd・command の実在する子に対する期限内の permit を用意し、マーカー付き役の payload を先に、元の子の payload を後で渡す
- **THEN** 役は deny し、permit を読み取り・消費せず、子の拒否回数・記録も変更しない。元の子だけは既存条件に従って一度 allow になる
- **AND** 空・数値・欠落の agent_id を役名や session_id から補ってはならず、役の応答や記録に偽の agent_id を作らない

#### Scenario: 役が自分で許可を置く既知の経路を止める
- **WHEN** マーカー付き役が `git-guard-permit.sh` を名指しする実行、Bash で許可の置き場所を名指しする既存の拒否例、Write / Edit / NotebookEdit で同置き場所へ書く例を渡す
- **THEN** 既存と同じ検出範囲で deny し、`DEV_WORKFLOW_GIT_GUARD=off` でもこの役への制約を解除しない。既存の読み取り専用の名前参照の例外は維持する
- **AND** 拒否の理由は本体への報告と承認後の主の実行を案内し、permit を書いて役に再実行させる手順を示さない

#### Scenario: 環境の印と実在する子を区別する
- **WHEN** `DEVELOP_ROLE` が未設定・空で payload や command にだけ印の文字列がある主、または有効な agent_id を持つ子を呼び出す
- **THEN** どちらも既存の判定・拒否回数・permit・明示 off の挙動を維持する。子は環境の印を継承していても同じである

#### Scenario: 判定不能を実行阻止の証拠としない
- **WHEN** python3 欠落、壊れた payload、文字列でない command など既存の fail-open 条件に当たる
- **THEN** 既存どおり無出力・exit 0 であり、deny が観測されたとも品質成功とも扱わない。検出器がもともと扱わない変数・別スクリプト経由などの完全封鎖を本要件に加えない
