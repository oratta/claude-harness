## Why

観点の配役（casting）は「毎ターンの配役判定＝この論点の担い手は主かエージェントか」の振り分けまでは持っているが、観点の中身（コンテキスト＋判断基準）を**いつ・どの機構でセッションに注入して論点潰しをするか**は未整理で、実装済みの配線（pr-review-gate・sns-safety-reviewer・secret-guard hook・聖域・burn-select 論点ゲート）が点在している。oratta/claude-harness#122 で、14観点それぞれの注入タイミング・配線先機構・注入文書の置き場所を1つの正本に確定する。

## What Changes

- **注入タイミングの語彙を8分類で確定**: issue #122 のたたき台6分類（①常時 ②毎ターンの配役判定 ③PR 時レンズ ④アクション直前ゲート ⑤定期監査 ⑥注入しない）に、実在する配線が収まらなかった **⑦起票・選定時**（burn-select 論点ゲート・issueify）と **⑧設計時**（longrun plan の research・opsx proposal）を追加する
- **注入マップの正本 `plugins/casting/catalog/injection.md` を新設**: 14観点 ×（注入タイミング／配線先機構／注入文書と置き場所）の確定表と、実装済み配線の実在パス一覧（点在の解消）を持つ
- **注入文書の置き場所規約**: `<repo>/.claude/casting/policies/<slug>.md` に統一（予算方針文・ブランド許容基準・フェーズ宣言文・優先基準文・許容工数宣言・業種固有規制メモ）
- **カタログ（catalog.md）は変更しない**: 5列の行単位継承はパース契約（casting-check.sh resolve / project.md 上書き）に焼き付いており、列追加は重量ルートの全 repo 移行を強いる。注入マップは per-repo で配役（上書き）する対象ではないため、カタログの外に別正本として置く。カタログとのドリフトは構造テスト（catalog_version 一致・14観点の全掲載）で機械的に防ぐ
- **未実装配線の実装 issue 切り出し**: ③の汎用化（リポ固有の観点レンズを pr-review-gate に自動注入）と④の汎用化（アクション直前ゲートの汎用機構）を別 issue として起票する（本 change には実装を含めない）
- ⑤定期監査は語彙に残すが現時点で割当なし（実装 issue も作らない）
- **（2026-08-19 主フィードバック反映）論点相談タイミングを追加して9分類に**: 注入文書のメインセッション読み込み禁止・観点スペシャリストへの相談・仲裁エージェント（事後報告）・人格規約を確定。実装は #127 に切り出し

## Capabilities

### New Capabilities

- `casting-injection-map`: 注入タイミング語彙・14観点の注入マップ・注入文書の置き場所規約・カタログとの整合検査

### Modified Capabilities

なし（casting-catalog / casting-project-files の要件は変えない。SKILL.md へのポインタ追記は casting-injection-map 側の要件として持つ）

## Impact

- `plugins/casting/catalog/injection.md` — 新設（注入マップの正本）
- `plugins/casting/tests/casting-injection.bats` — 新設（構造・整合テスト）
- `plugins/casting/skills/casting/SKILL.md` — injection.md へのポインタ追記
- `plugins/casting/.claude-plugin/plugin.json` — version 0.1.0 → 0.2.0
- catalog.md・rules/perspective-casting.md・casting-check.sh は変更しない
- 実装 issue（③汎用化・④汎用化）を oratta/claude-harness に起票
