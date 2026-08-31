## MODIFIED Requirements

### Requirement: Skill MUST auto-trigger only on skill-creation request phrases

新スキル `experience-to-skill` SHALL be activated by Claude **only when** the user message contains explicit skill-creation request phrases such as "スキル化して", "スキルにして", "スキルを作って", "過去の作業からスキルを作って", "この作業 スキル化したい". The skill description MUST NOT mention generic completion phrases (e.g., "完了", "done", "commit して", "archive") that would cause unrelated activations.

#### Scenario: User explicitly requests skill distillation

- **WHEN** the user sends a message such as "先週やった動画生成の作業をスキル化して"
- **THEN** Claude activates the `experience-to-skill` skill and initiates the jsonl distillation workflow

#### Scenario: User signals plain work completion

- **WHEN** the user sends a message such as "完了です" or "commit して" without any skill-creation phrase
- **THEN** the `experience-to-skill` skill MUST NOT auto-trigger

#### Scenario: Archive command completes

- **WHEN** `openspec:archive`（`/opsx:archive`）completes its workflow
- **THEN** the `experience-to-skill` skill MUST NOT be invoked (the new skill does not gate or augment archive flows). SKILL.md と README の「絶対に起動しないケース」の列挙は `openspec:archive` のみを挙げ、解散した `longrun:archive` を含まない
