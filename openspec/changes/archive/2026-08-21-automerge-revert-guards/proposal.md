## Why

auto-merge テンプレートの revert-pr.yml（緊急巻き戻し経路）に検証の穴が2つある（issue #121）。
(1) PR の `merged` と `merge_commit_sha` だけを見て `.base.ref` を見ないため、既定ブランチ以外へ
マージされた PR を指定すると「既定ブランチに元々無かった変更の逆パッチ」PR が生成される
（出典: oratta/marketing-harness#36 の Codex レビュー）。(2) ブランチ名が RUN_ID 固定で、
push 後や PR 作成後の部分失敗を re-run すると non-fast-forward / PR 重複で落ち、再開できない
（出典: oratta/claude-harness#118 の Codex レビュー）。緊急経路が緊急時に使えないのは実害になる。

## What Changes

- **base 検証**: META に `.base.ref` を含め、`$BASE_BRANCH` 以外へマージされた PR を拒否する
- **ancestor 検証**: 副作用（ブランチ作成・push）より前に `git merge-base --is-ancestor` で
  マージコミットが `origin/$BASE_BRANCH` の履歴に実在することを要求する
- **部分失敗からの再開**: re-run（RUN_ID 同一・attempt 増加）では既存ブランチを `ls-remote`、
  既存 PR を `gh pr list --head` で発見し、残工程（PR 作成・ラベル・コメント）だけ続行する
- 不変条件テスト（test-auto-merge-workflow.sh / automerge-templates.bats）に退行テストを追加

## Capabilities

### Modified Capabilities

- `dev-workflow-automerge-templates`: Requirement「テンプレートは flatmate で実証済みの安全不変条件を維持する」に revert-pr.yml の base/ancestor 検証と再開の SHALL を追加

## Impact

- `plugins/dev-workflow/templates/auto-merge/.github/workflows/revert-pr.yml` と repo 自身の配備コピー `.github/workflows/revert-pr.yml`
- `plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh` と repo 自身の `scripts/test-auto-merge-workflow.sh`
- `plugins/dev-workflow/tests/automerge-templates.bats`
- `docs/auto-merge.md`（テンプレート・repo 両方）— 拒否条件と re-run 再開の運用を追記
- 既存配備先への伝播が必要（正本: `plugins/dev-workflow/docs/auto-merge-deployments.md`）
