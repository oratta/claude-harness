# longrun-mvp-research Specification

## Purpose
TBD - created by archiving change longrun-mvp-mode-subagents. Update Purpose after archive.
## Requirements
### Requirement: Research subagent MUST be defined as a Markdown agent with proper frontmatter

The `longrun-mvp-research` subagent SHALL be defined in `plugins/longrun/agents/longrun-mvp-research.md` using the same frontmatter structure as existing `longrun-reviewer.md`. The frontmatter MUST include the keys `name`, `description`, and `tools`. The `name` value MUST be `longrun-mvp-research`. The `tools` list MUST include at minimum a tool capable of external web search (e.g., `WebSearch`) and a fetcher (e.g., `WebFetch`), plus `Read`, `Grep`, `Glob`, `Bash` for local introspection. The agent body MUST be Markdown explaining the role, output structure, and Search Audit requirement.

#### Scenario: Frontmatter is parsed by Claude Code

- **WHEN** Claude Code loads `plugins/longrun/agents/longrun-mvp-research.md`
- **THEN** the frontmatter MUST be valid YAML with `name: longrun-mvp-research`, a non-empty `description`, and a `tools` list that contains both a web-search-capable tool and `Read`

#### Scenario: Agent body documents role and output contract

- **WHEN** a developer reads the agent body section
- **THEN** the document MUST describe (1) that this agent performs MVP-mode parallel research, (2) the required output structure (2 sections in 1 report), (3) the Search Audit requirement, and (4) the no-duplicate-query rule

### Requirement: Research subagent MUST output one report containing two sections

When invoked, the agent SHALL produce a single Markdown report containing exactly two top-level sections: `## 類似サービス事例` and `## 実装パターン`. Both sections MUST be derived from the same research effort (same set of queries) so as to avoid duplicate external lookups. The agent MUST NOT split itself into two separate reports.

#### Scenario: Standard research invocation produces unified report

- **WHEN** the longrun-plan SKILL invokes the agent with a topic such as "1時間で作る料理レシピ提案ツール"
- **THEN** the agent's output MUST contain both `## 類似サービス事例` and `## 実装パターン` as headings within the same report, populated with content distilled from a shared search session

#### Scenario: Section is missing

- **WHEN** the agent finds no useful results for one of the two angles
- **THEN** the corresponding section MUST still be present and explicitly state "該当なし" or equivalent, rather than being omitted from the report

### Requirement: Research subagent MUST minimize external queries and append a Search Audit section

The agent SHALL execute external search at most once per invocation (ideal) and MUST NOT issue duplicate queries (same query string, same target). At the end of every report the agent MUST append a section titled exactly `## Search Audit`, formatted as a bulleted list with two keys: a `- queries: <N>` line where N is the integer number of distinct external search calls, and a `- list: [<query strings>]` line. The `queries` count MUST equal the length of `list` and MUST be `1` in normal operation (the design contract). If the agent legitimately found a single search insufficient and issued a follow-up, `queries` MAY be greater than 1 but MUST still be auditable via `list`.

#### Scenario: Single-search ideal path

- **WHEN** the agent completes a normal MVP research request
- **THEN** the report MUST end with a `## Search Audit` section where `queries: 1` and `list` contains exactly one query string used to populate both `## 類似サービス事例` and `## 実装パターン`

#### Scenario: Duplicate query attempt

- **WHEN** the agent considers issuing a query whose string already appears in the in-flight Search Audit list
- **THEN** the agent MUST skip the duplicate and reuse cached results from the prior call, ensuring `list` never contains duplicate entries

#### Scenario: Audit format is machine-checkable

- **WHEN** an external verifier greps the report for `## Search Audit` and parses `queries:` / `list:` lines
- **THEN** both keys MUST be present in the specified format (`- queries: <N>` / `- list: [...]`) so the count of queries can be validated against acceptance criteria #6 of the parent plan

