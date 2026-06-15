# Longrun Plugin v6.2

Claude Code 自律実行システム。Anthropic の [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) の知見を反映した設計。

## v6.2 変更点

- **モデル割り当て機構を追加**。plan.md に「モデル割り当て」セクション（`| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |` の表）を導入し、change × agent ロール（builder / verifier / reviewer）ごとに使用モデルのティアを指定できるようにした。全 agent 一律 opus からの最適化余地（コスト・レイテンシ）を plan 段階で構造的に扱う。
- **推奨生成は `longrun-plan` スキル側**。Synthesis（Step 5c）でヒューリスティクスに基づきティアを推奨生成する:
  - アーキテクチャレビュー・複雑な TDD 実装 → **inherit**（`opts.model` を渡さず agent 定義の opus を継承）
  - 定型的な検証・要約 → **haiku**
  - リサーチ・ブラウザ操作・中規模実装 → **sonnet**
  - **保守的デフォルト: 迷ったら inherit**（確信度が低いタスクは inherit に倒す）
- **ユーザーが plan 確認時に表を直接編集して上書きできる**。`上書き` 欄が非空ならティア欄より優先される（編集後の値は巻き戻されない）。
- **消費は `/longrun:exec` 側**（責務分離）。exec が表を読み、ティアを `references/model-tiers.md` で解決して Workflow の `opts.model` に反映する。`inherit` は `opts.model` キー自体を出力しない（agent frontmatter の `model:` を上書きしない）。
- **ティア → モデル ID の対応は [`references/model-tiers.md`](references/model-tiers.md) の 1 箇所に集約**。plan.md・SKILL.md・exec.md・workflow テンプレートはティア名（haiku/sonnet/inherit）のみを扱い、モデル ID を直書きしない（世代交代時の更新箇所はこのリファレンス 1 ファイルのみ）。
- **fail-soft**: 未知のティア値・パース不能行は inherit + 警告で続行（exec を中断しない／AskUserQuestion を出さない）。
- **旧 plan.md 後方互換**: 「モデル割り当て」セクションが無い旧形式の plan.md は全ロール inherit にフォールバックし、無変更で動く（移行作業不要）。
- 消費ロジックは `scripts/resolve-model-allocation.mjs`（plan.md + model-tiers.md → 解決済み JSON）に集約。workflow テンプレートは条件付きスプレッド `...(model ? { model } : {})` で inherit 時にキーを省略する。
- `plugin.json` / `marketplace.json`（plugins[] longrun エントリ）/ longrun-plan・longrun-mvp-plan SKILL.md frontmatter の version を 6.2.0 に同期 bump（lr プラグインは変更なし＝6.1.0 据え置き）。

## v6.1 変更点

- **MVP プラン作成を独立スキル `longrun-mvp-plan` に分離**。新コマンド `/longrun:mvp`（短縮 `/lr:m`）で起動する。旧 `longrun-plan` 内のモード分岐（`--mode=mvp`）は廃止され、独立スキルとして自己完結したステップ群に再構成された。詳細は下記「MVP プランモード」セクション参照。
- **`--mode=mvp` フラグを廃止（deprecation）**。`/longrun:plan --mode=mvp`（および `/lr:p --mode=mvp`）を実行すると、MVP フローを走らせる代わりに `/longrun:mvp` への移行案内を出力して終了する（サイレント無視・フルモードへの暗黙フォールバックはしない）。
- MVP 用 agent 3 種（`longrun-mvp-research` / `longrun-mvp-plan-reviewer` / `longrun-mvp-bestpractice-reviewer`）と軽量テンプレ `plan-template-mvp.md` は配置を変えず、帰属記述を `longrun-mvp-plan` スキルに整理（出力契約は不変）。
- Gap Analysis / Interview の方法論を `references/plan-interview-methodology.md` に切り出し、新スキルが自己完結に参照できるようにした。
- `<!-- mvp-mode -->` マーカーと `/longrun:archive` 側のマーカー分岐は現状維持（成果物形式は不変）。
- `plugin.json` / `marketplace.json`（top-level / plugins[]）の version を longrun・lr とも 6.1.0 に同期 bump。

## v6.0 変更点（BREAKING）

- **`/longrun:exec` を Workflow ツールに載せ替え**。plan.md を読んで Workflow スクリプト（`templates/workflow/review.workflow.js` / `build-verify.workflow.js`）を生成・起動し、`agent()` / `pipeline()` / `parallel()` でオーケストレーションする。旧 `longrun-orchestrator` SKILL.md のインライン展開・Agent 手動制御・checkpoint.md の散文パースは**全廃**された。
- **サブエージェント成果物を JSON Schema（StructuredOutput）で機構的に強制**。builder 完了レポート / verifier 4 軸スコア / reviewer 判定を `schemas/*.schema.json` に外部化し、`agent(prompt, {schema})` で検証層が不正形式を拒否する（散文ドリフトの無言破壊を排除）。
- **Verify ループに上限 3 周 + budget ガード**。`while (round < 3)` + `budget.total && budget.remaining()` の null ガードで暴走を構造的に防止。上限到達 / budget 枯渇時は状態を報告して停止（LLM の自制に依存しない）。
- **中断再開を `resumeFromRunId` 一次手段に**。runId を `_longruns/<run>/workflow-runs.jsonl` に記録し、同一 scriptPath + args で再開すると完了済み change の builder agent が再実行されない（same-session only）。
- **`/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` を削除**。進捗確認はネイティブの **`/workflows` ライブビュー**、意思決定は `decisions.md` を直接 Read で代替する。
- **`longrun-orchestrator` スキルを解体**（命名規則 backlog の -or 終わり廃止分を消化）。生成ロジックは exec コマンド + 同梱テンプレートへ移管。
- builder の agentType をパラメータ化（デフォルト `longrun:longrun-builder` 固定。Codex Builder Phase 2 の受け皿）。
- `plugin.json` / `marketplace.json` plugins[] の version を longrun・lr とも 6.0.0 に同期 bump。

### v6.0 移行ノート

- v6.0 は BREAKING。互換シムや deprecation 期間は設けない。marketplace 配布はバージョン単位キャッシュのため、bump で明示的に伝播する。
- 旧 `/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` は削除された。進捗は `/workflows`、意思決定は `decisions.md` の直接 Read を使う。
- 旧 checkpoint.md 形式の機械可読パースは廃止。checkpoint.md は人間向け監査ログとして書き続けられるが、状態復元には使わない（再開は `resumeFromRunId`）。
- 既存 agent 定義 7 種（`agents/*.md`）は無変更で、`agentType` 参照によりそのまま再利用される。

## v5.3 変更点

- **OpenSpec 縮退モードを一級の動作モードとして追加**。OpenSpec CLI が解決できない / 未 init の環境、またはユーザーが OpenSpec 不要と明示した場合に、spec 類を `_longruns/<run>/` 内に自己完結生成して run を完走させる。詳細は下記「OpenSpec 縮退モード」セクション参照。
- `/longrun:exec`（`/lr:e`）に **Step 0（preflight）** を追加。`scripts/openspec-preflight.sh` で前提条件（CLI 解決可 + init 済み）を判定し、AskUserQuestion で動作モード（通常 / 縮退）を確定する。
- orchestrator の多段フォールバック検出（which → command -v → npx → ~/.volta → `npm install -g openspec`）を廃止し、preflight に一元化。
- `plugins/longrun/tests/` を新設（longrun プラグイン初の bats テストディレクトリ）。
- 通常モード（既存の openspec/ あり repo）の挙動は完全維持（regression なし）。
- `plugin.json` / `marketplace.json`（top-level / plugins[]）の version を 5.3.0 に 3 箇所同期 bump。

## v5.2 変更点

- **MVP モード（旧 `--mode=mvp` フラグ）を `/longrun:plan` に追加**（このフラグは v6.1 で廃止され、独立コマンド `/longrun:mvp` に移行した）。詳細は下記「MVP プランモード」セクション参照。
- フルモードの既存挙動は完全維持（regression なし）。旧 `--mode=mvp`（v6.1 で廃止・移行案内化）フラグなし or `--mode=full` の場合は従来通り Step 1〜8 を実行する。
- `plugins/longrun/templates/plan-template-mvp.md`（軽量テンプレ）を新規追加。
- `/longrun:archive` に `<!-- mvp-mode -->` マーカー判定を追加。MVP モード plan.md は OpenSpec change archive をスキップしてランディレクトリのみアーカイブ。
- `plugin.json` と `longrun-plan` SKILL.md frontmatter の version を 5.2.0 に同期 bump（プラグインキャッシュ無効化）。

## v5.1 変更点

- **Skill 命名統一**: `longrun-planner` → `longrun-plan` にリネーム（命名規則 §参照）。`/longrun:plan` 経由で Agent 誤起動が発生するエラー（`Agent type 'longrun:longrun-planner' not found`）を解消。
- `commands/plan.md` を Skill tool 明示呼び出しに変更（Agent tool 禁止を明記）
- 当時の `longrun-orchestrator` の Build Contract レビュー段階に **バイアス緩和ガード** を追加。reviewer の指摘を仮説として扱い、根拠（spec違反・契約違反・事実誤認）の有無で採否を判定するルールを固定文として埋め込み。Opus 系の self-preference bias と過剰受容バイアスへの対処。（orchestrator は v6.0 で解体され、このガードは exec が生成する Review workflow と Build Contract 承認ゲートの手順に引き継がれた。）

## v5.0 変更点

- **リネーム**: `run` → `longrun` に戻した（一般名詞との衝突回避）
- `_runs/` → `_longruns/`、エージェント/スキル名も `longrun-*` に統一

## v4.0 変更点（旧 longrun → run 時代）

- `instruction.md` → `plan.md`、`progress.md` → `checkpoint.md`
- **Skill/Agent正しい使い分け**: 対話型 = Skill、自律実行 = Agent
- **フェーズ簡素化**: 8フェーズ → 5フェーズ（Plan → Build → Verify → Feedback → Archive）
- **Build Contract**: 実装前に longrun-reviewer がレビュー
- **4軸定量評価**: 機能性/品質/完成度/UX にハードしきい値
- **コンテキストリセット**: フェーズ間で Agent を分離し、checkpoint.md でハンドオフ
- **Context Anxiety 対策**: 完了条件チェックリストで早期終了を防止
- **spec-review-agent を longrun-reviewer に統合**

## コマンド

| コマンド | 短縮 | 説明 |
|---------|------|------|
| `/longrun:plan` | `/lr:p` | plan.md を対話的に作成（フルモード） |
| `/longrun:mvp` | `/lr:m` | 軽量 MVP plan.md を対話的に作成（人間実装向け） |
| `/longrun:exec` | `/lr:e` | Workflow を生成・起動して自律実行を開始 |
| `/longrun:archive` | `/lr:a` | 完了した実行をアーカイブ |
| `/longrun:feedback` | `/lr:f` | フィードバックを分類・実行 |

進捗確認はネイティブの **`/workflows` ライブビュー** を使う（旧 `/longrun:status` `/lr:s` は v6.0 で廃止）。意思決定は `_longruns/<run>/decisions.md` を直接 Read する（旧 `/longrun:decisions` `/lr:d` は v6.0 で廃止）。

## アーキテクチャ

```
/longrun:exec → Workflow スクリプト生成・起動（exec コマンド + templates/workflow/）
  ├── workflow #1 (Review)        ← longrun-reviewer agent で Build Contract レビュー
  │     ↓ メインループに戻り AskUserQuestion（Build Contract 承認ゲート）
  └── workflow #2 (Build→Verify)  ← change ごとに longrun-builder で TDD 実装
        Verify ループ（上限3周 + budget ガード） ← longrun-verifier の 4 軸スコア
        ↓ メインループに戻り AskUserQuestion（Feedback Tier 確認）

Skills (対話的・メインセッションで実行):
  longrun-plan      ← plan.md 作成
  longrun-feedback  ← フィードバック Tier 分類

Agents (自律実行・別コンテキスト。Workflow から agentType で参照):
  longrun-builder           ← TDD 実装（builder-report schema）
  longrun-verifier          ← 4軸定量評価・静的（verifier-score schema）
  longrun-browser-verifier  ← ブラウザ動作検証
  longrun-reviewer          ← Build Contract + Spec Review（reviewer-verdict schema）
```

成果物の StructuredOutput 契約は `schemas/builder-report.schema.json` / `verifier-score.schema.json` / `reviewer-verdict.schema.json` に外部化されており、生成 Workflow スクリプトが `agent(prompt, {schema})` で機構的に強制する。

## 命名規則

Skill と Agent の役割を名前で識別可能にしている。命名違反は Claude が Skill/Agent 種別を誤推論して起動失敗（`Agent type ... not found`）の原因となる。

| 種別 | 命名パターン | 例 |
|------|-------------|----|
| **Skill** | 動詞または名詞単独 | `longrun-plan`, `longrun-mvp-plan`, `longrun-feedback` |
| **Agent** | 役割名（`-er` / `-or` 終わり） | `longrun-builder`, `longrun-reviewer`, `longrun-verifier`, `longrun-browser-verifier` |

新規追加時は本ルールに従うこと。違反すると `/longrun:plan` 系コマンドの起動経路で再び誤起動エラーが発生する。

## MVP プランモード（`/longrun:mvp`）

独立スキル `longrun-mvp-plan` による軽量フロー。**短時間で人間が手で MVP を実装する**ケース向けの汎用機能で、特定のプロジェクトに依存しない（どのプロジェクトからでも呼び出せる）。

### 起動方法

```
/longrun:mvp <ブレインダンプ or テーマ>
/lr:m <ブレインダンプ or テーマ>   # 短縮形（lr プラグインがある場合）
```

### `--mode=mvp` は廃止（deprecation）

v6.1 で `--mode=mvp` フラグは**廃止**された。`/longrun:plan --mode=mvp`（および `/lr:p --mode=mvp`）を実行すると、MVP フローを走らせる代わりに `/longrun:mvp`（短縮 `/lr:m`）への**移行案内を出力して終了**する。`/longrun:plan` は引数フラグなし、または `--mode=full` の場合のみ従来どおりフルモードで起動する。

### フルモードとの違い

| 観点 | フルモード | MVP モード |
|---|---|---|
| Build Contract レビュー | 必須（`longrun-reviewer`） | **スキップ** |
| TDD 強制 | 必須（Red → Green → Refactor） | **スキップ**（人間実装前提） |
| Verifier 自動起動 | 必須（4 軸定量評価） | **スキップ**（人間がその場で確認） |
| リサーチ | 任意 | **並列リサーチ subagent×1**（類似サービス + 実装パターンを 1 レポート 2 セクション） |
| Plan Review | `longrun-reviewer` 単体 | `longrun-mvp-plan-reviewer` + `longrun-mvp-bestpractice-reviewer` を**並列起動** |
| OpenSpec 自動連携 | あり（backlog 照合 / change 自動生成 / archive 時 spec コピー） | **なし**（plan.md 先頭に `<!-- mvp-mode -->` マーカー、`/longrun:archive` は OpenSpec を触らない） |
| テンプレート | `templates/plan-template.md`（フル版） | `templates/plan-template-mvp.md`（軽量版） |

### いつ使うか

- 短時間で人間が手で MVP を実装するケース（数十分〜数時間スケール）
- 自律実行の重装備（Build Contract / TDD / Verifier）が過剰に感じるとき
- まず動くものを作って人間がレビューしたいとき

逆に、自動実装パイプラインに乗せたい / 仕様 driven で長期保守したい場合はフルモードを使うこと。

### アーカイブ

```
/longrun:archive _longruns/<dir>/
```

`plan.md` 先頭の `<!-- mvp-mode -->` マーカーを自動検知し、OpenSpec change の archive をスキップしてランディレクトリのみ `_longruns/_archive/` に移動する。フルモード plan.md（マーカーなし）は従来通り OpenSpec change と一緒に archive される。

## OpenSpec 縮退モード（v5.3 で追加）

OpenSpec CLI を前提にしない（または使わない）環境でも longrun の Review → Build → Verify → Feedback → Archive サイクルを完走させるための一級の動作モード。

### 発動条件

`/lr:e` 起動直後の **Step 0（preflight）** で `scripts/openspec-preflight.sh` を実行し、以下を判定する:

| preflight 出力 | 条件 | Step 0 の提案 |
|----------------|------|---------------|
| `OK`      | CLI 解決可 かつ `openspec/` 存在 | 動作モード確認（通常モードがデフォルト。**縮退選択肢を常時含む** = OpenSpec 不要の明示的 opt-out） |
| `NO_CLI`  | `openspec` が PATH にも npx にも解決できない | 縮退モードで実行 / 中断してセットアップ |
| `NO_INIT` | CLI はあるが `openspec/` が無い | init して通常続行 / 縮退モード / 中断 |

検出は `command -v openspec` **または** `npx --no-install openspec` の OR 条件（確定値とエビデンスは `docs/openspec-cli-verification.md`）。ユーザーが縮退を選ぶと `_longruns/<run>/.degraded-mode` マーカーが作成される。

### 成果物パス（縮退時）

縮退モードでは `openspec/` 配下に一切書き込まず、すべて run ディレクトリ内に自己完結する:

```
_longruns/<run>/
├── .degraded-mode                    # 縮退マーカー（exec Step 0 で作成）
├── plan.md
├── specs/<change-name>/
│   ├── proposal.md                   # openspec new change の代替（自己完結生成）
│   └── tasks.md                      # チェックボックス形式（- [ ] X.Y）で進捗管理
├── verification-guide.md             # specs/ の WHEN/THEN から生成（通常モードと同形式）
└── backlog.md                        # feedback Tier 3 のフォールバック記録先
```

- Archive は OpenSpec change の移動をスキップし、ランディレクトリのみ `_longruns/_archive/` へ移動（spec 類は内包されるため一緒に保全される）。判定は `.degraded-mode` マーカーで行い、MVP マーカー（`<!-- mvp-mode -->`）より優先する。
- feedback の Tier 3（new change）は `openspec/backlog.md` ではなく `_longruns/<run>/backlog.md` に記録される。

### 既知の制限

- ~~`/longrun:status` は縮退モードに非対応~~ → **v6.0.0 で `/longrun:status` 自体が削除されたため本制限は消滅**。縮退 run を含め進捗確認はネイティブの `/workflows` ライブビューで行う（5.3.0 時点では status に縮退分岐を実装していなかったが、change-2 で status を廃止したため投資不要だった判断が結実した）。
- 縮退モードでは `openspec validate` による構造検証が効かない。tasks のチェックボックス形式・spec の WHEN/THEN 形式はテンプレートで担保し、形式逸脱は Verify フェーズのレビューで補完する。
- 縮退 run から OpenSpec あり構成への「昇格」変換は未実装（backlog 残置）。

### 回帰（通常モードへの影響）

既存の openspec/ あり repo で Step 0 が `OK` を返し通常モードを選んだ場合、実行フロー・成果物のパス・形式は 5.2.0 と完全に同一。Step 0 で増えるユーザー対話は動作モード確認の 1 問のみ。`.degraded-mode` マーカーは通常モードでは作成されない。
