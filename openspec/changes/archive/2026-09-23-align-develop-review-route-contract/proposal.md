## Why

develop 本体、Codex adapter、ゲート実行者 G の間で、adapter 経路と従来経路の説明が複数の正本に分散し、一部の入力・model 選択・未実行証拠・重複防止の表現が食い違っている。現行の develop 本体は常に経路を明示するため未発症だが、G や本体が一方の記述だけを読んだときに adapter の選択を無視する余地をなくす。

## What Changes

- G の入力契約に `レビュー経路:` と、adapter 経路の再開時に必要な executor / model・dispatch 記録 URL を明記する。
- レビュアーの model は、従来経路では G の推奨値、adapter 経路では adapter の選択へ残量上限を適用した値を使うと書き分ける。
- adapter 経路では Codex 実行証拠の 5 欄を `未実行（adapter 経路）` とすることを、gate-runner の payload と pr-review-gate のコメント雛形で同じ形にする。
- `レビュー経路:` が無い fresh G の従来経路について、Claude の G と Codex の G の実行可能な動きを書き分ける。
- develop の欠陥探索の説明を、adapter 経路のレビュアーと従来経路の Codex の両方を含む表現に統一する。
- adapter 経路の G は `needs-reviewer` を返す前に、同一 PR/HEAD で別の G が着手済みでないことを確認する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: G のレビュー経路入力、executor ごとの従来経路、レビュアー model、adapter 未実行証拠、同一 PR/HEAD の重複防止に関する既存要件を明確化する。

## Impact

- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`
- `plugins/dev-workflow/skills/develop/SKILL.md`
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`
- `plugins/dev-workflow/references/codex-develop.md`
- `plugins/dev-workflow/tests/develop-adapter-review-routing.bats`
- `openspec/specs/dev-workflow-develop/spec.md`（archive 時に delta spec を同期）
- dev-workflow プラグインの version、marketplace metadata、CHANGELOG
