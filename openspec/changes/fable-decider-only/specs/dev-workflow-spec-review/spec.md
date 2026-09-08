## MODIFIED Requirements

### Requirement: 仕様レビュアーのモデルは役割で選ぶ
R1 は本体が `model` を明示して spawn しなければならない（MUST）。既定は中位ティア（`opus`）とし（SHALL）、仕様が `references/roles/worker.md` の「重要実装の事前分類」表のマージ権限・層間契約・課金/法務に当たる場合は、`model: fable` を付けた `general-purpose` ではなく `subagent_type: dev-workflow:decider` で spawn しなければならない（MUST。聖域パスだけでは上げない。分類表の正本は worker.md であり、この要件に再掲しない）。`general-purpose` などの実行役の種別に `model: fable` を付ける spawn は `scripts/agent-model-guard.sh` に拒否される（SHALL）。残量モードは `dev-workflow-execution-strategy` の規定に従い、`FABLE_BUDGET_MODE=reserve` は自動実行のみ、`exhausted` は全経路で `opus` を上限とする（MUST）。

#### Scenario: モデル明示と既定 opus が書かれている
- **WHEN** SKILL.md の「モデル」節または `references/roles/spec-reviewer.md` を読む
- **THEN** `model` を明示すること、既定が `opus` であること、マージ権限・層間契約・課金/法務に当たれば `dev-workflow:decider` で spawn し、聖域パスだけでは上げないことが書かれている

#### Scenario: 残量モードの扱いが既存規定と一致する
- **WHEN** SKILL.md または `references/roles/spec-reviewer.md` の残量モードの記述を読む
- **THEN** `reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限、と書き分けられている
