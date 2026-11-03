## Why

エピックの子が主の返事を待って止まるとき、`epic-dispatch.sh mark stopped` が `skipped <N> no-workspace`（自分のワークツリーを持つ状態の記録が無い）を返しても、手順書は「何もしない」と定めている。親の `wait --watch-stopped` は状態の記録の印だけを見るので、子は止まりが親に伝わっていないことに気づかず、親は待ちの打ち切り（6 時間）まで止まりに気づかない。2026-10-20 の夜にエピック #1122 の子 #1123 と、エピック #1137 の子 #1165 の 2 件で実際に起きた（親と子のプラグインの版がずれ、子の状態の記録が作られていなかった。#1247）。

## What Changes

- エピックの子は、`mark stopped` の出力が `skipped` で始まる（`skipped <N> no-workspace`・`skipped <N> not-linked`）ときも、`failed` と同じく主への質問に「親に止まったことが伝わっていない」と 1 行添える。`marked` なら今どおり何もしない
- `not-linked`（このワークツリーの記録が別の子のもの）も含める。親が見張る子の記録に印が付かない点で `no-workspace` と同じため

## 範囲外

- 親の `wait --watch-stopped` が、状態の記録の無い子について issue の最新の `子の停止:` コメントを見る変更は入れない。理由: 実際に起きた 2 件は親が古い版のまま見張っていたので wait を直しても防げなかった／今は親の `launch` が子ごとに状態の記録を作り、親を起動し直したときは `adopt` が記録の無い子を取り込むので、記録の無いまま動く子は手で起動した子・記録の消失・tmux の部品で `adopt` が拾えない子に限られ、まれである／記録の無い子には受けた印（`stopped-seen`）を書く場所が無く、同じ止まりをポーリングのたびに返すか、受けた止まりを覚える置き場を新しく設計する必要がある。子の側の 1 行添えで主には直接伝わる（判断の記録: https://github.com/oratta/claude-harness/issues/1247#issuecomment-6358988253 ）
- `epic-dispatch.sh` の `mark` の出力と終了コードは変えない（正本は `dev-workflow-epic-state` の spec のまま）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: 要件「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」の子の側の `mark stopped` の出力の扱いを変え、守備範囲の拾いたい誤りとシナリオを 1 つずつ足す

## Impact

- `plugins/dev-workflow/skills/develop/references/epic-child-stop.md`: `mark stopped` の出力の扱いの 1 項（SKILL.md の節「エピックの子が主の返事を待って止まるとき」はこのファイルを読むよう指すだけなので変えない）
- `plugins/dev-workflow/tests/epic-dispatch.bats`: 手順書の検査に、`skipped` で始まる出力でも 1 行添えること・`skipped` を何もしない側に置かないことの assert を足す
- `plugins/dev-workflow/changes/1247.md`: 変更の記録
- 子が主に添える 1 行が増えるだけで、親の手順・スクリプトの挙動は変わらない
