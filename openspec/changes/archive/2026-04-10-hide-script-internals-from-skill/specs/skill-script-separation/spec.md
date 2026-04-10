## ADDED Requirements

### Requirement: SKILL.mdはスクリプト内部実装を記述しない

SKILL.mdは、スクリプトが担当する処理の実装詳細（symlinkの作成方法、git追跡判定ロジック、ファイル操作コマンド等）を記述してはならない（SHALL NOT）。SKILL.mdに記述するのは「スクリプトの実行指示」と「スクリプト出力に基づくLLM判断処理」のみとする。

#### Scenario: SKILL.mdにsymlink関連の文言がない
- **WHEN** SKILL.md の全文を検索する
- **THEN** `symlink`、`ln -s`、`-sfn`、`git ls-files` の文字列が存在しない

#### Scenario: SKILL.mdにスクリプト実行指示がある
- **WHEN** SKILL.md の Step 1 を読む
- **THEN** `bash` コマンドでスクリプトを実行する指示が明記されている

#### Scenario: descriptionに実装詳細がない
- **WHEN** SKILL.md の frontmatter の description を読む
- **THEN** `symlink`、`.claude/のsymlink作成` 等の実装詳細が含まれていない

### Requirement: SKILL.mdはスクリプト出力に基づく分岐のみ記述する

スクリプト実行後のLLM処理は、スクリプトの標準出力に含まれる特定の文字列をトリガーとして記述する（SHALL）。

#### Scenario: .worktreeinclude未存在時の分岐
- **WHEN** スクリプト出力に「.worktreeinclude: なし」が含まれる
- **THEN** SKILL.mdの手順に従い.worktreeincludeを生成する処理が記述されている

#### Scenario: 依存インストール必要時の分岐
- **WHEN** スクリプト出力に「NEEDS_NPM_INSTALL=true」が含まれる
- **THEN** SKILL.mdの手順に従いユーザーに確認する処理が記述されている

### Requirement: エラーハンドリングはスクリプト出力に委譲する

SKILL.mdのエラーハンドリングセクションは、スクリプトの内部エラー処理の詳細を記述してはならない（SHALL NOT）。スクリプトがエラー終了した場合はその出力をユーザーに報告するのみとする。

#### Scenario: スクリプトエラー時の対応
- **WHEN** スクリプトが非ゼロで終了する
- **THEN** SKILL.mdの指示は「スクリプトのエラー出力をユーザーに報告する」のみである
