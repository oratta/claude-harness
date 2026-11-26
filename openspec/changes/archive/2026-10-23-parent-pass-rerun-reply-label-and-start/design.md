## Context

`ci-watch.md` は、手順 7 の経路で止まるとき PR に `needs-approval` を付ける（66 行目）。`ready` 後の扱いは、`needs-approval` などが付いていると `--until-merged` で待たずにマージを頼んで終わる（78 行目）。親の返事のあとの見張りの始め直しは、2 の重複確認と `CI 見張り開始:` の投稿を必須にしている（86 行目）。

## Decisions

- 返事の段落に直接書く。`ci-watch.md` 側は変えない（食い違いを作らず、親の基準の側で子への指示を完結させる）。
- `needs-approval` を外すのは、手順 7 の経路で止まった子に限る。`job-timeout` の `escalate` は主に上げるので返事の対象外であり、この段落に来ない。外す操作は `gh pr edit --remove-label`。
- 重複の確認と開始コメントの書き方は `ci-watch.md` 2 を参照させ、手順は複製しない（正本を 1 つに保つ）。
