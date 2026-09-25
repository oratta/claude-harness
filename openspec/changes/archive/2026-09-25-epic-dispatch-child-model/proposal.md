# エピックの子セッションを指定したモデルで起動する

## Why

`epic-dispatch.sh launch` は `orca worktree create --agent claude` で子セッションを起動しており、モデルを指定していない。そのため Claude Code の既定モデルがそのまま使われ、既定が Sonnet だったときには子セッションがすべて Sonnet で起動した（#475）。子セッションは `/develop` の 1 ループを丸ごと回すオーケストレーターなのでメインセッションと同じ扱いにしたいが、`orca worktree create` にはモデルを指定するオプションが無い。

## What Changes

- `launch` は `orca worktree create` に `--agent` を渡さずにワークツリーだけを作り、`orca terminal create --worktree path:<子のワークツリー> --command "claude --model <model> --dangerously-skip-permissions" --json` で子セッションを起動する。以降の `orca terminal wait --for tui-idle` → `orca terminal send`（#458）は、`terminal create` の JSON 出力のハンドルに対して行う
- `<model>` の既定は `opus`。環境変数 `EPIC_DISPATCH_MODEL` で変えられる
- `terminal create` が失敗した、または子のワークツリーのパスや端末のハンドルが取れなかった子は `failed` にする。ワークツリーができていれば、端末を手で起動し直すための `orca terminal create` のコマンドを stderr に出す（再実行ではその子は `skipped` になるため）
- develop の SKILL.md（Orca 経路）に、子セッションのモデルの決め方（既定 `opus`、`EPIC_DISPATCH_MODEL` で変更）と、`--dangerously-skip-permissions` を付けているのは `epic-dispatch.sh` であることを書く

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: 「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `launch` の呼び出し順と `launched` / `failed` の条件を変え、モデル指定の既定値と環境変数を足す。「エピックの条件・作り方・回し方・完了条件を規定する」に、SKILL.md の Orca 経路へ子セッションのモデルの決め方を書くことを足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_launch` と先頭コメント）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（orca スタブに `terminal create` を足し、launch のテストを更新・追加）
- `plugins/dev-workflow/skills/develop/SKILL.md`（Orca 経路の説明）
- `plugins/dev-workflow/changes/475.md`（変更記録）
- 子セッションの起動に Orca の agent 設定（`agentDefaultArgs` / `agentCmdOverrides`）が効かなくなる。起動コマンドは `epic-dispatch.sh` が決める
