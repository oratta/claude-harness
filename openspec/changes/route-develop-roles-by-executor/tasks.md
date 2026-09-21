## 1. Profile validation tests (Red)

- [x] 1.1 Add failing `test_codex_develop.py` coverage for a complete mixed version 1 profile, asserting every canonical role resolves the profile's exact executor/account/model/effort tuple and that the built-in `hybrid-standard` values preserve `review == impl-review`.
- [x] 1.2 Add failing table-driven coverage that rejects Claude models outside `haiku|sonnet|opus|fable`, Claude accounts other than `current` with an explicitly unsupported-account error, `fable` on every non-decider role, and executors outside `claude|codex` without creating a request.
- [x] 1.3 Add failing foreground-route coverage showing a Claude role returns `agent-required` with the unchanged requested tuple and creates no Codex request even when a budget mode will cap Agent startup, while a Codex role still writes a request with the selected account/model/effort and CODEX_HOME.
- [x] 1.4 Add failing legacy-dispatch coverage showing a mixed snapshot validates but a selected Claude role stops before any Codex worker submission.

## 2. Executor-aware profile resolution (Green)

- [x] 2.1 Refactor `load_profile` and `validate_execution_config` to share executor-discriminated validation while retaining version 1, complete canonical roles, non-empty four-field entries, registered Codex accounts, and the review/impl-review equality invariant.
- [x] 2.2 Make `resolve_execution` return the selected role's unchanged executor/account/model/effort tuple for both providers; remove the legacy `executor must be codex` error text rather than replacing it with a hidden fallback.
- [x] 2.3 Update foreground `request` preparation so executor=codex keeps the private request-file path and executor=claude returns `agent-required` with role/executor/account/model/effort/head without writing a Codex request or translating effort.
- [x] 2.4 Make the legacy ledger `dispatch` reject a selected Claude executor before `codex-worker.py` submission and point callers to the foreground provider route.
- [x] 2.5 Add the built-in `hybrid-standard` profile to `references/codex-role-profiles.json`: Codex standard settings for spec-write/implement/explore/summarize, Claude opus/current for spec-review/impl-review/review, and Claude fable/current for decider.

## 3. Coordinator and documentation contract

- [ ] 3.1 Update `references/codex-develop.md` so role resolution is followed by exactly one documented executor branch: Claude applies existing budget caps to the requested model at Agent startup and distinguishes requested/applied/reason, Codex uses request then foreground run, and Claude effort is recorded but not passed as an Agent option. Document that before every same-role Claude resume the current cap is checked: SendMessage is used only when the already-applied model is within the cap; otherwise the existing completion or stop-confirmation condition is satisfied before a fresh capped thread receives the unchanged requested tuple and an artifact/summary handoff, with requested/applied/reason recorded. A profile-role boundary or Codex delegation also starts fresh.
- [ ] 3.2 Update `skills/develop/SKILL.md` to consume the adapter's per-role executor result and synchronize its SendMessage resume points with the profile-role and current-cap rule, including fresh-thread handoff after the existing completion or stop-confirmation condition when the mode tightens, while leaving canonical phase ordering, review conditions, budget-mode tables, and provider-neutral transition decisions in the existing source of truth.
- [ ] 3.3 Update `references/model-tiers.md` to define the provider-neutral version 1 table, Claude tier validation, `current` account restriction, and decider-only Fable rule without duplicating Codex model IDs.
- [ ] 3.4 Add focused documentation regressions that prove the canonical executor branch occurs once in `references/codex-develop.md`, that `SKILL.md` points to it instead of restating it, and that same-role resume after a mode change to `exhausted` or `depleted` uses SendMessage only when the applied model remains within the cap and otherwise uses a fresh capped thread after the existing completion or stop-confirmation condition while preserving the requested tuple and recording requested/applied/reason; record the expected `grep -c "executor" plugins/dev-workflow/references/codex-develop.md` count in the test assertion.

## 4. Versioning and verification

- [ ] 4.1 Change only the dev-workflow entries in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` from 2.13.13 to 2.13.14.
- [ ] 4.2 Run `python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py` and record exit 0.
- [ ] 4.3 Run `grep -n "executor must be codex" plugins/dev-workflow/scripts/codex-develop.py`; record zero matches and the expected exit 1.
- [ ] 4.4 Run `openspec validate route-develop-roles-by-executor --strict` and record exit 0.
- [ ] 4.5 Confirm no other `scripts/test.sh` or `bats-exec` process is running, then run `bash scripts/test.sh` and record exit 0. If `statusline-multi-account.bats` alone is flaky, rerun that file in isolation before classifying the change.
