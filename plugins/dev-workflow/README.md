# dev-workflow

この開発ハーネスでの標準開発ワークフローを集めるプラグイン。開発の 1 ループ（`develop`）から PR の品質ゲート（`pr-review-gate`）・自動マージ（`templates/auto-merge/`）まで、「開発するときはこうする」という汎用的な手順を集約する。

## 含まれるスキル

### develop

コード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変えるときに、入口（issue 番号・URL・自然文・会話・cron・エピックの子）を問わず通す標準ワークフロー。旧スキル（issue 限定の入口だったもの）の後継。

- **本体はオーケストレータ専任**: Edit でコードを書かず、レビューを代行しない。作業者 W・仕様レビュアー R1・ゲート実行者 G を `model` 明示で spawn し、return の要約と記録先のコメント・ラベルだけを見て次に誰を起こすかを決める（役割の指示書は `skills/develop/references/roles/`）
- **入口 0（記録先の決定）**: issue があればそれ、無ければ issue を切らず、worktree 直後の空 commit → push → Draft PR を記録先にする（受け入れ条件は PR 本文。PR 本文に issue 参照を書かない）
- **1 ループ**: W（仕様化判断の記録 → 分割判定 → `/opsx:ff`）→ R1（別コンテキストの仕様レビュー・2 周キャップ）→ W 再開（TDD 実装 → verify → archive → PR → 仕様宣言）→ G（pr-review-gate 手順 1〜5・2 周キャップ）
- **モデル**: W と G は既定 `sonnet`、R1 は既定 `opus`。Fable にするのは `worker.md` の事前分類のうちマージ権限・層間契約・課金/法務に触れる実装・仕様・レビューだけ（聖域パスは `opus` のまま）。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が `throttled` / `depleted` なら全役割 `sonnet` 起点。W / G の SendMessage 再開は毎回 `scripts/subagent-context.sh` で測り、150K tokens 超なら再開せず同じ役割の新しいエージェント（新しい W / 新しい G）に手渡す。残量モード（`FABLE_BUDGET_MODE`）は `references/decision-criteria.md`
- **エピック**: 条件・作り方・回し方・完了条件を SKILL.md に規定。子 issue ごとに 1 ループを `isolation: "worktree"` で並列に回し、子が全部マージされただけでは閉じない

人間が `/develop` で直接依頼した場合でも、loop-dev-agent（各リポの憲法 `docs/agent-loop.md`）が無人サイクルの中から呼ぶ場合でも同じループを回す（`--unmanned` では憲法のメインが本体を務め、G は憲法 Step 1 に委ねる）。

### pr-review-gate

PR を作成したら必ず通す品質ゲート。「PR を作った」「レビューして」「マージまで進めて」「保留を再開する」で発火する。genetta-inc の flatmate リポで実運用検証済みの手順を全リポ向けに昇格したもの。

- 実装と**別コンテキスト**（既定 Codex CLI、フォールバック Task サブエージェント）でレビューする
- **リスク宣言の positive affirmation**: 「リスクなし」か「主のリスク許容が必要」のどちらかを必ず PR コメントに残す（書かないは選べない・fail-closed）
- 動作確認の**証拠**（HEAD SHA 付き）を添付し、API で実在を実測してから `agent-review:passed` を付ける
- 収束ルール: レビューは既定2周キャップ・再レビューは差分限定・マージ後に直せるものは blocking にしない
- auto-merge workflow 配備済みリポでは passed 付与で機械マージ、未配備リポではマージは人間操作（ゲート手順は同一）

### push-guard-setup

マージ済み PR のブランチへの push を全リポで拒否するグローバル pre-push ガードの導入。

### issueify

タスクメモ・バックログ md・TODO・受け入れ条件の無い issue を、測定可能な受け入れ条件付き GitHub issue に変換する（`skills/issueify/SKILL.md`。#205 で旧プラグインから移設）。入力はテキスト・ファイルパス・引数なし（`docs/` の未チェック項目や `TODO`/`FIXME` を自動発見）・`--existing`（既存 issue の補筆のみ）。1 issue = 1 論理タスクに原子化し、受け入れ条件を「実行コマンド + 期待値」に落とし、不足だけをヒアリングして、承認後に `gh issue create` する。`/develop` の issueify フォールバックはこのスキルを同プラグイン内で Read する。

## references/（他プラグインと共有する契約）

複数プラグインから参照される契約は、スキル配下ではなくプラグイン直下の `references/` に置く（#205 で旧プラグインから移設）。

| ファイル | 内容 |
|---|---|
| `references/self-verification.md` | 自己検証の共通原則（完了は主張であり証明ではない。evidence を提示してから完了を宣言する）。worktree / infra / daily-report / weekly-report / experience-to-skill の `## 自己検証` 節が参照する |
| `references/pr-body-format.md` | エージェントが書く PR / issue 本文の型（5 セクション・軽量モード・issue の承認判断 2 節）。`.github/PULL_REQUEST_TEMPLATE.md` と W の PR 手順が参照する |
| `references/model-tiers.md` | Workflow スクリプトの `opts.model` に渡すロール別ティア → エイリアスの対応表と、残量モードによる降格。`rules/subagent-model-selection.md` が正本として指す |
| `references/workflow-execution.md` | develop の 1 ループに収まらない規模をネイティブ Workflow ツールで回す型（Review → Build → Verify・Build Contract レビュー・verifier のしきい値・`resumeFromRunId`）。スクリプトの書き方は `workflow-authoring` スキルが正本 |

## テンプレート

### templates/auto-merge/

`agent-review:passed` が付いた PR を決定論的な条件（ラベル / CI green / 聖域非接触 / 緊急停止なし）だけで機械マージするロボットと、ワンクリック巻き戻し・攻撃再現テストのリポ展開用一式。展開手順（差し替え必須3点: 聖域パス・REQUIRED_CHECKS・AUTOMERGE_PAT）は `templates/auto-merge/README.md` を参照。

## コマンド

| コマンド | 説明 |
|---|---|
| `/develop [issue番号\|URL\|自然文]` | develop スキルを interactive モードで起動する（issue が無ければ Draft PR を記録先にする） |
| `/work-issue [issue番号\|URL\|自然文]` | `/develop` のエイリアス（旧名） |

## loop-dev-agent との関係

loop-dev-agent（無人常設ループ）の憲法は各リポに配備された `docs/agent-loop.md` で、**正本は flatmate 側（`new-resident` が配り、flatmate が保守する）**。harness はテンプレートを持たず、再生成や逆同期もしない（2026-08 の解散 #205 で旧テンプレートを廃止）。憲法は実装モード（Step 3）の中身をこのプラグインの `develop` スキルに委譲する。委譲の形は「憲法のメインが develop の本体として W / R1 を spawn する」で、Step 3 をサブエージェントに丸投げしない。ラベル操作・Draft PR 作成・キューの運用などの「無人運用の外形」は引き続き憲法側の責務。詳細は `develop/SKILL.md` の「実行モード」を参照。

2026-08 に解散した旧プラグイン 3 本からの移行手順と契約の新旧パスは `CHANGELOG.md` を参照。

```bash
/plugin install dev-workflow@oratta-claude-harness
```
