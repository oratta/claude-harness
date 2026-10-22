## Why

エピックの子が主にマージを頼んで見張りを終えたあと、主がマージして記録先 issue が閉じても、子はもう動いていないので `epic-dispatch.sh mark done` を呼ばない。親は `closed` を受けて `notify-closed` を呼ぶが、これは止まった印（`stop` が `stopped` / `stopped-seen`）の子にしか効かず `skipped <N> not-stopped` になる。以後、親は `wait --watch-done` で完了の印を待ち続け、主が気づくまでワークツリーが片付かない（実例: genetta-inc/flatmate#1658、PR https://github.com/genetta-inc/flatmate/pull/1740 。`human-merge` が付き、flatmate の `auto-merge.yml` に `parent-merge-approved` が無いので子は主に直接マージを頼んだ）。子は完了報告で「マージしたら教えてください、ステータスを変えます」と主に頼んでいたが、主はこの往復を無駄だと言っている。

## What Changes

- `epic-dispatch.sh wait --watch-done <N>` が、完了の印の無いまま記録先が閉じた子の完了を推定する。条件は、記録の `status` が `running`・`stop` が `stopped` / `stopped-seen` でない・子のトランスクリプトがちょうど 1 本で最後の活動が新しい環境変数 `EPIC_DISPATCH_DONE_IDLE_SEC`（既定 1800 秒）以上前・子 issue が `closed` で `state_reason` が `completed`、のすべて。満たせば排他つきで `status` を `done` にし、推定の項目（`done_inferred_at`・`done_inferred_last_activity`）を記録に足し、Orca の印へ写して `done <N>` を返す（LLM なし）
- 片付けの安全確認（git がきれい・`LLM/` が無い・マージ済み PR の HEAD と一致など）は今の `reap` がそのまま行う。`reap` は変えない
- エピックの子（`route` が `nested`）が主にマージを頼むとき、「マージしたら教えてください」と頼まず、「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書く（`references/ci-watch.md`「`ready` を受けたあと」と develop SKILL.md「ループの終わり」）
- develop SKILL.md「回し方」の手順 2〜4 に、`--watch-done` の推定と、推定の `done` も子の付けた `done` と同じに `reap` することを書く
- `epic-dispatch.sh` 冒頭のコメント、bats テスト、変更記録を合わせる。版は上げない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: `epic-dispatch.sh wait --watch-done` が完了を推定する要件と、回し方の手順 2〜4・ループの終わりの文面の要件を足す
- `dev-workflow-epic-state`: 親が推定した完了を記録に書く要件（排他・推定の項目・Orca の印への写し）を足す
- `dev-workflow-ci-watch`: エピックの子が主にマージを頼むときの文面（マージ後の連絡を頼まない）の要件を足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_wait`・トランスクリプトの解決を `decide_relaunch` と共有する関数・冒頭のコメント）
- `plugins/dev-workflow/skills/develop/SKILL.md`（「ループの終わり」・「回し方」の手順 2〜4）
- `plugins/dev-workflow/references/ci-watch.md`（「`ready` を受けたあと」）
- `plugins/dev-workflow/tests/epic-dispatch.bats`
- `plugins/dev-workflow/changes/1230.md`（新規）
- 新しい環境変数 `EPIC_DISPATCH_DONE_IDLE_SEC`。`--watch-done` の子 1 件あたり、推定の候補になったポーリングでだけ `gh api` の呼び出しが 1 回増える
