## Why

reap のブランチ削除は、先端が HEAD と同じことを確かめてから `git branch -D` を呼んでいた。確かめてから消すまでの間に別プロセスが同じ ref を進めると、進んだあとのブランチを消してしまう（#825）。削除時の期待 OID を Git に渡す `git update-ref -d` に替えると、今度は別の worktree が checkout しているブランチも消せてしまう（`git branch -D` は拒否する）。この change は、PR #1204 が openspec の change を作らずに `openspec/specs` を直接書き換えたことの事後記録である。

## What Changes

- reap のブランチ削除を `git branch -D <ブランチ>` から `git update-ref -d refs/heads/<ブランチ> <HEAD>`（期待 OID つき）にする。期待 OID の不一致は `reaped <N> branch-kept`
- 子のパスが `git worktree list --porcelain` から外れたあと、同じ一覧に `branch refs/heads/<ブランチ>` の行（別の worktree が checkout 中）があれば `update-ref -d` を呼ばず、stderr に理由を 1 行出して `reaped <N> branch-kept`
- spec の `git branch -D` の記述と Scenario を `git update-ref -d` に揃え、使用中ブランチの Scenario を足す

## Capabilities

### Modified Capabilities
- `dev-workflow-develop`: 要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」と、「epic-dispatch.sh reap は PR が無く issue を閉じた子を、main に入っていない commit が無いときに片付ける」の Scenario
- `dev-workflow-epic-state`: 要件「親の見張りは記録だけで子の状態を判定する」の reap の記述と Scenario

## Impact

- plugins/dev-workflow/scripts/epic-dispatch.sh（cmd_reap）
- plugins/dev-workflow/tests/epic-dispatch.bats
- plugins/dev-workflow/changes/825.md
