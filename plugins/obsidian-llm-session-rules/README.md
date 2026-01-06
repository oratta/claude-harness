# Obsidian LLM Session Plugin

Claude Code用のプラグインで、Obsidian Vault内でのLLMセッション管理を効率化します。

## 機能

### 自動セッションログ保存（v1.1.0〜）

**Claudeとのやりとりが自動的にLLM/ディレクトリにMarkdownファイルとして保存されます。**

- 毎ターン（Claudeの応答ごと）に自動保存
- ユーザーの操作は不要
- セッションIDと日付でファイル名を生成

### スキル

| スキル | 説明 |
|--------|------|
| **session-logger** | セッション内容を手動でLLM/ディレクトリに保存 |
| **context-reader** | contexts/ディレクトリからプロジェクト状況を把握 |
| **research-workflow** | Context7 MCPを優先した調査ワークフロー |

### コマンド

| コマンド | 説明 |
|----------|------|
| `/save-session` | 現在のセッションを手動保存（カスタムサマリ付き） |
| `/update-context` | 重要な決定事項をcontextsに記録 |

## インストール

```bash
# マーケットプレイスを追加
/plugin marketplace add oratta/obsidian-llm-session-plugin

# プラグインをインストール
/plugin install obsidian-llm-session-rules@oratta
```

## 使い方

### 自動ログ保存

**インストール後、特別な操作は不要です。** Claudeとのやりとりは自動的に`LLM/`ディレクトリに保存されます。

- ファイル名: `YYYY-MM-DD_セッションID.md`
- 保存タイミング: Claudeが応答するたび
- 保存先: 作業ディレクトリの`LLM/`フォルダ（自動作成）

### 調査時

技術的な調査はContext7 MCPを最優先で使用します。見つからない場合のみWeb検索を使用。

### 手動でサマリ付き保存したい時

```
/save-session
```

カスタムサマリを付けて保存したい場合に使用します。

### 重要な決定をした時

```
/update-context
```

または「コンテキストを更新して」と伝えると、contexts/ディレクトリに記録します。

## ディレクトリ構造

```
your-vault/
├── LLM/                    # セッションログ保存先
│   └── 2025-01-15_1430_機能追加.md
├── docs/contexts/          # プロジェクトコンテキスト
│   ├── prd.md
│   └── 決定事項.md
└── ...
```

## ライセンス

MIT
