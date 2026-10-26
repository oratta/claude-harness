## 1. 実装

- [ ] 1.1 `owner-message-number-check.sh` の質問判定を 1 行目の最初の文が `？` / `?` で終わるかに広げる（従来の末尾判定は残す。URL と引用の中身を除いてから最初の文を見る） 触る範囲: plugins/dev-workflow/scripts/owner-message-number-check.sh:77-81
- [ ] 1.2 先頭コメントの「判定の要点」の 1 行目の説明を直す 触る範囲: plugins/dev-workflow/scripts/owner-message-number-check.sh:14-16

## 2. テスト

- [ ] 2.1 bats に、すり抜けた発言（1 行目の `？` のあとに文が続き、区切りより上に `#1330` `#1303`）が block になるテストを足す 触る範囲: plugins/dev-workflow/tests/owner-message-number-check.bats
- [ ] 2.2 bats に、引用に `？` を含む答え・作業報告（`表示は「PR #1330 をマージしますか？」です。`、`#1330 に「マージしますか？」という確認を追加しました。`）と、`主がすること: なし` の報告が通り、報告のあとに質問が続く 1 行目が従来どおり block になるテストを足す（既存があれば確認） 触る範囲: plugins/dev-workflow/tests/owner-message-number-check.bats
