## ADDED Requirements

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
