## MODIFIED Requirements

### Requirement: /casting:init による生成

`/casting:init` コマンドは、実行した git repo に `.claude/casting/project.md`（差分方式の空表＋書き方説明。カタログ全行のコピーを含まない）・`.claude/casting/precedents.md`・`.claude/casting/delegation.md`（委任宣言の雛形。2 表の空表＋書き方説明）を雛形から生成し、`.gitignore` に `.claude/casting/local.md` を追記しなければならない (MUST)。あわせて導入 repo 台帳 `~/.claude/casting/registry.txt` に repo ルートの絶対パスを追記しなければならない (MUST)。既存のファイルがある場合は上書きしてはならない (MUST NOT)。gitignore 追記と台帳追記は冪等でなければならない (MUST)。

#### Scenario: 初回実行で一式が生成される

- **WHEN** `.claude/casting/` が無い git repo で init の生成手順を実行する
- **THEN** project.md（カタログ全行のコピーを含まない差分表）・precedents.md・delegation.md が生成され、.gitignore に local.md の行が1行だけ追加され、registry.txt に repo パスが1行追加される

#### Scenario: 再実行しても上書き・重複しない

- **WHEN** 生成済みの repo で project.md と delegation.md を編集した後、もう一度 init の生成手順を実行する
- **THEN** 編集内容が保持され、.gitignore と registry.txt の行も重複しない
