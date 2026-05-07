## 1. OpenSpec Documents

- [x] 1.1 Create `openspec/changes/longrun-mvp-mode-subagents/proposal.md` with Why / What Changes / Capabilities / Impact
- [x] 1.2 Create `specs/longrun-mvp-research/spec.md` with frontmatter / one-report-two-sections / Search Audit requirements + scenarios
- [x] 1.3 Create `specs/longrun-mvp-plan-reviewer/spec.md` with frontmatter / generic (no time-window) review / APPROVE-REQUEST_CHANGES output / Search Audit requirements + scenarios
- [x] 1.4 Create `specs/longrun-mvp-bestpractice-reviewer/spec.md` with frontmatter / pitfall surfacing / max-1-search / Search Audit requirements + scenarios
- [x] 1.5 Create `tasks.md` (this file)

## 2. Agent Implementation

- [x] 2.1 Create `plugins/longrun/agents/longrun-mvp-research.md` with frontmatter (`name: longrun-mvp-research`, `tools` including `WebSearch`/`WebFetch`/`Read`/`Grep`/`Glob`/`Bash`) and body documenting: (a) role as MVP-mode parallel research, (b) 1-report-2-sections (`## 類似サービス事例` / `## 実装パターン`) output structure, (c) Search Audit requirement (queries ideally 1), (d) no-duplicate-query rule
- [x] 2.2 Create `plugins/longrun/agents/longrun-mvp-plan-reviewer.md` with frontmatter (`name: longrun-mvp-plan-reviewer`, tools including `WebSearch`) and body documenting: (a) input is v0 plan, (b) three evaluation dimensions (scope sizing / contradictions / verifiable acceptance criteria), (c) generic review (no hardcoded time-window), (d) APPROVE/REQUEST_CHANGES output format, (e) Search Audit with queries <= 1
- [x] 2.3 Create `plugins/longrun/agents/longrun-mvp-bestpractice-reviewer.md` with frontmatter (`name: longrun-mvp-bestpractice-reviewer`, tools including `WebSearch`/`WebFetch`) and body documenting: (a) role as domain-pitfall surfacer, (b) max-1-search constraint with rationale (token explosion prevention), (c) consolidated-query strategy, (d) Search Audit with queries <= 1
- [x] 2.4 Verify all three agent files share the frontmatter shape of `plugins/longrun/agents/longrun-reviewer.md` (keys: `name`, `description`, `tools`, optionally `model` and `permissionMode`)

## 3. Validation

- [x] 3.1 Run `openspec validate longrun-mvp-mode-subagents` and confirm success
- [x] 3.2 Confirm the 3 agent files exist under `plugins/longrun/agents/`
- [x] 3.3 Grep each of the 3 agent bodies for the literal string `## Search Audit` and confirm presence

## 4. Commit

- [x] 4.1 `git add` the new files (proposal.md, 3 spec.md files, tasks.md, 3 agent .md files)
- [x] 4.2 Commit with the prescribed message (`feat(longrun): add MVP mode subagents ...`)
- [x] 4.3 Report the commit hash
