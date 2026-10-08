## 1. 前提の確認

- [ ] 1.1 eval の run で dev-workflow の PreToolUse hook が働くかを 1 ケースで確かめる（`--runs 1 --ablation none --allow-tools Bash`）。結果で design の Decision 4 を確定する。触る範囲: `plugins/dev-workflow/hooks/hooks.json`（全体）、`plugins/dev-workflow/evals/`（新規）

## 2. dev-workflow のお題

- [ ] 2.1 develop が発火すべき依頼のお題を 2 件以上作る（`tool_used: Skill` と結果 grader）。触る範囲: `plugins/dev-workflow/evals/develop-*/`（新規）
- [ ] 2.2 pr-review-gate が発火すべき依頼のお題を 1 件以上作る。触る範囲: `plugins/dev-workflow/evals/pr-review-gate-*/`（新規）
- [ ] 2.3 破壊的 git 操作の前で止まるお題を 2 件以上作る。触る範囲: `plugins/dev-workflow/evals/destructive-git-*/`（新規）、`plugins/dev-workflow/hooks/hooks.json`（参照）

## 3. casting のお題

- [ ] 3.1 主へ上げるべき論点と上げなくてよい論点のお題を 1 件以上作る（`llm` grader）。触る範囲: `plugins/casting/evals/*/`（新規）

## 4. docs と設定

- [ ] 4.1 実行方法・費用の目安・読み方の docs を書く。触る範囲: `docs/plugin-evals.md`（新規）
- [ ] 4.2 `evals/results/` を `.gitignore` に追加する。触る範囲: `.gitignore`（末尾）
- [ ] 4.3 お題の構造（件数・graders の有無）を検査する bats を追加する。触る範囲: `plugins/dev-workflow/tests/behavior-evals.bats`（新規）

## 5. 初回実行と記録

- [ ] 5.1 `claude plugin eval plugins/dev-workflow --max-cost-usd 10 --json <path> --no-publish` を実行し、exit 0/1 と `aggregates.overallScore` を確認する
- [ ] 5.2 casting も同様に実行する
- [ ] 5.3 スコア・ablation の差・費用を PR 本文に貼る
