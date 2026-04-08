# Longrun Plugin v5.0

Claude Code 自律実行システム。Anthropic の [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) の知見を反映した設計。

## v5.0 変更点

- **リネーム**: `run` → `longrun` に戻した（一般名詞との衝突回避）
- `_runs/` → `_longruns/`、エージェント/スキル名も `longrun-*` に統一

## v4.0 変更点（旧 longrun → run 時代）

- `instruction.md` → `plan.md`、`progress.md` → `checkpoint.md`
- **Skill/Agent正しい使い分け**: 対話型 = Skill、自律実行 = Agent
- **フェーズ簡素化**: 8フェーズ → 5フェーズ（Plan → Build → Verify → Feedback → Archive）
- **Build Contract**: 実装前に longrun-reviewer がレビュー
- **4軸定量評価**: 機能性/品質/完成度/UX にハードしきい値
- **コンテキストリセット**: フェーズ間で Agent を分離し、checkpoint.md でハンドオフ
- **Context Anxiety 対策**: 完了条件チェックリストで早期終了を防止
- **spec-review-agent を longrun-reviewer に統合**

## コマンド

| コマンド | 短縮 | 説明 |
|---------|------|------|
| `/longrun:plan` | `/lr:p` | plan.md を対話的に作成 |
| `/longrun:exec` | `/lr:e` | 自律実行を開始 |
| `/longrun:status` | `/lr:s` | 進捗状況を確認 |
| `/longrun:decisions` | `/lr:d` | 意思決定一覧を確認 |
| `/longrun:archive` | `/lr:a` | 完了した実行をアーカイブ |
| `/longrun:feedback` | `/lr:f` | フィードバックを分類・実行 |

## アーキテクチャ

```
Skills (対話的):
  longrun-planner    ← plan.md 作成
  longrun-feedback   ← フィードバック Tier 分類

Agents (自律実行):
  longrun-orchestrator ← 全体指揮
  longrun-builder      ← TDD 実装
  longrun-verifier     ← 4軸定量評価
  longrun-reviewer     ← Build Contract + Spec Review
```
