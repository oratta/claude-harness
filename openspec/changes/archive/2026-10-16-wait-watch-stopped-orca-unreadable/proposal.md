## Why

`epic-dispatch.sh wait` は `--watch-stopped` だけを付けても、位置引数の子が 1 件以上あれば `orca worktree current --json` を呼ぶ。今のワークツリーを Orca から読めないと、stdout に何も出さず exit 1 で終わる。develop の SKILL.md 手順 6 とその仕様はこの終わり方を `--watch-done` 付きの場合だけに書いていて、`--watch-stopped` 付きの場合に何をするかが手順から分からない。

## What Changes

- 要件「Orca 経路の本体は印が付いた子のワークスペースを片付ける」の該当 1 文を、`--watch-done` か `--watch-stopped` を付けた `wait` の場合に広げる（報告は同じく「親ワークツリーで開き直す」）。
- 手順 6 の SKILL.md の文も同じに合わせる（実装の工程で行う）。

## Capabilities

### Modified Capabilities
- `dev-workflow-develop`: 上記要件の 1 文と、その場合を確かめるシナリオ 1 件。

## Impact

`plugins/dev-workflow/skills/develop/SKILL.md` 手順 6 の末尾 1 文と `openspec/specs/dev-workflow-develop/spec.md`。`epic-dispatch.sh` の挙動は変えない。
