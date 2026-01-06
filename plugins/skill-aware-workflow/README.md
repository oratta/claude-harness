# Skill-Aware Workflow Plugin

タスク実行前にスキルを探索し、実行後に新スキルを提案するワークフローシステム。

## 概要

このプラグインは、Claude Code でタスクを実行する際に：

1. **実行前**: 必要なスキルを自動探索
2. **実行中**: フィードバックや試行錯誤を記録
3. **実行後**: 学びを抽出してスキル作成を提案

## インストール

```bash
/plugin add /path/to/skill-aware-workflow
```

## 使い方

### タスク開始前

```bash
/plan PDFに署名欄を追加したい
```

これにより：
- タスクを分析して必要な技術を特定
- ローカルスキルを検索
- 外部レジストリから推奨スキルを提示
- 実行計画を提案

### タスク完了後

```bash
/reflect
```

これにより：
- 実行中の摩擦ポイントを分析
- 学びを抽出
- 摩擦スコアが高い場合はスキル作成を提案

### スキル検索のみ

```bash
/find-skill pdf form
```

## コンポーネント構成

```
skill-aware-workflow/
├── skills/
│   ├── task-analyzer/       # タスク分析
│   ├── skill-inventory/     # ローカルスキル検索
│   ├── skill-finder/        # 外部スキル探索
│   ├── execution-tracker/   # 実行追跡
│   ├── skill-proposer/      # スキル提案
│   └── pre-task-orchestrator/ # 全体統合
├── commands/
│   ├── plan.md              # /plan コマンド
│   ├── reflect.md           # /reflect コマンド
│   └── find-skill.md        # /find-skill コマンド
└── hooks/
    └── hooks.json           # 自動トラッキング
```

## ワークフロー図

```
[タスク入力]
     │
     ▼
┌─────────────┐
│task-analyzer│ → 技術要件を特定
└─────┬───────┘
      │
      ▼
┌─────────────────┐
│ skill-inventory │ → ローカルスキル検索
└─────┬───────────┘
      │
   found? ─── no ──▶ ┌──────────────┐
      │              │ skill-finder │ → 外部検索
     yes             └──────┬───────┘
      │                     │
      ▼                     ▼
   [使用]              found? ─── no ──▶ [スキルなしで実行]
                           │
                          yes
                           │
                           ▼
                    [インストール提案]
                           │
                           ▼
                    ┌──────────────────┐
                    │execution-tracker │ → 実行中記録
                    └────────┬─────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │ skill-proposer │ → 完了後提案
                    └────────────────┘
```

## スキル検索ソース

### Tier 1 (高信頼)
- anthropics/skills - Anthropic公式
- travisvn/awesome-claude-skills - コミュニティキュレーション

### Tier 2 (コミュニティ)
- claude-market/marketplace
- daymade/claude-code-skills

### Tier 3 (GitHub検索)
- topic:claude-code-skills
- スター数50以上をフィルタ

## 摩擦シグナル

execution-tracker が検出するシグナル：

| シグナル | 例 | 重み |
|----------|-----|------|
| 明示的修正 | 「違う、〇〇して」 | +2 |
| トーンエスカレーション | 「なんで？」「まだ？」 | +2 |
| アプローチピボット | 「別の方法で」 | +4 |
| 繰り返し失敗 | 同じエラー3回 | +3 |

摩擦スコア 5以上でスキル作成を提案。

## ライセンス

MIT
