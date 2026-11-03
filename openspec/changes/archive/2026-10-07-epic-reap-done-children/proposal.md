## Why

`/develop <エピック番号>` を Orca 経路で回すと、マージされ issue が閉じた子のワークツリーが Claude のタブごと残り続け、オーナーが手で消している（2026-10-08 時点で、エピック #272 の issue-689 と issue-690 が `workspaceStatus: in-progress` のまま残っていた）。Orca の「完了しました」の通知も子 issue のクローズも、「用が済んだ子」と「マージ後の動作確認をオーナーに頼んで待っている子」を見分けられないので、片付けのきっかけに使えない。ハーネスには、子から親へ「もう不要」と伝える仕組みが無い（issue #805、エピック #811）。

あわせて、同じファイルの同じ箇所を触る小さな直しを同じ PR で閉じる（エピック #811 の判断）: develop の完了時にワークツリーの片付けを聞かない（#459）、`wait` のテストがポーリングごとの stderr の空化を固定していない（#526）、README のエピックの回し方の記述（#472・#473）。

## What Changes

- `plugins/dev-workflow/scripts/epic-dispatch.sh` にサブコマンド `mark <done|waiting> <issue>` を足す。develop のループを終えたセッションが、自分のワークスペースに「用が済んだ」または「オーナーの確認待ち」の印を付ける。Orca のボードの列では `done` が `completed`、`waiting` が `in-review` に当たる
- `epic-dispatch.sh wait` に `--watch-done <N>` を足す。子 issue のクローズに加えて、指定した子のワークスペースに完了の印が付いたことでも終わり、stdout に `done <N>...` の行を出す。`--watch-done` を付けない呼び出しの振る舞いは変えない
- `epic-dispatch.sh` にサブコマンド `reap <child>...` を足す。完了の印が付き、安全確認（親の `launch` が作ったワークツリーである・マージ済み PR の最終コミットと HEAD が一致する・作業ツリーがきれい・`LLM/` が無い）をすべて通った子だけ、端末を閉じてワークツリーとローカルブランチを消す。1 つでも外れたら消さずに `kept <N> <理由>` を出す
- develop の SKILL.md に「ループの終わり」の節を足す。ワークツリーの片付けを提案も質問もせず（#459）、最後に `mark` を 1 回呼ぶ
- develop の SKILL.md「エピックの扱い」の Orca 経路に、`wait` を `--watch-done` 付きで呼ぶこと、`done` で起こされたら `reap` を呼ぶこと、`kept` の子はエピックに理由を 1 行コメントしてオーナーの判断に残すことを書く
- develop の手順書（`plugins/dev-workflow/skills/develop/` 配下）から `orca` のコマンドの記述（`orca terminal read`）を除く。`orca` のコマンドを呼ぶスクリプトは `epic-dispatch.sh` の 1 本のままにする
- `plugins/dev-workflow/tests/epic-dispatch.bats` の「gh の stderr はエラー行の直前に出る」テストに、3 回目のポーリングの stderr だけが出ることの確認を足す（#526）
- `README.md` と `plugins/dev-workflow/README.md` のエピックの回し方の記述で、unmanned がサブエージェント方式であることを明記し、`epic-dispatch.sh` のパスを正す（#472・#473）。片付けの動きも 1 文で足す

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: `epic-dispatch.sh` のサブコマンドに `mark`・`reap` が加わり、`wait` が完了の印でも終わるようになる。SKILL.md に「ループの終わり」の規定と、Orca 経路の片付けの手順が加わる。develop の手順書に `orca` のコマンドを書かない規定が加わる

## Impact

- 変えるファイル: `plugins/dev-workflow/scripts/epic-dispatch.sh`、`plugins/dev-workflow/tests/epic-dispatch.bats`、`plugins/dev-workflow/skills/develop/SKILL.md`、`README.md`、`plugins/dev-workflow/README.md`、`plugins/dev-workflow/changes/805.md`（新規）、`openspec/specs/dev-workflow-develop/spec.md`（archive で反映）
- 変えないファイル: wt-clean・wt-setup（エピック #811 の判断）。常時注入される `description` と `rules/` は増やさない
- 破壊的操作: `reap` は `orca worktree rm`（`--force` なし）と `git branch -D` を実行する。子が完了の印を付けたこと（またはオーナーがボードで `completed` に動かしたこと）を承認として扱うことは、2026-10-08 にオーナーが承認している（issue #805「承認の扱い」）。子ごとの確認は取らない
- LLM のコスト: 子の側で増えるのは Bash 1 回（`mark`）、親の側で増えるのは `done` で起こされたときの Bash 1 回（`reap`。出力は子 1 件につき 1 行）
- 後続: 子 issue #809 が、`epic-dispatch.sh` に親子関係を調べる処理を足す前提で書かれている。この change は #809 の範囲（`launch --note` のコメント投稿、`route` の `nested` 判定）に手を出さない
