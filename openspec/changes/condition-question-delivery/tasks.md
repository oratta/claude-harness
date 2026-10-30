# Tasks

- [ ] 1. `gate-runner.md` の「条件の答えを受け取ったとき」の段落の前に、design.md の「同じ文」を 1 段落で足す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:114
- [ ] 2. `stages/triage.md` の「条件を主に聞くとき」の段落の「return の仕分け欄にも質問文を写す。」のあとに、同じ文を足す。続けて別の文「自分でゲートを回すセッションは、G を起こした側を兼ねる。」を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:92
- [ ] 3. `SKILL.md` (4) の `次の段へ` の行に、`条件の確認待ち` の質問文を主へ届けることと `gate-runner.md` への参照を短い 1 文で足す（全文は写さない）。`tests/develop-startup-budget.bats` の予算（`tests/develop-startup-budget.txt`、残り 164 バイト）に収め、予算ファイルの値は動かさない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:150
- [ ] 4. 回帰テスト: plugins/dev-workflow/tests/pr-review-gate-skill.bats に追加する。gate-runner.md・triage.md に同じ文が `grep -F` で見つかること、SKILL.md に参照があることを固定する。spec は archive 前は change の delta spec、archive 後は main spec を読む（前例: 同ファイル 831-833 行）。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats（末尾に追加）
- [ ] 5. 変更記録 `plugins/dev-workflow/changes/1013.md` を書く（バージョンは上げない）。触る範囲: plugins/dev-workflow/changes/1013.md（新規）
- [ ] 6. `openspec validate condition-question-delivery --type change --strict` と `./scripts/test.sh` を通す。main spec の反映は (3b) の archive で行うので、(3a) の検証に main spec の確認を入れない。
