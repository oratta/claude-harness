# Codex Prompts — codex-build-agent-poc

Prompts handed to Codex via `codex-companion task --write` during Task #6.
We keep at least two iterations so the evaluation can compare commit-grain
quality across prompt versions.

> **Status**: Both versions are written but NOT yet dry-run against a real
> Codex. The dry-run + observed-output annotations belong to Task #6.

---

## V1 — Initial prompt

```
You are operating as the Build agent for a TDD-driven OpenSpec change in a
locked-down sandbox. The sandbox is at:

  _longruns/2026-05-13_codex-build-agent-eval/sandbox/

ABSOLUTE RULES (violating any one of these aborts the run):
  R1. Do not modify any file outside the sandbox directory above.
  R2. Do not create new files outside that sandbox directory.
  R3. Do not touch ~/.codex/, ~/.claude/, or any plugin files.
  R4. Each commit must use Conventional Commits (feat:, fix:, test:, refactor:).
  R5. Tests come FIRST. A `feat:` commit that ships without a preceding `test:`
      commit (covering the same module) is a violation.

Your task:
  1. Read sandbox/tests/greet.test.ts to understand the spec.
  2. Confirm `npm test` is currently RED. Quote the failing output.
  3. Make ONE commit that adds or refines tests only (allowed if the existing
     tests already cover the spec; otherwise add edge cases). Message:
     `test(greet): describe expected greet() behaviour`
  4. Make ONE commit that implements `src/greet.ts` to satisfy the tests.
     Do not add unrelated logic. Message:
     `feat(greet): implement greet() to satisfy tests`
  5. Confirm `npm test` is GREEN. Quote the passing output.

Constraints:
  - Each commit's diff must be minimal (one logical change).
  - Refactors (if any) go in a third `refactor:` commit, never amended in.
  - Do NOT run `git push`, `git rebase`, or `git reset --hard`.

When done, print:
  RED→GREEN summary as a 5-line block.
  Final `git log --oneline` from the sandbox.
```

### Predicted weaknesses (to validate during Task #6)

- Codex may **combine** the test refinement and implementation into a single
  commit if it judges the existing tests sufficient. Mitigated in V2 by making
  Step 3 explicitly optional with a `noop:` escape.
- Codex may add **non-spec edge cases** (e.g. internationalisation) to look
  thorough. V2 caps the scope to exactly the cases described in
  `tests/greet.test.ts`.
- The "quote failing output" step often gets summarised away. V2 demands a
  verbatim fenced code block.

---

## V2 — Iterated prompt (commit-grain hardened)

```
ROLE: Build agent inside a Codex-driven TDD harness.
SCOPE: Only `_longruns/2026-05-13_codex-build-agent-eval/sandbox/`.

INVIOLABLE RULES
  - Sandbox-only writes. Nothing under plugins/, openspec/, or ~/.codex/.
  - Conventional Commits, one logical change per commit.
  - Tests precede implementation. Production code without a preceding test
    commit is a violation.
  - No amends, no rebases, no force-pushes, no `git reset --hard`.

PROCEDURE (each step is its own commit unless explicitly marked noop)

  Step 0 (verify RED)
    Run `npm test`. Paste the RAW failing output inside a fenced ```text block.
    No commit.

  Step 1 (test pass-through, may be noop)
    If `tests/greet.test.ts` already exercises:
      (a) greet('world') === 'Hello, world!'
      (b) greet('')      === 'Hello, stranger!'
    then commit `test(greet): acknowledge existing spec coverage (noop)`
    with an empty `--allow-empty` commit. Otherwise add the missing case in
    the test file and commit `test(greet): cover <case>`.

  Step 2 (implement)
    Edit `src/greet.ts` so both assertions in tests/greet.test.ts pass.
    Constraints:
      - Pure function. No I/O, no globals, no module-level side effects.
      - No additional exports.
    Commit: `feat(greet): implement greet() per spec`

  Step 3 (verify GREEN)
    Run `npm test`. Paste the RAW passing output inside a fenced ```text block.
    No commit.

  Step 4 (optional refactor)
    Only if there is duplication or a `// TODO(codex)` comment left over.
    Commit: `refactor(greet): <one-line reason>`

OUTPUT FORMAT (mandatory; the harness scrapes these markers)
  ```red
  <verbatim failing test output>
  ```
  ```green
  <verbatim passing test output>
  ```
  ```log
  <output of `git log --oneline -n 10` in the sandbox>
  ```
```

### Why V2 should outperform V1

- The `(noop)` escape removes Codex's incentive to invent extra tests just to
  produce a non-empty `test:` commit, which was the most likely cause of the
  V1 commit-collapse failure mode.
- Fenced output markers (` ```red `, ` ```green `, ` ```log `) make the
  RED→GREEN ladder machine-greppable for the evaluation script in Task #6.
- The implementation step lists explicit pure-function constraints, which we
  predict will reduce drift into unrelated edge cases.
