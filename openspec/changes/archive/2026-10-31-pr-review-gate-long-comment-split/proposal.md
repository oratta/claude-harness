# Proposal

## Why

GitHub の PR コメントは 65,536 字が上限だが、pr-review-gate の規則は `レビュー三表:` のコメントと順 3 の `## 一覧（順 3）` のコメントが 1 件に収まる前提で書かれている。PR #1243 では照合表 13 表が約 120KB になり、照合と振り分けの G がその場の判断で 3 つのコメントに分けて URL で結んだが、分け方も次の段の G の読み方も決まっていない。順 3 の一覧は #1457 のあとも全行のままなので、全ヒットが数十万字ある語で順 3 に当たると、W が投稿できず止まる。

## What Changes

- `stages/triage.md` に、コメントが上限を超えるときの共通の規則を足す。本文を行の境界で切って部分のコメントに置き、見出しの行と部分の URL だけを持つ親のコメントで結ぶ
- `レビュー三表:` のコメントと `## 一覧（順 3）` のコメントの親と部分の形、投稿の順、読むときの復元の手順、読めなかったときの扱いを決める
- 順 3 の節と W の指示書（`worker/implement.md`）から、この規則へ案内を足す
- 上の規則と、復元した表が `review-hit-set.py` の照合を通ることを確かめる bats を足す
- 上限に収まるコメントの書式と読み方は変えない

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 三表と順 3 の一覧が上限を超えるときの置き方と読み方の要件を足す

## Impact

- 変更するファイル: `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`、`plugins/dev-workflow/skills/develop/references/roles/worker/implement.md`
- 新しいファイル: `plugins/dev-workflow/tests/pr-review-gate-long-comment.bats`、`plugins/dev-workflow/changes/1249.md`
- W・レビュアー・G で共有する三表と一覧の形式に触れる（層間契約）。ただし上限を超えるときの置き方を足すだけで、表そのものの形式と `review-hit-set.py` は変えない
- `gate-runner.md` は変えない（照合と振り分けの G は `stages/triage.md` を全部読むので、規則に届く。#1455・#1436 との衝突も避ける）
