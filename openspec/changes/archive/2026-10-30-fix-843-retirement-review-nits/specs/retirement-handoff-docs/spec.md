## MODIFIED Requirements

### Requirement: `post-merge-steps.md` MUST contain user-facing cleanup instructions

`{longrun-dir}/post-merge-steps.md` SHALL instruct the user to run `/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness`, `/plugin uninstall skill-aware-workflow@oratta-claude-harness`, and `/reload-plugins`, and SHALL instruct the user to remove both plugins' keys from the `enabledPlugins` object of each affected project's `settings.local.json`.

#### Scenario: Uninstall and reload commands present

- **WHEN** a reader opens `{longrun-dir}/post-merge-steps.md`
- **THEN** it MUST contain the literal commands `/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness`, `/plugin uninstall skill-aware-workflow@oratta-claude-harness`, and `/reload-plugins`

#### Scenario: enabledPlugins cleanup guidance present

- **WHEN** a reader opens `{longrun-dir}/post-merge-steps.md`
- **THEN** it MUST instruct removing both `obsidian-llm-session-rules@oratta-claude-harness` and `skill-aware-workflow@oratta-claude-harness` keys from each affected project's `settings.local.json` `enabledPlugins` object
