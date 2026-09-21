## 1. Contract tests first

- [ ] 1.1 Update `test_codex_worker.py` before production edits so removed lifecycle commands/imports/storage fail the test, while foreground `run` still covers auth pinning, model/effort validation, role policy, quota preflight, caller/signal shutdown, and one-line JSON results.
- [ ] 1.2 Update `test_codex_develop.py` before production edits so run-dir/pending/continuation APIs and CLI commands are rejected, while account-home mapping, legacy account/model request input, named profiles, and Claude `status: agent-required` routing remain covered.
- [ ] 1.3 Update `handoff-declaration.bats` and focused documentation assertions before documentation edits to reject removed state operations and preserve all unrelated adapter rules, including exactly one `executor` occurrence in `references/codex-develop.md`.
- [ ] 1.4 Run the focused changed tests and record the expected Red failures caused by the still-present legacy surface.

## 2. Reduce the executable surface

- [ ] 2.1 Remove continuation encoding/parsing/restoration, SQLite account lookup, run snapshot/pending/retry helpers, state writers, worker lifecycle wrapper, and `init`/`dispatch`/`status`/`result`/`ack`/`retry` parsing from `codex-develop.py`, leaving a request-only CLI.
- [ ] 2.2 Preserve `codex-develop.py request` account-home resolution, profile and legacy account/model validation, role prompt construction, fixed HEAD evidence, private request creation for Codex roles, and unchanged `agent-required` output for Claude roles.
- [ ] 2.3 Remove SQLite job/account schema, global ownership, slots/locks, ledger recorder, detached worker, heartbeat/staleness, and `register`/`submit`/`status`/`result`/`cancel`/`ack`/`send`/`reap` parsing from `codex-worker.py`, leaving `run --request` as the only command.
- [ ] 2.4 Preserve the foreground dependency slice and execution order: request validation, CODEX_HOME/runtime auth checks, model/list model-effort validation, role sandbox/read-only policy, rate-limit preflight, thread/turn execution, parent/signal cancellation, runtime cleanup, and one-line JSON output.
- [ ] 2.5 Run the focused worker/develop tests to Green and confirm the Python scripts no longer import or refer to removed persistence mechanisms.

## 3. Documentation and release metadata

- [ ] 3.1 Rewrite `scripts/CODEX-WORKER.md` as a foreground-only reference, removing only the ledger/ownership/lifecycle material inventoried in design.md and retaining the runtime, security, environment, quota, shutdown, result, and quality-boundary rules.
- [ ] 3.2 Remove registration and old run workflow instructions from `docs/codex-develop.md`, retain the foreground/profile/quality guidance, and document exact safety conditions plus an explicit user-run procedure for deleting `~/.local/state/claude-harness-codex/`; add no automatic deletion code.
- [ ] 3.3 Remove only legacy transport claims from `references/codex-develop.md`, preserve every unrelated routing/budget/thread/review/hook/gate/no-fallback rule listed in design.md, and keep `grep -c "executor" plugins/dev-workflow/references/codex-develop.md` equal to 1.
- [ ] 3.4 Bump only dev-workflow entries in `plugins/dev-workflow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` from 2.13.14 to 2.13.15.

## 4. Specification and acceptance verification

- [ ] 4.1 Confirm the delta specs encode a foreground-only `codex-worker`, full removal of `codex-worker-concurrency` and `codex-develop-continuation`, and removal of saved-request recovery from `manual-codex-develop`; record that archive must also rewrite the surviving `codex-worker` Purpose so it has no ledger/ack claim.
- [ ] 4.2 Run issue #341 conditions 1–4 exactly, run `openspec validate --specs`, and verify every expected zero-match/existence check has the specified exit code.
- [ ] 4.3 Verify the docs contain manual state cleanup guidance, no code path deletes `~/.local/state/claude-harness-codex/`, and the PR body contains `Closes #341`, `Closes #323`, `Closes #329`, `Closes #331`, and `Closes #336`.
- [ ] 4.4 Run all focused Python/Bats tests changed by this work and record commands, counts, and exit codes.
- [ ] 4.5 Check `ps -eo pid,args | grep -E 'scripts/test.sh|bats-exec' | grep -v grep` returns no competing full suite, then run `bash scripts/test.sh` to exit 0; if the known statusline multi-account test fails, rerun it alone before classifying the failure.
- [ ] 4.6 Inspect the final diff against design.md's per-document deletion inventory and record, for each shrunken document, exactly what was removed and why it belonged to the retired mechanism.
