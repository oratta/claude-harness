# longrun-mvp-plan-skill Specification

## Purpose
TBD - created by archiving change mvp-plan-split. Update Purpose after archive.
## Requirements
### Requirement: Standalone MVP plan skill MUST exist with noun-form naming

The longrun plugin SHALL provide a standalone skill at `plugins/longrun/skills/longrun-mvp-plan/SKILL.md` whose YAML frontmatter `name:` field is `longrun-mvp-plan`. The skill name MUST be noun-form and MUST NOT end in `-er` or `-or` (those suffixes are reserved for Agents per the longrun naming convention). The skill MUST be registered in the `skills` array of `plugins/longrun/.claude-plugin/plugin.json` as `./skills/longrun-mvp-plan`.

#### Scenario: Skill directory and frontmatter

- **WHEN** a reader opens `plugins/longrun/skills/longrun-mvp-plan/SKILL.md`
- **THEN** the file MUST exist with valid YAML frontmatter containing `name: longrun-mvp-plan`, a non-empty `description`, a `version` field, and an `allowed-tools` list that includes at minimum `Read`, `Write`, `Grep`, `AskUserQuestion`, and the Agent tool capability needed for subagent dispatch

#### Scenario: plugin.json registration

- **WHEN** a reader reads the `skills` array of `plugins/longrun/.claude-plugin/plugin.json`
- **THEN** the array MUST contain `./skills/longrun-mvp-plan` in addition to the existing skill entries

#### Scenario: Noun-form naming is respected

- **WHEN** the skill name is checked against the longrun naming convention
- **THEN** the name `longrun-mvp-plan` MUST NOT end in `-er` or `-or`, and no file named `longrun-mvp-planner` SHALL exist under `plugins/longrun/skills/`

### Requirement: `/longrun:mvp` command MUST delegate to the skill via Skill tool

The longrun plugin SHALL provide a command file `plugins/longrun/commands/mvp.md` that instructs Claude to invoke the `longrun:longrun-mvp-plan` skill via the Skill tool with `$ARGUMENTS` passed through. The command body MUST explicitly forbid launching the skill via the Agent tool (to prevent the known `Agent type not found` misfire pattern). The command MUST be registered in the `commands` array of `plugins/longrun/.claude-plugin/plugin.json`.

#### Scenario: Command file content

- **WHEN** a reader opens `plugins/longrun/commands/mvp.md`
- **THEN** the body MUST state that the Skill tool is used to invoke `longrun:longrun-mvp-plan` with `$ARGUMENTS`, and MUST contain an explicit statement that the Agent tool is not to be used

#### Scenario: Command registration

- **WHEN** a reader reads the `commands` array of `plugins/longrun/.claude-plugin/plugin.json`
- **THEN** the array MUST contain `./commands/mvp.md`

#### Scenario: No Agent-tool misfire

- **WHEN** a user runs `/longrun:mvp <任意の引数>`
- **THEN** Claude MUST start the `longrun-mvp-plan` skill via the Skill tool, and no `Agent type 'longrun:longrun-mvp-plan' not found` error SHALL occur

### Requirement: `/lr:m` shortcut command MUST exist

The lr plugin SHALL provide a shortcut command file `plugins/lr/commands/m.md` that delegates to the `longrun:longrun-mvp-plan` skill via the Skill tool with `$ARGUMENTS` passed through, following the same delegation pattern as the existing `/lr:p`. The command MUST be registered in the `commands` array of `plugins/lr/.claude-plugin/plugin.json`.

#### Scenario: Shortcut file content

- **WHEN** a reader opens `plugins/lr/commands/m.md`
- **THEN** the body MUST instruct Skill-tool delegation to `longrun:longrun-mvp-plan` with `$ARGUMENTS` forwarded, and MUST state that the Agent tool is not to be used

#### Scenario: Shortcut registration

- **WHEN** a reader reads the `commands` array of `plugins/lr/.claude-plugin/plugin.json`
- **THEN** the array MUST contain `./commands/m.md`

### Requirement: Skill MUST preserve the existing MVP flow without logic changes

The `longrun-mvp-plan` skill SHALL implement the same MVP flow previously embedded in the `longrun-plan` SKILL.md MVP-mode section, restated as self-contained steps: lightweight template loading (`templates/plan-template-mvp.md`) → Brain Dump collection → Gap Analysis → Interview (AskUserQuestion, one question at a time) → parallel research (Step 4.5 equivalent) → lightweight Synthesis with the `<!-- mvp-mode -->` marker → remaining-steps declaration → lightweight Validation → parallel review → human handoff. The flow MUST NOT include Build Contract review, TDD enforcement, Verifier auto-invocation, OpenSpec backlog reconciliation, or OpenSpec change generation. Orchestration MUST remain Agent-tool based (multiple tool_use entries in a single message for parallelism); the skill MUST NOT use the Workflow tool.

#### Scenario: Flow completion produces an MVP plan

- **WHEN** a user runs `/longrun:mvp <brain dump>` (or `/lr:m <brain dump>`) and completes the interview and review steps
- **THEN** the skill MUST produce `_longruns/YYYY-MM-DD_slug/plan.md` following `templates/plan-template-mvp.md`, identical in artifact format to what the former `/longrun:plan --mode=mvp` flow produced

#### Scenario: Full-mode-only steps are absent

- **WHEN** a reader scans `plugins/longrun/skills/longrun-mvp-plan/SKILL.md`
- **THEN** the body MUST NOT instruct the executor to read `openspec/backlog.md`, reconcile existing OpenSpec changes, invoke the `longrun-reviewer` Agent, or load the full template `templates/plan-template.md`

#### Scenario: Orchestration stays Agent-parallel

- **WHEN** a reader scans the skill body for orchestration instructions
- **THEN** subagent dispatch MUST be specified via the Agent tool (with single-message multi-tool_use for parallel calls), and no instruction to use the Workflow tool SHALL appear

### Requirement: Skill MUST invoke the longrun-mvp-research subagent before Synthesis

After the Interview step and before Synthesis, the skill SHALL invoke the `longrun-mvp-research` subagent via the Agent tool. The step body MUST name `longrun-mvp-research` literally and MUST include a prompt template instructing the subagent to output a single report containing both `## 類似サービス事例` and `## 実装パターン` sections plus a trailing `## Search Audit` block, with no duplicate queries. The step MUST state that the invocation uses the single-message multi-tool_use pattern to keep the door open for future parallel research expansion.

#### Scenario: Research step names the agent

- **WHEN** an executor reads the research step in `plugins/longrun/skills/longrun-mvp-plan/SKILL.md`
- **THEN** the literal string `longrun-mvp-research` MUST appear as the subagent target of an Agent tool invocation

#### Scenario: Prompt template demands dual sections and Search Audit

- **WHEN** an executor reads the prompt template inside the research step
- **THEN** the prompt MUST instruct the subagent to include both `## 類似サービス事例` and `## 実装パターン` in one report and to append `## Search Audit` with the query count

### Requirement: Skill MUST invoke the two MVP reviewers in parallel within a single message

The review step SHALL invoke `longrun-mvp-plan-reviewer` and `longrun-mvp-bestpractice-reviewer` via the Agent tool as two tool_use entries inside a single assistant message. The skill MUST explicitly state that issuing the two calls in separate messages is forbidden (parallelism would be lost). After both reviewers respond, the skill SHALL aggregate the results, run up to two review rounds on REQUEST_CHANGES, record unresolved findings in the plan.md レビュー結果サマリ section, and proceed to handoff.

#### Scenario: Both reviewers named

- **WHEN** an executor reads the review step
- **THEN** both literal strings `longrun-mvp-plan-reviewer` and `longrun-mvp-bestpractice-reviewer` MUST appear, each as the subagent target of an Agent tool invocation

#### Scenario: Parallel invocation is explicit

- **WHEN** an executor reads the surrounding prose of the review step
- **THEN** the text MUST require both Agent tool calls to be issued within one assistant message (multiple tool_use entries) and MUST NOT instruct waiting for the first reviewer before invoking the second

### Requirement: Generated plan.md MUST begin with the `<!-- mvp-mode -->` marker

The Synthesis step SHALL embed the literal HTML comment `<!-- mvp-mode -->` as the first content of the generated plan.md, before any heading. This preserves the existing discriminant consumed by `/longrun:archive` (which skips OpenSpec change generation for marker-bearing plans); the archive-side branching is out of scope for this capability and MUST keep working unchanged against plans generated by this skill.

#### Scenario: Marker is the first content

- **WHEN** the skill generates `_longruns/<dir>/plan.md`
- **THEN** the file MUST contain the literal HTML comment `<!-- mvp-mode -->` at the top, before the first heading

#### Scenario: Archive compatibility is preserved

- **WHEN** `/longrun:archive` is invoked against a directory whose plan.md was generated by `longrun-mvp-plan`
- **THEN** the existing marker detection MUST trigger the MVP branch (OpenSpec change archival skipped, longrun directory archived only), with no archive-side modification required by this change

### Requirement: Skill MUST perform lightweight Validation against the seven required sections

Before saving the generated plan.md, the skill SHALL validate the existence of the seven required sections defined by the lightweight template: ゴール, 技術要件, スコープ, 受け入れ条件, 動作確認方法, 調査結果サマリ, レビュー結果サマリ. The skill MUST also verify the presence of the `<!-- mvp-mode -->` marker at the file head. Validation MUST NOT be skipped; if any item is missing, the skill MUST instruct repair of the plan.md before saving.

#### Scenario: Checklist is explicit

- **WHEN** an executor reads the Validation step
- **THEN** the seven section names MUST appear as an explicit checklist (one bullet each) plus a marker-existence check

#### Scenario: Missing section blocks save

- **WHEN** Validation finds any of the seven sections missing
- **THEN** the skill MUST instruct the executor to fix the plan.md before saving (GATE semantics; no save with missing sections)

### Requirement: Handoff step MUST omit OpenSpec writes and announce the human-implementation path

The final step SHALL NOT modify `openspec/backlog.md` and SHALL NOT trigger any OpenSpec change-creation workflow. It SHALL ask the user for final confirmation and then output a handoff message naming the saved plan.md path, describing the human-implementation path, optionally mentioning `/longrun:exec`, and pointing to `/longrun:archive` marker-based archival.

#### Scenario: No backlog or change writes

- **WHEN** an executor reads the handoff step
- **THEN** the body MUST NOT contain any instruction to edit `openspec/backlog.md` or to invoke OpenSpec change-creation tooling

#### Scenario: Handoff message present

- **WHEN** the flow reaches the handoff step after user confirmation
- **THEN** the skill MUST output a handoff message that names the saved plan.md path and presents the human-implementation guidance

### Requirement: MVP agents and lightweight template MUST be attributed to this skill

The three MVP agents (`plugins/longrun/agents/longrun-mvp-research.md`, `longrun-mvp-plan-reviewer.md`, `longrun-mvp-bestpractice-reviewer.md`) and the lightweight template (`plugins/longrun/templates/plan-template-mvp.md`) SHALL be documented as belonging to the `longrun-mvp-plan` skill. Their file locations MUST remain unchanged (plugin-level `agents/` and `templates/` directories), but any prose inside them that names the invoker as `/longrun:plan --mode=mvp` or "longrun:plan の MVP モード" MUST be updated to reference the `longrun-mvp-plan` skill / `/longrun:mvp` command. The template MUST keep its `<!-- mvp-mode -->` first line, its divergence-prevention HTML comment (sync rule with `plan-template.md`), and its section structure unchanged; only the 生成情報 mode notation changes from `--mode=mvp` to `/longrun:mvp`.

#### Scenario: Agent prose references the new owner

- **WHEN** a reader greps the three MVP agent .md files for `--mode=mvp`
- **THEN** zero matches MUST be found, and each agent's invoker description MUST reference the `longrun-mvp-plan` skill or the `/longrun:mvp` command instead

#### Scenario: Template structure is intact

- **WHEN** a reader opens `plugins/longrun/templates/plan-template-mvp.md`
- **THEN** the file MUST still begin with `<!-- mvp-mode -->`, still contain the divergence-prevention comment referencing `plan-template.md`, and still contain all eight H2 sections (ゴール, 技術要件, スコープ, 調査結果サマリ（類似サービス）, 調査結果サマリ（実装パターン）, レビュー結果サマリ, 受け入れ条件, 動作確認方法), while its 生成情報 mode line references `/longrun:mvp` rather than `--mode=mvp`

#### Scenario: Agent contracts are unchanged

- **WHEN** the three MVP agent .md files are diffed before and after this change
- **THEN** only invoker-attribution prose (description / 呼び出し元 passages) MAY differ; the output contracts (report sections, Search Audit, APPROVE/REQUEST_CHANGES format, search caps) MUST be textually unchanged

### Requirement: Methodology source MUST be self-contained without runtime dependency on longrun-plan

The Gap Analysis and Interview methodology used by `longrun-mvp-plan` SHALL be available to the skill without reading `plugins/longrun/skills/longrun-plan/SKILL.md` at runtime. This MUST be satisfied by either (a) a shared reference document under `plugins/longrun/` (e.g., a `references/` file) that both `longrun-plan` and `longrun-mvp-plan` instruct executors to Read, or (b) an inline copy of the methodology in the new SKILL.md when the shared prose is small (implementation-time decision). If option (a) is chosen, both skills MUST point to the same reference file; if option (b) is chosen, both copies MUST carry a divergence-prevention comment naming the counterpart location.

#### Scenario: No cross-skill SKILL.md read

- **WHEN** a reader scans `plugins/longrun/skills/longrun-mvp-plan/SKILL.md` for Read instructions
- **THEN** no instruction SHALL direct the executor to read `skills/longrun-plan/SKILL.md`

#### Scenario: Shared reference or guarded duplication

- **WHEN** the implementation is inspected for how Gap Analysis / Interview methodology is provided
- **THEN** either a shared reference document under `plugins/longrun/` MUST be Read by both skills, or each inline copy MUST contain a divergence-prevention comment naming the counterpart file to update in sync

### Requirement: Plugin versions MUST be synchronized at 6.1.0 across all three locations

After this change is delivered, the longrun plugin version MUST be `6.1.0` and the lr plugin version MUST be `6.1.0`, with each version synchronized across its three locations: the plugin's `.claude-plugin/plugin.json` `version`, the matching entry in the repository-root `.claude-plugin/marketplace.json` `plugins[]` array, and the marketplace.json top-level `version` (which MUST be bumped relative to its previous value). Additionally, the `version` frontmatter of `plugins/longrun/skills/longrun-mvp-plan/SKILL.md` and `plugins/longrun/skills/longrun-plan/SKILL.md` MUST equal the longrun plugin.json version.

#### Scenario: longrun version sync

- **WHEN** a reader compares `plugins/longrun/.claude-plugin/plugin.json` with the `longrun` entry in `.claude-plugin/marketplace.json` `plugins[]`
- **THEN** both MUST read `6.1.0`, and the SKILL.md frontmatter versions of `longrun-plan` and `longrun-mvp-plan` MUST also read `6.1.0`

#### Scenario: lr version sync

- **WHEN** a reader compares `plugins/lr/.claude-plugin/plugin.json` with the `lr` entry in `.claude-plugin/marketplace.json` `plugins[]`
- **THEN** both MUST read `6.1.0`

#### Scenario: Marketplace top-level bump

- **WHEN** a reader reads the top-level `version` of `.claude-plugin/marketplace.json`
- **THEN** the value MUST be strictly greater than the value recorded before this change was applied

