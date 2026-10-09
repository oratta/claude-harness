## Why

#397 で Codex モデルの系統名解決を導入したが、利用者向け手順書には旧形式だけが残り、review phase の記録手順には実際に解決したモデル ID の受け渡しがない。#405 の受け入れ条件に沿って説明とレビュー記録を揃え、archive 済み tasks の事実誤認も訂正する。

## What Changes

- `plugins/dev-workflow/docs/codex-develop.md` の旧形式の使用例と説明を、系統名または完全なモデル ID を指定できる形に更新する。
- adapter 経路の review phase で executor が Codex のとき、worker 結果の `execution.model_resolution.requested` と `resolved` を本体から G に渡し、G の `レビュー実行者:` コメントに `<requested>→<resolved>` を記録する手順を明記する。Claude 経路と既存のレビュー工程は維持する。
- archive 済み `codex-model-family-resolution/tasks.md` の 3.2 と 3.3 を、実在する docs と意図的に残した完全 ID の例に合う記述へ訂正する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: adapter 経路の Codex review で、実行結果の解決後モデル ID を G に渡し、レビュー実行者コメントに要求値と解決値を記録する。

## Impact

- `plugins/dev-workflow/docs/codex-develop.md`
- `plugins/dev-workflow/skills/develop/SKILL.md`
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`
- `openspec/changes/archive/2026-09-23-codex-model-family-resolution/tasks.md`
- 文言を検証するテスト。`tests/develop-adapter-review-routing.bats` の既存固定文字列は変えない。
