## Why

`レビュー経路: adapter` で起動された G が、後続の再開指示に同じ行が無いだけで従来経路へ切り替わるようにも読める。これにより、同じ G のレビュー周回中に adapter の委譲境界を外れて Codex を直接呼ぶおそれがあるため、初回に選ばれた経路の保持範囲を明確にする。

## What Changes

- `レビュー経路: adapter` で起動された同一の G は、後続の再開指示に `レビュー経路:` 行が無くても adapter 経路を保持する。
- `レビュー経路:` 行が無い場合に従来経路を選ぶ既定は、新しく G を起動する指示（手渡しで起こす後任 G を含む）に限る。
- develop 本体、Codex adapter reference、gate-runner の記述とテストを、この初回起動と再開の区別に揃える。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: G のレビュー経路判別要件を、同一 G の再開では初回の adapter 経路を保持し、行の無い新規起動だけを従来経路にする契約へ変更する。

## Impact

- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`
- `plugins/dev-workflow/skills/develop/SKILL.md`
- `plugins/dev-workflow/references/codex-develop.md`
- `plugins/dev-workflow/tests/develop-adapter-review-routing.bats`
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow version
- `openspec/specs/dev-workflow-develop/spec.md`（archive 時に delta を反映）

外部 API や依存パッケージの変更はない。
