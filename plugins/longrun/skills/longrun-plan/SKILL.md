---
name: longrun-plan
description: 自律実行用のplan.mdを対話的に作成する。ユーザーのbrain dumpを分析し、発散リスクの高い論点を特定して質問で埋めた上で、構造化されたplanファイルを生成する。OpenSpecのbacklog・既存changesも自動参照し、巻き込めるタスクを提案する。「planを作りたい」「実行計画を作成」「run準備」で起動。
version: 5.2.0
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

## モード分岐（フルモード / MVP モード）

<GATE>
本スキルは Step 1 以降を実行する前に、必ず引数を検査して以下のいずれかのモードを決定すること。
モード決定をスキップして既存 Step 1 に直行することは禁止。
</GATE>

引数（コマンド経由のテキストおよびフラグ）を解釈して、起動モードを以下のルールで決定する:

- 引数に `--mode=mvp` が含まれる → **MVP モード** に分岐し、本ファイル末尾の `## MVP モード（--mode=mvp）` セクションへ制御を移す
- 引数に `--mode=full` が含まれる、または `--mode=` フラグが一切無い → **フルモード**。下記の既存 `# Run Plan — plan.md 作成スキル` 以降（Step 1 〜 Step 8）を**そのまま**実行する
- 上記以外（例: `--mode=experimental` など未知の値）→ フルモードにフォールバックし、ユーザーに「未知のモード値だったためフルモードで継続する」と通知する

モードを決定したら、決定結果を 1 行で出力する（例: `モード判定: MVP モード（--mode=mvp）` / `モード判定: フルモード（既定）`）。これにより受け入れ条件 #7 のログ確認が可能になる。

**設計原則（regression 回避）**: フルモードに分岐した場合、以降の Step 1 〜 Step 8 の本文には**一切の差分**が無い。MVP モード固有の追記はすべて本セクションおよび末尾の `## MVP モード（--mode=mvp）` セクションに閉じている。

# Run Plan — plan.md 作成スキル

自律実行のための plan.md を対話的に作成するスキル。
Brain Dump → 開発フレームワーク理解 → Gap Analysis → Interview → Synthesis → Validation の6フェーズで、ユーザーの意図を最大限正確に構造化する。

## 自律実行フレームワークの理解（最重要）

plan.md は単なる「やりたいことリスト」ではない。自律実行エンジンへの入力であり、以下の開発プロセスを駆動する設計図である。このプロセスを理解した上で plan.md を設計すること。

### 自律実行の開発プロセス

```
plan.md（このスキルの出力）
  ↓ /longrun:exec が読み込んで Workflow スクリプトを生成・起動する
Build Contract: longrun-reviewer が実装計画をレビュー
  ↓ 承認後
Build: longrun-builder が TDD 実装
  → spec の Scenarios（WHEN/THEN）からテスト自動生成
  → テスト FAIL 確認 → 最小コードで PASS → リファクタ
  ↓
Verify: longrun-verifier が4軸定量評価
  → 機能性（Scenario通過率）/ 品質 / 完成度 / UX
  → ハードしきい値未達 → フィードバック付き差し戻し
  ↓
Feedback: longrun-feedback がユーザーフィードバックを Tier 分類
  → Tier 1/2 即修正、Tier 3 backlog
```

### plan.md に求められる品質

この開発プロセスから逆算すると、plan.md には以下が必要:

1. **仕様化できる要件**: OpenSpec の spec-agent が proposal/spec/design/tasks に変換できる具体性
2. **テスト可能な受け入れ条件**: TDD の Red Phase でテストコードに変換できる条件。「使いやすいUI」ではなく「お気に入りボタンをタップすると入力モーダルが開く」
3. **テストフレームワークの指定**: どのテストフレームワーク（Vitest, Jest, Playwright等）を使うか明示
4. **スコープの明確な境界**: 「何を変更するか」と「何を変更しないか」の両方

**要するに: plan.md の各セクションを書くとき、常に「これが仕様化され、TDD でテストされ、定量評価される」ことを意識して書く。**

## 引数の解釈と起動パターン

### パターンA: ユーザーが明示的なリクエストあり
- ファイルパスが渡された場合: そのファイルをbrain dumpとして読み込む
- テキストが渡された場合: それ自体をbrain dumpとして扱う
- **フロー**: ユーザーのリクエストからChanges分解を設計 → 設計完了後にbacklog/既存changesと照合して巻き込み提案

### パターンB: 引数なし
- **フロー**: まずbacklog/既存changesを確認 → 対応待ちアイテムを提示 → ユーザーと対話して何をやるか決定 → Changes分解を設計

## 実行フロー

### Step 1: テンプレート読み込み（最初に必ず実行）

<GATE>
Step 1を完了するまで、Step 2以降に進んではならない。
Brain Dumpの分析、ユーザーとの対話、plan.mdの生成、いずれも禁止。
まずテンプレートを読み込み、出力に必要なセクション構造を把握すること。
</GATE>

**必ずReadツールで以下の2ファイルを読み込む:**

1. `templates/plan-template.md`（パス: 同プラグイン内の `templates/plan-template.md`）
   - **これが plan.md の必須セクション構造を定義する**
   - 全セクション名を抽出し、生成時のチェックリストとして保持する
2. `commands/exec.md` を読み込む（パス: 同プラグイン内の `commands/exec.md`）
   - Review → Build → Verify → Feedback → Archive の流れ（Workflow スクリプト生成・起動）を把握
   - 特に Build フェーズが plan.md の Changes 分解をどう消費するかを理解

**Step 1の完了条件**: テンプレートから以下の必須セクションを抽出できていること:
- ゴール
- 技術要件（テストフレームワーク含む）
- スコープ
- Changes分解
- 受け入れ条件（必須条件4項目 + 機能固有条件）
- 動作確認方法（起動コマンド + テスト実行コマンド + 確認手順）

### Step 2: OpenSpec状態の確認（backlog + 既存changes）

**全パターン共通で実行する。** OpenSpecの現在の状態を把握する:

1. **backlogの確認**: `openspec/backlog.md` が存在すれば読み込む
2. **未完了changesの確認**: `openspec/changes/` 配下で `archive/` 以外のディレクトリを確認
   - 各changeの `proposal.md` を読み、何のchangeか把握する
   - 各changeの `tasks.md` を読み、完了状態を確認する
3. **既存specsの確認**: `openspec/specs/` でどんなcapabilityが実装済みか把握する

結果を内部的に保持する（ユーザーへの表示はパターンで異なる）。

#### パターンBの場合（引数なし）: 対応待ちアイテムの提示

backlogや未完了changesがある場合、ユーザーに提示する:

```
対応待ちのアイテムがあります:

📋 Backlog（前回のフィードバックから）:
- [ ] 通知機能の追加（2026-03-19 purchase-flow runから）
- [ ] ページネーション（2026-03-19 purchase-flow runから）

🔧 未完了のOpenSpec changes:
- cart-ux-fix: proposal済み、未apply（tasks 0/5）

どれに取り組みますか？または新しく作りたいものがあれば教えてください。
```

#### パターンAの場合: Step 5b で照合

パターンAではこの時点ではbacklog情報を表示しない。ユーザーのリクエストを優先し、Changes分解が完了したStep 5bで照合する。

### Step 2b: Brain Dump収集

引数からbrain dumpを取得する（パターンBで対話から得た情報も含む）。

既存のプロジェクトコンテキストがあれば読み込む:
- `context/core/project.md`
- `context/context.md`
- `CLAUDE.md`
- `package.json` / `Cargo.toml` 等（技術スタック推測用）

### Step 3: Gap Analysis（ギャップ分析）

brain dumpを分析し、**必ず以下のフォーマットで**ユーザーに提示する。自由形式での分析は禁止。

```
📊 Brain Dump分析結果:

✅ 十分な情報がある領域:
- ゴール: [要約]
- ユーザー像: [要約]
- 技術スタック: [推測含む]

⚠️ 曖昧な領域（質問で明確化する）:
- [領域1]: [何が曖昧か]
- [領域2]: [何が曖昧か]

❌ 情報がない領域（質問で補完する）:
- [領域3]: [なぜ必要か]

💡 発散リスクが高い論点（必ず確認する）:
- [論点1]: 「AかBかで実装が大きく変わる」
- [論点2]: 「ここが不明確だとUI全体に影響する」

🧪 開発プロセス観点の不足（仕様化・テストに必要な情報）:
- テストフレームワーク: [指定あり/なし]
- テスト可能な受け入れ条件: [十分/不足]
- 仕様化に必要な具体性: [十分/不足。どの要件が曖昧か]
```

**「発散リスク」の判定基準:**

| 発散リスクの種類 | 例 |
|----------------|-----|
| 二択以上の設計分岐 | SPA vs SSR、REST vs GraphQL |
| スコープの境界 | 「管理画面も含む？」「モバイル対応は？」 |
| ビジネスロジックの核心 | 「料金計算のルールは？」「承認フローの段階は？」 |
| UIの根本的な方向性 | 「ダッシュボード型？フォーム型？チャット型？」 |
| データモデルの根幹 | 「ユーザーとチームの関係は1:1？1:N？」 |

分析結果をユーザーに共有してから次のステップへ進む。

### Step 4: Interview（1問ずつ）

AskUserQuestion を使い、**1問ずつ**質問する。

**質問の設計原則:**
1. **提案ドリブン**: 「AとBどちらですか？私の推奨はAです。理由は〜」
2. **発散リスク順**: 最も実装に影響する論点から聞く
3. **コンテキスト付き**: 「あなたの言った〜を踏まえると、こういう選択肢が考えられます」
4. **最小限**: 十分な情報が集まったら質問を打ち切る
5. **開発プロセス観点**: テストフレームワークやテスト可能性に関する質問も含める

**「十分な情報」の閾値:**
- ゴールが1文で明確に記述できる
- 受け入れ条件が3つ以上、テストコードに変換可能な具体性で書ける
- 主要な技術選定が決まっている（テストフレームワーク含む）
- UIの大まかな方向性がある
- データモデルの根幹が固まっている
- スコープの境界が明確（含むもの/含まないもの）

**質問の打ち切り:**
閾値に達したら、以下を提示して続行するか確認する:
```
ここまでの情報で、以下のことが実現できます:
- [確実に実現できること]
- [ある程度の裁量で実現できること]

以下については、実装中に longrun-builder が自律判断します:
- [自律判断する項目]

これで十分ですか？追加で伝えたいことがあれば教えてください。
```

### Step 5: Synthesis（plan.md生成）

質問の回答を統合し、構造化された plan.md を生成する。

**保存先の決定:**
1. brain dumpから英語の短いslugを生成（例: `habit-skip`, `daily-impact`, `auth-refactor`）
2. 今日の日付を取得（YYYY-MM-DD形式）
3. ランディレクトリを作成: `_longruns/YYYY-MM-DD_slug/`
4. plan.md を `_longruns/YYYY-MM-DD_slug/plan.md` に保存

**生成時の心得:**

各セクションを書く際に、常に自律実行の開発プロセスを意識する:

- **ゴール**: OpenSpec の proposal.md の "Why" に直結する。1-2文で明確に
- **技術要件**: テストフレームワークを必ず含める。Build フェーズで使用される
- **スコープ**: OpenSpec の proposal.md の "What Changes" と "Capabilities" に対応。含む/含まないの境界を明確に
- **画面・UI設計**: OpenSpec の spec.md の Requirements に変換される。検証可能な具体性で書く
- **データモデル**: OpenSpec の design.md の Decisions に対応。エンティティの関係を明確に
- **受け入れ条件**: OpenSpec の spec.md の Scenarios（WHEN/THEN）に変換され、Build フェーズでテストコードになる。必ずテスト可能な形で書く
- **動作確認方法**: Verify フェーズの longrun-verifier が使用する。起動コマンドとテストコマンドを必ず含める

**生成する plan.md の構造:**

`templates/plan-template.md` の構造に従う。特に以下の必須セクションを必ず含めること:

- 受け入れ条件の **必須条件3項目**（OpenSpec仕様レビュー済み / テスト全PASS / ビルドエラーなし）
- 技術要件の **テストフレームワーク指定**
- **動作確認方法**（テスト実行コマンド含む）

### Step 5a: 残りステップの宣言（必須出力 — 自己拘束）

<GATE>
plan.md を生成したら、ファイル保存前に以下の宣言を必ずユーザーに出力すること。
この宣言を出力せずに Step 6 以降に進むことは禁止。
</GATE>

plan.md の内容が固まったら、**保存する前に**以下を出力する:

```
plan.md を生成しました。保存前に以下の3ステップを実行します:

1. **Validation** — テンプレート必須セクションの存在 + 内容品質チェック
2. **Plan Review** — longrun-reviewer Agent を呼び出して外部レビュー（自己レビューではない）
3. **ユーザー確認** — レビュー結果とともに最終確認を依頼

まず Validation から開始します。
```

**なぜこの宣言が必要か:** 自分で出力した内容はコンテキスト内で自己拘束として機能する。特にStep 7（Plan Review）はStep 6のセルフバリデーション直後に「もう確認済み」と感じてスキップしやすいが、ここで「longrun-reviewer Agent を呼び出す」と宣言しておくことで、その省略が自分の出力との矛盾になり、実行率が上がる。

### Step 5b: Backlog/既存changes照合（パターンAのみ）

**パターンAの場合のみ実行。** Changes分解が完了した後、Step 2で取得したbacklog/既存changesと照合する。

ユーザーのリクエストから作成したChangesと、backlog/未完了changesの間で:
1. **同じcapabilityスコープに含まれるもの**: 一緒にやれる可能性が高い
2. **関連するUI/データを触るもの**: ついでに対応すると効率が良い
3. **依存関係があるもの**: 先にやっておくべきかもしれない

該当するアイテムがあれば提案する:

```
Changes分解が完了しました。
ここで、一緒に対応できそうなアイテムが見つかりました:

📋 Backlogから:
- 「ページネーション」→ 一覧画面を触るchange-Bに組み込める
- 「通知機能」→ スコープが大きいため今回は見送り推奨

🔧 既存changesから:
- cart-ux-fix → 購入フローに関連。change-Aと統合可能

組み込むものを選んでください（なしでもOK）。
```

ユーザーが選択したアイテム:
- **backlogから採用**: plan.mdの該当changeに要件を追記。**まだbacklog.mdは編集しない**（Step 7で確定時に消込み）
- **既存changeから採用**: plan.mdのChanges分解に統合

該当アイテムがない場合はこのステップをスキップ。

### Step 6: Validation（生成後チェック）

<GATE>
このチェックに全て合格するまで、plan.md をファイルに保存してはならない。
1つでも欠けていたら、plan.md の内容を修正してから保存すること。
チェック結果をユーザーに明示的に表示すること。
</GATE>

**セクション存在チェック**（Step 1で抽出したテンプレート必須セクションとの照合）:
- [ ] 「ゴール」セクションがあるか
- [ ] 「技術要件」セクションがあるか
- [ ] 「スコープ」（含むもの/含まないもの）セクションがあるか
- [ ] 「Changes分解」セクションがあるか
- [ ] 「受け入れ条件」セクションがあるか
- [ ] 「動作確認方法」セクションがあるか

**内容品質チェック**:
- [ ] 受け入れ条件に OpenSpec 必須条件（仕様作成・レビュー済み）が含まれているか
- [ ] 受け入れ条件にテスト必須条件（全テストPASS）が含まれているか
- [ ] 受け入れ条件にビルド必須条件（型チェック + ビルド成功）が含まれているか
- [ ] 技術要件にテストフレームワークが指定されているか
- [ ] 動作確認方法に起動コマンドが記載されているか
- [ ] 動作確認方法にテスト実行コマンドが記載されているか
- [ ] 機能固有の受け入れ条件がテストコードに変換可能な具体性を持っているか

**チェック結果の表示形式**:
```
📋 Validation結果:
✅ ゴール
✅ 技術要件（テストフレームワーク: Vitest）
✅ スコープ
✅ Changes分解
✅ 受け入れ条件（必須4項目 + 機能固有N項目）
✅ 動作確認方法（起動: npm run dev / テスト: npm test）
❌ [欠落項目があればここに表示]
```

全て ✅ になったら、plan.md をファイルに保存し、Step 7 の外部レビューに進む。

### Step 7: Plan Review（外部レビュー — 自己評価バイアス排除）

<GATE>
このステップを飛ばしてはならない。省略してはならない。
plan.md を自分でレビューして「問題ありません」と言ってはならない。
必ず以下の手順で Agent ツールを呼び出すこと。
</GATE>

plan.md を保存した後、**必ず Agent ツールを使って longrun-reviewer にレビューさせる。**

**必須アクション — 以下のツール呼び出しを必ず実行すること:**

```
Agent ツールを呼び出す:
  subagent_type: "longrun-reviewer"
  prompt: "以下のplan.mdをBuild Contractレビューしてください: [plan.mdのフルパス]"
```

このツール呼び出しを行わずにStep 8に進むことは禁止。

**longrun-reviewer が評価する項目:**
1. 各changeの実装計画が現実的か
2. 技術的リスクが特定されているか
3. 依存関係の順序が正しいか
4. スコープが適切か（大きすぎるchangeの分割提案）
5. 受け入れ条件がテスト可能な具体性を持っているか

**longrun-reviewer の結果に応じた処理:**
- **APPROVE** → Step 8（ユーザー確認）へ
- **REQUEST_CHANGES** → 指摘事項に基づいてplan.mdを修正 → 再度Agentツールでlongrun-reviewerを呼び出す
- 最大2ラウンド。2回でAPPROVEされない場合は残課題を明記してStep 8へ

**レビュー結果をユーザーに表示する:**
```
📋 Plan Review結果（by longrun-reviewer）:
Status: APPROVE / REQUEST_CHANGES

✅ 実装可能性: [評価]
✅ 技術的リスク: [評価]
✅ 依存関係: [評価]
✅ スコープ: [評価]
✅ 受け入れ条件: [評価]
```

### Step 8: ユーザー確認 + Backlog消込み + 確定

レビュー通過後、ユーザーにplan.mdの最終確認を依頼する。修正があれば反映する。

plan.md が確定したら（ユーザーがOKを出した後）:

1. **backlogから採用したアイテムの消込み**:
   - `openspec/backlog.md` の該当行を削除する
   - 部分採用の場合は、残りの部分を行に残す
   - backlog.md が空になった場合はファイルを削除する
   - commit: `docs: update openspec backlog (adopted items removed)`

2. **確定報告**:
   「自律実行の準備完了」を報告し、`/longrun:exec` コマンドでの実行を案内する。

## MVP モード（--mode=mvp）

### 概要

短時間で**人間が手で MVP を実装する**用途のための軽量フロー。フルモードに含まれる Build Contract レビュー / TDD 強制 / Verifier 自動起動はスキップする。レビューは subagent による APPROVE/REQUEST_CHANGES で完結し、最終判断は人間に委ねる。

このモードは**特定のプロジェクトには依存しない汎用機能**であり、任意のプロジェクトから `/longrun:plan --mode=mvp` で呼び出せる。

### Step 1〜8 × MVP モード対応マッピング

| 既存 Step | MVP モード対応 | 内容 |
|---|---|---|
| Step 1（テンプレート読み込み） | REPLACE | `templates/plan-template-mvp.md`（軽量版）を読み込む |
| Step 2（OpenSpec 状態確認） | SKIP | 人間実装前提なので backlog 照合不要 |
| Step 2b（Brain Dump 収集） | REUSE | 引数 / 対話で取得する流れは同じ |
| Step 3（Gap Analysis） | REUSE | 軽量化せずそのまま実施 |
| Step 4（Interview） | REUSE | AskUserQuestion で 3〜5 問 |
| **Step 4.5（並列リサーチ）【新規】** | ADD | `longrun-mvp-research` subagent×1 を Agent ツールで起動。1 レポート 2 セクション（類似サービス / 実装パターン）を取得 |
| Step 5（Synthesis） | REPLACE | 軽量テンプレに従って v0 plan.md を生成。先頭に `<!-- mvp-mode -->` マーカーを必ず埋め込む |
| Step 5a（残りステップ宣言） | REPLACE | MVP 用文言（review subagent×2 並列レビュー → ユーザー確認）に書き換え |
| Step 5b（Backlog 照合） | SKIP | Step 2 をスキップしているため不要 |
| Step 6（Validation） | REPLACE | 軽量テンプレ用 Validation チェックリストに切り替え |
| Step 7（Plan Review） | REPLACE | `longrun-mvp-plan-reviewer` + `longrun-mvp-bestpractice-reviewer` を**単一メッセージ内の複数 tool_use として並列起動** |
| Step 8（確認 + 確定） | REPLACE | backlog 消込みなし。OpenSpec change 生成もしない。ハンドオフ案内のみ |

**SKIP の根拠**: Step 2 / Step 5b を SKIP するのは、MVP モードで生成される plan.md が人間実装を前提としており OpenSpec change 自動生成パイプラインに乗せない設計だからである（archive 側で `<!-- mvp-mode -->` マーカーを見て OpenSpec 生成をスキップする / change-C で実装）。

### MVP Step 1（REPLACE）: 軽量テンプレート読み込み

Read ツールで `templates/plan-template-mvp.md`（同プラグイン内の軽量テンプレ）を読み込む。フル版 `templates/plan-template.md` は読み込まない。読み込んだテンプレから必須セクション一覧を抽出し、Step 6 の Validation で使用する。

### MVP Step 2（SKIP）

OpenSpec backlog および既存 changes の確認は行わない。MVP モード plan.md は OpenSpec change 自動生成パイプラインに乗らないため、backlog 照合の意味がない。

### MVP Step 2b〜Step 4（REUSE）

フルモードの Step 2b（Brain Dump 収集）/ Step 3（Gap Analysis）/ Step 4（Interview, AskUserQuestion 1 問ずつ）をそのまま流用する。プロジェクトコンテキスト（`context/core/project.md` / `CLAUDE.md` 等）の読み込みも同様に実施する。

### MVP Step 4.5（NEW）: 並列リサーチ

<GATE>
Step 4 の Interview 完了後、Step 5 の Synthesis に進む前に必ず本ステップを実行する。
リサーチ結果無しに plan.md の Synthesis を行うことは禁止。
</GATE>

Agent ツールで `longrun-mvp-research` subagent を **1 つ起動**する。現状 1 個でも、将来的なリサーチ拡張（領域別 research）を視野に、**Agent ツール呼び出しは単一メッセージ内に複数 tool_use を配置するパターン**で実装すること（並列起動の作法を MVP モード全体で統一するため）。

呼び出し例:

```
Agent ツール:
  subagent_type: "longrun-mvp-research"
  prompt: |
    以下のテーマで MVP 向け調査を実施してください。
    テーマ: {Interview で確定した機能・対象ドメインの 1〜2 文要約}
    出力契約:
    - 単一レポートに `## 類似サービス事例` と `## 実装パターン` の両セクションを含めること
    - 末尾に `## Search Audit` を必ず付け、`- queries: <N>` と `- list: [...]` を記載
    - 同一クエリの重複検索を行わない（理想は queries: 1）
```

subagent から返ってきた 1 レポート（2 セクション + Search Audit）を context 内に保持し、Step 5 の Synthesis で軽量テンプレの「調査結果サマリ（類似サービス）」「調査結果サマリ（実装パターン）」セクションに圧縮反映する。

### MVP Step 5（REPLACE）: 軽量 Synthesis

軽量テンプレ `plan-template-mvp.md` の構造に従って v0 plan.md を生成する。**生成されるファイルの 1 行目（タイトル見出しより前）に必ず以下のマーカーコメントを入れる:**

```
<!-- mvp-mode -->
```

このマーカーが `/longrun:archive`（change-C）で OpenSpec change 生成をスキップする判定根拠となる。フルモードの plan.md にはこのマーカーが存在しないため、archive 側は安全に分岐できる。

保存先パス決定の規則（英語 slug + 日付 `YYYY-MM-DD_slug` を `_longruns/` 配下に作る）はフルモードと同じ。

### MVP Step 5a（REPLACE）: 残りステップの宣言

plan.md を保存する**前に**以下の宣言を出力する:

```
plan.md を生成しました。保存前に以下の3ステップを実行します:

1. **Validation** — 軽量テンプレ必須セクションの存在チェック
2. **Plan Review** — longrun-mvp-plan-reviewer と longrun-mvp-bestpractice-reviewer を**並列起動**（単一メッセージ内に2つの Agent tool_use）
3. **ユーザー確認** — レビュー結果とともに最終確認を依頼

まず Validation から開始します。
```

### MVP Step 5b（SKIP）

MVP モードでは Step 2 で backlog 照合をしていないため本ステップも実行しない。

### MVP Step 6（REPLACE）: 軽量 Validation

<GATE>
このチェックに全て合格するまで、plan.md をファイルに保存してはならない。
1 つでも欠けていたら plan.md を修正してから保存すること。
</GATE>

軽量テンプレの必須セクション存在チェックを行う。次の 7 セクションを必ず含むこと:

- [ ] ゴール
- [ ] 技術要件
- [ ] スコープ
- [ ] 受け入れ条件
- [ ] 動作確認方法
- [ ] 調査結果サマリ（Step 4.5 の 2 セクションを軽量化反映）
- [ ] レビュー結果サマリ（Step 7 の出力を反映する空欄プレースホルダでも可）

加えて、ファイル先頭に `<!-- mvp-mode -->` マーカーが存在することを Grep で確認する。フルモードの「OpenSpec 必須条件 / TDD 必須条件 / ビルド必須条件」チェックは MVP モードでは行わない（軽量テンプレに該当セクションが無いため）。

### MVP Step 7（REPLACE）: 並列レビュー

<GATE>
本ステップは省略禁止。`longrun-mvp-plan-reviewer` と `longrun-mvp-bestpractice-reviewer` を**必ず並列起動**する。
2 つの Agent ツール呼び出しを別メッセージに分けて発行することは禁止（並列性が失われる）。
</GATE>

**必須アクション — 単一の assistant メッセージ内に以下の 2 つの Agent ツール呼び出しを並べて発行する:**

```
Agent ツール (1):
  subagent_type: "longrun-mvp-plan-reviewer"
  prompt: |
    以下の v0 plan.md を MVP プランとしてレビューしてください: {plan.md フルパス}
    評価軸:
    - スコープが MVP として過大でないか
    - 矛盾がないか
    - 受け入れ条件が検証可能か
    出力: APPROVE または REQUEST_CHANGES + 具体的指摘 + `## Search Audit`

Agent ツール (2):
  subagent_type: "longrun-mvp-bestpractice-reviewer"
  prompt: |
    以下の v0 plan.md について該当ドメインの落とし穴・anti-pattern を指摘してください: {plan.md フルパス}
    制約: 外部検索は最大 1 回。`## Search Audit` を必ず付与（queries: <=1）
```

両 subagent からの結果を集約し、ユーザーに以下の形式で表示する:

```
📋 MVP Plan Review 結果:

[longrun-mvp-plan-reviewer] Status: APPROVE / REQUEST_CHANGES
- スコープ: ...
- 矛盾: ...
- 受け入れ条件検証可能性: ...
Search Audit: queries: <N>

[longrun-mvp-bestpractice-reviewer]
- 落とし穴: ...
- Anti-pattern: ...
Search Audit: queries: <=1
```

両者が APPROVE → MVP Step 8 へ。一方でも REQUEST_CHANGES → 指摘に基づき plan.md を修正し、最大 2 ラウンドまで再レビューを実施。2 ラウンドで通らない指摘は plan.md の「レビュー結果サマリ」セクションに残課題として明記したうえで Step 8 へ進む。

### MVP Step 8（REPLACE）: ハンドオフ案内

ユーザーに plan.md の最終確認を依頼し、修正があれば反映する。OK を得た後、以下のハンドオフメッセージを出力して MVP モードのフローを終える:

```
✅ MVP plan.md を確定しました。

保存先: _longruns/YYYY-MM-DD_slug/plan.md
（先頭に `<!-- mvp-mode -->` マーカー入り）

このまま人間が手で実装する場合: plan.md の「動作確認方法」セクションに従って着手してください。
自動実装に渡す場合: `/longrun:exec _longruns/YYYY-MM-DD_slug/` で開始できます（ただし MVP モード plan.md は自動実装パイプライン未対応の可能性あり）。
アーカイブ: `/longrun:archive _longruns/YYYY-MM-DD_slug/` を実行すると、`<!-- mvp-mode -->` マーカーを検知して OpenSpec change 生成をスキップし、ディレクトリのみアーカイブします。
```

**MVP Step 8 で実施しないこと**:
- `openspec/backlog.md` の編集（Step 2 / Step 5b を SKIP しているため照合自体していない）
- `openspec change add` 等による OpenSpec change の自動生成
- TDD テストハーネスの起動

これらが必要な場合はフルモード（`/longrun:plan` 引数なし）で再生成すること。
