## Why

親の片付け（`epic-dispatch.sh reap`）が子のワークツリーを `kept <N> <理由>` で残したとき、今の手順は「オーナーの判断に残し、手で消し直さない」と定めている。2026-10-19、親はこれに従い、PR がマージ済みで未コミットも無いワークツリーを消すかを主に聞いた。主には判断材料が無く、「論点が無いのに聞くな。価値があるかは親が知っている」と言われた。

## What Changes

- 手順 3 の `kept <N> <理由>`（`not-done` と `llm-logs` を除く）を、親が主に聞かずに確かめて決める形に変える。確かめるのは、未コミットの変更が無いことと、HEAD が main かマージ済み PR の HEAD に入っていること（squash は tree の一致）
- 満たせば親が `orca worktree rm` で消し、エピックに `子 #N のワークツリーを確かめて消した（<理由>）` を残す。満たさなければ残し、`子 #N のワークツリーを残した（<理由>） — <満たさなかったこと>` を残す
- 「手で消し直してはならない（MUST NOT）」を外す。`epic-dispatch.sh` の処理（特に端末を閉じる処理）は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「Orca 経路の本体は印が付いた子のワークスペースを片付ける」の `kept` の扱いと、片付け待ちの子から外す対象

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（Orca 経路の手順 2・3）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（手順 3 の文言を確かめるテスト）
- 変更の記録 `plugins/dev-workflow/changes/1095.md`
