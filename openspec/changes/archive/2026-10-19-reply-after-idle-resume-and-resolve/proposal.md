## Why

主が 1 時間以上離席して戻り、親を `/develop <エピック番号>` で起動し直しても、主に上げて返事を待っている子の質問が出し直されない（`wait --watch-stopped` が印を `epic-stopped-seen` に書き換え済みで、再開の手順 7 は `reap` と `launch` しか呼ばないため）。また `wait --resolve` で親が通す返事は常にそのまま送られ、何時間も前に止まった大きな会話へ送って入力換算 2N を書き直す。issue #1107。

## What Changes

- SKILL.md の Orca 経路の手順 7 に、`launch` の前に主の返事待ちの子を集めて手順 8 と同じ報告を出し直す動きを足す
- `references/reply-after-idle.md` の「親への適用」の復元元の表に、主の返事待ちの子の行を足す
- `epic-dispatch.sh wait --resolve` の `resolve_stopped` が、送る前に `reply-after-idle.md` の表で `--relaunch` を決める（事実を読めないときはそのまま送る）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 起動し直した親が主の返事待ちの子を出し直す要件と、`wait --resolve` が起動し直しを判定する要件を足す

## Impact

`plugins/dev-workflow/skills/develop/SKILL.md`、`references/reply-after-idle.md`、`scripts/epic-dispatch.sh`、`tests/epic-dispatch.bats`、`tests/develop-skill.bats`。
