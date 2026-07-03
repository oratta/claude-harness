# longrun-docs-restructure Delta Specification

## ADDED Requirements

### Requirement: Version history MUST be split out of README.md into a new CHANGELOG.md

`plugins/longrun/README.md` currently interleaves ~80 lines of version history (v6.2 down through v4.0, current lines ~5-85) with current-version documentation (command table, architecture, naming convention, MVP mode, degraded mode). A new file `plugins/longrun/CHANGELOG.md` MUST be created containing the full historical record (all version entries currently in README.md, verbatim in content though phrasing MAY be adjusted per the literal-string constraints below). `README.md` MUST retain only current-version-facing content: a brief current-version summary, the command table, the architecture diagram, the naming convention section, the MVP plan mode section, and the OpenSpec degraded mode section. `README.md` MUST link to `CHANGELOG.md` for historical detail.

#### Scenario: CHANGELOG.md exists and contains full historical record

- **WHEN** a reader opens `plugins/longrun/CHANGELOG.md`
- **THEN** the file MUST exist and MUST contain entries for at least v4.0 through the version immediately preceding this change's own version bump (i.e. no version entry is dropped in the migration)

#### Scenario: README.md no longer contains version-history blocks

- **WHEN** a reader greps `plugins/longrun/README.md` for heading patterns matching `^## v[0-9]+\.[0-9]+ 変更点`
- **THEN** there MUST be zero matches (all "変更点" version blocks have moved to CHANGELOG.md)

#### Scenario: README.md links to CHANGELOG.md

- **WHEN** a reader reads the top of `plugins/longrun/README.md`
- **THEN** it MUST contain a reference (e.g. a markdown link or explicit filename mention) pointing readers to `CHANGELOG.md` for version history

#### Scenario: current-feature sections survive the restructure unchanged in substance

- **WHEN** a reader compares the "コマンド" table, "アーキテクチャ" diagram, "命名規則" section, "MVP プランモード" section (minus the `--mode=mvp` deprecation subsection per the next requirement), and "OpenSpec 縮退モード" section before and after this change
- **THEN** their substantive content (table rows, diagram structure, documented behavior) MUST be unchanged — only their position in the file and surrounding version-history content may differ

### Requirement: README.md's current MVP-mode documentation MUST NOT retain the `--mode=mvp` deprecation subsection

`plugins/longrun/README.md`'s "MVP プランモード（/longrun:mvp）" section (current lines ~133-174) contains a subsection `### --mode=mvp は廃止（deprecation）` (current lines ~144-146) documenting the now-fully-removed migration-notice behavior (see `longrun-orphan-cleanup` capability). Since the shim itself no longer exists, this subsection MUST be removed from README's current-feature documentation. A brief historical mention MAY remain in `CHANGELOG.md` (per that file's historical nature) but MUST follow the literal-string constraint defined in `longrun-orphan-cleanup`'s residual-reference requirement (no literal `mode=mvp` substring in production prose).

#### Scenario: deprecation subsection removed from README's current MVP section

- **WHEN** a reader reads the "MVP プランモード（/longrun:mvp）" section of `plugins/longrun/README.md` after this change
- **THEN** it MUST NOT contain a subsection documenting `--mode=mvp` deprecation behavior, and MUST NOT contain the literal string `mode=mvp` anywhere within that section

### Requirement: `plugin.json` descriptions for both `longrun` and `lr` MUST be compressed to 1-2 sentences

`plugins/longrun/.claude-plugin/plugin.json`'s `description` field is currently approximately 600 characters across many clauses. `plugins/lr/.claude-plugin/plugin.json`'s `description` is 3 sentences. Both MUST be compressed to at most 2 sentences (at most 2 occurrences of the Japanese full stop `。`), each MUST stay under 200 characters, while still conveying what the plugin does at a glance (marketplace listing readability). Detailed mechanism descriptions (schema enforcement, budget guards, model-tier resolution, etc.) MUST be removed from the description field — that level of detail belongs in README.md, not the marketplace-facing description.

#### Scenario: longrun plugin.json description is compressed

- **WHEN** a reader reads `.description` from `plugins/longrun/.claude-plugin/plugin.json` via `jq -r .description`
- **THEN** the string MUST contain at most 2 occurrences of `。`, MUST be at most 200 characters long, and MUST still mention that this is an autonomous execution / longrun harness for Claude Code

#### Scenario: lr plugin.json description is compressed while preserving shortcut-command discoverability

- **WHEN** a reader reads `.description` from `plugins/lr/.claude-plugin/plugin.json` via `jq -r .description`
- **THEN** the string MUST contain at most 2 occurrences of `。`, MUST be at most 200 characters long, and MUST still mention `/lr:m` (preserving the existing `mvp-plan-split.bats` assertion "lr plugin.json description mentions /lr:m")

### Requirement: `commands/exec.md`'s checkpoint.md section MUST frame the file as an optional human memo foldable into decisions.md

`plugins/longrun/commands/exec.md`'s `## checkpoint.md（人間向け監査ログ）` section (current lines ~262-271) MUST be rewritten to state that checkpoint.md is an optional human-facing memo whose content MAY be folded into `decisions.md` instead of maintained as a separate file, rather than being framed as a file the run is expected to always produce. The existing prohibition against machine-parsing checkpoint.md for control flow (current lines ~243-244, ~265-267: "いかなるコードパスも checkpoint.md を grep/sed/正規表現でパースして制御フローを決めてはならない") MUST be preserved verbatim or near-verbatim, since `tests/exec-workflow.bats` asserts on this exact phrasing.

#### Scenario: checkpoint.md reframed as optional/foldable

- **WHEN** a reader reads the checkpoint.md section of `plugins/longrun/commands/exec.md` after this change
- **THEN** it MUST state that checkpoint.md is optional and MAY be integrated into decisions.md, and MUST NOT state or imply that every run is required to produce a standalone checkpoint.md file

#### Scenario: no-machine-parse prohibition preserved

- **WHEN** a reader greps `plugins/longrun/commands/exec.md` for the phrase `checkpoint.md を grep/sed` or `パースして制御フロー`
- **THEN** at least one match MUST exist (the prohibition against parsing checkpoint.md for control flow is not removed)

#### Scenario: workflow-runs.jsonl / resumeFromRunId flow is untouched

- **WHEN** a reader diffs `plugins/longrun/commands/exec.md`'s "Step 4: runId 記録" (current lines ~218-225) and "Step 5: 中断 → 再開（resumeFromRunId 一次手段）" (current lines ~241-259) sections before and after this change
- **THEN** there MUST be zero content differences (these sections are out of scope for this change; only the checkpoint.md section itself is rewritten)
