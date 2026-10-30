# Proposal

## Why

一周目の `照合表` は、変更点ごとに検索語の全ヒットを本文つきで返すことを求める。語の置き換えが広い PR ではこの表が返答に収まらず、指摘が確定していても `review-incomplete` で止まる。実例の genetta-inc/flatmate PR #1779 は全ヒット表が 2,554 行・約 47 万字で、Claude のレビュアー 3 体がコンテキスト上限で打ち切られ、Codex の補足は 2,364 行分が未掲載で終わり、約 1,200 万トークンを使って仕分けに進めなかった。

## What Changes

- 一周目の `照合表` に、ヒットが 50 行を超える語のための `全ヒット要約` の形を足す。レビュアーは全行の代わりに、検索コマンド・全ヒットの行数・全ヒットの出力のハッシュと、食い違いの行だけを返す
- `review-hit-set.py` は `全ヒット要約:` の行を持つ表を判別し、repository-wide な検索を固定 SHA で再実行して、行数とハッシュを比べる。検索範囲の検査は今の表と同じものを通す
- reviewer-brief に、読み取り専用のレビュアーでも標準出力だけで要約を作れる手順と、件数の多い語の読み方を書く
- 保証範囲の文を、要約の語で何が保証されて何が保証されないかが分かる形に直す
- gate-runner の三表の機械照合に、要約の表も同じコマンドで渡すことを書く
- 順 3 の一覧と triage.md は変えない（全行のまま）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 一周目の照合表の返し方と共通照合スクリプトの受け付ける形を足す

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md`（レビュアー向け指示ブロック）
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（一周目の三表の機械照合）
- `plugins/dev-workflow/scripts/review-hit-set.py`
- `plugins/dev-workflow/tests/review-hit-set.bats`、`plugins/dev-workflow/tests/pr-review-gate-skill.bats`、`plugins/dev-workflow/tests/develop-roles.bats`
- 全ヒット要約を使わない語の表と、順 3 の `--head` つきの照合の動きは変わらない
- 同じファイルを変更中の開いた PR: #1436・#1438（reviewer-brief.md）、#1436・#1455（gate-runner.md）、#1410・#1453（review-hit-set.py）、#1410（spec）。どれとも同じ行を書き換えない見込みで、#1436 だけは gate-runner の該当の節を別ファイルへ移すので後からマージする側が移し先に当て直す
