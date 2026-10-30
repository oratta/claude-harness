## Why

`rules/git-commit-policy.md` には、既存 issue の受け入れ条件を足す前に作業中かを確かめる決まり（#1390）がある。ところがその仕様 `in-progress-issue-scope` は、G（ゲート役）がレビュー指摘の振り分けで受け入れ条件に足す場合を対象外にしている。このため、段 C の表の子の行（同じエピックの子 issue の受け入れ条件に足す）は作業中かを確かめずに足せる。子に open の PR が付き、同じ HEAD でレビューを通っていると、足した条件を見ないままマージされ、子が閉じて追跡が切れうる（PR #1512 のレビュー指摘）。

## What Changes

- `in-progress-issue-scope` の「既存 issue の受け入れ条件を足す前に作業中かを確かめる」から、G の振り分けを対象外にする段落とシナリオを外し、G も同じ決まりに従うシナリオに置き換える
- `dev-workflow-pr-review-gate` に、段 C の表の子の行で足す前に作業中かを確かめ、作業中なら足さず新しい子 issue に切り出す要件を足す。主が切り出すと答えた止める指摘も、段 C の表を通るので同じ確認を通る
- `stages/triage.md` の段 C に、同じ内容の手順を足す（表の直後の段落。作業中かを判定するスクリプトは作らない。gh を 2 回打つ）

## Capabilities

### Modified Capabilities
- `in-progress-issue-scope`: G の振り分けの対象外を外す
- `dev-workflow-pr-review-gate`: 段 C の子の行に作業中の確認を足す（新しい要件を 1 つ追加）

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`（段 C）
- `openspec/specs/in-progress-issue-scope/spec.md`、`openspec/specs/dev-workflow-pr-review-gate/spec.md`
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`（検査の追加）
- 変更の記録 `plugins/dev-workflow/changes/1498.md`
