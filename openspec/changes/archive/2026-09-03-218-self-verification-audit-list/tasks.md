## 1. spec delta

- [x] 1.1 `dev-workflow-shared-references` delta: 対象スキルを 7（`push-guard-setup` 追加）・参照元 8 か所に MODIFIED
- [x] 1.2 `skill-verification-sections` delta: Scenario を 7 ファイルに MODIFIED、「棚卸しリストは実在する全スキルを網羅する」を ADDED

## 2. 棚卸しリスト（正本）

- [x] 2.1 `references/self-verification.md`: 冒頭の件数（6 → 7）と監査日（2026-09）を更新
- [x] 2.2 対象表に `plugins/dev-workflow/skills/push-guard-setup/SKILL.md` を追加
- [x] 2.3 対象外表に `capability-registry`・`discord/access`・`discord/configure`・`telegram/access`・`telegram/configure` を理由付きで追加

## 3. スキル

- [x] 3.1 `skills/push-guard-setup/SKILL.md` の `## 自己検証` 節に共通原則への参照 1 行を追記（既存行は変えない）

## 4. テスト

- [x] 4.1 `self-verification-sections.bats`: TARGETS に push-guard-setup を追加、`_artifact_kw` に `pre-push` を追加、網羅性テスト S51 を追加
- [x] 4.2 `shared-references.bats`: 対象 7・consumers 8 に更新
- [x] 4.3 `bash scripts/test.sh dev-workflow` が緑

## 5. 周辺同期

- [x] 5.1 dev-workflow 2.1.1 → 2.1.2（plugin.json・marketplace.json・CHANGELOG）
