---
name: longrun-orchestrator
description: 指示ファイルに基づいてロングラン自律実行を行うオーケストレーター。OpenSpec仕様駆動開発 + TDDを組み込み、ユーザー介入なしで品質を担保する。「ロングラン実行」「自律実装」「exec」で起動。
version: 2.1.0
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
---

# Longrun v2 Execution Protocol

指示ファイルに基づいて、人間の介入なしに自律的に実装を完遂するプロトコル。
**仕様駆動開発（OpenSpec）+ テスト駆動開発（TDD）**により、仕様を壊さず品質を担保する。

## アーキテクチャ概要

```
Phase 0: Setup
  ↓
Phase 1: Specification（OpenSpec駆動）
  1a: 仕様作成 → spec-agent
  1b: 仕様レビュー → spec-review-agent（最大3ラウンド）
  1c: UIデザイン → Pencil MCP（UI変更時のみ）
  ↓
Phase 2: Test Design（TDD Red Phase）
  → test-agent (red mode)
  ↓
Phase 3: Implementation Loop（TDD Green + Refactor）
  タスクごとに: 実装 → テスト → 検証 → コミット
  ↓
Phase 4: Finalization
  全体テスト → tasks.md最終同期 → サマリー
```

## Phase 0: セットアップ

1. ランディレクトリを特定する:
   - `$ARGUMENTS` がディレクトリパスの場合: そのディレクトリを使用（例: `_longrun/2026-03-11_habit-skip`）
   - `$ARGUMENTS` がファイルパスの場合: そのファイルの親ディレクトリを使用
   - 引数なしの場合: `_longrun/` 内の最新サブディレクトリ（`ls -1d _longrun/20*/ | sort | tail -1`）を使用
   - 以降、このディレクトリを `{run-dir}` として参照する
2. `{run-dir}/instruction.md` を読み込む
3. プロジェクトのコードベースを調査（Exploreサブエージェントで実施）
   - ディレクトリ構造の把握
   - 技術スタックの確認
   - 既存のコーディングパターン・命名規則の把握
   - テストフレームワーク・設定の確認
4. **OpenSpec初期化**: `openspec/` が存在しなければ `openspec init --tools claude` を実行
5. テストフレームワークの確認と既存テストの実行（ベースライン記録）
6. 進捗ファイル `{run-dir}/progress.md` を初期化
7. 意思決定ログ `{run-dir}/decisions.md` を初期化
8. 初期コミット: `chore: longrun v2 execution start - [タスク概要]`

## Phase 1: Specification（OpenSpec駆動）

### Phase 1a: 仕様作成

Spec Agent（Task tool で `spec-agent` サブエージェント、create モード）に委譲:

1. `openspec new change <change-name>` でスキャフォールド生成
2. instruction.md の要件から4つの公式アーティファクトを作成:
   - `openspec/changes/<name>/proposal.md` - Why / What Changes / Capabilities / Impact
   - `openspec/changes/<name>/specs/<capability>/spec.md` - Requirements + Scenarios（WHEN/THEN）
   - `openspec/changes/<name>/design.md` - Context / Goals・Non-Goals / Decisions / Risks
   - `openspec/changes/<name>/tasks.md` - 番号付きタスクグループ
3. `openspec validate` で構造検証
4. コミット: `docs: openspec change created - <change-name>`

### Phase 1b: 仕様レビュー

Spec Review Agent（Task tool で `spec-review-agent` サブエージェント）に委譲:

1. 4アーティファクト全体をレビュー
2. 結果が **APPROVE** → Phase 2 へ進む
3. 結果が **REQUEST_CHANGES** → Spec Agent (update モード) で修正 → 再レビュー
4. 最大3ラウンド。3回修正してもAPPROVEされない場合は、残課題を明記してAPPROVEとする

### Phase 1c: UIデザイン（UI変更がある場合のみ）

instruction.md または proposal.md にUI変更が含まれる場合:

1. Pencil MCP で `.pen` ファイルにモックアップ作成
   - `get_guidelines` → `get_style_guide` → `batch_design` → `get_screenshot` の流れ
2. design.md にモックアップの参照先を記載
3. コミット: `docs: UI mockup created for <change-name>`

## Phase 2: Test Design（TDD Red Phase）

Test Agent（Task tool で `test-agent` サブエージェント、red モード）に委譲:

1. specs/ の Requirements/Scenarios からテストケースを生成
2. 各 Scenario の WHEN/THEN をテストコードに変換
3. テスト実行 → **全件FAIL** を確認（Red状態の証明）
4. 既存テストが全PASS（リグレッションなし）を確認
5. コミット: `test: TDD red phase - failing tests for <change-name>`

`{run-dir}/progress.md` を更新（Phase 2 完了を記録）

## Phase 3: Implementation Loop（TDD Green + Refactor）

tasks.md の各タスクに対して以下を繰り返す:

### 3a. 実装前チェック
- 現在のテストの状態を確認（何件PASS/FAIL）
- `{run-dir}/progress.md` を更新（現在のタスクを記録）

### 3b. 意思決定が必要な場合
設計上の分岐点に遭遇したら:
1. 直前の状態でGitコミット（ロールバックポイント）
   - メッセージ: `checkpoint: before decision #N - [概要]`
2. Decision Agent（Task tool で `decision-agent` サブエージェント）に委譲
   - 指示ファイル、design.md、過去の決定、コード状況を渡す
3. 決定内容を `{run-dir}/decisions.md` と design.md の Decisions セクションに記録
4. 決定に基づいて実装を継続

### 3c. 実装（TDD Green Phase）
- Test Agent（green モード）で1タスクずつ実装
- テストをPASSさせる**最小限のコード**を書く
- テスト実行 → 対象テストPASS + 既存テスト全PASSを確認
- 問題があれば自分で修正（3回まで。超えたらスキップしてログに記録）

### 3d. リファクタリング（TDD Refactor Phase）
- Test Agent（refactor モード）でコード品質を改善
- テスト全件PASSを維持しながらリファクタリング

### 3e. UI変更の反映
UI変更を含むタスクの場合:
- Pencil MCP でデザインファイル（.pen）を更新
- 実装がモックアップと一致することを確認

### 3f. 検証
- Verification Agent（Task tool で `verification-agent` サブエージェント）に動作確認を委譲
  - ブラウザテスト（Playwright CLI）
  - UI変更がある場合はPencil MCPのget_screenshotで比較
- NGの場合は修正して再検証（最大3回）

### 3g. コミット & OpenSpec tasks.md 更新
- タスク完了ごとにコミット
  - メッセージ: `feat/fix/refactor(scope): [説明]`
  - 意思決定があった場合: `feat(scope): [説明] (decision #N: approach X)`
- **OpenSpec tasks.md のチェックボックス更新**:
  1. `openspec/changes/<change-name>/tasks.md` を読み込む
  2. 完了したタスクに対応する行の `- [ ]` を `- [x]` に変更する（Edit toolを使用）
  3. タスクの特定は、タスク番号・タスク説明文のどちらかで照合する
  4. 該当タスクが見つからない場合はスキップしてログに記録
- `{run-dir}/progress.md` を更新

## Phase 4: Finalization

1. **全体テスト実行**
   - テストスイート全体を実行、全PASSを確認
   - lint / 型チェック
   - ビルドが成功すること

2. **最終検証**
   - Verification Agent で最終動作確認
   - UI変更がある場合はPencil MCPで最終確認

3. **OpenSpec tasks.md 最終同期**
   `openspec/changes/<change-name>/tasks.md` を読み込み、全タスクの完了状態を最終確認する:
   - 実装済みタスク: `- [ ]` → `- [x]` に更新（Phase 3gで漏れがあった場合のキャッチアップ）
   - スキップしたタスク: `- [ ]` のまま残し、理由をコメントで追記（例: `- [ ] タスク名 <!-- skipped: [理由] -->`）
   - 部分完了のタスク: チェックは入れず、状態をコメントで追記
   - **目的**: ユーザーがOpenSpecドキュメントを見て、何が完了し何が未完了かを正確に把握できるようにする
   - コミット: `docs: update OpenSpec tasks.md completion status`

4. **成果物作成**
   `{run-dir}/verification-guide.md`（動作確認ガイド）を作成:
   ```markdown
   # 動作確認ガイド

   ## 環境
   - URL: [開発サーバーURL]
   - 起動コマンド: [コマンド]

   ## 確認手順
   1. [手順1] → [期待結果]
   2. [手順2] → [期待結果]

   ## 受け入れ条件チェックリスト
   - [ ] [条件1]: [確認方法]
   - [ ] [条件2]: [確認方法]
   ```

   `{run-dir}/summary.md`（完了サマリー）を作成:
   ```markdown
   # Longrun v2 Execution Summary

   ## 概要
   - 開始: [timestamp]
   - 完了: [timestamp]
   - タスク数: N完了 / M合計
   - コミット数: X
   - 意思決定数: Y

   ## OpenSpec Change
   - Change名: <change-name>
   - tasks.md更新: 済（N/M タスクにチェック）
   - アーカイブ: 未実施（ユーザーが `/opsx:archive` で実施）

   ## テスト結果
   - テストケース: N件（全PASS）

   ## 実装内容
   [主要な実装内容の要約]

   ## 残課題
   [完了しなかった項目があれば]
   ```

5. `{run-dir}/progress.md` を最終更新
6. 最終コミット: `docs: longrun v2 complete - <change-name>`
7. **ランディレクトリのアーカイブ**
   - `_longrun/_archive/` ディレクトリがなければ作成: `mkdir -p _longrun/_archive`
   - `{run-dir}` を `_longrun/_archive/` に移動: `mv {run-dir} _longrun/_archive/`
   - 例: `_longrun/2026-03-11_habit-skip` → `_longrun/_archive/2026-03-11_habit-skip`
   - コミット: `chore: archive longrun - <change-name>`

## Git コミット戦略

```
Phase 0: chore: longrun v2 execution start
Phase 1: docs: openspec change created / UI mockup created
Phase 2: test: TDD red phase - failing tests
Phase 3: checkpoint → feat/fix/refactor（タスクごと）
Phase 4: docs: longrun v2 complete → chore: archive longrun
```

コミットプレフィクスの使い分け:
- `chore:` longrun start / 設定変更
- `docs:` OpenSpec仕様書 / サマリー / 確認ガイド
- `test:` TDD Red Phase / テスト追加
- `checkpoint:` 意思決定前のセーブポイント
- `feat:` 新機能の実装
- `fix:` バグ修正
- `refactor:` リファクタリング

## エラーハンドリング

- **テスト失敗**: 自分で修正を試みる（最大3回）。修正不能な場合はスキップしてログに記録
- **ビルドエラー**: 原因を調査して修正。型エラーやimportの問題は自分で対処
- **意思決定の膠着**: シンプルな方を選択し、その旨を記録
- **spec-review-agentがAPPROVEしない**: 3ラウンドで打ち切り、残課題を明記して進行
- **コンテキスト枯渇の防止**: 各タスクの実装では、前のタスクの詳細ではなく `{run-dir}/progress.md` を参照して現在位置を把握する
- **OpenSpec CLIエラー**: `openspec validate` がFAILした場合は手動でディレクトリ構造を修正
