# longrun-mvp-research Delta Specification

## MODIFIED Requirements

### Requirement: Research subagent MUST output one report containing two sections

When invoked, the agent SHALL produce a single Markdown report containing exactly two top-level sections: `## 類似サービス事例` and `## 実装パターン`. Both sections MUST be derived from the same research effort (same set of queries) so as to avoid duplicate external lookups. The agent MUST NOT split itself into two separate reports.

#### Scenario: Standard research invocation produces unified report

- **WHEN** the longrun-mvp-plan SKILL invokes the agent with a topic such as "1時間で作る料理レシピ提案ツール"
- **THEN** the agent's output MUST contain both `## 類似サービス事例` and `## 実装パターン` as headings within the same report, populated with content distilled from a shared search session

#### Scenario: Section is missing

- **WHEN** the agent finds no useful results for one of the two angles
- **THEN** the corresponding section MUST still be present and explicitly state "該当なし" or equivalent, rather than being omitted from the report
