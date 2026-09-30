## MODIFIED Requirements

### Requirement: SKILL.md version frontmatter and personal path references MUST be removed/synced

`skills/infra-setup/SKILL.md` の frontmatter は `version` を持ってはならない（issue #447 で `plugins/infra/.claude-plugin/plugin.json` から `version` を撤去したため、写す元の値が無い）。また個人環境固有のディレクトリパス（`/Users/oratta/Dropbox/...`）への参照を含んではならない。This requirement MUST be satisfied.

#### Scenario: SKILL.md has no version frontmatter

- **WHEN** `skills/infra-setup/SKILL.md` の frontmatter を読む
- **THEN** `version:` の行が無い

#### Scenario: No personal Dropbox path remains

- **WHEN** `grep -rn "/Users/oratta" plugins/infra/` を実行する
- **THEN** 一致件数は 0 件でなければならない

## REMOVED Requirements

### Requirement: infra plugin.json version MUST be bumped for this change
**Reason**: issue #447 で plugin.json から `version` を撤去し、版は commit SHA から決まるようになった
**Migration**: 版は上げない。`plugins/infra/tests/infra-fixes.bats` の S31 は削除する
