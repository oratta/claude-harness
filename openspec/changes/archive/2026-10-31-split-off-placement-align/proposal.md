## Why

PR #1002 は、主が「切り出す」と答えた止める指摘を必ず追跡し、置き場所だけを段 C の表で決めると定めた。しかし `stages/triage.md` と main の spec は「必ず follow-up issue にする」と書き、同じ場所を直す子 issue が既にあるときは、新しい子 issue を作る読みと「段 C の表のとおり既存の子の受け入れ条件に足す」読みで割れる。また保留の解除の G は、切り出しの確認に「切り出す」と答えられると `stages/triage.md` の置き場所の段落と段 C で置き場所を決めるが、`gate-runner.md` の表は読むファイルを `stages/hold.md` だけとし、表にないファイルは読まないと定めるため、G が必要な規則を知らないまま issue を作るか、表の規則を破って読む。（記録先: oratta/claude-harness#1016、親エピック #1474）

## What Changes

- `stages/triage.md`・main の spec・bats の検査行を「必ず issue で追跡する（新しい issue を作るか、段 C の表のとおり既存 issue の受け入れ条件に足す）」に揃える
- 同じ段落に、「follow-up issue に切る」は新しい issue を作る場合と段 C の表のとおり既存 issue で受ける場合の両方を指す、と定義する 1 文を足す（既存 issue で受けたときも PR コメントには「follow-up issue に切った」と書いて URL を添える）
- `gate-runner.md` の「時点ごとに読むファイル」の表の保留の解除の行に、切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage.md` の置き場所の段落・候補探し・段 C の節を読む、と書く（前提確認の行の書き方に合わせる）。同じ表に揃える義務のある dev-workflow-develop の段の表の行も同じにする

## Capabilities

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 「主が切り出すと答えた止める指摘は捨てずに置き場所だけ決める」の追跡の書き方と、既存の子がある場合のシナリオ
- `dev-workflow-develop`: 「G は段ごとに新しく起こし、SendMessage で再開しない」の段の表の保留の解除の行

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`、`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`、`plugins/dev-workflow/tests/pr-review-gate-skill.bats`、`plugins/dev-workflow/tests/develop-roles.bats`（表の検査を足す）、変更の記録 `plugins/dev-workflow/changes/1016.md`
