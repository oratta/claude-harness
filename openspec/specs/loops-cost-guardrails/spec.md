# loops-cost-guardrails Specification (Delta)

## ADDED Requirements

### Requirement: cost-guardrails.md が公式トークン管理 6 項目を収録している

`plugins/loops/references/cost-guardrails.md` が存在し、公式記事「Getting started with loops」のトークン管理ベストプラクティス 6 項目を、`research/loop-engineering.md` 冒頭の公式記事セクションを一次ソースとして列挙しなければならない (MUST)。6 項目には少なくとも「ルーチン実行頻度を必要最小限にする」「決定論的作業はスクリプト化する」「大規模実行前にパイロット実行する」を含むこと。各項目は識別可能な見出しまたは番号付きリストで数えられる形式で記載すること。

#### Scenario: 6 項目が数えられる形式で存在する

- **WHEN** ユーザーが `plugins/loops/references/cost-guardrails.md` のトークン管理セクションの項目（見出しまたは番号付きリスト）を数える
- **THEN** ちょうど 6 項目が列挙されている

#### Scenario: 主要 3 項目の文言が確認できる

- **WHEN** ユーザーが `cost-guardrails.md` に対して「頻度」「スクリプト化」「パイロット」をそれぞれ grep する
- **THEN** 3 語すべてが 6 項目の記述内でヒットする

### Requirement: cost-guardrails.md がコスト定量事実を記載している

`cost-guardrails.md` は、公式記事由来のコスト定量事実「ループはチャットの約 4 倍のトークンを消費する」「マルチエージェント構成は約 15 倍のトークンを消費する」を記載しなければならない (MUST)。

#### Scenario: 定量事実が記載されている

- **WHEN** ユーザーが `cost-guardrails.md` に対して「4倍」（または「約 4 倍」）と「15倍」（または「約 15 倍」）を grep する
- **THEN** 両方の倍率がループ / マルチエージェントのトークン消費に関する文脈でヒットする

### Requirement: cost-guardrails.md が /usage・/workflows でのコストレビュー手順を記載している

`cost-guardrails.md` は、稼働中のループのコストを人間がレビューする手順として、`/usage` によるトークン消費確認と `/workflows` による実行状況確認の 2 つを記載しなければならない (MUST)。手順は「いつ確認するか（例: 新レシピのパイロット実行後・定常運用の定期見直し時）」を含むこと。

#### Scenario: レビュー手順に 2 コマンドが含まれる

- **WHEN** ユーザーが `cost-guardrails.md` に対して `/usage` と `/workflows` をそれぞれ grep する
- **THEN** 両コマンドがコストレビュー手順の記述内でヒットする

### Requirement: cost-guardrails.md にモデル ID を直書きしない

`cost-guardrails.md` に具体的なモデル ID（`claude-` で始まる識別子）を記載してはならない (MUST NOT)。モデルティアに言及する必要がある場合は `plugins/longrun/references/model-tiers.md` への参照で行うこと。

#### Scenario: モデル ID のハードコードが無い

- **WHEN** ユーザーが `cost-guardrails.md` に対して `claude-` で始まるモデル ID 文字列を grep する
- **THEN** ヒットは 0 件である
