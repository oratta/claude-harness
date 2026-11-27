# fable-judgment-only-spec-review — R1 の fable 条件を事前分類の fable 行に限定する

## Why

change fable-judgment-only（2026-09-06）で W / R1 / G の fable 条件を「マージ権限・層間契約・課金/法務」に絞り聖域パスを opus にしたが、`dev-workflow-spec-review` の Requirement「仕様レビュアーのモデルは役割で選ぶ」は「事前分類表に当たる場合は fable」のままで、`dev-workflow-develop` の「聖域パスだけでは R1 を上げない」と矛盾していた（PR #235 の Codex レビュー指摘）。

## What Changes

- R1 の fable 条件を事前分類表の `fable` 行に限定し、聖域パスだけでは上げないと明記する

## Capabilities

### Modified Capabilities

- `dev-workflow-spec-review`: Requirement「仕様レビュアーのモデルは役割で選ぶ」

## Impact

- spec のみ（実装 `references/roles/spec-reviewer.md` は fable-judgment-only で更新済み）
