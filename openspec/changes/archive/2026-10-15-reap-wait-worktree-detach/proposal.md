## Why

エピックの子を `epic-dispatch.sh reap` で片付けると、`orca worktree rm` が「Orca がバックグラウンドで削除中」と返して exit 0 になる。その直後に `git branch -D` を呼ぶと、ワークツリーがまだ git に残っているため `Cannot delete branch ... checked out at ...` で失敗し、`reaped <N> branch-kept` になる。2026-10-15 のエピック #1038 では子 3 件すべてがこうなり、主が後でブランチを手で消すことになった（issue #1047）。

## What Changes

- `reap` は、`orca worktree rm` が exit 0 のあと `git branch -D` の前に、その子のワークツリーが `git worktree list --porcelain` から消えるのを、上限つきで待つ。
- 上限は環境変数で上書きでき、テストでは短くできる。
- 上限を超えても残るときは、今どおり `reaped <N> branch-kept` を出す。
- 「先端が HEAD と同じときだけ `git branch -D`」の条件は変えない。

## Capabilities

### New Capabilities
なし。

### Modified Capabilities
- `dev-workflow-develop`: 「epic-dispatch.sh は ... reap」の要件のうち、rm 成功後のブランチ削除の手順に待ちが加わる。

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_reap` のブランチ削除の手前）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（reap のテスト）
- `openspec/specs/dev-workflow-develop/spec.md`（reap の要件と Scenario）
