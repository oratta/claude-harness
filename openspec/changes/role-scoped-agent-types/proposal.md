## Why

develop の作業者 W とゲート実行者 G は `general-purpose` で起こしているため、作業を 1 手も始めていない時点で使うコンテキストが大きい（2026-09-20 の #326 の実測で初回 43,208〜50,577。読み取り 3 つだけの `dev-workflow:decider` は 18,299）。差の大半は使っていない道具の定義で、上限 150,000 に対して実際に使える幅を削り、上限による強制停止と手渡しを増やしている（#326 の 1 本で 4 回、#509 の集計で交代 58 件・1 PR あたり 3.55 ドル）。

## What Changes

- `plugins/dev-workflow/agents/` に役割ごとの種別を 2 つ足す。作業者用 `dev-workflow:worker`（Read / Edit / Write / Bash / Grep / Glob）と、ゲート実行者用 `dev-workflow:gate-runner`（Read / Bash / Grep / Glob）。どちらもブラウザ・デザインツール・ドキュメント連携・ライブラリ文書検索・Skill・Agent を持たない
- 画面での動作確認は作業者から切り出し、**画面確認役 V** を新しく置く。V は必要なときだけ本体が (3a) と (3b) の間に起こす短命の役で、種別は `general-purpose`（ブラウザの道具を持つ既存の種別）を使う。W の return に `画面確認:` の 1 行を足し、V の結果は (3b) の W に渡して動作確認の証拠にする
- W は `/opsx:*` スキルを呼ばず、worker.md に既にある openspec CLI 直叩きの経路で仕様化・実装・検証・archive を行う（`Skill` を持たないため）
- develop/SKILL.md の役割表・(1)〜(4)、worker.md・gate-runner.md・codex-develop.md の spawn 時の種別指定を新種別に替える
- 新種別の定義は `model: sonnet` を持つ（省略・`inherit` にしない）。`agent-model-guard.sh` の `DECIDER_TYPES` には足さない（新種別に `model: fable` を渡すと従来どおり拒否される）。これを bats で固定する
- plugin.json の `agents` 配列と description、`.claude-plugin/marketplace.json` の description を更新する。常時注入の予算（`tests/injection-budget.txt`）に新しい agent description が加算されるので、description を短く保ち、足りなければ予算を理由付きで動かす

## Capabilities

### New Capabilities
- `dev-workflow-role-agent-types`: develop の作業者とゲート実行者の種別定義（道具の範囲・既定モデル・本文の中身）と、それを検証するテスト

### Modified Capabilities
- `dev-workflow-develop`: W / G をどの種別で起こすか、画面確認役 V を起こす条件と受け渡し、W が Skill を使わず openspec CLI で進めること（要件を追加する）

## Impact

- 新規: `plugins/dev-workflow/agents/worker.md`・`plugins/dev-workflow/agents/gate-runner.md`・`plugins/dev-workflow/tests/role-agent-types.bats`
- 変更: `plugins/dev-workflow/.claude-plugin/plugin.json`・`.claude-plugin/marketplace.json`・`plugins/dev-workflow/skills/develop/SKILL.md`・`plugins/dev-workflow/skills/develop/references/roles/worker.md`・`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`・`plugins/dev-workflow/references/codex-develop.md`・`plugins/dev-workflow/tests/agent-model-guard.bats`・（必要なら）`tests/injection-budget.txt`・`plugins/dev-workflow/changes/330.md`
- `agent-model-guard.sh` の判定ロジックは変えない（コメントに新種別の扱いを 1 行足すかは実装時に判断）
- 仕様レビュー R1（決める役でないとき）と G が要求するレビュアーは `general-purpose` のまま（この change の範囲外。効果を実測したあとで別に扱う）
