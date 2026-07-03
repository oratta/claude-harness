---
name: exec
description: plan.md を読んで Workflow スクリプトを生成・起動し、自律実行する（v6.0.0）
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Workflow, AskUserQuestion
---

plan.md に基づいて Workflow スクリプトを生成し、Workflow ツールで起動して自律実行を駆動する。

v6.0.0 BREAKING: 旧 `longrun-orchestrator` SKILL.md のインライン展開・Agent 手動制御・
checkpoint.md の散文パースは廃止された。オーケストレーションは Claude Code の **Workflow ツール**
（`agent()` / `pipeline()` / `parallel()` / `opts.schema` / `opts.agentType` / `resumeFromRunId` /
`budget`）が担う。Review → Build → Verify の各フェーズはコード（生成 Workflow スクリプト）と
JSON Schema（StructuredOutput）で機構的に表現する。

**Workflow ツールのシグネチャ・制約の一次ソースは
`${CLAUDE_PLUGIN_ROOT}/references/workflow-tool-reference.md`（実機検証済み・配布物内同梱）。
記憶・推測で API を書かない。記載のない挙動が必要になったら追加検証して reference を更新してから使う。**

## Workflow 起動の opt-in（追加確認不要）

`/longrun:exec` および `/lr:e` は **ユーザーが起動した slash command** である。Workflow ツールの
「ユーザーが起動した slash command の指示で呼ぶ」要件に該当するため、Workflow の起動について
**追加の確認ダイアログは不要**。Step 0 の権限モード検査と承認ゲート（Build Contract / Feedback
Tier）以外で、Workflow 起動そのものをユーザーに確認し直す必要はない。

---

## Step 0: 権限モード検査 + OpenSpec 前提条件チェック（preflight）

### 0a. 権限モード検査

<GATE>
Workflow を起動する前に現在の権限モードを検査すること。`acceptEdits` 未満（`default` 等）の場合、
Workflow が生成するサブエージェントが各 Edit/Write/Bash でいちいち承認を求めて自律実行が止まる。
未満なら起動前にユーザーへ切り替えを案内すること。
</GATE>

現在の権限モードを確認する。`acceptEdits` 以上（`acceptEdits` / `bypassPermissions` 等の
編集自動承認モード）であれば検査を通過し、追加案内なしに後続ステップへ進む。`acceptEdits` 未満
（`default` / `plan` 等）であれば、以下を案内してから続行可否を確認する:

```
現在の権限モードは <mode> です。自律実行では多数の Edit/Write/Bash が走るため、
Shift+Tab で「acceptEdits」以上に切り替えてから再実行することを推奨します。
このまま続行すると各操作で承認ダイアログが出て実行が頻繁に停止します。
```

### 0b. OpenSpec 前提条件チェック（preflight）と動作モード確定

<GATE>
preflight スクリプトを実行して結果を読むこと。コマンドを実行せずに「OpenSpec が無い」と
推測判断してはならない。
</GATE>

まず Step 1 の規則でランディレクトリ `{longrun-dir}` を特定し、その後 preflight を実行する。

1. **preflight スクリプトを実行する**:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/openspec-preflight.sh"
   ```
   `CLAUDE_PLUGIN_ROOT` が解決できない場合は exec.md を見つけたのと同じ marketplace パスから
   `scripts/openspec-preflight.sh` を探索して実行する。標準出力は `OK` / `NO_CLI` / `NO_INIT`
   のいずれか。**この出力（実行したコマンドと結果）を checkpoint.md の「ツール検証結果」に
   人間向け監査ログとして記録する。**

2. **結果に応じて AskUserQuestion で動作モードを確定する**:

   - **`OK`（CLI 解決可・openspec init 済み）** → 動作モード確認 AskUserQuestion を表示する。
     preflight が OK でも縮退選択肢を常時含める（「OpenSpec 不要」の明示的 opt-out 手段）:
     - 選択肢A: **通常モード（OpenSpec あり）** ← デフォルト（Enter 即決）
     - 選択肢B: **縮退モード（OpenSpec を使わない）**

   - **`NO_CLI`（CLI が解決できない）** → 縮退モード提案 AskUserQuestion を表示する:
     - 選択肢A: **縮退モードで実行する**（spec 類を `_longruns/<run>/` 内に自己完結生成）
     - 選択肢B: **中断して OpenSpec をセットアップする**（下記セットアップ案内を出して exec 終了）

   - **`NO_INIT`（CLI はあるが openspec/ が無い）** → 提案 AskUserQuestion を表示する:
     - 選択肢A: **openspec init して通常モードで続行する**（`openspec init --tools claude` +
       `openspec schema fork spec-driven longrun-tdd` を実行してから通常モードへ）
     - 選択肢B: **縮退モードで実行する**
     - 選択肢C: **中断する**（セットアップ案内を出して exec 終了）

3. **モードの確定処理**:
   - **通常モードを選択** → 何も特別なことはしない（`{longrun-dir}/.degraded-mode` マーカーは作成しない）。
   - **縮退モードを選択** → ランディレクトリに縮退マーカーを作成する:
     ```bash
     touch "{longrun-dir}/.degraded-mode"
     ```
     その旨を checkpoint.md に記録し、縮退モードで進める。縮退モードでは change ごとの spec 類
     （proposal.md / tasks.md / verification-guide.md 相当）を `{longrun-dir}/specs/<change>/` に
     自己完結生成し、`openspec/` には一切書き込まない。
   - **`NO_INIT` で「init して通常続行」を選択** → init / schema fork を実行してから通常モードへ。
   - **中断を選択** → run を開始せず、以下のセットアップ案内を表示して exec を終了する。

   セットアップ案内文言の確定版は `${CLAUDE_PLUGIN_ROOT}/docs/openspec-cli-verification.md` §5
   を参照（`NO_CLI` 用 / `NO_INIT` 用の 2 種）。

**preflight の判定基準・検出コマンド系列・導入案内の一次ソースは
`${CLAUDE_PLUGIN_ROOT}/docs/openspec-cli-verification.md` である。** 推測でコマンドを書かない。

---

## Step 1: ランディレクトリの特定と plan.md 読込

1. 実行対象のランディレクトリ `{longrun-dir}` を特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数がファイルパスの場合: その親ディレクトリを使用
   - 引数なしの場合: `_longruns/` 内の最新サブディレクトリ（`ls -1d _longruns/20*/ | sort | tail -1`）を使用
   - `{longrun-dir}/plan.md` が見つからない場合: `/longrun:plan` で先に作成するよう案内して終了
2. `{longrun-dir}/plan.md` を Read で読み込み、**Changes 分解セクション**を解析して以下を抽出する:
   - change 一覧（名前 / 対象リポジトリ / 依存関係）
   - 依存関係に基づく直列／並列の構造
   - （存在すれば）モデル割り当て表 — 本 change のスコープ外だが、生成スクリプトが `opts.model` を
     受け取れる構造を妨げない（change-4 で消費する。表が無ければ全 inherit）
3. ランディレクトリに既存の `checkpoint.md` / runId 記録（後述 Step 4 の `workflow-runs.jsonl`）が
   ある場合は、**Step 5 の再開フロー**に分岐するか新規開始するかを確認する。

---

## Step 2: Workflow スクリプトの生成

生成ロジックは exec コマンドと同梱テンプレートに集約されている（旧 orchestrator スキルは解体済み）。

テンプレート:
- `${CLAUDE_PLUGIN_ROOT}/templates/workflow/review.workflow.js` — Review フェーズ単体
- `${CLAUDE_PLUGIN_ROOT}/templates/workflow/build-verify.workflow.js` — Build → Verify フェーズ

schema（StructuredOutput 契約。`opts.schema` でインライン埋め込む）:
- `${CLAUDE_PLUGIN_ROOT}/schemas/builder-report.schema.json`
- `${CLAUDE_PLUGIN_ROOT}/schemas/verifier-score.schema.json`
- `${CLAUDE_PLUGIN_ROOT}/schemas/reviewer-verdict.schema.json`

各テンプレートには `__NAME__` 形式の埋め込みポイントがある。**JS テンプレートリテラルの補間
`${...}` とは別構文**（衝突回避のため）。レンダリングは同梱の参照実装を使う:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/render-workflow.mjs" <template> <params.json> > {longrun-dir}/<generated>.js
```

`params.json` に渡す値:

| 埋め込みポイント | 値 |
|---|---|
| `PLAN_PATH` | `{longrun-dir}/plan.md` の絶対パス |
| `PROJECT_ROOT` | プロジェクトルート（cwd） |
| `RUN_DIR` | `{longrun-dir}` の絶対パス |
| `CHANGES_JSON` | Changes 分解を `[{name, worktree, dependsOn:[...]}]` にした JSON 配列を `JSON.stringify` した**オブジェクトリテラル文字列** |
| `BUILDER_AGENT_TYPE` | 既定 `longrun:longrun-builder`（**D6: パラメータ化**。本 change ではデフォルト固定。ユーザー上書き手段は提供しない。Codex Builder Phase 2 の受け皿） |
| `VERIFIER_AGENT_TYPE` | 静的 verifier（quality/completeness 担当）。既定 `longrun:longrun-verifier` |
| `BROWSER_VERIFIER_AGENT_TYPE` | ブラウザ verifier（functionality/ux 担当）。既定 `longrun:longrun-browser-verifier`（change-2。Verify ループが静的 + ブラウザの 2 verifier を 2+2 軸で呼び分ける。`*_MODEL` でない通常パラメータのため params に**常時供給**する） |
| `REVIEWER_AGENT_TYPE` | 既定 `longrun:longrun-reviewer` |
| `BUILDER_SCHEMA` / `VERIFIER_SCHEMA` / `REVIEWER_SCHEMA` | 対応する `*.schema.json` を `JSON.stringify(JSON.parse(...))` した**オブジェクトリテラル文字列**（スクリプトに JS オブジェクトとして埋め込まれ、`opts.schema` で StructuredOutput を強制する。プロンプトへのインライン重複はしない）。`VERIFIER_SCHEMA`（`verifier-score.schema.json`）は静的・ブラウザ両 verifier で共用し、各 verifier が担当 2 軸 + verdict を部分返却する（change-2 D2 候補1） |
| `BUILDER_MODEL` / `VERIFIER_MODEL` / `BROWSER_VERIFIER_MODEL` / `REVIEWER_MODEL` | 各ロールの `opts.model` 値（**エイリアス文字列リテラル** `'sonnet'` 等、または `null`）。下記「モデル割り当ての消費」で解決する。`null`（= inherit）のときテンプレートは条件付きスプレッドで `model` キー自体を出力しない。**未指定なら render が `null` を既定値にする**（旧 plan.md フォールバック。`BROWSER_VERIFIER_MODEL` も同規則） |

### モデル割り当ての消費（change-4）

plan.md の「モデル割り当て」表を読み、各 change × ロールの `opts.model` 値を解決する。**この処理は
専用スクリプトに集約する**（モデル ID を exec.md・テンプレートに散在させない）:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-model-allocation.mjs" \
  {longrun-dir}/plan.md "${CLAUDE_PLUGIN_ROOT}/references/model-tiers.md"
```

- 出力 JSON は `{ hasSection, allocations:[{change, role, tier, model}], warnings:[...] }`。
  `model` はエイリアス文字列（`'haiku'`/`'sonnet'`）または `null`（inherit = `opts.model` を渡さない）。
- ティア → エイリアス値の解決元は **`references/model-tiers.md` の 1 箇所のみ**（D3）。exec はティア名と
  リファレンスだけを扱い、モデル ID を直書きしない。
- **`上書き` 欄が非空ならティア欄より優先**する（D4。スクリプトが処理済み）。
- **fail-soft**: 未知のティア値・パース不能行は inherit 扱い + `warnings` に列挙される（D5）。**exec は
  `warnings` をユーザーに表示するだけで、中断も AskUserQuestion もしない**。
- 「モデル割り当て」セクションが無い旧 plan.md は `hasSection:false` で `allocations` が空 → 全ロール
  inherit（`MODEL` パラメータ未指定 → render が `null` を既定値にする）。エラーにしない。

解決した `model` 値を、対応する change のロール（builder/verifier/reviewer）の `BUILDER_MODEL` /
`VERIFIER_MODEL` / `REVIEWER_MODEL` 埋め込みポイントに、**JS リテラルとして**渡す
（文字列なら `'sonnet'` のようにクォート込み、inherit なら `null`）。

<GATE>
具体的なモデル ID 文字列を exec.md・workflow テンプレート・plan.md に直書きしてはならない。
ティア → 値の解決は `references/model-tiers.md` を唯一のソースとする（config.yaml rule / D3）。
</GATE>

<GATE>
schema は外部ファイル（`plugins/longrun/schemas/*.schema.json`）を唯一のソースとし、スクリプトや
プロンプトにインライン重複コピーしてはならない。テンプレートは schema をインライン**埋め込む**が、
その元は常に外部ファイルである。
</GATE>

生成後、`node --check {longrun-dir}/<generated>.js` で構文検証する（受け入れ条件 8a）。

---

## Step 3: Review workflow の起動 → Build Contract 承認ゲート（メインループに戻る）

<GATE>
Workflow 内の agent から AskUserQuestion は使えない（サブエージェント全般の制約）。承認ゲートは
**workflow を分割してメインループに戻り AskUserQuestion → 次の workflow を起動**する（D5）。
</GATE>

1. `review.workflow.js` を Workflow ツールで起動する:
   ```
   Workflow({ scriptPath: "{longrun-dir}/review.workflow.js", args: { timestamp: "<ISO8601 現在時刻>" } })
   ```
   - **`args.timestamp` は exec（メインループ）側で現在時刻を文字列化して注入する**。Workflow
     スクリプト内では `Date.now()` / 引数なし `new Date()` が throw するため、時刻は必ず args 経由。
   - 起動応答から **runId を取得**し、Step 4 の手順で記録する。
2. 完了通知の `<result>` に reviewer 判定 JSON（`reviewer-verdict` schema）が入る。
   `verdict.status` を見て **AskUserQuestion で Build Contract 承認**を取得する:
   - `APPROVE` → ユーザーに承認可否を提示（承認ゲート）→ 承認されたら Step 4 の Build workflow へ
   - `REQUEST_CHANGES` → findings を提示し、plan.md を修正して再度 Review workflow を起動するか、
     残課題を明記して進むかを確認（バイアス緩和: 嗜好レベルの指摘は plan の意図を優先し
     decisions.md に反論を記録）

---

## Step 4: Build → Verify workflow の起動と runId 記録 → Feedback Tier 確認（メインループに戻る）

1. **runId 記録（再開の一次手段。D4 / 受け入れ条件 10・18）**:
   workflow を起動したら、起動応答の runId を**直後に**ランディレクトリへ追記式で記録する:
   ```bash
   printf '%s\n' '{"phase":"<Review|BuildVerify>","runId":"<runId>","scriptPath":"<path>","timestamp":"<ISO8601>"}' \
     >> "{longrun-dir}/workflow-runs.jsonl"
   ```
   - フェーズごとに 1 行追記する（Review / BuildVerify それぞれ）。これが `resumeFromRunId` の参照元。
   - **runId 記録は workflow 起動直後の最初の処理にする**（記録前クラッシュで resume 不能になるのを防ぐ）。
2. `build-verify.workflow.js` を起動する:
   ```
   Workflow({ scriptPath: "{longrun-dir}/build-verify.workflow.js", args: { timestamp: "<ISO8601>" } })
   ```
   - Build フェーズ: change ごとに `agentType: 'longrun:longrun-builder'` で TDD 実装。builder は
     完了レポートを `builder-report` schema で返す（散文 STATUS パースは廃止）。
   - Verify フェーズ: **while + 上限 3 周 + `budget.total && budget.remaining()` ガード**で、各周に
     静的 verifier（`longrun:longrun-verifier`、quality/completeness の 2 軸）と ブラウザ verifier
     （`longrun:longrun-browser-verifier`、functionality/ux の 2 軸）を呼び、両者の verdict の**論理積**を
     総合 verdict とする（`verifier-score` schema。両 verifier が担当 2 軸 + verdict を部分返却）。FAIL 時は
     合算 findings を builder へ渡して修正依頼する。上限到達 / budget 枯渇時は状態を構造化して返し停止する
     （`stopReason: MAX_ROUNDS_REACHED | BUDGET_EXHAUSTED | PASS`）。
3. 完了通知の `<result>` を見て **AskUserQuestion で Feedback Tier 確認**を取得する（D5）。フィードバック
   分類とループは `/longrun:feedback`（`longrun-feedback` スキル）に委譲する。

---

## Step 5: 中断 → 再開（resumeFromRunId 一次手段）

<GATE>
再開は `resumeFromRunId` を一次手段とする（D4）。checkpoint.md を grep/sed でパースして状態を
復元する制御フローを実装してはならない。checkpoint.md は人間向け監査ログであり、機械可読契約から
除外する。
</GATE>

1. `{longrun-dir}/workflow-runs.jsonl` から再開対象フェーズの `runId` と `scriptPath` を読む。
2. 同一 scriptPath + 同一 args で `resumeFromRunId` を指定して再起動する:
   ```
   Workflow({ scriptPath: "<記録済み scriptPath>", resumeFromRunId: "<記録済み runId>", args: { timestamp: "<元と同一の値>" } })
   ```
   - スクリプト・args が同一なら完了済みの agent() は**キャッシュヒット**して再実行されない（reference §5）。
     これにより完了済み change の builder agent が再実行されない（受け入れ条件 10）。
   - **制約: same-session only**（reference §5）。セッションをまたぐ resume は不可。セッションが
     変わった場合は checkpoint.md（人間向け）の進行記録を見て、未完了フェーズから新規 runId で起動し直す。
3. runId 記録が無い（記録前にクラッシュした等）場合は、新規実行するか `/workflows` ライブビューで
   手動確認するかをユーザーに案内する。

---

## checkpoint.md（人間向け監査ログ）

checkpoint.md は **人間が読む監査ログ**として各フェーズの進捗・ツール検証結果・意思決定の要約を
書き続ける。ただし exec / 生成 Workflow スクリプトの**いかなるコードパスも checkpoint.md を
grep/sed/正規表現でパースして制御フローを決めてはならない**（D4 / S20）。状態の真のソースは
Workflow ツール（runId + キャッシュ）と OpenSpec の tasks.md（縮退時は `{longrun-dir}/specs/` の
tasks.md）である。decisions.md は現行どおり維持する。

進捗の確認は **ネイティブの `/workflows` ライブビュー** で行う（旧 `/longrun:status` は v6.0.0 で
廃止された）。意思決定は `{longrun-dir}/decisions.md` を直接 Read する。

---

## 付録: 縮退モードの spec 類自己完結生成（change-1 から移管）

`{longrun-dir}/.degraded-mode` マーカーがある場合、OpenSpec CLI（`openspec new change` /
`openspec validate` / apply 等）を**一切呼び出さず**、`openspec/` 配下にも**一切書き込まない**。
change ごとの spec 類を `{longrun-dir}/specs/<change-name>/` 配下に自己完結生成する。これは
旧 orchestrator SKILL.md の「縮退モード分岐」を exec 側へ移管したものである（orchestrator スキルは
v6.0.0 で解体された）。

<GATE>
縮退モードで `openspec` コマンドを実行すること、および `openspec/` ディレクトリに書き込むことは
禁止。生成物は全て `{longrun-dir}/` 配下に収める。
</GATE>

1. **change ごとに spec 類を自己完結生成**（`openspec new change` の代替）。plan.md の Changes 分解
   から change 名を取得し、各 change について以下を生成する:
   - `{longrun-dir}/specs/<change-name>/proposal.md` — capability スコープ（Why / What Changes /
     Capabilities）。longrun-tdd の propose テンプレート相当の構成
   - `{longrun-dir}/specs/<change-name>/tasks.md` — **チェックボックス形式**のタスクリスト
     （`## N. <グループ>` 見出し + `- [ ] N.M <内容>` 行）。Build フェーズ（生成 Workflow スクリプトの
     builder）の進捗トラッキングはこの tasks.md のチェックボックスで行う
   - spec の Scenario（WHEN/THEN）は proposal.md 内または `{longrun-dir}/specs/<change-name>/spec.md`
     に WHEN/THEN 形式で記述する
   生成テンプレートの一次ソースは `${CLAUDE_PLUGIN_ROOT}/templates/longrun-tdd-schema/{propose.md,apply.md}`
   （形式の参照）。`openspec validate` は使えないため、形式逸脱は Verify フェーズのレビューで補完する。
2. **verification-guide.md 生成（縮退）**: 抽出元を `{longrun-dir}/specs/` 配下の WHEN/THEN とする
   （出力先・形式は通常モードと同一）。
3. Build → Verify workflow は通常モードと同じく `longrun:longrun-builder` / `longrun:longrun-verifier`
   を agentType で再利用する。縮退モードでは tasks.md のチェックボックスが進捗ソースになる。

Archive（`/longrun:archive`）は `.degraded-mode` マーカーを見て OpenSpec change の移動をスキップし、
ランディレクトリのみアーカイブする（spec 類は `{longrun-dir}/specs/` に内包されるため一緒に保全される）。

引数: `$ARGUMENTS`
