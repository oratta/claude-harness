## 1. Test fixtures and Red tests

- [ ] 1.1 Add secret-free JSONL and meta fixtures covering the same message ID with different request IDs, main/sub separation, exact-match and near-miss role strings, period-before starts, the four named model families, malformed records, PR association, usage-free user/tool-result rows, and intervals crossing both UTC period boundaries.
- [ ] 1.2 Add failing Bats tests for weekly metrics schema, exact jq acceptance (including baseline pace null and a non-null seven-observation-day period), token/cost calculations, role/model classification and starts boundary, gate PR medians, all-line 15-minute active-time clipping, GitHub lead-time/quality metrics, diagnostics, and invalid arguments.
- [ ] 1.3 Add failing Bats tests for atomic account-separated usage pace appends with `accounts.<id>.fetched_at`, stale duplicate observations, null/missing accounts, conflicting duplicate identities, reset-day differences, partial windows, one-account missingness, zero valid windows, concurrent writes, and absence of real-home or scheduler side effects.
- [ ] 1.4 Add a regression test that fixes the existing `cost_ledger.py cost` public output and its requestId-first deduplication before refactoring shared parsing and pricing helpers; use the same-message/different-request fixture to prove weekly metrics and `/cost` keep different policies.

## 2. Local transcript metrics

- [ ] 2.1 Refactor only reusable usage validation, model normalization, and pricing helpers in `cost_ledger.py`; implement weekly metrics deduplication as `message.id` → `requestId` → `uuid` while keeping the existing `/cost` `requestId` → `uuid` policy and command tests green.
- [ ] 2.2 Implement one-pass UTC-filtered main/sub transcript collection with per-population deduplication, malformed-record warnings, turns, context-per-turn, and API-equivalent cost.
- [ ] 2.3 Implement the specified first-nonempty-launch-line/basename literal matching, period-bounded starts, and startup-model shares without emitting raw prompts, paths, or authentication data; period-before transcripts contribute only their in-period usage/time.
- [ ] 2.4 Implement per-transcript active intervals from every valid JSONL timestamp, clipping valid intervals at period boundaries only after applying the 15-minute threshold, plus role totals, PR association for gate-runner, and per-PR turn/context/minute medians.

## 3. Pace and GitHub metrics

- [ ] 3.1 Implement `usage-pace-log.sh` with configurable snapshot/output paths, `recorded_at`, per-account `fetched_at` / pct / reset values (including null accounts), validation, sensitive-field filtering, and concurrency-safe one-line writes.
- [ ] 3.2 Deduplicate observations by account and fetched_at, reject conflicting identities, and implement account-local reset-window projections requiring seven UTC observation days; average with each account's own valid-window denominator and output `pace.weekly_sum_pct: null` for partial, one-account-missing, zero-valid-window, and no-log cases rather than treating missingness as zero.
- [ ] 3.3 Implement fakeable, paginated `gh api` REST queries for all current-repository closed PR pages, locally filter author and `merged_at`, and de-duplicate bug issues in the union of seven-day post-merge windows; fake gh must reproduce snake_case REST fields and at least two pages with a relevant item on page 2, and GitHub errors must fail closed.

## 4. Public command and documentation

- [ ] 4.1 Implement the thin `weekly-metrics.sh` entrypoint, strict date validation, one-line stdout JSON, stderr-only diagnostics, configurable fixture inputs, and the full stable output schema.
- [ ] 4.2 Update the cost-ledger README with command/output documentation, fetched_at observation semantics, missing/stale pace behavior, daily manual invocation, launchd or equivalent registration and removal examples, privacy boundaries, and explicit instructions not to register the scheduler automatically.
- [ ] 4.3 Document the post-merge operational handoff: collect at least three future daily pace records, verify `wc -l >= 3`, run the 2026-09-01 through 2026-09-21 baseline with `pace.weekly_sum_pct: null` because no historical records exist, and post its formatted table to epic #360 without backfilling, converting missingness to zero, or automating those external writes in tests or implementation.

## 5. Verification

- [ ] 5.1 Run focused cost-ledger Bats tests and confirm fixture-only execution, exact jq acceptance, existing cost command compatibility, and no scheduler/home side effects.
- [ ] 5.2 Run `scripts/test.sh` and confirm exit 0.
- [ ] 5.3 Run `openspec validate add-effect-metrics-baseline --strict`, confirm all task checkboxes are complete after implementation, and record the remaining operational handoff separately from PR code completion.
