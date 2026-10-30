## 1. triage.md・spec・bats

- [ ] 1.1 `stages/triage.md` の「主が切り出すと答えた止める指摘の置き場所」の「必ず follow-up issue にする」を「必ず issue で追跡する（新しい issue を作るか、段 C の表のとおり既存 issue の受け入れ条件に足す）」に直す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:119-119
- [ ] 1.2 `bats` の検査行を新しい文言に直す。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:778-778
- [ ] 1.3 main の spec は change の archive で更新される（delta は specs/ に作成済み）

## 2. gate-runner.md

- [ ] 2.1 「時点ごとに読むファイル」の表の保留の解除の行に、切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage.md` の置き場所の段落・候補探し・段 C の節を読む、と書く。触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:22-24
- [ ] 2.2 `develop-roles.bats` に保留の解除の行の検査を足す（既存の gate-runner の表の検査の近く）。触る範囲: plugins/dev-workflow/tests/develop-roles.bats:850-885
