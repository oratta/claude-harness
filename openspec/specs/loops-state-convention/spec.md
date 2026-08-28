# loops-state-convention Specification

## Purpose
TBD - created by archiving change loops-plugin. Update Purpose after archive.
## Requirements

### Requirement: State 規約は 4 節構成の形式を定義する

loops プラグインは、プロアクティブ/長期ループが使う State ファイルの規約を定義しなければならない (MUST)。State ファイルの置き場所は利用側リポジトリの `loops/state/<name>.state.md` とし、以下の 4 節を必須構成とする: 「現在の作業」「前回の試行と結果」「人間への引き継ぎ待ち」「繰り越しタスク」。規約には「エージェントは忘れるが、リポジトリは記憶する」という設計原則（セッションをまたぐ記憶はファイルに永続化する）を明記すること。規約は `plugins/loops/references/recipe-format.md` または独立した references 文書のいずれかに記載する。

#### Scenario: State 規約が 4 節を定義している

- **WHEN** loops プラグインの references 配下で State 規約の記述を grep する
- **THEN** `loops/state/<name>.state.md` という配置規約と、「現在の作業」「前回の試行と結果」「人間への引き継ぎ待ち」「繰り越しタスク」の 4 節がすべて定義されている

#### Scenario: 永続化の設計原則が明記されている

- **WHEN** State 規約の説明を読む
- **THEN** セッションをまたぐ記憶をファイルに永続化する旨（「エージェントは忘れるが、リポジトリは記憶する」相当の原則）が記載されている

### Requirement: State テンプレートは規約準拠の雛形を提供する

`plugins/loops/templates/state-template.md` は、State 規約の 4 節（現在の作業 / 前回の試行と結果 / 人間への引き継ぎ待ち / 繰り越しタスク）をこの構成で含む雛形でなければならない (MUST)。「繰り越しタスク」節には、discovery で拾ったが処理しなかったタスクを必ず記録する（silent drop 禁止）旨の注記を含めること。

#### Scenario: テンプレートが 4 見出しを持つ

- **WHEN** `plugins/loops/templates/state-template.md` の見出しを grep する
- **THEN** 「現在の作業」「前回の試行と結果」「人間への引き継ぎ待ち」「繰り越しタスク」の 4 見出しがすべて存在する

#### Scenario: silent drop 禁止の注記がある

- **WHEN** テンプレートの「繰り越しタスク」節を読む
- **THEN** 処理しなかったタスクを必ず繰り越しとして記録する旨の注記が存在する
