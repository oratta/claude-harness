## Why

1 本の PR にかかったトークン量を機械で出す手段が無く、PR #268 は 12 体のサブエージェント・1,091 リクエスト・122,955,450 トークンを使ったことが、人間がトランスクリプトを手で合計して初めて分かった（#281）。PR-A（#351）で入ったレビュー周回数のキャップでは、周回が少なくても 1 周が重い場合や W の再開が繰り返される場合を捕まえられない。既存の `subagent-context.sh` は 1 体の「最後のリクエストのコンテキスト量」しか測らず、累計ではない。

## What Changes

- 新スクリプト `plugins/dev-workflow/scripts/pr-token-budget.sh <記録先番号>...` を追加する。記録先（issue または Draft PR）に紐付く全サブエージェントの全リクエストの usage を合計し、体数・合計・上限・超過の有無を 1 行 JSON で出す。合計が上限を超えたら exit 2
- PR とサブエージェントの紐付けは、**spawn 時の Agent ツールの `description` に記録先番号 `#N` を入れる**規約で行う。Claude Code が各サブエージェントの `agent-<id>.meta.json` に `description` を書き残すので、スクリプトはそれを読むだけで紐付けが取れる（記録先へのコメントや worktree のパスを使う候補を採らなかった理由は design.md）
- develop の本体手順（`skills/develop/SKILL.md`）に、W / R1 / G / G のレビュアー / 決める役を spawn または SendMessage で再開する**前に毎回**このスクリプトを実行し、exit 2 なら spawn / SendMessage せず `needs-approval` を付けて主に「続けるか、範囲外として閉じるか」の 1 択を出して止まる手順を足す。問いの形は PR-A（#351）に揃える
- 上限の既定値は 30,000,000 トークン（環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP` で変更可）。主が「続ける」を選んだら、本体は記録先に `PR トークン上限: <新上限>` をコメントし、以後その値を `--cap` で渡す
- bats で固定のトランスクリプトに対する合計・体数・exit code を固定する

## Capabilities

### New Capabilities
- `dev-workflow-pr-token-budget`: 記録先単位のサブエージェント累計トークンの集計と、上限超で develop の本体が次のサブエージェントを起こす前に止まる手順

### Modified Capabilities
（なし。develop 本体の手順への追記は新 capability の要件として定め、`dev-workflow-develop` の既存要件の文言は変えない）

## Impact

- 追加: `plugins/dev-workflow/scripts/pr-token-budget.sh`、`plugins/dev-workflow/tests/pr-token-budget.bats`
- 変更: `plugins/dev-workflow/skills/develop/SKILL.md`（spawn / SendMessage 前の計測手順と description の規約）、`plugins/dev-workflow/.claude-plugin/plugin.json`（バージョン）、`plugins/dev-workflow/CHANGELOG.md`
- 依存: python3（既存スクリプトと同じ）、git（リポジトリ識別に `git rev-parse --git-common-dir`）。GitHub API は呼ばない
- 計測に入らないもの: メインセッション（本体）自身の消費、Codex CLI 経由のレビュー（Claude のトランスクリプトに残らない）、Workflow 経由のサブエージェント
