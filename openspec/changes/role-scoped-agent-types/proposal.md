## Why

develop の作業者 W とゲート実行者 G は `general-purpose` で起こしているため、作業を 1 手も始めていない時点で使うコンテキストが大きい（2026-09-20 の #326 の実測で初回 43,208〜50,577。読み取り 3 つだけの `dev-workflow:decider` は 18,299）。差の大半は使っていない道具の定義で、上限 150,000 に対して実際に使える幅を削り、上限による強制停止と手渡しを増やしている（#326 の 1 本で 4 回、#509 の集計で交代 58 件・1 PR あたり 3.55 ドル）。

## What Changes

- `plugins/dev-workflow/agents/` に役割ごとの種別を 2 つ足す。作業者用 `dev-workflow:worker`（Read / Edit / Write / Bash / Grep / Glob / TaskStop）と、ゲート実行者用 `dev-workflow:gate-runner`（Read / Bash / Grep / Glob / TaskStop）。`TaskStop` は背景で起こした処理を総待ちの上限で止めてから return するのに要るどちらもブラウザ・デザインツール・ドキュメント連携・ライブラリ文書検索・Skill・Agent を持たない
- 画面での動作確認は作業者から切り出し、**画面確認役 V** を新しく置く。V は必要なときだけ本体が (3a) と (3b) の間に起こす短命の役で、種別は `general-purpose`（ブラウザの道具を持つ既存の種別）を使う。W の return に `画面確認:` の 1 行を足し、V の結果は (3b) の W に渡して動作確認の証拠にする
- W は `/opsx:*` スキルを呼ばず、worker.md に既にある openspec CLI 直叩きの経路で仕様化・実装・検証・archive を行う（`Skill` を持たないため）。W の仕様化経路の有無は `openspec --version` だけで決める。既存の要件のうち W に `/opsx:*` を指示しているもの（develop の 1 ループ・前提環境・(3) の 2 分割、仕様レビューの挿入位置）は MODIFIED で書き直し、それを文字列で固定している既存の bats も直す
- develop/SKILL.md の役割表・(1)〜(4)、worker.md・gate-runner.md・codex-develop.md・dev-workflow の README の spawn 時の種別指定を新種別に替える
- 新種別の定義は `model: sonnet` を持つ（省略・`inherit` にしない）。`agent-model-guard.sh` の `DECIDER_TYPES` には足さない（新種別に `model: fable` を渡すと従来どおり拒否される）。これを bats で固定する
- plugin.json の `agents` 配列と description、`.claude-plugin/marketplace.json` の description を更新する。常時注入の予算（`tests/injection-budget.txt`）に新しい agent description が加算されるので、description を短く保ち、足りなければ予算を理由付きで動かす

## Capabilities

### New Capabilities
- `dev-workflow-role-agent-types`: develop の作業者とゲート実行者の種別定義（道具の範囲・既定モデル・本文の中身）と、それを検証するテスト

### Modified Capabilities
- `dev-workflow-develop`: W / G をどの種別で起こすか、画面確認役 V を起こす条件と受け渡し、W の仕様化経路を openspec CLI だけで進めること（要件を追加する）。「1 ループは W→R1→W→G の順で回る」「前提環境を明記する」「W の (3) は 2 回の return に分かれる」の W の工程を openspec CLI に書き直す（MODIFIED）
- `dev-workflow-spec-review`: 「書いた仕様は実装前に別コンテキストがレビューする」の挿入位置を、W の `/opsx:ff` から W の `openspec new change` に書き直す（MODIFIED）
- `manual-codex-develop`: 「委譲は前景実行の 3 手順で行う」の Claude role の種別を、W は `dev-workflow:worker`、G は `dev-workflow:gate-runner`、R1 と独立 PR レビューは `general-purpose`、decider は `dev-workflow:decider` に書き直す（MODIFIED）

## Impact

- 新規: `plugins/dev-workflow/agents/worker.md`・`plugins/dev-workflow/agents/gate-runner.md`・`plugins/dev-workflow/skills/develop/references/roles/screen-checker.md`（画面確認役 V の指示書）・`plugins/dev-workflow/tests/role-agent-types.bats`
- 変更: `plugins/dev-workflow/.claude-plugin/plugin.json`・`.claude-plugin/marketplace.json`・`plugins/dev-workflow/skills/develop/SKILL.md`・`plugins/dev-workflow/skills/develop/references/roles/worker.md`・`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`・`plugins/dev-workflow/references/codex-develop.md`・`plugins/dev-workflow/README.md`（役割とモデルの説明と 1 ループの行）・`plugins/dev-workflow/tests/agent-model-guard.bats`・既存の bats のうち W の `/opsx:*` を文字列で固定しているもの（`plugins/dev-workflow/tests/develop-roles.bats`・`develop-skill.bats`・`spec-decision-and-review.bats`）・（必要なら）`tests/injection-budget.txt`・`plugins/dev-workflow/changes/330.md`
- `agent-model-guard.sh` の判定ロジックは変えない（コメントに新種別の扱いを 1 行足すかは実装時に判断）
- 仕様レビュー R1（決める役でないとき）と G が要求するレビュアーは `general-purpose` のまま（この change の範囲外。効果を実測したあとで別に扱う）
