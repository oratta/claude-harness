# Proposal

## Why

親が CI の見張りのやり直しの上限で止まった子を通すとき、`親の判断:` の理由に PR 番号・落ちたチェック名・HEAD の短い SHA を「子の停止の記録から取って」書くと決めた（#1271 / PR #1294）。ところが子の停止の記録（`子の停止: 主の返事待ち` のコメント）の形には HEAD を書く場所の決まりが無く、子は HEAD を書かない。親はいつも `不明` と書くことになり、「同じ HEAD で許したあとにまた止まった同じ件は主に上げる」の見分けが効かない（PR #1294 のレビュー指摘 F1 のうち、PR #1294 が触れていないファイルの部分）。

## What Changes

- 子の停止の記録の形（`skills/develop/references/epic-child-stop.md` の「記録の形」）に、CI の見張りで止まったときの書き方を足す。止まり方が CI の見張りの `escalate`（`ci-watch.md` 6 の表）、`obs.state` が `wait` でない `none`（前回と同じ状態・同じ HEAD の決着。親が追加のやり直しを許したあと同じ HEAD でまた落ちたとき）、直し方の手順 7（直せないので上げる）のどれかのときは、`再開に要る途中経過:` に PR の URL・落ちたチェック名・止まった時点の PR の HEAD の短い SHA（PR の HEAD のコミット SHA の先頭 7 文字）を書く。HEAD が取れなかったときは作らずに `HEAD 不明` と書く
- 記録の項目は 7 つのまま。8 つ目の項目は足さない（読む部品と「7 つの項目」の記述・テストを変えないため）
- CI の見張りの手順（`references/ci-watch.md`）の `escalate` と `none` の行に、エピックの子のセッションは止まる前に停止の記録を残して `mark stopped` で止まり、その書き方は `epic-child-stop.md` に従うことを 1 文で足す（手順 7 は「`escalate` と同じ手順」なので同じ規定が及ぶ）
- テスト（`plugins/dev-workflow/tests/epic-dispatch.bats` と `plugins/dev-workflow/tests/ci-watch.bats`）で、記録の形の節と `ci-watch.md` の `escalate`・`none` の行にその記述があることを確かめる

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: 要件「エピックの子の停止の記録は、子の会話を読んでいない読み手が 1 通で読める形で書く」に、CI の見張りで止まったときに `再開に要る途中経過:` へ PR の URL・落ちたチェック名・HEAD の短い SHA を書く規定を足す
- `dev-workflow-ci-watch`: 要件「CI の見張りの手順は共有 reference に 1 本置く」の 6 の `escalate` と `none` に、エピックの子のセッションは止まる前に `skills/develop/references/epic-child-stop.md` の手順どおり記録を残して `mark stopped` で止まることを足す（`escalate` の行の中身はこの要件が持つので、規定が 2 つの capability に分かれて育たないよう、こちらに置く）

## Impact

- 文書: `plugins/dev-workflow/skills/develop/references/epic-child-stop.md`、`plugins/dev-workflow/references/ci-watch.md`
- テスト: `plugins/dev-workflow/tests/epic-dispatch.bats`
- 変更の記録: `plugins/dev-workflow/changes/1298.md`
- 読む部品（`scripts/stop-judge.sh`・`scripts/epic-dispatch.sh`・`parent-merge-criteria.md`・`parent-pass-criteria.md`）は変えない。`stop-judge.sh` は記録の本文を項目名を解釈せずに判断のモデルへ渡すので、`再開に要る途中経過:` に書いた HEAD はそのまま判断の入力に入る
