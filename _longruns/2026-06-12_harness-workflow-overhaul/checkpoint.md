---
phase: Build
status: in_progress
last_updated: 2026-06-12T13:45:00
---

# Checkpoint — harness 大型改修 run

longrun-dir: `_longruns/2026-06-12_harness-workflow-overhaul/`

## ツール検証結果

実行コマンドと出力（2026-06-12 11:09 実施）:

- openspec: `/Users/oratta/.volta/bin/openspec` (v1.2.0) ← `which openspec` の実出力
- npx openspec: v0.23.0 ← `npx --no-install openspec --version` の実出力
  - **注意**: volta グローバル (1.2.0) と npx ローカル (0.23.0) でバージョンが乖離。plan.md は `npx openspec` を参照しているため、change-1 の実機検証でどちらを正とするか確定すること
- git: 2.40.1 on branch `longrun-workflow-setup`（worktree: `~/.superset/worktrees/ef0031fc-.../longrun-workflow-setup`）
- bats: 1.13.0
- jq: 1.7.1-apple
- openspec/ ディレクトリ: 存在（`openspec/schemas/longrun-tdd/` カスタムスキーマあり）
- `openspec/config.yaml` は .gitignore 済み（27行目）

## テストベースライン（2026-06-12 11:11 実施）

| スイート | 結果 |
|---------|------|
| `bats plugins/experience-to-skill/tests/` | 24 PASS（全件 ok） |
| `bats plugins/daily-report/tests/` | 48 PASS（全件 ok） |
| `bats plugins/harvest/tests/`（marketing-harness, main, clean） | 313 PASS（全件 ok） |
| `plugins/longrun/tests/` | 未存在（本 run で新設予定） |

## バージョン現況（Explore 調査結果）

| 対象 | 現在 | 本 run 後 |
|------|------|----------|
| longrun plugin.json | 5.2.0 | 6.2.0（change-1: 5.3.0 → change-2: 6.0.0 → change-3: 6.1.0 → change-4: 6.2.0） |
| lr plugin.json | 5.1.1 | 6.1.0（change-2: 6.0.0 → change-3: 6.1.0） |
| claude-harness marketplace.json top | 2.5.1 | 要 bump |
| harvest plugin.json（marketing-harness） | 0.13.1 | 0.14.0（change-5） |
| marketing-harness marketplace.json top | 0.14.1 | 要 bump |

## コードベース調査メモ

- `plugins/longrun/`: commands 6（archive/decisions/exec/feedback/plan/status）、agents 7、skills 3（plan/feedback/orchestrator）、templates（plan-template.md / plan-template-mvp.md / longrun-tdd-schema/）、tests/ なし
- `plugins/lr/`: commands 6（p/e/s/d/a/f）、plugin.json のみ
- `docs/PLUGIN-CONVENTIONS.md` は **marketing-harness 側にのみ存在**（claude-harness 側 docs/ には cooking-mvp-mode-plan.md のみ）→ change-5 の規約追記先は marketing-harness 側で正しい
- marketing-harness: main ブランチ、working tree clean。harvest skills 10 / agents 2 / scripts 22
- サブエージェント散文契約の定義場所: `plugins/harvest/skills/bestprac/refresh/SKILL.md` と `plugins/harvest/skills/knowledge/knowledge/SKILL.md`

## フェーズ進捗

- [x] Setup: ツール検証・ベースライン・checkpoint/decisions 初期化
- [x] Build Contract: APPROVED by longrun-reviewer（1ラウンド、SHOULD_FIX 2 + NOTE 1 を plan.md に反映済み。decisions.md D-BC1 参照）
- [ ] Build: change-1〜4 直列（claude-harness）+ change-5 並行（marketing-harness）
  - [x] Build前半: 全 5 change の OpenSpec ドキュメント作成（validate --strict PASS）
  - [x] Spec Review: ラウンド1（3 APPROVE / 2 REQUEST_CHANGES）→ 修正 → ラウンド2（change-1/2 APPROVE）。全件 APPROVE（D-B2, D-B3）
  - [ ] verification-guide.md 生成
  - [ ] Build後半: TDD 実装（longrun-builder）
- [ ] Verify: 静的検証 + 動作検証
- [ ] Feedback: ユーザー確認
- [ ] Integration: マルチリポジトリ統合（options.integrate: true）
- [ ] Archive

## 次フェーズへの引き継ぎ

- 実行構造: change-1 → 2 → 3 → 4 直列、change-5 は marketing-harness で並行
- PR は change ごとに分割。このリポジトリは Draft PR バックアップ運用（CLAUDE.md）
- openspec バージョン乖離（volta 1.2.0 vs npx 0.23.0）を change-1 の実機検証で解消すること
