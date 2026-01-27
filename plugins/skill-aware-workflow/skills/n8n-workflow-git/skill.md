---
name: n8n-workflow-git
description: n8nワークフローをGitでバージョン管理し、安全に開発・デバッグするためのスキル。ワークフローのAPI更新は原則禁止。WebUIで編集→動作確認→ダウンロード→クレデンシャル分離→Git commitのフローを厳守。クレデンシャル情報は自動的に.envファイルに抽出し、JSONにはプレースホルダーを設定。エラー解決時はContext7、n8n-mcp、フォーラムを調査してから提案。
---

# n8n Workflow Git Management

n8nワークフローをGitでバージョン管理し、安全に開発・デバッグするためのスキル。

**関連スキル**: `n8n-mcp-dev` - n8n-mcpの技術的な使い方はこちらを参照

## Prerequisites

- プロジェクトに`.mcp.json`でn8n-mcpが設定されていること
- ワークフローJSONを保存するディレクトリ（例: `n8n/workflows/`）が存在すること
- `.gitignore`に`n8n/workflows/.env`が追加されていること

## Core Principles

### 1. ワークフローアップデートの厳格な制限

**絶対に守るべきルール:**

- **n8n-mcpを使ったワークフローの直接アップデート（`n8n_update_partial_workflow`, `n8n_update_full_workflow`）は原則禁止**
- WebUIでしか編集できない設定（クレデンシャル選択、データベース選択など）があり、APIでアップデートすると壊れる可能性がある
- ワークフローの変更はすべてWebUIで行い、動作確認後にダウンロードしてGit管理する

**例外的にAPIアップデートが許可される場合:**

1. ユーザーが明示的に許可した場合
2. WebUIで変更不可能な軽微な修正（式の構文エラーなど）の場合
3. ユーザーが「APIで直接修正して」と指示した場合

### 2. クレデンシャル分離（必須）

**n8nからダウンロードしたJSONには、クレデンシャル情報が含まれる。これをそのままコミットしてはならない。**

**クレデンシャル構造の例:**
```json
"credentials": {
  "notionApi": {
    "id": "YQ65SrGujHP7tuAz",
    "name": "Notion account (2025-09-03)"
  }
}
```

**分離後のJSON（コミット対象）:**
```json
"credentials": {
  "notionApi": {
    "id": "${NOTION_API_ID}",
    "name": "${NOTION_API_NAME}"
  }
}
```

**分離後の.env（コミット対象外）:**
```
NOTION_API_ID=YQ65SrGujHP7tuAz
NOTION_API_NAME="Notion account (2025-09-03)"
```

### 3. Git管理ワークフロー

**基本フロー:**

```
1. WebUIでワークフロー編集
2. WebUIで動作確認・テスト実行
3. ユーザーが「OK」と確認
4. n8n_get_workflowでJSONをダウンロード
5. クレデンシャル分離スクリプトを実行
6. ローカルファイルに保存
7. Git commit
```

**ワークフローダウンロード時の処理手順:**

```bash
# 1. JSONをダウンロードして保存
# (n8n_get_workflowで取得したJSONをファイルに書き込む)

# 2. クレデンシャル分離スクリプトを実行
SKILL_BASE=~/.claude/skills/n8n-workflow-git
python $SKILL_BASE/scripts/sanitize_workflow.py n8n/workflows/{name}.json

# 3. .gitignoreに.envが含まれているか確認
grep -q "n8n/workflows/.env" .gitignore || echo "n8n/workflows/.env" >> .gitignore

# 4. Git commit
git add n8n/workflows/{name}.json
git commit -m "n8n({name}): {変更内容}"
```

**保存先の規約:**

- JSONファイル: `n8n/workflows/{workflow-name}.json`
- 環境変数ファイル: `n8n/workflows/.env`
- ファイル名: ワークフロー名をケバブケースに変換（例: `Auto Post to X from Notion` → `auto-post-to-x-from-notion.json`）

## Scripts

### sanitize_workflow.py

クレデンシャルを抽出してプレースホルダーに置換するスクリプト。

```bash
SKILL_BASE=~/.claude/skills/n8n-workflow-git

# 基本的な使い方
python $SKILL_BASE/scripts/sanitize_workflow.py <workflow.json>

# .envファイルの場所を指定
python $SKILL_BASE/scripts/sanitize_workflow.py workflow.json --env-file /path/to/.env

# ドライラン（ファイル変更なし）
python $SKILL_BASE/scripts/sanitize_workflow.py workflow.json --dry-run
```

**処理内容:**
1. JSONからcredentialsフィールドを検出
2. クレデンシャル情報を`.env`ファイルに保存
3. JSONのcredentialsをプレースホルダーに置換

**プレースホルダー命名規則:**
| クレデンシャルタイプ | 環境変数キー |
|---------------------|-------------|
| notionApi | NOTION_API_ID, NOTION_API_NAME |
| twitterOAuth2Api | TWITTER_OAUTH2_API_ID, TWITTER_OAUTH2_API_NAME |
| googleSheetsApi | GOOGLE_SHEETS_API_ID, GOOGLE_SHEETS_API_NAME |

### restore_workflow.py

プレースホルダーを実際のクレデンシャル値に復元するスクリプト（n8nへのインポート用）。

```bash
SKILL_BASE=~/.claude/skills/n8n-workflow-git

# 標準出力に復元したJSONを出力
python $SKILL_BASE/scripts/restore_workflow.py <workflow.json>

# ファイルに保存
python $SKILL_BASE/scripts/restore_workflow.py workflow.json -o restored.json

# 元ファイルを上書き（注意して使用）
python $SKILL_BASE/scripts/restore_workflow.py workflow.json -i
```

## Commands

### ワークフロー一覧の確認

```javascript
n8n_list_workflows({ limit: 50 })
```

### ワークフローのダウンロード

```javascript
// 1. ワークフロー取得
const workflow = n8n_get_workflow({ id: "xxx", mode: "full" })

// 2. ローカルに保存
// 保存先: n8n/workflows/{name}.json

// 3. クレデンシャル分離（必須）
// python sanitize_workflow.py n8n/workflows/{name}.json
```

### ワークフローの状態確認

```javascript
// 実行履歴の確認
n8n_executions({ action: "list", workflowId: "xxx", limit: 10 })

// エラー詳細の確認
n8n_executions({ action: "get", id: "xxx", mode: "error" })
```

### ノードドキュメントの調査

```javascript
// ノードのドキュメント取得
get_node({ nodeType: "nodes-base.notion", mode: "docs" })

// プロパティ検索
get_node({ nodeType: "nodes-base.notion", mode: "search_properties", propertyQuery: "date" })
```

## Error Investigation Checklist

エラーが発生したら、以下を順番に実行：

1. [ ] `n8n_executions`でエラー詳細を取得
2. [ ] 関連ノードのドキュメントを`get_node`で確認
3. [ ] Context7で連携サービスのAPI仕様を確認
4. [ ] Web検索でn8nフォーラムの類似事例を検索
5. [ ] 調査結果をまとめて解決策を提示
6. [ ] **解決策の適用はユーザーがWebUIで行う**（API直接更新は原則禁止）

## File Naming Convention

| ワークフロー名 | ファイル名 |
|---------------|-----------|
| Auto Post to X from Notion | `auto-post-to-x-from-notion.json` |
| Webhook to Slack | `webhook-to-slack.json` |
| Daily Report Generator | `daily-report-generator.json` |

## Git Commit Message Format

```
n8n({workflow-name}): {変更内容}

例:
n8n(auto-post-to-x): fix date format for PostedAt property
n8n(webhook-to-slack): add error handling node
n8n(auto-post-to-x): sync workflow with credential sanitization
```

## Important Reminders

1. **WebUIで編集 → 動作確認 → ダウンロード → クレデンシャル分離** の順序を守る
2. **クレデンシャル分離は必須** - 生のクレデンシャルIDをコミットしてはならない
3. **`.env`ファイルは.gitignoreに追加** - 必ず確認する
4. **APIでのワークフロー更新は最終手段**、必ずユーザー許可を得る
5. **エラー解決は推測禁止**、必ず調査してから提案する
6. ダウンロードしたJSONは**クレデンシャル分離後**すぐにGit commitして履歴を残す

## Restoring Workflow for n8n Import

Gitから取得したワークフローをn8nにインポートする場合：

```bash
SKILL_BASE=~/.claude/skills/n8n-workflow-git

# 1. .envファイルが存在することを確認
cat n8n/workflows/.env

# 2. クレデンシャルを復元
python $SKILL_BASE/scripts/restore_workflow.py n8n/workflows/{name}.json -o /tmp/restored.json

# 3. /tmp/restored.json をn8n WebUIからインポート
```

**注意:** 復元したJSONにはクレデンシャル情報が含まれるため、一時ファイルとして扱い、インポート後は削除する。
