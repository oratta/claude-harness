# longrun-plan-skill Delta Specification

## ADDED Requirements

### Requirement: Deprecated `--mode=mvp` flag MUST surface a migration notice and terminate

The `longrun-plan` Skill (`plugins/longrun/skills/longrun-plan/SKILL.md`) SHALL inspect its invocation arguments before executing Step 1. When `--mode=mvp` is present, the Skill MUST output a migration notice stating that MVP plan creation has moved to `/longrun:mvp` (with the `/lr:m` shortcut), and MUST terminate without executing any of Step 1〜Step 8 and without generating a plan.md. The flag MUST NOT be silently ignored and MUST NOT fall through to full mode. When the flag is absent, or when `--mode=full` is provided, the Skill SHALL execute the existing full-mode flow (Step 1〜Step 8) without any behavioral change. The SKILL.md MUST no longer contain the MVP-mode section body (moved to the `longrun-mvp-plan` skill).

#### Scenario: Old flag shows migration notice

- **WHEN** a user runs `/longrun:plan --mode=mvp <args>`
- **THEN** the Skill MUST output a notice naming `/longrun:mvp` (and `/lr:m`) as the new entry point, MUST NOT execute Step 1〜Step 8, and MUST NOT generate any plan.md

#### Scenario: Old flag via shortcut shows the same notice

- **WHEN** a user runs `/lr:p --mode=mvp <args>` (arguments forwarded transparently to the skill)
- **THEN** the same migration notice MUST be shown and the flow MUST terminate without producing a plan.md

#### Scenario: Full mode is unaffected

- **WHEN** a user runs `/longrun:plan` with no `--mode` flag, or with `--mode=full`
- **THEN** the Skill MUST execute the existing full-mode Step 1〜Step 8 exactly as before, including reading `templates/plan-template.md` and invoking the `longrun-reviewer` Agent at Step 7

#### Scenario: MVP-mode section is removed from the skill body

- **WHEN** a reader greps `plugins/longrun/skills/longrun-plan/SKILL.md` for the MVP-mode step definitions (e.g., `MVP Step 4.5`, `longrun-mvp-plan-reviewer`)
- **THEN** zero matches MUST be found; only the migration-notice handling MAY reference MVP

## MODIFIED Requirements

### Requirement: README MUST document MVP mode usage

`plugins/longrun/README.md` SHALL contain a section that documents the standalone MVP plan entry point, its differences from full mode, and the situations in which it is appropriate to use. The section MUST include the literal command form `/longrun:mvp` (and MAY include the alias `/lr:m` if the alias plugin is available). The section MUST state that `--mode=mvp` is deprecated and that invoking `/longrun:plan --mode=mvp` produces a migration notice instead of running the MVP flow. The section MUST state that the MVP plan skill is a generic capability not tied to any specific project and is intended for short-time human-implemented MVP scenarios.

#### Scenario: MVP section is present

- **WHEN** a reader scans `plugins/longrun/README.md`
- **THEN** a section MUST exist that names the MVP plan skill and includes the literal text `/longrun:mvp`

#### Scenario: Differences from full mode are described

- **WHEN** a reader reads the MVP section in the README
- **THEN** the section MUST describe at least these differences: Build Contract review is skipped, TDD enforcement is skipped, Verifier auto-invocation is skipped, OpenSpec change archival is skipped on `/longrun:archive`

#### Scenario: Deprecation of the old flag is documented

- **WHEN** a reader reads the MVP section in the README
- **THEN** the section MUST state that `--mode=mvp` is deprecated and that `/longrun:plan --mode=mvp` now emits a migration notice pointing to `/longrun:mvp`

#### Scenario: Use-case guidance is generic

- **WHEN** a reader reads the MVP section in the README
- **THEN** the section MUST state that the MVP plan skill is suitable for short-time human-implemented MVP scenarios and is not specific to any particular project

## REMOVED Requirements

### Requirement: SKILL.md MUST dispatch on a `--mode=mvp` flag at the top of its execution flow

**Reason**: MVP モードは独立スキル `longrun-mvp-plan` に分離され、`longrun-plan` 内のモード分岐ディスパッチは廃止される。旧フラグの扱いは ADDED の移行案内要件が引き継ぐ。
**Migration**: MVP プラン作成は `/longrun:mvp`（短縮 `/lr:m`）を使用する。`--mode=mvp` 指定時は移行案内が表示される。

### Requirement: MVP mode MUST define a Step-by-Step mapping of full-mode steps

**Reason**: フルモードとの REUSE/REPLACE/SKIP マッピング表は、モード同居を前提とした構造であり、独立スキル化により不要となる。新スキルは自己完結したステップ群として記述される。
**Migration**: `longrun-mvp-plan-skill` capability の「Skill MUST preserve the existing MVP flow without logic changes」要件を参照。

### Requirement: MVP mode MUST introduce a parallel-research Step 4.5 that invokes the `longrun-mvp-research` subagent

**Reason**: リサーチステップの定義は新スキル `longrun-mvp-plan` に移設される（ロジック不変）。
**Migration**: `longrun-mvp-plan-skill` capability の「Skill MUST invoke the longrun-mvp-research subagent before Synthesis」要件を参照。

### Requirement: MVP mode Step 7 MUST invoke plan-reviewer and bestpractice-reviewer subagents in parallel

**Reason**: 並列レビューステップの定義は新スキル `longrun-mvp-plan` に移設される（ロジック不変）。
**Migration**: `longrun-mvp-plan-skill` capability の「Skill MUST invoke the two MVP reviewers in parallel within a single message」要件を参照。

### Requirement: MVP mode Step 5 MUST embed the `<!-- mvp-mode -->` marker in the generated plan.md

**Reason**: マーカー埋め込みの定義は新スキル `longrun-mvp-plan` に移設される（マーカー自体と archive 側分岐は現状維持）。
**Migration**: `longrun-mvp-plan-skill` capability の「Generated plan.md MUST begin with the `<!-- mvp-mode -->` marker」要件を参照。

### Requirement: MVP mode MUST replace Step 6 Validation with a lightweight checklist

**Reason**: 軽量 Validation の定義は新スキル `longrun-mvp-plan` に移設される（チェックリスト内容は不変）。
**Migration**: `longrun-mvp-plan-skill` capability の「Skill MUST perform lightweight Validation against the seven required sections」要件を参照。

### Requirement: MVP mode Step 8 MUST omit OpenSpec backlog reconciliation and recommend human handoff

**Reason**: ハンドオフステップの定義は新スキル `longrun-mvp-plan` に移設される（ロジック不変）。
**Migration**: `longrun-mvp-plan-skill` capability の「Handoff step MUST omit OpenSpec writes and announce the human-implementation path」要件を参照。

### Requirement: MVP lightweight template MUST exist with mvp-mode marker and divergence-prevention header

**Reason**: `plan-template-mvp.md` の帰属が新スキル `longrun-mvp-plan` に整理されるため、テンプレート要件は新 capability に移設される（ファイルパス・マーカー・divergence 防止コメント・セクション構成は不変）。
**Migration**: `longrun-mvp-plan-skill` capability の「MVP agents and lightweight template MUST be attributed to this skill」要件を参照。
