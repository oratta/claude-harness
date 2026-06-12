---
name: longrun-feedback
description: 自律実行完了後のフィードバックを分類・実行する。ユーザーの無選別フィードバック（brain dump）をTier 1（cosmetic）/ Tier 2（spec-aligned fix）/ Tier 3（new change）に自動分類し、Tier 1/2は即座に修正、Tier 3はopenspec/backlog.mdに記録する。/longrun:exec の Feedback Tier 確認（Build→Verify workflow 完了後のメインループ）からも呼ばれる共通ロジック。
version: 4.2.0
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion, Task
---

# Run Feedback — フィードバック分類・実行スキル

自律実行完了後のフィードバックを処理するスキル。
`/longrun:exec` の Feedback Tier 確認（Build→Verify workflow 完了後にメインループへ戻った時点）と、`/longrun:feedback` コマンドの両方から使われる共通ロジック。

## 設計原則

1. **ユーザーは分類しない**: brain dumpを受け取り、システムが分類する
2. **仕様整合性を守る**: specのScenarioに影響する変更は必ずspec経由で行う
3. **スコープクリープを防ぐ**: Tier 3の境界を明確にし、即アーカイブを促す
4. **アーカイブ前が最適タイミング**: delta specが生きている間に修正する

## Tier分類基準

### Tier 1: Cosmetic Fix（仕様外の表層修正）
- **対象**: typo、色、余白、フォントサイズ、文言の微調整、アイコン差し替え
- **基準**: specのScenario（WHEN/THEN）に影響しない変更
- **処理**: specは触らず、コードだけ修正してcommit
- **例**: 「ボタンの色をもう少し濃くして」「余白が狭い」「テキストの誤字」

### Tier 2: Spec-Aligned Fix（既存spec範囲内の修正）
- **対象**: 仕様通りだが動作が変、エッジケースの漏れ、既存capabilityの調整
- **基準**: 既存changeのspec.mdに記述されたcapability範囲内
- **処理**:
  1. spec.mdのScenarioを追加/修正
  2. TDDで修正（テスト追加 → 実装修正）
  3. tasks.mdに追記
  4. commit
- **例**: 「空入力でエラーにならない」「一覧の並び順が逆」「ローディング表示がない」

### Tier 3: New Change（新規要件）
- **対象**: 既存changeのcapabilityスコープ外、または工数が大きい（30分超の見積もり）
- **基準**: 新しいcapabilityが必要、またはアーキテクチャに影響する変更
- **処理**: backlog に記録。現runではやらない。**記録先は動作モードで分岐する**:
  - **通常 run**（縮退マーカーなし）→ `openspec/backlog.md`（従来どおり）
  - **縮退 run**（`{longrun-dir}/.degraded-mode` あり）→ `{longrun-dir}/backlog.md` に
    フォールバック。`openspec/` ディレクトリは作成しない（後述「Step 7」参照）
- **例**: 「通知機能も欲しい」「管理画面を追加して」「パフォーマンスを抜本的に改善して」

## 実行フロー

### Step 0: コンテキストロード

1. **未アーカイブrunの特定**:
   ```bash
   ls -1d _longruns/20*/ 2>/dev/null | sort | tail -1
   ```
   見つからない場合はエラー: 「アクティブなrunが見つかりません」

2. **必要ファイルの読み込み**（spec 類のパスは動作モードで分岐）:
   - `{longrun-dir}/plan.md` — スコープ・受け入れ条件の把握
   - `{longrun-dir}/decisions.md` — 設計判断の把握
   - 各 change の spec 類:
     - **NORMAL run** → `openspec/changes/<name>/` 配下の `proposal.md` /
       `specs/<capability>/spec.md` / `tasks.md`
     - **DEGRADED run** → `{longrun-dir}/specs/<change-name>/` 配下の `proposal.md` /
       `spec.md` / `tasks.md`（縮退モードの自己完結 spec）

3. **動作モードの判定（縮退フォールバックの起点）**:
   ```bash
   test -f "{longrun-dir}/.degraded-mode" && echo "DEGRADED" || echo "NORMAL"
   ```
   - **NORMAL** → Tier 3 の記録先は `openspec/backlog.md`（従来どおり）
   - **DEGRADED** → Tier 3 の記録先は `{longrun-dir}/backlog.md`（フォールバック。
     `openspec/` は作成しない）
   以降この記録先を **`{backlog-path}`** として参照する。

4. **既存backlogの確認**:
   - `{backlog-path}` が存在すれば読み込む（NORMAL なら `openspec/backlog.md`、
     DEGRADED なら `{longrun-dir}/backlog.md`）

### Step 1: フィードバック収集

引数でフィードバックが渡されていない場合、AskUserQuestionで聞く:

```
動作確認で気づいたことを教えてください。
分類は不要です。思ったことをそのまま全部伝えてください。
（例: 「ボタンの色が変」「一覧が遅い」「通知も欲しい」など）
```

### Step 2: アイテム分解

フィードバックを個別のアイテムに分解する。1つのフィードバックに複数の要望が混在していることが多い。

分解の粒度: **1修正 = 1アイテム**

### Step 3: Tier分類

各アイテムについて:

1. **specのScenarioへの影響を判定**:
   - 既存の `specs/<capability>/spec.md` のWHEN/THENに影響するか？
   - No → **Tier 1**（cosmetic）
   - Yes → 次へ

2. **既存changeのcapability範囲内か判定**:
   - `proposal.md` のCapabilitiesに含まれるか？
   - `specs/<capability>/spec.md` のRequirementsに関連するか？
   - Yes → **Tier 2**（spec-aligned fix）
   - No → **Tier 3**（new change）

3. **工数による補正**:
   - Tier 2と判定したが30分超の見積もり → **Tier 3に格上げ**

### Step 4: 分類結果の提示

ユーザーに分類結果を提示して確認する:

```
フィードバックを分類しました:

🎨 Cosmetic Fix（spec変更なし、即修正）:
1. ボタンの色を濃くする
2. 余白の調整

🔧 Spec-Aligned Fix（spec更新 + TDD修正）:
3. 空入力時のバリデーション追加
4. 一覧の並び順を修正

📋 New Change（backlogに記録、今回は対応しない）:
5. 通知機能の追加
6. 管理画面
   → 記録先: {backlog-path}（縮退 run の場合は `_longruns/<run>/backlog.md` と明示）

この分類で進めていいですか？変更があれば教えてください。
```

**Tier 3 を提示する際は、記録先パス（`{backlog-path}`）を必ず明示する**。縮退 run では
`_longruns/<run>/backlog.md` に記録されることをユーザーが分かるようにする。

### Step 4b: 実行計画の宣言（必須出力 — 自己拘束）

<GATE>
ユーザーが分類結果を承認した後、実際の修正に入る前に、以下の宣言を必ず出力すること。
この宣言を出力せずに Step 5 以降に進むことは禁止。
</GATE>

分類結果がユーザーに承認されたら、以下を出力する:

```
分類が確定しました。以下の順で実行します:

🎨 Tier 1（Cosmetic Fix）: N件
- specは変更しない。コード修正のみ。

🔧 Tier 2（Spec-Aligned Fix）: N件 — 各アイテムについて:
  1. spec.md の Scenario を追加/修正
  2. テストを追加（RED確認）
  3. 実装を修正（GREEN確認）
  4. 全テスト PASS 確認
  ※ spec更新なしにコードだけ直すことは禁止

📋 Tier 3（New Change）: N件
- backlog.md に記録。現runでは対応しない。

Tier 1 から開始します。
```

**なぜこの宣言が必要か:** 特にTier 2でspec更新→テスト追加(RED)→実装修正(GREEN)のTDDサイクルが省略されやすい。「小さい修正だからspecもテストも不要」と合理化しがちだが、自分で「spec更新なしにコードだけ直すことは禁止」と宣言することで、その省略が自己矛盾になり抑制される。

### Step 5: Tier 1実行（Cosmetic Fix）

Tier 1のアイテムをまとめて修正:

1. コードを修正
2. commit: `style: [修正内容の要約]`

specは一切触らない。

### Step 6: Tier 2実行（Spec-Aligned Fix）

Tier 2のアイテムを処理:

1. 対象changeの `specs/<capability>/spec.md` にScenarioを追加/修正
2. TDDで修正:
   - テストを追加（RED）
   - 実装を修正（GREEN）
   - 全テストPASS確認
3. `tasks.md` にフィードバック対応タスクを追記し `[x]` にする
4. commit: `fix: [修正内容の要約]`

**上限**: Tier 2の修正ラウンドは最大3回まで。3回を超える場合はTier 3に格上げし、backlogに移す。

### Step 7: Tier 3記録（Backlog）

Tier 3のアイテムを **Step 0 で確定した `{backlog-path}`** に記録する:
- **NORMAL run** → `openspec/backlog.md`
- **DEGRADED run** → `{longrun-dir}/backlog.md`（`openspec/` ディレクトリは作成しない）

```markdown
# Backlog

OpenSpec changeとして未対応のフィードバック。
`/longrun:plan` 作成時に参照される。

## From: YYYY-MM-DD longrun ([slug])
- [ ] [アイテム内容] — [簡単な背景/理由]
- [ ] [アイテム内容] — [簡単な背景/理由]
```

記録フォーマットは NORMAL / DEGRADED で同一。既に `{backlog-path}` が存在する場合は追記する。

<GATE>
DEGRADED run では `openspec/backlog.md` に書いてはならず、`openspec/` ディレクトリを
作成してもならない。記録先は必ず `{longrun-dir}/backlog.md`。
NORMAL run のフォールバック分岐への迂回も禁止（従来どおり `openspec/backlog.md`）。
</GATE>

commit: `docs: add feedback items to backlog`（DEGRADED 時はメッセージに run 名を含めてもよい）

### Step 8: 完了報告 + 継続確認

```
フィードバック対応完了:
- 🎨 Cosmetic: N件修正済み
- 🔧 Fix: N件修正済み（spec更新含む）
- 📋 Backlog: N件記録済み

他に気づいたことがあれば教えてください。
なければ「OK」でアーカイブに進みます。
```

ユーザーが追加フィードバックを出した場合 → Step 1に戻る（ただし全体で最大3ラウンド）。
3ラウンド超えた場合 → 残りは全てTier 3としてbacklogに記録し、アーカイブを促す。

「OK」の場合 → `/longrun:archive` を案内（exec のメインループから呼ばれている場合は Archive フェーズへ進む）。

## /longrun:exec のメインループからの呼び出し

Build→Verify workflow の完了後、メインループが Feedback Tier 確認でユーザーがフィードバックを返した場合、
このスキルのStep 2以降を実行する。Step 0（コンテキストロード）はメインループが既にコンテキストを
持っているためスキップ可能。

## 注意事項

- Tier 2の修正後は全テストを再実行して既存機能を壊していないことを確認する
- Tier 1/2の修正はアーカイブ前に行う。アーカイブ後のTier 1/2修正はこのスキルのスコープ外
- backlog.mdはgitにcommitする（仕様の一部として管理）
