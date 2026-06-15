# Design: workflow-exec

## Context

現行アーキテクチャは `/longrun:exec` → `longrun-orchestrator` SKILL.md（614 行）のメインセッション・インライン展開 → Agent ツール手動制御、という構成。状態管理は checkpoint.md の散文を grep/sed でパースし、Verify ループの上限は SKILL.md の散文指示（「最大3回」）のみで機構的強制がない。サブエージェント契約も散文（プロンプト内の表形式・文字列マッチ）であり、ドリフトすると無言で壊れる。

Claude Code の Workflow ツールは `agent()` / `pipeline()` / `parallel()` によるコードベースのオーケストレーション、`opts.schema` による StructuredOutput 強制、`resumeFromRunId` による再開、`budget` API を提供する。本 change はオーケストレーション層をこのツールに全面移行する（longrun 6.0.0 BREAKING）。

前提: change-1（openspec-degradation）が完了しており、exec Step 0 には縮退モード分岐が存在する。本 change はその Step 0 を保ったまま後段を Workflow 生成に置き換える。

制約:
- Workflow スクリプト内で `Date.now()` / `Math.random()` / 引数なし `new Date()` 使用禁止（タイムスタンプは args 注入）
- workflow のネストは 1 段まで。meta はピュアリテラル
- workflow 内 agent から AskUserQuestion 不可
- 既存 agent 定義 7 種の .md は書き直さない（agentType 参照で再利用）
- marketplace 版のみを編集。version 同期は plugin.json + marketplace.json plugins[] の 2 箇所 × 2 プラグイン（longrun / lr）。marketplace top-level version の bump 要否は別途判断

## Goals / Non-Goals

**Goals:**
- exec を「plan.md 読込 → Workflow スクリプト生成 → 起動」に全面書き換え
- サブエージェント成果物（builder / verifier / reviewer）の JSON Schema 強制と schema の外部化
- Verify ループの上限 3 周 + budget ガードによる暴走の構造的防止
- `resumeFromRunId` による確実な中断再開（checkpoint.md は人間向け監査ログに格下げ）
- status / decisions 系 4 コマンドの削除と orchestrator スキル解体（命名規則 backlog の orchestrator 分消化）
- builder agentType のパラメータ化（Codex Builder Phase 2 の受け皿）

**Non-Goals:**
- MVP モードの Workflow 化（change-3 で分離後、次 run で判断）
- Codex Builder の実接続（agentType デフォルト固定のまま）
- 旧 checkpoint.md 形式の互換読み取り（`/lr:s` `/lr:d` 廃止により不要）
- plan 段階のモデル割り当て消費（change-4 のスコープ。ただし `opts.model` を受け取れるスクリプト構造は妨げない）
- `longrun-orchestrator` 以外の Skill 命名規則リファクタリング

## Decisions

### D1: Workflow スクリプトは exec コマンドが同梱テンプレートから生成する（orchestrator スキル継続ではなく）

orchestrator SKILL.md を Workflow 対応に改修する案もあったが、採らない。SKILL.md インライン展開は「サブエージェントはサブエージェントを生成できない」制約への回避策であり、Workflow ツールがオーケストレーションを担う今、スキル層そのものが不要になる。exec コマンドが `plugins/longrun/templates/` 配下の Workflow スクリプトテンプレートを読み、plan.md の Changes 分解から具体値（change 一覧・依存関係・タイムスタンプ・agentType・schema パス）を埋めて生成する。

- 代替案: orchestrator スキルを残して内部だけ Workflow 化 → スキル間接層が 1 枚残るだけで価値がなく、命名規則 backlog（-or 終わり廃止）も消化できないため却下
- テンプレート方式の理由: 生成ロジックを exec.md の散文に埋め込むとドリフトする。テンプレート（JS 骨格）+ 埋め込みポイント明示なら bats で静的検証できる

### D2: schema は `plugins/longrun/schemas/*.schema.json` に外部化する

builder 完了レポート（コミットハッシュ / テスト結果 / 完了タスク）・verifier 4 軸スコア（functionality / quality / completeness / UX、各 0-100）・reviewer 判定（status: APPROVE|REQUEST_CHANGES + findings[]）の 3 本を独立ファイルにする。

- 代替案: スクリプトテンプレートにインライン埋め込み → jq による単体検証ができず、プロンプト・スクリプト間で重複コピーが発生してドリフト源になるため却下
- 外部化により `jq . plugins/longrun/schemas/*.schema.json` がビルド相当の検証になり、bats で回せる

### D3: Verify ループは while + 明示上限 3 周 + budget.remaining() ガード

```js
let round = 0;
while (round < 3 && budget.remaining() > VERIFY_ROUND_COST) {
  // verifier agent → FAIL なら builder agent に修正依頼
  round++;
}
// 上限到達 or budget 枯渇 → 状態を構造化して返し、メインループがユーザーに報告
```

- 代替案: 再帰 pipeline → ネスト 1 段制約に抵触しやすく、上限がコードに現れないため却下
- 散文指示「最大3回」からの本質的な変更点: 上限がコードの条件式になり、LLM の自制に依存しない

### D4: 再開は resumeFromRunId 一次、checkpoint.md は監査ログに格下げ

exec は workflow 起動直後に runId を `_longruns/<run>/` 内（例: `run-id.txt` ないし run メタファイル）に記録する。再開時は記録済み runId で `resumeFromRunId` を使い、完了済みステップのスキップは Workflow ツールに委ねる。checkpoint.md は人間向けに書き続けるが、これをパースする制御フローは全廃する。

- 代替案: checkpoint.md パース併用のハイブリッド → 二重ソース化で「どちらが真か」問題が再発するため却下
- 旧形式互換読み取りは提供しない（読み手だった `/lr:s` `/lr:d` 自体を本 change で廃止）

### D5: ユーザー対話境界で workflow を分割する

workflow 内 agent から AskUserQuestion が使えないため、Build Contract 承認と Feedback Tier 確認を境界として workflow を複数本に分割する:

1. **workflow #1（Review）**: reviewer agent → 判定 JSON を返して終了
2. メインループ: AskUserQuestion（Build Contract 承認）
3. **workflow #2（Build → Verify）**: builder（change ごと）→ Verify ループ → 結果 JSON を返して終了
4. メインループ: AskUserQuestion（Feedback Tier 確認）→ 必要なら修正用 workflow を追加起動

- 代替案: 1 本の workflow 内で擬似的に待機 → ツール制約上不可能。承認を事前一括取得 → Build Contract の意味（実装前レビュー結果を見て承認）が失われるため却下
- 分割境界はネイティブの `/workflows` ライブビューでそれぞれ進捗が見えるため、status コマンド廃止とも整合する

### D6: builder agentType はテンプレートのパラメータにする（デフォルト固定）

スクリプトテンプレートの builder 呼び出しを `agent(prompt, { agentType: params.builderAgentType })` とし、exec が生成時に既定値 `'longrun:longrun-builder'` を注入する。本 change ではユーザー向けの上書き手段は提供しない（Phase 2: Codex Builder Integration の受け皿のみ）。

### D7: status / decisions は削除し /workflows ライブビューで代替

ユーザー自身が「s, d 全く使ってない」と明言しており、Workflow 化後はネイティブのライブビューが進捗ソースになる。互換シムや deprecation 期間は設けない（BREAKING を明示した v6.0.0）。削除は grep 0 件（受け入れ条件 11）で検証する。

### D8: 実装の一次ソースは workflow-tool-reference.md（最初のタスクで固定）

Workflow ツールのシグネチャ・制約は学習知識で書かず、最初のタスクで hello-world workflow を実機起動して観測し、エビデンス付きで `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` に固定する。以降の全実装タスクはこのファイルを一次ソースとする（change-1 の openspec 実機検証と同じパターン）。

### D9〜D13: 実装フェーズの自律判断（builder 記録）

実装中に確定した判断（詳細とエビデンスは run の `decisions.md` D-C2-1〜D-C2-5）:

- **D9（= D-C2-1）**: Workflow テンプレートを `review.workflow.js` + `build-verify.workflow.js` の 2 本に分割（D5 の承認ゲート分割の実装形）。Build と Verify は承認ゲートを挟まないため 1 本に同居。
- **D10（= D-C2-2）**: テンプレート埋め込みプレースホルダを `${NAME}` ではなく `__NAME__` 形式にする。生成 JS のランタイム `${...}` 補間（例 `${VERIFY_MAX_ROUNDS}`）との置換衝突を構造的に回避。renderer 正規表現 `__([A-Z][A-Z0-9_]*)__`。
- **D11（= D-C2-3）**: schema 機構拒否の bats 検証は外部依存なしの最小バリデータ `scripts/validate-against-schema.mjs` で行う（ajv 等の npm 依存を持ち込まない）。これは Workflow ツール検証層の同等物で、真の検証は実走時にツールが行う。
- **D12（= D-C2-4）**: change-1 が orchestrator SKILL.md に入れた縮退モード分岐を exec.md 付録へ逐語移管して保全（orchestrator 解体に伴う回帰防止）。
- **D13（= D-C2-5）**: marketplace top-level version を 2.6.0 → 2.7.0 に bump（v6.0.0 BREAKING リリースの一貫性 + 3 箇所同期運用方針）。

### 未実機の残課題（orchestrator による実走確認待ち）

`agentType` 解決と `opts.schema` インライン埋め込みでの StructuredOutput 強制は reference §3 で未実機。最小 fixture plan（`plugins/longrun/tests/fixtures/minimal-plan/`）での Review → Build → Verify 1 周完走（受け入れ条件 8b）と Verify 上限 3 周停止・resume スキップ（受け入れ条件 9・10）の**実走**は builder（サブエージェント）が Workflow を起動できないため未実施。静的検証・schema 拒否・テンプレート制約遵守は bats で機械化済み。実走は orchestrator（メインループ）に委ねる（reference §10 に追記済み）。

## Risks / Trade-offs

- [Workflow ツールの実仕様が想定と異なる（opts キー不足・resumeFromRunId のスキップ粒度等）] → 最初のタスク（実機検証）で確定してから設計詳細を確定。reference に記載のない挙動は追加検証してから使う
- [runId 記録前のクラッシュで resume 不能になる] → runId 記録を workflow 起動直後の最初の処理にする。記録が無い場合の案内（新規実行 or `/workflows` からの手動確認）を exec に明記
- [workflow 分割により run 全体の単一 runId が無くなる] → `_longruns/<run>/` に workflow ごとの runId を追記式で記録し、フェーズ対応を残す
- [Verify 上限 3 周は fixture によっては不足] → 上限到達時の報告に「残課題と再実行手順」を含め、ユーザーが追加 workflow を起動できる形にする（無人での上限引き上げはしない）
- [status/decisions 削除でアーカイブ済み run の decisions.md 閲覧導線が消える] → decisions.md はプレーン markdown であり Read で直接読める。README に代替手段を記載
- [v6.0.0 BREAKING による他プロジェクトへの影響] → marketplace 配布はバージョン単位キャッシュのため、bump により明示的に伝播。README に移行ノートを記載

## Migration Plan

1. change-1（openspec-degradation）マージ後の main から worktree を切る（Draft PR 運用）
2. 最初のタスク: Workflow 実機検証 → workflow-tool-reference.md 固定
3. schema 新設 → スクリプトテンプレート → exec.md 書き換え → 削除系 → version bump の順で実装（各節目でコミット）
4. ロールバック: PR 未マージならクローズで戻せる。マージ後に問題が出た場合は本 change 直前の version（longrun は着手時点の起点 version、lr は 5.1.1）タグ時点の plugin を再インストール（checkpoint.md は人間向けに書き続けているため旧版でも run ディレクトリは読める）

## Open Questions

- Workflow スクリプトテンプレートの正確な配置（`plugins/longrun/templates/` 直下 or `templates/workflow/` サブディレクトリ）— 実機検証後、テンプレートが複数本（Review 用 / Build+Verify 用）になるかで決める
- runId 記録ファイルの形式（プレーンテキスト 1 行 or workflow ごとの追記式 JSONL）— D5 の分割数が確定してから決める
- `budget.remaining()` の単位と VERIFY_ROUND_COST の妥当値 — 実機検証（最初のタスク）で確定する
