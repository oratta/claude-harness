# サブエージェントのモデル選択

サブエージェント（Agent / Task ツール）を立てるときは `model` を**必ず明示**する。未指定は親セッションのモデルを継承し、調査 1 回ごとに最上位枠を無言で消費する。`subagent_type: "fork"` は常に親モデルで動く（`model` 指定は無視される）ので、役割が最上位ティア相当のときだけ使う。

モデル名ではなく**役割**でティアを決める。

| ティア | 値 | 役割 |
|---|---|---|
| 最安 | `haiku` | ファイル探索・grep 的な調査・機械的編集・fan-out ワーカー・要約 |
| 中位 | `sonnet`（重めの実装・レビューは `opus`） | 通常の実装・複数ファイルにまたがる調査・通常のコードレビュー。**迷ったらここ** |
| 最上位 | `fable` | 判断が一点に集中する仕事だけ（最終 verify・マージ可否・アーキテクチャ判断）。手を動かす仕事は聖域パスでも中位ティア止まり |

最上位ティアは決める役の種別（`dev-workflow:decider`）でだけ spawn する。`general-purpose` / `Explore` / `Plan` に `model: fable` を付けない。

詳細（なぜ明示が必須か、枠残量モード、強制層、ワークフロー経由のロール別ティアと適用範囲）は `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/references/model-tiers.md`。
