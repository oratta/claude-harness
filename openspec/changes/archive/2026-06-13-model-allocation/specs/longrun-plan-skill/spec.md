# longrun-plan-skill Specification (Delta)

## ADDED Requirements

### Requirement: longrun-plan は Synthesis でモデル割り当て推奨を生成する

`longrun-plan` スキル（`plugins/longrun/skills/longrun-plan/SKILL.md`、change-3 分離後のフルモード plan スキル）は、Step 5（Synthesis）で plan.md を生成する際に「モデル割り当て」セクションを必ず含めなければならない (MUST)。表には Changes分解 の各 change × 自律実行で起動される agent ロール（reviewer / builder / verifier / browser-verifier 等）ごとに 1 行を生成し、ティア（haiku / sonnet / inherit）の推奨と推奨理由を記入すること。推奨は以下のヒューリスティクスに従う:

- アーキテクチャレビュー・複雑な TDD 実装 → `inherit`（指定なし）
- 定型的検証・要約 → `haiku`
- リサーチ・ブラウザ操作・中規模実装 → `sonnet`
- 確信度が低い・分類に迷うタスク → `inherit`（保守的デフォルト。「迷ったら inherit」）

SKILL.md にはこのヒューリスティクスと保守的デフォルトの方針を明記し、ティアからモデル ID への解決は `plugins/longrun/references/model-tiers.md` を参照する旨を記載すること。SKILL.md 本文にモデル ID をハードコードしてはならない (MUST NOT)。

#### Scenario: 生成された plan.md にモデル割り当て表が含まれる

- **WHEN** ユーザーが `/longrun:plan` で plan.md を作成し Step 5（Synthesis）が完了する
- **THEN** 生成された plan.md に「モデル割り当て」セクションが存在し、Changes分解 の各 change × agent ロールごとの行にティア（haiku / sonnet / inherit のいずれか）と理由が記入されている

#### Scenario: SKILL.md にヒューリスティクスが明記されている

- **WHEN** ユーザーが `plugins/longrun/skills/longrun-plan/SKILL.md` の推奨生成ステップを読む
- **THEN** 「アーキテクチャレビュー・複雑な TDD 実装 → inherit」「定型的検証・要約 → haiku」「リサーチ・ブラウザ操作・中規模実装 → sonnet」の 3 ルールと「迷ったら inherit に倒す」保守的デフォルトが記載されている

#### Scenario: 確信度の低いタスクは inherit に倒される

- **WHEN** Synthesis 中にあるタスクがどのヒューリスティクス分類にも明確に該当しない
- **THEN** スキルは該当行のティアに `inherit` を記入し、理由欄に確信度が低いため保守的デフォルトを適用した旨を記載する

#### Scenario: ユーザーが plan 確認時に表を上書きできる

- **WHEN** ユーザーが Step 8（ユーザー確認）で plan.md のモデル割り当て表の `上書き` 欄またはティア欄を直接編集する
- **THEN** スキルは編集後の値をそのまま確定し、推奨値への巻き戻しや再生成を行わない

### Requirement: longrun-plan の Validation はモデル割り当てセクションの存在を検査する

`longrun-plan` スキルの Step 6（Validation）のセクション存在チェックリストは、「モデル割り当て」セクションの存在確認項目を含まなければならない (MUST)。セクションが欠落している場合は、フルモード Step 6 の既存 GATE セマンティクスに従い、plan.md を修正してから保存すること（欠落したままの保存は禁止）。

#### Scenario: Validation チェックリストにモデル割り当てが含まれる

- **WHEN** ユーザーが SKILL.md の Step 6（Validation）のセクション存在チェックリストを読む
- **THEN** 「モデル割り当て」セクションの存在確認項目がチェックリストに含まれている

#### Scenario: セクション欠落時は保存前に修復される

- **WHEN** Step 6 の Validation で生成済み plan.md に「モデル割り当て」セクションが無いことが検出される
- **THEN** スキルは plan.md を修正してセクションを追加してから保存し、欠落したままファイルを保存しない
