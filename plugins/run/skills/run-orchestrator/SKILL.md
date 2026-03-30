---
name: run-orchestrator
description: planファイルに基づいて自律実行を行うオーケストレーター v4.1。5フェーズ（Plan→Build→Verify→Feedback→Archive）をAgent分離で実行し、フェーズ間はファイルベースのコンテキストリセットで品質を担保する。Skillとしてメインセッションで実行されるため、Agent ツールでサブエージェント（run-reviewer, run-builder, run-verifier）を生成できる。
version: 4.1.0
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

# Run Orchestrator v4.1 — 自律実行プロトコル

planファイルに基づいて、人間の介入なしに自律的に実装を完遂するプロトコル。
**フェーズ間コンテキストリセット + 4軸定量評価 + Build Contract パターン**で品質を担保する。

## 重要: このSkillはメインセッションで実行される

このSkillはメインセッションでInline実行される。これにより Agent ツールでサブエージェント（run-reviewer, run-builder, run-verifier）を生成できる。

**サブエージェントはサブエージェントを生成できない（Claude Codeの仕様）。** だからこのorchestratorはAgent（サブエージェント）ではなくSkill（メインセッション）として定義されている。orchestratorが自分自身をサブエージェントとして実行していると認識した場合、即座にエラーを報告すること。

## アーキテクチャ概要

```
/run:exec → run-orchestrator (Skill, メインセッションでInline実行)
  ↓ Agent ツール呼び出し（メインセッションから = OK）
  ├── run-reviewer (Agent) ← Build Contract レビュー
  ├── run-builder (Agent)  ← changeごとにTDD実装
  └── run-verifier (Agent) ← 4軸定量評価 + ブラウザ確認
```

## 設計原則

1. **orchestratorは指揮者**: 実装はサブエージェントに完全委任する。orchestrator自身がコードを書いてはならない
2. **タスク管理はOpenSpec一元管理**: tasks.mdのチェックボックスが唯一の進捗ソース
3. **フェーズ間はコンテキストリセット**: 各フェーズを別Agentで実行し、checkpoint.mdでハンドオフ
4. **changeごとにAgent隔離**: コンテキスト汚染を防止
5. **AskUserQuestionはFeedbackフェーズのみ**: 自律実行中はユーザーに聞かない
6. **プロセス逸脱禁止**: 定義されたフェーズを自律判断でスキップしてはならない。ツールが使えない等の技術的問題が発生しても、フェーズ自体を省略するのではなく、代替手段で同等の品質保証を行う
7. **決定ログにはエビデンス必須**: decisions.mdに記録する全ての判断には「実行したコマンドとその出力」を含めること。コマンド未実行の推測による判断は禁止
8. **orchestratorはコードを書かない**: 実装は必ず run-builder Agent に委譲する。orchestratorが直接 Edit/Write でプロダクションコードを変更することは禁止

## コンテキストリセット戦略

各フェーズの完了時に checkpoint.md を更新し、次フェーズのAgentはそこから状態を復元する。
これにより各フェーズが新鮮なコンテキストで開始され、コンテキスト不安（Context Anxiety）を防止する。

**checkpoint.md の構造:**
```yaml
---
phase: Build
status: complete
last_updated: 2026-03-26T08:00:00
---

## 完了フェーズ
- [x] Build Contract: run-reviewer APPROVED
- [x] Build: 全change実装完了

## 次フェーズへの引き継ぎ
- 全テスト PASS（X件）
- 意思決定: Y件（decisions.md参照）
- 注意点: [特記事項]

## Changes状態
| Change | Tasks | Tests | Status |
|--------|-------|-------|--------|
| change-A | 5/5 | 12 PASS | Complete |
| change-B | 7/7 | 8 PASS | Complete |
```

---

## Planフェーズ（前提: 既に完了）

run-planner Skillによって plan.md が `_runs/YYYY-MM-DD_slug/` に作成済み。
orchestratorはこの plan.md を入力として受け取る。

---

## Setupフェーズ

1. ランディレクトリを特定する:
   - `$ARGUMENTS` がディレクトリパスの場合: そのディレクトリを使用
   - `$ARGUMENTS` がファイルパスの場合: そのファイルの親ディレクトリを使用
   - 引数なしの場合: `_runs/` 内の最新サブディレクトリ（`ls -1d _runs/20*/ | sort | tail -1`）を使用
   - 以降、このディレクトリを `{run-dir}` として参照する
2. `{run-dir}/plan.md` を読み込む
3. **Changes分解セクション**を解析し、change一覧・スキルマッピング・依存関係を抽出
4. プロジェクトのコードベースを調査（Exploreサブエージェントで実施）
5. **ツール検証（必須）**:

   <GATE>
   以下のコマンドを全て実行し、結果をcheckpoint.mdに記録すること。
   コマンドを実行せずに「インストールされていない」と判断してはならない。
   </GATE>

   ```bash
   # OpenSpec CLI検出（必須実行）
   which openspec 2>/dev/null || command -v openspec 2>/dev/null || echo "OPENSPEC_NOT_FOUND"
   openspec --version 2>/dev/null || echo "OPENSPEC_VERSION_UNKNOWN"

   # Git検証
   git --version
   git branch --show-current
   ```

   **結果をcheckpoint.mdに記録:**
   ```markdown
   ## ツール検証結果
   - openspec: [パス] (v[バージョン]) ← 実際のコマンド出力を転記
   - git: [バージョン] on [ブランチ]
   ```

   **OpenSpecが見つからない場合でも、フェーズをスキップしてはならない。** npm/volta/グローバルパスを順に確認:
   ```bash
   npx openspec --version 2>/dev/null
   ~/.volta/bin/openspec --version 2>/dev/null
   ```

6. **OpenSpec初期化**:
   - `openspec/` が存在しなければ `openspec init --tools claude` を実行
   - カスタムスキーマ `run-tdd` が存在しなければセットアップ
   - config.yamlを `.gitignore` に追加
7. テストフレームワークの確認と既存テストの実行（ベースライン記録）
8. checkpoint.md を初期化（フロントマター + フェーズ進捗 + ツール検証結果）
9. decisions.md を初期化
10. 初期コミット: `chore: run execution start - [タスク概要]`

### カスタムスキーマのセットアップ

`openspec/schemas/run-tdd/` が存在しない場合:

1. `openspec schema fork spec-driven run-tdd` を実行
2. プラグイン内の `templates/run-tdd-schema/apply.md` を `openspec/schemas/run-tdd/templates/apply.md` にコピー
3. プラグイン内の `templates/run-tdd-schema/propose.md` を反映

---

## Build Contractフェーズ（実装前レビュー）

<GATE>
このフェーズをスキップしてはならない。
「plan.mdは既にレビュー済み」「run-plannerでレビュー通過済み」は理由にならない。
run-plannerのレビューとBuild Contractは別の検査である。
必ず Agent ツールで run-reviewer を呼び出すこと。
</GATE>

**必須アクション — Agent ツール呼び出し:**
```
Agent ツールを呼び出す:
  subagent_type: "run-reviewer"
  prompt: "Build Contractレビュー: [plan.mdのフルパス] のChanges分解を評価してください。プロジェクトルートは [cwd] です。"
```

run-reviewer は plan.md の Changes 分解を見て、以下を評価:

1. 各changeの実装計画が現実的か
2. 技術的リスクが特定されているか
3. 依存関係の順序が正しいか
4. スコープが適切か（大きすぎるchangeの分割提案）

**結果:**
- APPROVE → Build フェーズへ
- REQUEST_CHANGES → 具体的な修正提案付き。orchestratorが plan.md を修正して再レビュー
- 最大2ラウンド。2回でAPPROVEされない場合は残課題を明記して進行

checkpoint.md 更新: `Build Contract: APPROVED by run-reviewer`

---

## Buildフェーズ（TDD実装）

<GATE>
orchestratorが直接コードを書いてはならない。
各changeは必ず Agent ツールで run-builder を起動して実装させること。
「簡単だから自分でやる」「1ファイルだけだから」は理由にならない。
</GATE>

各changeをrun-builder Agentに委譲して実装する。
**依存関係がないchangeは並列（worktree）、依存があるchangeは直列で処理する。**

### 並列実行（独立change）

1. changeごとにGit Worktreeを作成:
   ```bash
   git worktree add _worktrees/<change-name> -b feature/<change-name>
   ```

2. 各worktreeで **run-builder Agent** を起動:
   ```
   Agent ツールを呼び出す:
     subagent_type: "run-builder"
     prompt: "以下のchangeをTDD実装してください: [change名]。worktreeパス: [パス]。plan.md: [パス]。OpenSpec apply を使用すること。"
   ```
   - config.yaml動的生成（このchange専用）
   - `openspec apply <change-name>` を実行（カスタムスキーマがTDDを強制）
   - apply内で: テスト先行 → 最小実装 → リファクタ → tasks.md更新

3. 完了条件チェックリスト（Context Anxiety対策）:
   - [ ] 全タスクが `[x]` になっている
   - [ ] 全テストがPASS
   - [ ] lint / 型チェックが通る
   - [ ] ビルドが成功する
   **チェックリスト完了まで「完了」と報告してはならない**

### 直列実行（依存change）

依存先changeが完了 → メインブランチにマージ → その上で依存changeのworktreeを作成

### Worktreeマージ

全change完了後:
1. 各worktreeをメインブランチにマージ
2. コンフリクトがあれば解決
3. worktreeを削除
4. 全テストスイート実行 + lint + 型チェック + ビルド

checkpoint.md 更新: `Build: Complete` + 次フェーズ引き継ぎ情報

---

## Verifyフェーズ（2段階検証）

<GATE>
このフェーズをスキップしてはならない。
orchestratorが自分でテストやブラウザ確認をして「問題ありません」と判断してはならない。
必ず2つのAgentを順番に呼び出すこと。
</GATE>

### Step 1: 静的検証（run-verifier）

**必須アクション — Agent ツール呼び出し:**
```
Agent ツールを呼び出す:
  subagent_type: "run-verifier"
  prompt: "静的検証を実行してください。run-dir: [パス]。テスト・lint・型チェック・ビルドの品質検証と、コードレビューによる完成度評価を行ってください。"
```

| 軸 | ハードしきい値 |
|----|-------------|
| **品質** (テスト+lint+型チェック+ビルド) | 100% 必須 |
| **完成度** (エッジケース・エラーハンドリング) | 80% 以上 |

**run-verifier が FAIL → run-builder に修正依頼 → 再検証（最大3回）**
静的検証がPASSしてからStep 2に進む。

### Step 2: ブラウザ検証（run-browser-verifier）

**必須アクション — Agent ツール呼び出し:**
```
Agent ツールを呼び出す:
  subagent_type: "run-browser-verifier"
  prompt: "ブラウザ動作検証を実行してください。run-dir: [パス]。開発サーバーを起動し、spec ScenarioのWHEN/THENをブラウザ上で実際に操作して確認してください。Playwright MCPを優先し、使えない場合のみclaude-in-chromeにフォールバックしてください。verification-guide.mdも生成してください。"
```

| 軸 | ハードしきい値 |
|----|-------------|
| **機能性** (spec Scenario通過率) | 100% 必須 |
| **UX** (操作フロー) | 70% 以上 |

**run-browser-verifier が FAIL → run-builder に修正依頼 → 再検証（最大3回）**

### 4軸統合スコア

両Agentの結果を統合してcheckpoint.mdに記録:

```markdown
## Verify結果
| 軸 | スコア | しきい値 | 判定 | 検証Agent |
|----|-------|---------|------|----------|
| 品質 | 100% | 100% | ✅ | run-verifier |
| 完成度 | 85% | 80% | ✅ | run-verifier |
| 機能性 | 100% | 100% | ✅ | run-browser-verifier |
| UX | 80% | 70% | ✅ | run-browser-verifier |
```

checkpoint.md 更新: `Verify: PASS/FAIL` + 4軸スコア + 使用ツール（Playwright MCP / claude-in-chrome）

---

## Feedbackフェーズ（ユーザー確認）

### 成果物作成

**verification-guide.md**（動作確認ガイド）:
spec.mdのScenariosから自動生成。各changeのWHEN/THENをユーザー向けチェックリストに変換。

**summary.md**（完了サマリー）:
開始/完了時刻、Changes一覧、テスト結果、意思決定サマリー、4軸評価スコア。

### ユーザー確認（承認ゲート + フィードバックループ）

AskUserQuestion でユーザーに確認:

```
自律実行が完了しました。

## 評価スコア（by run-verifier）
| 軸 | スコア | しきい値 |
|----|-------|---------|
| 機能性 | 100% | 100% ✅ |
| 品質 | 100% | 100% ✅ |
| 完成度 | 85% | 80% ✅ |
| UX | 78% | 70% ✅ |

## 確認をお願いする項目
[verification-guide.mdの受け入れ条件チェックリスト]

動作確認して、気づいたことがあれば何でも教えてください。
分類は不要です。思ったことをそのまま全部伝えてください。
問題なければ「OK」でアーカイブに進みます。
```

**ユーザーの応答に応じた処理:**

- **「OK」** → Archiveフェーズへ
- **それ以外（フィードバック）** → **run-feedback スキルに委譲**:
  - Tier 1/2 の修正が完了し、ユーザーが「OK」と応答するまでフィードバックループを継続
  - フィードバックループの上限: 最大3ラウンド

---

## Archiveフェーズ

### OpenSpec changeのアーカイブ
各changeに対して:
- delta specがある場合: specs/ をメインspecsにコピー
- `openspec/changes/<name>` → `openspec/changes/archive/YYYY-MM-DD-<name>` に移動

### ランディレクトリのアーカイブ
- `{run-dir}` → `_runs/_archive/` に移動

### Worktreeのクリーンアップ
- 残存worktreeがあれば削除

### アーカイブコミット
- `chore: archive run and openspec - [全change名]`

---

## オプションフェーズ（plan.mdで有効化）

plan.md のフロントマターで有効化できるオプションフェーズ:

```yaml
---
options:
  deploy: true      # Deployフェーズを有効化
  integrate: true   # Integrationフェーズを有効化（マルチリポジトリ）
  document: true    # Documentationフェーズを有効化
---
```

### Integration（マルチリポジトリ）
- 複数リポジトリ間の変更マージ
- 共有依存関係の更新
- クロスリポジトリテスト

### Deployment
- ビルド成果物の作成
- 環境へのデプロイ
- スモークテスト

### Documentation
- チェンジログ生成
- アーキテクチャドキュメント更新
- 意思決定記録へのリンク

---

## Git コミット戦略

```
Setup:         chore: run execution start - [概要]
Build Contract: (レビュー結果のみ、コミットなし)
Build:         [run-builder がコミット]（タスクごと）
               merge: integrate <change-name> into main
Verify:        (検証結果のみ、コミットなし)
Feedback:      style: [Tier 1修正] / fix: [Tier 2修正]
Archive:       chore: archive run and openspec - [change名]
```

---

## エラーハンドリング

| シナリオ | 対処 |
|----------|------|
| OpenSpec CLIが見つからない | `which`, `command -v`, `npx`, `~/.volta/bin/` を全て試す。全て失敗したら `npm install -g openspec` を試みる。それでも失敗ならcheckpoint.mdに記録してユーザーに報告。**フェーズをスキップしてはならない** |
| OpenSpec applyがタスクを完了できない | 3回リトライ。それでも失敗ならスキップしてログ記録 |
| ビルドエラー | run-builder に修正を依頼 |
| run-reviewer がAPPROVEしない | 2ラウンドで打ち切り、残課題を明記して進行 |
| Worktreeマージでコンフリクト | コンフリクトを解決してコミット |
| run-verifier がFAIL | run-builderに修正依頼 → 再検証（最大3回） |
| サブエージェントがクラッシュ | checkpoint.mdからフェーズ/change状態を確認して再開 |
| OpenSpec CLIエラー | 手動でディレクトリ構造を修正 |
| **ツールの問題でフェーズをスキップしたくなった** | **禁止。代替手段を探すか、ユーザーに報告して判断を仰ぐ。自律判断でフェーズを省略してはならない** |

---

## ディレクトリ構造

```
_runs/
├── YYYY-MM-DD_slug/              # アクティブなランディレクトリ
│   ├── plan.md                   # 入力: ユーザー計画（Changes分解 + スキルマッピング含む）
│   ├── checkpoint.md             # フェーズ進捗 + ハンドオフ情報
│   ├── decisions.md              # 全changeの設計判断を集約
│   ├── verification-guide.md     # Verifyフェーズで作成
│   └── summary.md                # Feedbackフェーズで作成
└── _archive/                     # 完了済みラン

_worktrees/                       # Buildフェーズで作成、マージ後に削除
├── <change-name-A>/
└── <change-name-B>/

openspec/
├── config.yaml                   # schema: run-tdd + 動的ルール
├── schemas/run-tdd/              # カスタムスキーマ
│   └── templates/
│       ├── apply.md              # TDD強制 + 自律判断 + スキル注入
│       └── propose.md            # 自律判断（AskUserQuestion禁止）
├── specs/                        # メイン仕様（永続）
└── changes/                      # 変更提案（一時的）
```
