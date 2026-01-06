# スキルレジストリ一覧

## Tier 1: 公式・高信頼

### anthropics/skills
- **URL**: https://github.com/anthropics/skills
- **README直リンク**: https://raw.githubusercontent.com/anthropics/skills/main/README.md
- **信頼度**: ★★★★★
- **メンテナ**: Anthropic (公式)
- **特徴**: 
  - 公式サポート
  - Claude.ai でも使用可能
  - 高品質保証
- **主要スキル**:
  - docx: Word文書操作
  - pdf: PDF操作
  - pptx: PowerPoint操作
  - xlsx: Excel操作
  - algorithmic-art: アルゴリズムアート
  - canvas-design: キャンバスデザイン
- **インストール**:
  ```bash
  /plugin marketplace add anthropics/skills
  /plugin install docx@anthropic-agent-skills
  ```

### travisvn/awesome-claude-skills
- **URL**: https://github.com/travisvn/awesome-claude-skills
- **README直リンク**: https://raw.githubusercontent.com/travisvn/awesome-claude-skills/main/README.md
- **信頼度**: ★★★★☆
- **メンテナ**: Community (活発)
- **特徴**:
  - Awesome list形式
  - 広範囲のカテゴリ
  - コミュニティ貢献
- **カテゴリ**:
  - Development & Debugging
  - Git & Version Control
  - Documentation & Communication
  - Testing & Quality
  - Data & Analytics

---

## Tier 2: コミュニティ人気

### claude-market/marketplace
- **URL**: https://github.com/claude-market/marketplace
- **信頼度**: ★★★★☆
- **特徴**:
  - キュレーション済み
  - 品質レビューあり
  - CODEOWNERS必須
- **インストール**:
  ```bash
  /plugin marketplace add claude-market/marketplace
  ```

### daymade/claude-code-skills
- **URL**: https://github.com/daymade/claude-code-skills
- **信頼度**: ★★★☆☆
- **特徴**:
  - 25+プロダクションスキル
  - CCPM CLI付属
  - skill-creator メタスキル
- **主要スキル**:
  - skill-creator: スキル作成支援
  - github-ops: GitHub操作
  - markdown-tools: Markdown変換
  - mermaid-tools: 図表生成
  - ppt-creator: プレゼン作成
  - pdf-processor: PDF処理
- **インストール**:
  ```bash
  # CCPM使用
  ccpm search <keyword>
  ccpm install <skill-name>
  
  # または直接
  /plugin marketplace add daymade/claude-code-skills
  ```

### mhattingpete/claude-skills-marketplace
- **URL**: https://github.com/mhattingpete/claude-skills-marketplace
- **信頼度**: ★★★☆☆
- **特徴**:
  - ソフトウェアエンジニアリング特化
  - Git自動化
  - テスト修正
  - コードレビュー
- **主要スキル**:
  - git-commit-push: 自動コミット&プッシュ
  - test-fixer: テスト修正
  - review-implementer: レビュー対応
  - feature-planner: 機能計画

### netresearch/claude-code-marketplace
- **URL**: https://github.com/netresearch/claude-code-marketplace
- **信頼度**: ★★★☆☆
- **特徴**:
  - TYPO3特化
  - PHP モダナイゼーション
  - 技術ドキュメント

---

## Tier 3: GitHub Topics検索

### 検索クエリ

```bash
# トピックで検索
gh search repos --topic claude-code-skills --sort stars --limit 20

# キーワードで検索
gh search repos "claude-code skill" --sort stars --limit 20

# 特定機能で検索
gh search repos "claude-code skill pdf" --sort stars --limit 10
```

### スター数基準

| スター数 | 信頼度 | 推奨度 |
|----------|--------|--------|
| 100+ | 高 | 強く推奨 |
| 50-99 | 中 | 推奨 |
| 20-49 | 低 | 確認後使用 |
| 10-19 | 要注意 | 自己責任 |
| <10 | 未検証 | 非推奨 |

### 追加評価項目

- 最終コミット: 3ヶ月以内が望ましい
- Issue対応: オープンIssueへの対応状況
- ドキュメント: README.md の充実度
- ライセンス: MIT/Apache推奨

---

## カテゴリ別おすすめ

### ドキュメント処理
1. anthropics/skills → docx, pdf, pptx, xlsx
2. daymade/claude-code-skills → markdown-tools

### Git/GitHub
1. mhattingpete/claude-skills-marketplace → git-commit-push
2. daymade/claude-code-skills → github-ops

### フロントエンド
1. anthropics/skills → canvas-design
2. awesome-claude-skills → frontend-design

### テスト
1. mhattingpete/claude-skills-marketplace → test-fixer
2. awesome-claude-skills → test-driven-development

### 自動化
1. daymade/claude-code-skills → cli-demo-generator
2. awesome-claude-skills → workflow-automation
