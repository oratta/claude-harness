## ADDED Requirements

### Requirement: 手動で実行先とアカウントを固定する
手動Codex開発は登録accountとmodelを明示し、共通App Server workerだけに委譲しなければならない（MUST）。worker失敗時にexec/Claudeへfallbackしてはならない（MUST NOT）。

#### Scenario: 手動依頼
- **WHEN** 人間がCodexと登録accountを指定する
- **THEN** burn窓を要求せず同accountで全委譲を行う

### Requirement: 品質工程を維持する
工程管理はdevelopの正本を使用し、W/R1/G/追加レビュアー/deciderの全役割をCodexへ委譲しなければならない（MUST）。レビューは別threadかつread-onlyでなければならない（MUST）。

#### Scenario: 仕様に差し戻し
- **WHEN** 独立仕様レビューが修正を要求する
- **THEN** Claudeが正本の回数上限を確認し、Codex作業者へ修正を委譲する

#### Scenario: 既存CLI経路に到達する
- **WHEN** CodexモードでGが別レビューを要求する
- **THEN** ClaudeがApp Serverの新しいread-only依頼を作り、codex execやClaude reviewerを呼ばない
