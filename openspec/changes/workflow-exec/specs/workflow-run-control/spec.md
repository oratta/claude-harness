# workflow-run-control — Verify ループ上限と中断再開の実行制御

## ADDED Requirements

### Requirement: Verify ループは上限 3 周と budget ガードで暴走を防止する
Workflow スクリプトの Verify ループは `while` + 明示上限（3 周）+ `budget.remaining()` ガードで構成しなければならない（MUST）。上限到達または budget 枯渇時は、ループを停止して現在の状態（PASS/FAIL 内訳・残課題）をユーザーに報告しなければならない（MUST）。LLM の自制やユーザーの手動停止に依存した無上限ループを実装してはならない（MUST NOT）。

#### Scenario: 上限 3 周到達で必ず停止し状態が報告される
- **WHEN** verifier の FAIL が続き Verify → Build 修正のループが 3 周に到達する
- **THEN** ループは必ず停止する（4 周目は実行されない）
- **THEN** 到達時点の検証状態と残課題がユーザーに報告される

#### Scenario: budget 枯渇でループが早期停止する
- **WHEN** Verify ループの周回前チェックで `budget.remaining()` が不足している
- **THEN** 上限 3 周に達していなくてもループを停止し、budget 枯渇による停止であることをユーザーに報告する

### Requirement: 中断再開は resumeFromRunId を一次手段とする
run の中断再開は Workflow の `resumeFromRunId` を一次手段としなければならない（MUST）。そのために exec は workflow 起動時に runId を `_longruns/<run>/` 内に記録しなければならない（MUST）。checkpoint.md の散文パースによる状態復元を再開手段として実装してはならない（MUST NOT）。

#### Scenario: 再開時に完了済み change の builder が再実行されない
- **WHEN** 実行を中断した後、記録済み runId を使って `resumeFromRunId` で再開する
- **THEN** 完了済み change の builder agent は再実行されず、未完了のステップから実行が継続される

#### Scenario: runId がランディレクトリに記録される
- **WHEN** exec が workflow を起動する
- **THEN** その workflow の runId が `_longruns/<run>/` 内のファイルに記録され、後続の再開で参照できる

### Requirement: checkpoint.md は人間向け監査ログに格下げする
checkpoint.md は人間向け監査ログとして書き続けなければならない（MUST）が、機械可読契約からは除外する。exec / workflow スクリプトのいかなるコードパスも checkpoint.md を grep/sed 等でパースして状態復元・分岐判断に使用してはならない（MUST NOT）。decisions.md は現行どおり維持する。

#### Scenario: 実行中も監査ログとして更新され続ける
- **WHEN** workflow の各フェーズが進行する
- **THEN** checkpoint.md にフェーズの進捗が人間が読める形式で追記される

#### Scenario: 機械可読パースのコードパスが存在しない
- **WHEN** 書き換え後の exec.md・スクリプトテンプレート・同梱スクリプトを検査する
- **THEN** checkpoint.md を grep/sed/正規表現で解析して制御フローを決めるロジックが存在しない（旧形式の互換読み取りも提供しない）
