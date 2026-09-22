## Why

The first review pass currently asks for all findings but does not require the reviewer to enumerate the PR's new decisions or reconcile them with unchanged repository text before reporting findings. As a result, duplicated rules and missing cases can survive the first pass and only surface in later review rounds.

## What Changes

- Require the first-pass reviewer to produce, in order, a change inventory, a repository-wide reconciliation table, and per-hunk coverage before writing findings.
- Require the reconciliation table to use the revision-safe search-command and hit-table conventions established by the pr-review-gate triage inventory, and permit inconsistency findings to identify both the changed and unchanged locations.
- Add a deterministic checker that compares the reviewer's reported hit set with the repository search result, and let G request one supplemental pass for only the missing entries.
- Record later-round findings under four outcome categories so the effect of the first-pass inventory can be measured.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `dev-workflow-pr-review-gate`: Extend the reviewer output contract and G's verification contract with first-pass decision inventory, repository-wide reconciliation, hunk coverage, bounded supplementation, and later-round outcome classification.

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`
- Codex reviewer instruction templates under `plugins/dev-workflow/references/` and `plugins/dev-workflow/scripts/`
- A new reconciliation checker under `plugins/dev-workflow/scripts/`
- pr-review-gate/develop-role tests, plugin version metadata, and changelog
- `openspec/specs/dev-workflow-pr-review-gate/spec.md` after archive
