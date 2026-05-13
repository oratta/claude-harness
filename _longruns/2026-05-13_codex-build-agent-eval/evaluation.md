# Codex Build Agent PoC — Evaluation Report

> **Status**: Template only. Task #6 (orchestrator) is responsible for filling
> in every `TBD` cell after running `run-poc.sh`, `run-fallback.sh`, and
> `measure-tdd-fidelity.sh` against a real Codex CLI session.

## Environment

- Run date (UTC): TBD
- Codex CLI version: TBD
- Available Codex models (raw `codex --help` excerpt): TBD
- Codex model: TBD
- Codex auth source: TBD (e.g. `~/.codex/auth.json` present? yes/no)
- Opus auth source: TBD
- Host: TBD (`uname -a` short form)

## Results summary (4 axes)

| Axis                                | Result   | Notes                                              |
|-------------------------------------|----------|----------------------------------------------------|
| TDD loop completed (Codex, #6a)     | TBD      | RED→GREEN cycles observed; test count             |
| Commit granularity (#6b)            | TBD      | test-first ordering verified via `git log`         |
| Fallback drill (#7)                 | TBD      | Trigger pattern, time-to-detect                    |
| Cost / wall-clock (Codex vs Opus)   | TBD      | n=1; see raw numbers below                         |
| TDD fidelity (no-test-rate)         | TBD      | Output of `measure-tdd-fidelity.sh`               |

### Raw numbers (filled by scripts; do not hand-edit)

- Codex wall-clock: TBD
- Opus wall-clock: TBD
- no-test-rate: TBD

## Per-scenario outcomes

| Scenario | Status | Evidence (link / quote) |
|----------|--------|-------------------------|
| S1  Codex model discovery        | TBD | (excerpt of `codex --help`) |
| S2  5.5 Pro fallback (if absent) | TBD | adopted model id           |
| S3  TDD RED→GREEN loop           | TBD | quoted RED + GREEN blocks  |
| S4  Test-first commit order      | TBD | `git log --oneline`        |
| S5  Codex-down -> Opus           | TBD | fallback log line          |
| S6  Wall-clock recorded          | TBD | numbers above              |
| S7  TDD fidelity %               | TBD | classifier output          |
| S8  Pre-guard (dirty worktree)   | TBD | Bats coverage              |
| S9  Post-guard (outside writes)  | TBD | Bats coverage              |
| S10 Guard self-test (#12)        | TBD | Bats coverage              |
| S11 4-axis report present        | TBD | this file                  |
| S12 Existing files unchanged     | TBD | `git diff main -- ...`     |

## Phase 2 carry-over risks (minimum 5; the first four are mandatory)

1. **(a) Codex timeout / hang detection**
   - Risk: A Codex session may hang mid-stream (e.g. partial stdout, no exit).
     The PoC harness today has no inactivity timer.
   - Phase 2 plan: wrap `codex-companion task` in `timeout 600 ...` and treat
     SIGTERM as a "fallback to Opus" signal.

2. **(b) Partial-success rollback**
   - Risk: Codex may commit a test-only change and then crash, leaving the
     sandbox half-done. The post-guard catches *outside* writes but not
     *incomplete* TDD ladders.
   - Phase 2 plan: after each Codex turn, require both a `test:` and a
     matching `feat:` commit pair within N turns or `git reset --hard` to the
     pre-run SHA recorded by `run-poc.sh`.

3. **(c) Subscription-quota distinction**
   - Risk: There is no documented CLI flag for "how much quota is left".
     Today we can only react after a 429 / `quota exceeded` stderr.
   - Phase 2 plan: catalogue the exact stderr fingerprints observed during
     this PoC and pattern-match them in `run-fallback.sh`. Until then the
     fallback fires on *any* non-zero codex exit, which over-triggers.

4. **(d) Network-down vs auth-failure**
   - Risk: Both surface as non-zero exit codes; today the fallback can't tell
     them apart, which matters because network-down is transient and should
     retry, while auth-failure should hard-fail the run.
   - Phase 2 plan: classify by stderr (`ENOTFOUND`/`ETIMEDOUT` vs `401`/
     `unauthorized`) and add a `--retry` count to the Codex path.

5. **TDD fidelity drift under longer changes**
   - Risk: The PoC sample (`greet`) is a single function. On a real
     `longrun-builder` workload (many files, refactors), Codex's commit
     granularity could degrade in ways the 4-axis sample doesn't reveal.
   - Phase 2 plan: extend the fidelity classifier to bucket by "files
     touched" and "diff size", and re-evaluate on at least one real change.

6. **(stretch) `~/.codex/` immutability under concurrent sessions**
   - Risk: If two `run-poc.sh` invocations race (e.g. via experience-to-skill
     auto-commit), they may both touch `~/.codex/` state and corrupt it.
   - Phase 2 plan: file-lock `~/.codex/` reads with `flock`; treat lock
     failure as fallback.

## Go / Conditional Go / No-Go

- **Decision**: TBD
- **Rationale**: TBD
- **Phase 2 carry-over**: see risk list above.

### Decision rubric (recap of plan.md)

- **Go** if #6a, #6b, #7 all pass AND no-test-rate is 0%.
- **Conditional Go** if #6a and #7 pass but #6b or fidelity has shortfalls;
  Phase 2 plan must include a "commit-grain prompt redesign" task.
- **No-Go** if #6a or #7 fail, OR Bats #12 (guard self-test) breaks.

---

- fallback path engaged: TBD (filled by `run-fallback.sh`)
