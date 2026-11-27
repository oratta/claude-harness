## Why

エピックの子の PR のうち、聖域パスに触れて `human-merge` が付いたものは、主が手でマージするまで止まる（2026-10-13 の調査で停止中のセッション 21 個のうち 4 件がマージ待ちの子。#1042 は主がリスクを許容したあとも、マージのボタンを押すためだけに主の手が要った）。主は 2026-10-15 に「`human-merge` などの見送りラベル付きの PR は、マージ条件そのものに触れるものを除いて、親が合理性と危険の低さを見てマージしてよい」と決めた（#1030 の「決定」の表）。ところが自動マージの処理（`.github/workflows/auto-merge.yml`）は見送りラベルが 1 つでも付いていればマージせず、`docs/auto-merge.md` は LLM が直接マージすることを禁じている。親の判断を受け取る入口が無いので、決定を実行できない。

## What Changes

- 自動マージの処理が、親の判断の印（`parent-merge-approved` ラベルと、1 行目 `親のマージ判断: 可`・`親が見た HEAD: <今の HEAD の 40 桁 SHA>` の行を持つ PR コメント）を受け取り、次をすべて満たすときだけ `human-merge` を見送りの理由として数えない
  - 付いている見送りラベルが `human-merge` だけ（`needs-human-merge`・`human-only`・`needs-approval` は親の判断では外さない）
  - PR が実際に聖域パスに触れている（触れていない PR の `human-merge` は人が手で付けた留保なので外さない）
  - 触れたパス（rename 元を含む）に、マージ条件そのもののパスが 1 つも無い
  - 印のコメントの投稿者が OWNER・MEMBER・COLLABORATOR で、`親が見た HEAD:` が今の HEAD と一致する
- マージ条件そのもののパスを、聖域パス（`SACRED`）とは別の正規表現 `MERGE_CONDITION` として持つ。claude-harness では `.github/workflows/`・`plugins/dev-workflow/skills/pr-review-gate/`・`plugins/dev-workflow/templates/auto-merge/`、原本（テンプレート）では `.github/workflows/` を既定にしてリポ固有のものを足せるようにする
- `parent-merge-approved` ラベルが付いたときにも、ラベル即応（`pull_request_target: labeled`）の判定を走らせる
- マージ直前の取り直しでも同じ判定を当て直す。マージ後のコメントに、親の判断で `human-merge` を外したことと、印のコメントの URL を書く
- ほかの条件（`agent-review:passed`・合格の HEAD 束縛・CI green・`AUTOMERGE_PAUSED` 未設定・SHA ピン・`AUTOMERGE_PAT` 未設定の fail-closed）は変えない
- `docs/auto-merge.md`（展開先と原本の両方）に、親の判断で外せる条件・マージ条件そのもののパス・調べ方を書く。「マージの実行権は自動マージの処理の側」の原則は変えない
- 原本と展開先の対（`auto-merge.yml`・`test-auto-merge-workflow.sh`・`docs/auto-merge.md`）を同じに直し、テストを足す

範囲外: 親が判断する手順・判断の基準のファイル・子が止まるときの記録の形・`ci-watch.md` の分岐（#1054 に切り出した）。この change は、印を受け取る入口だけを作る。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-automerge-templates`: 親の判断の印を受け取って `human-merge` を見送りの理由から外す要件を足す（既存の安全不変条件の要件は変えない）

## Impact

- `.github/workflows/auto-merge.yml` と `plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml`（マージ条件そのもの。この PR は主がマージする）
- `scripts/test-auto-merge-workflow.sh` と `plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh`
- `docs/auto-merge.md` と `plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md`、`plugins/dev-workflow/templates/auto-merge/README.md`
- `plugins/dev-workflow/tests/automerge-templates.bats`
- `plugins/dev-workflow/changes/1030.md`（変更の記録）
- 原本を使う他のリポ（flatmate など）は、原本を展開し直すまでこの経路を持たない（今までどおり見送る側に倒れる）
