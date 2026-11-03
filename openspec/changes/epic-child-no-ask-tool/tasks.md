## 1. 手順書

- [ ] 1.1 `epic-child-stop.md` の冒頭の導入と「記録を残す止まり」から、質問ツールの中で待つことを認める文言をなくし、エピックの子は本文で質問してターンを終える（選択肢は本文に番号つき）と、読み替えの規則を 1 か所に書く 触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:3、plugins/dev-workflow/skills/develop/references/epic-child-stop.md:5-11
- [ ] 1.2 `openspec/specs/dev-workflow-develop/spec.md` は archive 時に差分から反映される（直接編集しない）

## 2. テスト

- [ ] 2.1 新規 bats `tests/epic-child-no-ask-tool.bats`: epic-child-stop.md に「質問ツールの中で待つ」が無く本文で質問してターンを終える旨があること、develop の手順書のうちエピックの子に向けた箇所（epic-child-stop.md）に質問ツールで聞く指示が残っていないこと、既存の `develop-channel-mode.bats` が通ることを確かめる 触る範囲: plugins/dev-workflow/tests/epic-child-no-ask-tool.bats（新規）、plugins/dev-workflow/tests/develop-channel-mode.bats:106-120

## 3. 記録

- [ ] 3.1 変更の記録 触る範囲: plugins/dev-workflow/changes/1555.md（新規）
