# Longrun - Claude Code ロングラン自律実行プラグイン

人間の介入なしに Claude Code が長時間自律的に実装を完遂するためのプラグイン。

## 概要

instruction.md（指示ファイル）を対話的に作成し、それに基づいて自律的にコードを実装します。
実装中は専門サブエージェント（意思決定・検証・テスト・仕様管理）が協調して品質を担保します。

## インストール

```bash
/plugin install longrun@oratta-claude-harness
```

## コマンド

| コマンド | 説明 |
|----------|------|
| `/instruction [brain-dump]` | instruction.mdを対話的に作成する |
| `/exec [instruction-path]` | instruction.mdに基づいてロングラン自律実行を開始する |
| `/status` | ロングラン実行の進捗状況を確認する |
| `/decisions [番号]` | 実行中に行われた意思決定の一覧を確認する |

## ワークフロー

### 1. 指示ファイルの作成（/instruction）

Brain Dump → Gap Analysis → Interview → Synthesis の4フェーズで instruction.md を作成します。

```
/instruction これこれの機能を実装したい。ユーザーがログインして...
```

または事前にファイルに書いた内容を渡すこともできます:

```
/instruction ./my-brain-dump.md
```

### 2. ロングラン実行（/exec）

instruction.md に基づいて自律的に実装を進めます:

```
/exec
```

実行中のフロー:
1. **セットアップ**: コードベース調査、実装計画策定
2. **増分実装ループ**: タスクごとに 実装 → テスト → 検証 → コミット
3. **仕上げ**: 全体テスト、動作確認ガイド作成

### 3. 進捗確認（/status）

別のClaude Codeセッションから進捗を確認:

```
/status
```

またはターミナルから直接:

```bash
cat _longrun/progress.md
```

### 4. 意思決定の確認（/decisions）

実装中に行われた設計上の意思決定を確認:

```
/decisions      # 一覧表示
/decisions 3    # Decision #3 の詳細
```

## アーキテクチャ

### サブエージェント

| エージェント | モデル | 役割 |
|-------------|--------|------|
| Decision Agent | Opus | 設計上の分岐点での意思決定 |
| Verification Agent | Opus | ブラウザ動作確認、ビジネス視点の品質チェック |
| Test Agent | Sonnet | テストの作成・実行・カバレッジ確認 |
| Spec Agent | Sonnet | 仕様書のメンテナンス、整合性チェック |

### 成果物ディレクトリ（_longrun/）

実行中・実行後に以下のファイルが生成されます:

```
_longrun/
├── instruction.md          # 入力: 指示ファイル
├── plan.md                 # 実装計画
├── progress.md             # 進捗ログ（随時更新）
├── decisions.md            # 意思決定の記録
├── verification-guide.md   # 動作確認ガイド（完了後）
├── summary.md              # 完了サマリー（完了後）
└── specs/                  # 仕様書（Spec Agentが管理）
```

### Git コミット戦略

- 意思決定前に必ずコミット（ロールバックポイント）
- 各タスク完了ごとにコミット
- `git log --oneline` で意思決定の流れが追える
- 任意の分岐点に `git checkout` で戻り、別の選択を試せる

## 設計ドキュメント

詳細な設計は以下を参照:
- [Claude Code ロングラン自律実行システム設計レポート](../../docs/longrun-design-report.md)

## ライセンス

MIT License
