# longrun-plan-skill Specification

## Purpose

longrun プラグインの plan.md 作成 Skill と関連コマンドの命名規則・起動プロトコル・orchestrator のバイアス緩和ガード・プラグインキャッシュ無効化ルールを定義する。
## Requirements
### Requirement: Skill 命名規則の統一

longrun プラグインは Skill と Agent の役割を命名で識別可能にしなければならない (MUST)。Skill は動詞または名詞単独の名前（例: `longrun-plan`, `longrun-orchestrator`）を持ち、Agent は役割を示す `-er` または `-or` で終わる名前（例: `longrun-builder`, `longrun-reviewer`, `longrun-verifier`）を持つこと。これに違反する命名は Skill/Agent 種別の誤認を招く。

#### Scenario: plan Skill の命名

- **WHEN** plan.md を生成する Skill を配置する
- **THEN** Skill ディレクトリは `plugins/longrun/skills/longrun-plan/` であり、SKILL.md の `name:` フィールドは `longrun-plan` でなければならない

#### Scenario: 旧名称の不在

- **WHEN** plugin.json の skills 配列を読む
- **THEN** `./skills/longrun-planner` のパスは存在せず、`./skills/longrun-plan` のみが存在しなければならない

### Requirement: コマンドからの起動プロトコル

`/longrun:plan` および `/lr:p` コマンドは、Claude が `longrun-plan` Skill を Agent として誤起動しないよう、Skill tool 経由での委譲を明示的に指示しなければならない (MUST)。Agent tool での起動を禁止する文言を含むこと。

#### Scenario: longrun:plan コマンドの記述

- **WHEN** `plugins/longrun/commands/plan.md` の本文を読む
- **THEN** 「Skill tool を使って `longrun:longrun-plan` を呼び出す」旨と「Agent tool は使わない」旨が明示的に記載されていなければならない

#### Scenario: lr:p コマンドの記述

- **WHEN** `plugins/lr/commands/p.md` の本文を読む
- **THEN** Skill 名 `longrun:longrun-plan`（旧 `longrun:longrun-planner` ではなく）を参照していなければならない

#### Scenario: 起動時の Agent 誤起動が発生しない

- **WHEN** ユーザーが `/longrun:plan <任意の引数>` を実行する
- **THEN** Claude は Skill tool で `longrun-plan` を起動し、`Agent type 'longrun:longrun-planner' not found` エラーは発生してはならない

### Requirement: orchestrator のバイアス緩和ガード

`longrun-orchestrator` Skill は、`longrun-reviewer` Agent からのレビュー結果を受領するフェーズにおいて、self-preference bias とフィードバック過剰受容バイアスへの対処を明示的に指示しなければならない (MUST)。具体的には、reviewer の指摘を仮説として扱い、(a) spec 違反 / 契約違反 / 事実誤認のいずれかの根拠がある指摘のみ採用する、(b) 嗜好や読みやすさレベルの指摘は plan 意図を優先して反論する、という判定ルールを skill 内に固定文として含むこと。

#### Scenario: orchestrator の reviewer 受領セクション

- **WHEN** `plugins/longrun/skills/longrun-orchestrator/SKILL.md` を読む
- **THEN** reviewer のレビュー結果を扱うセクションに「指摘は仮説として扱う」「明確な根拠（spec違反/契約違反/事実誤認）の有無で採否を判定する」「嗜好レベルの指摘は反論する」という趣旨の文言が含まれていなければならない

#### Scenario: バイアス緩和文の長さ制約

- **WHEN** バイアス緩和プロンプトを SKILL.md に直接埋め込む
- **THEN** 該当ブロックは 50 行以内に収まること。それを超える場合は `references/` 配下の別ファイルに切り出して読み込み参照にしなければならない

### Requirement: プラグインキャッシュ無効化のためのバージョンバンプ

skill ディレクトリ名・SKILL.md の `name:` フィールド・skills 配列のいずれかを変更する場合、`plugins/longrun/.claude-plugin/plugin.json` の `version` を必ず引き上げなければならない (MUST)。バージョンを引き上げないと他プロジェクトのプラグインキャッシュが古いままとなり変更が反映されない。

#### Scenario: スキル名変更時のバージョンバンプ

- **WHEN** longrun プラグインで skill 名・skill ディレクトリ・skills 配列が変更される
- **THEN** `plugin.json` の `version` フィールドが旧バージョンより大きい値（最低でも minor bump）に更新されていなければならない

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

### Requirement: MVP lightweight template MUST exist with mvp-mode marker and divergence-prevention header

The longrun plugin SHALL provide a lightweight plan template at `plugins/longrun/templates/plan-template-mvp.md`. The first content of this file MUST be the literal HTML comment `<!-- mvp-mode -->` (used by the archive command to detect MVP-mode plans), immediately followed by a multi-line HTML comment that states the template is derived from the full version `plan-template.md` and instructs editors to update both files when modifying any of the shared sections (ゴール / 技術要件 / スコープ / 受け入れ条件 / 動作確認方法). The template SHALL include the seven required sections that the SKILL.md MVP-mode Step 6 Validation enumerates: ゴール, 技術要件, スコープ（含むもの / 含まないもの）, 調査結果サマリ（類似サービス）, 調査結果サマリ（実装パターン）, レビュー結果サマリ（plan-reviewer / bestpractice-reviewer）, 受け入れ条件, 動作確認方法. The template SHALL NOT include sections specific to the full-mode autonomous-execution pipeline, namely Changes 分解 (Build Contract decomposition for autonomous execution) and the TDD / build / Verifier-related items inside the standard 必須条件 4 項目.

#### Scenario: Marker is the first content line

- **WHEN** a reader opens `plugins/longrun/templates/plan-template-mvp.md`
- **THEN** the file MUST begin with the literal HTML comment `<!-- mvp-mode -->` before any heading, prose, or other comment

#### Scenario: Divergence-prevention comment is present

- **WHEN** a reader inspects the top of `plugins/longrun/templates/plan-template-mvp.md`
- **THEN** an HTML comment block MUST appear within the first few lines that explicitly states the file is derived from `plan-template.md` and that the shared sections (ゴール / 技術要件 / スコープ / 受け入れ条件 / 動作確認方法) MUST be kept in sync between both templates when edited

#### Scenario: Required sections are present

- **WHEN** a reader scans the headings of `plugins/longrun/templates/plan-template-mvp.md`
- **THEN** all of the following section headings MUST be present at H2 level: ゴール, 技術要件, スコープ, 調査結果サマリ（類似サービス）, 調査結果サマリ（実装パターン）, レビュー結果サマリ, 受け入れ条件, 動作確認方法

#### Scenario: Heavyweight sections are excluded

- **WHEN** a reader scans the headings of `plugins/longrun/templates/plan-template-mvp.md`
- **THEN** the heading `Changes分解` MUST NOT appear, and the 受け入れ条件 section MUST NOT include the autonomous-execution-only required items related to TDD enforcement or Verifier auto-invocation

### Requirement: Archive command MUST branch on the mvp-mode marker

`plugins/longrun/commands/archive.md` SHALL define a discriminator step that inspects the target longrun directory's `plan.md` for the literal HTML comment `<!-- mvp-mode -->`. When the marker is present, the command MUST skip the OpenSpec-change archival step (the existing step that copies delta specs and moves `openspec/changes/<name>` to `openspec/changes/archive/...`) and proceed directly to archive only the longrun directory under `_longruns/_archive/`, then perform the standard worktree cleanup, commit, and completion report. When the marker is absent, the command MUST execute the existing full-mode flow without modification, including OpenSpec-change archival.

#### Scenario: MVP-mode archival skips OpenSpec change moves

- **WHEN** `/longrun:archive` is invoked against a directory whose `plan.md` begins with `<!-- mvp-mode -->`
- **THEN** the command MUST NOT move any directory under `openspec/changes/` to `openspec/changes/archive/`, MUST NOT copy delta specs into `openspec/specs/`, and MUST move only the longrun directory itself into `_longruns/_archive/`

#### Scenario: Full-mode archival is unchanged

- **WHEN** `/longrun:archive` is invoked against a directory whose `plan.md` does not contain the `<!-- mvp-mode -->` marker
- **THEN** the command MUST execute the existing flow: parse Changes 分解 from `plan.md`, archive each OpenSpec change under `openspec/changes/archive/`, copy delta specs into `openspec/specs/` when present, move the longrun directory under `_longruns/_archive/`, clean up worktrees, and create the archive commit

#### Scenario: Marker detection examines the file head

- **WHEN** `/longrun:archive` reads the target `plan.md` for marker detection
- **THEN** the detection MUST be based on the literal substring `<!-- mvp-mode -->` appearing at or near the start of the file (within the first content line) so that ordinary comments later in the document do not falsely trigger the MVP branch

### Requirement: plugin.json and longrun-plan SKILL.md MUST share the same version after MVP-mode delivery

When the MVP-mode feature set (template + archive branch + README update) is added to the longrun plugin, the `version` field in `plugins/longrun/.claude-plugin/plugin.json` and the `version` field in the YAML frontmatter of `plugins/longrun/skills/longrun-plan/SKILL.md` MUST both be updated and MUST hold the same value after the change. This synchronized bump is required so that plugin caches (keyed on plugin.json version) and skill caches (keyed independently) both invalidate together. The new value MUST be a strict increase over the previous `plugin.json` version (no downgrades), and MUST be at least a minor bump.

#### Scenario: Both versions match

- **WHEN** a reader reads `plugins/longrun/.claude-plugin/plugin.json` and `plugins/longrun/skills/longrun-plan/SKILL.md`
- **THEN** the `version` value in plugin.json MUST equal the `version` value in the SKILL.md frontmatter

#### Scenario: plugin.json version is not downgraded

- **WHEN** the version is bumped as part of this change
- **THEN** the new `plugin.json` version MUST be strictly greater than the immediately preceding `plugin.json` version, with at least the minor segment incremented

### Requirement: README MUST document MVP mode usage

`plugins/longrun/README.md` SHALL contain a section that documents the MVP mode entry point, its differences from full mode, and the situations in which it is appropriate to use. The section MUST include the literal command form `/longrun:plan --mode=mvp` (and MAY include the alias `/lr:p --mode=mvp` if the alias plugin is available). The section MUST state that MVP mode is a generic capability not tied to any specific project and is intended for short-time human-implemented MVP scenarios.

#### Scenario: MVP mode section is present

- **WHEN** a reader scans `plugins/longrun/README.md`
- **THEN** a section MUST exist that names MVP mode and includes the literal text `--mode=mvp`

#### Scenario: Differences from full mode are described

- **WHEN** a reader reads the MVP mode section in the README
- **THEN** the section MUST describe at least these differences: Build Contract review is skipped, TDD enforcement is skipped, Verifier auto-invocation is skipped, OpenSpec change archival is skipped on `/longrun:archive`

#### Scenario: Use-case guidance is generic

- **WHEN** a reader reads the MVP mode section in the README
- **THEN** the section MUST state that MVP mode is suitable for short-time human-implemented MVP scenarios and is not specific to any particular project

