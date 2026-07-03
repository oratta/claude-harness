# longrun-test-suite-alignment Specification

## Purpose
TBD - created by archiving change longrun-v5-cleanup. Update Purpose after archive.
## Requirements
### Requirement: `tests/mvp-plan-split.bats` MUST be updated to assert the shim's absence instead of its presence

`plugins/longrun/tests/mvp-plan-split.bats` currently contains assertions written against the now-removed `--mode=mvp` shim (e.g. `"plan: SKILL.md handles --mode=mvp with migration notice to /longrun:mvp"` at current lines ~333-337, which asserts the GATE block's presence via `grep -q -- '--mode=mvp' "$PLAN_SKILL"`). These MUST be rewritten to assert the shim's absence, consistent with `longrun-orphan-cleanup`'s requirements. The test file MUST NOT be deleted (config.yaml rule: update, don't delete); its verification intent ("the plan skill correctly handles the legacy flag name") MUST be preserved by re-pointing it at the new expected behavior ("the plan skill contains no trace of the legacy flag handling and runs full mode regardless of the flag").

#### Scenario: migration-notice assertions replaced with absence assertions

- **WHEN** a reader reads the test previously named `"plan: SKILL.md handles --mode=mvp with migration notice to /longrun:mvp"` in `plugins/longrun/tests/mvp-plan-split.bats`
- **THEN** it MUST be replaced by a test asserting `plugins/longrun/skills/longrun-plan/SKILL.md` contains zero occurrences of `mode=mvp`, and the companion test `"plan: migration notice instructs no Step 1-8 and no plan.md generation"` MUST be replaced or removed to match (no migration-notice text exists to instruct anything)

#### Scenario: residual scan test upgraded to strict scoped-zero

- **WHEN** a reader reads the test previously named `"residual: --mode=mvp only appears as deprecation/migration prose"` in `plugins/longrun/tests/mvp-plan-split.bats` (current lines ~394-406)
- **THEN** it MUST be replaced by a test asserting `grep -rln "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'` produces empty output (the "must be deprecation prose" tolerance is removed; the new tolerance is "must be confined to `tests/`", per `longrun-orphan-cleanup`'s scoped-zero requirement)

#### Scenario: version assertions match this change's final version

- **WHEN** a reader reads the version-sync tests in `plugins/longrun/tests/mvp-plan-split.bats` (current lines ~276-303, e.g. `"mvp: longrun version 6.2.0 in plugin.json and marketplace plugins[]"`)
- **THEN** the hardcoded version literals MUST be updated to match the version this change actually lands on (per design.md D6), and any assertion comparing `plugin.json` version against `marketplace.json` MUST be removed or adjusted to not require marketplace.json parity (marketplace.json sync is deferred to change-7; see below)

#### Scenario: README-section assertions still pass after the CHANGELOG split

- **WHEN** a reader re-runs the pre-existing README assertions in `plugins/longrun/tests/mvp-plan-split.bats` (e.g. `"readme: MVP section names skill and includes literal /longrun:mvp"`, `"readme: MVP section states generic / short-time human-implemented use case"`)
- **THEN** they MUST still pass against the restructured `README.md` (the MVP section itself is not removed, only its `--mode=mvp` deprecation subsection is; if any assertion specifically depends on deprecation-subsection text, it MUST be updated per the first two scenarios above)

### Requirement: `tests/release-and-readme.bats` version-sync assertions MUST track this change's final version, and MUST NOT require marketplace.json parity mid-change

`plugins/longrun/tests/release-and-readme.bats` hardcodes `"6.2.0"` in its plugin.json and marketplace.json parity assertions (current lines ~34-46). Since this change bumps `plugins/longrun/.claude-plugin/plugin.json`'s version but explicitly does not touch `.claude-plugin/marketplace.json` (deferred to change-7 per design.md D6 and plan.md's dependency note), the marketplace-parity assertions MUST be removed or reworked to not require `plugin.json` and `marketplace.json` to match within this change's own test run. The plugin.json-only version assertion MUST be updated to the new literal value.

#### Scenario: plugin.json version assertion updated

- **WHEN** a reader reads `"plugin.json: longrun version is 6.2.0"` in `plugins/longrun/tests/release-and-readme.bats`
- **THEN** the hardcoded `"6.2.0"` MUST be replaced with the version this change actually lands on (per design.md D6)

#### Scenario: marketplace.json parity assertion deferred, not silently broken

- **WHEN** a reader reads `"marketplace.json: longrun plugins[] entry is 6.2.0"` and `"version 3-way sync: plugin.json == marketplace plugins[] longrun"` in `plugins/longrun/tests/release-and-readme.bats`
- **THEN** these assertions MUST either be removed with a comment explaining that marketplace.json sync is change-7's responsibility, or be rewritten to assert something that holds true mid-change (e.g. `marketplace.json` still parses as valid JSON and still contains a `longrun` entry, without asserting its version value)

#### Scenario: degraded-mode documentation assertions remain valid

- **WHEN** a reader re-runs the degraded-mode README assertions in `plugins/longrun/tests/release-and-readme.bats` (e.g. `"README: has an OpenSpec degraded-mode section"`, `"README: documents activation conditions (NO_CLI/NO_INIT/OK)"`)
- **THEN** they MUST still pass, since the OpenSpec 縮退モード section is current-feature documentation and is not moved to CHANGELOG.md by this change

### Requirement: `tests/legacy-removal.bats` MUST track this change's final version and remain internally consistent with the scoped-zero residual policy

`plugins/longrun/tests/legacy-removal.bats` hardcodes `"6.2.0"` / `"6.1.0"` version-sync assertions (current lines ~93-105) and a description-content assertion that already forbids `--mode=mvp` / `orchestrator` substrings within `plugin.json`'s description field (current line ~54). The version literals MUST be updated to match this change's final version for `longrun` (design.md D6); the `lr` version literal MUST be updated if `lr`'s version is bumped by this change. The existing description-content assertion (line ~54) requires no logical change (a compressed description satisfying `longrun-docs-restructure`'s requirement will naturally satisfy it), but MUST be re-verified to still pass against the new compressed description text.

#### Scenario: legacy-removal.bats version literals updated

- **WHEN** a reader reads `"legacy: longrun version is 6.2.0 in plugin.json and marketplace plugins[]"` and `"legacy: lr version is 6.1.0 in plugin.json and marketplace plugins[] (no bump miss)"` in `plugins/longrun/tests/legacy-removal.bats`
- **THEN** the hardcoded version literals MUST be updated to match this change's final `longrun` and `lr` versions (design.md D6). If these assertions also require marketplace.json parity, they MUST be handled the same way as the corresponding `release-and-readme.bats` scenario (deferred / reworked, not left to fail)

#### Scenario: description-content assertion still passes against the compressed description

- **WHEN** `"legacy: longrun plugin.json description has no orchestrator / status / decisions refs"` (current line ~52-55) is re-run against the compressed `longrun` plugin.json description produced by `longrun-docs-restructure`
- **THEN** it MUST still pass (the compressed description MUST NOT reintroduce `orchestrator`, `/longrun:status`, `/longrun:decisions`, `--mode=mvp`, `v5\.2`, or `SKILL.md インライン`)

### Requirement: The full `plugins/longrun` and `plugins/lr` bats suite MUST pass after this change's edits, with no unmodified pre-existing test broken as a side effect

Beyond the three files explicitly named above, this change's edits (agent prose rewrites, dead-code removal, GATE removal, README/CHANGELOG split, description compression, checkpoint.md reframing, version bumps) MUST NOT break any other pre-existing bats test in `plugins/longrun/tests/` or `plugins/lr/tests/` (if present) that was passing before this change. In particular `exec-workflow.bats`, `exec-step0.bats`, and `verify-loop.bats` are expected to require zero edits (per design.md D5) — if implementation reveals an edit is in fact necessary, it MUST be made following the same "update, don't delete" policy.

#### Scenario: full bats run is clean

- **WHEN** a reader runs `find plugins/longrun plugins/lr -name '*.bats' -print0 | xargs -0 bats` after this change is complete
- **THEN** all tests MUST report PASS (zero failures, zero unexpected skips)

#### Scenario: unmodified test files require no edits, or edits are justified

- **WHEN** a reader diffs `plugins/longrun/tests/exec-workflow.bats`, `plugins/longrun/tests/exec-step0.bats`, and `plugins/longrun/tests/verify-loop.bats` before and after this change
- **THEN** either there is zero diff, or any diff present is accompanied by a note in `decisions.md` explaining what pre-implementation assumption (design.md D5) turned out to be wrong and why the edit was necessary

