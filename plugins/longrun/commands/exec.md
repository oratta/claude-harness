---
name: exec
description: plan.mdに基づいて自律実行を開始する
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

longrun-orchestrator の手順をメインセッションでインライン実行して、自律実行を開始してください。

**重要: Skill tool / Agent tool は使わないこと。** longrun-orchestrator の SKILL.md には `disable-model-invocation: true` が指定されており、Skill tool 経由で呼ぶと `cannot be used with Skill tool due to disable-model-invocation` エラーで失敗する。これは設計上の意図で、orchestrator はメインセッションでインライン実行されないとサブエージェント（longrun-reviewer / longrun-builder / longrun-verifier）を Agent ツールで生成できないため（サブエージェントはサブエージェントを生成できないという Claude Code の仕様）。Agent tool で起動するのも同じ理由で禁止。

## 手順

### Step 1: SKILL.md を読み込む

orchestrator の本体は以下にある:
```
${CLAUDE_PLUGIN_ROOT}/skills/longrun-orchestrator/SKILL.md
```

`CLAUDE_PLUGIN_ROOT` が解決できない環境では bash で探索:
```bash
for dir in \
  ~/.claude/plugins/marketplaces/*/plugins/longrun/skills/longrun-orchestrator \
  ~/.claude/plugins/installed/*/longrun/skills/longrun-orchestrator; do
  [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
done
```

特定した絶対パスを Read tool で読み込む。

### Step 0: OpenSpec 前提条件チェック（preflight）と動作モード確定

<GATE>
Setup フェーズ本体に入る前に、必ず preflight スクリプトを実行して結果を読むこと。
コマンドを実行せずに「OpenSpec がインストールされていない」と推測判断してはならない。
</GATE>

まずランディレクトリを Step 2 の規則で特定し（`{longrun-dir}`）、その後 preflight を実行する。

1. **preflight スクリプトを実行する**:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/openspec-preflight.sh"
   ```
   `CLAUDE_PLUGIN_ROOT` が解決できない場合は exec.md を見つけたのと同じ marketplace パスから
   `scripts/openspec-preflight.sh` を探索して実行する。標準出力は `OK` / `NO_CLI` / `NO_INIT`
   のいずれか。**この出力（実行したコマンドと結果）を checkpoint.md の「ツール検証結果」に記録する。**

2. **結果に応じて AskUserQuestion で動作モードを確定する**:

   - **`OK`（CLI 解決可・openspec init 済み）** → 動作モード確認 AskUserQuestion を表示する。
     **preflight が OK でも縮退選択肢を常時含める**（「OpenSpec 不要」の明示的 opt-out 手段。
     専用の引数は追加しない）:
     - 選択肢A: **通常モード（OpenSpec あり）** ← デフォルト
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
   - **通常モードを選択** → 何も特別なことはしない。Setup フェーズを従来どおり開始する
     （`{longrun-dir}/.degraded-mode` マーカーは作成しない）。
   - **縮退モードを選択** → ランディレクトリに縮退マーカーを作成する:
     ```bash
     touch "{longrun-dir}/.degraded-mode"
     ```
     その旨と「OpenSpec CLI を一切呼ばない縮退モードで進める」ことを checkpoint.md に記録し、
     縮退モードで Setup フェーズを開始する。
   - **`NO_INIT` で「init して通常続行」を選択** → init / schema fork を実行してから通常モードへ。
   - **中断を選択** → run を開始せず、以下のセットアップ案内を表示して exec を終了する。

   セットアップ案内文言の確定版は `${CLAUDE_PLUGIN_ROOT}/docs/openspec-cli-verification.md` §5
   を参照（`NO_CLI` 用 / `NO_INIT` 用の 2 種）。

**preflight の判定基準・検出コマンド系列・導入案内の一次ソースは
`${CLAUDE_PLUGIN_ROOT}/docs/openspec-cli-verification.md` である。** 推測でコマンドを書かない。

### Step 2: 実行前チェック

1. 実行対象のランディレクトリを特定する:
   - 引数でディレクトリパスが渡された場合: そのディレクトリを使用
   - 引数なしの場合: `_longruns/` 内の最新サブディレクトリ（`ls -1d _longruns/20*/ | sort | tail -1`）を使用
   - `plan.md` が見つからない場合: `/longrun:plan` コマンドで先に作成するよう案内
2. ランディレクトリ内に既に `checkpoint.md` がある場合:
   - 続行するか新規開始するか確認
3. **Step 0 で確定した動作モード（通常 / 縮退）を Setup フェーズに引き継ぐ**。縮退モードの場合は
   `{longrun-dir}/.degraded-mode` マーカーが存在し、orchestrator はこれを見て OpenSpec CLI を
   呼ばない縮退分岐に入る。

### Step 3: インライン実行

ランディレクトリのパスを引数として、SKILL.md の手順をメインセッションでインライン実行する。
Setup → Build Contract → Build → Verify → Feedback → Archive の順で自律的に実装を進める。

引数: `$ARGUMENTS`

## 実行中の進捗確認

`/longrun:status` コマンドで現在の状態を確認できます。
各changeの進捗は `openspec list` で確認できます。
