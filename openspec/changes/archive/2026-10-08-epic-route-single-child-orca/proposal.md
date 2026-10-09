## Why

`/develop <エピック番号>` は、同時に着手できる子が 2 件以上のときだけ Orca の子ワークツリーの別セッションで子を回し、1 件のときは親のセッションの中で子の作業者・レビュアー・ゲート担当を順に動かす。1 件ずつ進むエピックでは、エピックの進行と子の作業の報告が 1 つの会話に混ざり、状況を追いにくい。エピック #811 自身がこの形で回った（#805 → #809 を 1 件ずつ親のセッションで実行）ため、Orca 経路を一度も通らず、実機確認もエピックの中でできなかった（issue #844、エピック #811）。

## What Changes

- `epic-dispatch.sh route` が `orca` を返す条件から「子が 2 件以上」を外し、子が 1 件以上あれば（`orca` が PATH にあり、`orca worktree current --json` が exit 0 のとき）`orca` を返す。子 0 件は今までどおり `subagent`。`nested` の判定が先に行われること、`orca` が無い・Orca 管理外・無人実行（`--unmanned`）がサブエージェント方式のままであることは変えない
- develop の SKILL.md「エピックの扱い」→「回し方」の「経路の決め方」の段落から件数の条件を外す。Orca 経路の手順 2〜4 と `reap` / `wait` には触らない（#827 が同時に直している）
- README.md と plugins/dev-workflow/README.md のエピックの回し方の 1 行から「並列可能な子が 2 件以上で」を外す
- `openspec/specs/dev-workflow-develop/spec.md` の回し方（経路の決め方）・`route` の要件・`route` の Scenario のうち件数に関わる箇所だけを直し、1 件でも `orca` になる要件を足す。片付け待ちの子の集合・`reap`・`wait` の要件は変えない
- すでに `回し方: サブエージェント` と記録したエピックを途中で Orca 経路に切り替える規則は作らない（理由は design.md）
- `tests/epic-dispatch.bats` の件数のテスト（`one child under Orca goes to subagent` ほか）を直す
- 変更の記録 `plugins/dev-workflow/changes/844.md` を足す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: 要件「エピックの条件・作り方・回し方・完了条件を規定する」の経路の決め方の件数の条件、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `route` の件数の条件、要件「エピックの子への注意書きと…引き継ぐ」の `route` の判定を直し、1 件でも `orca` になる要件を ADDED で足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_route` の件数の条件と冒頭コメントの route の説明だけ。`reap`・`wait`・`launch` は触らない）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（route のテストと、SKILL.md の経路の記述のテスト）
- `plugins/dev-workflow/skills/develop/SKILL.md`（「回し方」の「経路の決め方」の段落だけ。Orca 経路の手順 2〜4 は 1 文字も変えない）
- `README.md`、`plugins/dev-workflow/README.md`（エピックの回し方の 1 行）
- `openspec/specs/dev-workflow-develop/spec.md`（件数に関わる箇所だけ）
- `plugins/dev-workflow/changes/844.md`（新規）
- 子ごとに `/develop` を丸ごと回すセッション（既定で opus）が、着手できる子が 1 件のエピックでも 1 本増える。状況の見やすさと引き換えにする（2026-10-08、オーナーの指示）。LLM の呼び出しは増えない。`orca` を実行する書き方を SKILL.md に足さない
