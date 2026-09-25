## ADDED Requirements

### Requirement: セッション開始時に目印を付ける

worktree プラグインの SessionStart フックは、セッションの持ち主である Claude Code プロセスを表す目印 `CLAUDE_SESSION_PROC_MARK=<claude_pid>.<start_token>` を、`export CLAUDE_SESSION_PROC_MARK=<claude_pid>.<start_token>` の 1 行として `CLAUDE_ENV_FILE` に追記するものとする（SHALL）。`start_token` は `LC_ALL=C ps -o lstart= -p <claude_pid>` の出力から英数字以外を除いた文字列とし、目印付け・後始末・掃除のどこで計算しても `LC_ALL=C` を付けるものとする（SHALL）。持ち主が見つからない、または `CLAUDE_ENV_FILE` が未設定・書き込めないときは目印を書かず、フックは会話に何も出力せず exit 0 で終わるものとする（SHALL）。既存の `CLAUDE_ENV_FILE` の内容を上書きしてはならない（SHALL NOT）。

#### Scenario: Bash ツールから起動したプロセスが目印を持つ

- **GIVEN** SessionStart フックが目印を `CLAUDE_ENV_FILE` に追記した
- **WHEN** そのセッションの Bash ツールから `nohup python3 -m http.server 4021 &` を起動する
- **THEN** 起動した python3 の環境変数に `CLAUDE_SESSION_PROC_MARK=<そのセッションの値>` が含まれる

#### Scenario: ロケールが違っても同じ目印になる

- **GIVEN** 持ち主の Claude Code プロセスが動いている
- **WHEN** `LC_TIME=ja_JP.UTF-8` の環境と `LC_ALL=C` の環境でそれぞれ `start_token` を計算する
- **THEN** 両者は同じ値になり、掃除は持ち主を生きていると判定する

#### Scenario: CLAUDE_ENV_FILE が無い

- **GIVEN** `CLAUDE_ENV_FILE` が未設定
- **WHEN** SessionStart フックが走る
- **THEN** 何も書かず、標準出力に何も出さず exit 0 で終わる

### Requirement: セッション終了時に目印を持つプロセスを止める

SessionEnd フックは、フックの PID から親をたどって持ち主の Claude Code プロセスを特定して目印の値を計算し（フックのプロセス環境の変数には頼らない）、新しいセッションとして切り離した後始末プロセスにその値を渡して起動し、すぐ exit 0 で戻るものとする（SHALL）。後始末プロセスはフックの親とそのプロセスグループが終了しても動き続けるものとする（SHALL）。後始末プロセスは目印の持ち主の Claude Code プロセスの終了を最大 30 秒（既定値）待ち、終了していればそのセッションの目印を持つ自分のユーザーのプロセスとその子孫を止めるものとする（SHALL）。持ち主が待ちの上限を過ぎても同じ開始時刻で生きていれば、何も止めずに終わるものとする（SHALL）。後始末プロセス自身は目印を持たずに起動するものとする（SHALL）。この要件と以下の要件の待ち時間・間隔の既定値は、テスト用の環境変数（`SESSION_REAPER_OWNER_WAIT_SECS` / `SESSION_REAPER_TERM_GRACE_SECS` / `SESSION_REAPER_SWEEP_INTERVAL_SECS`）で変えられる。

#### Scenario: 正常終了で dev サーバーと子プロセスが止まる

- **GIVEN** セッションの Bash ツールから `wrangler dev`・`next dev`・`python -m http.server` をバックグラウンドまたは `nohup` で起動している
- **WHEN** セッションを正常に終了する
- **THEN** それらと子プロセス（workerd・esbuild 等）が全部止まり、`ps` で 0 本になる

#### Scenario: /clear では止めない

- **GIVEN** セッションの Bash ツールから dev サーバーを起動している
- **WHEN** `/clear` を実行し、SessionEnd が走るが Claude Code プロセスは続く
- **THEN** dev サーバーは止まらない

### Requirement: 落ちたセッションの目印を持つプロセスを定期的に止める

SessionStart フックは、前回の掃除から 10 分（既定値）以上たっていれば、切り離した掃除プロセスを起動するものとする（SHALL）。掃除プロセスは、目印の持ち主（PID と開始時刻の組）がもう存在しない目印を持つ自分のユーザーのプロセスとその子孫を止めるものとする（SHALL）。持ち主が生きている目印を持つプロセスは止めてはならない（SHALL NOT）。

#### Scenario: KILL で落ちたセッションの残りが止まる

- **GIVEN** セッションの Bash ツールから dev サーバーを起動したあと、そのセッションの Claude Code を KILL で落とした（SessionEnd は走っていない）
- **WHEN** 10 分以上たってから別のセッションが始まる
- **THEN** 掃除プロセスが残った dev サーバーを止める

#### Scenario: 動いている別セッションのプロセスは止めない

- **GIVEN** 別の Claude Code セッションが動いていて、その Bash ツールから dev サーバーを起動している
- **WHEN** 掃除プロセスが走る
- **THEN** その dev サーバーは止まらない

### Requirement: 目印を持たないプロセスと環境変数を読めないプロセスは止めない

止める対象は、環境変数に対象の目印を持つ自分のユーザーのプロセスと、その子孫のうち環境変数が読めないものに限るものとする（SHALL）。子孫は PPID をたどって求め、環境変数が読めて対象の目印を持たないプロセス（無い・空・別の値）に当たったら、そのプロセスも配下も見ない（打ち切る）ものとする（SHALL）。読めない子孫を加えるのは、目印ありから読めないプロセスだけを経由して届く範囲に限る。「環境変数が読めない」とは、`ps -ww -E -o command=` の出力に `[A-Za-z_][A-Za-z0-9_]*=` の形の語が 1 つも無いことをいう。次のものは止めてはならない（SHALL NOT）: 目印を持たないプロセス（launchd から起動した住人・ダッシュボード、端末から人が手で起動したもの）、別の目印を持つプロセス、他ユーザーのプロセス、環境変数が読めず目印を持つ祖先もいないプロセス、目印を空にして起動したプロセスとその配下。

守備範囲: 入力は `ps -U <自分の uid>` で列挙した自分のユーザーのプロセスの一覧だけとする。拾いたいのは、持ち主が終了した目印を持つプロセスと、そこから環境変数が読めないプロセスだけを経由して届く子孫。通す例は、launchd の住人、端末から手で起動したもの、他ユーザーのプロセス、目印を外して起動したものとその配下、目印を持つ祖先がいない環境変数が読めないプロセス。止め漏れは wt-clean の `kill_devserver_under` が最後に拾うので、止め漏れの報告のたびに判定規則を足していくことを完了条件にしない。

#### Scenario: 目印の無いプロセスは残る

- **GIVEN** launchd から起動した住人と、端末から人が手で起動した `python3 -m http.server` が動いている
- **WHEN** 後始末または掃除が走る
- **THEN** どちらも止まらない

#### Scenario: 他ユーザーのプロセスは候補に入らない

- **GIVEN** root が所有するプロセスが動いていて、その環境変数は読めない
- **WHEN** 後始末または掃除が走る
- **THEN** そのプロセスは止める候補に入らず、止まらない

#### Scenario: 環境変数を読めない子孫は止める

- **GIVEN** 目印を持つ node の子として `/bin/sh` が動いていて、その環境変数は読めない
- **WHEN** 後始末が走る
- **THEN** node と `/bin/sh` の両方が止まる

#### Scenario: 目印を空にしたプロセスで子孫の探索を打ち切る

- **GIVEN** 目印付きの node の子として目印を空にして起動した node がいて、その子として `/bin/sh`（環境変数が読めない）がいる
- **WHEN** 後始末が走る
- **THEN** 目印付きの node だけが止まり、目印を空にした node と `/bin/sh` は残る

### Requirement: 目印を外して起動したプロセスはセッション終了後も残る

目印を空にして（`CLAUDE_SESSION_PROC_MARK= <cmd>`）起動したプロセスは、セッションが終わっても止めてはならない（SHALL NOT）。この書き方を worktree プラグインの references に文書化するものとする（SHALL）。

#### Scenario: 目印を外した dev サーバーは残る

- **GIVEN** セッションの Bash ツールから `CLAUDE_SESSION_PROC_MARK= nohup python3 -m http.server 4021 &` を起動した
- **WHEN** セッションを正常に終了する
- **THEN** その python3 は動き続ける

### Requirement: TERM で止まらないプロセスは KILL で止める

後始末と掃除は、対象に TERM を送り、3 秒（既定値）待って生存確認し、生きていれば KILL を送るものとする（SHALL）。TERM と KILL の直前に、目印ありとして拾ったものは同じ PID が同じ目印を持っていることを、子孫として加えたものは同じ PID・同じコマンド名・同じ PPID であることを確かめ、違えば送らないものとする（SHALL）。

#### Scenario: TERM を無視するプロセス

- **GIVEN** 目印を持ち、TERM を無視するプロセスが動いている
- **WHEN** 後始末が走る
- **THEN** TERM のあと 3 秒で生存が確認され、KILL で止まる

### Requirement: 止めたプロセスをログに残す

後始末と掃除は、止めた各プロセスについて時刻・送ったシグナル（`TERM` / `KILL`）・PID・コマンド名・目印・起動の種類（`session-end` / `sweep`）を 1 行ずつログファイルに追記するものとする（SHALL）。止めるものが無かったときも、その旨の 1 行を残すものとする（SHALL）。ログの場所は `${CLAUDE_PLUGIN_DATA}/session-devserver-cleanup.log`、`CLAUDE_PLUGIN_DATA` が未設定なら `~/.claude/logs/session-devserver-cleanup.log` とし、ディレクトリが無ければ作るものとする（SHALL）。

#### Scenario: 止めたものがログに残る

- **WHEN** 後始末が目印を持つ python3 を TERM で止める
- **THEN** ログに `TERM pid=<pid> comm=python3 mark=<値> trigger=session-end` を含む行が追記される
