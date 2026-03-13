---
name: instruction-builder
description: ロングラン実行用のinstruction.mdを対話的に作成する。ユーザーのbrain dumpを分析し、発散リスクの高い論点を特定して質問で埋めた上で、構造化された指示ファイルを生成する。「instructionを作りたい」「指示ファイルを作成」「ロングラン準備」で起動。
version: 2.2.0
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash
---

# Instruction.md 作成スキル

ロングラン自律実行のための instruction.md を対話的に作成するスキル。
Brain Dump → 開発フレームワーク理解 → Gap Analysis → Interview → Synthesis → Validation の6フェーズで、ユーザーの意図を最大限正確に構造化する。

## ロングラン開発フレームワークの理解（最重要）

instruction.md は単なる「やりたいことリスト」ではない。ロングラン実行エンジンへの入力であり、以下の開発プロセスを駆動する設計図である。このプロセスを理解した上で instruction.md を設計すること。

### ロングランの開発プロセス

```
instruction.md（このスキルの出力）
  ↓ 読み込まれる
Phase 1: OpenSpec 仕様駆動開発
  → instruction.md の要件から proposal / spec / design / tasks を生成
  → spec-review-agent がレビュー（人間の代わり）
  ↓
Phase 2: TDD Red Phase
  → spec の Scenarios（WHEN/THEN）からテストを自動生成
  → 全テストがFAILすることを確認
  ↓
Phase 3: TDD Green + Refactor
  → テストをPASSさせる最小限のコードを書く
  → タスクごとにコミット
  ↓
Phase 4: 全テストPASS + ビルド成功 + 完了
```

### instruction.md に求められる品質

この開発プロセスから逆算すると、instruction.md には以下が必要:

1. **仕様化できる要件**: OpenSpec の spec-agent が proposal/spec/design/tasks に変換できるだけの具体性。曖昧な要件は仕様化できず、実装が発散する
2. **テスト可能な受け入れ条件**: TDD の Red Phase でテストコードに変換できる条件。「使いやすいUI」ではなく「お気に入りボタンをタップすると入力モーダルが開く」のように検証可能な形で書く
3. **テストフレームワークの指定**: Phase 2 でどのテストフレームワーク（Vitest, Jest, Playwright等）を使うか明示する。未指定だとセットアップで時間を浪費する
4. **スコープの明確な境界**: OpenSpec の proposal は「何を変更するか」と「何を変更しないか」の両方を定義する。instruction.md でも同様にスコープ境界を明示する

**要するに: instruction.md の各セクションを書くとき、常に「これが OpenSpec で仕様化され、TDD でテストされる」ことを意識して書く。**

## 引数の解釈

- ファイルパスが渡された場合: そのファイルをbrain dumpとして読み込む
- テキストが渡された場合: それ自体をbrain dumpとして扱う
- 引数なしの場合: ユーザーに「何を作りたいか教えてください」と聞く

## 実行フロー

### Step 1: 開発フレームワークの確認

ロングランの開発プロセスを理解するため、以下を確認する:

1. `longrun-orchestrator` の SKILL.md を読み込む（パス: 同プラグイン内の `skills/longrun-orchestrator/SKILL.md`）
   - Phase 0-4 の流れを把握する
   - 特に Phase 1（OpenSpec）と Phase 2（TDD Red）が instruction.md をどう消費するかを理解する
2. `templates/instruction-template.md` を読み込む（パス: 同プラグイン内の `templates/instruction-template.md`）
   - 出力フォーマットを確認する

これにより「instruction.md → OpenSpec 仕様 → テスト → 実装」の流れを頭に入れた状態で以降のステップを進める。

### Step 2: Brain Dump収集

引数からbrain dumpを取得する。

既存のプロジェクトコンテキストがあれば読み込む:
- `context/core/project.md`
- `context/context.md`
- `CLAUDE.md`
- `package.json` / `Cargo.toml` 等（技術スタック推測用）

### Step 3: Gap Analysis（ギャップ分析）

brain dumpを分析し、以下の5カテゴリに分類する:

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

以下については、実装中にDecision Agentが判断します:
- [自律判断する項目]

これで十分ですか？追加で伝えたいことがあれば教えてください。
```

### Step 5: Synthesis（instruction.md生成）

質問の回答を統合し、構造化された instruction.md を生成する。

**保存先の決定:**
1. brain dumpから英語の短いslugを生成（例: `habit-skip`, `daily-impact`, `auth-refactor`）
2. 今日の日付を取得（YYYY-MM-DD形式）
3. ランディレクトリを作成: `_longrun/YYYY-MM-DD_slug/`
4. instruction.md を `_longrun/YYYY-MM-DD_slug/instruction.md` に保存

**生成時の心得:**

各セクションを書く際に、常にロングランの開発プロセスを意識する:

- **ゴール**: OpenSpec の proposal.md の "Why" に直結する。1-2文で明確に
- **技術要件**: テストフレームワークを必ず含める。Phase 2 で使用される
- **スコープ**: OpenSpec の proposal.md の "What Changes" と "Capabilities" に対応。含む/含まないの境界を明確に
- **画面・UI設計**: OpenSpec の spec.md の Requirements に変換される。検証可能な具体性で書く
- **データモデル**: OpenSpec の design.md の Decisions に対応。エンティティの関係を明確に
- **受け入れ条件**: OpenSpec の spec.md の Scenarios（WHEN/THEN）に変換され、Phase 2 でテストコードになる。必ずテスト可能な形で書く
- **動作確認方法**: Phase 4 の Verification Agent が使用する。起動コマンドとテストコマンドを必ず含める

**生成するinstruction.mdの構造:**

`templates/instruction-template.md` の構造に従う。特に以下の必須セクションを必ず含めること:

- 受け入れ条件の **必須条件3項目**（OpenSpec仕様レビュー済み / テスト全PASS / ビルドエラーなし）
- 技術要件の **テストフレームワーク指定**
- **動作確認方法**（テスト実行コマンド含む）

### Step 6: Validation（生成後チェック）

instruction.md を保存する前に、以下を確認する:

- [ ] 受け入れ条件に OpenSpec 必須条件（仕様作成・レビュー済み）が含まれているか
- [ ] 受け入れ条件にテスト必須条件（全テストPASS）が含まれているか
- [ ] 受け入れ条件にビルド必須条件（型チェック + ビルド成功）が含まれているか
- [ ] 技術要件にテストフレームワークが指定されているか
- [ ] 動作確認方法にテスト実行コマンドが記載されているか
- [ ] 機能固有の受け入れ条件がテストコードに変換可能な具体性を持っているか

1つでも欠けていたら、instruction.md を修正してから保存する。

生成後、ユーザーにレビューを依頼する。修正があれば反映する。
確定したら「ロングラン実行の準備完了」を報告し、`/exec` コマンドでの実行を案内する。
