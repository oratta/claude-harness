# oratta-claude-harness リポジトリ構造マップ

調査日: 2026-07-04（survey-repo エージェントによる調査結果）
調査対象: このリポジトリ（marketplace dir、marketplace.json v2.9.0、8プラグイン収録）

## 0. 全体像

marketplace dir（`.claude-plugin/marketplace.json` v2.9.0）に **8プラグイン** を収録。ルートに `openspec/`（spec駆動の変更管理）と `_longruns/`（自律実行のランディレクトリ）が同居。ルートdoc: `README.md`/`AGENTS.md`/`CONTRIBUTING.md`/`CLAUDE.md`。

重要な前提: **harvest / sns-strategy / codex は別marketplace（marketing-harness 等）にあり、このrepoには存在しない**。ここに実在するのは longrun / lr / daily-report / weekly-report / worktree / experience-to-skill / infra / skill-pack。

## 1. プラグイン一覧

| plugin | ver | cmd | skill | agent | 役割 |
|---|---|---|---|---|---|
| **longrun** | 6.3.0 | 5 | 3 | 7 | 自律実行ハーネス（主力）。plan→Workflow生成→TDD Build→4軸Verify |
| **lr** | 6.2.0 | 5 | 0 | 0 | longrunの短縮エイリアス（薄いラッパー） |
| **worktree** | 2.2.0 | 2 | 2 | 0 | wt-setup / wt-clean |
| **daily-report** | 0.3.1 | 1 | 1 | 2 | 音声+Vault+jsonl集約の日次日記。2フェーズcompactor |
| **weekly-report** | 1.1.0 | 1 | 1 | 0 | 週次レポート（git+jsonl直読）cron対応 |
| **infra** | 0.3.0 | 1 | 1 | 5 | Vercel+Supabase+GHAを5フェーズagentで構築 |
| **experience-to-skill** | 0.3.0 | 1 | 1 | 0 | jsonlからSKILL.md蒸留 |
| **skill-pack** | 0.2.0 | 1 | 1 | 0 | skillOverrides/enabledPlugins対話編集 |

## 2. longrun アーキテクチャ（主力・ベストプラクティスの基準系）

設計の核: **オーケストレーションをコード＋JSON Schemaで機構化**（v6.0.0 BREAKING で旧orchestrator SKILLの散文制御を廃止）。

- **Workflow ツール駆動**: `plugins/longrun/commands/exec.md`(312行) がオーケストレータ。plan.md の Changes分解を読み `scripts/render-workflow.mjs` で JSテンプレート（`templates/workflow/{review,build-verify}.workflow.js`）に値を埋め、Workflow ツールで起動。状態の真のソースは runId+キャッシュ と OpenSpec tasks.md。checkpoint.md は人間向け監査ログで「grep/sedで制御フローを決めるな」と `<GATE>` 明文化。
- **StructuredOutput 契約（最も整備）**: `plugins/longrun/schemas/{builder-report,verifier-score,reviewer-verdict}.schema.json` を `opts.schema` でサブエージェント返却に強制し散文パースを排除。「schemaは外部ファイルが唯一のソース、プロンプトへ重複禁止」を `<GATE>` 化。verifier-scoreは部分返却設計（静的verifierがquality/completeness、ブラウザverifierがfunctionality/uxの各2軸+verdictを返し、総合verdict=論理積）。
- **上限のコード化**: `build-verify.workflow.js` は Verifyループを `while(round<3)` + `budget.total && budget.remaining()` null ガードで実装。「上限はコードの条件式、LLMの自制に依存しない」と明記。停止理由を `stopReason: PASS|MAX_ROUNDS_REACHED|BUDGET_EXHAUSTED` で構造化返却。
- **モデル割り当ての単一ソース**: `references/model-tiers.md` がティア→エイリアス解決の唯一ソース。`scripts/resolve-model-allocation.mjs` が消費。モデルID直書き禁止を `<GATE>` 化、未知ティアはfail-soft。
- **承認ゲート**: Workflow内agentからAskUserQuestion不可のため、workflowを分割しメインループに戻って承認取得（Build Contract / Feedback Tier）。
- **縮退モード**: `.degraded-mode` マーカーで OpenSpec CLI不在時も `_longruns/<run>/specs/` に自己完結生成。
- エージェント7本は全て `model: opus`。builder/verifierは `bypassPermissions`、MVP系3本は外部検索を最大1回に制限。

## 3. daily-report のコンテキスト分離（好例）

`plugins/daily-report/skills/daily-report/SKILL.md`(477行) の思想「メイン文脈を汚さない」: `voice-compactor`（Notion MCP）と `llm-log-compactor`（jsonl）を**単一メッセージで並列起動**し、生transcript/jsonl本体をサブエージェントに閉じ込め中間ファイル（voice.md/dailyLLM.md）だけメインに返す。両agentとも「最終message はSTATUS line 1行のみ」。Anthropicの context isolation ベストプラクティスの実装例。

## 4. openspec の仕組み

- `openspec/specs/`: 32個の capability spec（完了変更のsync先）。
- `openspec/changes/`: 進行中5件 + `archive/` 22件。
- `openspec/backlog.md`: 未確定タスク置き場。`/longrun:feedback` Tier 3 もここへ。Codex Builder統合Phase 2の起点やキャンセル経緯を記録。
- `openspec/schemas/longrun-tdd/`: `openspec schema fork` 用テンプレート群。longrun TDDと結合。

## 5. _longruns の仕組み

`_longruns/<YYYY-MM-DD>_<slug>/` がランディレクトリ。中身: `plan.md`/`checkpoint.md`(人間向け)/`decisions.md`/`verification-guide.md`/`summary.md`/`workflow-runs.jsonl`(runId台帳)/`specs/`(縮退時)。MVP系は `research/` を持つ。`_archive/` に完了ラン6件。`/longrun:archive` がchange移動+退避を担う。

## 6. 設計上の弱点・改善余地（実装計画の材料）

**A. StructuredOutput schema の欠落（最重要）**
- infra の5フェーズagent（`plugins/infra/agents/infra-phase-*.md`）は構造化出力契約がなく、状態を **`/tmp/infra-setup-state.md` という散文マークダウン**で受け渡す。longrunが「散文パース廃止」した真逆。
- daily-reportのcompactorも STATUS line（1行散文）を集約パースしておりschema化されていない。
- → 横展開余地: longrunの schemas/ + `opts.schema` を infra・daily-report・weekly-report へ適用。

**B. ハードコード `/tmp` パス（scratchpadルール違反）**
- `plugins/infra/agents/infra-phase-*.md` が `/tmp/infra-setup-state.md` 直書き。セッション分離scratchpad未使用で衝突・残留リスク。

**C. description が極端に長い（トークン浪費）**
- `plugins/worktree/.claude-plugin/plugin.json` の description が複数段落の巨大ブロブ。これが `marketplace.json` にも丸ごと重複コピーされ、全セッションのプラグイン一覧ロードでトークンを食う。「トリガー判定に足る1-2文」原則から逸脱。
- 逆に `plugins/lr/` は薄すぎ、かつ longrun とバージョン非同期（lr 6.2.0 vs longrun 6.3.0）。

**D. 巨大な SKILL.md（コンテキスト重量）**
- `wt-clean`(506行)/`daily-report`(477行)/`longrun-plan`(420行)/`weekly-report`(335行)。起動時に全文ロード。longrunが `references/` へ外出しした分離を他スキルにも適用余地。

**E. メインコンテキストでの重量処理**
- weekly-report は agent 0本で jsonl直読・集約をメインで実行（daily-reportがsubagent隔離したのと非対称）。experience-to-skill も同様（scriptsで軽減はあり）。

**F. エラーハンドリング契約の不在**
- longrunは stopReason/fail-soft/null ガードが整備されるが、infra phase・weekly-report・daily-report のフェーズ失敗時の構造化リカバリ経路が未定義。

**G. model指定の二重管理**
- longrun agentsは frontmatter `model: opus` を持つ一方、実行時に `opts.model` で上書き。優先順位がagent定義から読めず混乱の余地。

**H. resume の same-session 制約**
- `exec.md` Step 5 の通り `resumeFromRunId` はセッションをまたげない。marketplace自動更新でworktreeが吹き飛ぶ運用（CLAUDE.md）と組み合わさると、セッション断での再開が checkpoint.md 手動確認へフォールバックする脆さ。

## 7. 総括（Anthropicベストプラクティス反映の着眼点）

longrunが既に体現する好パターン（schema契約 / コードでの上限 / 単一ソース / context isolation / gate明文化）を**基準系**とし、未適用の infra・weekly-report・daily-report・experience-to-skill へ横展開するのが最短の改善線。投資対効果が高い3点は **(A) StructuredOutput schema化**、**(C) description スリム化**、**(E) 重量処理のsubagent隔離**。いずれもファイルパス特定済み。

起点ファイル:
- schema実装の参照元: `plugins/longrun/schemas/*.schema.json` + `plugins/longrun/commands/exec.md`
- context分離の参照元: `plugins/daily-report/skills/daily-report/SKILL.md` + `plugins/daily-report/agents/*.md`
- 是正対象: `plugins/infra/agents/infra-phase-*.md`（schema無し・`/tmp`直書き）、`plugins/worktree/.claude-plugin/plugin.json`（description肥大）
