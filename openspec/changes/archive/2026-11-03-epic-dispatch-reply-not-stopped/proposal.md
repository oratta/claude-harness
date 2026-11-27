## Why

親が主に「子への答え」を頼んでいるあいだに主が子のタブで先に答えると、子は作業を再開しているのに、親が同じ件の古い答えを子の入力欄に重ねて送る。`epic-dispatch.sh reply`（と `wait --resolve` の送る段）は、子がまだ止まっているかを送る直前に確かめていない。`notify-closed` にはすでに同じ確認がある（oratta/claude-harness#1109）。

## What Changes

- `epic-dispatch.sh reply` は、子がもう止まっていなければ（記録の `stop` が `stopped` でも `stopped-seen` でもない。記録が `stopped-seen` のままでも、会話ログが止まりの発言より進んでいれば同じ）送らず、`skipped <child> not-stopped` を出して exit 0 で終える
- `wait --resolve` は、送る直前に子が再開済みだったとき、送らず、エピックに `親の判断: 子 #N 通した` も投稿せず、待ちを続ける
- 親の手順 8（`references/epic.md`）は、`reply` が `skipped <N> not-stopped` を返したら主の答えを送り直さず、主に「子のタブで既に答えが届いている」と伝える
- 実装は PR #1287 に既にある（`scripts/epic-dispatch.sh`・`tests/epic-dispatch.bats`・`references/epic.md`）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」（状態表に行を足す）・「epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける」（送る直前の確認）・「Orca 経路の親は止まった子を解決し、解決できないものを主に分かる形で上げる」（手順 8 の `skipped` の扱い）

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`・`plugins/dev-workflow/skills/develop/references/epic.md`・`plugins/dev-workflow/tests/epic-dispatch.bats`
- 状態ファイルの形は変えない。戻し方は PR の差分を戻す
