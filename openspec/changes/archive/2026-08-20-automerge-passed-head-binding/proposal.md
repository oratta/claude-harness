## Why

auto-merge テンプレートは `agent-review:passed` ラベルの存在だけを合格根拠にしており、ラベルは PR 番号にしか紐づかない。合格後にコミットを push してもラベルは残るため、次の run（workflow_run / schedule）が未レビューの HEAD をマージできる。マージ時の SHA ピンが守るのは「判定〜マージの隙」だけで、「ラベル付与〜次の run」の間の push は守られない（oratta/claude-harness#120。#118 の Codex 敵対的レビュー high 指摘。2026-08-21 に PR #129 で実際に発生し人手でラベルを剥がした）。

## What Changes

- **合格ラベルの HEAD 束縛を合格条件に追加**: pr-review-gate スキルが宣言・証拠コメントの 1 行目に必須と定める規約「対象 HEAD: <40桁フル SHA>」を、workflow が判定時の HEAD SHA と機械照合し、一致するコメントが実在しない限りマージしない（fail-closed。コメント取得失敗も同じ側に倒す）。`pull_request_target: types: [synchronize]` によるラベル自動剥がし案は採らない（剥がしイベントの不発が fail-open になる・`types: [labeled]` 完全一致のトリップワイヤーを緩めるため）
- **新マーカー対 `passed-head-binding`** を auto-merge.yml に追加（不変条件テストが抽出して検査する）
- **退行テスト追加**: `scripts/test-auto-merge-workflow.sh` に照合の存在・`$HEAD_SHA` 変数の同一性・不一致時 `continue`・fail-closed・位置（ラベルチェック後〜マージ前）の静的 assert を追加
- **規約の結合を明文化**: `対象 HEAD:` コメント規約が workflow の合格条件になったこと（規約を変えると機械マージが止まること）を workflow ヘッダと pr-review-gate SKILL.md の両方に記載
- このリポ自身の配備分（`.github/workflows/auto-merge.yml` / `scripts/test-auto-merge-workflow.sh` / `docs/auto-merge.md`）にも同じ差分を適用

## Capabilities

### Modified Capabilities

- `dev-workflow-automerge-templates`: マーカー対に `passed-head-binding` を追加し、安全不変条件に「合格ラベルの HEAD 束縛（対象 HEAD コメント照合）」を追加

## Impact

- `plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml` — 照合の実装＋ヘッダ追記
- `plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh` — 退行テスト（1-f）
- `plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md` — 条件 4→5・調べ方追記
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` — 規約の結合を明文化（version 1.3.0）
- `plugins/dev-workflow/tests/automerge-templates.bats` — マーカー・不変条件テスト
- `.github/workflows/auto-merge.yml` / `scripts/test-auto-merge-workflow.sh` / `docs/auto-merge.md` — 自リポ配備分へ同差分
- `plugins/dev-workflow/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` — 1.10.0 → 1.11.0
- 他配備リポ（genetta-inc/flatmate / oratta/marketing-harness）への伝播は別 PR（正本: `plugins/dev-workflow/docs/auto-merge-deployments.md`）。genetta-inc/suimei は移行 issue genetta-inc/suimei#301
