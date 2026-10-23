## Why

CI の見張りのやり直しの上限で止まった子に、親が追加のやり直しを返事で許したあと、子が見張りに正しく戻れない。手順 7 の経路で止まった子は PR に `needs-approval` を付けたままで、これが残るとやり直しが通っても見張りは `ready` 後に `--until-merged` で待たずオーナーへマージを頼んで終わる。また返事が `CI 見張り開始:` の重複確認と投稿を求めないため、別のセッションが見張りを重ねうる（issue #1270、PR #1268 のレビュー指摘 F1）。

## What Changes

- `parent-pass-criteria.md` の節「CI の見張りのやり直しの上限で止まった子」の「返事」の段落に、見張りに戻る前の手順を足す: 止まるときに付けた `needs-approval` を外す（手順 7 の経路で止まった子のみ）／`ci-watch.md` 2 の重複の確認と `CI 見張り開始:` の投稿をしてから戻る。
- 要件「親が通してよい範囲の基準は、CI の見張りのやり直しの上限で止まった子の扱いを決める」の返事の場面に同じ内容を書き、bats で記述の有在を確かめる。
- `ci-watch.md` は変えない。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「親が通してよい範囲の基準は、CI の見張りのやり直しの上限で止まった子の扱いを決める」の返事の場面

## Impact

- `plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md`（返事の段落）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（該当の @test に検査を足す）
- `plugins/dev-workflow/changes/1270.md`
