## 1. epic-dispatch.sh の mark に stopped / resumed を足す

- [ ] 1.1 `mark` の種別に `stopped`（コメント欄を `epic-stopped`）と `resumed`（コメント欄が `epic-stopped` / `epic-stopped-seen` のときだけ `epic-resumed`、それ以外は `skipped <issue> not-stopped`）を足す。どちらも `--workspace-status` を渡さず `orca worktree set --worktree current --comment <値>` を 1 回呼ぶ。linkedIssue の一致の確認・`no-workspace`・`failed` は `done` / `waiting` と共通にする。`resumed` は `orca worktree current --json` の `.result.worktree.comment` を読む（新しい `orca` の呼び出しは足さない） 触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:284-311（cmd_mark）
- [ ] 1.2 冒頭のコメントの使い方の行・`mark` の説明・引数の誤りの説明・正本の要件名の列挙（新しい要件「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」を足す）と、`usage` の `mark` の行を `<done|waiting|stopped|resumed>` にする 触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:7-9、plugins/dev-workflow/scripts/epic-dispatch.sh:57-60、plugins/dev-workflow/scripts/epic-dispatch.sh:67-76、plugins/dev-workflow/scripts/epic-dispatch.sh:78-88（usage）

## 2. epic-dispatch.sh の wait に --watch-stopped を足す

- [ ] 2.1 `--watch-stopped`（値なし）を受け付ける。`--watch-done` も位置引数の子も無いときは今までどおり使い方を出す（`--watch-stopped` だけでは足りない）。`--watch-done` か「`--watch-stopped` と位置引数の子 1 件以上」のどちらかがあるときに、`orca` / `jq` / `orca worktree current --json` の `repoId` を確かめる 触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:314-343（cmd_wait の引数解析と前提の確認）
- [ ] 2.2 ポーリングごとに一覧を 1 回だけ取り（`--watch-done` と共用）、そのポーリングで閉じていない位置引数の子のうち、同じ `repoId`・linkedIssue が一致・archive されていない・`comment` が `epic-stopped` のワークツリー全部に `orca worktree set --worktree path:<パス> --comment epic-stopped-seen` を呼ぶ（`orca` の出力は stderr）。全部 exit 0 の子を止まった子にし、1 つでも失敗した子があればそのポーリングを失敗したポーリングに数える（`wsfail=1` と同じ扱い） 触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:345-375（ポーリングの本体）
- [ ] 2.3 出力を `closed` → `done` → `stopped` の順に、該当するものだけ 1 行ずつ出して exit 0 にする。失敗したポーリングの数え方（閉じた子・印が付いた子・止まった子がいれば exit 0 を優先）と `error workspaces` の条件を合わせる。冒頭のコメントの `wait` の説明に `--watch-stopped` と `stopped` の行を足す 触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:376-403、plugins/dev-workflow/scripts/epic-dispatch.sh:7、plugins/dev-workflow/scripts/epic-dispatch.sh:42-56、plugins/dev-workflow/scripts/epic-dispatch.sh:83（usage の wait の行）

## 3. bats のテスト

- [ ] 3.1 スタブの補助を広げる: `wt_entry` に 6 番目の引数 `comment`（既定は空文字）を足して一覧の 1 件に `"comment"` を出す。`set_current` に 2 番目の引数 `comment` を足す。`orca worktree set` の失敗を `--comment` の呼び出しだけで起こせるようにする（今の `worktree set` の分岐の終了コードの設定を読み、足りなければ `set_comment_exit` を足す） 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:47-75（orca のスタブ）、plugins/dev-workflow/tests/epic-dispatch.bats:208-223（wt_entry・set_list・set_current）
- [ ] 3.2 `mark` のテストを足す（spec の Scenario「自分の issue のワークスペースに止まった印を付ける」「別の issue のワークスペースには止まった印を付けない」「止まった印があるときだけ再開の印に書き換える」「止まった印を付けられなければ failed」）。引数の誤りのテストの種別の例を新しい種別に合わせて見直す 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:910-995（mark のテスト）
- [ ] 3.3 `wait --watch-stopped` のテストを足す（spec の Scenario「止まった子を受けた印に書き換えて stopped で終わる」「受けた印と再開の印では起きない」「閉じた子・印が付いた子・止まった子は 3 行で出す」「閉じた子は止まった子に数えない」「別の repo や archive されたワークツリーの止まった印は数えない」「受けた印に書き換えられないポーリングが 3 回続いたら error で終わる」「--watch-stopped が無ければコメント欄を見ない」「--watch-stopped だけで子が無ければ使い方を出す」） 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1146-1240（wait --watch-done のテストのあと）
- [ ] 3.4 SKILL.md の文言のテストを足す・直す: 子が止まるときの節（`nested`・`子の停止: 主の返事待ち`・項目の 5 つ・`mark stopped`・`mark resumed`・`途中経過:` に引き継ぎの URL）、Orca 経路の `--watch-stopped` と `stopped` の手順（止まった子を外さずに再び待つ）。既存の「Orca route reacts to closed, timeout and error」の `子のタブ`・`検知できない` は、記録を残さずに止まった子の文として残るので通ることを確かめる 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1479-1488、plugins/dev-workflow/tests/epic-dispatch.bats:1549-1608（skill のテストの末尾に足す）

## 4. develop の SKILL.md

- [ ] 4.1 「保留で止まるときの引き継ぎ」の節のあと（「## モデル」の前）に、エピックの子が主の返事を待って止まるときの節を足す。spec の要件「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」の子の側の 6 点を書く。`orca` のサブコマンドを書かない 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:320-322（新しい節を挟む）
- [ ] 4.2 Orca 経路の手順 2 の `wait` の呼び出しに `--watch-stopped` を足し、出力の説明を `closed`・`done`・`stopped` の 1〜3 行にする。`stopped <N>...` で起こされたときの手順を、番号を振り直さずに手順 7 のあとに 8 として足す（最新の `子の停止:` を読んで報告し、止まった子を外さずに 2 に戻る。返事の仕方は書かない）。手順 5 の「子が自分のタブで質問して止まっていても…検知できない」を、記録を残さずに止まった子に限る文に直す（`子のタブ`・`検知できない` の語は残す）。ほかの手順と節には触れない 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:380（手順 2）、plugins/dev-workflow/skills/develop/SKILL.md:383（手順 5）、plugins/dev-workflow/skills/develop/SKILL.md:385（手順 7 のあと）

## 5. 変更の記録と確認

- [ ] 5.1 変更の記録を書く（何が増えたか・`mark` の新しい種別と `wait --watch-stopped`・SKILL.md の手順・入れなかったもの（入力待ちでの推定）とその根拠・受け入れること（主のコメント欄のメモの上書き）・戻し方） 触る範囲: plugins/dev-workflow/changes/1033.md（新規）
- [ ] 5.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats` と `openspec validate epic-child-stop-signal --type change --strict` を通す。常時注入の予算のテスト（`tests/injection-budget.bats`）は SKILL.md の本文を数えないことを確かめ、数えるなら通す 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats、openspec/changes/epic-child-stop-signal/
- [ ] 5.3 (3a) の return の `画面確認:` 行は「不要」とし、design.md「実機での確かめ方」の 1〜4 を本体が実機の Orca で行うことを書く（スクリプトの往復は bats で、通しの確認は実機でしか確かめられない）
