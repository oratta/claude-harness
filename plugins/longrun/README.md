# Longrun v2 - Claude Code ロングラン自律実行プラグイン

人間の介入なしに Claude Code が長時間自律的に実装を完遂するためのプラグイン。
**OpenSpec仕様駆動開発 + TDD（テスト駆動開発）+ Pencil MCP** により品質を担保。

## 概要

instruction.md（指示ファイル）を対話的に作成し、それに基づいて自律的にコードを実装します。
v2 では以下の品質保証メカニズムが組み込まれています:

1. **仕様駆動開発**: OpenSpec公式CLI（v1.2.0）で仕様を管理。後から変更内容を確認可能
2. **自動仕様レビュー**: Spec Review Agent が人間の代わりに仕様を検証
3. **テスト駆動開発**: Red-Green-Refactorサイクルで実装。仕様を壊さない
4. **UIデザイン統合**: Pencil MCP でモックアップ作成・検証

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

### 2. ロングラン実行（/exec）

instruction.md に基づいて自律的に実装を進めます:

```
/exec
```

実行中のフロー:

```
Phase 0: Setup
  ├── コードベース調査
  ├── OpenSpec初期化（openspec init）
  └── テストベースライン確認
  ↓
Phase 1: Specification（OpenSpec駆動）
  ├── 1a: 仕様作成（spec-agent → 4アーティファクト）
  ├── 1b: 仕様レビュー（spec-review-agent → APPROVE/REQUEST_CHANGES）
  └── 1c: UIデザイン（Pencil MCP、UI変更時のみ）
  ↓
Phase 2: Test Design（TDD Red Phase）
  └── specs/のScenarios → 失敗テスト作成 → 全件FAIL確認
  ↓
Phase 3: Implementation Loop（TDD Green + Refactor）
  └── タスクごとに: 実装(Green) → リファクタ → 検証 → コミット
  ↓
Phase 4: Finalization
  ├── 全体テスト・ビルド確認
  ├── OpenSpecアーカイブ
  └── 動作確認ガイド・サマリー作成
```

### 3. 進捗確認（/status）

別のClaude Codeセッションから進捗を確認:

```
/status
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
| Spec Agent | Sonnet | OpenSpec公式CLIと連携した仕様作成（proposal/specs/design/tasks） |
| Spec Review Agent | Opus | 仕様の品質・完全性・整合性レビュー（人間レビュアー代替） |
| Decision Agent | Opus | 設計上の分岐点での意思決定 |
| Test Agent | Sonnet | TDD Red/Green/Refactor でのテスト管理 |
| Verification Agent | Opus | ブラウザ動作確認、Pencil MCP UI検証 |

### 成果物ディレクトリ

```
_longrun/                           # 実行管理
├── instruction.md                  # 入力: 指示ファイル
├── progress.md                     # 進捗ログ（随時更新）
├── decisions.md                    # 意思決定の記録
├── verification-guide.md           # 動作確認ガイド（完了後）
└── summary.md                      # 完了サマリー（完了後）

openspec/                           # 仕様管理（OpenSpec公式構造）
├── AGENTS.md                       # プロジェクトコンテキスト
├── specs/                          # メイン仕様（永続的）
│   └── <capability>/spec.md
└── changes/                        # 変更提案
    ├── <change-name>/
    │   ├── proposal.md             # Why / What / Capabilities / Impact
    │   ├── specs/<cap>/spec.md     # Delta specs（ADDED/MODIFIED/REMOVED）
    │   ├── design.md               # Goals / Decisions / Risks
    │   └── tasks.md                # タスクチェックリスト
    └── archive/                    # アーカイブ済み
```

### Git コミット戦略

- Phase 0: `chore: longrun v2 execution start`
- Phase 1: `docs: openspec change created`
- Phase 2: `test: TDD red phase - failing tests`
- Phase 3: `checkpoint:` → `feat/fix/refactor:` （タスクごと）
- Phase 4: `docs: longrun v2 complete`

## 前提条件

- OpenSpec CLI v1.2.0+（`npm install -g @fission-ai/openspec`）
- テストフレームワーク（Vitest, Jest, Playwright 等）がプロジェクトに設定済み
- UI変更がある場合: Pencil MCP が利用可能であること

## ライセンス

MIT License
