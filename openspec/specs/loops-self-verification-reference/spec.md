# loops-self-verification-reference Specification

## Purpose
TBD - created by archiving change skill-verification. Update Purpose after archive.
## Requirements

### Requirement: 自己検証の共通原則リファレンスが存在し原則と evidence 種別を定義する

`plugins/loops/references/self-verification.md` が存在しなければならない (MUST)。同ファイルは、中核原則「完了は主張であり証明ではない。evidence を提示してから完了を宣言する」を明記し、evidence の種別として少なくとも「テスト出力」「exit code」「生成物の実在と形式チェック」「実行結果ログ」の 4 種を列挙しなければならない (MUST)。

#### Scenario: リファレンスが中核原則を含む

- **WHEN** ユーザーが `plugins/loops/references/self-verification.md` を開き「完了は主張であり証明ではない」を grep する
- **THEN** ファイルが存在し、中核原則の文（「完了は主張であり証明ではない。evidence を提示してから完了を宣言する」）が本文に記載されている

#### Scenario: evidence の 4 種別が列挙されている

- **WHEN** ユーザーが `plugins/loops/references/self-verification.md` の evidence 種別の節を読む
- **THEN** 「テスト出力」「exit code」「生成物の実在と形式チェック」「実行結果ログ」の 4 種がすべて列挙されている

### Requirement: スキル側への記載ルールを定義し共通原則本文の重複コピーを禁止する

`plugins/loops/references/self-verification.md` は、スキル側への記載ルールとして「各スキルの SKILL.md は本リファレンスへの 1 行参照とスキル固有の検証手順のみを記載し、共通原則の本文をコピーしない」ことを明記しなければならない (MUST)。中核原則の文言が `plugins/*/skills/*/SKILL.md` のいずれかに重複して現れてはならない (MUST NOT)。

#### Scenario: 記載ルールが明記されている

- **WHEN** ユーザーが `plugins/loops/references/self-verification.md` のスキル側への記載ルールの節を読む
- **THEN** 「1 行参照 + スキル固有の検証手順のみ」「共通原則本文のコピー禁止」に相当するルールが記載されている

#### Scenario: 中核原則の文言が SKILL.md に重複していない

- **WHEN** ユーザーが `plugins/*/skills/*/SKILL.md` の全ファイルに対して「完了は主張であり証明ではない」を grep する
- **THEN** ヒットは 0 件である（中核原則の本文は `plugins/loops/references/self-verification.md` にのみ存在する）

### Requirement: 対象スキルの棚卸しリストをリファレンス内に記録する

`plugins/loops/references/self-verification.md` は「対象スキル一覧」の節を含み、`plugins/*/skills/*/SKILL.md` 全件の監査結果を「SKILL.md の実パス + 対象/対象外の判定 + 対象外の場合はその理由」の形式で記録しなければならない (MUST)。対象には最低でも次の 7 スキルの実パスを含めること: `plugins/longrun/skills/longrun-plan/SKILL.md`・`plugins/worktree/skills/wt-setup/SKILL.md`・`plugins/worktree/skills/wt-clean/SKILL.md`・`plugins/daily-report/skills/daily-report/SKILL.md`・`plugins/weekly-report/skills/weekly-report/SKILL.md`・`plugins/infra/skills/infra-setup/SKILL.md`・`plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`（コマンド名 e2s-distill のスキル実体。コマンド名でパスを組み立ててはならない (MUST NOT)）。

#### Scenario: 棚卸しリストに最低 7 スキルの実パスが記録されている

- **WHEN** ユーザーが `plugins/loops/references/self-verification.md` の「対象スキル一覧」節で対象と判定されたスキルのパスを確認する
- **THEN** 上記 7 スキルの実パスがすべて対象として記録されており、e2s-distill のエントリは `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md` の実パスで記載されている（`e2s-distill` をパスに含む存在しないパスの記載が 0 件）

#### Scenario: 対象外スキルに理由が記録されている

- **WHEN** ユーザーが「対象スキル一覧」節で対象外と判定されたスキルのエントリを読む
- **THEN** 各対象外エントリに判定理由（例: 成果物を出さない、既に検証ステップが本文に明示されている）が記載されている
