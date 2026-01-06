---
name: skill-finder
description: This skill should be used when local skills are insufficient, user asks to "find skills", "search for Claude Code skills", "look for a skill to do X", or when skill-inventory returns needs_external_search. It searches curated registries and GitHub for relevant skills.
version: 1.0.0
---

# Skill Finder

外部のキュレーションリストやGitHubからスキルを探索するスキル。

## 目的

- キュレーションリストから適切なスキルを発見
- GitHubでスター数の多い人気スキルを検索
- スキルの品質・信頼性を評価
- インストール推奨を提示

## 検索ソース（優先順）

### Tier 1: 公式・信頼性高

1. **Anthropic Skills** (anthropics/skills)
   - URL: https://github.com/anthropics/skills
   - 信頼度: ★★★★★
   - 特徴: 公式サポート、高品質

2. **Awesome Claude Skills** (travisvn/awesome-claude-skills)
   - URL: https://github.com/travisvn/awesome-claude-skills
   - 信頼度: ★★★★☆
   - 特徴: コミュニティキュレーション、広範囲

### Tier 2: コミュニティ人気

3. **Claude Market** (claude-market/marketplace)
   - URL: https://github.com/claude-market/marketplace
   - 信頼度: ★★★★☆
   - 特徴: レビュー済み、品質管理あり

4. **daymade Skills** (daymade/claude-code-skills)
   - URL: https://github.com/daymade/claude-code-skills
   - 信頼度: ★★★☆☆
   - 特徴: 25+スキル、CCPM CLI付き

### Tier 3: GitHub検索

5. **GitHub Topics検索**
   - クエリ: `topic:claude-code-skills`
   - フィルタ: stars:>50
   - 信頼度: 変動（スター数で判断）

## 検索プロセス

### Step 1: キュレーションリスト検索

`references/registries.md` に定義されたレジストリを順に検索：

```
検索キーワード: [pdf, form, signature]

1. anthropics/skills をチェック
   → pdf スキルあり（公式）
   
2. awesome-claude-skills をチェック
   → pdf-processor, form-filler 発見
```

### Step 2: 品質評価

各候補スキルを以下の基準で評価：

| 評価項目 | 配点 | 基準 |
|----------|------|------|
| ソース信頼度 | 30点 | Tier 1=30, Tier 2=20, Tier 3=10 |
| GitHubスター | 25点 | 100+星=25, 50+=20, 10+=10 |
| メンテナンス | 20点 | 3ヶ月以内更新=20, 6ヶ月=10 |
| ドキュメント | 15点 | README充実=15 |
| キーワード適合 | 10点 | マッチ率×10 |

**採用閾値**: 60点以上で推奨

### Step 3: GitHub API検索（Tier 1-2で見つからない場合）

```bash
# GitHub CLI で検索
gh search repos "claude-code skill pdf" --sort stars --limit 10

# または REST API
curl -s "https://api.github.com/search/repositories?q=claude-code+skill+pdf&sort=stars"
```

スター数フィルタ:
- 100+ stars: 高信頼
- 50-99 stars: 中信頼
- 10-49 stars: 要確認
- <10 stars: 推奨しない

### Step 4: 結果判定

```yaml
search_result:
  query_keywords: [pdf, form, signature]
  
  recommended_skills:
    - name: pdf
      source: anthropics/skills (Tier 1)
      score: 85
      stars: N/A (official)
      install: "/plugin install pdf@anthropic-agent-skills"
      reason: "公式スキル、高品質、PDF操作全般をカバー"
      
    - name: pdf-processor
      source: daymade/claude-code-skills (Tier 2)
      score: 72
      stars: 156
      install: "ccpm install pdf-processor"
      reason: "フォーム処理に特化"
      
  not_recommended:
    - name: pdf-helper
      source: github search
      score: 35
      stars: 8
      reason: "スター不足、最終更新1年前"
      
  decision: found | partial | not_found
  
  # found: 60点以上のスキルが存在
  # partial: スキルはあるが完全にはカバーしない
  # not_found: 適切なスキルなし
```

## スキルなしの場合のフォールバック

`decision: not_found` の場合：

1. スキルなしでタスク実行を開始
2. **execution-tracker** で実行過程を記録
3. タスク完了後に **skill-proposer** で新スキル提案

## インストールコマンド生成

```bash
# Anthropic公式
/plugin marketplace add anthropics/skills
/plugin install <skill-name>@anthropic-agent-skills

# コミュニティ
/plugin marketplace add <owner>/<repo>
/plugin install <skill-name>@<marketplace-name>

# 直接インストール
/plugin add https://github.com/<owner>/<repo>/tree/main/skills/<skill-name>
```

## 参照

- `references/registries.md` - レジストリ詳細情報
- `references/quality-criteria.md` - 品質評価基準の詳細
