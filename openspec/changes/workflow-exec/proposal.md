# Proposal: workflow-exec — /longrun:exec の Workflow ツール載せ替え

## Why

現行の `/longrun:exec` は手書きオーケストレーション（`longrun-orchestrator` SKILL.md 614 行のインライン展開 + Agent 手動制御 + checkpoint.md の散文 grep/sed パース）に依存しており、契約のドリフトが無言で壊れる・Verify ループに構造的上限がない・中断再開が脆い、という 3 つの構造的欠陥を抱えている。Claude Code の Workflow ツール（`agent()` / `pipeline()` / `parallel()` / `resumeFromRunId` / `opts.schema`）が利用可能になった今、オーケストレーションをコード（Workflow スクリプト）と JSON Schema（StructuredOutput）に載せ替え、これらを機構的に排除する。

## What Changes

- **BREAKING** `/longrun:exec` を「plan.md を読んだ後、Workflow スクリプトを生成・起動する」形に全面書き換え（longrun は着手時点の現行 version を起点に 6.0.0 へ bump。change-1 マージ済みなら 5.3.0 起点、未マージなら現行値起点で最終的に 6.0.0 に揃える）。`meta.phases` で Review → Build → Verify を表現し、既存 agent 定義 7 種は `agentType: 'longrun:longrun-builder'` 等の参照でそのまま再利用する（agent .md の書き直しはしない）
- **BREAKING** `/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` を削除（lr 5.1.1 → 6.0.0）。進捗確認はネイティブの `/workflows` ライブビューで代替する。削除対象: `plugins/longrun/commands/{status,decisions}.md`、`plugins/lr/commands/{s,d}.md`、`plugins/lr/.claude-plugin/plugin.json` の commands[] と description、`.claude-plugin/marketplace.json` の lr / longrun description 文字列、longrun 側 plugin.json / README、`exec.md` 末尾の「実行中の進捗確認」セクション
- **BREAKING** `longrun-orchestrator` スキルを解体。Workflow スクリプト生成ロジックは exec コマンド + 同梱スクリプトテンプレートへ移管する。backlog の Skill 命名規則リファクタリング（-or 終わり廃止）の orchestrator 分をこれで消化する
- サブエージェント成果物の構造化: `agent(prompt, {schema})` で builder 完了レポート / verifier 4 軸スコア / reviewer 判定を JSON Schema で機構的に強制。schema は `plugins/longrun/schemas/*.schema.json` に外部化
- Verify ループに明示上限（3 周）+ `budget.remaining()` ガードを導入。上限到達時は状態をユーザーに報告して停止
- 再開の一次手段を `resumeFromRunId` に変更。checkpoint.md は人間向け監査ログに格下げ（機械可読パース廃止）。runId は `_longruns/<run>/` 内に記録
- exec Step 0 に権限モード検査を追加（`acceptEdits` 未満なら切り替え案内してから起動）
- builder の agentType をパラメータ化（デフォルト `longrun:longrun-builder` 固定。Codex Builder Phase 2 の受け皿）
- ユーザー対話境界の整理: Build Contract 承認と Feedback Tier 確認では workflow を分割してメインループに戻し、AskUserQuestion → 次の workflow を起動（workflow 内 agent からは AskUserQuestion 不可のため）
- Workflow 起動の opt-in 整理: slash command（`/lr:e` / `/longrun:exec`）起動は「ユーザーが起動した slash command の指示で呼ぶ」要件に該当するため追加確認は不要、と exec 内に明記
- `/lr:e` は exec.md への単純委譲を維持（exec.md 側の orchestrator インライン展開構造が廃止されるため、委譲先の中身が Workflow 生成に変わる）
- **最初のタスク**: Workflow ツールの作法を実環境で確認し、確定したシグネチャと制約をエビデンス付きで `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` に固定する。以降の実装はこのファイルを一次ソースとする

## Capabilities

### New Capabilities
- `workflow-exec`: exec コマンドによる Workflow スクリプトの生成・起動。フェーズ構成、JSON Schema による成果物強制、権限モード検査、承認ゲートでの workflow 分割、builder agentType パラメータ化、起動 opt-in を含む
- `workflow-run-control`: 実行制御。Verify ループの上限 3 周 + budget ガードによる暴走防止、`resumeFromRunId` による中断再開、runId の記録、checkpoint.md の人間向け監査ログへの格下げ
- `legacy-command-removal`: `/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` の削除と全残存参照の排除、`longrun-orchestrator` スキルの解体、バージョン同期（longrun / lr 両プラグインの plugin.json と marketplace.json plugins[] の 2 箇所）
- `workflow-tool-reference`: Workflow ツールの実機検証結果のエビデンス付き固定と、それを一次ソースとする実装規律

### Modified Capabilities

（なし — `openspec/specs/` 配下の既存 spec に exec / status / decisions / orchestrator を対象とするものは存在しない）

## Impact

- **書き換え**: `plugins/longrun/commands/exec.md`（全面）、`plugins/lr/commands/e.md`（委譲先構造の変化に追従する記述修正）
- **削除**: `plugins/longrun/commands/status.md`、`plugins/longrun/commands/decisions.md`、`plugins/lr/commands/s.md`、`plugins/lr/commands/d.md`、`plugins/longrun/skills/longrun-orchestrator/`（解体）
- **新設**: `plugins/longrun/schemas/builder-report.schema.json` / `verifier-score.schema.json` / `reviewer-verdict.schema.json`、Workflow スクリプトテンプレート（`plugins/longrun/templates/` 配下）、`plugins/longrun/tests/`（bats 新設）
- **修正**: `plugins/longrun/.claude-plugin/plugin.json`（skills[] / commands[] / description / version）、`plugins/lr/.claude-plugin/plugin.json`（commands[] / description / version）、`.claude-plugin/marketplace.json`（lr / longrun の description・version）、`plugins/longrun/README.md`
- **バージョン**: longrun は着手時点の現行 version（change-1 マージ済みなら 5.3.0、未マージなら 5.2.0）→ 6.0.0、lr 5.1.1 → 6.0.0（いずれも BREAKING）。各プラグインは plugin.json と marketplace.json plugins[] の 2 箇所を同期する。marketplace.json の top-level version はマーケットプレイス全体のものであり、bump 要否は別途判断
- **互換性**: 旧 checkpoint.md 形式の互換読み取りは提供しない（`/lr:s` `/lr:d` 自体が廃止されるため不要）。既存 agent 定義 7 種（`plugins/longrun/agents/*.md`）は無変更
- **依存**: change-1（openspec-degradation）完了後に着手（縮退モードの Step 0 分岐を前提に exec を設計するため）
