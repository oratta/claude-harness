# dev-workflow

この開発ハーネスでの標準開発ワークフローを集めるプラグイン。issue 着手（`github-issue`）から PR の品質ゲート（`pr-review-gate`）・自動マージ（`templates/auto-merge/`）まで、「開発するときはこうする」という汎用的な手順を集約する。

## 含まれるスキル

### github-issue

GitHub issue（番号・URL・自然文）に取り組む時の標準ワークフロー。

- worktree 上なのに `wt-setup` が未実行なら先に実行する
- 仕様として残すべき変更なら opsx（openspec）フローに乗せ、そうでなければコード直行する
- 単一 change で足りるか複数 change に割れるかを判定し、複数なら change ごとに分けて処理する
- 全経路で TDD（テスト先行）を徹底する

人間が `/work-issue` で直接依頼した場合でも、`loops` プラグインの loop-dev-agent が無人サイクルの中から呼ぶ場合でも、同じ判定ロジックを共有する（`--unmanned` で無人モードに切り替え）。

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
| `/work-issue [issue番号\|URL\|自然文]` | github-issue スキルを interactive モードで起動する |

## loop-dev-agent との関係

`loops` プラグインの loop-dev-agent（無人常設ループ）は、実装モード（Step 3）の中身をこのプラグインの `github-issue` スキルに委譲する。ラベル操作・Draft PR 作成・Review Queue 連携などの「無人運用の外形」は引き続き loop-dev-agent 側の責務。詳細は `github-issue/SKILL.md` の「このスキルの立ち位置」を参照。

```bash
/plugin install dev-workflow@oratta-claude-harness
```
