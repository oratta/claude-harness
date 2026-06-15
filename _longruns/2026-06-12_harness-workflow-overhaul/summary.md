# Summary — harness 大型改修 run

- **開始**: 2026-06-12（`/lr:e` 起動、Setup フェーズ）
- **完了（自律フェーズ）**: 2026-06-13（Verify フェーズ完了、Feedback ゲート到達）
- **run ディレクトリ**: `_longruns/2026-06-12_harness-workflow-overhaul/`
- **対象リポジトリ**: claude-harness（このリポジトリ）+ marketing-harness（change-5 のみ）

## ゴール（達成）

longrun の手書きオーケストレーション（SKILL.md インライン展開 + Agent 手動制御 + checkpoint.md 散文パース）を Claude Code の **Workflow ツール**に載せ替え、サブエージェント契約を **JSON Schema（StructuredOutput）** で機構的に強制。あわせて OpenSpec CLI 不可環境の縮退モード、MVP モードの独立スキル分離、plan 段階のモデル割り当てリコメンド機構を導入した。

## Changes 一覧

| # | change | リポジトリ | 内容 | version | 状態 |
|---|--------|-----------|------|---------|------|
| 1 | openspec-degradation | claude-harness | OpenSpec CLI 不可環境向け縮退モードを一級の動作モードに | longrun 5.3.0 | ✅ マージ済み (6ee81e5) |
| 2 | workflow-exec | claude-harness | `/longrun:exec` の Workflow ツール載せ替え（BREAKING）。status/decisions/lr:s/lr:d 廃止、orchestrator 解体 | longrun/lr 6.0.0 | ✅ マージ済み (346f3b9) |
| 3 | mvp-plan-split | claude-harness | MVP モードを独立スキル `longrun-mvp-plan`（+ `/longrun:mvp` `/lr:m`）に分離 | longrun/lr 6.1.0 | ✅ マージ済み (c742b3d) |
| 4 | model-allocation | claude-harness | plan 段階の change×ロール別モデル割り当てリコメンド → exec が opts.model 消費 | longrun 6.2.0 | ✅ マージ済み (b9000a7) |
| 5 | harvest-structured-output | marketing-harness | harvest サブエージェント契約の StructuredOutput 化（散文契約 → schema 4本） | harvest 0.14.0 | ✅ feature ブランチ・Draft PR #8 |

## テスト結果

| スイート | 結果 | 備考 |
|---------|------|------|
| `bats plugins/longrun/tests/` | **219 PASS / 0 fail** | 本 run で新設（change-1 で 55 → 最終 219） |
| `bats plugins/experience-to-skill/tests/` | 24 PASS | 回帰なし |
| `bats plugins/daily-report/tests/` | 48 PASS | 回帰なし |
| `bats plugins/harvest/tests/*.bats` | **375 PASS / 0 fail** | baseline 313 → 375（新規 62） |

ビルド相当（jq 構文検証）: plugin.json / marketplace.json / schema JSON 全 PASS。lint 相当（shellcheck / node --check）クリーン。

## Workflow ツール実機検証（受け入れ条件 11b / 8 / 10）

`workflow-tool-reference.md` にエビデンス固定済み。最小 fixture で実走確認：

- **review workflow**（runId `wf_b0263fa2-2fe`）: `agentType: 'longrun:longrun-reviewer'` 解決 + APPROVE 判定の StructuredOutput 返却
- **build-verify workflow**（runId `wf_a36f47ee-baf`）: builder/verifier agentType 解決、TDD 実装（commit 95b6e23）、Verify ループ 1 周 PASS（`stopReason: PASS`）
- **resume**（`resumeFromRunId`）: 3ms / tool_uses 0 で同一結果 = 完了済み builder 再実行なし（受け入れ条件 10）

## 意思決定サマリ（decisions.md に全 26 件のエビデンス付き記録）

- **D-S1**: openspec の volta グローバル(1.2.0) と npx ローカル(0.23.0) 乖離を発見 → change-1 で OR 判定に確定
- **D-BC1 / D-B2 / D-B3**: Build Contract APPROVE、Spec Review ラウンド1（3 APPROVE / 2 REQUEST_CHANGES）→ 修正 → ラウンド2 全 APPROVE。バイアス緩和ガードを各ラウンドで適用
- **D-C1-1**: 実機検証で `openspec apply` が現行 CLI に不在、longrun-tdd スキーマは `schema fork` 必須（init では入らない）を確定
- **D-C2-1〜5**: workflow テンプレート 2 本分割、プレースホルダ `__NAME__` 形式（JS 補間との衝突回避）、schema 拒否の最小バリデータ自作、縮退分岐の exec.md 移管
- **D-V1 / D-V2**: Verify で change-5 の中重大度ドリフト finding を検出 → 修正ループ 1 回で解消（完成度 86%→100%）

## 4 軸評価スコア（最終）

| 軸 | claude-harness | marketing-harness | しきい値 | 判定 |
|----|---------------|-------------------|---------|------|
| 品質 | 100% | 100% | 100% | ✅ |
| 完成度 | 100% | 100% | 80% | ✅ |
| 機能性 | bats 162 Scenario + fixture 実走で代替担保 | 同左 | 100% | ✅ |
| UX | N/A（CLI、Web UI なし） | N/A | 70% | N/A |

## ユーザー手動確認待ち（live E2E）

CLI プラグインのため、以下の slash command 実走確認はユーザーに委ねる（自律実行では検証不可）。受け入れ条件の機構は全て静的検証 + fixture 実走で確認済み：

1. **(change-2)** 代表 plan.md で `/lr:e` を実行 → Workflow 起動 → `/workflows` 進捗表示 → 承認ゲートで AskUserQuestion → 完走
2. **(change-2)** Verify ループを意図的に FAIL させ 3 周で停止・報告を確認
3. **(change-2)** 中断 → `resumeFromRunId` 再開で完了フェーズがスキップされる
4. **(change-1)** `npx openspec` を PATH から外し縮退モード提案 → 完走
5. **(change-3)** `/longrun:mvp`（`/lr:m`）で MVP プラン作成が完走、`--mode=mvp` で移行案内
6. **(change-4)** plan.md のモデル割り当て表が exec の opts.model に反映される
7. **(change-5)** `/harvest:knowledge` と `/harvest:bestprac-refresh` の成果物が現行同等、不正 fixture でフォールバック

## マージ状況

- claude-harness: run ブランチ `longrun-workflow-setup` に change-1〜4 を `--no-ff` 統合済み。Draft PR #6 で常時バックアップ。**main へのマージは未実施（承認制）**
- marketing-harness: `feature/harvest-structured-output` に change-5、Draft PR #8。**main へのマージは未実施（承認制）**
- per-change の main 向け PR 分割は Feedback フェーズでユーザーに確認（decisions.md D-B1）
