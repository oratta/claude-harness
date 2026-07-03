# plugin-retirement-cleanup Specification

## Purpose
TBD - created by archiving change plugin-retirement. Update Purpose after archive.
## Requirements
### Requirement: Both retired plugin directories MUST be deleted as a git-tracked removal

`plugins/obsidian-llm-session-rules/` and `plugins/skill-aware-workflow/` SHALL be deleted from the repository as a git-tracked removal (recorded in git history, restorable via `git log`/`git checkout`), not left as untracked or ignored artifacts.

#### Scenario: Plugin directories are absent

- **WHEN** a reader lists `plugins/`
- **THEN** `plugins/obsidian-llm-session-rules/` and `plugins/skill-aware-workflow/` MUST NOT exist

#### Scenario: Deletion is git-tracked

- **WHEN** a reader runs `git log --diff-filter=D -- plugins/obsidian-llm-session-rules plugins/skill-aware-workflow`
- **THEN** the deletion of both directories' contents MUST appear as tracked commits (not as an untracked-file removal invisible to git history)

### Requirement: `marketplace.json` `plugins[]` entries for both retired plugins MUST be removed

The `plugins[]` array in `.claude-plugin/marketplace.json` SHALL NOT contain an entry whose `name` is `"obsidian-llm-session-rules"` or `"skill-aware-workflow"`.

#### Scenario: plugins[] array excludes both entries

- **WHEN** a reader parses `.claude-plugin/marketplace.json` and inspects the `plugins[]` array
- **THEN** no entry with `name: "obsidian-llm-session-rules"` or `name: "skill-aware-workflow"` MUST be present

### Requirement: `marketplace.json` `bundles[].all.plugins[]` MUST also drop both retired plugin names

The `plugins[]` list of the bundle named `"all"` inside `.claude-plugin/marketplace.json` `bundles[]` SHALL NOT contain `"obsidian-llm-session-rules"` or `"skill-aware-workflow"`.

#### Scenario: "all" bundle no longer lists retired plugins

- **WHEN** a reader parses the `bundles[]` array entry named `"all"` in `.claude-plugin/marketplace.json`
- **THEN** its `plugins[]` list MUST NOT contain `"obsidian-llm-session-rules"` or `"skill-aware-workflow"`

### Requirement: Entry removal MUST NOT touch version/description synchronization fields

This capability's edits to `.claude-plugin/marketplace.json` SHALL be limited to removing the two retired plugins' array entries (from `plugins[]` and from `bundles[].all.plugins[]`). The top-level `version` field and the `version`/`description` fields of all remaining (non-retired) plugin entries MUST be left textually unchanged by this capability (final version/description synchronization across all edited plugins is out of scope, reserved for a later change).

#### Scenario: Only entry removal appears in the diff

- **WHEN** a reader diffs `.claude-plugin/marketplace.json` before and after this capability's changes
- **THEN** the diff MUST consist only of the removal of the two retired plugins' entries from `plugins[]` and their names from `bundles[].all.plugins[]`; the top-level `version` and the `version`/`description` fields of every remaining plugin entry MUST be identical to their pre-change values

### Requirement: References to both retired plugin names MUST be swept from all non-archival files

No file under `plugins/`, `README.md`, or `docs/` (excluding `openspec/changes/archive/` and `_longruns/`, which are historical and out of scope) SHALL contain the literal string `obsidian-llm-session-rules` or `skill-aware-workflow`.

#### Scenario: Zero plugin-name references outside archive/_longruns

- **WHEN** `grep -rln "obsidian-llm-session-rules\|skill-aware-workflow" plugins/ README.md docs/` is run from the repository root
- **THEN** the result MUST be empty (0 files matched)

### Requirement: References to the nine retired skill names MUST be swept from all non-archival files

No file in the repository (excluding `openspec/changes/archive/` and `_longruns/`) SHALL contain the literal strings `session-logger`, `context-reader`, `research-workflow`, `pre-task-orchestrator`, `task-analyzer`, `skill-inventory`, `skill-finder`, `execution-tracker`, or `skill-proposer`, except where such a string is required as part of this change's own file paths inside `openspec/changes/plugin-retirement/` itself (e.g. this spec file, which necessarily names the retired skills). Illustrative naming-convention examples in documentation (e.g. `CONTRIBUTING.md`'s "bad naming" examples) MUST be replaced with generic names that were never used as a real skill.

#### Scenario: Zero skill-name references outside archive/_longruns/this-change

- **WHEN** `grep -rlnE "session-logger|context-reader|research-workflow|pre-task-orchestrator|task-analyzer|skill-inventory|skill-finder|execution-tracker|skill-proposer" .` is run from the repository root, excluding `openspec/changes/archive/`, `_longruns/`, and `openspec/changes/plugin-retirement/`
- **THEN** the result MUST be empty (0 files matched)

#### Scenario: Illustrative examples use generic names

- **WHEN** a reader reads the "NG パターン" (bad naming pattern) examples in `CONTRIBUTING.md`
- **THEN** the example names MUST NOT include any of the nine retired skill names; they MUST use generic illustrative names not tied to any real, currently or formerly existing skill

### Requirement: Root README.md plugin catalog MUST no longer reference either retired plugin

`README.md` SHALL NOT contain install commands, feature descriptions, or local-development `/plugin add` examples referencing `obsidian-llm-session-rules` or `skill-aware-workflow`.

#### Scenario: Quickstart install commands cleaned

- **WHEN** a reader reads the `## クイックスタート` section of `README.md`
- **THEN** it MUST NOT contain `/plugin install skill-aware-workflow@oratta-claude-harness` or `/plugin install obsidian-llm-session-rules@oratta-claude-harness`

#### Scenario: Plugin catalog sections removed

- **WHEN** a reader reads the `## プラグイン一覧` section of `README.md`
- **THEN** it MUST NOT contain a `### skill-aware-workflow` or `### obsidian-llm-session-rules` subsection

#### Scenario: Local development examples cleaned

- **WHEN** a reader reads the `## ローカル開発` section of `README.md`
- **THEN** it MUST NOT contain `/plugin add ./plugins/skill-aware-workflow` or `/plugin add ./plugins/obsidian-llm-session-rules`

