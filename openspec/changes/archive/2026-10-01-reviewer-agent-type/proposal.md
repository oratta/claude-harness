## Why

pr-review-gate で Claude のレビュアーを `general-purpose` + `model: opus` で起こしているため、レビュアーは作業を始める前に全部の道具の定義を読み込み、起動直後のコンテキストが中央値 57,964 トークンある（W・G は道具を絞った種別に移して約 3 万。エピック #511 の flatmate 計測）。上限 150K を超えるレビュアーは 15 体中 3 体（20%）で、#1116 のレビュアーは 167.7K で強制停止された。W と G を移した #330 の範囲にレビュアーは入っていなかったので、同じ形でレビュアーの種別を足す。

## What Changes

- エージェント定義 `plugins/dev-workflow/agents/reviewer.md`（種別 `dev-workflow:reviewer`）を足す。frontmatter の `tools:` を `Read, Bash, Grep, Glob, TaskStop` に絞り、Edit / Write / NotebookEdit を持たせない。`model: opus`
- 本体（develop の (4) の needs-reviewer ③、および pr-review-gate を develop 以外で回すときのフォールバック）がレビュアーを起こすときの既定の `subagent_type` を `general-purpose` から `dev-workflow:reviewer` に替える（`skills/pr-review-gate/stages/prepare.md`・`stages/review-run.md`・`skills/develop/SKILL.md`・`references/codex-develop.md`）
- 事前分類（マージ条件・層間契約・課金/法務）に当たるときに `dev-workflow:decider` で起こす扱いは変えない
- `scripts/agent-model-guard.sh` は新種別を Fable の許可リストに入れない（`model: fable` は拒否のまま）
- `scripts/subagent-context-audit.sh --by-role` は `agentType` が `dev-workflow:reviewer` の個体を description に頼らず `Reviewer` に数える
- `plugin.json` の `agents` 配列に新種別を足し、plugin.json と marketplace.json の description を揃える
- 仕様レビュー R1 と画面確認役 V の種別は変えない（`general-purpose`）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-role-agent-types`: レビュアーの種別 `dev-workflow:reviewer` の要件と、issue #650 の PR 本文に効果を記録する要件を別の要件として足し、プラグインの宣言と Fable 拒否の要件を新種別込みに改める（#330 の PR を対象にした「新種別の効果を分けて記録する」は変えない）
- `dev-workflow-develop`: 「W と G は役割ごとの種別で起こす」の「G が要求するレビュアーの種別は変えない（`general-purpose`）」を、`dev-workflow:reviewer` で起こす規定に改める
- `dev-workflow-execution-strategy`: 「担当分類の優先順位」に、`agentType` が `dev-workflow:reviewer` の個体を description に頼らず `Reviewer` に数える規則を足す
- `manual-codex-develop`: 「委譲は前景実行の 3 手順で行う」の Claude role の種別の対応で、G が必要とする独立 PR レビューを `general-purpose` から `dev-workflow:reviewer` に改める

## Impact

- 追加: `plugins/dev-workflow/agents/reviewer.md`
- 変更: `plugins/dev-workflow/.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json`、`plugins/dev-workflow/skills/pr-review-gate/stages/prepare.md`・`stages/review-run.md`、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/references/codex-develop.md`、`plugins/dev-workflow/README.md`、`plugins/dev-workflow/scripts/agent-model-guard.sh`（コメント）、`plugins/dev-workflow/scripts/subagent-context-audit.sh`、`plugins/dev-workflow/docs/usage-audit.md`
- テスト: `plugins/dev-workflow/tests/role-agent-types.bats`・`agent-model-guard.bats`・`subagent-context-audit.bats`・`develop-roles.bats`、必要なら `tests/injection-budget.txt`
- 変更記録: `plugins/dev-workflow/changes/650.md`
- マージ前は配布版のキャッシュに新種別が無いので、新種別を起こす実機確認と、この PR 自身のゲートのレビュアーは `claude -p --plugin-dir` のセッションの中で起こす（手順は design.md）
