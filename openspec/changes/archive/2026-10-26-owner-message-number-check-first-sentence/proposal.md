## Why

Stop の hook `owner-message-number-check.sh` は、1 行目が `？` か `?` で終わる発言だけを確かめる。1 行目の `？` のあとに同じ行で説明が続くマージの依頼（「PR #1330 を GitHub でマージしてもらえますか？ マージすると、子 #1303 の修正が main に入ります。…」）はすり抜け、区切りより上に番号が残ったまま主に届いた（issue #1370、親エピック #1216）。

## What Changes

- 確かめる対象の判定を広げる: 1 行目の最初の文が `？` か `?` で終わるものも対象にする。
- 差し戻しの文面、他の hook、答え方の語の一覧は変えない（親エピックからの指示）。

## Impact

- `plugins/dev-workflow/scripts/owner-message-number-check.sh`
- `plugins/dev-workflow/tests/owner-message-number-check.bats`
- capability `dev-workflow-owner-message-number-check` の要件「主に判断・確認・操作を求める発言だけを対象にする」
