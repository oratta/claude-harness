行番号は仕様づくりの時点（HEAD 7225146d）の値。前のタスクの編集でずれるので、編集前に該当範囲を読んで確かめる。テストは各節の実装より先に書き、落ちることを見てから実装する。

## 1. observe の原因の仕分け（pr-state.sh）

- [x] 1.1 `pr-state.bats` の「observe: やり直しに当たるかの仕分け」の並びに次のテストを足す: `conclusion: CANCELLED` のチェック（job 77）に `The job running on runner mac-1 has exceeded the maximum execution time of 40 minutes.` の annotation を渡すと `.checks[0].cause` が `job-timeout`・`retry` が `true`／annotation が `The operation was canceled.` だけの `CANCELLED` は `real`・`retry` が `false`／`--unrelated test` を同時に渡しても `job-timeout`／同名チェックの job 77 と job 88 で job 77 だけに上限時間の annotation があるとき job 88 は `real`・`retry` が `false`／1 つのジョブに通信切れと上限時間の両方の annotation があれば `runner-lost`。上限時間の文言はファイル冒頭の `LOST` の隣に定数で置く。触る範囲: plugins/dev-workflow/tests/pr-state.bats:12（`LOST` の定数）、plugins/dev-workflow/tests/pr-state.bats:166-221（observe の仕分けのテストの並び）
- [x] 1.2 `pr-state.sh` に上限時間の annotation の文言 `maximum execution time` の定数を足し、`observe` の `cause` の判定に、`runner-lost` の次・`unrelated` の前の分岐として `job-timeout` を足す（ジョブ ID で `annotations_by_job` を引く部分一致。`runner-lost` と同じ書き方）。定数は `cmd_observe` の `jq` 呼び出しに `--arg` で渡す。触る範囲: plugins/dev-workflow/scripts/pr-state.sh:35-36（文言の定数）、plugins/dev-workflow/scripts/pr-state.sh:52-71（jq の `observe`）、plugins/dev-workflow/scripts/pr-state.sh:103-107（`cmd_observe` の `jq` 呼び出し）

## 2. decide の一手（pr-state.sh）

- [x] 2.1 `pr-state.bats` の decide のテストの並びに次のテストを足す: HEAD `t1` の `job-timeout` の `ci-fail`（`view` と上限時間の hints を `watch` に通す）を 2 回続けると 1 回目は `rerun`、2 回目は `escalate` で `PREV` の `raised` が `true`・`fixes` が無い／前回の状態が `{state: "wait", head: "t1", reran_head: "t1", fixes: 1}` のとき `escalate` で `fixes` は 1 のまま／`job-timeout` と `real` が混ざった（`retry: false`）同じ HEAD の 2 回目は `fix`／打ち切りで `escalate` になったあと HEAD が変わった `job-timeout` は `none`／`checks` が空で `retry: true` の観測（既存の `obs` ヘルパー）の同じ HEAD の 2 回目は今までどおり `fix`。既存の `Ne1-Ne2 (runner-lost hint)` と `decide: two failures on the same head rerun only once` の期待値（2 回目は `fix`）は変えない。触る範囲: plugins/dev-workflow/tests/pr-state.bats:265-274（`runner-lost` の 2 回目が `fix` のテスト。確認のみ）、plugins/dev-workflow/tests/pr-state.bats:313-345（やり直しと `escalate` のテストの並び。この後ろに足す）
- [x] 2.2 `pr-state.sh` の jq の `decide` に、`rerun` の分岐の直後・`fixes` が 2 以上の分岐の前に、「観測が `ci-fail` で `retry` が `true` で、`checks` に `cause` が `job-timeout` の要素がある」ときの分岐を足す。一手は `escalate`、`next` は見た状態に `{raised: true}` を重ねたもの（`fixes` は触らない）。`checks` が無い観測でエラーにならない書き方（`.checks[]?` など）にする。触る範囲: plugins/dev-workflow/scripts/pr-state.sh:72-83（jq の `decide`）
- [x] 2.3 `pr-state.sh` 冒頭の契約コメントを直す: `observe` の `cause` の順に `job-timeout`（annotation に上限時間の文言）を足し、`decide` の説明に「上限時間の打ち切りは、やり直したあと同じ HEAD でまた起きたら `fix` でなく `escalate`」を 1 文足す。触る範囲: plugins/dev-workflow/scripts/pr-state.sh:12-23（サブコマンドの説明）
- [x] 2.4 `bats plugins/dev-workflow/tests/pr-state.bats` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 3. 見張りを通した確認（ci-watch.bats）

- [x] 3.1 `ci-watch.bats` に次のテストを足す: `wait` で、`CANCELLED` のチェック（run 11・job 77）に上限時間の annotation があると `.obs.checks[0].cause` が `job-timeout`・`.obs.retry` が `true`／`next` で、状態ファイルが無いとき `.act` が `rerun`・状態ファイルの `.reran_head` が `h1`・`.fixes` が `null`／`next` で、状態ファイルが `{"state":"wait","head":"h1","reran_head":"h1"}` のとき `.act` が `escalate`・状態ファイルの `.raised` が `true`・`.fixes` が `null`／`next` で、annotation が `The operation was canceled.` だけの `CANCELLED` は `.act` が `fix`・`.obs.checks[0].cause` が `real`。上限時間の文言はファイル冒頭の `LOST` の隣に定数で置く。`ci-watch.sh` 自体は編集しない（判定は `pr-state.sh` を通るだけなので、タスク 1.2 と 2.2 のあとはこのテストがそのまま通る）。触る範囲: plugins/dev-workflow/tests/ci-watch.bats:13（`LOST` の定数）、plugins/dev-workflow/tests/ci-watch.bats:107-114（通信切れの `wait` のテスト。この後ろに足す）、plugins/dev-workflow/tests/ci-watch.bats:213-241（`next` の `escalate`・`--unrelated` のテストの並び。この後ろに足す）

## 4. 共有 reference（ci-watch.md）

- [x] 4.1 `ci-watch.bats` の `reference:` の並びに次のテストを足す: reference に `job-timeout` の語があり、`escalate` の動きの行に上限時間で打ち切られたこと・ランナーの状態を確かめてほしいこと・実装者に直しを頼まないことが書かれている／`--unrelated` を渡す基準の節に `job-timeout` は判断の対象でないことが書かれている／`job-timeout` と `wait` の `timeout` が別の出来事だと書かれている。触る範囲: plugins/dev-workflow/tests/ci-watch.bats:290-367（`reference:` のテストの並び。末尾の `reference:` のテストの後ろに足す）
- [x] 4.2 `references/ci-watch.md` を直す。「5. `--unrelated` を渡す基準」の冒頭の段落に、`cause` が `job-timeout`（ジョブが上限時間で打ち切られた）のチェックはこの判断の対象でなく、渡さなくても同じ HEAD で 1 回やり直されることを 1〜2 文で足す（守備範囲の段落は変えない）。「6. `next` の一手ごとの動き」の表の `escalate` の行に、`obs.checks` に `cause` が `job-timeout` のチェックがあるときは、落ちたチェック名と PR の URL に加えて「ジョブが上限時間で打ち切られた。ランナーの状態を確かめてほしい」と伝え、実装者に直しを頼まないことを足す。同じ節に、`job-timeout` は CI のジョブ自身の上限時間での打ち切りで、4 の表の `timeout`（見張りの上限時間）とは別であることを 1 文で書く。触る範囲: plugins/dev-workflow/references/ci-watch.md:49-56（5 の基準）、plugins/dev-workflow/references/ci-watch.md:58-66（6 の表）
- [x] 4.3 `bats plugins/dev-workflow/tests/ci-watch.bats` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 5. 変更の記録と全体の確認

- [x] 5.1 変更の記録を `plugins/dev-workflow/changes/991.md` に書く: `observe` の `cause` に `job-timeout` が増えること（見分ける文言・判定の順）、`decide` が打ち切りの 2 回目を `escalate` にすること（`fixes` は増えない・出力の形と `act` の種類は変わらない）、`runner-lost` と `unrelated` の動きは変わらないこと、`wait` の上限時間の既定値は変えていないこと、戻し方。親のエピックに触れるときは genetta-inc/flatmate#1566 と書く（このリポジトリの番号として書かない）。触る範囲: plugins/dev-workflow/changes/991.md（新規）
- [x] 5.2 `scripts/test.sh pr-state ci-watch` が exit 0 になることを確かめる（issue の受け入れ条件）。触る範囲: なし（実行のみ）
- [x] 5.3 `openspec validate ci-watch-job-timeout-cause --strict` が通ることを確かめる。触る範囲: なし（実行のみ）
