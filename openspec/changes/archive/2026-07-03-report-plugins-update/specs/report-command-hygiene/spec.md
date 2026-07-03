# report-command-hygiene Specification (Delta)

## ADDED Requirements

### Requirement: weekly-report command は存在するパスで SKILL.md を参照する

`plugins/weekly-report/commands/weekly-report.md` は、存在しないパス `.claude/skills/weekly-report/SKILL.md` を参照してはならない (MUST NOT)。`plugins/daily-report/commands/daily-report.md` と同方式の plugin-relative パス `skills/weekly-report/SKILL.md` を参照しなければならない (MUST)。

#### Scenario: 存在しない旧パスへの参照が無い

- **WHEN** `plugins/weekly-report/commands/weekly-report.md` 内で `.claude/skills/weekly-report/SKILL.md` という文字列を grep する
- **THEN** 該当行は 0 件である

#### Scenario: plugin-relative パスで SKILL.md を参照している

- **WHEN** `plugins/weekly-report/commands/weekly-report.md` の本文を読む
- **THEN** `skills/weekly-report/SKILL.md` という plugin-relative なパスで SKILL.md の手順に従う旨が記載されている

### Requirement: daily-report command の frontmatter は実際に使用するツールを宣言する

`plugins/daily-report/commands/daily-report.md` の frontmatter `allowed-tools` は、`skills/daily-report/SKILL.md` Phase 1 が実際に起動する Agent tool_use（`llm-log-compactor` / `voice-compactor` の並列起動）に対応する `Agent` を含まなければならない (MUST)。

#### Scenario: allowed-tools に Agent が含まれる

- **WHEN** `plugins/daily-report/commands/daily-report.md` の frontmatter `allowed-tools` 行を読む
- **THEN** `Agent` がツール一覧に含まれている
