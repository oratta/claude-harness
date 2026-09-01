# モデルティア → `opts.model` 対応表（Workflow 実行のロール別ティア）

Workflow ツールのスクリプトで `agent(prompt, opts)` に渡す `opts.model` を、**ティア名からエイリアスに解決する唯一の対応表**。`rules/subagent-model-selection.md`（Agent ツールで立てるサブエージェントのティアの原則）と対になる、ワークフロー側の正本。解散した自律実行プラグインの対応表から、ロール別ティア・エイリアス規則・残量モードによる降格だけを引き継いだ（#205）。

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

`haiku` / `sonnet` / `inherit` は残量モードの影響を受けない。降格したときはスクリプトの return 値や PR コメントに 1 行残す（記録形式の正本は pr-review-gate の「修正実装モデル: opus（fable レート制限のためフォールバック）」）。
