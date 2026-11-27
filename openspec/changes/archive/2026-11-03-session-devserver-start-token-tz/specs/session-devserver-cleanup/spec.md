## MODIFIED Requirements

### Requirement: セッション開始時に目印を付ける

worktree プラグインの SessionStart フックは、セッションの持ち主である Claude Code プロセスを表す目印 `CLAUDE_SESSION_PROC_MARK=<claude_pid>.<start_token>` を、`export CLAUDE_SESSION_PROC_MARK=<claude_pid>.<start_token>` の 1 行として `CLAUDE_ENV_FILE` に追記するものとする（SHALL）。`start_token` は `LC_ALL=C TZ=UTC ps -o lstart= -p <claude_pid>` の出力から英数字以外を除いた文字列とし、目印付け・後始末・掃除のどこで計算しても `LC_ALL=C` と `TZ=UTC` を付けるものとする（SHALL）。持ち主が見つからない、または `CLAUDE_ENV_FILE` が未設定・書き込めないときは目印を書かず、フックは会話に何も出力せず exit 0 で終わるものとする（SHALL）。既存の `CLAUDE_ENV_FILE` の内容を上書きしてはならない（SHALL NOT）。

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
