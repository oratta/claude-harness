# 観点相談・仲裁プロトコル（oratta/claude-harness#127）

## Why

観点の注入設計（`plugins/casting/catalog/injection.md`、#122/#124 で確定）は、注入タイミング「論点相談」の実装を #127 に予約している。現行の返信前チェック手順④「主でないなら送らず自走で決め直す」は、移譲済み観点の論点をメインセッションが**独断**で決める形になっており、注入文書（`policies/`）をメインに読み込めない大原則（バイアス・コンテキスト汚染の回避）と両立しない — 判断基準文書を読めない者が判断だけしている。観点スペシャリストへの相談と仲裁エージェントの裁定に差し替え、判断基準文書を読んだ者が判断する形に配線する。

## What Changes

- 汎用の観点スペシャリスト subagent（`plugins/casting/agents/casting-specialist.md`）を新設する。呼び出し時に指定された `policies/<slug>.md` を自分で Read し、人格ブロックを纏って意見を返す
- 汎用の仲裁 subagent（`plugins/casting/agents/casting-arbiter.md`）を新設する。入力は**フェーズ宣言文＋双方の主張のみ**（作業コンテキスト非共有を定義文面で保証）
- policy 文書テンプレート（`plugins/casting/templates/policy.md`）を新設し、人格ブロック（名前・スタンス・口調）の形式を定義する
- `rules/perspective-casting.md` 手順④を「全観点移譲済みなら観点スペシャリストに相談 → 割れたら仲裁 → 裁定実行・主へ事後報告」に差し替え、手順⑤に人格名帰属を追記する（**聖域パス**: SACRED 判定により人間マージ）
- casting SKILL.md に「論点相談・仲裁」の運用手順（相談の発火点・事後報告フォーマット・再相談しない終端条件）を追記する
- `plugins/casting/.claude-plugin/plugin.json` に `agents` を登録し、バージョンを 0.2.0 → 0.3.0 に上げる
- `.claude/casting/precedents.md`（このリポジトリの実体）に、事後報告フォーマットに沿った判例の実例を1件追記する
- 上記を検査する bats スイート `plugins/casting/tests/casting-consultation.bats` を新設する

## Capabilities

### New Capabilities

- `casting-consultation-protocol`: 論点相談・仲裁プロトコル。観点スペシャリスト／仲裁 subagent の定義要件（入力契約・モデルティア・人格規約）、policy テンプレートの人格ブロック形式、事後報告フォーマット、再相談しない終端条件

### Modified Capabilities

- `casting-catalog`: 常時ロード層の返信前チェック rule の要件変更。手順④の「自走で決め直す」を「観点スペシャリストへの相談（割れたら仲裁・事後報告）」に差し替え、手順⑤に人格名での発言帰属を追加。「担い手が主の観点が1つでもあれば主へ」の分岐は不変

## Impact

- 変更ファイル: `rules/perspective-casting.md`（聖域パス・人間マージ）、`plugins/casting/`（agents/ 新設・templates/policy.md 新設・SKILL.md 追記・plugin.json バージョン 0.3.0）、`.claude/casting/precedents.md`、`plugins/casting/tests/`
- 触らないもの: `catalog/catalog.md`（casting-set.sh 経由のみ・今回変更なし）、`catalog/injection.md`（注入マップ表・catalog_version は不変。終端条件の正本は SKILL.md 側に置き、injection.md の予約記述はそのまま有効）
- 依存: なし（テキスト規約と bats のみ。hook 新設なし）
