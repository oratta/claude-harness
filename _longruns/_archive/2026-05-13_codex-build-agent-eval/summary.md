# Run Summary — codex-build-agent-eval

## 期間
- 開始: 2026-05-13 10:55 JST（Setup フェーズ commit `649bb21`）
- 完了: 2026-05-13 13:35 JST（PoC 実行記録 commit `1c73393`）
- 所要: 約 2 時間 40 分（Build フェーズの builder Agent 実装が約 9 分、実 Codex 呼び出しが 165 秒）

## Changes
- `codex-build-agent-poc` (single change, ADDED capability `codex-build-poc`)
- 7 Requirements / 12 Scenarios / 6 タスクセクション

## テスト結果
- Bats（PoC harness ガード自体）: **10 / 10 PASS**
- Vitest（sandbox `greet` 実装）: **2 / 2 PASS**（Codex 経由で実装完了）
- shellcheck: PASS
- 型チェック: グローバル TypeScript で代替確認 PASS

## 意思決定サマリ
- Plan 段階: D-001〜D-008（アーキ・フォールバック・スコープ・モデル・評価軸）
- Build 段階: D-009〜D-013（Bats 隔離・REPO_ROOT 解決・npm install スキップ・git diff merge-base・dry-run スコープ）
- PoC 実行段階: D-014〜D-017（モデル `gpt-5.5` 採用 / `codex exec` 直接 / gitmeta 観察 / Conditional Go 判定）
- 合計 **17 件**（`decisions.md` 参照）

## 4 軸評価スコア

| 軸 | スコア | しきい値 | 判定 | 検証 Agent |
|----|-------|---------|------|----------|
| 品質 | 100% | 100% | ✅ | longrun-verifier |
| 完成度 | 86% | 80% | ✅ | longrun-verifier（指摘 1, 2 修正済み） |
| 機能性 | N/A | — | N/A（CLI のみ） | — |
| UX | N/A | — | N/A（CLI のみ） | — |

## PoC 判定: **Conditional Go**

### PASS
- ✅ #6a TDD ループ成立（実 Codex で RED→GREEN 観測）
- ✅ #7 フォールバック検証（codex 失敗検出 → Opus 経路）
- ✅ #4 / #11 既存ファイル不変（`plugins/longrun` `plugins/codex` `openspec/specs` への変更ゼロ）
- ✅ Bats #12 ガード自体のテスト

### Shortfall（Phase 2 で要解決）
- ⚠️ #6b コミット粒度: Codex は `--allow-empty` の noop test commit で順序「形式上」成立。テストファイル先行の本質は不成立
- ⚠️ no-test-rate: 50%（Codex 内部 gitmeta 計測）
- ⚠️ **★最重要発見**: Codex の commit が親 repo に乗らない（gitmeta/ に閉じる）

## Phase 2 への引き継ぎ（要約）

Phase 2 plan の起票時に必ず以下を含めること:

1. **最初のタスク**: Codex commit を親 repo に乗せる方式の確立（案 A: `-C` を親 repo / 案 B: `format-patch` + `git am` / 案 C: `codex apply` サブコマンド利用）
2. **2 番目のタスク**: Codex 向け prompt から `--allow-empty` noop test 許容を撤去
3. **3 番目のタスク**: `longrun-builder-codex` Agent 新設 + orchestrator 分岐（本来の Phase 2 主題）
4. **必須リスク 4 件**: タイムアウト検出 / 部分成功ロールバック / quota 判別 / NW vs 認証
5. **stretch リスク 4 件**: fidelity drift / empty-test anti-pattern / `~/.codex/` 排他制御 / fidelity スクリプトのスコープ

詳細は `evaluation.md` の「Phase 2 carry-over risks」セクション（9 件）。

## 主要成果物パス

| ファイル | 用途 |
|---------|------|
| `_longruns/2026-05-13_codex-build-agent-eval/plan.md` | 入力 plan |
| `_longruns/2026-05-13_codex-build-agent-eval/evaluation.md` | **本 PoC の最終成果物** |
| `_longruns/2026-05-13_codex-build-agent-eval/prompts.md` | Codex への TDD prompt V1/V2 |
| `_longruns/2026-05-13_codex-build-agent-eval/sandbox/` | Codex が実装した小規模 TS 関数 |
| `_longruns/2026-05-13_codex-build-agent-eval/scripts/` | run-poc / run-fallback / measure-tdd-fidelity + Bats |
| `_longruns/2026-05-13_codex-build-agent-eval/decisions.md` | 17 件の設計判断ログ |
| `openspec/changes/codex-build-agent-poc/` | OpenSpec change（archive 予定） |

## Git log（本 run）

```
1c73393 docs(codex-poc): record PoC execution results - Conditional Go
affd966 feat(codex-poc): record Codex TDD output for sandbox/greet
dd78d39 fix(codex-poc): address longrun-verifier findings
114e0a5 docs(longrun): checkpoint Build phase complete
9597679 merge: integrate codex-build-agent-poc into codex-build-agent-eval
c014cb4 docs(codex-poc): add prompts/evaluation templates and progress trackers
f802d20 feat(codex-poc): add PoC harness scripts with triple-defence guards
ff6ae18 feat(codex-poc): seed sandbox TypeScript project for Codex TDD target
0682ed8 docs(codex-poc): add openspec change + verification-guide
649bb21 chore: longrun execution start - codex-build-agent-eval
```
