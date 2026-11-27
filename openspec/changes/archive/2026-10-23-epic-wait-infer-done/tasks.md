## 1. テストを先に書く

- [x] 1.1 `tests/epic-dispatch.bats` に推定のテストを足す: 5 つを満たすと `done 11`・記録の `status` が `done`・`done_inferred_at` と `done_inferred_last_activity` が付き `extra` と `schema` が残る・stderr に `inferred done 11`／最後の活動が閾値より新しい・トランスクリプト 0 本・2 本のうち片方だけ新しい・`status` `waiting`・`stop` `stopped` / `stopped-seen` は `gh` を呼ばず `timeout`／2 本とも古ければ推定し `done_inferred_last_activity` が 2 本を通した最大値／同じ子を位置引数と `--watch-done` の両方に渡すと `closed 11` と `done 11` の 2 行／issue が `open`・`not_planned` で閉じたときは推定しない／`EPIC_DISPATCH_DONE_IDLE_SEC=300` で 10 分前の子が推定され、`abc` は exit 1・stdout 空・`gh` 0 回／残ったロックで 3 回のあと `error workspaces`・記録は `running` のまま／`launcher` が `orca` の子は `orca worktree set --worktree path:<子> --workspace-status completed` が 1 回。トランスクリプトの置き方は既存の `put_transcript` を使うか、任意の種類の行と `timestamp` を置けるよう引数を足す。`gh` のスタブが `--jq '.state + " " + (.state_reason // "")'` の形にも答えられるよう必要なら直す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1952-1990（`--watch-done` のテストの並び）、plugins/dev-workflow/tests/epic-dispatch.bats:4158-4175（`put_transcript`）、plugins/dev-workflow/tests/epic-dispatch.bats:103-372（`make_stub` の `gh` の答え方）
- [x] 1.2 回し方とループの終わりと ci-watch.md の文面のテストを足す（手順 2〜4 に `EPIC_DISPATCH_DONE_IDLE_SEC`・推定の `done` を同じに `reap`・`skipped <N> not-stopped` の子が推定で片付くこと／「ループの終わり」と ci-watch.md「`ready` を受けたあと」に「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と、マージ後の連絡を頼まないこと）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:442-444（`section`・`run_section`）の近くの skill のテストの並び、または plugins/dev-workflow/tests/develop-skill.bats

## 2. スクリプト

- [x] 2.1 トランスクリプトの置き場のディレクトリを返す関数を `decide_relaunch` から切り出し、`decide_relaunch` と推定の両方から使う（「ちょうど 1 本」の判定は `decide_relaunch` の側に残し、挙動は変えない）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1005-1046（`decide_relaunch`）
- [x] 2.2 最後の活動（置き場の全部の `.jsonl` を通して `timestamp` を持つ行の最大値を epoch 秒と元の文字列で出す。0 本は無し）を読む関数を足し、推定の 5 条件を確かめて `es_modify` で書く関数（`status` `running`・`stop` が止まった印でないことの確かめ直し、`done_inferred_at`・`done_inferred_last_activity` の付与）を足す。書けたら `mirror_state <記録> <worktree> done` と stderr の `inferred done <N>: ...`。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1046-1050（`decide_relaunch` と `resolve_stopped` の間、新しい関数）
- [x] 2.3 `cmd_wait` で、`--watch-done` があるとき `EPIC_DISPATCH_DONE_IDLE_SEC` を待つ前に確かめ（空か数字でなければ使い方を出して exit 1）、`--watch-done` の子の印を見るループで、`status` が `done` でない子に 2.2 の推定を掛ける（`gh` の失敗は数えない・書き込みの失敗は `wsfail=1`）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1130-1145（引数の確認）、plugins/dev-workflow/scripts/epic-dispatch.sh:1170-1178（`for n in $watch` のループ）
- [x] 2.4 冒頭のコメントの `wait` の説明に推定の 5 条件・`EPIC_DISPATCH_DONE_IDLE_SEC`（既定 1800）・推定の `done` が同じ行に出ること・推定の項目を、引数の誤りの段落に `EPIC_DISPATCH_DONE_IDLE_SEC` の誤りを足す。設計の正本の要件名の列に新しい要件名を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:79-94（wait の説明）、plugins/dev-workflow/scripts/epic-dispatch.sh:168-176（トランスクリプトと引数の誤り）、plugins/dev-workflow/scripts/epic-dispatch.sh:179-191（正本の要件名の列）
- [x] 2.5 `epic-state.sh` 冒頭のコメントの項目の列に、親が推定したときだけ書く `done_inferred_at`・`done_inferred_last_activity` を足す。触る範囲: plugins/dev-workflow/scripts/epic-state.sh:1-10

## 3. 手順書

- [x] 3.1 develop SKILL.md「回し方」の手順 2（`--watch-done` の説明に推定の条件と `EPIC_DISPATCH_DONE_IDLE_SEC`）・手順 3（推定の `done` も同じに `reap`。同じ子が `closed` と `done` の両方に出たら手順 4 を処理してから `reap`）・手順 4（`notify-closed` の `skipped <N> not-stopped` の子は推定で片付く。主にステータスを変えるよう頼まない）を直す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:507-509
- [x] 3.2 develop SKILL.md「ループの終わり」の「PR がマージされていないとき…は呼ばない」の項に、エピックの子が主にマージを頼んで終えるときはマージ後の連絡を頼まず「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書くこと（理由: 親の `wait` が完了を推定する）を足す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:205-215
- [x] 3.3 `references/ci-watch.md`「`ready` を受けたあと」の 1〜3 のあとに、エピックの子のセッションがオーナーにマージを頼んで見張りを終えるとき（1 の親の判断を待たない場合・3・4 の表の `--until-merged` の `timeout`）の文面の規定を 1 か所にまとめて書く。4 の表の `timeout` の行からそこを指す。触る範囲: plugins/dev-workflow/references/ci-watch.md:72-89、plugins/dev-workflow/references/ci-watch.md:46

## 4. 記録と確認

- [x] 4.1 `plugins/dev-workflow/changes/1230.md` に変更記録を書く（何を・なぜ・新しい環境変数と既定・記録に足した項目）。版は上げない。触る範囲: plugins/dev-workflow/changes/1230.md（新規）
- [x] 4.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats`（変更したテストの範囲）と `shellcheck plugins/dev-workflow/scripts/epic-dispatch.sh` を通し、`openspec validate epic-wait-infer-done --type change --strict` を通す。触る範囲: なし（確認だけ）
