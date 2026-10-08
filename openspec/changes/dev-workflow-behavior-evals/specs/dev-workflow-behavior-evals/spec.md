## ADDED Requirements

### Requirement: dev-workflow のお題集を置く

`plugins/dev-workflow/evals/` に `claude plugin eval` 用のお題を置かなければならない（MUST）。各お題はディレクトリ 1 つで、`prompt.md` と `graders/*.md` を持つ。お題は 5 件以上とし、develop の発火、pr-review-gate の発火、破壊的 git 操作の前で止まること、のそれぞれを少なくとも 1 件含む。

#### Scenario: お題の件数
- **WHEN** `ls plugins/dev-workflow/evals/*/prompt.md | wc -l` を実行する
- **THEN** 5 以上を返す

#### Scenario: 各お題に採点がある
- **WHEN** `plugins/dev-workflow/evals/` 配下の任意のお題ディレクトリを見る
- **THEN** `graders/` に grader が 1 つ以上あり、`claude plugin eval` がそのお題を読み込める

### Requirement: 発火のお題は発火と結果の両方を採点する

スキルの発火を測るお題は、`tool_used: Skill` の grader に加えて、結果を測る grader（`llm` または `regex`）を 1 つ以上持たなければならない（MUST）。依頼文はスキル名を含めず、実際の失敗の言い回しから作る。

#### Scenario: ablation で採点が空にならない
- **WHEN** `--ablation with-without` で実行する
- **THEN** 発火を測るお題にも採点に使われる grader が残り、Δ を計算できる

### Requirement: casting のお題集を置く

`plugins/casting/evals/` に、返信前チェックで主へ上げるべき論点を上げるかを測るお題を 1 件以上置かなければならない（MUST）。判定は `llm` grader で行い、上げるべき論点と、上げなくてよい論点の両方を含める。

#### Scenario: casting のお題の件数
- **WHEN** `ls plugins/casting/evals/*/prompt.md | wc -l` を実行する
- **THEN** 1 以上を返す

### Requirement: 実行は部分実行にならず JSON にスコアが残る

`claude plugin eval plugins/dev-workflow --max-cost-usd 10 --json <path> --no-publish` は exit 0 または 1 で終わらなければならず（MUST）、出力 JSON に `aggregates.overallScore` を含む。exit 2（費用上限による部分実行）は受け入れない。

#### Scenario: 初回実行
- **WHEN** 上記コマンドを実行する
- **THEN** exit code が 0 か 1 で、JSON の `aggregates.overallScore` が存在する

### Requirement: CI を閾値で落とさず、結果を記録する

お題集は CI のゲートに組み込まず、閾値による合否判定をしない（MUST NOT）。初回の結果（スコア・ablation の差・かかった費用）を PR 本文に記録する。

#### Scenario: CI に組み込まない
- **WHEN** `.github/workflows/` を調べる
- **THEN** `claude plugin eval` を実行する workflow がない

#### Scenario: 結果の記録
- **WHEN** 初回実行が終わる
- **THEN** PR 本文に overallScore・with と without の差・費用が書かれている

### Requirement: 実行方法を docs に書く

`docs/` に、実行コマンド・`--max-cost-usd` の上限・費用の目安・結果の読み方（Δ は合否に使わず記録する）・`evals/results/` を git に入れないことを書かなければならない（MUST）。

#### Scenario: docs の記載
- **WHEN** docs のページを読む
- **THEN** 実行コマンド、費用の目安、Δ の扱いが書かれている
