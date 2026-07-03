# Claude Harness

Claude Code用スキル・プラグインのマーケットプレイス

## クイックスタート

```bash
# マーケットプレイスを登録
/plugin marketplace add oratta/claude-harness

# プラグインをインストール
/plugin install longrun@oratta-claude-harness
```

## プラグイン一覧

### longrun

Claude Code ロングラン自律実行システム。instruction.mdを対話的に作成し、人間の介入なしに長時間の自律的実装を完遂する。

```bash
/plugin install longrun@oratta-claude-harness
```

**機能:**
- Brain Dump → Gap Analysis → Interview → Synthesis で instruction.md を対話的に作成
- 専門サブエージェント（意思決定・検証・テスト・仕様管理）による品質担保
- 意思決定の分岐点でGitコミット（ロールバックポイント）
- リアルタイム進捗追跡（`_longrun/progress.md`）

**コマンド:**

| コマンド | 説明 |
|----------|------|
| `/instruction [brain-dump]` | instruction.mdを対話的に作成する |
| `/exec [instruction-path]` | ロングラン自律実行を開始する |
| `/status` | 実行中の進捗状況を確認する |
| `/decisions [番号]` | 意思決定の一覧・詳細を確認する |

**含まれるスキル:**
- `instruction-builder` - 指示ファイルの対話的作成
- `longrun-orchestrator` - 自律実行オーケストレーション

**含まれるエージェント:**
- `decision-agent` - 設計上の意思決定（Opus）
- `verification-agent` - ブラウザ動作確認（Opus）
- `test-agent` - テスト作成・実行（Sonnet）
- `spec-agent` - 仕様書メンテナンス（Sonnet）

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
/plugin add ./plugins/longrun
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
