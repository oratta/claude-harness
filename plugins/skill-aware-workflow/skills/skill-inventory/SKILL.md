---
name: skill-inventory
description: This skill should be used when checking available local skills, searching installed skills by keyword, or verifying if a specific skill exists locally. It manages and searches the local skill inventory before looking externally.
version: 1.0.0
---

# Skill Inventory

ローカルにインストールされているスキルを検索・管理するスキル。

## 目的

- 現在利用可能なスキルの一覧取得
- キーワードによるスキル検索
- スキルの詳細情報取得
- 外部検索が必要かどうかの判断

## スキル検索場所

以下の場所を順に検索する：

1. `/mnt/skills/public/` - Anthropic公式スキル
2. `/mnt/skills/user/` - ユーザーアップロードスキル
3. `/mnt/skills/private/` - プライベートスキル
4. `~/.claude/skills/` - ローカルインストールスキル
5. 現在のプロジェクトの `.claude/skills/` - プロジェクト固有スキル

## 検索プロセス

### Step 1: スキル一覧の収集

各スキルディレクトリを走査し、SKILL.md のフロントマターを解析：

```bash
# スキル一覧を取得するスクリプト
find /mnt/skills -name "SKILL.md" -exec dirname {} \;
```

### Step 2: メタデータ抽出

各 SKILL.md から以下を抽出：
- name: スキル名
- description: 説明文（トリガーキーワード含む）
- version: バージョン

### Step 3: キーワードマッチング

task-analyzer の出力を受け取り、マッチするスキルを検索：

```
入力キーワード: [pdf, edit, form]

検索結果:
1. pdf (score: 0.95) - /mnt/skills/public/pdf
   マッチ: "pdf", "form"
   
2. docx (score: 0.30) - /mnt/skills/public/docx  
   マッチ: "edit"
```

### Step 4: スコアリング

マッチスコアの計算方法：

| 条件 | スコア |
|------|--------|
| name が完全一致 | +0.5 |
| description にキーワード含む | +0.2/キーワード |
| カテゴリ一致 | +0.3 |

閾値: 0.5 以上で「ローカルに適切なスキルあり」と判断

## 出力フォーマット

```yaml
inventory_result:
  search_keywords: [pdf, edit, form]
  
  found_skills:
    - name: pdf
      path: /mnt/skills/public/pdf
      match_score: 0.95
      matched_keywords: [pdf, form]
      recommendation: "高い適合性 - このスキルを使用"
      
  partial_matches:
    - name: docx
      path: /mnt/skills/public/docx
      match_score: 0.30
      matched_keywords: [edit]
      note: "部分的にカバー可能"
      
  missing_capabilities:
    - "署名機能の専用スキルなし"
    
  decision: local_sufficient | needs_external_search | no_skill_needed
```

## 判断基準

| decision | 条件 |
|----------|------|
| local_sufficient | スコア0.7以上のスキルが存在 |
| needs_external_search | スコア0.5未満、または重要なキーワードが未マッチ |
| no_skill_needed | タスクが単純で汎用的（スキル不要） |

## 次のステップ

- `local_sufficient` → そのスキルを使用してタスク実行
- `needs_external_search` → **skill-finder** に引き継ぎ
- `no_skill_needed` → そのままタスク実行

## スクリプト

`scripts/list_skills.sh` - ローカルスキル一覧を取得
`scripts/search_skills.py` - キーワード検索実行
