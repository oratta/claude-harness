## Context

Version 1 role profiles already carry `executor`, `account`, `model`, and `effort`, but `load_profile` and `validate_execution_config` reject every executor except `codex`. The canonical path added by issue #340 resolves one role, writes a Codex request, and runs it in the foreground; it has no ledger, job id, or acknowledgement. The develop coordinator separately knows how to spawn Claude Agent roles, so a mixed profile needs one validated routing decision without creating a second workflow.

The change must preserve all canonical roles and phase mappings, the `review == impl-review` invariant, independent review boundaries, and the rule that Fable is available only to the `decider` role. Claude Agent cannot select another Claude account per call, so Claude entries can currently name only `current`. A profile model is the requested model; the existing budget modes still cap the model actually passed to Agent.

## Goals / Non-Goals

**Goals:**

- Make a version 1 profile the single table that selects executor/account/model/effort for every canonical role.
- Validate Claude and Codex entries according to their executor and return the selected role's full tuple.
- Route Claude roles to Agent and Codex roles to the existing foreground request/run path without changing phase order or quality gates, while preserving the existing budget caps and same-role resume behavior.
- Keep old all-Codex profiles valid and add measurable rejection cases for invalid mixed profiles.

**Non-Goals:**

- Running Claude under another `CLAUDE_SECURESTORAGE_CONFIG_DIR`; that requires a separate-process transport and belongs to a later issue.
- Translating Claude tier aliases into Codex model IDs, or Codex effort values into Claude controls.
- Removing or redesigning the legacy ledger commands.
- Changing role-to-phase mappings, review counts, specification criteria, or merge policy.

## Decisions

### Keep version 1 and make validation executor-discriminated

The four-field entry shape does not change, so the profile schema remains version 1. Each entry is validated as follows:

- `executor` must be exactly `codex` or `claude`.
- For `codex`, `account` must exist in the caller-supplied Codex account mapping/registry. Model and effort remain non-empty strings and are checked against the live Codex worker advertisement at execution time, as today.
- For `claude`, `account` must be exactly `current`; `model` must be one of `haiku`, `sonnet`, `opus`, or `fable`; and `fable` is valid only when the profile key is `decider`.
- `effort` remains a required non-empty string for both executors and is returned as part of the resolved tuple. Claude Agent has no effort parameter, so the coordinator does not forward it. Keeping the field avoids a version-2 shape and preserves the allocator's uniform output without inventing an unsupported mapping.

Alternatives considered: introduce schema version 2 with executor-specific objects, or drop `effort` from Claude entries. Both make one allocator output harder to consume and require migration despite no ambiguity in the existing discriminator.

### Keep the historical filename and add `hybrid-standard`

The built-in table stays at `references/codex-role-profiles.json`. Although the name is historical, it is already documented and may be passed or inspected by external tooling. Renaming it would break paths without improving the runtime contract; documentation will state that its entries are provider-neutral.

Add one `hybrid-standard` profile. Writing roles (`spec-write`, `implement`) and cheap helpers (`explore`, `summarize`) use the existing standard Codex settings. Independent review roles (`spec-review`, `impl-review`, `review`) use Claude `opus`, and `decider` uses Claude `fable`. All Claude entries use `account: current`; `review` and `impl-review` remain identical. Claude effort values mirror the role's existing high/low metadata but are not forwarded to Agent.

Alternatives considered: rename the file to `role-execution-profiles.json`, or add only an external test fixture. Keeping the path is compatible, and a built-in mixed profile makes the supported behavior usable and continuously tested.

### Resolve once at the foreground boundary, then branch once

`codex-develop.py request` remains the profile parser and role resolver. Its JSON result always includes `role`, `executor`, `account`, `model`, `effort`, and target `head`.

- If the selected executor is `codex`, behavior stays as today: require the selected account's CODEX_HOME mapping, write the private request file, and return `status: request-written`; the coordinator then runs `codex-worker.py run`.
- If the selected executor is `claude`, validate the whole profile, do not create a Codex request, and return `status: agent-required`. The returned model remains the requested model. Immediately before a new Agent spawn, the coordinator applies the existing budget-mode caps, passes the resulting applied model, and retains requested model, applied model, and adjustment reason as distinct audit values. With no applicable cap the applied model equals the requested model and the reason is unchanged; `FABLE_BUDGET_MODE=exhausted` changes a requested `fable` to applied `opus`; `SHARED_BUDGET_MODE=depleted` changes it to applied `sonnet` and wins over the Fable mode.

Thread lifetime follows the profile role rather than every transport call. A new profile role, an independent review, or any Codex delegation starts a fresh thread and receives only artifacts plus the required summary. When canonical develop resumes the same Claude profile role, the coordinator uses SendMessage on its named thread and retains the requested tuple and applied model fixed at that thread's first spawn. This preserves the existing review/fix resume loops without pretending a running Agent can change model.

The `references/codex-develop.md` adapter documents this as one branch immediately after role resolution, including budget application and the profile-role resume rule. `skills/develop/SKILL.md` points to that branch rather than duplicating the executor branch, while retaining the canonical resume points. This keeps executor choice in one place while leaving workflow transitions in the develop source of truth.

Alternatives considered: add a separate `resolve` subcommand, or make the coordinator parse JSON directly. A second subcommand would read an editable external profile twice before a Codex request, while direct parsing would duplicate validation in prose. Making `request` a route-preparation boundary resolves and acts from one read.

### Accept mixed snapshots but fail closed in the legacy ledger path

`validate_execution_config` and `resolve_execution` accept mixed version 1 snapshots so the shared profile contract is consistent. The canonical foreground route handles both executors. If a legacy `dispatch` resolves a Claude entry, it must stop with an explicit message directing the caller to the foreground provider route; it must never submit a Claude model/account tuple to `codex-worker.py`.

This does not add Claude support to the ledger. It only prevents the shared validator from contradicting the profile schema while keeping an obsolete transport safe.

## Risks / Trade-offs

- [The historical filename still says `codex`] → Document that the file is the provider-neutral built-in role table and keep all executor branching in its consumers.
- [Claude `effort` is recorded but not effective] → State this explicitly in the adapter and return the value for audit; do not claim it was applied.
- [A requested Claude model can exceed the current budget-mode cap] → Preserve the resolver output, apply the existing cap only at Agent start, and record requested model, applied model, and the reason separately.
- [A profile role can be resumed after a return] → Reuse the named Claude thread only for the same profile role; start a fresh thread at a role boundary or for Codex, carrying artifacts and a concise handoff instead of full conversation history.
- [A full mixed profile requires Codex account mappings even when the selected role is Claude] → Validate the whole profile up front so a later role cannot fail due to a latent bad account. Built-in `current` uses the same mapping already required by all-Codex profiles.
- [Legacy init can store a mixed snapshot it cannot fully dispatch] → Fail before any worker submission when the selected role is Claude and direct callers to the foreground route.
- [Documentation can drift into two executor branches] → Put the branch in `references/codex-develop.md` only and add a focused textual regression around the canonical wording/count.

## Migration Plan

Existing `codex-standard`, `codex-economy`, external version 1 all-Codex files, and legacy account/model calls remain valid. Implementation adds `hybrid-standard`, updates validators and the foreground return contract, updates documentation, and bumps dev-workflow from 2.13.13 to 2.13.14.

Rollback is a normal revert: existing all-Codex profiles retain their old values and no persistent data is migrated. A mixed legacy snapshot created during the new version will be rejected by the old version rather than silently rerouted.

## Open Questions

None. A non-`current` Claude account remains explicitly deferred to the separate-process Claude executor issue.
