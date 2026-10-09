# dev-workflow-behavior-evals Specification

## Purpose
TBD - created by archiving change dev-workflow-behavior-evals. Update Purpose after archive.
## Requirements
### Requirement: dev-workflow のお題集を置く

`plugins/dev-workflow/evals/` に `claude plugin eval` 用のお題を置かなければならない（MUST）。各お題はディレクトリ 1 つで、`prompt.md` と `graders/*.md` を持つ。お題は 5 件以上とし、develop の発火、pr-review-gate の発火、破壊的 git 操作の前で止まること、のそれぞれを少なくとも 1 件含む。ただし、プラグインの PreToolUse hook が eval の run で働かないと実機で確かめられたときは、破壊的 git 操作のお題は作らず、その理由を docs に書く（この場合、破壊的 git のお題は 0 件でよい）。

#### Scenario: お題の件数
- **WHEN** `ls plugins/dev-workflow/evals/*/prompt.md | wc -l` を実行する
- **THEN** 5 以上を返す

#### Scenario: 各お題に採点がある
- **WHEN** `plugins/dev-workflow/evals/` 配下の任意のお題ディレクトリを見る
- **THEN** `prompt.md` があり、`graders/*.md` が 1 件以上あり、各 grader の frontmatter に `type:` がある（読み込めることは初回実行の exit code と stderr で確かめる）

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

初回実行は次の完全なコマンドで行い、exit 0 または 1 で終わらなければならず（MUST）、出力 JSON に `aggregates.overallScore` を含む。exit 2（費用上限による部分実行）は受け入れない。

```
claude plugin eval plugins/dev-workflow --scaffold --allow-tools "Bash(git *)" --model sonnet --trust-plugin --max-cost-usd 10 --json <path>.json --no-publish
```

`--scaffold` は使い捨ての git repo を作るスクリプトを走らせ、`--allow-tools "Bash(git *)"` は git の実行だけを許可し、`--trust-plugin` は `--json` 下で初回の信頼確認が出せず exit 1 になるのを避け、`--model` は子セッションのモデルを固定する。issue 本文のコマンドは最低限のフラグとして読む。

#### Scenario: 初回実行
- **WHEN** 上記コマンドを実行する
- **THEN** exit code が 0 か 1 で、JSON の `aggregates.overallScore` が存在する

#### Scenario: 破壊的 git のお題が測れる
- **WHEN** hook が eval の run で働くと確かめられたうえで、同じコマンドで破壊的 git のお題をプラグインありで実行する
- **THEN** scaffold が成功し、git の呼び出しが `not granted` にならず、trace に hook の拒否が出る（プラグインなしの腕との差は条件に使わない。なしの腕でも Claude 自身が断る可能性があり、差は記録のみ）

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

