## MODIFIED Requirements

### Requirement: 対象スキルの SKILL.md は「## 自己検証」節を持つ

棚卸しリスト（`plugins/dev-workflow/references/self-verification.md` の「対象スキル一覧」）で対象と判定された各スキルの SKILL.md は、見出しリテラル「## 自己検証」の節を持たなければならない (MUST)。節は (a) `plugins/dev-workflow/references/self-verification.md` への参照 1 行、(b) スキル固有の検証手順、の 2 要素で構成し、固有手順には検証コマンド（実行可能なコマンド文字列）または検証対象の成果物パスを最低 1 つ含めなければならない (MUST)。

#### Scenario: 7 スキルの SKILL.md に「## 自己検証」節が存在する

- **WHEN** ユーザーが `plugins/worktree/skills/wt-setup/SKILL.md`・`plugins/worktree/skills/wt-clean/SKILL.md`・`plugins/daily-report/skills/daily-report/SKILL.md`・`plugins/weekly-report/skills/weekly-report/SKILL.md`・`plugins/infra/skills/infra-setup/SKILL.md`・`plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md` の各ファイルで「## 自己検証」を grep する
- **THEN** 7 ファイルすべてで見出しがちょうど 1 件ヒットする

#### Scenario: 各節が共通原則リファレンスへの参照 1 行を含む

- **WHEN** ユーザーが対象スキルの「## 自己検証」節で `dev-workflow/references/self-verification.md` を grep する
- **THEN** 各対象スキルの節にリファレンスへのパス参照が 1 行含まれ、旧パス `loops/references/self-verification.md` は 0 件である

#### Scenario: 各節に検証コマンドまたは成果物パスが最低 1 つある

- **WHEN** ユーザーが対象スキルの「## 自己検証」節の固有手順を読む
- **THEN** 各節に、実行可能な検証コマンド（例: テスト実行・lint・`jq` による形式チェック）または検証対象の成果物パス（例: 生成されるファイルのパス）が最低 1 つ記載されている

## ADDED Requirements

### Requirement: 棚卸しリストは実在する全スキルを対象か対象外のどちらかに載せる

`plugins/dev-workflow/references/self-verification.md` の「対象スキル一覧」は、リポジトリに実在する `plugins/*/skills/*/SKILL.md` の全件を、対象表か対象外表のどちらかに実パスで載せなければならない (MUST)。対象外表の各行には判定理由を付けなければならない (MUST)。網羅性はテスト（`plugins/dev-workflow/tests/self-verification-sections.bats`）で機械検査し、載っていないスキルがあればテストが落ちる。

#### Scenario: 実在する全 SKILL.md が棚卸しリストに現れる

- **WHEN** ユーザーが `ls plugins/*/skills/*/SKILL.md` の各パスを `plugins/dev-workflow/references/self-verification.md` で grep する
- **THEN** 全件が 1 回以上ヒットし、ヒットしないパスは 0 件である

#### Scenario: 新しいスキルを載せ忘れるとテストが落ちる

- **WHEN** 棚卸しリストに載っていない `plugins/<plugin>/skills/<skill>/SKILL.md` が追加された状態で `bash scripts/test.sh dev-workflow` を実行する
- **THEN** 網羅性のテストが `not ok` となり、載っていないパスがテスト出力に表示される
