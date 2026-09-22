## 1. Test fixtures and Red tests

- [ ] 1.1 Add secret-free JSONL and meta fixtures covering duplicate message IDs, main/sub separation, the four roles, the four named model families, malformed records, PR association, and UTC period boundaries.
- [ ] 1.2 Add failing Bats tests for weekly metrics schema, exact jq acceptance, token/cost calculations, role/model classification, gate PR medians, 15-minute active-time boundaries, GitHub lead-time/quality metrics, diagnostics, and invalid arguments.
- [ ] 1.3 Add failing Bats tests for atomic account-separated usage pace appends, invalid snapshot rejection, reset-window 7-day projection, concurrent writes, and absence of real-home or scheduler side effects.
- [ ] 1.4 Add a regression test that fixes the existing `cost_ledger.py cost` public output before refactoring shared parsing and pricing helpers.

## 2. Local transcript metrics

- [ ] 2.1 Refactor the minimum reusable usage extraction, message-ID fallback, model normalization, and pricing helpers in `cost_ledger.py` while keeping the existing cost command tests green.
- [ ] 2.2 Implement one-pass UTC-filtered main/sub transcript collection with per-population deduplication, malformed-record warnings, turns, context-per-turn, and API-equivalent cost.
- [ ] 2.3 Implement transcript-level role classification and startup-model shares without emitting raw prompts, paths, or authentication data.
- [ ] 2.4 Implement per-transcript active intervals, role totals, PR association for gate-runner, and per-PR turn/context/minute medians.

## 3. Pace and GitHub metrics

- [ ] 3.1 Implement `usage-pace-log.sh` with configurable snapshot/output paths, one-line multi-account JSON append, validation, sensitive-field filtering, and concurrency-safe writes.
- [ ] 3.2 Implement reset-window grouping and 7-day projections for `pace.by_account` and `pace.weekly_sum_pct`, including warnings for insufficient samples.
- [ ] 3.3 Implement fakeable `gh` queries for current-repository merged PR lead time/count and de-duplicated bug issues in the union of seven-day post-merge windows, failing closed on GitHub errors.

## 4. Public command and documentation

- [ ] 4.1 Implement the thin `weekly-metrics.sh` entrypoint, strict date validation, one-line stdout JSON, stderr-only diagnostics, configurable fixture inputs, and the full stable output schema.
- [ ] 4.2 Update the cost-ledger README with command/output documentation, daily manual invocation, launchd or equivalent registration and removal examples, privacy boundaries, and explicit instructions not to register the scheduler automatically.
- [ ] 4.3 Document the post-merge operational handoff: collect at least three daily pace records, verify `wc -l >= 3`, run the 2026-09-01 through 2026-09-21 baseline, and post its formatted table to epic #360 without automating those external writes in tests or implementation.

## 5. Verification

- [ ] 5.1 Run focused cost-ledger Bats tests and confirm fixture-only execution, exact jq acceptance, existing cost command compatibility, and no scheduler/home side effects.
- [ ] 5.2 Run `scripts/test.sh` and confirm exit 0.
- [ ] 5.3 Run `openspec validate add-effect-metrics-baseline --strict`, confirm all task checkboxes are complete after implementation, and record the remaining operational handoff separately from PR code completion.
