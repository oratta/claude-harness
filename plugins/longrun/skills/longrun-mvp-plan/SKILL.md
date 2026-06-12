---
name: longrun-mvp-plan
description: 短時間で人間が手で MVP を実装するための軽量 plan.md を対話的に作成する。Brain Dump → Gap Analysis → Interview → 並列リサーチ → 軽量 Synthesis → 並列レビュー → 人間ハンドオフ。Build Contract / TDD / Verifier 自動起動 / OpenSpec 連携はスキップする。先頭に `<!-- mvp-mode -->` マーカー付き plan.md を生成。「MVP プランを作りたい」「軽量な実行計画」「手で作る MVP の準備」で起動。`/longrun:mvp`（短縮 `/lr:m`）。
version: 6.2.0
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash, Agent
---

# Run MVP Plan — 軽量 plan.md 作成スキル

短時間で**人間が手で MVP を実装する**用途のための軽量フロー。フルモード（`longrun-plan`）に含まれる Build Contract レビュー / TDD 強制 / Verifier 自動起動はスキップする。レビューは subagent による APPROVE/REQUEST_CHANGES で完結し、最終判断は人間に委ねる。

このスキルは**特定のプロジェクトには依存しない汎用機能**であり、任意のプロジェクトから `/longrun:mvp`（短縮 `/lr:m`）で呼び出せる。

このスキルは自己完結している。フルモードのスキル本文を実行時に Read する必要はない。Gap Analysis / Interview の方法論は共有リファレンス `references/plan-interview-methodology.md` を Read して適用する。

## 引数の解釈と起動パターン

引数（brain dump）を取得する。
- ファイルパスが渡された場合: そのファイルを Read して brain dump として読み込む
- テキストが渡された場合: それ自体を brain dump として扱う
- 引数なしの場合: ユーザーと対話して何を作るか決める

OpenSpec backlog および既存 changes の確認は**行わない**。MVP モード plan.md は OpenSpec change 自動生成パイプラインに乗らないため、backlog 照合の意味がない。

## 実行フロー

### Step 1: 軽量テンプレート読み込み（最初に必ず実行）

<GATE>
Step 1 を完了するまで、Step 2 以降に進んではならない。
Brain Dump の分析、ユーザーとの対話、plan.md の生成、いずれも禁止。
まず軽量テンプレートを読み込み、出力に必要なセクション構造を把握すること。
</GATE>

Read ツールで `templates/plan-template-mvp.md`（同プラグイン内の軽量テンプレ）を読み込む。フル版テンプレ（フルモード用）は読み込まない。読み込んだ軽量テンプレから必須セクション一覧を抽出し、Step 6 の Validation で使用する。

加えて、Read ツールで `references/plan-interview-methodology.md`（同プラグイン内の共有リファレンス）を読み込み、Step 3（Gap Analysis）/ Step 4（Interview）で適用する方法論を把握する。

### Step 2: Brain Dump 収集

引数から brain dump を取得する（引数なしの場合は対話から得た情報も含む）。

既存のプロジェクトコンテキストがあれば読み込む:
- `context/core/project.md`
- `context/context.md`
- `CLAUDE.md`
- `package.json` / `Cargo.toml` 等（技術スタック推測用）

### Step 3: Gap Analysis（ギャップ分析）

Step 1 で読み込んだ `references/plan-interview-methodology.md` の「Gap Analysis（ギャップ分析）」セクションに従い、brain dump を分析して**必ず指定フォーマットで**ユーザーに提示する。自由形式での分析は禁止。発散リスク判定基準もリファレンスの表に従う。

分析結果をユーザーに共有してから次のステップへ進む。

### Step 4: Interview（1問ずつ）

Step 1 で読み込んだ `references/plan-interview-methodology.md` の「Interview（1問ずつ）」セクションに従い、AskUserQuestion で**1問ずつ**質問する。質問の設計原則・「十分な情報」の閾値・質問の打ち切り手順はリファレンスに従う。

### Step 4.5: 並列リサーチ

<GATE>
Step 4 の Interview 完了後、Step 5 の Synthesis に進む前に必ず本ステップを実行する。
リサーチ結果無しに plan.md の Synthesis を行うことは禁止。
</GATE>

Agent ツールで `longrun-mvp-research` subagent を **1 つ起動**する。現状 1 個でも、将来的なリサーチ拡張（領域別 research）を視野に、**Agent ツール呼び出しは単一メッセージ内に複数 tool_use を配置するパターン**で実装すること（並列起動の作法を本スキル全体で統一するため）。

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

### Step 5: 軽量 Synthesis（plan.md 生成）

軽量テンプレ `plan-template-mvp.md` の構造に従って v0 plan.md を生成する。**生成されるファイルの 1 行目（タイトル見出しより前）に必ず以下のマーカーコメントを入れる:**

```
<!-- mvp-mode -->
```

このマーカーが `/longrun:archive` で OpenSpec change 生成をスキップする判定根拠となる。フルモードの plan.md にはこのマーカーが存在しないため、archive 側は安全に分岐できる。

**保存先の決定:**
1. brain dump から英語の短い slug を生成（例: `habit-skip`, `daily-impact`, `recipe-mvp`）
2. 今日の日付を取得（YYYY-MM-DD 形式）
3. ランディレクトリを作成: `_longruns/YYYY-MM-DD_slug/`
4. plan.md を `_longruns/YYYY-MM-DD_slug/plan.md` に保存（保存は Step 6 の Validation 合格後）

### Step 5a: 残りステップの宣言（必須出力 — 自己拘束）

<GATE>
plan.md の内容が固まったら、ファイルに保存する**前に**以下の宣言を必ずユーザーに出力すること。
この宣言を出力せずに Step 6 以降に進むことは禁止。
</GATE>

plan.md を保存する**前に**以下の宣言を出力する:

```
plan.md を生成しました。保存前に以下の3ステップを実行します:

1. **Validation** — 軽量テンプレ必須セクションの存在チェック
2. **Plan Review** — longrun-mvp-plan-reviewer と longrun-mvp-bestpractice-reviewer を**並列起動**（単一メッセージ内に2つの Agent tool_use）
3. **ユーザー確認** — レビュー結果とともに最終確認を依頼

まず Validation から開始します。
```

### Step 6: 軽量 Validation（生成後チェック）

<GATE>
このチェックに全て合格するまで、plan.md をファイルに保存してはならない。
1 つでも欠けていたら plan.md を修正してから保存すること。
チェック結果をユーザーに明示的に表示すること。
</GATE>

軽量テンプレの必須セクション存在チェックを行う。次の 7 セクションを必ず含むこと:

- [ ] ゴール
- [ ] 技術要件
- [ ] スコープ
- [ ] 受け入れ条件
- [ ] 動作確認方法
- [ ] 調査結果サマリ（Step 4.5 の 2 セクションを軽量化反映）
- [ ] レビュー結果サマリ（Step 7 の出力を反映する空欄プレースホルダでも可）

加えて、ファイル先頭に `<!-- mvp-mode -->` マーカーが存在することを Grep で確認する。フルモードの「OpenSpec 必須条件 / TDD 必須条件 / ビルド必須条件」チェックは本スキルでは行わない（軽量テンプレに該当セクションが無いため）。

いずれかのセクションが欠けていた場合は、plan.md を修正してから保存すること（GATE セマンティクス。欠落したままの保存は禁止）。全て揃ったら plan.md をファイルに保存し、Step 7 の並列レビューに進む。

### Step 7: 並列レビュー

<GATE>
本ステップは省略禁止。`longrun-mvp-plan-reviewer` と `longrun-mvp-bestpractice-reviewer` を**必ず並列起動**する。
2 つの Agent ツール呼び出しを別メッセージに分けて発行することは禁止（並列性が失われる）。
片方のレビュアを待ってからもう片方を呼ぶこともしない。
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

両者が APPROVE → Step 8 へ。一方でも REQUEST_CHANGES → 指摘に基づき plan.md を修正し、最大 2 ラウンドまで再レビューを実施。2 ラウンドで通らない指摘は plan.md の「レビュー結果サマリ」セクションに残課題として明記したうえで Step 8 へ進む。

### Step 8: ハンドオフ案内

ユーザーに plan.md の最終確認を依頼し、修正があれば反映する。OK を得た後、以下のハンドオフメッセージを出力して本スキルのフローを終える:

```
✅ MVP plan.md を確定しました。

保存先: _longruns/YYYY-MM-DD_slug/plan.md
（先頭に `<!-- mvp-mode -->` マーカー入り）

このまま人間が手で実装する場合: plan.md の「動作確認方法」セクションに従って着手してください。
自動実装に渡す場合: `/longrun:exec _longruns/YYYY-MM-DD_slug/` で開始できます（ただし MVP モード plan.md は自動実装パイプライン未対応の可能性あり）。
アーカイブ: `/longrun:archive _longruns/YYYY-MM-DD_slug/` を実行すると、`<!-- mvp-mode -->` マーカーを検知して OpenSpec change 生成をスキップし、ディレクトリのみアーカイブします。
```

**Step 8 で実施しないこと**:
- OpenSpec backlog ファイルへの書き込み（本スキルは backlog 照合自体をしていない）
- OpenSpec change 作成ツールの起動
- TDD テストハーネスの起動

これらが必要な場合はフルモード（`/longrun:plan` 引数なし）で plan.md を作り直すこと。
