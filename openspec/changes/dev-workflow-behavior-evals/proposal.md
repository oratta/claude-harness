## Why

今のテスト（bats）は文面と構造の検査が中心で、スキルやルールを書き換えたあとに Claude が実際にそのとおり動くか（発火すべき場面で発火するか）は、手で `claude -p --plugin-dir` を叩いて確かめている。常時注入を減らす作業（#370）のたびに、効きが落ちていないかを測る手段がない。Claude Code 2.1.293 の `claude plugin eval` で、過去の失敗から作ったお題集を実行し、スコアを数字で残せる。

## What Changes

- `plugins/dev-workflow/evals/` に、develop・pr-review-gate の発火と destructive-git-guard の止まりを測るお題を 5 件以上、新規に置く
- `plugins/casting/evals/` に、返信前チェックで主へ上げるべき論点を上げるかを測るお題を 1 件以上、新規に置く
- 実行方法・費用の目安・結果の読み方を `docs/` に書く
- 初回実行（`--max-cost-usd 10`、`--ablation with-without`）の結果（スコア・ablation の差・費用）を PR 本文に記録する
- CI は落とさない（閾値でのゲートはしない）。スコアと ablation の差を記録する用途から始める

## Capabilities

### New Capabilities
- `dev-workflow-behavior-evals`: `claude plugin eval` 用のお題集（dev-workflow・casting）の置き場所・構成・測定項目・実行と記録の契約

### Modified Capabilities

なし（既存 capability の要件は変えない。`destructive-git-hook` の hook は測定対象として参照するだけ）

## Impact

- 新規: `plugins/dev-workflow/evals/*/`、`plugins/casting/evals/*/`、`docs/` の実行手順ページ、`.gitignore` への `evals/results/`
- 既存コードは変えない。プラグインの `description` は触らない（常時注入の予算 `tests/injection-budget.txt` に影響しない）
- 実行には実費がかかる（上限 10 USD）
