# モデルティア → `opts.model` 対応表（Workflow 実行のロール別ティア）

Workflow ツールのスクリプトで `agent(prompt, opts)` に渡す `opts.model` を、**ティア名からエイリアスに解決する唯一の対応表**。あわせて、Agent / Task ツールで直接立てるサブエージェントのティア選択の詳細（経緯・適用範囲・強制層）もここが持つ。常時注入される `rules/subagent-model-selection.md` は「`model` を必ず明示する」と対応表だけの短い版で、判断に迷ったときはこのファイルを読む。

## なぜ 1 箇所に集約するか

モデル ID は世代交代で変わる。スクリプト・SKILL.md・reference に ID を散在させると更新漏れで無言のドリフトが起きる。この表 1 箇所に集約し、新世代対応はこの 1 行変更だけで全経路に伝播させる。

## ティア → `opts.model` に渡す値

`opts.model` は **agent 定義 frontmatter の `model:` 指定より優先される**。渡す値は**エイリアス**（`'haiku'` / `'sonnet'` / `'opus'` / `'fable'`）で、フル ID（`claude-…-2026…`）を直書きしない。エイリアスは世代交代に追従するため、この表の値は通常変更不要。

| ティア | 用途の目安（ロール） | `opts.model` に渡す値 |
|--------|---------------------|----------------------|
| `haiku`   | 定型的な検証・要約・ファイル探索など、結果がモデルの賢さでほぼ変わらない仕事 | `'haiku'` |
| `sonnet`  | リサーチ・ブラウザ操作・中規模実装。**builder の出発点** | `'sonnet'` |
| `fable`   | 判断が一点に集中する場所——checkpoint の再ランク・verify の最終判定・Build Contract レビュー・アーキテクチャ判断 | `'fable'` |
| `inherit` | 分類に迷うタスクの保守的デフォルト | （**渡さない**。下記） |

## develop role の provider-neutral profile

`spec-write`、`spec-review`、`implement`、`impl-review`、`review`、`decider`、`explore`、`summarize` の各 role は、`references/codex-role-profiles.json`（または明示した version 1 profile-file）の同名 entry にある executor/account/model/effort へ解決する。歴史的なファイル名は維持するが、version 1 table は Claude と Codex を同じ profile 内で扱う provider-neutral な正本である。本表へ個別 Codex model ID を重複記載せず、Claude の tier alias を Codex model へ暗黙変換しない。

Claude entry は account=`current`、model=`haiku|sonnet|opus|fable`、非空の effort を要求する。`fable` は `decider` role だけに許可する。別 Claude account の実行はまだ対応せず、account 欄自体は allocator の共通出力として保持する。Codex entry は登録済み account と非空の model/effort を要求し、正式な model/effort の対応可否は worker 起動時にも検証する。

重めの実装・レビューを中位ティアで回すときは `'opus'` を渡す（`rules/subagent-model-selection.md` の対応表と同じ）。

## `inherit` の意味

`inherit` は **`opts.model` キー自体を省略する**ことを指す（値として `'inherit'` を渡すのではない）。キーを省略すると Workflow ツールの既定の解決順（agent 定義 frontmatter `model:` → 親セッションのモデル）がそのまま働く。何らかの値を渡すと agent frontmatter の指定を意図せず上書きするので、`inherit` ティアでは必ずキーを省略する。

## 残量モードによる降格（`fable` のみ対象）

残量モード `FABLE_BUDGET_MODE` の定義と導出の正本は `plugins/dev-workflow/skills/develop/references/decision-criteria.md`。ワークフロー側の適用は次の 2 行に閉じる:

- `reserve` の**自動実行**（unmanned / cron / loop 経由）では、`fable` ティアを `'opus'` として渡す（interactive では降格しない）
- `exhausted` では **全経路**で `fable` ティアを `'opus'` として渡す（枠が実際に無いため）

`haiku` / `sonnet` / `inherit` は残量モードの影響を受けない。降格したときはスクリプトの return 値や PR コメントに 1 行残す（記録形式の正本は pr-review-gate の「決める役モデル: opus（fable レート制限のためフォールバック。subagent_type は dev-workflow:decider のまま）」）。

## 役ごとの effort（推論の深さ）

effort は親セッションの値を継ぐだけだと、答えの型が決まった工程も最終検証と同じ深さで考えて消費する。dev-workflow の 4 つの agent 定義は、frontmatter の `effort:` で既定を持つ。初期値は次のとおり（`/cost` の前後記録を見て調整する。戻し方は frontmatter 1 行の修正）。

| agent 定義 | `effort` | 理由 |
|-----------|----------|------|
| `worker` | `medium` | 答えの型が決まった仕様化・実装 |
| `gate-runner` | `medium` | 決まった手順の実行 |
| `reviewer` | `high` | 判断が集中する差分レビュー |
| `decider` | `high` | 修正方針・最終 verify・マージ可否 |

**上書き。** Agent ツールの `effort` 引数（Claude Code 2.1.292）で呼び出し単位に上書きできる（出典は issue #711。公式文書には記載なし）。`model` と違い、呼び出しごとの明示は義務ではない。未指定でも frontmatter の値が効くので、最上位枠を無言で消費する事故は起きない。

**優先順位。** 公式文書（https://code.claude.com/docs/en/sub-agents ）が定める範囲は、frontmatter の `effort` はセッションの effort を上書きするが、環境変数 `CLAUDE_CODE_EFFORT_LEVEL` は上書きしない、まで。環境変数が設定された環境では、4 役の frontmatter の値は効かず環境変数の値が全役に効く（測定前に `echo $CLAUDE_CODE_EFFORT_LEVEL` で確認する）。Agent の `effort` 引数と frontmatter・環境変数の優先関係は文書に記載なし。

**profile の effort との関係。** `references/codex-role-profiles.json` の effort は監査値で、Agent の引数には変換しない。Claude role の値は上の表と同じ（W = medium、レビュー・決める役 = high）。

**検査。** `plugins/dev-workflow/tests/agent-effort.bats` が、4 定義の frontmatter の `effort:` 行数と値を検査する。

## Agent / Task ツールで直接立てるサブエージェント

### なぜ `model` の明示が必須か

モデル未指定のサブエージェントは**親セッションのモデルを継承する**ため、親が最上位モデルのセッションでは調査 1 回ごとに最上位枠を無言で消費する。2026-08 に実際に発生した（pr-review-gate に記録した 2026-08-07 のレビュー自動発火事故と同じメカニズム）。

`subagent_type: "fork"` は仕様として常に親モデルで動き、`model` 指定は無視される。fork を使ってよいのは**役割が最上位ティア相当の仕事のときだけ**（下の枠残量確認も同様に適用）。それ以外は fork ではなく `model` 明示の通常サブエージェントで立てる。

### 原則: モデル名ではなく役割で選ぶ

モデルが世代交代しても変わらない基準。メインセッションの最上位モデルはオーケストレーション・アドバイス・最終判断に温存し、サブエージェントは役割でティアを決める。

- **最安ティア** — 結果がモデルの賢さでほぼ変わらない仕事: ファイル探索・grep 的な調査・機械的編集・fan-out ワーカー・要約
- **中位ティア** — 通常の実装・複数ファイルにまたがる調査・通常のコードレビュー。**迷ったらここ**
- **最上位ティア** — 判断が一点に集中する仕事だけ（最終 verify・マージ可否・アーキテクチャ判断）。手を動かす仕事（実装・修正ループ）は聖域パスでも中位ティア止まり。枠残量（`FABLE_BUDGET_MODE`。正本は dev-workflow の `scripts/session-tripwires.sh`、未設定時は `conserve` 扱い）を確認してから使う

**最上位ティアは決める役の種別（`dev-workflow:decider`）でだけ spawn する**（`general-purpose` / `Explore` / `Plan` / 他種別に `model: fable` を付けない）。強制層は `plugins/dev-workflow/scripts/agent-model-guard.sh`（`Agent` の PreToolUse。全解除は `DEV_WORKFLOW_MODEL_GUARD=off`）。

### 対応表の保守

`rules/subagent-model-selection.md` の対応表（2026-08 時点）について: `model` パラメータはエイリアス指定でバージョン非依存のため、モデルが更新されたらこの表だけ直せばよい。原則の節は書き換え不要。

### 適用範囲

`model` の明示義務は**すべての直接の Agent / Task 呼び出しに共通**で、ワークフロー経由でも免除されない。ワークフローを持つスキルは「どのティアを選ぶか」の決め方の正本を持つだけ:

- ワークフロー実行のロール別ティア: このファイルの上半分
- レビュー系の既定ティアと最上位ティアへの昇格条件: `dev-workflow:pr-review-gate`
- 実装役（W）の事前分類: `plugins/dev-workflow/skills/develop/references/pre-classification.md`

それらの網に無い**アドホックに立てるサブエージェント**（Explore / general-purpose 等）は上の原則で直接決める。
