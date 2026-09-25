## 1. テストを先に書く（Red）

- [ ] 1.1 `plugins/worktree/tests/session-proc-cleanup.bats` を作り、固定の `ps` 出力で止める対象の判定を確かめるテストを書く（目印あり・空の目印・別の目印・環境が読めない子孫・環境が読めない非子孫・他ユーザー・自分自身の除外）
- [ ] 1.2 持ち主の Claude Code の見つけ方のテストを書く（`comm` が `claude`、`node` + `@anthropic-ai/claude-code`、見つからないときは目印を書かない）
- [ ] 1.3 目印付けのテストを書く（`CLAUDE_ENV_FILE` への追記で既存内容を残す、未設定なら無出力・exit 0）
- [ ] 1.4 実プロセスのテストを書く（目印付き python3 は止まり、目印を空にした python3 は残り、TERM を無視する python3 は KILL で止まり、ログに PID・コマンド名・目印が残る。環境変数が読めない環境では skip）
- [ ] 1.5 SessionEnd の後始末が、持ち主が生きている間は止めず、終了後に止めることを確かめるテストを書く（待ち時間はテスト用に短くできるようにする）
- [ ] 1.6 掃除の 10 分間隔の判定のテストを書く
- [ ] 1.7 `hooks.json` に SessionStart の目印付けと SessionEnd の後始末が登録されていることを確かめるテストを書く

## 2. 実装（Green）

- [ ] 2.1 `plugins/worktree/scripts/session-proc-reaper.sh` を作る（`--session-end <mark>` と `--sweep` の 2 モード、対象の決定、TERM → 3 秒 → KILL、直前の目印の読み直し、ログ追記と 1 世代の回転）
- [ ] 2.2 `plugins/worktree/scripts/session-proc-mark.sh` を作る（持ち主の特定、`CLAUDE_ENV_FILE` への追記、10 分間隔での掃除の切り離し起動、無出力・常に exit 0）
- [ ] 2.3 SessionEnd 用の入口（後始末を目印を外した環境で切り離して起動し、すぐ exit 0）を作る
- [ ] 2.4 `plugins/worktree/hooks/hooks.json` に SessionStart と SessionEnd を登録する
- [ ] 2.5 bats を bash と zsh の両方の落とし穴（`for pid in $pids`、ループ内の `local`、`(` を区切りに使う）を避けて書けているか、既存の `kill_devserver_under` のコメントと照らして確かめる

## 3. 文書と記録

- [ ] 3.1 `plugins/worktree/references/session-devserver-cleanup.md` を書く（仕組み、目印を外す書き方 `CLAUDE_SESSION_PROC_MARK= nohup <cmd> &`、ログの場所、止まらないもの＝環境変数が読めず目印を持つ祖先もいないプロセス、wt-clean との関係）
- [ ] 3.2 `plugins/worktree/changes/470.md` に変更の記録を書く（版は上げない）

## 4. 確認

- [ ] 4.1 `scripts/test.sh` を全件実行し、exit code を記録する
- [ ] 4.2 実機で、Bash ツールから `nohup python3 -m http.server` と目印を外したものを起動 → 後始末を走らせ、前者だけが止まり、ログに残ることを確かめる（wrangler / next はこのリポジトリに無いので、node の常駐プロセスで代える）
- [ ] 4.3 `openspec validate session-devserver-cleanup --strict` が通ることを確かめる
