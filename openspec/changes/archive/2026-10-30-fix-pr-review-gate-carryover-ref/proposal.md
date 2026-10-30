## Why

`dev-workflow-pr-review-gate` の要件「前の HEAD の許容を新しい HEAD に引き継いでよい条件」は、3-c に書く例外の文の対象として「`gate-runner.md` の再レビューの同趣旨の文」を挙げている。しかし `gate-runner.md` に該当する文は無く、「W の修正後の再レビュー」の項目は `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md` にある（#1423。PR #1420 のレビュー指摘 F2）。

## What Changes

- 要件の末尾の参照先を「`stages/triage.md` の「W の修正後の再レビュー」の同趣旨の文」に直す。要件のほかの文は変えない
- 手順書（`stages/hold.md` ほか）は変えない。`hold.md` の同じ文は PR #1420（#572）が直す

## Capabilities

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 要件「前の HEAD の許容を新しい HEAD に引き継いでよい条件」の参照先を直す

## Impact

`openspec/specs/dev-workflow-pr-review-gate/spec.md` の 1 要件の 1 文だけ。
