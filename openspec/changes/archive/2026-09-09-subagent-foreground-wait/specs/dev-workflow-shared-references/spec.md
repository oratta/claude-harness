## MODIFIED Requirements

### Requirement: 共有契約はプラグイン直下 references/ に置く
dev-workflow プラグインは、他プラグインからも参照される契約文書、および dev-workflow 内の複数スキル（develop の役割指示書と pr-review-gate）が共通で読む契約文書を `plugins/dev-workflow/references/` 直下に置かなければならない（MUST）。ここに置く契約は `self-verification.md`・`pr-body-format.md`・`model-tiers.md`・`workflow-execution.md`・`subagent-waiting.md` の 5 本である。develop スキル固有の判定表（`skills/develop/references/`）と混ぜてはならない（MUST NOT）。`plugins/dev-workflow/README.md` は「複数プラグインで共有する契約は `references/` に置く」と、5 本それぞれの一言説明を持たなければならない（MUST）。

#### Scenario: 5 契約が実在する
- **WHEN** `plugins/dev-workflow/references/` を一覧する
- **THEN** `self-verification.md`・`pr-body-format.md`・`model-tiers.md`・`workflow-execution.md`・`subagent-waiting.md` が存在する

#### Scenario: README が置き場の規約と 5 本を説明している
- **WHEN** `plugins/dev-workflow/README.md` を読む
- **THEN** `references/` の節があり、5 本のファイル名がそれぞれ 1 行の説明付きで並ぶ

#### Scenario: dev-workflow 内の複数スキルが読む契約の置き場
- **WHEN** develop の役割指示書と pr-review-gate の両方が同じ待ち方の契約を参照する
- **THEN** その契約は片方のスキル配下ではなく `plugins/dev-workflow/references/` に 1 本だけ置かれている
