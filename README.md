# Claude Harness

Claude Code用スキル・プラグインのマーケットプレイス

## クイックスタート

```bash
# マーケットプレイスを登録
/plugin marketplace add oratta/claude-harness

# プラグインをインストール
/plugin install skill-aware-workflow@oratta-claude-harness
/plugin install obsidian-llm-session-rules@oratta-claude-harness
```

## プラグイン一覧

### skill-aware-workflow

タスク実行前にスキルを探索し、実行後に新スキル作成を提案するワークフローシステム。

```bash
/plugin install skill-aware-workflow@oratta-claude-harness
```

**機能:**
- タスク分析 → 必要なスキルを自動特定
- ローカル・外部レジストリからスキル検索
- 実行中の摩擦（修正指示、失敗、ピボット）を記録
- 完了後に学びを抽出してスキル作成を提案

**コマンド:**

| コマンド | 説明 |
|----------|------|
| `/plan [task]` | タスクを分析してスキルを探し、実行計画を立てる |
| `/reflect` | 完了したタスクを振り返り、スキル作成を検討 |
| `/find-skill [keyword]` | キーワードでスキルを検索 |

**含まれるスキル:**
- `task-analyzer` - タスク分析、技術要件特定
- `skill-inventory` - ローカルスキル検索
- `skill-finder` - 外部レジストリ検索
- `execution-tracker` - 実行中の摩擦記録
- `skill-proposer` - スキル作成提案
- `pre-task-orchestrator` - ワークフロー統合

**オプション連携: claude-mem**

`claude-mem` プラグインがインストールされている場合、以下の機能が強化されます：

- 複数セッションにわたる摩擦パターンの学習
- 以前延期したスキル提案の追跡
- 累積パターンからの優先度判定

```bash
# claude-mem をインストール（オプション）
/plugin install claude-mem@thedotmack
```

claude-mem がなくても基本機能は動作します。

---

### obsidian-llm-session-rules

Obsidian Vault内でのLLMセッション管理を効率化するプラグイン。

```bash
/plugin install obsidian-llm-session-rules@oratta-claude-harness
```

**機能:**
- セッション内容の自動保存（毎ターン自動保存）
- コンテキストファイルの管理
- Context7 MCPを優先した調査ワークフロー

**コマンド:**

| コマンド | 説明 |
|----------|------|
| `/save-session` | 現在のセッションを手動保存（カスタムサマリ付き） |
| `/update-context` | 重要な決定事項をcontextsに記録 |

**含まれるスキル:**
- `session-logger` - セッション内容をLLM/ディレクトリに保存
- `context-reader` - contexts/ディレクトリからプロジェクト状況を把握
- `research-workflow` - Context7 MCPを優先した調査ワークフロー

**ホームページ:** https://github.com/oratta/obsidian-llm-session-plugin

---

## バンドル

複数のプラグインを一括でインストールできます。

```bash
# 全プラグインをインストール
/plugin install bundle:all@oratta-claude-harness
```

---

## ローカル開発

```bash
# リポジトリをクローン
git clone https://github.com/oratta/claude-harness
cd claude-harness

# Claude Codeでローカルプラグインを追加
/plugin add ./plugins/skill-aware-workflow
/plugin add ./plugins/obsidian-llm-session-rules
```

### 新しいプラグインを追加

```bash
# プラグインディレクトリを作成
mkdir -p plugins/new-plugin/{.claude-plugin,skills,commands}

# plugin.json を作成
cat > plugins/new-plugin/.claude-plugin/plugin.json << 'EOF'
{
  "name": "new-plugin",
  "version": "1.0.0",
  "description": "...",
  "skills": [],
  "commands": []
}
EOF

# marketplace.json を更新
# plugins 配列に追加
```

---

## ライセンス

MIT License

## Author

Oratta
