## Why

CI の見張りの待ち（`ci-watch.sh wait` を `run_in_background` で起動したもの）はセッションの背景タスクなので、セッションが落ちると一緒に消える。起動し直したセッションには `stopped` / `killed` の背景タスクの通知が届くが、見張りの手順（`references/ci-watch.md`）にその通知を受けたときの動きが書かれていないため、セッションは何もせずに止まる。genetta-inc/flatmate#1312（PR genetta-inc/flatmate#1610、2026-10-18）では、09:00 に見張りが切れ、09:09 に CI が落ち、10:08 に起動し直したセッションが `<status>stopped</status>`（Background shell command didn't finish before the previous session ended）の通知を受けたが動かず、親が主の指示で `epic-dispatch.sh reply` を送るまで PR は赤のまま放置された（#1085）。この change が救うのは、前の会話を持ったまま起動し直したセッション（Claude Code の resume で、前のセッションの背景タスクの通知を受け取るもの）に限る。#1323 の起動し直し（`/clear` してから `/develop #<N>` で起こす形）は会話も通知も持たないので、この change では救えない（design.md の Non-Goals）。その扱いは #1323 に参考として送った（https://github.com/oratta/claude-harness/issues/1323#issuecomment-6409774571 ）。

## What Changes

- `references/ci-watch.md` に「起動し直したセッションが見張りの背景タスクの `stopped` / `killed` の通知を受けたとき」の手順を足す。PR が open で、最新の `CI 見張り開始:` のあとに `CI 見張り終了:` が無いとき（コメントは全ページを見る）だけ、主やオーナーに聞き返さずに、通知を受けたあとの最初のターンで `ci-watch.sh next` から見張りを再開する（同じ見張りの続きとして扱い、開始の判定・開始のコメントはしない）。PR が merged / closed、または終了のコメントがあれば再開しない。判定の守備範囲（入力・拾いたい誤り・通ることを許す入力）も書く
- 入力なしでセッションを起こす部分は #1084 に任せ、この change は通知が会話に残った状態で次のターンが来たら（通知そのもの、親の返事、主の入力のいずれでも）聞き返さずに `next` を実行するまでを扱う
- `references/ci-watch.md` の 2（1 つの PR を見張るのは 1 セッションだけ）の「前のセッションが閉じた」再開にオーナーの指示を求める規則を、別のセッションが始める場合のものとして書き分け、新しい節を指す
- develop の `SKILL.md` の CI の見張りの行から、新しい節を 1 行で指す（手順は言い換えない）
- SessionStart hook は足さない（hooks は変えない）。`scripts/epic-dispatch.sh` と `skills/develop/references/reply-after-idle.md` は変えない

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-ci-watch`: 起動し直したセッションが、見張りの背景タスクの `stopped` / `killed` の通知を受けたときに、決着していない見張りを `next` から再開する要件を足す

## Impact

- 入力なしでセッションを起こす部分は #1084 に任せ、この change の範囲は通知が会話に残った状態で次のターンが来たら聞き返さずに `next` を実行するまでに限る
- `plugins/dev-workflow/references/ci-watch.md`（新しい節と 2 の書き分け）、`plugins/dev-workflow/skills/develop/SKILL.md`（参照 1 行）、`plugins/dev-workflow/tests/ci-watch.bats`（reference の文面の検査を足す）、`plugins/dev-workflow/changes/1085.md`（変更の記録）
- `ci-watch.sh`・`pr-state.sh` の振る舞いは変えない
- エピックの親の `wait` が「CI の見張りが決着しないまま止まった子」を返す経路は、この change では足さない。子のセッションが起動し直らない場合は #1084 の親の検知で拾う対象として送った（https://github.com/oratta/claude-harness/issues/1084#issuecomment-6409774131 。design.md の判断を参照）
