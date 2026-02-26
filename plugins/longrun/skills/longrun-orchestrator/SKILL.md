---
name: longrun-orchestrator
description: 指示ファイルに基づいてロングラン自律実行を行うオーケストレーター。instruction.mdを解析し、計画策定→増分実装→検証→コミットのループを自律的に繰り返す。「ロングラン実行」「自律実装」「exec」で起動。
version: 1.0.0
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
---

# Longrun Execution Protocol

指示ファイルに基づいて、人間の介入なしに自律的に実装を完遂するプロトコル。

## Phase 0: セットアップ

1. 指示ファイル `$ARGUMENTS` を読み込む（デフォルト: `_longrun/instruction.md`）
2. プロジェクトのコードベースを調査（Exploreサブエージェントで実施）
   - ディレクトリ構造の把握
   - 技術スタックの確認
   - 既存のコーディングパターン・命名規則の把握
   - テストフレームワーク・設定の確認
3. `_longrun/` ディレクトリを作成（存在しない場合）
4. 実装計画を `_longrun/plan.md` に出力
5. 進捗ファイル `_longrun/progress.md` を初期化
6. 意思決定ログ `_longrun/decisions.md` を初期化
7. 初期コミットを作成: `chore: longrun execution start - [タスク概要]`

## Phase 1: 計画策定

1. 指示ファイルの要件を分解
2. 各機能の依存関係を整理
3. 実装順序を決定（依存関係の少ないものから）
4. `_longrun/plan.md` に記録:

```markdown
# Implementation Plan

## タスク一覧
- [ ] Task 1: [説明] (推定: S/M/L)
- [ ] Task 2: [説明] (推定: S/M/L)
  - 依存: Task 1
- [ ] Task 3: [説明] (推定: S/M/L)

## 依存関係図
Task 1 → Task 2 → Task 4
Task 3 → Task 4

## 実装順序
1. Task 1 (前提なし)
2. Task 3 (前提なし、並行可能)
3. Task 2 (Task 1完了後)
4. Task 4 (Task 2, 3完了後)
```

## Phase 2: 増分実装ループ

以下を各タスクごとに繰り返す:

### 2a. 実装前チェック
- 現在のテストが全てパスすることを確認
- 前回の変更が正常であることを確認
- `_longrun/progress.md` を更新（現在のタスクを記録）

### 2b. 意思決定が必要な場合
設計上の分岐点に遭遇したら:
1. 直前の状態でGitコミット（ロールバックポイント）
   - メッセージ: `checkpoint: before decision #N - [概要]`
2. Decision Agent（Task tool で `decision-agent` サブエージェント）に委譲
   - 指示ファイルのガイドライン、過去の決定、コード状況を渡す
3. 決定内容を `_longrun/decisions.md` に記録
4. 決定に基づいて実装を継続

### 2c. 実装
- 1タスクずつ実装
- 既存のコーディングパターンに合わせる
- 自己検証: テスト実行、lint、型チェック
- 問題があれば自分で修正（3回まで。超えたらスキップしてログに記録）

### 2d. 実装後検証
- Test Agent（Task tool で `test-agent` サブエージェント）にテスト作成を委譲
- テストが作成されたら実行して確認
- Verification Agent（Task tool で `verification-agent` サブエージェント）に動作確認を委譲（動作確認方法が指示ファイルにある場合）
- NGの場合は修正して再検証（最大3回）

### 2e. コミット
- タスク完了ごとにコミット
  - メッセージ: `feat/fix/refactor(scope): [説明]`
  - 意思決定があった場合: `feat(scope): [説明] (decision #N: approach X)`
- `_longrun/progress.md` を更新:

```markdown
# Progress

## 現在のステータス
- 現在のタスク: Task N / 全 M タスク
- 最終更新: [timestamp]
- ステータス: 実行中

## 完了タスク
- [x] Task 1: [説明] — commit: abc1234
- [x] Task 2: [説明] — commit: def5678

## 進行中
- [ ] Task 3: [説明] — 実装中...

## 未着手
- [ ] Task 4: [説明]

## 意思決定サマリー
- Decision #1: [タイトル] → [選択した案]
- Decision #2: [タイトル] → [選択した案]

## 問題・スキップ
- [問題があればここに記録]
```

## Phase 3: 仕上げ

1. 全体テスト実行
2. Verification Agentで最終動作確認
3. Spec Agentで仕様書の整合性チェック
4. `_longrun/verification-guide.md`（動作確認ガイド）を作成:

```markdown
# 動作確認ガイド

## 環境
- URL: [開発サーバーURL]
- 起動コマンド: [コマンド]

## 確認手順
1. [手順1]
2. [手順2]
3. [手順3]

## 受け入れ条件チェックリスト
- [ ] [条件1]: [確認方法]
- [ ] [条件2]: [確認方法]
```

5. `_longrun/summary.md`（完了サマリー）を作成:

```markdown
# Longrun Execution Summary

## 概要
- 開始: [timestamp]
- 完了: [timestamp]
- タスク数: N完了 / M合計
- コミット数: X
- 意思決定数: Y

## 実装内容
[主要な実装内容の要約]

## 意思決定サマリー
[各決定の簡潔な要約]

## 残課題
[完了しなかった項目があれば]
```

6. 最終コミット: `docs: longrun complete - verification guide added`

## Git コミット戦略

```
意思決定の分岐点の前: 必ずコミット（ロールバックポイント）
  ↓
意思決定後: 決定内容をコミットメッセージに含む
  ↓
各タスク完了後: 機能単位でコミット
  ↓
最終: 全体完了のコミット
```

コミットプレフィクスの使い分け:
- `chore:` longrun start / 設定変更
- `checkpoint:` 意思決定前のセーブポイント
- `feat:` 新機能の実装
- `fix:` バグ修正
- `test:` テスト追加
- `refactor:` リファクタリング
- `docs:` ドキュメント・仕様書

## エラーハンドリング

- テスト失敗: 自分で修正を試みる（最大3回）。修正不能な場合はスキップしてログに記録
- ビルドエラー: 原因を調査して修正。型エラーやimportの問題は自分で対処
- 意思決定の膠着: シンプルな方を選択し、その旨を記録
- コンテキスト枯渇の防止: 各タスクの実装では、前のタスクの詳細ではなく `_longrun/progress.md` を参照して現在位置を把握する
