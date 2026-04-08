---
name: longrun-orchestrator
description: planファイルに基づいて自律実行を行うオーケストレーター v4.1。5フェーズ（Plan→Build→Verify→Feedback→Archive）をAgent分離で実行し、フェーズ間はファイルベースのコンテキストリセットで品質を担保する。Skillとしてメインセッションで実行されるため、Agent ツールでサブエージェント（longrun-reviewer, longrun-builder, longrun-verifier）を生成できる。
version: 4.2.0
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

# Run Orchestrator v4.1 — 自律実行プロトコル

planファイルに基づいて、人間の介入なしに自律的に実装を完遂するプロトコル。
**フェーズ間コンテキストリセット + 4軸定量評価 + Build Contract パターン**で品質を担保する。

## 重要: このSkillはメインセッションで実行される

このSkillはメインセッションでInline実行される。これにより Agent ツールでサブエージェント（longrun-reviewer, longrun-builder, longrun-verifier）を生成できる。

**サブエージェントはサブエージェントを生成できない（Claude Codeの仕様）。** だからこのorchestratorはAgent（サブエージェント）ではなくSkill（メインセッション）として定義されている。orchestratorが自分自身をサブエージェントとして実行していると認識した場合、即座にエラーを報告すること。

## アーキテクチャ概要

```
/longrun:exec → longrun-orchestrator (Skill, メインセッションでInline実行)
  ↓ Agent ツール呼び出し（メインセッションから = OK）
  ├── longrun-reviewer (Agent) ← Build Contract レビュー
  ├── longrun-builder (Agent)  ← changeごとにTDD実装
  └── longrun-verifier (Agent) ← 4軸定量評価 + ブラウザ確認
```

## 設計原則

1. **orchestratorは指揮者**: 実装はサブエージェントに完全委任する。orchestrator自身がコードを書いてはならない
2. **タスク管理はOpenSpec一元管理**: tasks.mdのチェックボックスが唯一の進捗ソース
3. **フェーズ間はコンテキストリセット**: 各フェーズを別Agentで実行し、checkpoint.mdでハンドオフ
4. **changeごとにAgent隔離**: コンテキスト汚染を防止
5. **AskUserQuestionはFeedbackフェーズのみ**: 自律実行中はユーザーに聞かない
6. **プロセス逸脱禁止**: 定義されたフェーズを自律判断でスキップしてはならない。ツールが使えない等の技術的問題が発生しても、フェーズ自体を省略するのではなく、代替手段で同等の品質保証を行う
7. **決定ログにはエビデンス必須**: decisions.mdに記録する全ての判断には「実行したコマンドとその出力」を含めること。コマンド未実行の推測による判断は禁止
8. **orchestratorはコードを書かない**: 実装は必ず longrun-builder Agent に委譲する。orchestratorが直接 Edit/Write でプロダクションコードを変更することは禁止
9. **フェーズ前宣言（自己拘束）**: 各フェーズ開始前に「これから何をやるか」「どのAgentを呼ぶか」を必ず出力する。自分で出力した宣言はコンテキスト内で拘束として機能し、フェーズスキップやAgent呼び出し省略を防ぐ

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
- [x] Build Contract: longrun-reviewer APPROVED
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

longrun-planner Skillによって plan.md が `_longruns/YYYY-MM-DD_slug/` に作成済み。
orchestratorはこの plan.md を入力として受け取る。

---

## Setupフェーズ

1. ランディレクトリを特定する:
   - `$ARGUMENTS` がディレクトリパスの場合: そのディレクトリを使用
   - `$ARGUMENTS` がファイルパスの場合: そのファイルの親ディレクトリを使用
   - 引数なしの場合: `_longruns/` 内の最新サブディレクトリ（`ls -1d _longruns/20*/ | sort | tail -1`）を使用
   - 以降、このディレクトリを `{longrun-dir}` として参照する
2. `{longrun-dir}/plan.md` を読み込む
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
   - カスタムスキーマ `longrun-tdd` が存在しなければセットアップ
   - config.yamlを `.gitignore` に追加
7. テストフレームワークの確認と既存テストの実行（ベースライン記録）
8. checkpoint.md を初期化（フロントマター + フェーズ進捗 + ツール検証結果）
9. decisions.md を初期化
10. 初期コミット: `chore: longrun execution start - [タスク概要]`

### カスタムスキーマのセットアップ

`openspec/schemas/longrun-tdd/` が存在しない場合:

1. `openspec schema fork spec-driven longrun-tdd` を実行
2. プラグイン内の `templates/longrun-tdd-schema/apply.md` を `openspec/schemas/longrun-tdd/templates/apply.md` にコピー
3. プラグイン内の `templates/longrun-tdd-schema/propose.md` を反映

---

## フェーズ前宣言（Setup完了後、必須出力）

<GATE>
Setupフェーズ完了後、Build Contractフェーズに入る前に、以下の宣言を必ず出力すること。
この宣言を出力せずにBuild Contractに進むことは禁止。
</GATE>

Setupが完了したら、以下を出力する:

```
Setupフェーズ完了。これから以下のフェーズを順に実行します:

1. **Build Contract** — longrun-reviewer Agent を呼び出してChanges分解をレビュー
2. **Build** — 各changeごとに longrun-builder Agent を呼び出してTDD実装
3. **Verify** — longrun-verifier Agent + longrun-browser-verifier Agent を呼び出して4軸定量評価
4. **Feedback** — ユーザーに動作確認を依頼し、フィードバックを処理
5. **Archive** — OpenSpec changeとランディレクトリをアーカイブ

Build Contractフェーズから開始します。
```

**なぜこの宣言が必要か:** orchestratorがSetup完了後に「Build Contractは既にplannerでレビュー済み」「Verifyは自分でテスト通したから不要」と合理化してフェーズをスキップすることを防ぐ。宣言した内容は自己拘束として機能し、各Agentの呼び出しを省略しにくくなる。

---

## Build Contractフェーズ（実装前レビュー）

<GATE>
このフェーズをスキップしてはならない。
「plan.mdは既にレビュー済み」「longrun-plannerでレビュー通過済み」は理由にならない。
longrun-plannerのレビューとBuild Contractは別の検査である。
必ず Agent ツールで longrun-reviewer を呼び出すこと。
</GATE>

**必須アクション — Agent ツール呼び出し:**
```
Agent ツールを呼び出す:
  subagent_type: "longrun-reviewer"
  prompt: "Build Contractレビュー: [plan.mdのフルパス] のChanges分解を評価してください。プロジェクトルートは [cwd] です。"
```

longrun-reviewer は plan.md の Changes 分解を見て、以下を評価:

1. 各changeの実装計画が現実的か
2. 技術的リスクが特定されているか
3. 依存関係の順序が正しいか
4. スコープが適切か（大きすぎるchangeの分割提案）

**結果:**
- APPROVE → Build フェーズへ
- REQUEST_CHANGES → 具体的な修正提案付き。orchestratorが plan.md を修正して再レビュー
- 最大2ラウンド。2回でAPPROVEされない場合は残課題を明記して進行

checkpoint.md 更新: `Build Contract: APPROVED by longrun-reviewer`

---

## Buildフェーズ

<GATE>
orchestratorが直接コードを書いてはならない。
各changeは必ず Agent ツールで longrun-builder を起動して実装させること。
「簡単だから自分でやる」「1ファイルだけだから」は理由にならない。
</GATE>

### Build前半: OpenSpec change作成 + verification-guide.md生成

#### 1. 各changeのOpenSpecドキュメント作成

changeごとにサブエージェントでOpenSpecドキュメントを作成:
- `openspec new change <change-name>`
- proposal.md / specs/spec.md / design.md / tasks.md を生成
- `openspec validate` で構造検証
- longrun-reviewer Agent で仕様レビュー（Spec Reviewモード）

#### 2. verification-guide.md 生成（spec.md Scenariosから）

<GATE>
全changeのspec.md作成・レビュー完了後、TDD実装開始前に、
verification-guide.md を `{longrun-dir}/` に生成すること。
このファイルがBuild後半〜Feedback までの全フェーズの進捗基盤となる。
</GATE>

各changeの `openspec/changes/<name>/specs/<capability>/spec.md` からScenario（WHEN/THEN）を抽出し、以下のフォーマットで生成:

```markdown
# Verification Guide

## 環境
- URL: [plan.mdの動作確認方法から]
- 起動: [コマンド]
- テスト: [テスト実行コマンド]

## change-A: [change名]

### S1: [Scenario名]
- WHEN: [ユーザー操作]
- THEN: [期待結果]
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [Scenario名]
- WHEN: [ユーザー操作]
- THEN: [期待結果]
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-B: [change名]
...
```

**権威ソースはspec.md。verification-guide.mdはspec.mdの派生ビュー + 進捗トラッカー。**

### Build後半: TDD実装

各changeをlongrun-builder Agentに委譲して実装する。
**依存関係がないchangeは並列（worktree）、依存があるchangeは直列で処理する。**

#### 並列実行（独立change）

<GATE>
Worktreeの作成は**必ず順次実行**すること。並列でworktreeを作成すると `.git/config.lock` の競合が発生する。
worktree作成完了後のlongrun-builder Agent起動は並列でOK。
</GATE>

1. changeごとにGit Worktreeを**順次**作成:
   ```bash
   # 1つずつ順番に作成する。並列実行禁止（.git/config.lock競合を回避）
   git worktree add _worktrees/<change-name-A> -b feature/<change-name-A>
   git worktree add _worktrees/<change-name-B> -b feature/<change-name-B>
   # ...
   ```

2. 全worktree作成完了後、各worktreeで **longrun-builder Agent** を並列起動:
   ```
   Agent ツールを呼び出す:
     subagent_type: "longrun-builder"
     prompt: "以下のchangeをTDD実装してください: [change名]。worktreeパス: [パス]。plan.md: [パス]。verification-guide.md: [パス]。OpenSpec apply を使用すること。テスト実装完了・ロジック実装完了のタイミングでverification-guide.mdの該当Scenarioに[x]を入れること。**実装完了後、必ずworktreeブランチにコミットすること（git add -A && git commit）。未コミットの変更はworktree削除時に消失する。コミットハッシュを報告に含めること。**"
   ```
   - config.yaml動的生成（このchange専用）
   - `openspec apply <change-name>` を実行（カスタムスキーマがTDDを強制）
   - apply内で: テスト先行 → 最小実装 → リファクタ → tasks.md更新
   - **テスト実装時**: verification-guide.mdの該当Scenarioの `[ ] テスト実装完了` → `[x]`
   - **ロジック実装時**: verification-guide.mdの該当Scenarioの `[ ] ロジック実装完了` → `[x]`

3. 完了条件チェックリスト（Context Anxiety対策）:
   - [ ] 全タスクが `[x]` になっている
   - [ ] 全テストがPASS
   - [ ] lint / 型チェックが通る
   - [ ] ビルドが成功する
   - [ ] verification-guide.mdの全Scenarioで「テスト実装完了」「ロジック実装完了」が `[x]`
   **チェックリスト完了まで「完了」と報告してはならない**

#### 直列実行（依存change）

依存先changeが完了 → メインブランチにマージ → その上で依存changeのworktreeを作成

#### Worktreeマージ

<GATE>
**ファイルコピー（cp）によるマージは禁止。** 必ず `git merge` を使うこと。
cpは漏れ検出が困難で、エイリアス（cp -i）によるサイレント失敗のリスクがある。
git mergeならコンフリクト検出・差分検証が自動化される。

**マージ完了を検証するまでworktreeを削除してはならない。**
未コミットの変更はworktree削除で完全に消失し、復旧不可能になる。
</GATE>

全change完了後、以下の手順で**順次**マージ:

1. **コミット確認**: 各worktreeブランチにコミットがあることを確認
   ```bash
   # 各worktreeでコミット状態を確認
   git -C _worktrees/<change-name> log --oneline -3
   git -C _worktrees/<change-name> status  # clean であること
   ```
   **未コミットの変更がある場合**: longrun-builderが完了条件を満たしていない。worktreeで追加コミットするか、longrun-builderを再起動する

2. **git mergeで統合**: メインブランチに各worktreeブランチを順次マージ
   ```bash
   git merge feature/<change-name-A> --no-ff -m "merge: integrate <change-name-A> into main"
   git merge feature/<change-name-B> --no-ff -m "merge: integrate <change-name-B> into main"
   ```
   コンフリクトがあれば解決してコミット

3. **マージ検証**: 全変更が正しく統合されたことを確認
   ```bash
   # 全テストスイート実行
   npm test  # or appropriate test command
   # lint + 型チェック + ビルド
   npm run lint && npm run typecheck && npm run build
   # マージされたファイル数を確認
   git diff --stat HEAD~<change数>..HEAD
   ```

4. **worktree削除**: マージ検証が**全てPASS**した後にのみ削除
   ```bash
   git worktree remove _worktrees/<change-name-A>
   git branch -d feature/<change-name-A>
   # 全worktreeに対して繰り返す
   ```

#### Build完了確認

orchestratorが verification-guide.md を確認:
```bash
grep -c "\[x\] テスト実装完了" {longrun-dir}/verification-guide.md
grep -c "\[x\] ロジック実装完了" {longrun-dir}/verification-guide.md
# 全Scenario数と一致すること
```

checkpoint.md 更新: `Build: Complete` + verification-guide.md進捗

---

## Verify前宣言（Build完了後、必須出力）

<GATE>
Buildフェーズ完了後、Verifyフェーズに入る前に、以下の宣言を必ず出力すること。
この宣言を出力せずにVerifyに進むことは禁止。
</GATE>

Buildが完了したら、以下を出力する:

```
Buildフェーズ完了。次に2段階のVerifyフェーズを実行します:

1. **静的検証** — longrun-verifier Agent を呼び出し、テスト・lint・型チェック・ビルド + コードレビュー
2. **ブラウザ検証** — longrun-browser-verifier Agent を呼び出し、verification-guide.mdの各Scenarioを実際に操作確認

静的検証から開始します。自分でテストを実行して「問題ない」と判断することは禁止です。
```

---

## Verifyフェーズ（2段階検証）

<GATE>
このフェーズをスキップしてはならない。
orchestratorが自分でテストやブラウザ確認をして「問題ありません」と判断してはならない。
必ず2つのAgentを順番に呼び出すこと。
</GATE>

### Step 1: 静的検証（longrun-verifier）

**必須アクション — Agent ツール呼び出し:**
```
Agent ツールを呼び出す:
  subagent_type: "longrun-verifier"
  prompt: "静的検証を実行してください。longrun-dir: [パス]。テスト・lint・型チェック・ビルドの品質検証と、コードレビューによる完成度評価を行ってください。"
```

| 軸 | ハードしきい値 |
|----|-------------|
| **品質** (テスト+lint+型チェック+ビルド) | 100% 必須 |
| **完成度** (エッジケース・エラーハンドリング) | 80% 以上 |

**longrun-verifier が FAIL → longrun-builder に修正依頼 → 再検証（最大3回）**
静的検証がPASSしてからStep 2に進む。

### Step 2: ブラウザ検証（longrun-browser-verifier）

**必須アクション — Agent ツール呼び出し:**
```
Agent ツールを呼び出す:
  subagent_type: "longrun-browser-verifier"
  prompt: "ブラウザ動作検証を実行してください。longrun-dir: [パス]。開発サーバーを起動し、verification-guide.mdの各Scenarioをブラウザ上で実際に操作して確認してください。PASSしたScenarioは verification-guide.md の '[ ] 動作確認完了' にチェックを入れてください。Playwright MCPを優先し、使えない場合のみclaude-in-chromeにフォールバックしてください。"
```

| 軸 | ハードしきい値 |
|----|-------------|
| **機能性** (spec Scenario通過率) | 100% 必須 |
| **UX** (操作フロー) | 70% 以上 |

**longrun-browser-verifier が FAIL → longrun-builder に修正依頼 → 再検証（最大3回）**

### 4軸統合スコア

両Agentの結果を統合してcheckpoint.mdに記録:

```markdown
## Verify結果
| 軸 | スコア | しきい値 | 判定 | 検証Agent |
|----|-------|---------|------|----------|
| 品質 | 100% | 100% | ✅ | longrun-verifier |
| 完成度 | 85% | 80% | ✅ | longrun-verifier |
| 機能性 | 100% | 100% | ✅ | longrun-browser-verifier |
| UX | 80% | 70% | ✅ | longrun-browser-verifier |
```

checkpoint.md 更新: `Verify: PASS/FAIL` + 4軸スコア + 使用ツール（Playwright MCP / claude-in-chrome）

---

## Feedbackフェーズ（ユーザー確認）

### 成果物作成

**summary.md**（完了サマリー）:
開始/完了時刻、Changes一覧、テスト結果、意思決定サマリー、4軸評価スコア。

**verification-guide.md** は Build前半で生成済み。この時点で以下の状態になっているはず:
- [x] テスト実装完了（全Scenario）
- [x] ロジック実装完了（全Scenario）
- [x] 動作確認完了（全Scenario）
- [ ] ユーザー確認完了 ← これだけ残っている

### ユーザー確認（承認ゲート + フィードバックループ）

AskUserQuestion でユーザーに verification-guide.md の内容を提示:

```
自律実行が完了しました。

## 評価スコア
| 軸 | スコア | しきい値 | 検証Agent |
|----|-------|---------|----------|
| 品質 | 100% | 100% ✅ | longrun-verifier |
| 完成度 | 85% | 80% ✅ | longrun-verifier |
| 機能性 | 100% | 100% ✅ | longrun-browser-verifier |
| UX | 80% | 70% ✅ | longrun-browser-verifier |

## verification-guide.md 進捗
[verification-guide.mdの全Scenarioリストを表示。
テスト実装/ロジック実装/動作確認は全て[x]。ユーザー確認のみ[ ]。]

動作確認して、気づいたことがあれば何でも教えてください。
分類は不要です。思ったことをそのまま全部伝えてください。
問題なければ「OK」でアーカイブに進みます。
```

**ユーザーが「OK」と応答した場合:**
- verification-guide.md の全Scenarioで `[ ] ユーザー確認完了` → `[x] ユーザー確認完了`
- Archiveフェーズへ

**ユーザーの応答に応じた処理:**

- **「OK」** → Archiveフェーズへ
- **それ以外（フィードバック）** → **longrun-feedback スキルに委譲**:
  - Tier 1/2 の修正が完了し、ユーザーが「OK」と応答するまでフィードバックループを継続
  - フィードバックループの上限: 最大3ラウンド

---

## Archiveフェーズ

### OpenSpec changeのアーカイブ
各changeに対して:
- delta specがある場合: specs/ をメインspecsにコピー
- `openspec/changes/<name>` → `openspec/changes/archive/YYYY-MM-DD-<name>` に移動

### ランディレクトリのアーカイブ
- `{longrun-dir}` → `_longruns/_archive/` に移動

### Worktreeのクリーンアップ
- 残存worktreeがあれば削除

### アーカイブコミット
- `chore: archive longrun and openspec - [全change名]`

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
Setup:         chore: longrun execution start - [概要]
Build Contract: (レビュー結果のみ、コミットなし)
Build:         [longrun-builder がコミット]（タスクごと）
               merge: integrate <change-name> into main
Verify:        (検証結果のみ、コミットなし)
Feedback:      style: [Tier 1修正] / fix: [Tier 2修正]
Archive:       chore: archive longrun and openspec - [change名]
```

---

## エラーハンドリング

| シナリオ | 対処 |
|----------|------|
| OpenSpec CLIが見つからない | `which`, `command -v`, `npx`, `~/.volta/bin/` を全て試す。全て失敗したら `npm install -g openspec` を試みる。それでも失敗ならcheckpoint.mdに記録してユーザーに報告。**フェーズをスキップしてはならない** |
| OpenSpec applyがタスクを完了できない | 3回リトライ。それでも失敗ならスキップしてログ記録 |
| ビルドエラー | longrun-builder に修正を依頼 |
| longrun-reviewer がAPPROVEしない | 2ラウンドで打ち切り、残課題を明記して進行 |
| Worktreeマージでコンフリクト | コンフリクトを解決してコミット |
| Worktreeに未コミットの変更がある | longrun-builderの完了条件未達。worktreeで `git add -A && git commit` するか、longrun-builderを再起動 |
| `.git/config.lock` 競合 | worktree作成を順次実行に切り替える。lockファイルが残っている場合は `rm .git/config.lock` 後にリトライ |
| worktreeブランチにコミットがない | **絶対にworktreeを削除しない**。longrun-builderが正常終了したか確認し、必要なら再実行 |
| longrun-verifier がFAIL | longrun-builderに修正依頼 → 再検証（最大3回） |
| サブエージェントがクラッシュ | checkpoint.mdからフェーズ/change状態を確認して再開 |
| OpenSpec CLIエラー | 手動でディレクトリ構造を修正 |
| **ツールの問題でフェーズをスキップしたくなった** | **禁止。代替手段を探すか、ユーザーに報告して判断を仰ぐ。自律判断でフェーズを省略してはならない** |

---

## ディレクトリ構造

```
_longruns/
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
├── config.yaml                   # schema: longrun-tdd + 動的ルール
├── schemas/longrun-tdd/              # カスタムスキーマ
│   └── templates/
│       ├── apply.md              # TDD強制 + 自律判断 + スキル注入
│       └── propose.md            # 自律判断（AskUserQuestion禁止）
├── specs/                        # メイン仕様（永続）
└── changes/                      # 変更提案（一時的）
```
