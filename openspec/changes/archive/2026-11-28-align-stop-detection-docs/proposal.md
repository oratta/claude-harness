## Why

止まり検知の手順書と spec に、実装と食い違う記述が残っている。手順書や spec を正本にして実装を直す人が、記述に合わせて実装を退行させるおそれがある（動作は今の実装が正しい）。元の issue は #1543（文書の食い違い）と #1714（`止まった理由: なし` の途中経過で judge を呼ばない）。

## What Changes

- spec の 3 つの要件で、停止の記録の作成時刻と最後の入力の時刻の比較を、実装（`stop-judge.sh` の `>=`）に合わせて「最後の入力以降」と書く（「より後」を直す）
- 手順書（`parent-merge-criteria.md`）と `channel.md` の読み替えの対象ファイルの数・列挙を実物に合わせる
- #1543 の残りの指摘（uuid の有無・手順 8 の条件・`mirror` の写す範囲・`stop-judge.sh` と `epic-dispatch.sh` のコメント）は、今の main と 1 件ずつ照合し、直っているものは済みと記録、残るものだけ文を直す
- #1714: `止まった理由: なし` で始まる通常の作業報告（`dependency_wait` が欠落か false）の子は止まりに数えられず judge も呼ばれないことを、bats で固定する（実装の変更なし）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける」「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」「エピックの子の止まりの手順と、親が stopped を受けて報告する手順を規定する」の文言（比較の境界を実装の `>=` に合わせる）。振る舞いは変わらない

## Impact

- `openspec/specs/dev-workflow-develop/spec.md`、`plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md`・`channel.md`、`plugins/dev-workflow/tests/epic-dispatch.bats`
- スクリプトの動作は変わらない
