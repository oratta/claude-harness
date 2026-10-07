## MODIFIED Requirements

### Requirement: スキルは隔離されたコンテキストで実行する

スクリプト実行を含むスキルは、frontmatterで `context: fork` を指定し、会話コンテキストから隔離して実行するものとする（SHALL）。`context: fork` を指定するスキルは `background: false` も指定し、呼び出し側が完了を待つものとする（SHALL）。ただし同名の `commands/<name>.md` が存在する間は呼び出しがそのコマンドに解決され、スキル本体の frontmatter は効かない。効くのはスキル本体が直接実行される経路に限る。その旨を SKILL.md の frontmatter コメントに理由として残すものとする（SHALL）。

#### Scenario: wt-setup SKILL.mdにcontext: forkが指定されている
- **WHEN** wt-setup SKILL.md の frontmatter を読む
- **THEN** `context: fork` と `background: false` が設定されている

#### Scenario: fork環境でスクリプト実行が正常に動作する
- **WHEN** wt-setupスキルをスキル本体が直接実行される経路（fork）で実行する
- **THEN** wt-setup.shが実行され、出力が親コンテキストに返される

#### Scenario: 効かない経路の理由が frontmatter から読める
- **WHEN** wt-setup SKILL.md の先頭 12 行を読む
- **THEN** `/wt-setup` と Skill ツール経由が同名の commands ラッパーに解決されるため、現行経路では `context: fork` / `background` が効かないこと、残す理由が読める
