## Why

pr-review-gate の仕分け表の順 3（一覧の一致で閉じる）では、表の「ヒットした行の本文」列を 1 段目（修正前 SHA）と 2 段目（HEAD の残存ヒット）の両方で照合に使う。W が「該当しない」と分類した行そのものを同じ周の別の修正で書き換えると、その行の本文は修正前と HEAD で異なるので、どちらの本文を表に書いても片方の段が不一致になり、正しく直した PR が差し戻される（PR #372 の Codex レビュー 1 周目の指摘 2、issue #377）。#355 で順 3 の第 1 段を一周目照合と共通の 4 列契約・`review-hit-set.py` にそろえたので、その契約を崩さずに本文の持ち方を決める必要がある。

## What Changes

- 順 3 の一覧表の PR コメントに、同じ周の修正で本文を書き換えた「該当しない」行だけを載せる補助表 `### 書き換えた該当しない行`（列 `| ファイル | 行（修正前 SHA） | 修正後の本文 |`）を足す。主表の 4 列（共通全ヒット一覧契約）は変えず、主表の本文列は常に修正前 SHA の本文とする
- 2 段目の照合で、補助表に載った「該当しない」行は修正後の本文と照合し、載っていない行は主表の本文と照合する
- 扱いが混在する組の削除行の検査で、必要な削除行数を「直した」の件数と補助表に載った「該当しない」の件数の和にする（書き換えた「該当しない」行の削除が「直した」の削除に数えられて直し忘れを隠すのを防ぐ）
- `plugins/dev-workflow/scripts/review-hit-set.py` に、修正後の HEAD を受け取って順 3 の 2 段目（本文・件数・削除行）を機械照合するオプションを足す。オプションを付けない既存の呼び出し（一周目の照合表・順 3 の 1 段目）の振る舞いは変えない
- `plugins/dev-workflow/tests/review-hit-set.bats` に、「該当しない」行を同じ周に書き換えたケース（補助表あり→一致、補助表なし→不一致、混在する組での削除行の加算）を足す
- worker.md の順 3 の段落に、書き換えた「該当しない」行は補助表に載せることを足す（書式の正本は SKILL.md のまま、列は再掲しない）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 「一覧の一致で閉じる（順 3）」の一覧表の書式と 2 段目の照合規則を変え、共通照合スクリプトに順 3 の 2 段目を足す。「W の指示書が一覧の表と今直す記録を持つ」に補助表への記載を足す

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`（手順 2-1 の順 3 の節）
- `plugins/dev-workflow/scripts/review-hit-set.py`
- `plugins/dev-workflow/skills/develop/references/roles/worker.md`、`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（順 3 の 2 段目をスクリプトで回す手順の参照）
- `plugins/dev-workflow/tests/review-hit-set.bats`、`plugins/dev-workflow/tests/pr-review-gate-skill.bats`
- `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョン、`plugins/dev-workflow/CHANGELOG.md`
- 一周目の `照合表` と共通全ヒット一覧契約の 4 列は変わらない
