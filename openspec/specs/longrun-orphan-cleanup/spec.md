# longrun-orphan-cleanup Specification

## Purpose
TBD - created by archiving change longrun-v5-cleanup. Update Purpose after archive.
## Requirements
### Requirement: Verifier agents MUST describe context restoration and FAIL escalation via the live Workflow-driven recovery path, not the dismantled orchestrator

`plugins/longrun/agents/longrun-verifier.md` and `plugins/longrun/agents/longrun-browser-verifier.md` MUST NOT instruct context restoration from `checkpoint.md` as the starting point, and MUST NOT instruct escalating a FAIL result to "orchestrator". Both MUST instead describe the current recovery path: context restoration starts from `{longrun-dir}/plan.md` and `{longrun-dir}/decisions.md` (checkpoint.md may still be read as a supplementary human log, but is not the primary source), and a FAIL result is surfaced as a structured result that the generated Workflow script uses to re-invoke `longrun-builder` (no separate "orchestrator" component exists to escalate to).

#### Scenario: longrun-verifier context restoration step

- **WHEN** a reader opens `plugins/longrun/agents/longrun-verifier.md` and reads its "コンテキスト復元" step (current line ~37)
- **THEN** the step MUST list `{longrun-dir}/plan.md` and `{longrun-dir}/decisions.md` as the primary sources of current state, and MUST NOT state that `checkpoint.md` is read to "把握" (grasp) current status as the first/primary action

#### Scenario: longrun-verifier FAIL escalation step

- **WHEN** a reader opens `plugins/longrun/agents/longrun-verifier.md` and reads its "FAILの場合" step (current line ~98)
- **THEN** the step MUST NOT contain the string "orchestratorに修正を依頼" (or any equivalent instruction to escalate to an "orchestrator"), and MUST instead describe returning a structured FAIL result (per `verifier-score` schema) that the generated Workflow script uses to re-invoke `longrun-builder`

#### Scenario: longrun-browser-verifier context restoration step

- **WHEN** a reader opens `plugins/longrun/agents/longrun-browser-verifier.md` and reads its "コンテキスト復元" step (current line ~101)
- **THEN** the step MUST list `{longrun-dir}/plan.md` and `{longrun-dir}/decisions.md` as the primary sources of current state, and MUST NOT state that `checkpoint.md` is read to "把握" current status as the first/primary action

#### Scenario: longrun-browser-verifier verification-guide.md provenance note

- **WHEN** a reader opens `plugins/longrun/agents/longrun-browser-verifier.md` and reads the note about who generates `verification-guide.md` (current line ~151)
- **THEN** the note MUST NOT attribute generation to "orchestrator", and MUST instead attribute it to the Build phase / `longrun-builder` (or the generated Workflow script, whichever is accurate at implementation time)

#### Scenario: longrun-browser-verifier FAIL escalation step

- **WHEN** a reader opens `plugins/longrun/agents/longrun-browser-verifier.md` and reads its "FAILの場合" step (current line ~187)
- **THEN** the step MUST NOT contain the string "orchestratorに修正を依頼", and MUST instead describe returning a structured FAIL result that the generated Workflow script uses to re-invoke `longrun-builder`

### Requirement: longrun-builder agent description MUST match its actual output contract

`plugins/longrun/agents/longrun-builder.md` YAML frontmatter `description` field currently ends with "checkpoint.mdを更新する", which no longer matches actual behavior (checkpoint.md is an optional human memo; the builder's machine-consumed output is the `builder-report` schema, per `plugins/longrun/README.md` architecture section and `commands/exec.md` Step 4). The description MUST be updated to describe the actual completion contract instead of claiming checkpoint.md as the update target.

#### Scenario: longrun-builder description accuracy

- **WHEN** a reader reads the `description` field in `plugins/longrun/agents/longrun-builder.md` frontmatter
- **THEN** the description MUST NOT claim "checkpoint.mdを更新する" as the agent's completion action, and MUST describe the TDD implementation + structured completion report (`builder-report` schema) behavior instead

### Requirement: `commands/exec.md` historical note MUST NOT use the literal compound "longrun-orchestrator"

`plugins/longrun/commands/exec.md` line ~9 contains a historical BREAKING-change note referencing "旧 `longrun-orchestrator` SKILL.md". This is accurate history but its literal use of the compound "longrun-orchestrator" blocks the scoped-zero grep defined in this capability's residual-reference requirement (see design.md D1/D3). The note's substance (what was removed in v6.0.0: SKILL.md inline expansion, manual Agent control, prose parsing of checkpoint.md) MUST be preserved, but the literal string "longrun-orchestrator" MUST NOT appear in the rewritten sentence (e.g. referring to "旧 orchestrator スキル" instead of the full compound).

#### Scenario: exec.md historical note rewritten without the literal compound

- **WHEN** a reader greps `plugins/longrun/commands/exec.md` for the exact string `longrun-orchestrator`
- **THEN** there MUST be zero matches, while the surrounding sentence still accurately describes what v6.0.0 removed (SKILL.md inline expansion / manual Agent control / checkpoint.md prose parsing)

### Requirement: Dead code `scripts/update-checkpoint.sh` MUST be removed

`plugins/longrun/scripts/update-checkpoint.sh` has zero invocation sites (no hook configuration references it, and no other script or command file calls it — confirmed via `grep -rn "update-checkpoint.sh" plugins/`, whose only hit is the script's own self-referential header comment). It MUST be deleted from the git tree (git-tracked deletion, recoverable via history per plan.md constraint).

#### Scenario: dead script removed

- **WHEN** a reader checks for the existence of `plugins/longrun/scripts/update-checkpoint.sh`
- **THEN** the file MUST NOT exist

#### Scenario: no orphaned call sites remain after removal

- **WHEN** a reader runs `grep -rn "update-checkpoint.sh" plugins/` after the deletion
- **THEN** there MUST be zero matches (no dangling references to the deleted script anywhere in `plugins/`)

### Requirement: The `--mode=mvp` compatibility shim MUST be fully removed from `longrun-plan` SKILL.md

`plugins/longrun/skills/longrun-plan/SKILL.md` currently opens with a GATE block (current lines ~8-35) that intercepts `--mode=mvp`, prints a migration notice pointing to `/longrun:mvp`, and exits before Step 1. Since MVP plan creation has been an independent skill/command (`longrun-mvp-plan` / `/longrun:mvp` / `/lr:m`) for at least one full release cycle, and marketplace plugin distribution invalidates prior versions wholesale via version-bump cache eviction (making a permanent deprecation shim unnecessary per plan.md's own reasoning), this entire GATE block MUST be deleted. The skill's full-mode behavior (Step 1 through Step 8, template loading, `longrun-reviewer` invocation) MUST be preserved unchanged — only the mode-dispatch GATE at the top is removed.

#### Scenario: GATE block removed, full mode starts directly at Step 1

- **WHEN** a reader opens `plugins/longrun/skills/longrun-plan/SKILL.md`
- **THEN** the file MUST NOT contain a `--mode=mvp` interception GATE, and the document MUST begin its executable instructions directly with the full-mode flow (`# Run Plan — plan.md 作成スキル` heading or equivalent, followed by Step 1)

#### Scenario: full-mode regression — unaffected behavior

- **WHEN** a reader diffs the full-mode body (former Step 1 through Step 8, template loading of `templates/plan-template.md`, and the `longrun-reviewer` invocation at the review step) before and after this change
- **THEN** there MUST be no content differences beyond the removal of the GATE block and any header restructuring strictly necessary to make full mode the document's sole entry point

#### Scenario: unrecognized `--mode=mvp` argument no longer triggers a migration notice

- **WHEN** a user runs `/longrun:plan --mode=mvp <任意の引数>` after this change
- **THEN** the skill MUST run the full-mode flow (Step 1 through Step 8) treating `--mode=mvp` as an unrecognized/ignored argument, MUST NOT print a migration notice, and MUST NOT exit early (this is a deliberate, documented behavior change from the prior release — see design.md D4)

### Requirement: `plugins/lr/commands/p.md` MUST drop the `--mode=mvp` migration description while preserving argument passthrough

`plugins/lr/commands/p.md` line ~11 currently describes the now-removed migration-notice behavior ("旧 `--mode=mvp` フラグは skill 側で移行案内を出して終了する"). This sentence MUST be removed since it describes behavior that no longer exists. The command's core contract — that `$ARGUMENTS` is forwarded verbatim to the `longrun:longrun-plan` skill via the Skill tool, and that the Agent tool must not be used — MUST be preserved unchanged.

#### Scenario: migration description removed, passthrough contract intact

- **WHEN** a reader opens `plugins/lr/commands/p.md`
- **THEN** the file MUST NOT contain the string `mode=mvp` anywhere, MUST still instruct forwarding `$ARGUMENTS` to `longrun:longrun-plan` via the Skill tool, and MUST still explicitly forbid using the Agent tool

### Requirement: `commands/plan.md` and `commands/mvp.md` MUST remain free of `--mode=mvp` shim references

`plugins/longrun/commands/plan.md` and `plugins/longrun/commands/mvp.md` were confirmed (at spec-writing time) to already contain zero `mode=mvp` references — they are pure Skill-tool delegation wrappers. This change does not require edits to these two files, but their shim-free state MUST be preserved (i.e. no regression that reintroduces `--mode=mvp` handling text into these wrapper commands).

#### Scenario: plan.md wrapper stays shim-free

- **WHEN** a reader greps `plugins/longrun/commands/plan.md` for `mode=mvp`
- **THEN** there MUST be zero matches, and the file MUST still instruct Skill-tool delegation to `longrun:longrun-plan` with `$ARGUMENTS` forwarded

#### Scenario: mvp.md wrapper stays shim-free

- **WHEN** a reader greps `plugins/longrun/commands/mvp.md` for `mode=mvp`
- **THEN** there MUST be zero matches, and the file MUST still instruct Skill-tool delegation to `longrun:longrun-mvp-plan` with `$ARGUMENTS` forwarded

### Requirement: Scoped residual-reference check MUST pass for both "longrun-orchestrator" and "mode=mvp" (acceptance criterion 9)

Plan.md acceptance criterion 9 requires `grep -rn "longrun-orchestrator" plugins/` and `grep -rn "mode=mvp" plugins/longrun/ plugins/lr/` to return zero matches. Because pre-existing regression tests under `plugins/longrun/tests/*.bats` necessarily embed these exact literal strings as their own search patterns (to verify the strings' absence elsewhere), a literal unscoped zero is unachievable without deleting those tests — which config.yaml rules forbid. This capability therefore defines the achievable, intentional scope: production surfaces (agents/, commands/, skills/, README.md, CHANGELOG.md, plugin.json) MUST have zero occurrences of both strings; only files under `plugins/longrun/tests/` MAY retain them as self-referential test search patterns.

#### Scenario: scoped-zero for "longrun-orchestrator"

- **WHEN** a reader runs `grep -rln "longrun-orchestrator" plugins/ | grep -v '/tests/'`
- **THEN** the output MUST be empty (zero matching files outside `plugins/longrun/tests/`)

#### Scenario: scoped-zero for "mode=mvp"

- **WHEN** a reader runs `grep -rln "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'`
- **THEN** the output MUST be empty (zero matching files outside `plugins/longrun/tests/`)

#### Scenario: residual test-file occurrences are documented, not silently ignored

- **WHEN** a reader reads `_longruns/2026-07-03_plugin-review-fixes/decisions.md` (or the equivalent run-scoped decision log) after this change lands
- **THEN** it MUST contain a note explaining that `grep -rn "longrun-orchestrator" plugins/` and `grep -rn "mode=mvp" plugins/longrun/ plugins/lr/` (unscoped, matching acceptance criterion 9's literal wording) still return matches confined to `plugins/longrun/tests/*.bats` self-referential search patterns, and that this is the intended, reviewed final state

