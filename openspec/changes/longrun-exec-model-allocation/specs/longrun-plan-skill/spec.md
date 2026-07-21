## MODIFIED Requirements

### Requirement: longrun-plan は Synthesis でモデル割り当て推奨を生成する

`longrun-plan` スキル（`plugins/longrun/skills/longrun-plan/SKILL.md`、change-3 分離後のフルモード plan スキル）は、Step 5（Synthesis）で plan.md を生成する際に「モデル割り当て」セクションを必ず含めなければならない (MUST)。表には Changes分解 の各 change × 自律実行で起動される agent ロール（reviewer / builder / verifier / browser-verifier 等）ごとに 1 行を生成し、ティア（haiku / sonnet / fable / inherit）の推奨と推奨理由を記入すること。推奨は以下のヒューリスティクスに従う:

- 判断が集中する場所（checkpoint 再ランク・verify の最終判定・アーキテクチャレビュー） → `fable`（判断点には賢いモデル、のモード不変ルール）
- 実装（builder） → `sonnet` を出発点とする（実行はテストと verify に守られ、失敗ループは昇格トリップワイヤーが救済する）。複雑な TDD 実装で最初から高能力が必要と判断される場合は `inherit`
- 定型的検証・要約 → `haiku`
- リサーチ・ブラウザ操作・中規模実装 → `sonnet`
- 確信度が低い・分類に迷うタスク → `inherit`（保守的デフォルト。「迷ったら inherit」）

SKILL.md にはこのヒューリスティクスと保守的デフォルトの方針を明記し、ティアからモデル ID への解決は `plugins/longrun/references/model-tiers.md` を参照する旨、および `fable` は reserve 降格（`FABLE_BUDGET_MODE=reserve` の自動実行で opus に解決される）の対象である旨を記載すること。SKILL.md 本文にモデル ID をハードコードしてはならない (MUST NOT)。

#### Scenario: 生成された plan.md にモデル割り当て表が含まれる

- **WHEN** ユーザーが `/longrun:plan` で plan.md を作成し Step 5（Synthesis）が完了する
- **THEN** 生成された plan.md に「モデル割り当て」セクションが存在し、Changes分解 の各 change × agent ロールごとの行にティア（haiku / sonnet / fable / inherit のいずれか）と理由が記入されている

#### Scenario: SKILL.md にヒューリスティクスが明記されている

- **WHEN** ユーザーが `plugins/longrun/skills/longrun-plan/SKILL.md` の推奨生成ステップを読む
- **THEN** 「判断が集中する場所 → fable」「builder は sonnet を出発点」「定型的検証・要約 → haiku」「リサーチ・ブラウザ操作・中規模実装 → sonnet」のルールと「迷ったら inherit に倒す」保守的デフォルトが記載されている

#### Scenario: 確信度の低いタスクは inherit に倒される

- **WHEN** Synthesis 中にあるタスクがどのヒューリスティクス分類にも明確に該当しない
- **THEN** スキルは該当行のティアに `inherit` を記入し、理由欄に確信度が低いため保守的デフォルトを適用した旨を記載する

#### Scenario: ユーザーが plan 確認時に表を上書きできる

- **WHEN** ユーザーが Step 8（ユーザー確認）で plan.md のモデル割り当て表の `上書き` 欄またはティア欄を直接編集する
- **THEN** スキルは編集後の値をそのまま確定し、推奨値への巻き戻しや再生成を行わない
