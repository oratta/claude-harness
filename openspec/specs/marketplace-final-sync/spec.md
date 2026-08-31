# marketplace-final-sync Specification

## Purpose
TBD - created by archiving change repo-cleanup-final. Update Purpose after archive.
## Requirements
### Requirement: 全編集プラグインの plugin.json version bump を確認する

本 run（change-1〜7）で編集した全プラグイン（infra / longrun / lr / worktree / daily-report / weekly-report / skill-pack / experience-to-skill）について、`plugins/<name>/.claude-plugin/plugin.json` の `version` が本 run の変更を反映して bump されていることを確認しなければならない（MUST）。（longrun / lr は 2026-08 に解散したため対象外。#205）本 change 自身が編集する skill-pack / experience-to-skill は本 change 内で bump する（MUST）。

#### Scenario: skill-pack / experience-to-skill の version bump

- **WHEN** 本 change が skill-pack と experience-to-skill を編集した後に両者の plugin.json を読む
- **THEN** `plugins/skill-pack/.claude-plugin/plugin.json` と `plugins/experience-to-skill/.claude-plugin/plugin.json` の `version` が編集前より bump されている

#### Scenario: 他 change 編集分の version bump 確認

- **WHEN** infra / longrun / lr / worktree / daily-report / weekly-report の plugin.json を読む
- **THEN** 各 `version` が本 run で編集された変更に対応して bump されている（未 bump のものがあれば本 change で bump を補完する）

### Requirement: marketplace.json を各 plugin.json と完全一致させる

`.claude-plugin/marketplace.json` の各プラグインエントリの `version` と `description` を、対応する `plugins/<name>/.claude-plugin/plugin.json` の値と完全一致させなければならない（MUST）。version は 1 文字も違わず一致すること（MUST）。marketplace.json の同期は全プラグイン編集の完了後に、同一ファイル競合を避けるため本 change が最後に直列で行う（MUST）。change-6 が除去する obsidian-llm-session-rules / skill-aware-workflow のエントリには手を出さない（MUST）。

#### Scenario: version の完全一致

- **WHEN** marketplace.json の各エントリ version と対応 plugin.json の version を比較する
- **THEN** infra / longrun / lr / worktree / daily-report / weekly-report / skill-pack / experience-to-skill の全てで両者が完全一致する（受け入れ条件 15）

#### Scenario: description の同期

- **WHEN** marketplace.json の各エントリ description と対応 plugin.json の description を比較する
- **THEN** 各プラグインで両者が一致する（plugin.json 側を正として同期）

#### Scenario: 廃止 2 プラグインのエントリに触れない

- **WHEN** 本 change が marketplace.json を編集する
- **THEN** obsidian-llm-session-rules / skill-aware-workflow のエントリ除去は change-6 の責務であり、本 change はそれらの version/description を触らない

### Requirement: 受け入れ条件 5-16 の統合検証を実行する

本 change の最後に、受け入れ条件 5-16 の grep / ls 機械検証一式を実行し、全て期待値になることを確認しなければならない（MUST）。worktree マージ後の main 上での再実行（受け入れ条件 4）に備え、各検証コマンドと期待値を `decisions.md` または統合検証ログに残さなければならない（MUST）。

#### Scenario: change-7 固有条件（14/15）の検証

- **WHEN** 統合検証を実行する
- **THEN** `templates/rules/` 不存在・`docs/cooking-mvp-mode-plan.md` 不存在（条件 14）、および全編集プラグインで plugin.json version が marketplace.json と一致（条件 15）が確認される

#### Scenario: 他 change 由来条件（5-13, 16）の横断検証

- **WHEN** 統合検証を実行する
- **THEN** 条件 5（infra secrets 一致）/ 6（Phase 5 旧方式不在）/ 7（build-verify browser-verifier）/ 8（workflow-tool-reference 移動）/ 9（orchestrator/update-checkpoint/mode=mvp ゼロ）/ 10（worktree command ラッパー化）/ 11（weekly-report LLM 参照除去）/ 12（廃止 2 プラグイン不在）/ 13（LLM/ 退避）/ 16（daily/weekly の非対話モード節）の各 grep/ls が期待値になり、逸脱があれば該当 change 担当へ差し戻す

#### Scenario: 全 *.json の parse 検証

- **WHEN** 統合検証の一部として全 JSON の構文を確認する
- **THEN** marketplace.json を含む全 `*.json` が JSON として parse 可能である（受け入れ条件 3 の一部）

