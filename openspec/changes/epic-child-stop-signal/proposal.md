## Why

Orca 経路のエピックで、子セッションが主の返事を待って止まっても、親セッションはそれを知る手段を持たない。親が子の止まりを確かめるのは `epic-dispatch.sh wait` の 6 時間ごとの `timeout` のときだけで、見るのは `needs-approval` ラベルとコメントだけである。2026-10-01〜10-14 の子セッションの停止 88 件のうち、本文で `needs-approval` に触れていたのは 8 件だけで、止まり方はほぼ全部が本文での質問だった（issue #1033）。親が止まった子を解決する仕組み（#1034）は、親が LLM を使わずに止まりに気づき、止まった理由と子の推奨を読めることを前提にしているので、先にその土台を作る。

## What Changes

- `epic-dispatch.sh mark` に種別 `stopped` と `resumed` を足す。`stopped` は今のワークスペース（linkedIssue が一致するときだけ）の Orca のコメント欄を `epic-stopped` にし、`resumed` は止まった印（`epic-stopped` / `epic-stopped-seen`）があるときだけ `epic-resumed` に書き換える。ボードの列（`workspaceStatus`）には触れないので、`waiting` の `in-review` と取り違えない
- `epic-dispatch.sh wait` に `--watch-stopped` を足す。付けたときは、ポーリングごとの 1 回の `orca worktree list --json` で位置引数の子のコメント欄を見て、`epic-stopped` の子があれば、その子のコメント欄を `epic-stopped-seen` に書き換えてから `stopped <N>...` の行を出して exit 0 で終わる。書き換えた子は次の `wait` で同じ止まりを返さない
- develop の SKILL.md に、エピックの子のセッション（`route` が `nested` を返す）が主の返事を待ってターンを終える前に、記録先の子 issue へ 1 行目 `子の停止: 主の返事待ち` の記録（止まった理由・推奨・根拠・受け入れるリスク・途中経過）を 1 件残し、最後のツール呼び出しで `mark stopped` を呼ぶ手順と、主の返事を受けたら最初に `mark resumed` を呼ぶ手順を足す
- SKILL.md の Orca 経路の手順で、`wait` に `--watch-stopped` を付け、`stopped <N>...` で起こされたら最新の `子の停止:` の記録を読んでユーザーに報告し、再び待つようにする。`timeout` の確認の説明は、記録を残さずに止まった子だけが検知できないと書き直す
- 記録を残さずに止まった子を、端末の入力待ちが一定時間続いたことで拾う仕組みは入れない（誤検知が多い。根拠は design.md）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: `epic-dispatch.sh` の `mark` と `wait` に止まった子の印と検知を足し、develop の SKILL.md にエピックの子が止まるときの記録と印、親が `stopped` を受けたときの扱いを足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`mark` の種別、`wait` の `--watch-stopped`、冒頭のコメントと使い方）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（`orca` のスタブの一覧にコメント欄、`mark` と `wait` のテスト、SKILL.md の文言のテスト）
- `plugins/dev-workflow/skills/develop/SKILL.md`（子が止まるときの節と、Orca 経路の手順 2・5 と `stopped` を受ける手順）
- `plugins/dev-workflow/changes/1033.md`（変更の記録）
- 子のワークスペースの Orca のコメント欄を `epic-dispatch.sh` が上書きする。主がそこに書いたメモは `mark stopped` で消える
- 親の解決の仕方（決める役・子への返事の送り方）は #1034、記録の書式の細部と完了報告は #1036 の範囲で、この変更では扱わない
