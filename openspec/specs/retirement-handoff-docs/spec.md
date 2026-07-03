# retirement-handoff-docs Specification

## Purpose
TBD - created by archiving change plugin-retirement. Update Purpose after archive.
## Requirements
### Requirement: `openspec/backlog.md`'s naming-refactor item MUST be consolidated

The `## Skill 命名規則リファクタリング` section of `openspec/backlog.md` SHALL be resolved by this change, because all seven of its target skills (`pre-task-orchestrator`, `context-reader`, `execution-tracker`, `session-logger`, `skill-finder`, `skill-proposer`, `task-analyzer`) cease to exist once the plugin-retirement-cleanup capability deletes their parent plugins. The section MUST either be removed in full, or reduced to a single-line note recording that it was resolved by deletion rather than rename — the choice is an implementation-time decision — but in either case the file MUST NOT retain the literal names of the nine retired skills as active backlog content (a single generic reference such as "対象7スキル" is permitted in the residual-note case).

#### Scenario: Section is resolved, not left dangling

- **WHEN** a reader reads `openspec/backlog.md` after this change
- **THEN** the `## Skill 命名規則リファクタリング` section MUST either be absent entirely, or reduced to a single-line resolution note that does not spell out any of the nine retired skill names individually

#### Scenario: No orphaned rename-target table remains

- **WHEN** a reader reads `openspec/backlog.md` after this change
- **THEN** the rename-target table (mapping each of the nine retired skills to a proposed renamed name) MUST NOT be present, since none of the target skills exist to be renamed

### Requirement: `post-merge-steps.md` MUST contain user-facing cleanup instructions

`{longrun-dir}/post-merge-steps.md` SHALL instruct the user to run `/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness`, `/plugin uninstall skill-aware-workflow@oratta-claude-harness`, and `/reload-plugins`, and SHALL instruct the user to remove both plugins' keys from the `enabledPlugins` object of each affected project's `settings.local.json` (referencing the skill-pack plugin's `enabledPlugins`-editing convention).

#### Scenario: Uninstall and reload commands present

- **WHEN** a reader opens `{longrun-dir}/post-merge-steps.md`
- **THEN** it MUST contain the literal commands `/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness`, `/plugin uninstall skill-aware-workflow@oratta-claude-harness`, and `/reload-plugins`

#### Scenario: enabledPlugins cleanup guidance present

- **WHEN** a reader opens `{longrun-dir}/post-merge-steps.md`
- **THEN** it MUST instruct removing both `obsidian-llm-session-rules@oratta-claude-harness` and `skill-aware-workflow@oratta-claude-harness` keys from each affected project's `settings.local.json` `enabledPlugins` object

### Requirement: `post-merge-steps.md` MUST co-locate the LLM/ evacuation report

The evacuation outcome produced by the `llm-log-relocation` capability (collision list or "衝突ゼロ" statement, and any hook-generated post-snapshot files) SHALL appear in the same `post-merge-steps.md` document as the plugin-uninstall instructions, not in a separate untracked note.

#### Scenario: Evacuation report and uninstall instructions share one file

- **WHEN** a reader opens `{longrun-dir}/post-merge-steps.md`
- **THEN** the same file MUST contain both the `/plugin uninstall` instructions and the LLM/ evacuation collision report (or explicit zero-collision statement)

