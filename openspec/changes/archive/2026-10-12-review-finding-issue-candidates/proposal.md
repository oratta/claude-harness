## Why

pr-review-gate のゲート役は、マージを止めない指摘を無条件で follow-up issue にしている。issue #973 で主と決めた 5 段の振り分けは、新しい issue を作る前に「同じ場所を直す open の issue が既にあるか」を調べる段（エピックに効く指摘を既存 issue との関係で分ける段と、既存 issue に相乗りする段）を持つ。この調べ方をゲート役の手作業にすると、検索語・件数の上限・外す番号が周ごとにぶれるので、スクリプト 1 本に固定する。

issue #973（エピック）は 3 つの change に分けて進める。この change はそのうち最初の 1 つで、記録先は子 issue #984 である。候補探しのスクリプトだけを足す。振り分けの手順（`stages/triage.md` など）からこのスクリプトを呼ぶ変更は、次の change `gate-nonblocking-finding-triage` が行う。

## What Changes

- `plugins/dev-workflow/scripts/review-issue-candidates.sh` を新しく置く。指摘が指すファイルのパスの一覧を受け取り、パスごとに open の issue を 1 回検索して、番号と題名を最大 15 件返す。本文は返さない
- 候補から外す番号（いまの PR と記録先 issue）を受け取り、結果から除く
- エピックの番号を受け取ると、各候補がそのエピックの子かどうかを行に添える。子だけに絞る指定も受け取る
- `plugins/dev-workflow/tests/review-issue-candidates.bats` を足す（`gh` は偽物に差し替える）
- `plugins/dev-workflow/changes/984.md` に変更の記録を書く。版は上げない
- 既存のスキル・手順書・スクリプトは変えない。このスクリプトを呼ぶ箇所は、この change の時点ではまだ無い

## Capabilities

### New Capabilities

- `dev-workflow-review-issue-candidates`: レビューの指摘が指すファイルについて、同じ場所を直す open の issue の候補（番号と題名）を返すスクリプトの入出力・検索のしかた・終了コードの規約

### Modified Capabilities

（なし。`dev-workflow-pr-review-gate` の要件は次の change `gate-nonblocking-finding-triage` で変える）

## Impact

- 足すファイル: `plugins/dev-workflow/scripts/review-issue-candidates.sh`、`plugins/dev-workflow/tests/review-issue-candidates.bats`、`plugins/dev-workflow/changes/984.md`
- 依存: `gh`（`gh issue list` と `gh api`）と `jq`。どちらも dev-workflow の既存スクリプトが使っている
- 常時注入される文書（`rules/`・`CLAUDE.md`・`output-styles/`・各種 `description`）は変えないので、`tests/injection-budget.txt` の予算は動かさない
- 追加の LLM コスト: この change だけでは 0（呼ぶ箇所が無い）。次の change で呼ぶようになると、ゲート役が題名を読む分がファイル 1 つあたり約 700〜1,000 トークン（issue #973 の見積もり）
