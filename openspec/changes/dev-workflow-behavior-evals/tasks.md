## 1. 前提の確認

- [ ] 1.1 eval の run で dev-workflow の PreToolUse hook が働くかを 1 ケースで確かめる（`--runs 1 --ablation none --scaffold --allow-tools "Bash(git *)" --model sonnet --trust-plugin`）。結果で design の Decision 6 の分岐（測る／外す）を確定する。触る範囲: `plugins/dev-workflow/hooks/hooks.json`（全体）、`plugins/dev-workflow/evals/`（新規）

## 2. dev-workflow のお題

- [ ] 2.1 develop が発火すべき依頼のお題を 2 件以上作る（`tool_used: Skill` と、記録先を確かめる流れかを見る結果 grader）。触る範囲: `plugins/dev-workflow/evals/develop-*/`（新規）
- [ ] 2.2 pr-review-gate が発火すべき依頼のお題を 1 件以上作る。触る範囲: `plugins/dev-workflow/evals/pr-review-gate-*/`（新規）
- [ ] 2.3 破壊的 git 操作の前で止まるお題を 2 件以上作る（scaffold で使い捨て repo と未コミット変更を用意し、`regex` の `target: {source: file, path}` で判定）。1.1 で hook が働かないと分かった場合は作らず、docs に理由を書く。触る範囲: `plugins/dev-workflow/evals/destructive-git-*/`（新規）、`plugins/dev-workflow/hooks/hooks.json`（参照）

## 3. casting のお題

- [ ] 3.1 主へ上げるべき論点と上げなくてよい論点のお題を 1 件以上作る（`llm` grader。ルール要点を `append_system_prompt` で両腕に入れる）。触る範囲: `plugins/casting/evals/*/`（新規）

## 4. docs と設定

- [ ] 4.1 完全な実行コマンド・各フラグの理由・費用の見積りと実費・実行した Claude Code の版・読み方（Δ は記録のみ）の docs を書く。触る範囲: `docs/plugin-evals.md`（新規）
- [ ] 4.2 `evals/results/` を `.gitignore` に追加する。触る範囲: `.gitignore`（末尾）
- [ ] 4.3 変更の記録を書く。触る範囲: `plugins/dev-workflow/changes/709.md`（新規）
- [ ] 4.4 お題の構造（件数・`prompt.md` と `graders/*.md` の有無・各 grader の `type:`）を検査する bats を追加する。触る範囲: `plugins/dev-workflow/tests/behavior-evals.bats`（新規）

## 5. 初回実行と記録

- [ ] 5.1 design Decision 2 の完全なコマンドで実行し、exit 0/1 と `aggregates.overallScore` を確認する
- [ ] 5.2 casting も同様に実行する（`--scaffold` / `--allow-tools` は不要なら外す）
- [ ] 5.3 スコア・ablation の差・費用を PR 本文に貼る
