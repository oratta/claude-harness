## ADDED Requirements

### Requirement: 子への拒否を記録し、親が 1 回だけ通せるようにする

子の呼び出し（`agent_id` が空でない文字列）に `deny` を返すたびに、hook は拒否の記録を `<base>/denied/<key>.json` に書かなければならない（MUST）。`<base>` は要件「同じ子への拒否の繰り返しを打ち切る」の回数のファイルと同じ `dev-workflow-git-guard/`（環境変数 `TMPDIR` が空でない文字列ならその下、未設定か空なら `/tmp` の下）。`<key>` は payload の `session_id`・`agent_id`・`cwd`・`tool_input.command` を NUL でつないだ文字列の sha256 の 16 進とする（`session_id` と `cwd` が文字列でなければ空文字として扱う）。記録には `session_id`・`agent_id`・`cwd`・`command`（全文）・当たった種類・時刻を含めなければならない（MUST）。記録を書けなかったときも `deny` は返さなければならない（MUST）。

子の呼び出しで破壊的 git 操作を見つけたとき、hook は同じ規則で `<key>` を計算し、`<base>/permits/<key>.json`（許可）を自分だけが使えるように `rename` で取ってから読まなければならない（MUST）。取れた許可の `session_id`・`agent_id`・`cwd`・`command` がすべて payload と一致し、`expires_at` が今より後なら、`permissionDecision` を `allow` にし、取った許可を消さなければならない（MUST）。このとき拒否の回数を数えてはならず、拒否の記録も書いてはならない（MUST NOT）。許可が無い・取れない・読めない・どれかの値が一致しない・期限切れのときは、取った許可を消し、今までどおり `deny` を返して回数を数えなければならない（MUST）。主の呼び出し（`agent_id` が無い・空・文字列でない）は許可を見てはならない（MUST NOT。今までどおり `ask` / `deny`）。`allow` の `permissionDecisionReason` には、親が書いた許可に一致したのでこの 1 回だけ通すことを書かなければならない（MUST）。

守備範囲: 受け取る入力は、要件「同じ子への拒否の繰り返しを打ち切る」の入力に payload の `cwd` と、`<base>` の下の `denied/` と `permits/` のファイルを足したものである。拾いたい誤りは、子が自分の scratchpad の検証用 repo を戻すだけの操作でも、親が代わりに打つと主の確認画面が出て、主が画面を押すまで作業が止まることである。次の入力は止めることを許す: 親が許可を書いたあと、子がコマンドを 1 文字でも変えて打ったもの・別の cwd から打ったもの／SendMessage で再開されずに新しい子として起こされ `agent_id` が変わったもの／期限が切れてから打ったもの。次の入力は通すことを許す: 許可を書いてから使うまでの間に、scratchpad の中のディレクトリが外への symlink に差し替えられたもの（hook は使う時点で行き先を確かめ直さない）／他のプロセスが `permits/` に書いた許可。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 一致する許可があれば 1 回だけ通す

- **WHEN** 空の `TMPDIR` で、`session_id` が scratchpad の形に合うセッション・`agent_id` が `a1`・`cwd` が scratchpad の中の repo の payload に `git checkout -- .` を渡して拒否され、拒否の記録のパスで許可を書くスクリプトが exit 0 で終わったあと、同じ payload を 2 回渡す
- **THEN** 1 回目は `permissionDecision` が `allow`、2 回目は `deny` になる

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

### Requirement: 許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する

`plugins/dev-workflow/scripts/git-guard-permit.sh` は、引数に拒否の記録のパスと理由（空でない文字列）を受け取り、次をすべて確かめたときだけ許可を書かなければならない（MUST）。どれかを確かめられなければ、許可を書かず、理由を stderr に書いて 0 以外で終わらなければならない（MUST）。

- 記録が `<base>/denied/<key>.json` の形の場所にあり、中身から計算し直した `<key>` がファイル名と一致する。`<base>` は記録のパスの 2 つ上とし、環境変数 `TMPDIR` を見てはならない（MUST NOT。hook と親の Bash で `TMPDIR` が違いうるため）
- コマンドが英数字・空白・タブ・改行・`/ . _ , : = @ + % -`・`;`・`&&` だけでできている（変数・置換・引用符・リダイレクト・パイプ・グロブ・`~`・コメント・行継続を含まない）
- `&&`・`;`・改行で区切った単純コマンドがすべて、引数 1 つの `cd`（実在するディレクトリ。`-` を除く）か、サブコマンドの前に `-C <パス>` だけを置いた `git` で、サブコマンドが `checkout`・`restore`・`reset`・`clean`・`branch`・`switch`・`status`・`add`・`commit`・`init`・`rev-parse` のどれかであり、`git` が 1 つ以上ある
- 各 `git` の作業ディレクトリ（記録の `cwd` から `cd` と `-C` を順に適用し `realpath` で解決したもの）から親へ辿って見つかる `.git` について、作業ツリーの最上位・git ディレクトリ（`.git` がファイルなら `gitdir:` の先）・共通の git ディレクトリ（`commondir` があればその先）の `realpath` が、すべて記録の `session_id` のセッションの scratchpad の中にある。scratchpad とは、`basename` が `scratchpad`、その親の `basename` が `session_id`、さらに 2 つ上の `basename` が `claude-<スクリプトを動かすユーザーの uid>` のディレクトリである。`session_id` は英数字と `-` だけの空でない文字列でなければならない。scratchpad の中で `.git` が見つからないものは拒む
- 共通の git ディレクトリの `config` と git ディレクトリの `config.worktree` に、`worktree` のキーも `[include` / `[includeIf` の節も無い

スクリプトは確かめるために git を実行してはならない（MUST NOT。子が作った repo の設定でコマンドが動きうるため）。許可は `<base>/permits/<key>.json` に、`session_id`・`agent_id`・`cwd`・`command`・`scratchpad`・確かめた repo・理由・`created_at`・`expires_at`（書いた時刻の 15 分後の UNIX 秒）を入れて、一時ファイルからの `rename` で置かなければならない（MUST）。許可を書いたら、その子の回数のファイル（`<base>/<sha256(session_id + NUL + agent_id)>`）を消さなければならない（MUST。要件「同じ子への拒否の繰り返しを打ち切る」）。消せなかったときは stderr に書き、exit 0 で終わってよい。成功したときは、許可したコマンド・cwd・scratchpad・確かめた repo・期限を stdout に書かなければならない（MUST）。

守備範囲: 受け取る入力は、引数・拒否の記録・ファイルシステム上の scratchpad と repo の置き場所である。拾いたい誤りは、親が「子が自分の一時領域を戻すだけ」と判断を誤って、一時領域の外のワークツリー・ホーム・他のリポジトリへの破壊的な操作を許可することである。次の入力は通す（許可を書く）ことを許す: 子の Bash の環境に `GIT_DIR` / `GIT_WORK_TREE` などが入っていて git が別の場所を触るもの（スクリプトは子の環境を見られない）／scratchpad の中の、親の判断と違うファイルや repo を触るもの（守らないもの）。止めすぎる向きでは、引用符やグロブを使ったコマンド・許した以外の git のサブコマンドは scratchpad の中でも許可できないが、これは許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 一時領域の中の repo への操作は許可を書く

- **WHEN** `<tmp>/claude-<uid>/<slug>/<session_id>/scratchpad/repo` に repo を作り、`cwd` がそこで `git checkout -- .` の拒否の記録を作って、記録のパスと理由を渡す
- **THEN** exit 0 で終わり、`permits/` に許可が 1 つ作られ、stdout に scratchpad のパスが含まれる

#### Scenario: 一時領域の外を触る許可は書けない

- **WHEN** 拒否の記録の `cwd` が scratchpad の外の repo のもの、`cd` で scratchpad の外の repo に移ってから `git reset --hard` するもの、`git -C <外の repo> clean -fd` のもの、`.git` が外の git ディレクトリを指す repo のもの、`session_id` が別のセッションの scratchpad の中の repo のもの、をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られない

#### Scenario: 行き先を確定できないコマンドは許可を書かない

- **WHEN** コマンドが `cd "$D" && git checkout -- .`・`git reset --hard && rm -rf x`・`git push --force origin main`・`GIT_DIR=x git reset --hard`・`git checkout -- . > out` の拒否の記録をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られない

#### Scenario: 置き場所や中身が合わない記録には許可を書かない

- **WHEN** 拒否の記録を `denied/` の外に写したもの、中身のコマンドを書き換えたもの、理由を空にしたもの、をそれぞれ渡す
- **THEN** どれも 0 以外で終わり、`permits/` に許可が作られない

#### Scenario: スクリプトは TMPDIR ではなく記録の場所に許可を書く

- **WHEN** hook を `TMPDIR=A` で動かして拒否の記録を作り、スクリプトを `TMPDIR=B` で動かす
- **THEN** 許可が `A` の下の `dev-workflow-git-guard/permits/` に作られ、`B` の下には何も作られない

### Requirement: 子は許可を書くスクリプトを呼べない

子の呼び出しで、単純コマンドの先頭の語の basename が `git-guard-permit.sh` のもの、または先頭の語が `bash` / `sh` / `zsh` / `dash` / `ksh` / `source` / `.` で最初のオプションでない引数の basename が `git-guard-permit.sh` のものに、hook は `deny` を返さなければならない（MUST）。拒否理由・回数・拒否の記録は、破壊的 git 操作の拒否と同じに扱う（当たった種類は許可を書くスクリプトの子からの呼び出し）。この呼び出しには許可を使ってはならない（MUST NOT）。主の呼び出しと、スクリプトを引数として読むだけのもの（`cat` など、先頭の語が上のどれでもないもの）は止めてはならない（MUST NOT）。

守備範囲: 拾いたい誤りは、拒否された子が親に返らずに自分で許可を書いて通すことである。変数で組み立てたパス・別名・`python3` などからスクリプトを動かす形は通ることを許す（通っても、許可を書けるのは要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」を満たすコマンドだけに限られる）。

#### Scenario: 子がスクリプトを呼ぶと拒否する

- **WHEN** `agent_id` が `a1` の payload に `/x/scripts/git-guard-permit.sh /y/denied/k.json ok` と `bash /x/scripts/git-guard-permit.sh /y/denied/k.json ok` をそれぞれ渡す
- **THEN** どちらも `permissionDecision` が `deny` になる

#### Scenario: 主の呼び出しと読むだけの呼び出しは止めない

- **WHEN** `agent_id` の無い payload に `/x/scripts/git-guard-permit.sh /y/denied/k.json ok` を渡し、`agent_id` が `a1` の payload に `cat /x/scripts/git-guard-permit.sh` を渡す
- **THEN** どちらも何も出力しない

### Requirement: 許可を書いたこと・使ったことを記録する

許可を書くスクリプトは、許可を書く前に `<base>/permit-log.jsonl` に、`event` が `permit` で、時刻・`session_id`・`agent_id`・`cwd`・`command`・`scratchpad`・確かめた repo・理由・`expires_at` を含む 1 行の JSON を追記しなければならない（MUST）。追記できなければ許可を書かずに 0 以外で終わらなければならない（MUST）。hook は許可を使ったとき `event` が `use`、期限切れの許可を捨てたとき `event` が `expired` の行を追記しなければならない（MUST）。hook の追記の失敗で判定を変えてはならない（MUST NOT）。

#### Scenario: 許可と使用が記録に残る

- **WHEN** 要件「子への拒否を記録し、親が 1 回だけ通せるようにする」の「一致する許可があれば 1 回だけ通す」の手順を行う
- **THEN** `permit-log.jsonl` に `event` が `permit` の行（理由とコマンドを含む）と `use` の行がこの順にある

## MODIFIED Requirements

### Requirement: 確認画面が出るモードでだけ ask を返す

payload の `agent_id` が空でない文字列のとき（サブエージェントから呼ばれたとき。`context-tripwire.sh` と同じ判定）は、`permission_mode` にも `DEV_WORKFLOW_GIT_GUARD_FORCE` にもよらず `deny` を返さなければならない（MUST）。ただし、要件「子への拒否を記録し、親が 1 回だけ通せるようにする」の一致する許可があるときは `allow` を返す。親は子の確認画面に応答できず、子が止まっていることも分からないので、子に `ask` を返してはならない（MUST NOT）。`agent_id` が無い・文字列でない・空のときは、以下の規則で決める。

`permissionDecision` は payload の `permission_mode` で決めなければならない（MUST）: `default` / `acceptEdits` / `plan` / `bypassPermissions` は `ask`、それ以外（`dontAsk`・`auto`・未知の値・欠落）は `deny`。この対応は実機確認（design.md「`ask` と `deny` は payload の `permission_mode` で切り替える」の判定条件。対照実験を含む）で確定した: `-p` では `default` と `bypassPermissions` のどちらでも `ask` が実行を止め、対話セッションの `bypassPermissions` では `ask` で主が承認できる確認画面が出た。`ask` が `-p` で実行を止めない、または対話セッションで確認画面を出さないと分かったモードは、`deny` に戻さなければならない（MUST）。

環境変数 `DEV_WORKFLOW_GIT_GUARD_FORCE` が `ask` か `deny` のときは、`permission_mode` によらずその値を返さなければならない（MUST。実機確認と bats のための上書き）。ただし子の呼び出しには効かない（上の段落が先に決める）。

以下、`agent_id` が無い・空・文字列でない呼び出しを「主の呼び出し」、`agent_id` が空でない文字列の呼び出しを「子の呼び出し」と呼ぶ。

守備範囲: 子と主の見分けは、要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲の入力に、Claude Code が PreToolUse で hook の stdin に渡す payload の `agent_id`（Claude Code が子の呼び出しに付ける値で、エージェントが書く `tool_input.command` とは別のフィールド）を足す。拾いたい誤りは、子が破壊的 git 操作を打ったときに主の確認画面が出て、親が応答も検知もできず、主が画面を見るまでワークフロー全体が止まることである。次の入力は通すこと（または今までどおり確認画面を出すこと）を許す: Claude Code の版や起動経路によって子の payload に `agent_id` が入らない呼び出し（主の呼び出しとして扱われ、`permission_mode` と `DEV_WORKFLOW_GIT_GUARD_FORCE` の規則に従う）／`DEV_WORKFLOW_GIT_GUARD=off` のセッションで子が打つもの（すべて通る）／要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲で通ることを許した形を子が打つもの（変数で組み立てた形やスクリプトファイル経由など）。止めすぎる向きでは、主が子に破壊的操作を任せた場合も、親が許可を書けるコマンド（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）以外は子では実行できず、親か主が打つことになるが、これは許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

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

### Requirement: 拒否理由は承認の取り方を案内する

主の呼び出し（`agent_id` が無い・空・文字列でない）への `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（9 種のどれか。複数当たればすべて）／規範の正本が `rules/destructive-git-guard.md` であること／実行せず主に承認を求めること／承認されたら主が自分で実行すること（Claude Code の入力欄で `!` を付けるか、自分の端末で。`ask` のときは、確認画面が出ないセッション（`claude -p` など）ではそうすること）／`ask` のときは、確認画面を出していること／言い換えたコマンドで再実行して hook を避けないこと。`!` の入力は PreToolUse hook を通らない（対話セッションで `! git reset --hard` が止められずに実行されることを確かめた）ので、`!` の案内を残す。コマンドに付けて hook を通す目印（環境変数の前置など）を案内してはならない（MUST NOT）。

子の呼び出し（`agent_id` が空でない文字列）への `deny` の `permissionDecisionReason` は次をすべて含まなければならない（MUST）: 当たった操作の種類（判定しきれなかった入れ子のときはその旨）／規範の正本が `rules/destructive-git-guard.md` であること／このコマンドは実行されないこと／打ち直さず、別の書き方も試さないこと（文字列「打ち直さず」を含む）／scratchpad の検証用 repo なら git で戻さず作り直すこと／それ以外は作業を止め、何を・なぜ実行したかったかを報告に書いて親に返すこと／拒否の記録を書けたときは、そのパスと、親に返す報告にそのパスを書くこと。子への理由に、確認画面を出していること、`!` を付けて打つこと、許可を書くスクリプトの名前と使い方を書いてはならない（MUST NOT。主に上げるのも許可を書くのも親の役目で、子が自分で主に聞こうとしたり自分で許可を書こうとしたりする余地を残さないため）。コマンドに付けて hook を通す目印を案内してはならない（MUST NOT）。

#### Scenario: deny の理由に承認の取り方が書かれている

- **WHEN** `agent_id` の無い、`permission_mode` が `auto` の payload で `git push origin main` を渡す
- **THEN** `permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: ask の理由に確認画面と、画面が出ないときの取り方が書かれている

- **WHEN** `agent_id` の無い、`permission_mode` が `bypassPermissions` の payload で `git push origin main` を渡す
- **THEN** `permissionDecision` が `ask` で、`permissionDecisionReason` に、main / master への push に当たったこと、`rules/destructive-git-guard.md`、確認画面を出していること、主に承認を求めること、主が自分で実行することが含まれ、`DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

#### Scenario: 子への理由は親に返すよう案内する

- **WHEN** `agent_id` が空でない文字列で `permission_mode` が `default` の payload に `git checkout -- a` を渡す
- **THEN** `permissionDecisionReason` に、作業の破棄に当たったこと、`rules/destructive-git-guard.md`、「打ち直さず」、scratchpad の検証用 repo なら作り直すこと、何を・なぜを報告に書いて親に返すこと、拒否の記録のパスが含まれ、「確認画面」と `!` を付けて打つ案内と `git-guard-permit.sh` と `DEV_WORKFLOW_GIT_GUARD` の文字列は含まれない

### Requirement: 同じ子への拒否の繰り返しを打ち切る

子（`agent_id` が空でない文字列）に `deny` を返すたびに、`session_id` と `agent_id` の組ごとの拒否の回数を、環境変数 `TMPDIR` が空でない文字列ならその下、未設定か空なら `/tmp` の下の `dev-workflow-git-guard/` にあるファイルに数えなければならない（MUST）。書き込めない `TMPDIR` を飛ばして別の場所に書いてはならない（MUST NOT。`tempfile.gettempdir()` の候補探しを使わない）。ファイル名は `session_id` と `agent_id` から導いたハッシュとし、`agent_id` や `session_id` をそのままパスに使ってはならない（MUST NOT）。回数のファイルを作れない・読めない・中身が整数でないときは、その呼び出しを 1 回目として扱い、`deny` は返さなければならない（MUST。数えられないことで通してはならない）。`allow` を返した呼び出しは数えてはならない（MUST NOT）。

親が許可を書くスクリプト（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）で許可を書いたときは、その子の回数を 0 に戻す（回数のファイルを消す）。許可のあとの最初の拒否は 1 回目として扱わなければならない（MUST）。

同じ組への 2 回目以降の `deny` では、`permissionDecisionReason` に「直ちに作業を終えて親に返す」を含めなければならない（MUST）。加えて、出力のトップレベルに `"continue": false` と `stopReason` を含めるかは実装段の実機確認（design.md「2 回目以降の拒否」）の結果で決める:

- 子の中で `continue: false` を返すと子だけが終わり、親が子の結果を受け取って続けると確かめた場合は、`"continue": false` と `stopReason` を含めなければならない（MUST）
- 親まで止まると分かった場合、または確かめられなかった場合は、`"continue"` のキーを出力してはならない（MUST NOT）

どちらに決めたかと実機確認の結果は、この change の design.md と PR 本文に記録しなければならない（MUST）。1 回目の `deny` には `"continue"` のキーを出力してはならない（MUST NOT）。主の呼び出し（`agent_id` が無い・空・文字列でない）は数えず、出力も変えない（MUST）。

守備範囲: 受け取る入力は、Claude Code が PreToolUse で渡す payload の `agent_id` と `session_id`、環境変数 `TMPDIR`、その下の回数のファイルである。拾いたい誤りは、拒否された子が打ち直しや言い換えで同じ hook に繰り返し当たり続けることである。次の入力は打ち切らずに通す（1 回目として扱う）ことを許す: 同じ子が並列の Bash 呼び出しで同時に拒否され、回数の読み書きが重なったもの／回数のファイルを作れない・読めない・中身が整数でないとき（毎回 1 回目になる）／一時ディレクトリが片付けられたあとの拒否（0 から数え直す）／hook に当たらない書き方（要件「破壊的 git 操作を Bash の実行前に検出する」の守備範囲で通ることを許した形）で子が同じことを試みたもの（拒否にならないので数えない）／他のプロセスが回数のファイルを書き換えたもの。止めすぎる向きでは、SendMessage で再開された子は同じ `agent_id` を持つので回数が再開をまたいで続き、前の工程で 1 回拒否され親が許可を書かなかった子は次の工程の最初の拒否で 2 回目として扱われるが、これは許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: 1 回目は打ち切らない

- **WHEN** 空の `TMPDIR` で、`agent_id` が `a1` の payload に `git checkout -- a` を 1 回渡す
- **THEN** `permissionDecision` が `deny` で、出力に `"continue"` のキーが無く、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が無い

#### Scenario: 同じ子への 2 回目は強く返す

- **WHEN** 空の `TMPDIR` で、`session_id` が `s1`・`agent_id` が `a1` の payload に `git checkout -- a` を渡して 1 回拒否されたあと、同じ `TMPDIR` で `session_id` が `s1`・`agent_id` が `a1` の payload に `git checkout -- b` を渡す
- **THEN** `permissionDecision` が `deny` で、`permissionDecisionReason` に「直ちに作業を終えて親に返す」が含まれ、実機確認で子だけが終わると確かめた場合は出力のトップレベルに `"continue": false` と `stopReason` が含まれ、そうでない場合は `"continue"` のキーが無い

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

dev-workflow の `agents/reviewer.md`・`agents/worker.md`・`agents/gate-runner.md` の本文は、scratchpad の検証用 repo は git の破壊的操作で戻さず作り直すことを、文字列「作り直す」を含む文で書かなければならない（MUST）。hook が子の呼び出しを、コマンドの行き先（scratchpad の中かどうか）だけを見て許可してはならない（MUST NOT。コマンドの中で変数を作ってから使う形を hook は展開できず、行き先を判定できないため）。子の呼び出しを通すのは、親が許可を書くスクリプトで許可を書いたとき（要件「子への拒否を記録し、親が 1 回だけ通せるようにする」）に限る。行き先の判定は許可を書く時点でスクリプトが行い、行き先を確定できる形のコマンドだけを受け付ける（要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）。

#### Scenario: 3 つの定義に戻し方がある

- **WHEN** `plugins/dev-workflow/agents/reviewer.md`・`worker.md`・`gate-runner.md` の本文を読む
- **THEN** どれにも、scratchpad の検証用 repo は git の破壊的操作で戻さず作り直すことが「作り直す」を含む文で書かれている

#### Scenario: 許可が無ければ scratchpad の中でも子を通さない

- **WHEN** 許可の無い空の `TMPDIR` で、`cwd` が scratchpad の中の repo の、`agent_id` が `a1` の payload に `git checkout -- .` を渡す
- **THEN** `permissionDecision` が `deny` になる
