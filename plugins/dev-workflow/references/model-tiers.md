# モデルティア → `opts.model` 対応表（Workflow 実行のロール別ティア）

Workflow ツールのスクリプトで `agent(prompt, opts)` に渡す `opts.model` を、**ティア名からエイリアスに解決する唯一の対応表**。あわせて、Agent / Task ツールで直接立てるサブエージェントのティア選択の詳細（経緯・適用範囲・強制層）もここが持つ。常時注入される `rules/subagent-model-selection.md` は「`model` を必ず明示する」と対応表だけの短い版で、判断に迷ったときはこのファイルを読む。解散した自律実行プラグインの対応表から、ロール別ティア・エイリアス規則・残量モードによる降格だけを引き継いだ（#205）。

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

重めの実装・レビューを中位ティアで回すときは `'opus'` を渡す（`rules/subagent-model-selection.md` の対応表と同じ）。

## `inherit` の意味

`inherit` は **`opts.model` キー自体を省略する**ことを指す（値として `'inherit'` を渡すのではない）。キーを省略すると Workflow ツールの既定の解決順（agent 定義 frontmatter `model:` → 親セッションのモデル）がそのまま働く。何らかの値を渡すと agent frontmatter の指定を意図せず上書きするので、`inherit` ティアでは必ずキーを省略する。

## 残量モードによる降格（`fable` のみ対象）

残量モード `FABLE_BUDGET_MODE` の定義と導出の正本は `plugins/dev-workflow/skills/develop/references/decision-criteria.md`。ワークフロー側の適用は次の 2 行に閉じる:

- `reserve` の**自動実行**（unmanned / cron / loop 経由）では、`fable` ティアを `'opus'` として渡す（interactive では降格しない）
- `exhausted` では **全経路**で `fable` ティアを `'opus'` として渡す（枠が実際に無いため）

`haiku` / `sonnet` / `inherit` は残量モードの影響を受けない。降格したときはスクリプトの return 値や PR コメントに 1 行残す（記録形式の正本は pr-review-gate の「決める役モデル: opus（fable レート制限のためフォールバック。subagent_type は dev-workflow:decider のまま）」）。

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

### 適用範囲

`model` の明示義務は**すべての直接の Agent / Task 呼び出しに共通**で、ワークフロー経由でも免除されない。ワークフローを持つスキルは「どのティアを選ぶか」の決め方の正本を持つだけ:

- ワークフロー実行のロール別ティア: このファイルの上半分
- レビュー系の既定ティアと最上位ティアへの昇格条件: `dev-workflow:pr-review-gate`
- 実装役（W）の事前分類: `plugins/dev-workflow/skills/develop/references/roles/worker.md`

それらの網に無い**アドホックに立てるサブエージェント**（Explore / general-purpose 等）は上の原則で直接決める。
