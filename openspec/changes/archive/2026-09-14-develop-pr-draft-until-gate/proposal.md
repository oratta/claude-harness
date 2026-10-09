## Why

develop の W は工程 (3b) で PR を Ready にしてからゲート（G）に渡すため、レビューと修正の周回中も CI が push ごとに走る。genetta-inc/flatmate は PR #645 で「Draft の PR では CI を回さず、Draft を外したときに 1 回回す」設定にしたが、この流れのままでは効かない。2026-09 の flatmate では PR の CI が 199 回・67 ブランチ（1 PR あたり平均 3 回、最大 15 回）走り、14 日で org の Actions 無料枠 2,000 分を使い切って CI と auto-merge が全停止した（genetta-inc/flatmate#643）。ゲート合格まで Draft のまま進めれば、CI は 1 PR につき最後の 1 回にできる。

## What Changes

- W の工程 (3b) で PR を Ready にしない。記録先が Draft PR ならそのまま、issue が記録先なら `gh pr create --draft` で作り、Draft のまま仕様宣言まで行って G に渡す
- pr-review-gate の手順 5（合格処理）で、PR が Draft なら `gh pr ready` を実行してから `agent-review:passed` を付ける。合格処理の実測確認に「PR が Draft でない」を加える
- pr-review-gate の手順 1 で stale な `agent-review:passed` を外したとき、PR が Draft でなければ `gh pr ready --undo` で Draft に戻す（合格後に commit を積んでゲートを取り直す場合）
- 人間が作った非 Draft の PR は、初回のゲートでは Draft に戻さない（Ready 化・Draft 戻しはどちらも条件付き）
- G の指示書（gate-runner.md）の手順要約と passed の return に Ready 化を含める

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: 1 ループの (3b) の「PR を Ready に切り替えるか作成する」を「PR を Draft のまま用意する（無ければ Draft で作成する）」に変える
- `dev-workflow-pr-review-gate`: 合格処理に Draft なら Ready 化する手順を足し、ゲートの取り直しで stale passed を外すときに Draft へ戻す手順を足す

## Impact

- 編集: `plugins/dev-workflow/skills/develop/references/roles/worker.md`、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/skills/pr-review-gate/SKILL.md`、`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`
- テスト: `plugins/dev-workflow/tests/develop-skill.bats`（(3b) の `Ready` を検査している 2 本を反転）、`plugins/dev-workflow/tests/develop-roles.bats`、`plugins/dev-workflow/tests/pr-review-gate-skill.bats`
- バージョン: `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow エントリ、`plugins/dev-workflow/CHANGELOG.md`
- 変えないもの: auto-merge のテンプレートと `docs/auto-merge.md`（draft スキップと workflow_run のバックストップが既にある）、unmanned の実行モード表（W は既に Draft PR を作る）、cost-ledger の区間境界（`gh pr ready` は既に境界の 1 つ）、リポ直下の `CLAUDE.md` / `AGENTS.md` の PR 運用ルール
- 他リポ: flatmate の無人ループの憲法（`docs/agent-loop.md`）が自分で Ready にしている場合は flatmate 側の別 issue で揃える
