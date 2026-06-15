# workflow-tool-reference — Workflow ツール実機検証結果の固定

## ADDED Requirements

### Requirement: Workflow ツールの実機検証結果をエビデンス付きで固定する
本 change の実装着手前に、Workflow ツールの作法を実環境で確認し（最小の hello-world workflow を 1 本起動して挙動観測）、確定したシグネチャと制約を `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` に固定しなければならない（MUST）。記録には実行した workflow とその出力（エビデンス）を含めなければならない（MUST）。網羅対象: `agent` / `pipeline` / `parallel` の引数、`opts` で渡せるキー（schema / model / agentType 等）、`resumeFromRunId` の挙動、meta ピュアリテラル制約、`Date.now()` 不可制約、ネスト 1 段制約。

#### Scenario: 実機検証結果がエビデンス付きで記録されている
- **WHEN** 実装タスクの着手前に `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` を確認する
- **THEN** 実際に起動した hello-world workflow のスクリプトとその実行出力が記録されている
- **THEN** `agent` / `pipeline` / `parallel` のシグネチャ、`opts` の利用可能キー、`resumeFromRunId` の挙動、meta ピュアリテラル / Date.now 不可 / ネスト 1 段の各制約が確定事項として記載されている

### Requirement: 以降の実装は workflow-tool-reference.md を一次ソースとする
exec の書き換え・スクリプトテンプレート・schema 連携の実装では、Workflow ツールのシグネチャと制約を `workflow-tool-reference.md` から参照しなければならない（MUST）。記憶や推測でシグネチャを書いてはならない（MUST NOT）。reference に記載のない挙動が必要になった場合は、追加の実機検証を行って reference を更新してから実装する。

#### Scenario: 実装が reference に基づいて行われる
- **WHEN** workflow スクリプト生成ロジックを実装・レビューする
- **THEN** 使用している API シグネチャ・opts キー・制約が全て workflow-tool-reference.md に記載済みのものである

#### Scenario: 未記載の挙動は再検証してから使う
- **WHEN** 実装中に reference に記載のない Workflow ツールの挙動が必要になる
- **THEN** 先に実機検証を行い、エビデンス付きで reference を更新してから実装に使用する
