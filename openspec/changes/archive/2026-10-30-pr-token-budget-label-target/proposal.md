## Why
`dev-workflow-pr-token-budget` の上限超（exit 2）の文とシナリオが `needs-approval` を常に記録先に付けると読め、PR がある場合の `dev-workflow-develop` 「ラベルの付け先」（PR があれば PR）と食い違う（#609）。

## What Changes
- 上限超の文とシナリオの付け先を「PR があれば PR、無ければ記録先」に揃える（文言のみ）。
