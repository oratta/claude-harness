---
description: タスクを分析し、必要なスキルを探して実行計画を立てる。タスク実行前に使用。
argument-hint: [task-description]
---

# タスク実行計画

**pre-task-orchestrator** スキルを使用して、以下のワークフローを実行する。

## Phase 1: タスク分析

タスク「$ARGUMENTS」を **task-analyzer** スキルで分析:

- 必要な技術領域を特定
- 複雑度を評価
- キーワードを抽出

## Phase 2: ローカルスキル検索

**skill-inventory** スキルで、抽出したキーワードに基づきローカルスキルを検索:

- `/mnt/skills/public/` の公式スキル
- `/mnt/skills/user/` のユーザースキル
- プロジェクト固有のスキル

マッチスコア 0.7 以上のスキルがあれば「ローカルで対応可能」と判断。

## Phase 3: 外部スキル検索（必要な場合）

ローカルで適切なスキルが見つからない場合、**skill-finder** スキルで外部検索:

1. Anthropic公式 (anthropics/skills)
2. Awesome Claude Skills (travisvn/awesome-claude-skills)
3. Claude Market (claude-market/marketplace)
4. GitHub Topics検索

スター数50以上、スコア60点以上のスキルを推奨。

## Phase 4: 実行計画の提示

分析結果と推奨スキルを以下の形式で提示:

```
## 📋 実行計画

### タスク概要
[1行要約]

### 技術要件
- カテゴリ: [primary] / [secondary]
- 複雑度: [simple/medium/complex]

### スキル状況
- ✅ ローカル利用可能: [skill-name]
- ⬇️ インストール推奨: [skill-name] from [source]
- ❌ 該当スキルなし: [category]

### 推奨アプローチ
1. [ステップ1]
2. [ステップ2]
...

### 次のアクション
- `yes` - この計画で実行開始
- `install` - 推奨スキルをインストールしてから開始
- `skip` - スキルなしで直接開始
```

## Phase 5: 実行開始

ユーザーが承認したら、**execution-tracker** を有効化してタスク実行を開始。

実行中の修正指示、試行錯誤、アプローチ変更を記録。

## Phase 6: 完了後

タスク完了後、摩擦スコアが高い場合は自動的に振り返りを提案。
手動で振り返りたい場合は `/reflect` コマンドを使用。
