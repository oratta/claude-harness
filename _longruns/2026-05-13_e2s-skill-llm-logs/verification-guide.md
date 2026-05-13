# Verification Guide — experience-to-skill-jsonl-refocus (change-A)

各 Scenario のテスト実装・ロジック実装・動作確認・ユーザー確認の進捗トラッカー。

## Requirement: Skill MUST auto-trigger only on skill-creation request phrases

### Scenario: User explicitly requests skill distillation
- [x] テスト実装完了（手動 E2E でカバー、Scenario として spec.md に記載）
- [x] ロジック実装完了（新 SKILL.md description）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: User signals plain work completion
- [x] テスト実装完了（description 文言の grep でカバー）
- [x] ロジック実装完了（新 SKILL.md description）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Archive command completes
- [x] テスト実装完了（description 文言の grep でカバー）
- [x] ロジック実装完了（新 SKILL.md description）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: Plugin MUST expose exactly one slash command e2s-distill

### Scenario: plugin.json lists only e2s-distill
- [x] テスト実装完了（jq 検査）
- [x] ロジック実装完了（plugin.json 更新）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Old command files do not exist
- [x] テスト実装完了（find 検査）
- [x] ロジック実装完了（旧ファイル削除）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: jsonl-finder script MUST normalize cwd to encoded directory name

### Scenario: Standard cwd is encoded
- [x] テスト実装完了（tests/jsonl-finder.bats）
- [x] ロジック実装完了（scripts/jsonl-finder.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Cwd contains a dotted directory
- [x] テスト実装完了（tests/jsonl-finder.bats）
- [x] ロジック実装完了（scripts/jsonl-finder.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Worktree-style cwd is encoded
- [x] テスト実装完了（tests/jsonl-finder.bats）
- [x] ロジック実装完了（scripts/jsonl-finder.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: jsonl-finder script MUST provide reverse-lookup fallback

### Scenario: Primary encoded directory exists
- [x] テスト実装完了（tests/jsonl-finder.bats）
- [x] ロジック実装完了（scripts/jsonl-finder.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Primary encoded directory does not exist, prefix candidates exist
- [x] テスト実装完了（tests/jsonl-finder.bats）
- [x] ロジック実装完了（scripts/jsonl-finder.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: jsonl-finder script MUST apply four-stage scan order

### Scenario: Directory missing short-circuits
- [x] テスト実装完了（tests/jsonl-finder.bats）
- [x] ロジック実装完了（scripts/jsonl-finder.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Size filter excludes large files
- [x] テスト実装完了（tests/jsonl-finder.bats）
- [x] ロジック実装完了（scripts/jsonl-finder.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: sanitize script MUST redact known secret patterns

### Scenario: OpenAI API key is redacted
- [x] テスト実装完了（tests/sanitize.bats）
- [x] ロジック実装完了（scripts/sanitize.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Anthropic API key is redacted
- [x] テスト実装完了（tests/sanitize.bats）
- [x] ロジック実装完了（scripts/sanitize.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Email address is redacted
- [x] テスト実装完了（tests/sanitize.bats）
- [x] ロジック実装完了（scripts/sanitize.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Non-secret text is preserved
- [x] テスト実装完了（tests/sanitize.bats）
- [x] ロジック実装完了（scripts/sanitize.sh）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: New SKILL.md MUST document Layer 2 LLM semantic review

### Scenario: SKILL.md mentions Layer 2 review
- [x] テスト実装完了（grep 検査）
- [x] ロジック実装完了（新 SKILL.md）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: e2s-distill command MUST be a single conversational entry point

### Scenario: Command file exists and uses skill chaining
- [x] テスト実装完了（ls 検査）
- [x] ロジック実装完了（commands/e2s-distill.md）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Command does not reference removed reflect candidates file
- [x] テスト実装完了（grep 検査）
- [x] ロジック実装完了（commands/e2s-distill.md）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: Generated SKILL.md MUST use e2s- or distilled- prefix

### Scenario: Command file documents the prefix rule
- [x] テスト実装完了（grep 検査）
- [x] ロジック実装完了（commands/e2s-distill.md）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: Plugin MUST NOT contain old e2s command files or skill

### Scenario: No old command files remain
- [x] テスト実装完了（find 検査）
- [x] ロジック実装完了（旧ファイル削除）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: No old commands referenced in repository
- [x] テスト実装完了（grep 検査、許可リストは decisions.md）
- [x] ロジック実装完了（参照修正）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: Bats tests MUST cover shell helper functions

### Scenario: Bats test files exist
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Bats tests pass
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: Test fixture jsonl MUST be sanitized

### Scenario: Fixture file exists
- [x] テスト実装完了（ls 検査）
- [x] ロジック実装完了（fixture 作成）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: Fixture does not contain known secrets
- [x] テスト実装完了（idempotent 検査）
- [x] ロジック実装完了（fixture が事前にサニタイズ済み）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

## Requirement: plugin.json and marketplace.json versions MUST be bumped consistently

### Scenario: plugin.json version bumped
- [x] テスト実装完了（jq 検査）
- [x] ロジック実装完了（plugin.json 更新）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

### Scenario: marketplace.json version synced
- [x] テスト実装完了（jq 検査）
- [x] ロジック実装完了（marketplace.json 更新）
- [ ] 動作確認完了
- [x] ユーザー確認完了 (2026-05-13 user OK)

---

注: 動作確認完了 / ユーザー確認完了 は worktree マージ後の Verify フェーズで orchestrator が更新する。本 builder は「テスト実装完了」「ロジック実装完了」までを担当範囲とする。
