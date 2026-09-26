## ADDED Requirements

### Requirement: 合格処理のあとに CI の見張りを始める
`skills/pr-review-gate/SKILL.md` は、手順 5（合格処理）の実測確認が済んだあとに、CI の見張りを始める手順を書かなければならない（MUST）。手順は次の 2 つに書き分ける（MUST）。

- ゲートをメインセッションで回している場合: `plugins/dev-workflow/references/ci-watch.md` の手順で、`scripts/ci-watch.sh wait` を Bash ツールの `run_in_background` で起動して見張りを始める
- ゲートをサブエージェント（develop の G など）が回している場合: 見張りを始めずに `passed` を return し、呼び出し側の本体に見張りを任せる（サブエージェントは背景タスクの完了で起こされないため）

見張りの中身（待ち方・`--unrelated` の基準・一手ごとの動き・直し方）は reference を参照し、SKILL.md に言い換えて再掲してはならない（MUST NOT）。直し方で PR に commit が積まれたときは、手順 1 からゲートを取り直すことを書く（MUST）。手順 6（保留処理）で合格しなかった PR には見張りを始めない（MUST NOT）。

#### Scenario: 合格処理のあとに run_in_background で見張りを始める
- **WHEN** `git grep -n 'run_in_background' -- plugins/dev-workflow/skills/pr-review-gate/SKILL.md` を実行する
- **THEN** 1 件以上当たり、当たった行は手順 5 の実測確認より後、手順 6 の見出しより前にある

#### Scenario: 直し方の reference を参照する
- **WHEN** `skills/pr-review-gate/SKILL.md` を読む
- **THEN** `references/ci-watch.md` への参照があり、サブエージェントの場合は見張りを始めずに `passed` を return することが書かれている
