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

### loops

公式記事「Getting started with loops」（https://claude.com/blog/getting-started-with-loops）が定義する **4 つのループタイプ**を、Claude Code のネイティブプリミティブ（`/goal`・`/loop`・`/schedule`・skill・workflows・auto mode）の**合成レシピ集**として設計・記述するためのプラグイン。**独自のループ実行系（常駐スクリプト・カスタム driver）は持たない**——ハーネスが提供するのはレシピ（設計図）と規約であり、反復・スケジュール・停止判定はネイティブプリミティブに委ねる。

```bash
/plugin install loops@oratta-claude-harness
```

**公式 4 ループタイプ:**

| タイプ | 何を手放すか | 主なプリミティブ |
|--------|--------------|------------------|
| ターンベース | 検証ステップ（skill の自己検証） | skill |
| ゴールベース | 停止条件（定量基準まで反復） | `/goal` |
| タイムベース | トリガー（定期・イベント起動） | `/loop`・`/schedule` |
| プロアクティブ | プロンプト自体（人間不在で回る） | 合成（`/schedule` + `/goal` + workflows + auto mode） |

**機能:**
- `/loops:design` — 選択フレームワークに沿ってループ型を選び、停止基準必須・Bad Loop 検査を通したレシピを設計する
- `/loops:goalify <テキスト|ファイル>` — brain dump から機械検証可能な goal ブリーフと `/goal` 起動コマンドを一発生成する
- レシピ集（ゴール / タイム / プロアクティブ）と State 規約・コストガードレール

詳細は `plugins/loops/`（レシピ・規約・リファレンス）および調査資料 `research/` を参照。定期実行のスケジューラ登録・課金選択はレシピのスコープ外（呼び出し側の責務）。

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
