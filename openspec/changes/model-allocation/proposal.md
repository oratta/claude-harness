# Proposal: model-allocation

## Why

longrun の自律実行では、全 agent（builder / reviewer / verifier 等）が agent 定義 frontmatter の `model: opus` で一律に最上位モデルを使っており、定型的な検証・要約・リサーチのようなタスクでもコストと時間を浪費している。change-2 で `/longrun:exec` が Workflow ツール化され `opts.model` でロールごとのモデル指定が機構的に可能になったため、plan 段階で change × agent ロールごとの推奨モデルを生成し、ユーザーが plan 確認時に上書きでき、exec がそれを機械的に消費する経路を今整備する。

## What Changes

- `plugins/longrun/templates/plan-template.md` に「モデル割り当て」セクションを追加する。表形式は `| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |`。ユーザーが plan 確認時に直接編集して上書きできる
- ティア → モデル ID の対応表を `plugins/longrun/references/model-tiers.md` に新設し、**1 箇所に集約**する。plan.md・workflow スクリプト・SKILL.md へのモデル ID ハードコードの散在を禁止する
- `longrun-plan` スキル（change-3 分離後のフルモード plan スキル）の Synthesis に推奨生成ステップを追加する。ヒューリスティクス: アーキテクチャレビュー・複雑な TDD 実装 → inherit（指定なし）/ 定型的検証・要約 → haiku / リサーチ・ブラウザ操作・中規模実装 → sonnet。確信度の低いタスクは inherit に倒す（保守的デフォルト）
- `/longrun:exec`（change-2 の新 Workflow 生成ロジック）が plan.md のモデル割り当て表を読み、ティアをリファレンスドキュメント経由で解決して `opts.model` に渡す。`上書き` 欄が非空ならティアより優先する
- モデル割り当てセクションが無い旧 plan.md でも exec が動く（全ロール inherit へのフォールバック。エラーにしない）
- バージョン: longrun 6.1.0 → 6.2.0（plugin.json / marketplace.json top-level / marketplace.json plugins[] の 3 箇所同期。lr プラグインは変更なし）

## Capabilities

### New Capabilities

- `longrun-model-allocation`: plan.md のモデル割り当て表の形式、ティア → モデル ID 対応のリファレンスドキュメント一元管理、exec による `opts.model` 消費、旧 plan.md への全 inherit フォールバックを定義する

### Modified Capabilities

- `longrun-plan-skill`: 要件の追加（ADDED）。`longrun-plan` スキルの Synthesis にモデル割り当て推奨生成ステップを、Validation にモデル割り当てセクションの存在チェックを追加する。既存要件の変更はない

## Impact

- **変更ファイル**:
  - `plugins/longrun/templates/plan-template.md`（「モデル割り当て」セクション追加）
  - `plugins/longrun/skills/longrun-plan/SKILL.md`（推奨生成ステップ + Validation 項目追加、version bump）
  - `plugins/longrun/commands/exec.md` および change-2 で導入される workflow スクリプト生成テンプレート（割り当て表のパースと `opts.model` 反映）
  - `plugins/longrun/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json`（version 6.2.0 同期）
  - `plugins/longrun/README.md`（モデル割り当て機構の説明追記）
- **新規ファイル**: `plugins/longrun/references/model-tiers.md`（ティア → モデル ID 対応表）
- **依存**: change-2（新 exec の Workflow 生成ロジックと `opts.model` の実機検証結果 `workflow-tool-reference.md`）および change-3（plan スキル分離。本 change はフルモード `longrun-plan` のみ対象）の完了が前提
- **非対象**: `plugins/longrun/agents/*.md` の frontmatter（`model: opus`）は書き換えない（change-2 のルール「既存 agent 定義 7 種の .md は書き直さない」を踏襲）。`/longrun:mvp`（change-3 分離後の MVP plan スキル）、lr プラグインも対象外
