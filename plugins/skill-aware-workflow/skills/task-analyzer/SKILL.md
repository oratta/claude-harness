---
name: task-analyzer
description: This skill should be used when the user provides a new task, asks "what do I need for this task", wants to understand task requirements, or before starting any significant development work. It analyzes tasks to identify required technologies, complexity, and skill categories.
version: 1.0.0
---

# Task Analyzer

タスクの内容を分析し、実行に必要な技術領域・スキルカテゴリを特定するスキル。

## 目的

タスク実行前に以下を明確化する：
- 必要な技術スタック（言語、フレームワーク、ツール）
- タスクの複雑度（simple / medium / complex）
- 必要なスキルカテゴリ
- 潜在的な課題や依存関係

## 分析プロセス

### Step 1: タスク分類

タスクを以下のカテゴリに分類する：

| カテゴリ | 例 | 典型的なスキル |
|---------|-----|---------------|
| document | ドキュメント作成・編集 | docx, pdf, markdown |
| presentation | スライド作成 | pptx |
| data | データ処理・分析 | xlsx, csv, pandas |
| frontend | UI/Web開発 | react, html, css |
| backend | サーバー/API開発 | node, python, database |
| devops | CI/CD, インフラ | docker, github-actions |
| testing | テスト作成・実行 | jest, pytest, playwright |
| git | バージョン管理 | git-operations |
| automation | 自動化スクリプト | bash, python |

### Step 2: 技術要件抽出

タスク説明から以下を抽出する：

```
入力: "Reactでダッシュボードを作って、APIからデータを取得して表示"

出力:
- primary_category: frontend
- secondary_categories: [backend, data]
- technologies: [react, javascript, rest-api, fetch]
- complexity: medium
- estimated_skills: [frontend-design, api-integration]
```

### Step 3: 複雑度評価

| 複雑度 | 基準 |
|--------|------|
| simple | 単一技術、1-2ステップ、明確なゴール |
| medium | 2-3技術の組み合わせ、複数ステップ |
| complex | 4+技術、依存関係あり、判断分岐あり |

### Step 4: 出力フォーマット

分析結果を構造化して出力する：

```yaml
task_analysis:
  summary: "タスクの1行要約"
  categories:
    primary: frontend
    secondary: [backend]
  technologies:
    required: [react, typescript]
    optional: [tailwind]
  complexity: medium
  skill_requirements:
    - category: frontend
      keywords: [react, component, dashboard]
    - category: api
      keywords: [fetch, rest, json]
  potential_challenges:
    - "状態管理の設計"
    - "APIエラーハンドリング"
  recommended_approach: "コンポーネント分割から開始"
```

## 使用例

ユーザーが「PDFを編集して署名欄を追加したい」と言った場合：

```yaml
task_analysis:
  summary: "PDFに署名欄を追加"
  categories:
    primary: document
  technologies:
    required: [pdf]
  complexity: simple
  skill_requirements:
    - category: document
      keywords: [pdf, edit, form, signature]
  recommended_approach: "pdf スキルを使用してフォームフィールドを追加"
```

## 次のステップ

分析完了後、以下のスキルに引き継ぐ：
- **skill-inventory**: ローカルスキルの検索
- **skill-finder**: 外部スキルの探索

## 参照

詳細なカテゴリ定義は `references/categories.md` を参照。
