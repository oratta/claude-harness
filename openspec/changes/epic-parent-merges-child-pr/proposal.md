## Why

#1030 の前半（PR #1056、change `automerge-accepts-parent-merge-judgment`）で、自動マージの処理は親の判断の印（`parent-merge-approved` ラベルと、1 行目 `親のマージ判断: 可`・`親が見た HEAD: <40 桁 SHA>` の行を持つコメント）を受け取って、聖域接触だけで付いた `human-merge` を見送りの理由から外せるようになった。ところが親がいつ・何を見て印を付けるかの手順と基準が無く、develop の SKILL.md は「子の PR のマージは今までどおり子セッションの中で人の承認で行い、本体は自動でマージしない」のままなので、`human-merge` 付きの子の PR は今までどおり主がボタンを押すまで止まる（2026-10-13 の調査で停止中のセッション 21 個のうち 4 件がマージ待ちの子）。

## What Changes

- 子の側: エピックの子のセッション（`epic-dispatch.sh route` が `nested`）は、ゲート合格後の見張りで見送りラベルが `human-merge` だけのとき、主にマージを直接頼む代わりに、既存の「子の停止」の記録を `止まった理由: PR のマージ待ち（human-merge）: <PR の URL>` で残して `mark stopped` で止まる。親から「マージに回した」の返事が届いたら、`ci-watch.sh wait --until-merged` でマージを見届ける。子は自分で印を付けない。ほかの見送りラベルや、エピックの子でないセッションは今までどおり主に頼む（`ci-watch.md` の見送りラベルの分岐）
- 親の側: 親は既存の `stopped` の経路（`wait --resolve` の判断はマージを通さないので親が起こされる）で起こされ、手順 8 の主への報告の前に、記録の `止まった理由:` が `PR のマージ待ち（` で始まる子について新しい手順を行う。対象リポの main の `auto-merge.yml` に `parent-merge-approved` の語があり、見送りラベルが `human-merge` だけのときに限り、`dev-workflow:decider` を起こして新しい基準ファイル `parent-merge-criteria.md` の 6 条件で `裁定: 可`・`裁定: 否`・`不足: <足りないもの>` を受け取る。可なら、判断した HEAD が今も PR の HEAD であることを確かめて、判断のコメント → ラベルの順に付け、`epic-dispatch.sh reply --as parent` で子に伝え、エピックに 1 行残す。否・不足・前提を満たさない・迷ったときは、手順 8 の報告の形で主に上げる
- 基準ファイル `plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md` を新しく置く。条件名と「迷ったら主に上げる」を `parent-pass-criteria.md` とそろえ、別ファイルにする（`parent-pass-criteria.md` は `stop-judge.sh` がそのまま読むプロンプトで、マージはこの基準で通さないと定めているため）
- develop の SKILL.md の「本体は自動でマージしない」の段落を、「本体は `gh pr merge` などで直接マージしない。マージは子セッションの中の人の承認か自動マージの処理が行い、`human-merge` の付いた子の PR は本体が判断の印を付けたときだけ自動マージの処理がマージする」に書き換える
- `commit-and-pr-operations.md` の「ゲート通過 → auto-merge の機械マージが唯一のマージ経路」に、親の判断の印で自動マージの処理が聖域接触だけの `human-merge` を外せることを足す（#1056 の一周目レビューで #1054 に回された件）
- epic-dispatch.sh、develop の SKILL.md の手順 2・手順 8・子の側の「親から届いた返事」の行は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 「エピックの条件・作り方・回し方・完了条件を規定する」の「本体が自動でマージしてはならない（MUST NOT）」とそのシナリオを、直接マージの禁止と親の判断の印の経路に書き換える。親がマージ待ちの子を判断して印を付ける手順と基準ファイルの要件を足す
- `dev-workflow-ci-watch`: エピックの子のセッションで見送りラベルが `human-merge` だけのとき、主に直接頼まず子の停止の記録で親の判断を待つ要件を足す（既存の「CI の見張りの手順は共有 reference に 1 本置く」の見送りラベルの扱いに、この場合に限って優先する）

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（「本体は自動でマージしない」の段落と、Orca 経路の手順のあとへの段落の追加のみ）
- `plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md`（新規）
- `plugins/dev-workflow/references/ci-watch.md`（「`ready` を受けたあと」の 1 の見送りラベルの分岐）
- `plugins/dev-workflow/references/commit-and-pr-operations.md`
- `openspec/specs/dev-workflow-develop/spec.md`・`openspec/specs/dev-workflow-ci-watch/spec.md`（archive で反映）
- `plugins/dev-workflow/tests/`（`epic-dispatch.bats` の「本体は自動でマージしない」を見る 1 行の差し替えと、新しい bats）
- `plugins/dev-workflow/changes/1054.md`（変更の記録）
- 原本を展開し直していない他のリポ（flatmate など）では、親は印を付けずに今までどおり主に上げる
