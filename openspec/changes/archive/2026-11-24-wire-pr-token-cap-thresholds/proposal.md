# Proposal

## Why

#1800 は、トークンのしきい値をモデル（固定 ID）ごとに引き、値を決めたときのモデルと違えば検証のやり直しを知らせることを求める。change 1（PR #1804）で表 `references/token-thresholds.json` と共通の解決処理 `scripts/token_thresholds.py` を作り、change 2（PR #1808）で文脈の上限・強制停止（`subagent-context.sh`・`context-tripwire.sh`）をつないだ。残る記録先 1 件の累計上限（`pr-token-budget.sh`）は、まだ `--cap` > `DEV_WORKFLOW_PR_TOKEN_CAP` > 固定の 30000000 で決まり、使ったモデルと表の根拠モデルの違いを知らせない。この change が #1800 の最後の PR になる（受け持ちの正本は https://github.com/oratta/claude-harness/issues/1800#issuecomment-7121511137 ）。

## What Changes

- `pr-token-budget.sh` は、数えたサブエージェントの各リクエスト（usage を合計したのと同じ assistant レコード）の `message.model` を集め、モデルごとに共通の解決処理で `pr_token_cap` を引く。値が分かれたら最も小さい値を上限にする。数えたリクエストが無いときは不明モデル（fallback 行）の値を診断なしで使う
- 上限の優先順位は `--cap` > `DEV_WORKFLOW_PR_TOKEN_CAP` > モデル行 / fallback。env の扱い（空白だけは未設定・前後空白付きの ASCII 非負整数は有効・0 を通す）は共通の解決処理にそろえる。有効な `--cap` は不正な env も遮る
- 未知モデル・再検証の診断は、上書きのときも呼び出しごとに stderr に出し、実行中の同梱プラグインの手順 `token-thresholds.md` の絶対パスを示す。stdout の 1 行 JSON のキーは変えない
- 表・上書きの不正と、共通処理のロード失敗・API 欠損（`resolver_unavailable`）は、理由を stderr に、`error` の JSON を stdout に出して exit 1（`pr-token-budget.md` の「計測できない」扱い）
- 本体が「続ける」のあとに使う新上限の「直前の計測で上限に使った値」は、直前の計測の出力 `cap` とする
- `token-thresholds.md` の「未配線」の注記を文脈の上限・強制停止と累計上限の両方について接続後の事実に直し、`decision-criteria.md` の累計上限の分、`pr-token-budget.md` の上限の決まり方と診断の扱いを直す
- 既定の上限値（30000000）、エピックの子の権限（60000000）、exit 2 のあとの止まり方は変えない。#1802 の粒度の計算には手を出さない

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-token-budget`: 「出力と exit code」の上限の決まり方と、「本体は spawn と再開の前に測り、上限超なら止まる」の新上限の計算に使う直前の上限を、共通の解決処理と出力の `cap` に合わせて直す
- `dev-workflow-token-thresholds`: 累計計測がモデル別の値を引く・上書きの優先順位・診断・失敗の扱いの要件を足し、入口の文書の「未配線」の記述を接続後の事実に直す

## Impact

- `plugins/dev-workflow/scripts/pr-token-budget.sh`（上限の解決、モデルの収集、診断、失敗の扱い、ヘッダの説明）
- `plugins/dev-workflow/tests/pr-token-budget.bats`（モデル別・fallback・上書き・診断・失敗の検査。既存テストは stderr を分けて JSON を読む形にする）
- `plugins/dev-workflow/skills/develop/references/pr-token-budget.md`・`token-thresholds.md`・`decision-criteria.md`
- `pr-token-measure.sh` は stdout と exit code をそのまま返し stderr を素通しするので変えない（テストはスタブなので影響なし）
