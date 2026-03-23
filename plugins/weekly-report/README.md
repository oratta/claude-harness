# Weekly Report Plugin

Obsidian Vault内のプロジェクト活動を自動集約し、週次実績レポートを生成するClaude Codeプラグイン。

## 前提条件

このプラグインを使用するには、以下のVault構造・設定が必要です。

### 1. Obsidian Vaultがgitリポジトリであること

Vault全体が `git init` されており、定期的にコミットされていること（例: obsidian-git プラグインによる自動バックアップ）。LLMセッションログやObsidianファイル変更の収集にVaultのgit履歴を使用します。

### 2. ディレクトリ構造

```
your-vault/
├── 02 - PERIODIC/Weekly/         # 週次ノートの保存先
│   └── GGGG-WXX.md              # ISO週番号形式（例: 2026-W12）
├── 12 - PROJECT/                 # プロジェクトディレクトリ
│   └── [project-name]/
│       ├── phases/               # フェーズ管理（frontmatter必須）
│       │   └── *.md
│       └── LLM/                  # プロジェクト別LLMログ（除外対象）
├── 90 - LLM/                    # VaultレベルLLMセッションログ
│   └── YYYYMMDD-*.md            # 日付プレフィックス形式
├── __META/
│   ├── TEMPLATE/
│   │   └── 02 - WEEKLY Template.md   # 週次ノートテンプレート
│   └── project-registry.md      # プロジェクトレジストリ
```

### 3. プロジェクトレジストリ (`__META/project-registry.md`)

ソースコードリポジトリのパスを管理するMarkdownテーブル。このファイルがないとソースコードのgitログは収集されません。

```markdown
| project     | source_path                          | label | notes |
| ----------- | ------------------------------------ | ----- | ----- |
| MyProject   | /absolute/path/to/source/repo        | main  |       |
| AnotherProj |                                      | main  |       |
```

- `source_path` が空のプロジェクトはソースコード活動をスキップ
- `source_path` はソースコードリポジトリの絶対パス

### 4. フェーズファイルのfrontmatter

`12 - PROJECT/[name]/phases/*.md` のfrontmatterに以下のフィールドが必要です：

```yaml
---
type: phase
status: active    # active / on-hold / pending / completed
deliverable: "成果物の説明"
progress: 50      # 進捗率（%）
---
```

### 5. LLMセッションログの命名規則

`90 - LLM/` 内のファイルは `YYYYMMDD-<サマリ>.md` 形式であること。日付プレフィックスで対象週のログをフィルタリングします。

### 6. 週次ノートのセクション構造

週次ノートに `## 週次振り返り（金曜）` セクションがある場合、その直前にレポートを挿入します。なければファイル末尾に追加します。

## インストール

```bash
# マーケットプレイスを追加（未追加の場合）
/plugin marketplace add oratta/claude-harness

# プラグインをインストール
/plugin install weekly-report@oratta-claude-harness
```

## 使い方

```bash
# 直近の完了した週のレポートを生成
/weekly-report

# 特定の週を指定
/weekly-report 2026-W12
```

## 機能

- **ソースコードGitログ収集**: 各プロジェクトのリポジトリからcommitを取得し、conventional commit type別に分類・要約
- **LLMセッションログ収集**: 対象週のセッションログをプロジェクト別にグルーピング
- **Obsidianファイル変更追跡**: Vault gitログからプロジェクト内の変更ファイルを収集
- **フェーズ状態表示**: アクティブなフェーズの成果物・進捗率を表示
- **冪等な挿入**: 再実行時は既存の「今週の実績サマリ（自動生成）」セクションを置換
- **週次ノート自動作成**: 対象週のノートが存在しない場合、テンプレートから自動作成

## 出力例

```markdown
## 今週の実績サマリ（自動生成）

> 生成日: 2026-03-23 | 対象週: 2026-W12（03/16 〜 03/22）

### サマリ
ProjectAでメンバーシップ機能を完遂。ProjectBはUI刷新を実施...

**アクティブプロジェクト数**: 4/8 | **ソースコミット数**: 87 | **LLMセッション数**: 10

---

### [[ProjectA]]
**フェーズ**: [[フェーズ1]] — 成果物名 (進捗: 90%)

**ソースコード活動** (31コミット):
- feat(18): 機能追加の要約...
- fix(5): バグ修正の要約...

**LLMセッション**:
- [[20260316-プロジェクト方針策定|プロジェクト方針策定]]
```

## ライセンス

MIT
