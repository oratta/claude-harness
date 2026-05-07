## ADDED Requirements

### Requirement: Best-practice reviewer subagent MUST be defined as a Markdown agent with proper frontmatter

The `longrun-mvp-bestpractice-reviewer` subagent SHALL be defined in `plugins/longrun/agents/longrun-mvp-bestpractice-reviewer.md` using the same frontmatter structure as existing `longrun-reviewer.md`. The frontmatter MUST include `name`, `description`, and `tools`. The `name` value MUST be `longrun-mvp-bestpractice-reviewer`. The `tools` list MUST include `WebSearch` (since the agent's primary value comes from external knowledge), plus `Read`, `Grep`, `Glob`, `Bash`, and `WebFetch` as needed.

#### Scenario: Frontmatter is parsed by Claude Code

- **WHEN** Claude Code loads `plugins/longrun/agents/longrun-mvp-bestpractice-reviewer.md`
- **THEN** the frontmatter MUST be valid YAML with `name: longrun-mvp-bestpractice-reviewer`, a non-empty `description`, and a `tools` list containing `WebSearch`

### Requirement: Best-practice reviewer MUST surface domain pitfalls and anti-patterns

The agent SHALL receive the v0 plan (and optionally the research report) as input and SHALL produce a report that lists relevant domain-specific pitfalls and anti-patterns. Each item MUST include: a short title, a 1–2 sentence description of why it is a pitfall, and a concrete recommendation for the plan (e.g., "Acceptance criterion N should be tightened to ..."). The agent MUST NOT merely list generic best practices unrelated to the plan's domain.

#### Scenario: Plan touches a domain with well-known pitfalls

- **WHEN** the plan involves a domain such as "user input form" where common pitfalls (e.g., missing validation, XSS, untrimmed whitespace) exist
- **THEN** the agent MUST list at least one domain-relevant pitfall with a concrete recommendation tied to a specific section/criterion of the v0 plan

#### Scenario: Plan domain has no notable pitfalls

- **WHEN** the agent cannot identify domain-specific pitfalls after reviewing the plan
- **THEN** the agent MUST explicitly state "該当する重大な anti-pattern は検出されませんでした" or equivalent and proceed to APPROVE, rather than fabricating concerns

### Requirement: Best-practice reviewer MUST cap external searches at one to prevent token explosion

The agent SHALL execute at most ONE external search per invocation. This constraint is non-negotiable and exists specifically to prevent token explosion when running in parallel with other reviewers. The agent body MUST explicitly document this single-search constraint and instruct the LLM to consolidate all external lookups into a single, well-crafted query.

#### Scenario: Reviewer plans multiple lookups

- **WHEN** the agent identifies several pitfall topics it would like to verify externally
- **THEN** the agent MUST consolidate them into one composite query (or pick the highest-value single query) rather than issuing multiple searches

#### Scenario: Reviewer skips external search entirely

- **WHEN** the agent determines its existing knowledge is sufficient
- **THEN** the agent MAY skip external search and report `queries: 0`

### Requirement: Best-practice reviewer MUST append a Search Audit section with queries <= 1

At the end of every report the agent MUST append a section titled exactly `## Search Audit`, with two bulleted lines: a `- queries: <0 or 1>` line and a `- list: [<query string>]` line (use `[]` when no search was performed). The `queries` value MUST satisfy `queries <= 1`. If `queries` is `0`, `list` MUST be `[]`. If `queries` is `1`, `list` MUST contain exactly one query string. Any value greater than `1` is a contract violation and the parent SKILL MUST treat such output as failed.

#### Scenario: One external search was used

- **WHEN** the agent issues one consolidated external search
- **THEN** the report MUST end with `## Search Audit` containing `queries: 1` and `list` MUST contain exactly one query string

#### Scenario: No external search was used

- **WHEN** the agent relied only on internal knowledge
- **THEN** the report MUST end with `## Search Audit` containing `queries: 0` and `list: []`

#### Scenario: Audit format must be machine-checkable

- **WHEN** acceptance criterion #11 of the parent plan greps for `## Search Audit` and parses `queries:`
- **THEN** the format MUST exactly match the bulleted `- queries: <N>` / `- list: [...]` pattern so the verifier can assert `queries <= 1`
