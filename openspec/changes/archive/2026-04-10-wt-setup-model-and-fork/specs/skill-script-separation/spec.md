## ADDED Requirements

### Requirement: fork環境でのスクリプト出力ベース分岐が動作する

context: fork環境において、スクリプトの標準出力に基づくLLM分岐処理が正常に動作するものとする（SHALL）。

#### Scenario: fork環境で.worktreeinclude未存在を検知する
- **WHEN** fork環境でwt-setup.shを実行し、出力に「.worktreeinclude: なし」が含まれる
- **THEN** SKILL.mdの手順に従い.worktreeinclude生成処理が開始される

#### Scenario: fork環境でスクリプトエラーを検知する
- **WHEN** fork環境でwt-setup.shがエラー終了する
- **THEN** エラー出力が親コンテキストを通じてユーザーに報告される
