## MODIFIED Requirements

### Requirement: marketplace.json を各 plugin.json と完全一致させる

`.claude-plugin/marketplace.json` の各プラグインエントリの `description` を、対応する `plugins/<name>/.claude-plugin/plugin.json` の値と完全一致させなければならない（MUST）。`version` は issue #447 で両方から撤去したため照合の対象にしない（両方に存在しないことは capability `marketplace-plugin-sync` が検査する）。marketplace.json の同期は全プラグイン編集の完了後に、同一ファイル競合を避けるため本 change が最後に直列で行う（MUST）。change-6 が除去する obsidian-llm-session-rules / skill-aware-workflow のエントリには手を出さない（MUST）。

#### Scenario: description の同期

- **WHEN** marketplace.json の各エントリ description と対応 plugin.json の description を比較する
- **THEN** 各プラグインで両者が一致する（plugin.json 側を正として同期）

#### Scenario: 廃止 2 プラグインのエントリに触れない

- **WHEN** 本 change が marketplace.json を編集する
- **THEN** obsidian-llm-session-rules / skill-aware-workflow のエントリ除去は change-6 の責務であり、本 change はそれらの description を触らない

### Requirement: 受け入れ条件 5-16 の統合検証を実行する

本 change の最後に、受け入れ条件 5-16 の grep / ls 機械検証一式を実行し、全て期待値になることを確認しなければならない（MUST）。worktree マージ後の main 上での再実行（受け入れ条件 4）に備え、各検証コマンドと期待値を `decisions.md` または統合検証ログに残さなければならない（MUST）。

#### Scenario: change-7 固有条件（14/15）の検証

- **WHEN** 統合検証を実行する
- **THEN** `templates/rules/` 不存在・`docs/cooking-mvp-mode-plan.md` 不存在（条件 14）が確認される（条件 15 の plugin.json と marketplace.json の version 一致は、issue #447 で version を撤去したため対象外）

#### Scenario: 他 change 由来条件（5-13, 16）の横断検証

- **WHEN** 統合検証を実行する
- **THEN** 条件 5（infra secrets 一致）/ 6（Phase 5 旧方式不在）/ 7（build-verify browser-verifier）/ 8（workflow-tool-reference 移動）/ 9（orchestrator/update-checkpoint/mode=mvp ゼロ）/ 10（worktree command ラッパー化）/ 11（weekly-report LLM 参照除去）/ 12（廃止 2 プラグイン不在）/ 13（LLM/ 退避）/ 16（daily/weekly の非対話モード節）の各 grep/ls が期待値になり、逸脱があれば該当 change 担当へ差し戻す

#### Scenario: 全 *.json の parse 検証

- **WHEN** 統合検証の一部として全 JSON の構文を確認する
- **THEN** marketplace.json を含む全 `*.json` が JSON として parse 可能である（受け入れ条件 3 の一部）

## REMOVED Requirements

### Requirement: 全編集プラグインの plugin.json version bump を確認する
**Reason**: issue #447 で plugin.json から `version` を撤去し、版は commit SHA から決まるようになった
**Migration**: 版は上げない。変更の記録は `plugins/<name>/changes/<番号>.md` に書く（capability `plugin-release-convention`）
