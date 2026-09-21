## Context

#340 made `codex-worker.py run` and `codex-develop.py request` the canonical Codex transport. The foreground worker receives an already-resolved CODEX_HOME, performs one turn, emits one JSON result, and dies with its caller. #342 then routed each develop role through that boundary and proved the full workflow without a ledger or acknowledgement.

The repository still carries the earlier transport in parallel:

- `codex-worker.py` persists jobs and accounts in `ledger.sqlite`, cross-ledger ownership in `ownership.sqlite`, starts detached workers, and exposes lifecycle commands.
- `codex-develop.py` persists `run.json`, pending requests, execution snapshots, retry state, and v1/v2 continuation records.
- three documents and tests describe both transports.
- `codex-worker-concurrency` and `codex-develop-continuation` specify behavior that only the old transport can provide.

That duplication is now misleading: the supported workflow stores durable progress only in the issue or Draft PR and in the linked worktree. The change is intentionally breaking and ships as dev-workflow 2.13.15. It must not touch sacred paths or the injection-budget value.

## Goals / Non-Goals

**Goals:**

- Make foreground `request` → `run` the only Codex transport.
- Remove all SQLite, detached-worker, run-dir, pending, retry, acknowledgement, continuation, slot, lock, and reap behavior.
- Preserve every behavior the foreground route still needs: account-home resolution, auth pinning, model/effort validation, role policy, read-only reviewers, quota preflight, caller-linked cancellation, and result evidence.
- Keep Claude role routing from #342 unchanged: `request` returns `status: agent-required` and does not create a Codex request.
- Reduce docs and main specs without dropping unrelated operating or quality rules.
- Leave existing state on disk and document a deliberate, manual cleanup path.

**Non-Goals:**

- Adding live resume, steering, durable recovery, a queue, concurrency slots, cwd locks, or a new persistent account registry.
- Changing profile schema, role-to-provider routing, model budget caps, sandbox policy, GitHub responsibility boundaries, or quality review gates.
- Deleting `~/.local/state/claude-harness-codex/` automatically or deciding cleanup for the separate temporary-area issue #333/#338.
- Implementing or validating the change in this specification phase.

## Decisions

### Remove the old transport in one cut, without a compatibility shim

The implementation removes the old commands and their storage together. Keeping read-only `status`/`result`, accepting old run directories, or translating old commands into foreground calls would preserve a second state contract and create ambiguous semantics for acknowledgement, unknown delivery, and ownership. The supported migration is to start a fresh foreground phase from the issue/Draft PR and worktree.

This is one OpenSpec change because worker lifecycle, develop run state, continuation records, documentation, and the two obsolete capabilities are one tightly coupled removal. Splitting them would leave intermediate commits where documentation or a caller refers to state that the other side no longer implements.

### Account registration lives at the `codex-develop.py request` boundary

There will be no `register` subcommand and no durable account registry. The existing `--account-home NAME=PATH` repeatable option and `--account-home-file PATH` flat JSON are the registration boundary: the coordinator supplies the mapping for each delegation, `request` validates it, resolves the selected Codex role's account name, and writes the absolute `codex_home` into the private request. `run` treats that resolved home as the execution source and verifies it against the live account.

This is preferred to moving `register` into `codex-develop.py` or introducing a standalone account file because either alternative recreates machine-local persistent state whose lifetime and migration would need management. The explicit mapping already exists, fails closed for missing accounts, supports profiles, and matches the design principle that provider/account differences occur only in the routing input.

The trade-off is deliberate: a caller can label one CODEX_HOME with the wrong account name. The worker therefore continues to publish the live account as `effective.account` separately from `requested.account`; it does not pretend the label is authenticated.

**Specification reviewer checkpoint:** explicitly confirm that removing `register` rather than relocating it is acceptable, and that the per-delegation account-home mapping is the sole replacement.

### Preserve the foreground dependency slice before deleting shared-looking helpers

Implementation must establish tests around the foreground path before deleting code. The retained dependency slice is:

- In `codex-develop.py`: `ROOT` / `CANONICAL_ROLES`; role/phase tables and writer/reader instructions; `_unique_object`; `account_homes`; `validate_role_entry`; `load_profile`; `clean_env`; `git`; `prompt`; `resolve_execution`; `validate_execution_config`; `execution_config_hash`; `write`; `build_request`; and the `request` parser/dispatcher. The Claude branch returning `agent-required`, the full-profile validation, legacy `--account/--model` request form, and account-home validation remain.
- In `codex-worker.py`: request validation and execution metadata; `auth_info`; child/git environment filtering and linked-worktree/project-config checks; model/effort advertisement validation; foreground runtime creation, identity recheck and cleanup; quota parsing; RPC, final-answer selection and turn state; role sandbox/network policy; `ForegroundRecorder`; caller ancestry/signal monitoring; `run_turn`; and `run`.
- `run_turn` keeps the order `initialize` → live account verification → `model/list` verification → `account/rateLimits/read` quota preflight → `thread/start` → `turn/start`. It must not regain a dependency on any persistent store.

The deletion slice includes `db_open`, job row CRUD, `ownership_open`, `slot_state`, occupied/reservation logic, `LedgerRecorder`, detached `worker`, all ledger command branches and parsers, continuation encoding/selection/validation, `payload_hash`, `registered_accounts`, the `worker()` wrapper, `validate_profile_pending` / `validate_legacy_pending`, run JSON writes, and legacy command parsers.

### Keep one-line JSON and failure semantics as the transport contract

Removing durable job state does not weaken observability. `run` still returns the same-shaped one-line JSON for success and failure, keeps requested/effective/evidence separate, uses nonzero exit for failure, never retries a server-rejected start, and never falls back to a different account or provider. If the process ends before that JSON exists, the canonical workflow restarts the phase from the issue/Draft PR and worktree rather than replaying a saved request.

### Shrink each document by named mechanism, preserving unrelated rules

The documentation edits have an explicit deletion inventory:

- `scripts/CODEX-WORKER.md`: remove the entire ledger-path introduction and section, including persistent registration, job IDs, detached lifetime, status/result/cancel/ack/send/reap, unknown recovery, shared ownership DB, account slots, cwd locks, cross-state-dir behavior, heartbeat/staleness, and old-version coexistence. These paragraphs exist only to operate the removed mechanism. Retain and consolidate foreground request schema, role sandbox/read-only policy, environment filtering, auth pinning, model/effort checks, quota preflight, runtime cleanup, caller/signal shutdown, one-line JSON, and final-answer quality boundary.
- `docs/codex-develop.md`: remove the old registration example and the full “台帳を持つ旧経路” section covering init/dispatch/status/result/ack/retry, worker-state, run-dir, pending, and continuation markers. Retain setup, account-home inputs, profile/legacy request forms, three-step foreground invocation, no-fallback behavior, role responsibilities, and quality workflow. Add manual cleanup conditions and commands for existing state.
- `references/codex-develop.md`: remove only claims that legacy dispatch, ledger commands, ack/retry/run directory/continuation remain available. Retain role resolution, built-in/mixed profiles, budget application, fresh-thread and handoff rules, foreground three-step invocation, reviewer/write-role boundaries, hooks caveat, quality gates, no fallback, OpenSpec mapping, evidence handoff, and worktree serialization. Preserve exactly one occurrence of `executor` as required by #342.
- `commands/develop.md`: remove `[--worker-state DIR] [--run-dir DIR]` from the argument hint. Replace the continuation/run-dir paragraph with only「引数なしの追加依頼では初回の Codex 設定を再推測せず、実行先オプションと account-home の対応を明示し直す。」and remove the ledger-route options paragraph. Preserve the `SendMessage` and context-limit wording read by `develop-command.bats` and `test_codex_develop.py`.
- `skills/develop/SKILL.md`: remove only「旧台帳経路も互換性のため残るが、1つの委譲を複数 transport にまたがせない。」and retain all unrelated canonical workflow rules.

Tests should assert the retained rules and the removed vocabulary so a concise rewrite cannot silently lose unrelated behavior.

### Retire obsolete capabilities and narrow the two surviving specs

`codex-worker-concurrency` and `codex-develop-continuation` are removed in full because every requirement depends on slots/ownership or run/continuation storage. OpenSpec cannot represent a capability whose delta removes every requirement, so these two capabilities have no delta directories; implementation deletes their main spec directories immediately before archive. `codex-worker` remains but becomes foreground-only: requirements are rewritten where they currently compare foreground and ledger routes, and ledger-only compatibility scenarios are removed. `manual-codex-develop` remains for role routing and foreground delegation; its saved-pending requirement and ledger-specific clauses are removed.

The retired `codex-worker-concurrency` requirements and migrations are summarized here:

- Account concurrency limits, cwd exclusion, and abandoned-slot reap all depend on SQLite ownership plus lifecycle-job occupancy, so they disappear with that store. The canonical coordinator instead assigns one job per worktree and serializes writing roles; any future cross-provider concurrency control must be shared with Claude rather than recreate a Codex-only registry.
- Quota margin no longer multiplies by occupied slots. The surviving foreground quota preflight checks one request plus `quota_margin_pct` without consulting other jobs.
- Server-start rejection is reported in the foreground one-line JSON with a nonzero exit and no retry or account fallback; there is no durable failed/unknown job state to preserve.
- Past state is not reaped by the worker. The user stops the foreground command and may remove the old state directory only after the documented safety checks.

The retired `codex-develop-continuation` requirements and migrations are summarized here:

- v1/v2 continuation restoration and run matching disappear with run directories. A fresh phase starts from the issue or Draft PR and worktree, with profile/account mapping resolved again; missing inputs fail closed without provider or account fallback.
- Canonical specification, review, verify, archive, finish/G, and role-responsibility boundaries remain provider-neutral in `manual-codex-develop` and the canonical develop workflow; no continuation layer may alter them.
- v1/v2 fixtures are replaced by foreground request/run, fresh-phase re-delegation, no-fallback, and profile-routing regression coverage.
- The coordinator continues to own record-target selection, routing, and proxy posting of read-only verdicts; workspace-write roles keep GitHub/commit/push responsibility and do not collect LLM logs.

Archive must result in the two obsolete main spec files no longer existing, while `openspec validate --specs` succeeds.

### Existing state is inert data and only the user deletes it

The code does not scan, migrate, mutate, or delete `~/.local/state/claude-harness-codex/`, including at startup. Documentation tells the user to remove it only after all three conditions hold: (1) `pgrep -fl 'codex-worker.py'` is empty, (2) every old job whose result must be recovered was recovered with 2.13.14 or judged unnecessary, and (3) no dev-workflow 2.13.14-or-earlier session remains. The documented user-run command is exactly `rm -rf -- "$HOME/.local/state/claude-harness-codex"`; it explains that `runtimes/` contains links to `auth.json`, so deleting those links does not delete the authentication data at their targets. This is an explicit command against the exact directory, not an automatic action or broad glob.

Rollback is a normal code revert. Because the new code never modifies the old state, reverting to 2.13.14 can still read it, subject to whatever state was already present before this change.

## Risks / Trade-offs

- [Direct users of removed CLI commands break] → Mark the change breaking, list every removed command, and document the foreground replacement rather than silently accepting old syntax.
- [Deleting shared code breaks `run`] → Add/retain focused foreground tests first, then delete only outside the dependency slice and run the full suite.
- [Documentation becomes shorter by losing live rules] → Use the per-document deletion inventory above and add textual regression checks, including `grep -c "executor" ... == 1`.
- [Users delete state while an old worker still runs] → Never delete automatically; document process/version checks and explicit manual cleanup only.
- [No durable recovery after a crash] → This is the intended parity with Claude subagents: resume from the record target and worktree, starting a fresh phase.
- [Account mapping must be passed repeatedly] → Prefer explicit input over a new hidden registry; callers may reuse their own private JSON file via `--account-home-file`.

## Migration Plan

1. Add failing tests for the removed CLI surface and retained foreground behaviors, including Claude `agent-required` routing and doc invariants.
2. Remove run/continuation state from `codex-develop.py`, leaving the request-only parser and dependencies.
3. Remove ledger/ownership state and lifecycle commands from `codex-worker.py`, leaving the run-only parser and dependencies.
4. Shrink docs using the deletion inventory and add the explicit manual state-cleanup guidance.
5. Apply the spec deltas, bump only the dev-workflow entries to 2.13.15, run OpenSpec validation and the full test suite, then perform independent review before archive.

Rollback reverts the implementation and version bump. No data rollback step is needed because the new code does not mutate old state.

## Open Questions

None for implementation. The independent spec reviewer must explicitly adjudicate the `register` decision called out above before implementation begins.
