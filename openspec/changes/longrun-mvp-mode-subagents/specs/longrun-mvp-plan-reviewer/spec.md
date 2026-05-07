## ADDED Requirements

### Requirement: Plan reviewer subagent MUST be defined as a Markdown agent with proper frontmatter

The `longrun-mvp-plan-reviewer` subagent SHALL be defined in `plugins/longrun/agents/longrun-mvp-plan-reviewer.md` using the same frontmatter structure as existing `longrun-reviewer.md`. The frontmatter MUST include `name`, `description`, and `tools`. The `name` value MUST be `longrun-mvp-plan-reviewer`. The `tools` list MUST include `Read`, `Grep`, `Glob`, `Bash`, plus a web-search-capable tool (`WebSearch`) since up to 1 external search is permitted.

#### Scenario: Frontmatter is parsed by Claude Code

- **WHEN** Claude Code loads `plugins/longrun/agents/longrun-mvp-plan-reviewer.md`
- **THEN** the frontmatter MUST be valid YAML with `name: longrun-mvp-plan-reviewer`, a non-empty `description`, and a `tools` list containing `Read` and `WebSearch`

### Requirement: Plan reviewer MUST evaluate v0 plan generically without time-window assumptions

The agent SHALL receive an initial plan v0 (from the longrun-plan SKILL Step 5 synthesis) as its input and SHALL evaluate three dimensions: (1) whether the scope is excessively large for an MVP, (2) whether internal contradictions exist (e.g., a "not included" item appearing in the included scope), (3) whether the acceptance criteria are objectively verifiable. The agent MUST NOT hard-code any specific time window (e.g., "1時間" / "1 hour" / "30分") as a sizing criterion; it MUST evaluate scope using generic MVP heuristics so that the same agent serves any time-bounded MVP context.

#### Scenario: Plan with vague acceptance criteria

- **WHEN** the v0 plan contains acceptance criteria such as "良い感じに動く" without measurable conditions
- **THEN** the agent MUST flag at least one specific criterion as not verifiable and produce REQUEST_CHANGES with concrete rewrite suggestions

#### Scenario: Plan that explicitly mentions "1 hour" budget

- **WHEN** the input plan mentions a 1-hour implementation budget
- **THEN** the reviewer MUST evaluate scope based on the items listed (Changes / files / acceptance criteria count) rather than treating "1 hour" as a hardcoded threshold, ensuring the agent stays reusable for other time budgets

#### Scenario: Plan with internal contradiction

- **WHEN** the same feature appears in both the "含むもの" (included) and "含まないもの" (excluded) lists, or acceptance criteria reference scope items that were excluded
- **THEN** the agent MUST identify the contradiction explicitly in its output

### Requirement: Plan reviewer MUST output APPROVE or REQUEST_CHANGES with concrete pointers

The agent's output SHALL begin with a status line stating either `APPROVE` or `REQUEST_CHANGES`. When the status is `REQUEST_CHANGES`, the agent MUST list specific issues in a numbered format, each with: a short title, the affected section/item of the plan, the problem in 1–2 sentences, and a single recommended action (no "either A or B" alternatives). When the status is `APPROVE`, the agent MAY include an empty or minimal issues list.

#### Scenario: Approval path

- **WHEN** the v0 plan passes all three evaluation dimensions
- **THEN** the agent's first line MUST contain `APPROVE` and the report MUST NOT list any BLOCKER-level issues

#### Scenario: Request changes path

- **WHEN** at least one BLOCKER issue is found
- **THEN** the agent's first line MUST contain `REQUEST_CHANGES` and each issue MUST include a single recommended action (alternatives MAY be mentioned only as a supplementary note)

### Requirement: Plan reviewer MUST limit external searches to at most one and append a Search Audit section

The agent SHALL issue at most one external search per invocation. At the end of its report the agent MUST append a section titled exactly `## Search Audit`, with two bulleted lines: a `- queries: <0 or 1>` line and a `- list: [<query string>]` line (use `[]` when no search was performed). If no external search was needed, `queries` MUST be `0` and `list` MUST be `[]`. If exactly one search was performed, `queries` MUST be `1` and `list` MUST contain that one query string.

#### Scenario: Review completed without external search

- **WHEN** the agent reviews a plan and concludes that local context is sufficient
- **THEN** the report MUST end with `## Search Audit` containing `queries: 0` and `list: []`

#### Scenario: Review used a single external lookup

- **WHEN** the agent performs one external search to verify a referenced library or pattern
- **THEN** the report MUST end with `## Search Audit` containing `queries: 1` and `list` MUST list that one query string

#### Scenario: Attempted second external search

- **WHEN** the agent considers issuing a second external search
- **THEN** it MUST instead conclude review with what it already has, ensuring `queries` never exceeds 1
