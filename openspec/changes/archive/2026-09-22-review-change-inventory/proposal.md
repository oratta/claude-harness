## Why

The first review pass currently asks for all findings but does not require the reviewer to enumerate the PR's new decisions or reconcile them with unchanged repository text before reporting findings. As a result, duplicated rules and missing cases can survive the first pass and only surface in later review rounds.

## What Changes

- Require the first-pass reviewer to produce, in order, a change inventory, a repository-wide reconciliation table, and per-hunk coverage before writing findings.
- Define one revision-safe, repository-wide search-command and hit-table contract shared by the first-pass reconciliation table and the grep-term path of pr-review-gate triage step 3, while keeping the case-axis path on its existing full-domain comparison and keeping the grep path's post-fix second stage separate.
- Add a deterministic checker that compares either shared table's reported hit set with the repository search result, and let G request one supplemental pass for only the missing entries. A residual after that pass ends as `review-incomplete` without starting another reviewer.
- Record later-round findings under four outcome categories so the effect of the first-pass inventory can be measured.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dev-workflow-pr-review-gate`: Extend the reviewer output contract and G's verification contract with first-pass decision inventory, repository-wide reconciliation, hunk coverage, bounded supplementation, and later-round outcome classification.
- `dev-workflow-develop`: Add the terminal `review-incomplete` G return to the loop routing contract so the coordinator stops without launching another reviewer.

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`
- `plugins/dev-workflow/skills/develop/SKILL.md`
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`
- Codex reviewer instruction templates under `plugins/dev-workflow/references/` and `plugins/dev-workflow/scripts/`
- A new reconciliation checker under `plugins/dev-workflow/scripts/`
- pr-review-gate/develop-role tests, plugin version metadata, and changelog
- `openspec/specs/dev-workflow-pr-review-gate/spec.md` after archive
- `openspec/specs/dev-workflow-develop/spec.md` after archive
