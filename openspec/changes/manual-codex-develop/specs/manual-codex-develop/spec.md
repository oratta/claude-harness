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

### Requirement: 承認と検証証拠を対象に結び付ける
手動入口は独立仕様レビューのcompleted結果・承認行・固定HEAD・clean状態・仕様artifact hashを確認しなければならない（MUST）。仕様変更時は再レビューを要求しなければならない（MUST）。

#### Scenario: 同じHEADの未コミット変更
- **WHEN** レビュー後に未コミット変更が発生する
- **THEN** 承認記録を拒否する

#### Scenario: 内容が同一のarchive移動
- **WHEN** 承認済み仕様がarchiveされ明示的な移動操作が要求される
- **THEN** 内容hash一致時だけ対象pathを更新し、内容変更時は再レビューを要求する

### Requirement: 必須検証を実行し結果を保存する
本体が選定したrequired-checkを実行してexit codeと出力を保存し、現在のclean HEADで成功した証拠なしにfinish/gateへ進んではならない（MUST NOT）。

#### Scenario: 検証失敗
- **WHEN** 必須検証が非zeroで終了する
- **THEN** finish/gateを拒否し、Codex作業者へ修正を戻す
