## Why

`epic-dispatch.sh launch` で起動した子のワークツリーには端末が 2 つ残る（空のシェルの「Terminal 1」と、子のセッションが動く「✳ Claude Code」）。Orca 1.4.226 の `orca worktree create`（`--agent` なし）は作った時点で空のシェルの端末を 1 つ作り、launch がそのあと `orca terminal create` で 2 つ目を作るためである。端末が 2 つあると、親が子に返事を送るとき `reply` が `failed <N> ambiguous-terminal` で止まる（#1052 で起きた）。issue: https://github.com/oratta/claude-harness/issues/1055

## What Changes

- `launch` は、worktree create のあと子のワークツリーの `orca terminal list` を見る。端末がちょうど 1 つあれば、新しい端末を作らず、その端末へ従来と同じ起動コマンド（`EPIC_DISPATCH_PARENT_EPIC=<epic> CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値> <cmd> --model <model>`）を `orca terminal send --enter` で打ち込む。端末が Claude Code になる（一覧の `agentIdentity` が `claude`、またはタイトルに `Claude Code`）まで一覧を引き直して待ち、その端末のハンドルで従来どおり `terminal wait` → `terminal send`（最初の指示）へ進む
- 端末が 0 個のときだけ従来どおり `orca terminal create` で作る（Orca の版によって worktree create が端末を作らない場合の後方互換）
- 一覧を読めないとき・端末が 2 個以上のとき・起動コマンドを打ち込めないとき・待っても Claude Code にならないときは `failed <N>` とし、端末を新たに作らない（作ると端末が増えるため）。理由と手で続けるコマンドを stderr に出す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: 要件「エピックの子の経路判定・起動・待ち受けを LLM なしで行う」の launch の呼び出し順（worktree create のあとに terminal create）に対し、最初の端末の再利用を新しい要件として足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_launch` の端末の作成部分、新しい関数 `shell_start`、ヘッダコメントの launch の説明だけ）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（launch の呼び出し順のテストの更新と、新しいテスト）
- `plugins/dev-workflow/changes/1055.md`（新規）
- reply / reap / wait / mark / route には手を入れない
