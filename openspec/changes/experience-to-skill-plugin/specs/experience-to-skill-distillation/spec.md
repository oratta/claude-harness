## ADDED Requirements

### Requirement: `/e2s:reflect` MUST analyze verified tag intervals to propose skill candidates

The `/e2s:reflect` slash command SHALL accept an optional tag range argument and produce a list of candidate skills derived from commits and session logs in that range. The default behavior (no argument) MUST analyze the most recent `verified/...verified/HEAD` interval. An explicit range like `verified/A..verified/B` MUST analyze commits between those tags. The analysis MUST integrate three data sources: (1) commit subjects, bodies, and diffs in the range, (2) Session jsonl content referenced by `Prompted-by` trailers, (3) file-change patterns across commits in the range.

#### Scenario: Default reflect after a verified checkpoint

- **WHEN** the user runs `/e2s:reflect` with no arguments and the most recent verified tag is `verified/20260414-1530-infra-phase5`
- **THEN** the command MUST analyze commits from `verified/20260414-1530-infra-phase5..HEAD` and present skill candidates

#### Scenario: Explicit range

- **WHEN** the user runs `/e2s:reflect verified/A..verified/B`
- **THEN** the command MUST analyze only commits in that range and produce candidates

#### Scenario: Range has no commits

- **WHEN** the user runs `/e2s:reflect` but the specified range contains zero commits
- **THEN** the command MUST report the empty range and exit without error

### Requirement: Skill candidates MUST include trigger, steps, rationale, and source traceability

Each skill candidate proposed by `/e2s:reflect` SHALL include: (1) a proposed kebab-case name, (2) a one-line description suitable for a Skill tool description field, (3) trigger phrases or conditions derived from the analyzed user prompts, (4) a step-by-step procedure derived from the commit sequence, (5) rationale explaining why this pattern emerged, (6) source traceability listing the exact commit SHAs and session-id#turn references that contributed.

#### Scenario: Multi-commit pattern yields a skill candidate

- **WHEN** three consecutive commits in the analyzed range all fix similar bugs in a consistent way
- **THEN** the candidate MUST have a trigger describing the bug symptom, steps describing the fix pattern, and source listing all three SHAs

#### Scenario: Source traceability includes both commit and session references

- **WHEN** a candidate is derived from commits with valid Prompted-by trailers
- **THEN** the candidate MUST list each contributing commit's SHA AND the corresponding session-id#turn reference; missing Prompted-by trailers MUST be noted as `session-unavailable`

### Requirement: `/e2s:distill` MUST produce a SKILL.md file from an accepted candidate

The `/e2s:distill <candidate-id>` slash command SHALL take a candidate selected from `/e2s:reflect` output and generate a SKILL.md file. The output file MUST include valid YAML frontmatter with `name`, `description` fields matching the Claude Code skill format, MUST include the skill body with trigger conditions, steps, and guardrails, and MUST include a `## Source` section listing the originating commit SHAs and session references for provenance.

#### Scenario: Accept a candidate and generate SKILL.md

- **WHEN** the user runs `/e2s:distill 1` after reviewing `/e2s:reflect` output
- **THEN** the command MUST generate a SKILL.md file at the output path (see next requirement), with valid frontmatter and source traceability

#### Scenario: Invalid candidate id

- **WHEN** the user runs `/e2s:distill 99` but only 3 candidates were proposed
- **THEN** the command MUST report the invalid id and exit without creating any file

### Requirement: Distilled SKILL.md output MUST be placed in a dedicated directory separate from the canonical skill-creator output

Distilled SKILL.md files SHALL be placed under `.claude/skills/distilled/<skill-name>/SKILL.md` relative to the current working directory's root (project-level) OR `~/.claude/skills/distilled/<skill-name>/SKILL.md` (user-level) depending on user choice presented by the command. This path MUST NOT conflict with the default `.claude/skills/<skill-name>/` used by `skill-creator`. The directory structure makes the origin explicit for future review.

#### Scenario: Distill to project-local skills

- **WHEN** the user chooses project-local placement for a distilled skill named `verify-infra-setup`
- **THEN** the file MUST be created at `<project-root>/.claude/skills/distilled/verify-infra-setup/SKILL.md`

#### Scenario: Distill to user-global skills

- **WHEN** the user chooses user-global placement
- **THEN** the file MUST be created at `~/.claude/skills/distilled/<skill-name>/SKILL.md`

#### Scenario: Target directory already exists

- **WHEN** the target `distilled/<skill-name>/` directory already exists with a SKILL.md
- **THEN** the command MUST ask whether to overwrite, append a version suffix, or cancel

### Requirement: Distilled skill names MUST use `e2s-` or `distilled-` prefix to distinguish from skill-creator output

Every distilled SKILL.md's `name` frontmatter field SHALL use either `e2s-<descriptive-name>` or `distilled-<descriptive-name>` prefix. The directory name under `distilled/` MAY use the same prefix or a shorter form, but the `name:` in YAML frontmatter MUST carry the prefix. This prevents naming collisions with `skill-creator`-generated skills and makes their origin identifiable in skill listings.

#### Scenario: Generating SKILL.md for infrastructure verification pattern

- **WHEN** `/e2s:distill` produces a SKILL.md for an infrastructure verification pattern
- **THEN** the YAML frontmatter MUST contain `name: e2s-verify-infra-setup` or `name: distilled-verify-infra-setup`

### Requirement: Reflect MUST use session jsonl content only in sanitized form, never including raw prompts in output

When `/e2s:reflect` reads session jsonl to enrich analysis, the command SHALL extract user intent, decision rationale, and tool-call patterns but MUST NOT display raw prompt text in its output or embed raw prompts into distilled SKILL.md content. Any content derived from session jsonl MUST be abstracted into generalized language before presentation to the user or writing to SKILL.md.

#### Scenario: Raw prompt contains PII or secret

- **WHEN** a Prompted-by-referenced session turn contains personal or secret information in the user's original message
- **THEN** `/e2s:reflect` output MUST abstract the intent without displaying the raw text, and `/e2s:distill`-generated SKILL.md MUST NOT contain the raw prompt

#### Scenario: Distilled skill description derived from user prompts

- **WHEN** a skill candidate's description is derived from multiple user prompts
- **THEN** the description MUST be a generalized formulation of the pattern, not a copy of any original prompt

### Requirement: Reflect MUST handle missing or deleted session jsonl gracefully

When a `Prompted-by` trailer in a commit points to a session-id that no longer exists in `~/.claude/projects/<project>/`, the `/e2s:reflect` command SHALL continue analysis using commit content alone and MUST annotate affected candidates with `session-unavailable`. The command MUST NOT error out due to missing jsonl.

#### Scenario: Session jsonl was deleted by user cleanup

- **WHEN** a commit has `Prompted-by: <session-id>#turn-5` but the corresponding jsonl file does not exist
- **THEN** the analysis MUST continue with commit content, and the resulting candidate MUST mark that source with `session-unavailable`

#### Scenario: Project directory location differs from expected

- **WHEN** the `~/.claude/projects/<project-hash>/` directory cannot be resolved for the current working directory
- **THEN** the command MUST fall back to commit-only analysis and report the fallback to the user

### Requirement: Reflect MUST NOT modify git state or commit history

The `/e2s:reflect` command SHALL be read-only with respect to git state. It MUST NOT execute `git commit`, `git rebase`, `git reset`, `git tag`, or any write operation. Analysis MUST use only read operations like `git log`, `git show`, `git diff`.

#### Scenario: Reflect runs during active work

- **WHEN** the user runs `/e2s:reflect` while having uncommitted changes
- **THEN** the command MUST perform the analysis without affecting the working tree or index

### Requirement: Plugin MUST document the distinction from the `skill-creator` plugin in README

The plugin's README SHALL contain an explicit section explaining how `experience-to-skill` differs from the canonical `skill-creator` plugin. The section MUST state: (1) `skill-creator` builds new skills from scratch with explicit design input, (2) `experience-to-skill` distills skills from past work history (commits + sessions), (3) both can coexist without collision due to `distilled/` subdirectory and `e2s-`/`distilled-` name prefixes.

#### Scenario: User encounters the README

- **WHEN** a user opens `plugins/experience-to-skill/README.md`
- **THEN** the README MUST contain a section titled "Relationship to skill-creator" or equivalent that describes the three distinctions above
