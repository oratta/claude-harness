## Why

エピックの子が質問ツール（AskUserQuestion）の選択肢で待つと、キャッシュ維持の声かけと親の `epic-dispatch.sh reply` が届かない（選択肢の画面に文字を送ると選んでしまうため、送り側が送らない）。それなのに `references/epic-child-stop.md` は「質問ツールの中で待つ」止まり方を認めており、手順書どおりに動いた子が親から届かない状態になる（flatmate のエピック #1722 の子 #1818 で実際に起きた）。issue: #1555。

## What Changes

- `references/epic-child-stop.md` から、エピックの子（`route` が `nested`）が質問ツールの中で待つことを認める文をなくし、主の返事を待つときは本文で質問してターンを終める、と書く。選択肢を見せたいときは本文に番号つきで書く。
- develop の他の手順書にある「interactive は AskUserQuestion で聞く」は、エピックの子では同じ聞き方（本文で質問してターンを終える）に読む、という読み替えの規則を `epic-child-stop.md` に 1 か所だけ書く（channel の `references/channel.md` と同じ型。各文書には書き足さない）。
- エピックの子でないセッション（interactive の通常の本体・channel・unmanned）の質問ツールの扱いは変えない。
- 範囲外: キャッシュ維持の声かけ（#1554）、親の待ち方と 12 時間の上限（#1556）。

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `dev-workflow-develop`: 要件「エピックの子は PR のリスク許容の返事を待って止まるときだけ記録を残す」の、質問ツールの中で待つことを認める文言を、本文で質問してターンを終える規定に直し、読み替えの規則を足す。

## Impact

- `plugins/dev-workflow/skills/develop/references/epic-child-stop.md`
- `plugins/dev-workflow/tests/`（新規 bats 1 本）
- `plugins/dev-workflow/changes/1555.md`（変更の記録）
