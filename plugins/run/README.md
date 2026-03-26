# Run Plugin v4.0

Claude Code 自律実行システム。Anthropic の [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) の知見を反映した設計。

## 旧 longrun からの主な変更点

- **リネーム**: `longrun` → `run`、`instruction.md` → `plan.md`、`progress.md` → `checkpoint.md`、`_longrun/` → `_runs/`
- **Skill/Agent正しい使い分け**: 対話型 = Skill、自律実行 = Agent
- **フェーズ簡素化**: 8フェーズ → 5フェーズ（Plan → Build → Verify → Feedback → Archive）
- **Build Contract**: 実装前に run-reviewer がレビュー
- **4軸定量評価**: 機能性/品質/完成度/UX にハードしきい値
- **コンテキストリセット**: フェーズ間で Agent を分離し、checkpoint.md でハンドオフ
- **Context Anxiety 対策**: 完了条件チェックリストで早期終了を防止
- **spec-review-agent を run-reviewer に統合**

## コマンド

| コマンド | 短縮 | 説明 |
|---------|------|------|
| `/run:plan` | `/r:p` | plan.md を対話的に作成 |
| `/run:exec` | `/r:e` | 自律実行を開始 |
| `/run:status` | `/r:s` | 進捗状況を確認 |
| `/run:decisions` | `/r:d` | 意思決定一覧を確認 |
| `/run:archive` | `/r:a` | 完了した実行をアーカイブ |
| `/run:feedback` | `/r:f` | フィードバックを分類・実行 |

## アーキテクチャ

```
Skills (対話的):
  run-planner    ← plan.md 作成
  run-feedback   ← フィードバック Tier 分類

Agents (自律実行):
  run-orchestrator ← 全体指揮
  run-builder      ← TDD 実装
  run-verifier     ← 4軸定量評価
  run-reviewer     ← Build Contract + Spec Review
```
