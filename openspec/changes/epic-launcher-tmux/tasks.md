## 1. 部品の選び方と契約の追加（epic-dispatch.sh）

- [ ] 1.1 テストを先に書く: `route` の判定順（`tmux`・`EPIC_DISPATCH_LAUNCHER`・Orca が先）、`launch` が記録の `launcher` に `tmux` を書く、`reply`・`reap` が記録の `launcher` の部品を呼ぶ（`orca` が呼ばれない）、`unregistered` の `ok` で別リポジトリの子が進む、`here` の空の `repo_id` が tmux で止まらない、Orca の既存の bats が書き換えなしで通る。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats`（末尾に追加。スタブの置き方は先頭の setup 付近）
- [ ] 1.2 `launcher()` を、選んだ部品の名前で `epic-launch-<名前>.sh` を呼ぶ形にする。選ぶ関数を足す（`EPIC_DISPATCH_LAUNCHER` → Orca の `here` → `TMUX` と `tmux`）。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:262-285`（`LAUNCHER`・`launcher()`・`mirror_state`）
- [ ] 1.3 `cmd_route` に `tmux` を足す。`EPIC_DISPATCH_LAUNCHER` の検査（`orca`・`tmux`・空以外は使い方で exit 1）。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:298-322`
- [ ] 1.4 `launch`・`adopt` は選んだ部品を記録の `launcher` に書く（`es_new_record` の引数）。`has no repoId` の停止は Orca の部品のときだけ。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:500-560`、`:640-650`（`es_new_record` の呼び出し）、`:1326-1345`（`cmd_adopt`）
- [ ] 1.5 `xrepo_resolve` は `unregistered` が `ok` を返したら登録は要らないとして `XR_CODE=ok`・`XR_ID` 空で通す。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:438-499`（`:476-481`）
- [ ] 1.6 `reply`・`notify-closed`・`wait --resolve`・`reap` は子の記録の `launcher` の部品を呼び、入口と違う部品の子は `launcher-unavailable`。記録の `launcher` が `orca`・`tmux` でないものは読めない記録の扱い。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:714-760`（`deliver_reply`）、`:1171-1300`（`cmd_reap`）、`:782-850`（`cmd_notify_closed`）、`:951-1005`（`resolve_stopped`）
- [ ] 1.7 `mark`・`wait --watch-stopped` の `mirror_state` は記録の `launcher` が `orca` のときだけ呼ぶ今の条件のまま確かめる。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:277-282`

## 2. tmux の部品（epic-launch-tmux.sh）

- [ ] 2.1 テストを先に書く: 各サブコマンドの stdout・exit code、`orca` を呼ばないこと、`start` が `new-window` にコマンドを渡さず `send-keys -l` で打つこと、送信の確かめ（会話ログ）、シェルだけのペインへ送らないこと、`remove` が `--force` を付けないこと、知らないサブコマンドは exit 2。`tmux`・`git` を PATH 上のスタブにする。触る範囲: `plugins/dev-workflow/tests/epic-launch-tmux.bats`（新規。`tests/epic-dispatch.bats` の `calls()` の書き方を参考にする）
- [ ] 2.2 `epic-launch-tmux.sh` を書く。サブコマンド 12 個、使い方、待ち時間の環境変数は `epic-dispatch.sh` が渡した値を使う。ワークツリーは `<repo>/.claude/worktrees/issue-<N>`・ブランチ `worktree-issue-<N>`。入力待ちの画面の文字列は先頭の定数にする。触る範囲: `plugins/dev-workflow/scripts/epic-launch-tmux.sh`（新規。`epic-launch-orca.sh:1-60` の使い方とサブコマンドの並びに揃える）
- [ ] 2.3 `orca` の語を含む呼び出しの照合（`grep -rlE` の検査）が `epic-launch-orca.sh` の 1 本のままであることを確かめる。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats`（`grep -rlE` の照合 1 件）

## 3. SKILL.md の書き直し

- [ ] 3.1 テストを先に書く: 手順が 1 本で部品ごとの欄がある、「Orca 経路」の見出しが無い、サブエージェント方式は記録を書かない、`EPIC_DISPATCH_LAUNCHER` と `tmux` が書かれている、channel と unmanned の規定（`route` を呼ばない・別セッションを起こさない）が残っている。触る範囲: `plugins/dev-workflow/tests/develop-skill.bats`（エピックの扱いの照合の近く）、`plugins/dev-workflow/tests/develop-channel-mode.bats`（channel の照合は意味を変えない）
- [ ] 3.2 SKILL.md「エピックの扱い」→「回し方」を、共通の手順（起動・待ち・閉じた子・止まった子・片付け・完了）に部品ごとの欄を置く形に書き直す。`回し方:` のコメントに `tmux` を足す。触る範囲: `plugins/dev-workflow/skills/develop/SKILL.md:479-548`（回し方・完了条件）、`:46`（前提の表の `orca` の行）、`:207`、`:348-376`（子が主の返事を待って止まるとき）
- [ ] 3.3 SKILL.md の `orca` のコマンドの書き方の照合（要件「develop の手順書に orca のコマンドを書かず…」）が通ることを確かめる

## 4. 記録と検証

- [ ] 4.1 変更の記録を書く。触る範囲: `plugins/dev-workflow/changes/1123.md`（`## 3/3: 起動部品を tmux にも広げる（change epic-launcher-tmux）` を追記）
- [ ] 4.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/epic-launch-tmux.bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/develop-channel-mode.bats` と `shellcheck`（CI の workflow が読む検査コマンドを実装の段で確かめる）、`tests/injection-budget.bats`（SKILL.md の description を変えたとき）を通す。`openspec validate epic-launcher-tmux --type change --strict` を通す

## 5. 実機 1 回

- [ ] 5.1 tmux の中の実機で、入力待ちの画面の文字列と `#{pane_current_command}` の値を確かめ、2.2 の定数に反映する。使い捨ての検証用 repo を scratchpad に作り、`EPIC_DISPATCH_LAUNCHER=tmux` で子 1 件を `launch` → 子が独立した Claude Code のセッションとして起動し最初の指示が届く → 子が止まった印（`mark stopped`）を付けて親の `wait` が `stopped` で拾う → 子が `mark done` して親の `reap` がワークツリーを消し記録が消える、までを確かめ、結果を PR 本文と `changes/1123.md` に書く。画面の確認は要らない（tmux のペインを `capture-pane` で読む）
