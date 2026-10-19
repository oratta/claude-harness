## Why

`epic-dispatch.sh launch` は着手できる子を件数にかかわらずすべて起動する。オーナーの環境では 2026-10-19 に genetta-inc/flatmate#1615 で子を一度に 12 件、合わせて 15 件まで同時に動かした。子 1 件ごとに Claude Code のセッションが 1 つ立ち、さらにサブエージェントやテストを動かすので、メモリの少ない Mac ではメモリを使い切って PC ごと落ちうる。flatmate の構築代行の第3版（genetta-inc/flatmate#1633）で客の住人も同じ開発ワークフローを使うようになり、客の Mac でも `/develop <エピック>` が子を並列に起動しうるため、上限を入れる（issue #1106）。

## What Changes

- `epic-dispatch.sh` に、同時に枠を使う子の数の上限を足す。上限は環境変数 `EPIC_DISPATCH_MAX_PARALLEL` で変えられ、設定が無いときは PC の物理メモリ量から決める既定値（物理メモリの GB を 4 で割って切り捨て、最小 1。メモリ量を読めなければ 2）を使う
- 上限の実際の値を出すサブコマンド `epic-dispatch.sh max-parallel` を足す（親がサブエージェント方式で同じ上限を使うため）
- `launch` は、親のワークツリーから作られた子のワークツリーのうち「枠を使っている子」を数え、空いた枠の分だけ子を起動し、残りを `deferred <N>` の 1 行で出して起動しない。「枠を使っている子」は、archive されておらず、`done` の印（workspaceStatus が completed）が無く、主の返事待ちで止まった印（comment が `epic-stopped` / `epic-stopped-seen`）が無く、issue が閉じていない子とする。数えた子と上限は stderr に出す
- develop の SKILL.md「エピックの扱い」→「回し方」に、上限と後回しにした子の扱いを書く。Orca 経路では、`wait` で起こされて完了の印・閉じた子・止まった子を処理したあと、後回しの子があれば `launch` に渡し直す。サブエージェント方式では、`max-parallel` の値を上限に、同時に 1 ループを回す子（＝同時に動く W）の数を抑える
- 既定値の根拠（この Mac での実測値）を SKILL.md と変更記録に書く

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: `epic-dispatch.sh launch` に同時に枠を使う子の上限と後回し（`deferred`）の出力を足し、`max-parallel` サブコマンドを足す。SKILL.md の回し方（Orca 経路・サブエージェント方式）に、上限と後回しにした子を枠が空いたときに起動する手順を足す。既存の要件の文は書き換えず、要件を追加する

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`launch` の枠の計算と `deferred` 出力、`max-parallel` サブコマンド、冒頭の説明と usage）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（上限・後回し・枠の数え方・既定値のテスト。既存の `launch` のテストは上限を大きく設定して従来どおりに動かす）
- `plugins/dev-workflow/skills/develop/SKILL.md`（「回し方」の Orca 経路の手順と、サブエージェント方式の段落）
- `plugins/dev-workflow/changes/1106.md`（変更記録）
- `launch` は枠を数えるために、親から作られた子のワークツリーごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` を 1 回呼ぶようになる
- 客の Mac での値の置き場（住人の `.env` など）は flatmate 側の子 issue で配線する（この change の範囲外）
