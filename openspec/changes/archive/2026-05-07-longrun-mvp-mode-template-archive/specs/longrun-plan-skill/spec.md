## ADDED Requirements

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
