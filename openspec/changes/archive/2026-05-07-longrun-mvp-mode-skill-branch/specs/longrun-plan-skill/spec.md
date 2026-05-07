## ADDED Requirements

### Requirement: SKILL.md MUST dispatch on a `--mode=mvp` flag at the top of its execution flow

The `longrun-plan` Skill (defined in `plugins/longrun/skills/longrun-plan/SKILL.md`) SHALL inspect its invocation arguments before executing any of the existing Step 1〜Step 8 logic and route control based on the presence of `--mode=mvp`. When the flag is absent, or when `--mode=full` is provided explicitly, the Skill SHALL execute the existing full-mode flow (Step 1 〜 Step 8) without any behavioral change. When `--mode=mvp` is provided, the Skill SHALL transfer control to the MVP-mode section instead. The dispatching block MUST be placed immediately after the YAML frontmatter and before the existing Step 1 GATE, so the existing body remains textually untouched.

#### Scenario: Full-mode invocation without flag

- **WHEN** a user runs `/longrun:plan` with no `--mode` flag
- **THEN** the Skill MUST proceed to execute Step 1 〜 Step 8 exactly as defined in the existing body, including reading `templates/plan-template.md` (the full template) and invoking the `longrun-reviewer` Agent at Step 7

#### Scenario: Explicit full-mode invocation

- **WHEN** a user runs `/longrun:plan --mode=full <args>`
- **THEN** the Skill MUST treat this identically to the no-flag case and execute Step 1 〜 Step 8 with no MVP-mode side effects

#### Scenario: MVP-mode dispatch

- **WHEN** a user runs `/longrun:plan --mode=mvp <args>`
- **THEN** the Skill MUST jump to the MVP-mode section and MUST NOT execute the full-mode Step 1 (full template loading), Step 2 (OpenSpec backlog reconciliation), Step 5b (backlog adoption), or full-mode Step 7 (longrun-reviewer invocation)

#### Scenario: Existing Step 1〜8 body is unchanged

- **WHEN** a reviewer compares the SKILL.md body before and after this change with `git diff`
- **THEN** no edits SHALL appear inside the existing Step 1 〜 Step 8 sections; only additions are permitted, in the form of (a) a new dispatch section above Step 1 and (b) a new MVP-mode section appended after Step 8

### Requirement: MVP mode MUST define a Step-by-Step mapping of full-mode steps

The MVP-mode section in SKILL.md SHALL include a mapping table (Markdown table form) that lists every existing full-mode step and classifies its MVP-mode treatment as one of three values: REUSE, REPLACE, or SKIP. The mapping MUST cover Step 1, Step 2, Step 2b, Step 3, Step 4, Step 5, Step 5a, Step 5b, Step 6, Step 7, Step 8, and the new Step 4.5. The body of each REPLACE or new step MUST contain prose detail sufficient for an executor to perform the action without consulting the original full-mode prose.

#### Scenario: Mapping table is present and complete

- **WHEN** a reader scans the MVP-mode section
- **THEN** a Markdown table MUST be present with columns identifying the existing step, its MVP treatment (REUSE / REPLACE / SKIP), and a short description, and the rows MUST cover Step 1 through Step 8 plus the new Step 4.5

#### Scenario: Skipped steps justification

- **WHEN** Step 2 and Step 5b are listed as SKIP
- **THEN** the table or surrounding prose MUST state the rationale (no OpenSpec backlog reconciliation needed because MVP plans are human-implemented and bypass OpenSpec change generation)

### Requirement: MVP mode MUST introduce a parallel-research Step 4.5 that invokes the `longrun-mvp-research` subagent

After Step 4 (Interview) and before MVP Step 5 (Synthesis), the MVP-mode section SHALL define a new Step 4.5 that invokes the `longrun-mvp-research` subagent via the Agent tool. The invocation pattern MUST use the Agent tool form (single tool_use entry; the section MUST also state that future expansion to multiple parallel research subagents is supported via multiple tool_use entries in a single message). The Step 4.5 description MUST include the agent name (`longrun-mvp-research`) and a representative prompt template that asks for a single report containing both the `## 類似サービス事例` and `## 実装パターン` sections plus the trailing `## Search Audit` block.

#### Scenario: Step 4.5 specifies the agent name

- **WHEN** an executor reads Step 4.5
- **THEN** the literal string `longrun-mvp-research` MUST appear in the step body, identifying the subagent that the Agent tool call targets

#### Scenario: Step 4.5 prompt template references the dual-section output

- **WHEN** an executor reads the prompt template inside Step 4.5
- **THEN** the prompt MUST instruct the subagent to output both `## 類似サービス事例` and `## 実装パターン` in a single report and to append the `## Search Audit` section

### Requirement: MVP mode Step 7 MUST invoke plan-reviewer and bestpractice-reviewer subagents in parallel

The MVP-mode replacement of Step 7 SHALL invoke `longrun-mvp-plan-reviewer` and `longrun-mvp-bestpractice-reviewer` subagents via the Agent tool, with the two invocations placed inside a single assistant message as two distinct tool_use entries (parallel execution pattern). The section MUST explicitly state that the two invocations are placed in one message to achieve parallelism, and MUST NOT instruct the executor to call them sequentially in separate messages. After the two reviewers respond, the MVP-mode flow SHALL aggregate their results and proceed to MVP Step 8.

#### Scenario: Two reviewer agents named in Step 7

- **WHEN** an executor reads MVP-mode Step 7
- **THEN** both literal strings `longrun-mvp-plan-reviewer` and `longrun-mvp-bestpractice-reviewer` MUST appear in the body, each as the `subagent_type` of an Agent tool invocation

#### Scenario: Parallel invocation is explicit

- **WHEN** an executor reads the surrounding prose
- **THEN** the section MUST state that both Agent tool calls MUST be issued within a single assistant message (multiple tool_use entries) to run in parallel, and MUST NOT instruct the executor to wait for the first reviewer before invoking the second

#### Scenario: Full-mode Step 7 path remains the longrun-reviewer

- **WHEN** the SKILL.md is executed in full mode (no `--mode=mvp` flag)
- **THEN** the existing Step 7 body MUST still call the `longrun-reviewer` Agent and MUST NOT call the MVP reviewers

### Requirement: MVP mode Step 5 MUST embed the `<!-- mvp-mode -->` marker in the generated plan.md

When MVP mode synthesizes the plan.md (replacement of Step 5), the generated file SHALL begin with an HTML comment marker `<!-- mvp-mode -->` placed before any other content. This marker is the discriminant used by the `/longrun:archive` command (delivered in change-C) to skip OpenSpec change generation. Full-mode plan.md MUST NOT include this marker.

#### Scenario: Marker is the first line content

- **WHEN** MVP mode generates `_longruns/<dir>/plan.md`
- **THEN** the file MUST contain the literal HTML comment `<!-- mvp-mode -->` at or near the top, before the first heading

#### Scenario: Full mode does not embed the marker

- **WHEN** full-mode Synthesis (existing Step 5) generates `_longruns/<dir>/plan.md`
- **THEN** the literal string `<!-- mvp-mode -->` MUST NOT appear anywhere in the generated file

### Requirement: MVP mode MUST replace Step 6 Validation with a lightweight checklist

The MVP-mode replacement of Step 6 SHALL define a lightweight Validation checklist that targets the lightweight template `templates/plan-template-mvp.md` (delivered in change-C). The checklist MUST cover the existence of these required sections in the generated plan.md: ゴール, 技術要件, スコープ, 受け入れ条件, 動作確認方法, 調査結果サマリ, レビュー結果サマリ. Validation MUST NOT be skipped in MVP mode; it MUST be performed against the lightweight section list rather than the full-mode list.

#### Scenario: Lightweight checklist present

- **WHEN** an executor reads MVP-mode Step 6
- **THEN** the seven required section names listed above MUST appear as an explicit checklist (each as its own bullet) so an executor can mark each as present/absent

#### Scenario: Validation is mandatory in MVP mode

- **WHEN** Step 6 finds any of the seven sections missing in the generated plan.md
- **THEN** the SKILL MUST instruct the executor to repair the plan.md before saving, mirroring the GATE semantics of full-mode Step 6 (no save with missing sections)

### Requirement: MVP mode Step 8 MUST omit OpenSpec backlog reconciliation and recommend human handoff

The MVP-mode replacement of Step 8 SHALL NOT modify `openspec/backlog.md` and SHALL NOT instruct the executor to run any OpenSpec change-creation workflow. Instead it SHALL announce completion of plan generation and present a handoff message describing the human-implementation path (and optionally `/longrun:exec` for those who choose to delegate). The MVP-mode flow ends at this announcement.

#### Scenario: No backlog write in Step 8

- **WHEN** an executor reads MVP-mode Step 8
- **THEN** the body MUST NOT contain any instruction to edit `openspec/backlog.md`, and MUST NOT contain any instruction to invoke `openspec change add` or equivalent change-creation tooling

#### Scenario: Handoff message present

- **WHEN** MVP mode reaches Step 8
- **THEN** the body MUST output a handoff message naming the saved plan.md path and inviting the human to either implement directly or invoke `/longrun:exec`
