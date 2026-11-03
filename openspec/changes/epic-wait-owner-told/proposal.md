## Why

エピックの親は、動いている子が全員主の返事待ちで止まっていても、`wait` の上限（親のキャッシュが 1 時間なら 3000 秒）で約 46 分ごとに起こされ、掛け直すたびに同じ質問を主に繰り返していた（flatmate のエピック #1722 の子 #1818 で約 30 時間）。`references/epic.md` の「待ちをやめてよい条件」には、主の返事が来ない限り見張りを終える出口が無い。止まった子への声かけ（#1383）も止まりから 24 時間まで続き、「何時間たったら記録から再開するか」の決まりが親と子でそろっていない。

## What Changes

- 親が主に上げた止まりを、子の記録に `told_uuid`（主に伝えた止まりの uuid）として書く新しいサブコマンド `epic-dispatch.sh told <子> <止まりの uuid>` を足す。手順 7・8 で主に上げる報告を出したら、親が呼ぶ
- `wait --watch-stopped` は、位置引数の子が全員「主に伝え済みの止まり」（`stop` が `stopped-seen`・`stop_uuid` が空でなく `told_uuid` と一致）のあいだ、上限（3000 秒など）で `timeout` を返さずに待つ。確認はスクリプトのポーリングだけで、親の LLM は起こさない
- その待ちは、止まりの uuid が変わる（`stopped`）・子 issue が閉じる（`closed`）・子が動き出す（主の返事が届いて会話ログが進み、記録が `resumed` になる）と、既存の行で返る。子が動き出したときは普通の上限を過ぎているので `timeout` で返り、親は 60 分以上の再開の決まりに従う
- 待ちに入ってから新しい上限（`EPIC_DISPATCH_OWNER_WAIT_SEC`、既定 43200 秒 = 12 時間）たっても変化が無ければ、`wait` は新しい行 `expired <子>...` で exit 0 を返す。親はエピックに再開の記録を残し、主に 1 通だけ「見張りを止めた。子のタブで答えたら `/develop <エピック番号>` で親を再開する」と伝えて、`wait` を掛けずに終える。「待ちをやめてよい条件」にこの場合を足す
- 止まった子への声かけの期限（今は止まりから 86400 秒）を同じ `EPIC_DISPATCH_OWNER_WAIT_SEC` にする
- `--resolve` 付きでこの待ちにいるあいだ、エピックか子 issue の判断の材料（本文と、親自身の `親の判断: ` の投稿を除くコメント）が処理済みの版から変わったら、その子の止まりを 1 回だけ `wait --resolve` と同じ判断にかけ直す。材料は `updated_at` が変わったときだけ読む。処理済みにするのは判断の直前に読んだ版で、判断のあいだに主が足した更新は次のポーリングで判断する。変わらないあいだは判断しない
- 長い待ちに入ったあとの一時の取得の失敗では待ちから出ず（普通の上限で `timeout` を返さない）、取得の失敗が続けば今までどおり `error` で返る
- 既存の要件「声かけは wait を終了させず親の起床を増やさない」の上限の扱いを、伝え済みでない子がいる場合（今までどおり `timeout`）と全員が伝え済みの場合（長い待ち）に分ける
- 作業中の子が 1 件でもいる `wait` の動き（約 46 分ごとの `timeout`）は変えない

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: `wait` の長い待ち（入り方・返り方・`expired` の行・判断し直し）、`told` サブコマンド、親が `told` を呼ぶ時点と `expired` を受けた動きを足す。声かけの期限の要件の 86400 秒を上限の値に直す。要件「声かけは wait を終了させず親の起床を増やさない」の上限の扱いを長い待ちに合わせて分ける
- `dev-workflow-epic-state`: 子の記録に任意の項目 `told_uuid`・`told_at` を足す。声かけの `skipped expired` の理由の説明を上限の値に直す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_wait`・`keepalive_candidate`・新しい `cmd_told`・冒頭の使い方とコメント）
- `plugins/dev-workflow/skills/develop/references/epic.md`（手順 5・7・8、待ちをやめてよい条件、声かけの段落）、`plugins/dev-workflow/skills/develop/references/reply-after-idle.md`（声かけの期限の文）
- `plugins/dev-workflow/tests/epic-dispatch.bats`、`plugins/dev-workflow/tests/develop-skill.bats`
- `plugins/dev-workflow/changes/1556.md`
- 範囲外: #1395（親が主と決めたことをエピック本文から引き取る）。ここでは本文が書き換わったときに判断し直す入口だけを作る。#1545 は PR が無いので今の main に合わせ、先に入ったほうに合わせて競合を直す
