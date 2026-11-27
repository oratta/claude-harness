## Why

1 本の PR にかかったトークン量を機械で出す手段が無く、PR #268 は 12 体のサブエージェント・1,091 リクエスト・122,955,450 トークンを使ったことが、人間がトランスクリプトを手で合計して初めて分かった（#281）。PR-A（#351）で入ったレビュー周回数のキャップでは、周回が少なくても 1 周が重い場合や W の再開が繰り返される場合を捕まえられない。既存の `subagent-context.sh` は 1 体の「最後のリクエストのコンテキスト量」しか測らず、累計ではない。

## What Changes

- 新スクリプト `plugins/dev-workflow/scripts/pr-token-budget.sh <記録先番号>...` を追加する。記録先（issue または Draft PR）に紐付く全サブエージェントの全リクエストの usage と、その記録先のために使った Codex の消費を合計し、Claude 分・Codex 分の内訳・体数・合計・上限・超過の有無を 1 行 JSON で出す。上限は合計に 1 本で掛け、超えたら exit 2
- PR とサブエージェントの紐付けは、**spawn 時の Agent ツールの `description` に記録先番号 `#N` を入れる**規約で行う。Claude Code が各サブエージェントの `agent-<id>.meta.json` に `description` を書き残すので、スクリプトはそれを読むだけで紐付けが取れる（記録先へのコメントや worktree のパスを使う候補を採らなかった理由は design.md）
- Codex の消費は、本体が Codex を呼ぶたびに記録先へ残す 1 行コメント `Codex 消費: <thread_id> <トークン数または ->` で紐付ける。本体は計測の前にそのコメントを集めてファイルに書き、`--codex-records` で渡す（スクリプトは GitHub を読まない）。トークン数は codex-worker の結果 JSON の `usage.total.totalTokens` を書き、分からないとき（G が Bash から直接 `codex exec` を呼んだ場合）は `-` にしてスクリプトが `$CODEX_HOME/sessions` の rollout から読む。codex-worker は runtime CODEX_HOME をジョブ後に消すので rollout が残らず、rollout の cwd で束ねる案は採れない（design.md）
- develop の本体手順（`skills/develop/SKILL.md`）に、その記録先のためにサブエージェントを spawn する・SendMessage で再開する・Codex executor へ委譲する**前に毎回**（役割と executor を問わない）このスクリプトを実行し、exit 2 なら spawn / SendMessage / Codex への委譲をせず `needs-approval` を付けて主に「続けるか、範囲外として閉じるか」を出して止まる手順を足す。2 択は PR-A（#351）と同じ。判断材料は合計・体数・上限・残工程・推奨（#354 で判断材料なしの 1 択は禁じられたため）
- 上限の既定値は 30,000,000 トークン（Claude 分と Codex 分の合計に対する値。環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP` で変更可）。主が「続ける」を選んだら、本体は記録先に `PR トークン上限: <その時点の合計 ＋ 直前の計測で使った上限>` をコメントし、以後その値を `--cap` で渡す
- bats で固定のトランスクリプトと Codex の記録・rollout に対する合計・内訳・体数・exit code を固定する

## Capabilities

### New Capabilities
- `dev-workflow-pr-token-budget`: 記録先単位のサブエージェント累計トークンと Codex の消費の集計と、その合計の上限超で develop の本体が次のサブエージェントを起こす・Codex に委譲する前に止まる手順

### Modified Capabilities
（なし。develop 本体の手順への追記は新 capability の要件として定め、`dev-workflow-develop` の既存要件の文言は変えない）

## Impact

- 追加: `plugins/dev-workflow/scripts/pr-token-budget.sh`、`plugins/dev-workflow/tests/pr-token-budget.bats`
- 変更: `plugins/dev-workflow/skills/develop/SKILL.md`（spawn / SendMessage / Codex 委譲の前の計測手順、description の規約、Codex を呼んだあとの `Codex 消費:` コメント）、`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（G が Bash から呼んだ Codex の thread_id を return に書く）、`plugins/dev-workflow/.claude-plugin/plugin.json`（バージョン）、`plugins/dev-workflow/CHANGELOG.md`
- 依存: python3（既存スクリプトと同じ）、**git 2.31 以上**（リポジトリ識別に `git rev-parse --path-format=absolute --git-common-dir` を使う。cost-ledger と同じ要件）。GitHub API は呼ばない
- 変更しないもの: `scripts/codex-worker.py` と adapter（`references/codex-develop.md`）。worker は結果を保存しない（`openspec/specs/codex-worker/spec.md`）、adapter は独自の品質ゲートを置かない（`openspec/specs/manual-codex-develop/spec.md`）ため、計測と `Codex 消費:` の記録は本体手順（SKILL.md）に置く
- 計測に入らないもの: メインセッション（本体）自身の消費、Workflow 経由のサブエージェント、結果 JSON を受け取れずに終わった Codex 委譲（thread_id が分からない）
