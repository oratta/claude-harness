## Why

Role profiles already describe an `executor`, but every entry is currently forced to `codex`, so the coordinator still chooses Claude versus Codex outside the role table. Allowing a validated mixed profile makes executor/account/model/effort resolution the single source of truth while preserving the existing develop phases, independent reviews, and gates.

## What Changes

- Accept `claude` as well as `codex` in version 1 role-profile entries and reject every other executor.
- Validate executor-specific values: Claude entries use `account: current`, a Claude tier alias as `model`, and permit `fable` only for the `decider` role; Codex entries retain registered-account validation and worker-side model/effort validation.
- Add one built-in mixed profile and return the selected role's executor/account/model/effort so the coordinator can route Claude roles through Agent and Codex roles through the foreground request/run path.
- Keep the historical `codex-role-profiles.json` filename to avoid breaking documented paths; its contents and documentation become provider-neutral.
- Keep specification, implementation, review, and gate ordering unchanged. The profile selects transport and execution settings only.
- Bump the dev-workflow plugin version to 2.13.14 during implementation.

## Capabilities

### New Capabilities

<!-- None. This extends the existing role-profile and develop-provider contracts. -->

### Modified Capabilities

- `codex-role-profiles`: Version 1 profiles may mix validated Claude and Codex entries, and expose the selected role's full execution tuple.
- `manual-codex-develop`: The foreground adapter resolves each role first and routes Claude entries to Agent or Codex entries to the request/run commands without introducing a second workflow.
- `dev-workflow-develop`: The coordinator selects the per-role provider from the profile while preserving the canonical role, review, and transition rules.

## Impact

- `plugins/dev-workflow/scripts/codex-develop.py`: executor-aware profile/config validation and foreground route resolution.
- `plugins/dev-workflow/references/codex-role-profiles.json`: one mixed built-in profile; filename retained.
- `plugins/dev-workflow/references/codex-develop.md`, `plugins/dev-workflow/references/model-tiers.md`, and `plugins/dev-workflow/skills/develop/SKILL.md`: one documented executor branch and executor-specific model rules.
- `plugins/dev-workflow/tests/test_codex_develop.py`: mixed resolution, Claude validation, unsupported executor, and fail-closed legacy-dispatch coverage.
- `plugins/dev-workflow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`: dev-workflow 2.13.14 version sync during implementation.
