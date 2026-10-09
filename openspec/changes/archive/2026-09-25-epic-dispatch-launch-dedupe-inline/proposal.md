## Why

`epic-dispatch.sh launch` は起動前に `orca worktree list --json` を 1 回だけ読み、既存ワークツリーがある子を `skipped` にする。同じ呼び出しの中で本体が同じ子番号を 2 回渡すと（例: `launch 420 11 11`）、1 回目の `create` で作られたワークツリーはこの一覧に載っていないため、2 回目も `create` が呼ばれ同じ子が二重に起動する（PR #428 のレビュー指摘 F6、https://github.com/oratta/claude-harness/pull/428#issuecomment-5792114321 )。`route` の引数検査が重複した番号をそのまま通すのは仕様どおりだが（`openspec/specs/dev-workflow-develop/spec.md:466`）、`skipped` の目的（同じ子を二重に起動しない）は呼び出しをまたいだ場合と同じ呼び出し内の場合の両方に及ぶべきで、現状は前者しかカバーしていない。

## What Changes

- `cmd_launch` の子番号ループに、同じ呼び出し内で既に処理した番号を憶えておく仕組み（`seen` 変数）を足し、2 回目以降の同じ番号は `orca worktree create` を呼ばずに `skipped <N>` を出す
- 既存の「一覧に既存ワークツリーがある子は `skipped`」の規定（`spec.md:462`）は変えない。ADDED 要件として、同じ呼び出し内の重複番号にも `skipped` が及ぶことを足す

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `dev-workflow-develop`: 「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」要件（`launch` の `skipped`/`launched`/`failed` 規定、spec.md:462 付近）に、同じ呼び出し内で渡された重複番号を 2 回目以降 `skipped` にする ADDED 要件を足す。既存の MUST は書き換えない（並行する兄弟 issue #429 #431〜#433 が同じ要件を触るため、archive 済みの `openspec/changes/archive/2026-09-25-epic-dispatch-depth-limit/proposal.md` と同じ ADDED 方式に倣う）

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_launch` の冒頭と子番号ループ）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（同一呼び出し内の重複番号を渡したとき 2 回目が `skipped` になることを確かめるテストを足す）
- `plugins/dev-workflow/changes/434.md`（変更記録）
- `route`・`wait`・エピックの深さ制限（#429 #431〜#433 の範囲）には触れない
