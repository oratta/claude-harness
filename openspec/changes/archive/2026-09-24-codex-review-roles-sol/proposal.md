## Why

Codex の利用枠の消費が速すぎる（issue #474）。組み込み profile の `codex-standard`・`codex-economy`・`claude-write-codex-review` は、レビュー 3 役（`spec-review`・`impl-review`・`review`）に最上位の GPT-6 Astra（$10/$50 per MTok）を当てている。Claude がオーケストレーターを担う構成では、Astra の強み（長い自律的な多段作業）はオーケストレーター側と役割が重なり、レビューには中位の GPT-6 Sol（$2/$10、Astra の 1/5）が妥当とされた（2026-09-24 時点の OpenAI 公式の Model guidance と Pricing）。

## What Changes

- 組み込み profile `codex-standard`・`codex-economy`・`claude-write-codex-review` の `spec-review`・`impl-review`・`review` の model を `astra` から `sol` に替える。effort は `high` のまま据え置く（「レビューで effort を上げる」は公式の推奨ではないため）
- 3 profile の `decider` は `astra`/`high` のまま残す
- `hybrid-standard` は変えない（レビュー役は Claude が担っており、Astra を使っていない）
- 自動選択で `claude-write-codex-review` が選ばれたとき、レビュー役が `sol`、decider が `astra` に解決されるようになる

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `codex-role-profiles`: 要件「名前付き設定セットを共通入口で選ぶ」のシナリオ「二つの Codex 組み込みセットを解決する」と「Claude が書き Codex が検査する組み込みセットを解決する」、要件「明示指定が無い工程では provider の週次余裕から構成を選ぶ」のシナリオ「両 provider に余裕がある」で、レビュー 3 役の解決先を `sol/high` に、decider を `astra/high` に分けて書く（要件本文は変えない）

## Impact

- 設定: `plugins/dev-workflow/references/codex-role-profiles.json`（3 profile × 3 役 = 9 行）
- テスト: `plugins/dev-workflow/tests/test_codex_develop.py` の `test_builtin_codex_entries_name_families_not_model_ids` と `test_reverse_hybrid_profile_resolves_every_canonical_role` の期待値
- 変更記録: `plugins/dev-workflow/changes/474.md`
- 受け入れるリスク: Sol のレビューが Astra より見落としを増やす可能性がある（比較データは無い）。Claude 側の R1 / pr-review-gate のレビュアーとの二重レビューで補う前提
- 版は上げない（このリポジトリは `version` を撤去済み）
