# skill-execution-isolation Specification

## Purpose
TBD - created by archiving change wt-setup-model-and-fork. Update Purpose after archive.
## Requirements

### Requirement: スキルはモデルを明示的に指定する

スクリプト実行を含むスキルは、frontmatterで `model` フィールドを指定し、セッションモデルに依存しないものとする（SHALL）。

#### Scenario: wt-setup SKILL.mdにmodelが指定されている
- **WHEN** wt-setup SKILL.md の frontmatter を読む
- **THEN** `model: sonnet` が設定されている

### Requirement: スキルは隔離されたコンテキストで実行する

スクリプト実行を含むスキルは、frontmatterで `context: fork` を指定し、会話コンテキストから隔離して実行するものとする（SHALL）。

#### Scenario: wt-setup SKILL.mdにcontext: forkが指定されている
- **WHEN** wt-setup SKILL.md の frontmatter を読む
- **THEN** `context: fork` が設定されている

#### Scenario: fork環境でスクリプト実行が正常に動作する
- **WHEN** wt-setupスキルをfork環境で実行する
- **THEN** wt-setup.shが実行され、出力が親コンテキストに返される

### Requirement: コマンドファイルのdescriptionに実装詳細を含めない

コマンドファイル（commands/wt-setup.md）のdescriptionは、スキルの利用判断に必要な情報のみ記述し、実装詳細（symlink、git追跡等）を含めないものとする（SHALL NOT）。

#### Scenario: コマンドdescriptionに実装詳細がない
- **WHEN** commands/wt-setup.md の frontmatter の description を読む
- **THEN** `symlink`、`.claude/`、`env` 等の実装詳細が含まれていない

### Requirement: スクリプト出力ベースの分岐は対話を最小化する

スクリプト出力に基づく LLM の分岐処理は、自明な判断に対して AskUserQuestion を使用せず、自動判定ルールに基づいて処理するものとする（SHALL）。AskUserQuestion は、判断に必要な情報がスクリプト出力や既存ファイルから得られない場合のみ使用する（SHALL）。

#### Scenario: .worktreeinclude のパターン選択で AskUserQuestion を使用しない
- **WHEN** `.worktreeinclude` の生成が必要と判定される
- **THEN** env 系・ローカル設定系のパターンは AskUserQuestion なしで自動決定される

#### Scenario: 判断不能な場合のみ AskUserQuestion を使用する
- **WHEN** `.gitignore` に分類ルールに該当しない未知のパターンがある
- **AND** そのパターンがワークツリーで必要かどうかスクリプト出力や既存ファイルから判断できない
- **THEN** そのパターンのみ AskUserQuestion で確認する
