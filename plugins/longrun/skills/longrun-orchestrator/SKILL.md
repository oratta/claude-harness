---
name: longrun-orchestrator
description: 指示ファイルに基づいてロングラン自律実行を行うオーケストレーター v3.0。マルチchange分解 + OpenSpec applyへの実装委任 + カスタムスキーマによるTDD/スキル注入 + サブエージェント隔離で品質を担保する。「ロングラン実行」「自律実装」「exec」で起動。
version: 3.0.0
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
---

# Longrun v3 Execution Protocol

指示ファイルに基づいて、人間の介入なしに自律的に実装を完遂するプロトコル。
**OpenSpec applyへの実装委任 + カスタムスキーマによるTDD/スキル注入**により、仕様を壊さず品質を担保する。

## アーキテクチャ概要

```
Phase 0: Setup
  ↓
Phase 1: ドキュメント作成（changeごとにサブエージェント）
  → OpenSpec ff + spec-review-agent（最大3ラウンド）
  ↓
Phase 2: 実装（changeごとにworktree + openspec apply）
  → カスタムスキーマがTDD + スキル + decision-agentパターンを注入
  ↓
Phase 3: 統合
  → worktreeマージ + 統合テスト + verification-agent
  ↓
Phase 4: ハンドオフ
  → openspec list集約 + verification-guide + ユーザー承認 + archive
```

## 設計原則

1. **longrunはオーケストレーター**: 実装はOpenSpec applyに完全委任する
2. **タスク管理はOpenSpec一元管理**: tasks.mdのチェックボックスが唯一の進捗ソース
3. **changeごとにサブエージェント隔離**: コンテキスト汚染を防止
4. **カスタムスキーマでTDD/スキル注入**: OpenSpecの動的指示生成を活用
5. **AskUserQuestionは使わない**: Phase 4のハンドオフ時のみ使用

---

## Phase 0: セットアップ

1. ランディレクトリを特定する:
   - `$ARGUMENTS` がディレクトリパスの場合: そのディレクトリを使用
   - `$ARGUMENTS` がファイルパスの場合: そのファイルの親ディレクトリを使用
   - 引数なしの場合: `_longrun/` 内の最新サブディレクトリ（`ls -1d _longrun/20*/ | sort | tail -1`）を使用
   - 以降、このディレクトリを `{run-dir}` として参照する
2. `{run-dir}/instruction.md` を読み込む
3. **Changes分解セクション**を解析し、change一覧・スキルマッピング・依存関係を抽出
4. プロジェクトのコードベースを調査（Exploreサブエージェントで実施）
   - ディレクトリ構造の把握
   - 技術スタックの確認
   - 既存のコーディングパターン・命名規則の把握
   - テストフレームワーク・設定の確認
5. **OpenSpec初期化**:
   - `openspec/` が存在しなければ `openspec init --tools claude` を実行
   - カスタムスキーマ `longrun-tdd` が存在しなければセットアップ（後述）
   - **config.yamlをgit管理外にする**: `openspec/config.yaml` が `.gitignore` に含まれていなければ追加する
     ```bash
     echo 'openspec/config.yaml' >> .gitignore
     ```
     config.yamlは各change実行前に動的生成される使い捨てファイルであり、gitにコミットしない。
6. テストフレームワークの確認と既存テストの実行（ベースライン記録）
7. 進捗ファイル `{run-dir}/progress.md` を初期化（Phase進捗のみ記録）
8. 意思決定ログ `{run-dir}/decisions.md` を初期化
9. 初期コミット: `chore: longrun v3 execution start - [タスク概要]`

### カスタムスキーマのセットアップ

`openspec/schemas/longrun-tdd/` が存在しない場合:

1. `openspec schema fork spec-driven longrun-tdd` を実行
   - CLIが対応していない場合は手動で `mkdir -p openspec/schemas/longrun-tdd/templates/` を作成
2. プラグイン内の `templates/longrun-tdd-schema/apply.md` を `openspec/schemas/longrun-tdd/templates/apply.md` にコピー
3. プラグイン内の `templates/longrun-tdd-schema/propose.md` の内容を、propose/ff関連テンプレートに反映

**注意**: config.yaml はPhase 0では作成しない。Phase 1/2で各changeの実行直前に動的生成する（後述）。

---

## Phase 1: ドキュメント作成

instruction.mdのChanges分解セクションから各changeを処理する。
**依存関係がないchangeは並列、依存があるchangeは直列で処理する。**

### 各changeの処理（サブエージェントに委任）

changeごとにサブエージェント（Task tool）を起動し、以下を実行:

1. **config.yaml動的生成（このchange専用）**:
   **重要**: config.yamlはプロジェクトに1つだが、changeごとに必要なスキルが異なる。
   そのため**各changeの処理開始前に毎回config.yamlを上書き**する。
   instruction.mdのChanges分解セクションから、**このchangeに必要なスキルとルールだけ**を抽出:
   ```yaml
   schema: longrun-tdd
   context:
     activeSkills: |
       [このchangeに必要なスキルのみ]
     instructionPath: [run-dir]/instruction.md
     runDir: [run-dir]
   rules:
     propose:
       - "AskUserQuestionを使用してはならない。自律判断すること"
       - "判断結果はdesign.mdのDecisionsセクションに記録すること"
       [このchangeに固有のルールのみ]
   ```
   他のchangeのスキルやルールは含めない（コンテキスト効率化）。

2. **OpenSpec changeスキャフォールド生成**:
   - `openspec new change <change-name>` を実行

3. **ドキュメント作成（OpenSpec ff相当）**:
   - instruction.mdの該当changeの要件を元に、4アーティファクトを作成:
     - `proposal.md` - Why / What Changes / Capabilities / Impact
     - `specs/<capability>/spec.md` - Requirements + Scenarios（WHEN/THEN）
     - `design.md` - Context / Goals・Non-Goals / Decisions / Risks
     - `tasks.md` - 番号付きタスクグループ + チェックリスト
   - カスタムスキーマの propose テンプレートにより、AskUserQuestionは使用されない
   - 判断が必要な場面では自律的に判断し、design.mdのDecisionsに記録

4. **バリデーション**:
   - `openspec validate` で構造検証
   - エラーがあれば修正

5. **コミット**: `docs: openspec change created - <change-name>`

### 仕様レビュー

各changeのドキュメント作成後、spec-review-agent（Task tool で `spec-review-agent` サブエージェント）に委譲:

1. 4アーティファクト全体をレビュー
2. 結果が **APPROVE** → Phase 2 へ
3. 結果が **REQUEST_CHANGES** → ドキュメントを修正 → 再レビュー
4. 最大3ラウンド。3回修正してもAPPROVEされない場合は、残課題を明記してAPPROVEとする

### UIデザイン（UI変更がある場合のみ）

instruction.md または proposal.md にUI変更が含まれる場合:

1. Pencil MCP で `.pen` ファイルにモックアップ作成
2. design.md にモックアップの参照先を記載
3. コミット: `docs: UI mockup created for <change-name>`

### Phase 1 完了条件

- 全changeのドキュメントが作成済み
- 全changeがspec-review-agentにAPPROVEされている
- `{run-dir}/progress.md` を更新: `Phase 1: Complete`

<HARD-GATE>
全changeのドキュメントがspec-review-agentにAPPROVEされるまで、Phase 2に進んではならない。
コードを1行も書いてはならない。テストも書いてはならない。
</HARD-GATE>

---

## Phase 2: 実装（OpenSpec apply委任）

各changeをOpenSpec applyで実装する。
**依存関係がないchangeは並列（worktree）、依存があるchangeは直列で処理する。**

### 並列実行（独立change）

依存関係がないchangeを並列で実装する場合:

1. changeごとにGit Worktreeを作成:
   ```bash
   git worktree add _worktrees/<change-name> -b feature/<change-name>
   ```

2. 各worktreeでサブエージェント（Task tool）を起動し、OpenSpec applyを実行:
   - worktreeのディレクトリに移動
   - **config.yaml動的生成（このchange専用）**: instruction.mdから**このchangeに必要なスキルとルールだけ**を抽出してconfig.yamlを上書き:
     ```yaml
     schema: longrun-tdd
     context:
       activeSkills: |
         [このchangeに必要なスキルのみ]
       instructionPath: [run-dir]/instruction.md
       runDir: [run-dir]
     rules:
       apply:
         [このchangeに固有のルールのみ]
     ```
   - `openspec apply <change-name>` を実行（カスタムスキーマがTDDを強制）
   - apply内で:
     - 各タスクに対してテストを先に書く（RED）
     - 最小コードで実装（GREEN）
     - リファクタリング（REFACTOR）
     - テスト全PASS後にtasks.mdの `[ ]` → `[x]` 更新
     - 設計判断はdesign.mdのDecisionsセクションに記録

3. サブエージェントの戻り値を確認:
   - 全タスク完了 → 次のPhaseへ
   - BLOCKED → 原因を調査、必要に応じて修正して再実行

### 直列実行（依存change）

依存関係があるchangeは、依存先が完了してからメインブランチにマージし、その上で実装:

1. 依存先changeのworktreeをマージ
2. 依存changeのworktreeを作成（マージ後のメインブランチから分岐）
3. 以降は並列実行と同じフロー

### 進捗監視

- 各changeの進捗は `openspec list` で確認（tasks.mdのチェックボックスが唯一のソース）
- `{run-dir}/progress.md` にはPhaseレベルの進捗のみ記録
- 設計判断は `{run-dir}/decisions.md` に集約

### Phase 2 完了条件

- 全changeの全タスクが `[x]` になっている（`openspec list` で確認）
- 全changeのテストがPASS
- `{run-dir}/progress.md` を更新: `Phase 2: Complete`

---

## Phase 3: 統合

### 3a. Worktreeマージ

1. 各changeのworktreeをメインブランチにマージ:
   ```bash
   git checkout main  # or master
   git merge feature/<change-name-A>
   git merge feature/<change-name-B>
   ```
2. コンフリクトがあれば解決
3. worktreeを削除:
   ```bash
   git worktree remove _worktrees/<change-name>
   ```

### 3b. 統合テスト

1. 全テストスイート実行
2. lint / 型チェック
3. ビルドが成功すること
4. 問題があれば修正してコミット

### 3c. 統合検証

Verification Agent（Task tool で `verification-agent` サブエージェント）に委譲:

- instruction.mdの受け入れ条件が全て満たされているか
- 全changeの統合後にE2Eで動作するか
- ブラウザテスト（Playwright）
- UI検証（Pencil MCP、UI変更がある場合）

結果が FAIL の場合:
- 問題の原因を特定（特定changeか統合時の問題か）
- 修正して再検証（最大3回）

### Phase 3 完了条件

- 全worktreeがマージ済み
- 全テストPASS + ビルド成功
- verification-agentがPASS
- `{run-dir}/progress.md` を更新: `Phase 3: Complete`

---

## Phase 4: ハンドオフ

### 4a. 最終状態確認

1. `openspec list` で全changeの完了状態を確認
2. 各changeの `tasks.md` を確認:
   - 全タスク `[x]` → OK
   - スキップしたタスクがあれば `<!-- skipped: [理由] -->` コメントを確認

### 4b. 成果物作成

**`{run-dir}/verification-guide.md`**（動作確認ガイド）:
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

**`{run-dir}/summary.md`**（完了サマリー）:
```markdown
# Longrun v3 Execution Summary

## 概要
- 開始: [timestamp]
- 完了: [timestamp]
- Changes: [N]個
- 意思決定: [Y]件

## Changes
| Change | タスク | テスト | ステータス |
|--------|--------|--------|-----------|
| change-A | 5/5 | 12 PASS | Complete |
| change-B | 7/7 | 8 PASS | Complete |

## テスト結果
- 全テストケース: N件（全PASS）
- 統合テスト: PASS

## 意思決定サマリー
[主要な判断の一覧]

## 残課題
[完了しなかった項目があれば]
```

### 4c. ユーザー確認（承認ゲート）

AskUserQuestion でユーザーに確認:

```
ロングラン実行が完了しました。

## 完了状態
[openspec listの結果]

## 確認をお願いする項目
[verification-guide.mdの受け入れ条件チェックリスト]

確認が完了したら、以下のいずれかを指示してください:
- 「OK」→ アーカイブして完了
- 「修正: [内容]」→ 修正を実施
```

### 4d. アーカイブ（ユーザー承認後）

**OpenSpec change のアーカイブ:**
各changeに対して:
- delta spec がある場合: `openspec/changes/<name>/specs/` → `openspec/specs/<capability>/spec.md` にコピー
- `openspec/changes/<name>` → `openspec/changes/archive/YYYY-MM-DD-<name>` に移動

**ランディレクトリのアーカイブ:**
- `{run-dir}` → `_longrun/_archive/` に移動

**アーカイブコミット:**
- `chore: archive longrun and openspec - [全change名]`

---

## Git コミット戦略

```
Phase 0: chore: longrun v3 execution start - [概要]
Phase 1: docs: openspec change created - <change-name>（changeごと）
         docs: UI mockup created for <change-name>（UI変更時）
Phase 2: [openspec applyが自動でコミット]（タスクごと）
Phase 3: merge: integrate <change-name> into main
         fix: resolve merge conflicts
         chore: remove worktree <change-name>
Phase 4: docs: longrun v3 complete
         [ユーザー承認]
         chore: archive longrun and openspec
```

---

## エラーハンドリング

| シナリオ | 対処 |
|----------|------|
| OpenSpec applyがタスクを完了できない | 3回リトライ。それでも失敗ならスキップしてログ記録 |
| ビルドエラー | 原因を調査して修正。型エラーやimportの問題は自分で対処 |
| spec-review-agentがAPPROVEしない | 3ラウンドで打ち切り、残課題を明記して進行 |
| Worktreeマージでコンフリクト | コンフリクトを解決してコミット |
| verification-agentがFAIL | 問題を修正して再検証（最大3回） |
| サブエージェントがクラッシュ | progress.mdからPhase/change状態を確認して再開 |
| OpenSpec CLIエラー | 手動でディレクトリ構造を修正 |

---

## ディレクトリ構造

```
_longrun/
├── YYYY-MM-DD_slug/              # アクティブなランディレクトリ
│   ├── instruction.md            # 入力: ユーザー指示（Changes分解 + スキルマッピング含む）
│   ├── progress.md               # Phase進捗のみ記録
│   ├── decisions.md              # 全changeの設計判断を集約
│   ├── verification-guide.md     # Phase 4で作成
│   └── summary.md                # Phase 4で作成
└── _archive/                     # 完了済みラン

_worktrees/                       # Phase 2で作成、Phase 3で削除
├── <change-name-A>/
└── <change-name-B>/

openspec/
├── config.yaml                   # schema: longrun-tdd + 動的ルール
├── schemas/longrun-tdd/          # カスタムスキーマ
│   └── templates/
│       ├── apply.md              # TDD強制 + 自律判断 + スキル注入
│       └── propose.md            # 自律判断（AskUserQuestion禁止）
├── specs/                        # メイン仕様（永続）
└── changes/                      # 変更提案（一時的）
    ├── <change-name-A>/
    │   ├── proposal.md
    │   ├── specs/
    │   ├── design.md
    │   └── tasks.md              # チェックボックスが唯一の進捗ソース
    ├── <change-name-B>/
    └── archive/
```
