# fable-judgment-only — Fable は判断だけ。聖域パスの実装は opus、G は sonnet、abundant の押し上げ廃止

## Why

PR #234（dev-workflow 2.3.0）の後に Fable の行き先を再集計したところ、先週の Fable 消費 3,590（API 定価換算）のうち W（作業者）924・G（ゲート実行者）497・R1（仕様レビュアー）464 で、Fable で走った W / G 24 本のうち 20 本は最初の指示に事前分類の「聖域パス」（`.claude/` 配下・CLAUDE.md・スキル）を含んでいた。エージェント設定が製品そのものであるリポ（claude-harness・flatmate）ではほぼ全実装が聖域に当たり、例外のはずの Fable が既定になっていた。今週は abundant モードの押し上げで R1 / G が 100% Fable になっている。G 自身の仕事は HEAD 固定・ラベル操作・書式照合・証拠の実在確認で、欠陥探索は Codex か needs-reviewer のレビュアーが担っており、G を opus にする根拠が無い。

Anthropic の公式資料（cost-optimization / model-migration、2026-09-06 取得）は「モデル交換は最後、測ってから」「調査・照合は effort を下げても落ちない、長い実装は落ちる」「lead = Opus、subagent = Sonnet の実例」を示しており、判断を Fable に、実装と照合を Sonnet / Opus に置く方向と整合する。オーナー決定 2026-09-06。

## What Changes

- 事前分類表に「1 周目」列を足し、聖域パスは `opus`、マージ権限・層間契約・課金/法務は `fable`。W の Fable 経路はこの 3 行と失敗ループ昇格だけ
- G の既定を `opus` → `sonnet`（上げない）。needs-reviewer で spawn するレビュアーは既定 `opus`、マージ権限・層間契約・課金/法務で `fable`
- R1 は `opus` 固定。Fable はマージ条件・層間契約・課金/法務に触れるときだけ（聖域パスだけでは上げない）
- `abundant` はどの役割の既定も上げない（余った Fable 枠は人間の対話と verify に回す）
- pr-review-gate 2-2: 実装品質起因の修正実装は `fable` 直行ではなく前回の実装モデルの 1 段上（sonnet → opus → fable）

## Capabilities

### Modified Capabilities

- `dev-workflow-develop`: Requirement「役割のモデルは事前分類と残量モードで決める」（W の 1 周目・G sonnet・abundant）と Requirement「役割の指示書」の事前分類表の列
- `dev-workflow-execution-strategy`: Requirement「残量モードによる閾値調整」の abundant

## Impact

- `skills/develop/SKILL.md`・`references/roles/{worker,gate-runner,spec-reviewer}.md`・`references/decision-criteria.md`・`scripts/session-tripwires.sh`・`skills/pr-review-gate/SKILL.md`・README
