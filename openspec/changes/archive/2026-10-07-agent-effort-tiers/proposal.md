## Why

`plugins/dev-workflow/references/model-tiers.md` はモデルの段（`model`）だけを決めていて、effort（推論の深さ）は親セッションの値をそのまま継いでいる。実装やゲート実行のように答えの型が決まっている工程も、最終検証と同じ深さで考えて消費する。公式記事 Spending your effort は、effort を上げても概念の取り違えは減らず、深く考えさせるのは最終検証のような判断が集中する工程だけにするよう勧めている。役ごとに effort を決めて、同じ品質のまま消費を減らす。

## What Changes

- `model-tiers.md` に、役ごとの effort の初期値と、呼び出し単位で上書きする方法（Agent ツールの `effort` 引数、Claude Code 2.1.292）を書く節を足す
- `plugins/dev-workflow/agents/` の `worker.md` / `gate-runner.md` / `reviewer.md` / `decider.md` の frontmatter に `effort:` を 1 行足す。初期値は worker / gate-runner = `medium`、reviewer / decider = `high`
- `dev-workflow-decider-agent` の「frontmatter は name・description・model・tools を持つ」を、`effort: high` も持つ形に改める
- 変更の記録を `plugins/dev-workflow/changes/711.md` に書く

## Capabilities

### New Capabilities
- `dev-workflow-agent-effort`: dev-workflow の 4 つの agent 定義が役ごとの `effort` を frontmatter に持ち、`model-tiers.md` が対応表と上書き方法の正本になる

### Modified Capabilities
- `dev-workflow-decider-agent`: 決める役の frontmatter に `effort: high` が加わる

## Impact

- 触るファイル: `plugins/dev-workflow/references/model-tiers.md`、`plugins/dev-workflow/agents/{worker,gate-runner,reviewer,decider}.md`、`plugins/dev-workflow/changes/711.md`
- 常時注入の予算（`tests/injection-budget.bats`）は `description` 行と `rules/` などだけを数えるので、frontmatter の `effort:` 行と `model-tiers.md`（常時注入ではない）は予算に影響しない。予算ファイルは動かさない
- `manual-codex-develop` / `codex-role-profiles` の「profile の effort は監査値で Agent 引数に変換しない」は変えない。profile の effort は今回の frontmatter 初期値と同じ値（Claude の W・G = medium、レビュー・決める役 = high）で、食い違わない
- #614（epic #616）も `model-tiers.md` を触る。別の節への追記なら機械マージできるが、同じ表を書き換えると衝突する（マージ前に main と照合する）
