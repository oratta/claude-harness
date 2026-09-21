## 1. Contract tests first

- [x] 1.1 Update `test_codex_worker.py` before production edits so removed lifecycle commands/imports/storage fail the test, while foreground `run` still covers auth pinning, model/effort validation, role policy, quota preflight, caller/signal shutdown, and one-line JSON results.
- [x] 1.2 Update `test_codex_develop.py` before production edits so run-dir/pending/continuation APIs and CLI commands are rejected, while account-home mapping, legacy account/model request input, named profiles, and Claude `status: agent-required` routing remain covered.
- [x] 1.3 Add the removed-vocabulary zero-match checks to `plugins/dev-workflow/tests/test_codex_develop.py:1040` の `DocumentationContracts`, where the existing single-`executor` assertion lives, before documentation edits. `handoff-declaration.bats` は Codex・台帳の記述を含まないため、変更不要を確認する。
- [x] 1.4 Run the focused changed tests and record the expected Red failures caused by the still-present legacy surface.

## 2. Reduce the executable surface

- [ ] 2.1 Remove continuation encoding/parsing/restoration, SQLite account lookup, run snapshot/pending/retry helpers, state writers, worker lifecycle wrapper, and `init`/`dispatch`/`status`/`result`/`ack`/`retry` parsing from `codex-develop.py`, leaving a request-only CLI.
- [ ] 2.2 Preserve `codex-develop.py request` account-home resolution, profile and legacy account/model validation, role prompt construction, fixed HEAD evidence, private request creation for Codex roles, and unchanged `agent-required` output for Claude roles.
- [ ] 2.3 Remove SQLite job/account schema, global ownership, slots/locks, ledger recorder, detached worker, heartbeat/staleness, and `register`/`submit`/`status`/`result`/`cancel`/`ack`/`send`/`reap` parsing from `codex-worker.py`, leaving `run --request` as the only command.
- [ ] 2.4 Preserve the foreground dependency slice and execution order: request validation, CODEX_HOME/runtime auth checks, model/list model-effort validation, role sandbox/read-only policy, rate-limit preflight, thread/turn execution, parent/signal cancellation, runtime cleanup, and one-line JSON output.
- [ ] 2.5 Run the focused worker/develop tests to Green and confirm the Python scripts no longer import or refer to removed persistence mechanisms.

## 3. Documentation and release metadata

- [ ] 3.1 Rewrite `scripts/CODEX-WORKER.md` as a foreground-only reference, removing only the ledger/ownership/lifecycle material inventoried in design.md and retaining the runtime, security, environment, quota, shutdown, result, and quality-boundary rules.
- [ ] 3.2 Remove registration and old run workflow instructions from `docs/codex-develop.md`, retain the foreground/profile/quality guidance, and write「コードは起動時にこのディレクトリを見ない」。Permit cleanup only when (1) `pgrep -fl 'codex-worker.py'` is empty, (2) every old job whose result must be recovered was recovered with 2.13.14 or judged unnecessary, and (3) no dev-workflow 2.13.14-or-earlier session remains. Document exactly `rm -rf -- "$HOME/.local/state/claude-harness-codex"` and explain that `runtimes/` 内の `auth.json` はリンクで、リンク先の認証情報は消えない; add no automatic deletion code.
- [ ] 3.3 Remove only legacy transport claims from `references/codex-develop.md`, preserve every unrelated routing/budget/thread/review/hook/gate/no-fallback rule listed in design.md, and keep `grep -c "executor" plugins/dev-workflow/references/codex-develop.md` equal to 1.
- [ ] 3.4 Update `plugins/dev-workflow/commands/develop.md`: remove `[--worker-state DIR] [--run-dir DIR]` from `argument-hint`; replace the continuation/run-dir paragraph with exactly「引数なしの追加依頼では初回の Codex 設定を再推測せず、実行先オプションと account-home の対応を明示し直す。」; delete the ledger-route options paragraph; preserve the `SendMessage` and context-limit wording read by `develop-command.bats` and `test_codex_develop.py`.
- [ ] 3.5 Update `plugins/dev-workflow/skills/develop/SKILL.md` by deleting exactly「旧台帳経路も互換性のため残るが、1つの委譲を複数 transport にまたがせない。」and preserving all unrelated workflow rules.
- [ ] 3.6 Bump only dev-workflow entries in `plugins/dev-workflow/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` from 2.13.14 to 2.13.15.

## 4. Specification and acceptance verification

- [ ] 4.1 Confirm the delta specs encode a foreground-only `codex-worker` and removal of saved-request recovery from `manual-codex-develop`; confirm the two all-REMOVED capability deltas are absent because main-spec deletion is handled explicitly in 4.7.
- [ ] 4.2 Run issue #341 conditions 1–4 exactly, run `openspec validate --specs`, and verify every expected zero-match/existence check has the specified exit code.
- [ ] 4.3 Verify the docs contain manual state cleanup guidance, no code path deletes `~/.local/state/claude-harness-codex/`, and the PR body contains `Closes #341`, `Closes #323`, `Closes #329`, `Closes #331`, and `Closes #336`.
- [ ] 4.4 Run all focused Python/Bats tests changed by this work and record commands, counts, and exit codes.
- [ ] 4.5 Check `ps -eo pid,args | grep -E 'scripts/test.sh|bats-exec' | grep -v grep` returns no competing full suite, then run `bash scripts/test.sh` to exit 0; if the known statusline multi-account test fails, rerun it alone before classifying the failure.
- [ ] 4.6 Inspect the final diff against design.md's per-document deletion inventory and record, for each shrunken document, exactly what was removed and why it belonged to the retired mechanism.
- [ ] 4.7 Immediately before archive, run `git rm -r openspec/specs/codex-worker-concurrency openspec/specs/codex-develop-continuation`, then run `openspec archive remove-codex-legacy-state --yes`. After archive, manually replace the final sentence of `openspec/specs/codex-worker/spec.md` Purpose line 4 with「…ごとに砂場と取得経路を決め、認証帰属の照合を行い、1 回の前景実行の結果を標準出力の 1 行 JSON で返す。永続的な台帳・所有権・受領は持たない。」and delete line 8's `codex-worker-concurrency` reference. Finally run `openspec validate --specs` and require exit 0.
