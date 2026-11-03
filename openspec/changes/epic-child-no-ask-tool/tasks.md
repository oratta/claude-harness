## 1. 手順書

- [ ] 1.1 `epic-child-stop.md` の冒頭の導入と「記録を残す止まり」から、質問ツールの中で待つことを認める文言をなくし、エピックの子は本文で質問してターンを終える（選択肢は本文に番号つき）と、読み替えの規則を 1 か所に書く 触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:3、plugins/dev-workflow/skills/develop/references/epic-child-stop.md:5-11
- [ ] 1.2 `openspec/specs/dev-workflow-develop/spec.md` は archive 時に差分から反映される（直接編集しない）

## 2. テスト

- [ ] 2.1 新規 bats `tests/epic-child-no-ask-tool.bats` の (a): `epic-child-stop.md` に「質問ツールの中で待つ」を認める文が無いこと、本文で質問してターンを終える旨と、読み替えの規則（対象は `route` が `nested` のエピックの子、「interactive は AskUserQuestion で聞く」をこの聞き方に読む）があることを文言で確かめる 触る範囲: plugins/dev-workflow/tests/epic-child-no-ask-tool.bats（新規）
- [ ] 2.2 同 bats の (b): 検査範囲は develop の手順書の全部（`skills/develop/SKILL.md`・`skills/develop/references/*.md`・`skills/develop/references/roles/**/*.md`）。`AskUserQuestion` を含む各行は、`interactive は`・`**interactive**`・`**interactive モード**`・`interactive モードでは`（既存の手順書の表記。decision-criteria.md:96 と roles/spec-reviewer.md:113。手順書は変えない）の条件つき、`AskUserQuestion は使わない／を呼ばない／を呼ばず／を使わず` の否定、のどれかであることを grep で確かめる（通常の interactive 向けの指示は許容し、条件なしでエピックの子に質問ツールを使わせる指示を検出する）。`epic-child-stop.md` の行は否定の形に限る。既存の `develop-channel-mode.bats:106` は SKILL.md しか読まないので補わず、この (b) が範囲を担う 触る範囲: plugins/dev-workflow/tests/epic-child-no-ask-tool.bats（新規）、plugins/dev-workflow/tests/develop-channel-mode.bats:106-120（通ることの確認のみ）
- [ ] 2.3 エピックの子でないセッションの質問ツールの扱いが変わっていないことは、既存の bats（`develop-channel-mode.bats`・`develop-skill.bats` など）が通ることで確かめる

## 3. 記録

- [ ] 3.1 変更の記録 触る範囲: plugins/dev-workflow/changes/1555.md（新規）
