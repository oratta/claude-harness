# dev-workflow

この開発ハーネスでの標準開発ワークフローを集めるプラグイン。開発の 1 ループ（`develop`）から PR の品質ゲート（`pr-review-gate`）・自動マージ（`templates/auto-merge/`）まで、「開発するときはこうする」という汎用的な手順を集約する。

## 含まれるスキル

### develop

コード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変えるときに、入口（issue 番号・URL・自然文・会話・cron・エピックの子）を問わず通す標準ワークフロー。旧スキル（issue 限定の入口だったもの）の後継。

- **本体はオーケストレータ専任**: Edit でコードを書かず、レビューを代行しない。作業者 W・仕様レビュアー R1・ゲート実行者 G を `model` 明示で spawn し、return の要約と記録先のコメント・ラベルだけを見て次に誰を起こすかを決める（役割の指示書は `skills/develop/references/roles/`）
- **入口 0（記録先の決定）**: issue があればそれ、無ければ issue を切らず、worktree 直後の空 commit → push → Draft PR を記録先にする（受け入れ条件は PR 本文。PR 本文に issue 参照を書かない）
- **1 ループ**: W（仕様化判断の記録 → 分割判定 → `/opsx:ff`）→ R1（別コンテキストの仕様レビュー・2 周キャップ）→ W 再開（TDD 実装 → verify → archive → PR → 仕様宣言）→ G（pr-review-gate 手順 1〜5・2 周キャップ）
- **モデル**: W / R1 / G は既定 `opus`。`worker.md` の「重要実装の事前分類」（聖域パス・マージ権限・層間契約・課金/法務）やマージ条件・聖域・層間契約に触れれば `fable`。残量モード（`FABLE_BUDGET_MODE`）は `references/decision-criteria.md`
- **エピック**: 条件・作り方・回し方・完了条件を SKILL.md に規定。子 issue ごとに 1 ループを `isolation: "worktree"` で並列に回し、子が全部マージされただけでは閉じない

人間が `/develop` で直接依頼した場合でも、`loops` プラグインの loop-dev-agent が無人サイクルの中から呼ぶ場合でも同じループを回す（`--unmanned` では憲法のメインが本体を務め、G は憲法 Step 1 に委ねる）。

### pr-review-gate

PR を作成したら必ず通す品質ゲート。「PR を作った」「レビューして」「マージまで進めて」「保留を再開する」で発火する。genetta-inc の flatmate リポで実運用検証済みの手順を全リポ向けに昇格したもの。

- 実装と**別コンテキスト**（既定 Codex CLI、フォールバック Task サブエージェント）でレビューする
- **リスク宣言の positive affirmation**: 「リスクなし」か「主のリスク許容が必要」のどちらかを必ず PR コメントに残す（書かないは選べない・fail-closed）
- 動作確認の**証拠**（HEAD SHA 付き）を添付し、API で実在を実測してから `agent-review:passed` を付ける
- 収束ルール: レビューは既定2周キャップ・再レビューは差分限定・マージ後に直せるものは blocking にしない
- auto-merge workflow 配備済みリポでは passed 付与で機械マージ、未配備リポではマージは人間操作（ゲート手順は同一）

### push-guard-setup

マージ済み PR のブランチへの push を全リポで拒否するグローバル pre-push ガードの導入。

## テンプレート

### templates/auto-merge/

`agent-review:passed` が付いた PR を決定論的な条件（ラベル / CI green / 聖域非接触 / 緊急停止なし）だけで機械マージするロボットと、ワンクリック巻き戻し・攻撃再現テストのリポ展開用一式。展開手順（差し替え必須3点: 聖域パス・REQUIRED_CHECKS・AUTOMERGE_PAT）は `templates/auto-merge/README.md` を参照。

## コマンド

| コマンド | 説明 |
|---|---|
| `/develop [issue番号\|URL\|自然文]` | develop スキルを interactive モードで起動する（issue が無ければ Draft PR を記録先にする） |
| `/work-issue [issue番号\|URL\|自然文]` | `/develop` のエイリアス（旧名） |

## loop-dev-agent との関係

`loops` プラグインの loop-dev-agent（無人常設ループ）は、実装モード（Step 3）の中身をこのプラグインの `develop` スキルに委譲する。委譲の形は「憲法のメインが develop の本体として W / R1 を spawn する」で、Step 3 をサブエージェントに丸投げしない。ラベル操作・Draft PR 作成・Review Queue 連携などの「無人運用の外形」は引き続き loop-dev-agent 側の責務。詳細は `develop/SKILL.md` の「実行モード」を参照。

```bash
/plugin install dev-workflow@oratta-claude-harness
```
