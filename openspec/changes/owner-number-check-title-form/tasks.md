# Tasks

## 1. テスト

- [x] 1.1 spec の Scenario 3 つ（題名とアクションの行の依頼で対象に入る・太字の項目名のアクションの行でも対象に入る・2 行目の途中のアクションの語では対象にしない）を `target:` の節にテストとして足し、スクリプトを直す前に前の 2 つが落ちることを確かめる。加えて、2 行目が区切りの行で 3 行目が `アクション:` の発言と、`主がすること: なし` の 1 行目のあとに `アクション:` の行が来る発言が対象にならないことのテストを足す。触る範囲: plugins/dev-workflow/tests/owner-message-number-check.bats:324-349（「対象の見分け方」の節の `target:` のテスト）

## 2. スクリプト

- [x] 2.1 判定に、並びの 2 番目の行（前後の空白と `*` を除く）が `アクション` で始まり `:` か `：` が続く条件を足し、`is_question`・`has_answer_line` と並べて「どれかに当たれば対象」にする。旧い 2 つの条件と `ANSWER_WORDS` は変えない。触る範囲: plugins/dev-workflow/scripts/owner-message-number-check.sh:59-67（定数の並び）、plugins/dev-workflow/scripts/owner-message-number-check.sh:133-141（`is_question`・`has_answer_line` と対象の判定）
- [x] 2.2 冒頭の「判定の要点」の説明に、2 行目のアクションの行で対象に入ることを書き足す（正本の新しい書き分けの手がかりであることを添える）。触る範囲: plugins/dev-workflow/scripts/owner-message-number-check.sh:11-20

## 3. 確認と記録

- [x] 3.1 `bats plugins/dev-workflow/tests/owner-message-number-check.bats plugins/dev-workflow/tests/hook-python-invocation.bats tests/hook-python-isolation.bats` を通す。触る範囲: なし（確認のみ）
- [ ] 3.2 変更の記録 `plugins/dev-workflow/changes/1671.md` にこの change の分を足す。触る範囲: plugins/dev-workflow/changes/1671.md
