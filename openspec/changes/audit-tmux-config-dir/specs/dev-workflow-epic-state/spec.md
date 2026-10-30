## MODIFIED Requirements

### Requirement: tmux の部品は子を独立した Claude Code のセッションとして tmux のウィンドウに起動する

`plugins/dev-workflow/scripts/epic-launch-tmux.sh` は、要件「起動部品は epic-launch-<名前>.sh の 1 本ずつで、同じサブコマンドと出力の契約を持つ」の 13 個のサブコマンドを、`tmux` と `git` だけで実装しなければならない（MUST）。親が tmux で常駐していること（環境変数 `TMUX` が空でなく、`tmux` が PATH にある）を前提とし、`orca` を呼んではならない（MUST NOT）。開発に固有の語を入れてはならない（MUST NOT）。

| サブコマンド | tmux の部品の動き |
|---|---|
| `available` | `tmux` が PATH にあり `TMUX` が空でなければ exit 0。使えなければ stderr に `tmux is not available (run inside a tmux session)` を出して exit 1 |
| `here` | `available` と同じ条件なら `{"repo_id":"","worktree_id":""}` を出して exit 0、そうでなければ exit 1 |
| `prepare` | 何もせず exit 0 |
| `list`・`repos` | 何も出さず exit 0（記録が正本で、部品は子を知らない） |
| `unregistered` | stdout に `ok` |
| `create` | `repo_id` は読まない。ワークツリーは `git -C <clone か親のワークツリー> worktree add -b worktree-issue-<N> <リポジトリの最上位>/.claude/worktrees/issue-<N> origin/<起点>`（worktree プラグインの置き場と名前の決まり `<repo>/.claude/worktrees/<name>`・`worktree-<name>` に合わせる）。同じ名前のブランチかワークツリーが既にあれば作らず exit 1。作れたら `{"path","branch"}` の 1 行 |
| `start` | 同じ tmux サーバーに `tmux new-window -d -P -F '#{pane_id}' -c <ワークツリー>` でシェルを開き（起動コマンドを `new-window` に直接渡さない。対話でないシェルでは `cld` のシェル関数が解けないため）、起動コマンドを `send-keys -l` で打ち込んで Enter を送る。画面（`capture-pane`）の最下部（空行を除いた末尾の数行。行数は部品の先頭の定数）に Claude Code の入力待ちの印が出て、同じ最下部に許可・選択・信頼の確認画面の印が出ていない状態になるまで `EPIC_DISPATCH_READY_TIMEOUT_MS` を上限に待ち、最初の指示を `send-keys -l` で送って Enter（`send-keys` の `C-m`）を送る。起動して間もない Claude Code は最初の Enter を取りこぼすことがあるので、届くまで 4 秒ごとに Enter だけを重ねる（文は打ち直さない）。重ねる前に毎回画面の最下部を読み、入力待ちの印があり、確認画面の印が無く、送った文の先頭がまだ入力欄に残っているときだけ重ね、一度でも満たさなければ重ね送りをやめる（会話ログの確認は続ける。確認画面に Enter が選択として届くのを避けるため）。最初の指示を打つ前にも、最下部が入力待ちで確認画面が出ていないことを確かめ、そうでなければ何も打たずに `failed send` とする。印の文言（入力待ち・確認画面とも）は Claude Code 2.1.305 の画面で決めた定数で、版で変わると、入力待ちの印が当たらず `failed ready` で止まる（誤送信しない側）か、確認画面の印を見逃す（守る範囲の外）。送信が届いたかは、子のワークツリーの会話ログ（`${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-~/.claude}/projects}/<パスの英数字以外を - にした名前>/*.jsonl`）に、送る直前に控えた時刻より後の user の行が現れ、その本文が送った文の先頭 40 文字（40 文字に満たなければ全体。送った文が `/<コマンド>` で始まるときは、会話ログでコマンド名が `<command-name>` に展開されるので、コマンド名のうしろの引数の先頭 40 文字）を含むことを `EPIC_DISPATCH_SUBMIT_WAIT` 秒を上限に確かめる（時刻だけでなく本文と照合するので、別のセッションが同じログに書いた入力とは区別できる。検出できないのは、先頭 40 文字より後ろの欠けと、送った文と同じ先頭を持つ別の入力が同時に入ったときである）。届けば `started <ペイン ID>`、段ごとの失敗は `failed terminal|ready|send <ペイン ID>`（exit 1） |
| `deliver` | ウィンドウ（ペイン）の一覧を `tmux list-panes -a` で 1 回だけ読み、`#{pane_current_path}` が子のワークツリーのペインを探す。Claude Code が動いていること（`#{pane_current_command}` と画面の入力待ち）を確かめたペインがちょうど 1 つなら、同じ送り方で文を送り、会話ログで（`start` と同じ本文の照合で）届いたことを確かめて `sent`。ペインが無い、または `relaunch` が 1 なら、あるペインを `kill-pane` してから `start` と同じ手順で起動し直し、`relaunched <ペイン ID>`。シェルだけのペインしか無い・候補が 2 つ以上のときは `relaunch` が 0 なら `failed ambiguous-terminal` |
| `keepalive` | 引数・stdout/exit は共通の契約に従う。`tmux list-panes -a` の `pane_current_path`・`pane_current_command` と `tmux capture-pane -p -e -t <ペイン ID>` で既存の一意の Claude Code のペイン、前景の入力待ち、空欄、選択画面でないことを共通の画面判定に従って観測し、送信直前にも再確認する。`pane_current_command` が `bash` 等でも Claude Code の画面を確認できれば候補とし、シェル名だけでは除外しない。文字列は `tmux send-keys -t <ペイン ID> -l -- <text>`、Enter は `tmux send-keys -t <ペイン ID> C-m` で一度だけ送る。子の会話ログで `start` と同じ時刻・本文照合を `EPIC_DISPATCH_SUBMIT_WAIT` 秒の範囲で行い、到達すれば `sent`、未確認は `failed send`。観測は list-panes/capture-pane と会話ログの読み取りだけ、変更操作は既存ペインへのこの文字列と Enter の送信だけとし、new-window/kill-pane/git worktree/入力消去/Enter の再送は行わない |
| `close` | 子のワークツリーのペインを `tmux kill-pane` で閉じる。ペインが無ければ成功。閉じられなければ 1 回だけ閉じ直して、駄目なら exit 1 |
| `remove` | 子のワークツリーが属するリポジトリの本体のワークツリー（`git -C <ワークツリー> rev-parse --git-common-dir` の親）で `git worktree remove <ワークツリー>`（`--force` を付けない。ワークツリーの中から自分自身を消さない）。消せなければ理由の語 `rm-failed` を 1 行出して exit 1。`close` の成功後に `reap` が呼ぶ（`close` が失敗した子は `reap` が `kept close-failed` にして `remove` を呼ばない）。`epic-dispatch.sh` の `kept` の子を本体が確かめて消す操作（要件「別セッション方式の既存要件は…」）も同じ形で、本体が `bash epic-launch-tmux.sh remove <path>` を呼ぶ |
| `mirror` | 何もせず exit 0 |

この要件の検査（ペイン・画面・会話ログ・`git` の出力の分類）の守備範囲は次のとおりである。入力の出どころは、`epic-dispatch.sh` が検査済みで渡す引数と、`tmux`（`list-panes`・`capture-pane`・`new-window -P`）・`git`・子の会話ログの出力である。拾いたい誤りは、シェルのペインに指示を打ち込んで実行してしまうこと、Claude Code の入力待ちの表示が変わって黙って誤送信すること（`failed ready` にする）、送信が届いていないのに `started`・`sent` と言うこと、同じ名前のブランチ・ワークツリーを上書きすること、未コミットの変更があるワークツリーを消すことである。次は通してよく、この要件では止めない: 入力待ちの判定が画面の末尾の部分一致であること／`list-panes` の出力に改行を含むパスは無いと信じること／会話ログの user 行以外の形／送った文の先頭 40 文字より後ろの欠けと、同じ先頭を持つ別の入力が同時に入った場合（検出できない範囲として上の `start` の行に書いた）。`keepalive` は入力待ち・空欄の両方を観測できなければ送らず、画面の判定が未対応なら `skipped unknown-state`、読み取り失敗や壊れた出力なら `failed observe`（一覧なら `failed terminal-list`）とする。観測と送信の間の並行入力までは排除できない。tmux・画面・ログの崩れ方をすべて塞ぎ切ることは、この要件の完了条件としない。

送信の前に、送り先のペインで Claude Code が動いていることを確かめなければならない（MUST。シェルに指示を打ち込んで実行してしまう事故を避けるため）。送った文字列は `send-keys -l`（リテラル）で渡し、キー名として解釈させてはならない（MUST NOT）。

`start`・`deliver` が失敗したとき（`failed terminal`・`failed ready`・`failed send`）は、Orca の部品と同じく、共通手順が参照する作り直しか送り直しのコマンドを stderr に出さなければならない（MUST）。出す順は、先に確かめるコマンド、次にやり直すコマンドとする（確かめる前にやり直すと、動いている子を二重に起動する・届いている指示を二重に送る）。`failed send` は、ペインの入力欄を見る `tmux capture-pane -p -t <ペイン ID>` を先に出し、そのあとに `epic-launch-tmux.sh deliver <ワークツリー> 0 <送る文> <起動コマンド> <起動し直しの指示>` を `resend:` として出す。`failed terminal`・`failed ready` は、ワークツリーのペインを一覧する `tmux list-panes -a` を先に出し、残ったペインがあればそれを閉じる `tmux kill-pane -t <ペイン ID>`、次に `epic-launch-tmux.sh start <ワークツリー> <起動コマンド> <最初の指示> <子の呼び方>` を `create:` として出す。記録とワークツリーは残るので `launch` の再実行は `skipped` になることも添える。引数は単一引用符で囲む（MUST）。

#### Scenario: tmux の部品の送信失敗は確認のコマンドを先に、送り直しのコマンドを後に出す
- **WHEN** `epic-launch-tmux.sh start` が最初の指示を送ったが会話ログに現れず `failed send` で終わる
- **THEN** stderr に `tmux capture-pane -p -t <ペイン ID>` の行があり、そのあとの行に `deliver <ワークツリー> 0 <送る文> ...` を含む `resend:` の行がある

#### Scenario: tmux の部品は orca を呼ばない
- **WHEN** `orca` のスタブが呼ばれたら失敗する環境で、tmux の部品の全サブコマンドを実行する
- **THEN** `orca` は 1 回も呼ばれない

#### Scenario: start は起動コマンドをシェルに打ち込む
- **WHEN** tmux のスタブがある環境で `epic-launch-tmux.sh start /work/issue-5 'cld --model opus' '/develop #5' 5` を実行する
- **THEN** `tmux new-window -d -P -F '#{pane_id}' -c /work/issue-5` が引数にコマンドを付けずに 1 回呼ばれ、起動コマンドと最初の指示が `send-keys -l` で順に送られ、会話ログに送信後の user の行が現れたら stdout は `started <ペイン ID>`、exit 0 である

#### Scenario: シェルだけのペインには送らない
- **WHEN** 子のワークツリーのペインの `#{pane_current_command}` が `zsh` で、`relaunch` が 0 の環境で `deliver` を実行する
- **THEN** 何も送らず、stdout は `failed ambiguous-terminal`、exit 1 である

#### Scenario: remove は --force を付けない
- **WHEN** `epic-launch-tmux.sh remove /work/issue-5` を実行する
- **THEN** `git worktree remove /work/issue-5` が `--force` なしで 1 回呼ばれる

#### Scenario: 送信確認は本文と照合する
- **WHEN** 送った時刻より後に会話ログへ現れた user の行の本文が、送った指示の先頭 40 文字を含まない環境で `start` を実行する
- **THEN** `EPIC_DISPATCH_SUBMIT_WAIT` 秒待ったあと stdout は `failed send <ペイン ID>`、exit 1 である

#### Scenario: 別リポジトリの子は空の repo_id と clone で作られる
- **WHEN** `epic-launch-tmux.sh create /other/clone '' 5 main /work/parent` を実行する
- **THEN** `git -C /other/clone worktree add -b worktree-issue-5 /other/clone/.claude/worktrees/issue-5 origin/main` が呼ばれ（親のリポジトリには作らない）、stdout は `{"path","branch"}` の 1 行、exit 0 である。同じ引数で Orca の部品の `create` は呼ばれない

#### Scenario: 登録の無い別リポジトリの clone でも別リポジトリの子を起動できる
- **WHEN** `TMUX` が空でない環境で、`EPIC_DISPATCH_CLONES` に clone を書いた別リポジトリの子を `launch` に渡す
- **THEN** `unregistered` の `ok` で `not-in-orca` にならず、clone にワークツリーができて `launched <child>` になる

#### Scenario: keepalive は既存ペイン以外を変更しない
- **WHEN** tmux の keepalive で、ペイン無し・シェルだけ・複数候補・実行中・入力済み・選択画面・状態不明をそれぞれ観測する
- **THEN** `skipped <共通契約の理由>` と exit 0 を返し、send-keys/new-window/kill-pane/git worktree を呼ばない。送信可能な場合は list-panes/capture-pane・リテラル送信と C-m 一回・会話ログの確認だけで完結し、Orca は呼ばない

#### Scenario: tmux の薄字の提案文は空欄とみなせる
- **WHEN** `capture-pane -p -e` で前景の入力待ちを確認し、`❯ ` の後に薄字 `\e[2m` の提案文だけがある場合と、人が入力した文字がある場合をそれぞれ観測する
- **THEN** 提案文だけなら空欄とみなして送信してよい。人の入力があれば `skipped input-not-empty`（exit 0）で文字列も Enter も送らない

#### Scenario: シェル名だけで Claude Code の画面を除外しない
- **WHEN** keepalive の候補ペインの pane_current_command が bash だが、画面では Claude Code の前景の入力待ち・空欄を確認でき、他の送信条件を満たす
- **THEN** コマンド名だけでシェルのみと判断せず送信可能とする。Claude Code の画面を確認できないシェルだけのペインには送らない

#### Scenario: keepalive の送信直前に状態が変わる
- **WHEN** 初回は入力待ち・空欄だったが、送信直前の再観測では入力済みまたは選択画面になっている
- **THEN** `skipped input-not-empty` または `skipped dialog`（exit 0）となり、文字列も Enter も送らず入力を保持する

#### Scenario: CLAUDE_CONFIG_DIR の下の会話ログで送信を確かめる
- **GIVEN** `CLAUDE_PROJECTS_DIR` が未設定で、`CLAUDE_CONFIG_DIR` が指す一時ディレクトリの `projects/<パスの英数字以外を - にした名前>/` に、送った文を含む user の行を持つ `*.jsonl` があり、`HOME` の下には無い
- **WHEN** `epic-launch-tmux.sh` が送った文の届きを確かめる
- **THEN** 届いたと判定し、`started <ペイン ID>` を出す
