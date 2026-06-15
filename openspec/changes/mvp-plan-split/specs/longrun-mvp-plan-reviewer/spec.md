# longrun-mvp-plan-reviewer Delta Specification

## MODIFIED Requirements

### Requirement: Plan reviewer MUST evaluate v0 plan generically without time-window assumptions

The agent SHALL receive an initial plan v0 (from the longrun-mvp-plan SKILL Step 5 synthesis) as its input and SHALL evaluate three dimensions: (1) whether the scope is excessively large for an MVP, (2) whether internal contradictions exist (e.g., a "not included" item appearing in the included scope), (3) whether the acceptance criteria are objectively verifiable. The agent MUST NOT hard-code any specific time window (e.g., "1時間" / "1 hour" / "30分") as a sizing criterion; it MUST evaluate scope using generic MVP heuristics so that the same agent serves any time-bounded MVP context.

#### Scenario: Plan with vague acceptance criteria

- **WHEN** the v0 plan contains acceptance criteria such as "良い感じに動く" without measurable conditions
- **THEN** the agent MUST flag at least one specific criterion as not verifiable and produce REQUEST_CHANGES with concrete rewrite suggestions

#### Scenario: Plan that explicitly mentions "1 hour" budget

- **WHEN** the input plan mentions a 1-hour implementation budget
- **THEN** the reviewer MUST evaluate scope based on the items listed (Changes / files / acceptance criteria count) rather than treating "1 hour" as a hardcoded threshold, ensuring the agent stays reusable for other time budgets

#### Scenario: Plan with internal contradiction

- **WHEN** the same feature appears in both the "含むもの" (included) and "含まないもの" (excluded) lists, or acceptance criteria reference scope items that were excluded
- **THEN** the agent MUST identify the contradiction explicitly in its output
