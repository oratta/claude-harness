## Why

PR #824（#805）の一周目レビュー F3。SKILL.md「エピックの扱い」の Orca 経路で、手順 2 の片付け待ちの子は `launch` に渡した履歴から作り直される。`reaped`（`branch-kept` を含む）と `gone` の子を除く規則が無いので、全 issue が閉じたあと最後の done を片付けても、削除済みの子だけを `--watch-done` に渡して最大 6 時間待つ経路が残る。手順 4 は `kept <N> not-done` の子だけを待つと書いており、手順 3 から 2 への戻り先と食い違う。

## What Changes

- 片付け待ちの子の定義に「このセッションで `reap` が `reaped`・`gone` を返した子を除く」を足す
- 全 issue が閉じたあとは `not-done` の集合だけを更新し、空なら `wait` を呼ばずに終える
- 手順 3・4・7 を新しい定義に合わせる
- 「全 issue closed → 最後の done → reaped → 待機終了」を spec とテストに足す

`route`・「経路の決め方」・README は触らない（エピック #811 の別の子 #844 が同時に直している）。

## Capabilities

### Modified Capabilities
- `dev-workflow-develop`: 要件「Orca 経路の本体は印が付いた子のワークスペースを片付ける」

## Impact

`plugins/dev-workflow/skills/develop/SKILL.md`（Orca 経路の手順 2〜4・7）、`plugins/dev-workflow/tests/epic-dispatch.bats`、`plugins/dev-workflow/changes/827.md`。スクリプトの挙動は変えない。
