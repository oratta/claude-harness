# Tasks

- [ ] 1. `gate-runner.md` の「条件の答えを受け取ったとき」の段落の前に、design.md の「同じ文」を 1 段落で足す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:114
- [ ] 2. `stages/triage.md` の「条件を主に聞くとき」の段落の「return の仕分け欄にも質問文を写す。」のあとに、同じ文を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:92
- [ ] 3. 回帰テスト: 3 か所（gate-runner.md・triage.md・main の spec）に同じ文が `grep -F` で見つかることを bats で固定する。触る範囲: tests/dev-workflow-condition-question-delivery.bats（新規。既存の pr-review-gate 系 bats の命名と書き方に揃える）
- [ ] 4. 変更記録 `plugins/dev-workflow/changes/1013.md` を書く（バージョンは上げない）。触る範囲: plugins/dev-workflow/changes/1013.md（新規）
- [ ] 5. `openspec validate condition-question-delivery --type change --strict` と `./scripts/test.sh` を通す。
