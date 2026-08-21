# skill-script-separation Specification

## Purpose
TBD - created by archiving change hide-script-internals-from-skill. Update Purpose after archive.
## Requirements

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

### Requirement: fork環境でのスクリプト出力ベース分岐が動作する

context: fork環境において、スクリプトの標準出力に基づくLLM分岐処理が正常に動作するものとする（SHALL）。

#### Scenario: fork環境で.worktreeinclude未存在を検知する
- **WHEN** fork環境でwt-setup.shを実行し、出力に「.worktreeinclude: なし」が含まれる
- **THEN** SKILL.mdの手順に従い.worktreeinclude生成処理が開始される

#### Scenario: fork環境でスクリプトエラーを検知する
- **WHEN** fork環境でwt-setup.shがエラー終了する
- **THEN** エラー出力が親コンテキストを通じてユーザーに報告される

### Requirement: SKILL.md はスクリプトが担当するリソースの直接操作を禁止する

SKILL.md は、スクリプトが管理するリソース（ファイル、ディレクトリ、シンボリンク等）に対して、LLM がスクリプト外で直接操作コマンドを実行することを禁止するものとする（SHALL NOT）。「スクリプトの処理を効率化する」目的での独自コマンド実行も禁止に含む。

#### Scenario: スクリプトが .claude/ を管理する場合
- **WHEN** wt-setup.sh が `.claude/` のシンボリンク作成を担当している
- **THEN** SKILL.md には LLM が `.claude/` に対する `rm`, `mv`, `ln -s` 等の直接操作を実行してはならない旨が記述されている

#### Scenario: LLM がスクリプトの処理を「最適化」しようとした場合
- **WHEN** LLM がスクリプトの処理をバイパスしてより「効率的な」コマンドを生成しようとする
- **THEN** 禁止事項に該当するため実行してはならない
