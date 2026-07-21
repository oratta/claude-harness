## Why

Fable 5 がサブスクで定常利用可能になり、Lance Martin「Cost effective harnesses with Fable」の知見（判断点に賢いモデル・実行に安いモデル・小タスクは委譲しない）をハーネスに組み込む条件が揃った（issue #26）。現状の dev-workflow は「誰がどのモデル・どの実行形態でやるか」の判断をユーザーの都度指示に依存しており、無人ループ（loop-dev-agent）では無監視のままトークンが単一モデル solo に燃える。実行戦略の選択を、事前分類ではなく「粗い入口判定 + 実行中の昇格トリップワイヤー」で自動化する。

## What Changes

- `references/decision-criteria.md` に3つ目の判定表「実行戦略」（決定論的シグナル × 判断分布 × 残量モード → solo / delegate+verify / workflow 型）を追加し、4象限モデル（トークン量 × 判断の分布）を判定の共通軸として明文化する
- 同ファイルの Step B（仕様化要否）基準を「外部振る舞いの変更」重心から「設計判断・トレードオフの有無」重心に改訂する（TDD・テスト必須は不変）
- 昇格トリップワイヤー（①規模超過→workflow 型、②失敗ループ→モデル昇格、③仕様の発明検知→plan/質問）の常駐ルールテンプレートを dev-workflow プラグインから配布する。テンプレートは「いつ手を止めるか」のみを含み、アクションは全てスキル呼び出しにする（Workflow ツールの opt-in 制約対応）
- `SKILL.md` の Step D に実行戦略別の分岐（solo / delegate+verify / workflow 型）と昇格ルールを定義する
- 残量モード（`abundant` / `conserve`）の設定値と参照方法を定義する（v0 は手動宣言。自動検知はスコープ外）
- 新規の独立 Step は増やさない。入口判定は既存 Step B/C に相乗りする

## Capabilities

### New Capabilities

- `dev-workflow-execution-strategy`: タスクを「トークン量 × 判断の分布」の4象限で分類し、実行戦略（solo / delegate+verify / workflow 型）と担当モデルを決める判定系。決定論的シグナルの前処理、残量モードによる閾値調整、Step B（仕様化要否）との判定軸統合を含む
- `dev-workflow-escalation-tripwires`: solo からの離脱条件を行為ベースの数えられる条件で定義する常駐トリップワイヤー3本と、その配布テンプレート。「いつ止まるか」（常駐ルール）と「どう実行するか」（スキル）の2段構え配線を含む

### Modified Capabilities

（なし — dev-workflow プラグインには既存 spec が無く、longrun / loops 側の変更は別 change `longrun-exec-model-allocation` / `loop-dev-agent-tripwires` で扱う）

## Impact

- `plugins/dev-workflow/skills/github-issue/SKILL.md` — Step B 判定の参照先更新、Step D に実行戦略分岐を追加
- `plugins/dev-workflow/skills/github-issue/references/decision-criteria.md` — Step B 基準改訂 + 実行戦略判定表の追加
- `plugins/dev-workflow/` 配下に新規テンプレート（昇格トリップワイヤー常駐ルール）
- `plugins/dev-workflow/.claude-plugin/plugin.json` — バージョン更新（marketplace キャッシュ反映のため必須）
- 後続 change への前提提供: `longrun-exec-model-allocation`（workflow 型バックエンドのモデル割り当て）、`loop-dev-agent-tripwires`（憲法テンプレートへの組み込み）は本 change のトリップワイヤー定義・残量モード定義を参照する
