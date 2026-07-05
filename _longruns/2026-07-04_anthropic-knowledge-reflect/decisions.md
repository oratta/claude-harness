# Decisions — anthropic-knowledge-reflect run

## D-E1: 全 change を単一 worktree（この cwd）で直列実施

- 日付: 2026-07-05
- 背景: cwd 自体が専用 worktree（branch `oratta/anthropic論文をハーネスに反映`、Draft PR #9 バックアップ済み）。change 依存は 1 → {2,3} → 4 → 5 の直列支配的な DAG。
- 判断: change ごとの worktree 分割はせず、全 builder がこのブランチに順次コミットする。CHANGES_JSON の worktree は全 change で cwd を指す。
- 理由: (1) build-verify workflow は 1 起動内で直列に builder を回すため、change 間依存（後続が前段の成果物の上に建つ）は同一ブランチが自然。(2) Draft PR #9 への逐次 push で CLAUDE.md のバックアップ運用を満たす。(3) マージ操作（要明示承認）を run 中に挟まなくて済む。

## D-E2: モデル割り当ての単一値への縮約（テンプレート制約）

- 日付: 2026-07-05
- 背景: plan.md の割り当て表は change × ロールの 15 セル（builder: change-2/3/5=sonnet, change-1/4=inherit。verifier: change-1/4=sonnet, change-2/3/5=haiku。reviewer: 全て inherit）。一方 v6 の build-verify テンプレートはロール毎に 1 つの `*_MODEL` 埋め込みポイントしか持たない（exec.md D6: 本 change ではデフォルト固定）。
- 判断:
  - `BUILDER_MODEL = null`（inherit）— plan が「安全設計が critical」とする change-1/4 の要求に全体を合わせる（安全性 > コスト最適化）。
  - `VERIFIER_MODEL = 'sonnet'` — Verify ループは run 全体の検証であり、sonnet を要求する change-1/4 を含むため要求中の最上位ティアを採用。
  - `BROWSER_VERIFIER_MODEL = null` — 割り当て表に行が無いため render の既定値（inherit）。
  - `REVIEWER_MODEL = null` — 表の全行が inherit。
- 理由: plan.md の意思決定ガイドライン「安全性 > 忠実さ > シンプルさ」。ティア縮約はコスト面の劣化のみで品質面の劣化はない（下位ティア指定 change を上位で実行する方向の縮約）。
- 備考: change 毎の `opts.model` 粒度対応はテンプレート側の将来課題（openspec/backlog.md 行き）。
