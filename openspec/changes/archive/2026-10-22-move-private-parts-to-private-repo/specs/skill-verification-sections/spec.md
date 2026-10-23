## MODIFIED Requirements

### Requirement: 対象スキルの SKILL.md は「## 自己検証」節を持つ

棚卸しリスト（`plugins/dev-workflow/references/self-verification.md` の「対象スキル一覧」）で対象と判定された各スキルの SKILL.md は、見出しリテラル「## 自己検証」の節を持たなければならない (MUST)。節は (a) `plugins/dev-workflow/references/self-verification.md` への参照 1 行、(b) スキル固有の検証手順、の 2 要素で構成し、固有手順には検証コマンド（実行可能なコマンド文字列）または検証対象の成果物パスを最低 1 つ含めなければならない (MUST)。公開版の対象は `wt-setup`・`wt-clean`・`infra-setup`・`push-guard-setup` の 4 スキルで、`daily-report`・`weekly-report` は #1129 で個人版のリポジトリ `oratta/claude-harness-oratta` に移したので含めない（個人版に写したスキルは「## 自己検証」節を持ったまま移る）。

#### Scenario: 4 スキルの SKILL.md に「## 自己検証」節が存在する

- **WHEN** ユーザーが `plugins/worktree/skills/wt-setup/SKILL.md`・`plugins/worktree/skills/wt-clean/SKILL.md`・`plugins/infra/skills/infra-setup/SKILL.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md` の各ファイルで「## 自己検証」を grep する
- **THEN** 4 ファイルすべてで見出しがちょうど 1 件ヒットする

#### Scenario: 各節が共通原則リファレンスへの参照 1 行を含む

- **WHEN** ユーザーが対象スキルの「## 自己検証」節で `dev-workflow/references/self-verification.md` を grep する
- **THEN** 各対象スキルの節にリファレンスへのパス参照が 1 行含まれ、旧パス `loops/references/self-verification.md` は 0 件である

#### Scenario: 各節に検証コマンドまたは成果物パスが最低 1 つある

- **WHEN** ユーザーが対象スキルの「## 自己検証」節の固有手順を読む
- **THEN** 各節に、実行可能な検証コマンド（例: テスト実行・lint・`jq` による形式チェック）または検証対象の成果物パス（例: 生成されるファイルのパス）が最低 1 つ記載されている
