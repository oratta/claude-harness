## Why

子が「用が済んだ」の印を付けた直後に親が `epic-dispatch.sh reap` を呼ぶと、子のセッションがまだターンを終えておらず、Orca が `terminal_close_incomplete` を返して `kept <N> close-failed` になり、ワークツリーが残る（#1059 で実際に起きた）。待てば閉じられる場合まで主の判断に回っており、閉じられない場合も主が何をすればよいか分からない。

## What Changes

- reap の端末の閉じ（`orca terminal close --all`）が失敗したら、原因の手がかり（端末の一覧）を stderr に出し、短く待って 1 回だけ閉じ直す
- 閉じ直しで成功すれば従来どおり rm へ進む（`reaped <N>`）
- 閉じ直しも失敗したら `kept <N> close-failed` を返し、stderr に主がする操作（どの画面で何をするか）を出す
- SKILL.md の手順 3 で、`kept <N> close-failed` のときエピックへの 1 行に stderr の主がする操作を含める

## Capabilities

### Modified Capabilities
- `dev-workflow-develop`: 要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の close の扱い

## Impact

- plugins/dev-workflow/scripts/epic-dispatch.sh（cmd_reap）
- plugins/dev-workflow/tests/epic-dispatch.bats
- plugins/dev-workflow/skills/develop/SKILL.md（手順 3）
