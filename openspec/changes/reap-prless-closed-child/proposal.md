## Why

PR を伴わない記録先 issue（調査だけの issue など）を子が閉じて `epic-dispatch.sh mark done` を呼んでも、親の `reap` はマージ済み PR の先端（`headRefOid`）と子の HEAD の一致を必須にしているため `kept <N> no-merged-pr` を返し、ワークツリーが残る。#1035 で develop の「ループの終わり」に「PR を伴わない記録先 issue は本体が閉じて `mark` を呼ぶ」と足したので、この子は Orca 経路のエピックで普通に現れる（発生元 PR #1042、エピック #1038）。

## What Changes

- `epic-dispatch.sh reap` の確認 7（マージ済み PR の先端と HEAD の一致）で一致する行が無かった子について、PR の無い子の経路を足す。次の 3 つを全部満たした子だけを、マージ済み PR の子と同じ手順（端末を閉じる → `--force` なしの `orca worktree rm` → 先端が HEAD と同じローカルブランチだけ消す）で片付ける
  - そのブランチの PR が状態を問わず 1 件も無い（`gh pr list --head <ブランチ> --state all`）
  - 子の issue が閉じている（`gh api repos/{owner}/{repo}/issues/<N> --jq .state` が `closed`）
  - 子の HEAD が `origin/<base>`（`EPIC_DISPATCH_BASE`、既定 `main`）の祖先か同じ（`git merge-base --is-ancestor`）。つまりブランチに main に入っていない commit が無い
- PR がある子（マージされていない PR を含む）と issue が開いている子は、従来どおり `kept <N> no-merged-pr` か `kept <N> head-mismatch` を返す（受け入れ条件 (2)。既存の判定を弱めない）
- 新しい `kept` の理由を 2 つ足す: `unmerged-commits`（PR が無く issue は閉じたが、main に入っていない commit がブランチに残る）と `issue-lookup-failed`（issue の状態を読めない）。祖先の判定が失敗したときは既存の `git-failed`、`--state all` の検索が失敗したときは既存の `pr-lookup-failed` を使う
- develop の SKILL.md「ループの終わり」の PR を伴わない記録先 issue の項に、親の `reap` がこの子を片付ける条件と、commit を積んだまま閉じると `kept <N> unmerged-commits` で残ることを 1 文足す。`mark` を呼ぶ手順は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: `epic-dispatch.sh reap` に PR の無い子の片付けの経路を足す要件を加える（既存の要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の確認 7 の `no-merged-pr`・`head-mismatch` の出し方に優先する）。「ループの終わり」に親の片付けの条件を書く規定を足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`cmd_reap` と冒頭の reap の説明）
- `plugins/dev-workflow/tests/epic-dispatch.bats`（git・gh のスタブと reap のテスト、SKILL.md のテスト）
- `plugins/dev-workflow/skills/develop/SKILL.md`（「ループの終わり」の 1 項だけ）
- `plugins/dev-workflow/changes/1045.md`（変更の記録）
- `reap` が呼ぶ外部コマンドが、PR の無い子に限って `gh pr list --state all`・`gh api .../issues/<N>`・`git merge-base` の 3 つ増える。マージ済み PR で一致した子の呼び出しは変わらない
