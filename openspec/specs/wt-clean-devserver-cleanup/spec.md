# wt-clean-devserver-cleanup Specification

## Purpose

`wt-clean` が `git worktree remove` で worktree を削除する際、その配下で稼働中のプロセス（dev サーバー等）を削除前に検出・停止し、誤って対象パス外や対話セッションを止めないようにするための振る舞いを定義する。

## Requirements

### Requirement: 削除前にプロセス残留を検出し停止する

`wt-clean` は `git worktree remove` を実行する全ての箇所（Step B-🟢 自動削除、Step B-🟡 LLM 退避後削除、Pass 2 の 🔴 破棄削除・🟡 dirty 破棄・🔴 マージ後削除）で、その直前に削除対象 worktree のパス配下で稼働中のプロセスを `lsof +D "$WT"` により検出するものとする（SHALL）。`lsof` が使えない環境では `pgrep -f "$WT"` にフォールバックし、フォールバックを使用したことをログに明示するものとする（SHALL）。

#### Scenario: 稼働中の dev サーバーがある worktree を削除する

- **GIVEN** 削除対象 worktree 配下で `next dev` プロセスが稼働している
- **WHEN** `wt-clean` がその worktree に対して `git worktree remove` を実行しようとする
- **THEN** `git worktree remove` の実行前に `lsof +D` で当該プロセスの PID を検出する

#### Scenario: 稼働中プロセスが無い worktree を削除する

- **GIVEN** 削除対象 worktree 配下で稼働中のプロセスが存在しない
- **WHEN** `wt-clean` がその worktree に対して `git worktree remove` を実行しようとする
- **THEN** 「稼働中プロセスなし」の 1 行がログに表示され、待機なしで `git worktree remove` に進む

### Requirement: SIGTERM → 生存確認 → SIGKILL フォールバックで停止する

`wt-clean` は検出したプロセスへ SIGTERM を送信し、数秒待って生存確認（`kill -0`）を行い、まだ生存していれば SIGKILL を送信するものとする（SHALL）。

#### Scenario: SIGTERM で正常終了する

- **GIVEN** 削除対象 worktree 配下で dev サーバープロセスが稼働している
- **WHEN** `wt-clean` が SIGTERM を送信し、数秒後に生存確認する
- **THEN** プロセスが終了していることを確認し、SIGKILL は送信しない

#### Scenario: SIGTERM に応答しないプロセスを SIGKILL する

- **GIVEN** 削除対象 worktree 配下のプロセスが SIGTERM を無視して稼働し続けている
- **WHEN** `wt-clean` が数秒待って生存確認する
- **THEN** プロセスがまだ生存していることを検出し、SIGKILL を送信して停止させる

### Requirement: 停止結果をログに明示する（無音実行の禁止）

`wt-clean` は停止したプロセスの PID とコマンド名、またはプロセスが見つからなかった旨を必ず 1 行以上のログとして表示するものとする（SHALL）。無音での停止・無音でのスキップを行ってはならない（SHALL NOT）。

#### Scenario: 停止したプロセスがログに表示される

- **WHEN** `wt-clean` が対象 worktree 配下のプロセスを SIGTERM または SIGKILL で停止する
- **THEN** 停止した PID とコマンド名を含む行がその場でログ表示される

### Requirement: 対象パス外・対話セッションの誤 kill を防ぐ

`wt-clean` は検出範囲を削除対象 worktree のパス配下に厳密に限定し、メインリポや他の worktree で稼働するプロセスを対象にしてはならない（SHALL NOT）。また、検出したプロセスのコマンド名がシェル（`bash`/`zsh`/`sh`/`fish`）や対話用ツール（`tmux`/`ssh`/`vim`/`nvim`/`code`/`Cursor` 等）に一致する場合は停止対象から除外し、その旨をログに明示するものとする（SHALL）。

#### Scenario: 他の worktree のプロセスは対象にしない

- **GIVEN** 削除対象ではない別の worktree 配下で dev サーバーが稼働している
- **WHEN** `wt-clean` が削除対象 worktree に対してプロセス検出を行う
- **THEN** 別の worktree のプロセスは検出・停止の対象に含まれない

#### Scenario: 対象 worktree に cd しているだけのシェルは止めない

- **GIVEN** 削除対象 worktree のディレクトリを cwd とする対話シェル（`zsh` 等）が起動している
- **WHEN** `wt-clean` がプロセス検出を行う
- **THEN** そのシェルのコマンド名が除外リストに一致し、停止対象から除外され、除外した旨がログに表示される

### Requirement: 自己検証にプロセス残留チェックを含める

`wt-clean` の自己検証（`wt-clean-verification.md`）は、削除した worktree について削除対象パス配下にプロセスが残留していないことを確認項目に含めるものとする（SHALL）。

#### Scenario: 完了宣言前にプロセス残留なしを確認する

- **WHEN** `wt-clean` が worktree の削除処理を完了し、完了レポートを提示する
- **THEN** 自己検証の確認項目に「削除対象 worktree 配下のプロセス残留なし」が含まれている
