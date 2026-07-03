## change-3: longrun-v5-cleanup

### S1: [longrun-orphan-cleanup] longrun-verifier context restoration step
- WHEN: a reader opens `plugins/longrun/agents/longrun-verifier.md` and reads its "コンテキスト復元" step (current line ~37)
- THEN: the step MUST list `{longrun-dir}/plan.md` and `{longrun-dir}/decisions.md` as the primary sources of current state, and MUST NOT state that `checkpoint.md` is read to "把握" current status as the first/primary action
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [longrun-orphan-cleanup] longrun-verifier FAIL escalation step
- WHEN: a reader opens `plugins/longrun/agents/longrun-verifier.md` and reads its "FAILの場合" step (current line ~98)
- THEN: the step MUST NOT contain "orchestratorに修正を依頼" and MUST describe returning a structured FAIL result that the generated Workflow script uses to re-invoke `longrun-builder`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [longrun-orphan-cleanup] longrun-browser-verifier context restoration step
- WHEN: a reader opens `plugins/longrun/agents/longrun-browser-verifier.md` and reads its "コンテキスト復元" step (current line ~101)
- THEN: the step MUST list `{longrun-dir}/plan.md` and `{longrun-dir}/decisions.md` as primary sources, MUST NOT prioritize checkpoint.md
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [longrun-orphan-cleanup] longrun-browser-verifier verification-guide.md provenance note
- WHEN: a reader opens `plugins/longrun/agents/longrun-browser-verifier.md` and reads the note about who generates `verification-guide.md` (current line ~151)
- THEN: the note MUST NOT attribute generation to "orchestrator"; MUST attribute it to the Build phase / `longrun-builder`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [longrun-orphan-cleanup] longrun-browser-verifier FAIL escalation step
- WHEN: a reader opens `plugins/longrun/agents/longrun-browser-verifier.md` and reads its "FAILの場合" step (current line ~187)
- THEN: the step MUST NOT contain "orchestratorに修正を依頼"; MUST describe Workflow re-invoking `longrun-builder`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [longrun-orphan-cleanup] longrun-builder description accuracy
- WHEN: a reader reads the `description` field in `plugins/longrun/agents/longrun-builder.md` frontmatter
- THEN: MUST NOT claim "checkpoint.mdを更新する"; MUST describe the TDD implementation + `builder-report` schema contract
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [longrun-orphan-cleanup] exec.md historical note rewritten without the literal compound
- WHEN: a reader greps `plugins/longrun/commands/exec.md` for the exact string `longrun-orchestrator`
- THEN: MUST be zero matches, while the sentence still accurately describes what v6.0.0 removed
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [longrun-orphan-cleanup] dead script removed
- WHEN: a reader checks for the existence of `plugins/longrun/scripts/update-checkpoint.sh`
- THEN: the file MUST NOT exist
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [longrun-orphan-cleanup] no orphaned call sites remain after removal
- WHEN: a reader runs `grep -rn "update-checkpoint.sh" plugins/` after the deletion
- THEN: MUST be zero matches
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [longrun-orphan-cleanup] GATE block removed, full mode starts directly at Step 1
- WHEN: a reader opens `plugins/longrun/skills/longrun-plan/SKILL.md`
- THEN: MUST NOT contain a `--mode=mvp` interception GATE; document begins directly with the full-mode flow
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [longrun-orphan-cleanup] full-mode regression — unaffected behavior
- WHEN: a reader diffs the full-mode body (Step 1〜8, template loading, `longrun-reviewer` invocation) before and after this change
- THEN: MUST be no content differences beyond the GATE removal itself
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [longrun-orphan-cleanup] unrecognized --mode=mvp argument no longer triggers a migration notice
- WHEN: a user runs `/longrun:plan --mode=mvp <任意の引数>` after this change
- THEN: MUST run full-mode flow treating the flag as unrecognized/ignored; MUST NOT print a migration notice or exit early
- [ ] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [longrun-orphan-cleanup] migration description removed, passthrough contract intact (lr p.md)
- WHEN: a reader opens `plugins/lr/commands/p.md`
- THEN: MUST NOT contain the string `mode=mvp`; MUST still forward `$ARGUMENTS` and forbid the Agent tool
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [longrun-orphan-cleanup] plan.md wrapper stays shim-free
- WHEN: a reader greps `plugins/longrun/commands/plan.md` for `mode=mvp`
- THEN: MUST be zero matches; MUST still instruct Skill-tool delegation with `$ARGUMENTS`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [longrun-orphan-cleanup] mvp.md wrapper stays shim-free
- WHEN: a reader greps `plugins/longrun/commands/mvp.md` for `mode=mvp`
- THEN: MUST be zero matches; MUST still instruct Skill-tool delegation with `$ARGUMENTS`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [longrun-orphan-cleanup] scoped-zero for "longrun-orchestrator"
- WHEN: a reader runs `grep -rln "longrun-orchestrator" plugins/ | grep -v '/tests/'`
- THEN: output MUST be empty
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [longrun-orphan-cleanup] scoped-zero for "mode=mvp"
- WHEN: a reader runs `grep -rln "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'`
- THEN: output MUST be empty
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [longrun-orphan-cleanup] residual test-file occurrences are documented, not silently ignored
- WHEN: a reader reads the run's `decisions.md` after this change lands
- THEN: MUST contain a note explaining the unscoped grep still matches only `plugins/longrun/tests/*.bats`, and that this is intended/reviewed
- [ ] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [longrun-docs-restructure] CHANGELOG.md exists and contains full historical record
- WHEN: a reader opens `plugins/longrun/CHANGELOG.md`
- THEN: MUST exist with entries for at least v4.0 through the version immediately preceding this change's own bump
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [longrun-docs-restructure] README.md no longer contains version-history blocks
- WHEN: a reader greps `plugins/longrun/README.md` for `^## v[0-9]+\.[0-9]+ 変更点`
- THEN: MUST be zero matches
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [longrun-docs-restructure] README.md links to CHANGELOG.md
- WHEN: a reader reads the top of `plugins/longrun/README.md`
- THEN: MUST contain a reference pointing to `CHANGELOG.md`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S22: [longrun-docs-restructure] current-feature sections survive the restructure unchanged in substance
- WHEN: a reader compares コマンド表/アーキテクチャ/命名規則/MVPプランモード(minus deprecation subsection)/OpenSpec縮退モード before and after
- THEN: substantive content MUST be unchanged; only position/surrounding content differs
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S23: [longrun-docs-restructure] deprecation subsection removed from README's current MVP section
- WHEN: a reader reads the "MVP プランモード（/longrun:mvp）" section of `README.md` after this change
- THEN: MUST NOT contain a `--mode=mvp` deprecation subsection or the literal string `mode=mvp`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S24: [longrun-docs-restructure] longrun plugin.json description is compressed
- WHEN: a reader reads `.description` from `plugins/longrun/.claude-plugin/plugin.json` via `jq -r .description`
- THEN: at most 2 occurrences of `。`, at most 200 characters, still mentions autonomous execution harness
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S25: [longrun-docs-restructure] lr plugin.json description is compressed while preserving shortcut-command discoverability
- WHEN: a reader reads `.description` from `plugins/lr/.claude-plugin/plugin.json`
- THEN: at most 2 occurrences of `。`, at most 200 characters, still mentions `/lr:m`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S26: [longrun-docs-restructure] checkpoint.md reframed as optional/foldable
- WHEN: a reader reads the checkpoint.md section of `plugins/longrun/commands/exec.md` after this change
- THEN: MUST state checkpoint.md is optional and MAY be integrated into decisions.md; MUST NOT imply every run requires a standalone checkpoint.md
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S27: [longrun-docs-restructure] no-machine-parse prohibition preserved
- WHEN: a reader greps `plugins/longrun/commands/exec.md` for `checkpoint.md を grep/sed` or `パースして制御フロー`
- THEN: at least one match MUST exist
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S28: [longrun-docs-restructure] workflow-runs.jsonl / resumeFromRunId flow is untouched
- WHEN: a reader diffs exec.md's Step 4 (runId 記録) and Step 5 (中断→再開) sections before and after this change
- THEN: MUST be zero content differences
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S29: [longrun-test-suite-alignment] migration-notice assertions replaced with absence assertions
- WHEN: a reader reads the former `"plan: SKILL.md handles --mode=mvp with migration notice to /longrun:mvp"` test in `mvp-plan-split.bats`
- THEN: MUST be replaced by a test asserting zero `mode=mvp` occurrences in `longrun-plan/SKILL.md`; companion migration-instruction test replaced/removed to match
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S30: [longrun-test-suite-alignment] residual scan test upgraded to strict scoped-zero
- WHEN: a reader reads the former `"residual: --mode=mvp only appears as deprecation/migration prose"` test
- THEN: MUST be replaced by an assertion that `grep -rln "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'` is empty
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S31: [longrun-test-suite-alignment] version assertions match this change's final version (mvp-plan-split.bats)
- WHEN: a reader reads the version-sync tests in `mvp-plan-split.bats`
- THEN: hardcoded literals MUST match this change's final version; marketplace.json parity assertions removed or relaxed
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S32: [longrun-test-suite-alignment] README-section assertions still pass after the CHANGELOG split
- WHEN: a reader re-runs the pre-existing README assertions in `mvp-plan-split.bats`
- THEN: MUST still pass against restructured README.md; deprecation-subsection-dependent assertions updated
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S33: [longrun-test-suite-alignment] plugin.json version assertion updated (release-and-readme.bats)
- WHEN: a reader reads `"plugin.json: longrun version is 6.2.0"` in `release-and-readme.bats`
- THEN: hardcoded `"6.2.0"` MUST be replaced with this change's final version
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S34: [longrun-test-suite-alignment] marketplace.json parity assertion deferred, not silently broken
- WHEN: a reader reads the marketplace.json parity assertions in `release-and-readme.bats`
- THEN: MUST be removed with explanatory comment, or rewritten to not assert version equality
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S35: [longrun-test-suite-alignment] degraded-mode documentation assertions remain valid
- WHEN: a reader re-runs the degraded-mode README assertions in `release-and-readme.bats`
- THEN: MUST still pass unchanged
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S36: [longrun-test-suite-alignment] legacy-removal.bats version literals updated
- WHEN: a reader reads the longrun/lr version-sync tests in `legacy-removal.bats`
- THEN: hardcoded literals MUST match this change's final versions; marketplace parity handled per S34's policy
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S37: [longrun-test-suite-alignment] description-content assertion still passes against the compressed description
- WHEN: `"legacy: longrun plugin.json description has no orchestrator / status / decisions refs"` is re-run against the compressed description
- THEN: MUST still pass
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S38: [longrun-test-suite-alignment] full bats run is clean
- WHEN: a reader runs `find plugins/longrun plugins/lr -name '*.bats' -print0 | xargs -0 bats` after this change
- THEN: all tests MUST report PASS
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S39: [longrun-test-suite-alignment] unmodified test files require no edits, or edits are justified
- WHEN: a reader diffs `exec-workflow.bats` / `exec-step0.bats` / `verify-loop.bats` before and after this change
- THEN: zero diff, or a diff justified by a decisions.md note
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了
