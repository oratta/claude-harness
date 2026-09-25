## 1. テストを先に書く（Red）

- [x] 1.1 `plugins/worktree/tests/session-proc-cleanup.bats` を作り、固定の `ps` 出力で止める対象の判定を確かめるテストを書く（`SESSION_REAPER_PS_FIXTURE_DIR` を使う。目印あり・空の目印・別の目印・環境が読めない子孫・環境が読めない非子孫・他ユーザー・自分自身の除外・「目印付き node → 目印を空にした node → `/bin/sh`」で目印付き node だけが対象になる打ち切り・`NAME=` 形の語が無いことによる「読めない」の判定）
- [x] 1.2 持ち主の Claude Code の見つけ方のテストを書く（`comm` が `claude`、`node` + `@anthropic-ai/claude-code`、見つからないときは目印を書かない、`LC_TIME=ja_JP.UTF-8` を付けても `LC_ALL=C` と同じ `start_token` になる）
- [x] 1.3 目印付けのテストを書く（`CLAUDE_ENV_FILE` に `export CLAUDE_SESSION_PROC_MARK=<値>` の 1 行を追記し既存内容を残す、未設定なら無出力・exit 0）
- [x] 1.4 実プロセスのテストを書く（目印付き python3 は止まり、目印を空にした python3 は残り、TERM を無視する python3 は KILL で止まり、ログに PID・コマンド名・目印が残る。環境変数が読めない環境では skip）
- [x] 1.5 SessionEnd の後始末が、持ち主が生きている間は止めず、終了後に止めることを確かめるテストを書く（`SESSION_REAPER_OWNER_WAIT_SECS` で待ちを短くする）と、フックの親とそのプロセスグループを終了させても切り離した後始末が生き残ることを確かめるテストを書く
- [x] 1.6 掃除の間隔の判定のテストを書く（`SESSION_REAPER_SWEEP_INTERVAL_SECS` と `SESSION_REAPER_LOG_DIR` を使い、スタンプファイルがログと同じディレクトリにできること）
- [x] 1.7 `hooks.json` に SessionStart の目印付けと SessionEnd の後始末が登録されていることを確かめるテストを書く

## 2. 実装（Green）

- [x] 2.1 `plugins/worktree/scripts/session-proc-reaper.sh` を作る（`--session-end <mark>` と `--sweep` の 2 モード、持ち主の特定と `LC_ALL=C` での `start_token` 計算の共通関数、打ち切り付きの対象の決定、TERM → 既定 3 秒 → KILL、直前の読み直し（目印ありは目印、子孫は comm と PPID）、ログ追記と 1 世代の回転、ログディレクトリの `mkdir -p`、テスト用環境変数による既定値の差し替え）
- [x] 2.2 `plugins/worktree/scripts/session-proc-mark.sh` を作る（持ち主の特定、`CLAUDE_ENV_FILE` への `export` 行の追記、既定 10 分間隔での掃除の `perl -MPOSIX` による setsid 切り離し起動、無出力・常に exit 0）
- [x] 2.3 `plugins/worktree/scripts/session-proc-end.sh` を作る（フック環境の変数に頼らず、親をたどって持ち主から目印を計算し、`env -u CLAUDE_SESSION_PROC_MARK` と `perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV'` で後始末を切り離して起動し、すぐ exit 0）
- [x] 2.4 `plugins/worktree/hooks/hooks.json` に SessionStart と SessionEnd を登録する（`plugins/*/hooks/` は auto-merge の聖域パスなので、PR は自動マージされず主の明示承認が要る）
- [x] 2.5 bats を bash と zsh の両方の落とし穴（`for pid in $pids`、ループ内の `local`、`(` を区切りに使う）を避けて書けているか、既存の `kill_devserver_under` のコメントと照らして確かめる

## 3. 文書と記録

- [x] 3.1 `plugins/worktree/references/session-devserver-cleanup.md` を書く（仕組み、目印を外す書き方 `CLAUDE_SESSION_PROC_MARK= nohup <cmd> &`、`env -i` で起動したものは目印を外したことにならず目印の配下なら止まること、Bash から起動したものは種類を問わず止まる例（dev サーバー・子の Claude Code・`code` CLI など）、ログとスタンプファイルの場所、止まらないもの＝環境変数が読めず目印を持つ祖先もいないプロセス、wt-clean とは対象の母集団が違う（パス配下 vs 目印）ので除外基準も違うこと）
- [x] 3.2 `plugins/worktree/changes/470.md` に変更の記録を書く（版は上げない）

## 4. 確認

- [x] 4.1 `scripts/test.sh` を全件実行し、exit code を記録する
- [x] 4.2 実機で、Bash ツールから `nohup python3 -m http.server` と目印を外したものを起動 → 後始末を走らせ、前者だけが止まり、ログに残ることを確かめる（wrangler / next はこのリポジトリに無いので、node の常駐プロセスで代える）
- [x] 4.3 `openspec validate session-devserver-cleanup --strict` が通ることを確かめる
