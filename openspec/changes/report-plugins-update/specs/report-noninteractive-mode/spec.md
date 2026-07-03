# report-noninteractive-mode Specification (Delta)

## ADDED Requirements

### Requirement: daily-report / weekly-report は cron 非対話実行モードを定義する

`plugins/daily-report/skills/daily-report/SKILL.md` と `plugins/weekly-report/skills/weekly-report/SKILL.md` は、`/schedule`（cron）経由での非対話実行モードの節をそれぞれ持たなければならない (MUST)。この節は以下を満たすこと:

- AskUserQuestion（またはその他の対話依存ステップ）が使用できない実行コンテキストであることを検知した場合、質問をスキップしてデフォルト値で処理を続行する (MUST)
  - daily-report のデフォルト対象日: 昨日
  - weekly-report のデフォルト対象週: 先週
- 対話依存ステップ（口頭報告の反映等、ユーザー入力を前提とする箇所）は、非対話時にファイル出力（レポート内の空セクション・プレースホルダー等）に代替すること (MUST)
- デフォルト値を採用した・対話をスキップしたという判断は、生成物の出力（レポート本文またはログ）に判断ログとして残さなければならない (MUST)。判断ログを残さず無言でデフォルト値を適用してはならない (MUST NOT)

#### Scenario: daily-report SKILL.md に非対話モード節が存在する

- **WHEN** `plugins/daily-report/skills/daily-report/SKILL.md` を読む
- **THEN** cron / 非対話実行時にデフォルト対象日「昨日」で続行する旨を記載した節が存在する

#### Scenario: weekly-report SKILL.md に非対話モード節が存在する

- **WHEN** `plugins/weekly-report/skills/weekly-report/SKILL.md` を読む
- **THEN** cron / 非対話実行時にデフォルト対象週「先週」で続行する旨を記載した節が存在する

#### Scenario: AskUserQuestion 不可時はデフォルト値で続行する

- **WHEN** 非対話実行コンテキスト（cron 経由等）で AskUserQuestion が使用できない状態でスキルが起動される
- **THEN** SKILL.md の記述に従い、質問をスキップしデフォルト値（daily=昨日、weekly=先週）で処理が続行される

#### Scenario: 対話依存ステップがファイル出力に代替される

- **WHEN** 非対話実行時に対話依存ステップ（口頭報告等のユーザー入力前提の箇所）に到達する
- **THEN** SKILL.md の記述に従い、当該ステップはファイル出力（空セクション・プレースホルダー等）へ代替される

#### Scenario: 判断ログが出力に残る

- **WHEN** 非対話実行によりデフォルト値の適用や対話ステップのスキップが発生する
- **THEN** その判断内容が生成物の出力（レポート本文またはログ）に判断ログとして記録される
