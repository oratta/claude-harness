## Why

dev-workflow の `github-issue` スキルは「本体セッションが自分で実装し、必要な工程だけ委譲する」手順書になっている。この形だと、エピックの子 issue を Opus サブエージェントに並列で渡したとき、サブエージェントは孫（Agent ツール）を持てないため、仕様レビュー・別コンテキストの PR レビュー・fable 昇格が動かず、自己レビューのまま `agent-review:passed` に到達しうる（flatmate #380 と同じ経路。2026-08-28 の議論、#191 / #193 の続き）。また入口が GitHub issue に限定されているため、issue 経由でない開発（会話・cron・エピックの子）が手順から外れ、仕様化判断と仕様レビューの記録が残らない。

## What Changes

- **BREAKING** `skills/github-issue` を廃止し、`skills/develop` を新設する。発火語（issue 番号・URL・「この issue 対応して」）は develop の description に吸収する
- develop の本体（メインセッション）は**オーケストレータ専任**にする: コードもレビューも自分では書かず、役割 W（作業者）/ R1（仕様レビュアー）/ G（ゲート実行者）を `model` 明示で spawn し、return の要約と記録先のコメント・ラベルだけを見て次に誰を起こすかを決める
- 役割ごとの指示書を `skills/develop/references/roles/` に置く: `worker.md`（今の github-issue Step A〜D 本文と「重要実装の事前分類」表）、`spec-reviewer.md`（今の `references/spec-review.md`）、`gate-runner.md`（pr-review-gate を読んで手順 1〜5 を実行する薄い指示）
- **入口 0（記録先の決定）**を規定する: issue があればそれを記録先に、無ければ issue を切らず、worktree を切って最初の commit を積んだ時点で Draft PR を開いてそれを記録先にする。仕様化判断・仕様レビュー結果・仕様宣言は記録先のコメントに置く。issue を切るのは追跡・キュー・議論が要るときだけ
- **BREAKING** 実行戦略の 3 分岐（solo / delegate+verify / workflow 型）と決定論的シグナルの収集コマンド・4 象限モデルを廃止し、「W のモデル選択」に畳む。残量モード（`FABLE_BUDGET_MODE`）の表と自動導出は据え置く。昇格トリップワイヤーは W の再開時のモデル選択として残す
- **エピックの扱い**（条件・作り方・回し方・完了条件）を規定する
- `commands/work-issue.md` を `commands/develop.md` にリネームし、`/work-issue` はエイリアスとして残す。issue を特定できない入力は issueify 直行ではなく入口 0（Draft PR）に落とし、追跡・キュー・議論が要るときだけ issueify に進む
- pr-review-gate は G の手順書として据え置く。#193 の契約（記録先の探索順 issue → 無ければ PR・仕様宣言の突き合わせ）は変えず、`github-issue` を指していた参照だけ `develop`（`references/roles/worker.md`）に付け替える
- loops プラグインの loop-dev-agent（憲法テンプレート・レシピ）の Step 3 の委譲先を `github-issue` → `develop` に付け替える
- 既存 bats（`work-issue-command` / `issue-draft-sections` / `model-escalation-policy` / `spec-decision-and-review`）を develop の構造に移行する

## Capabilities

### New Capabilities
- `dev-workflow-develop`: 入口を問わない標準開発ワークフロー。本体＝オーケストレータの 1 ループ（W→R1→W→G）、入口 0（記録先の決定）、役割の指示書と model 選択、エピックの条件・作り方・回し方・完了条件

### Modified Capabilities
- `dev-workflow-issue-entry`: `/work-issue` の 5 分岐を `/develop` の入口分岐に置き換える。issue を特定できない入力の既定を issueify 直行から入口 0（Draft PR を記録先）に変え、issueify は追跡・キュー・議論が要るときの選択肢にする。`/work-issue` はエイリアス
- `dev-workflow-execution-strategy`: 実行戦略の判定表・決定論的シグナル・Step D の 3 分岐・abundant の self-contained 委譲条件を REMOVED。残量モードの定義・自動導出・Step B 基準の重心移動は develop の `references/decision-criteria.md` に置く形で MODIFIED
- `dev-workflow-spec-review`: 記録先を「元 issue」から「記録先（issue または Draft PR）」に、手順の置き場所を github-issue SKILL.md から develop の `references/roles/worker.md` / `spec-reviewer.md` に、レビュアーを本体が spawn する R1 に MODIFIED
- `loop-dev-agent-tripwires`: 憲法テンプレートのトリップワイヤー①の乗り換え先の参照を github-issue → develop に MODIFIED

## Impact

- `plugins/dev-workflow/`: `skills/github-issue/` 削除、`skills/develop/` 新設、`commands/develop.md` 新設・`commands/work-issue.md` はエイリアス化、`skills/pr-review-gate/SKILL.md` の参照 2 箇所、`templates/escalation-tripwires.md` の乗り換え先の文言、`.claude-plugin/plugin.json`（skills/commands の登録・description・version）、README、tests 4 本の移行
- `plugins/loops/`: `templates/agent-loop-template.md`・`recipes/loop-dev-agent.md`・`.claude-plugin/plugin.json` の description（github-issue → develop）、version
- ルート `README.md`（dev-workflow 節）、`scripts/test-auto-merge-workflow.sh`（非聖域パスの例に挙げているスキルパス）、`.claude-plugin/marketplace.json`（version 2 件）
- 他リポへの伝播: `/work-issue` を呼んでいる既存の運用はエイリアスで動き続ける。loop-dev-agent の憲法（`docs/agent-loop.md`）を配備済みのリポは、テンプレート更新後に再生成するまで `github-issue` を Skill ツールで呼ぼうとして失敗する（移行手順は design.md）
