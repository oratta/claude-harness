## Why

issue #26（cost-effective harness）の v2。longrun:exec は4象限「④ トークン大 × 判断多」の workflow 型実行バックエンドとして再配置されたが、現行の tier 語彙（haiku / sonnet / inherit）には Fable が存在せず、記事準拠のモデル配置（builder=安いモデル、checkpoint/verify=Fable）を plan.md で表現できない。また残量モード `FABLE_BUDGET_MODE=reserve`（自動実行では Fable を温存）の解決経路が longrun 側に無い。

## What Changes

- tier 語彙に `fable` を追加する（`references/model-tiers.md` の対応表、resolver の KNOWN_TIERS、plan-template / SKILL.md / exec.md の語彙記載）
- `resolve-model-allocation.mjs` に reserve 降格を実装する: `FABLE_BUDGET_MODE=reserve` かつ `LONGRUN_AUTOMATED=1`（無人配線が設定）のとき `fable` ティアを `'opus'` に解決し、警告を出力する。interactive（`LONGRUN_AUTOMATED` 未設定）では降格しない
- ロール別推奨の出発点を更新する: builder=sonnet（安いモデル。失敗ループは昇格トリップワイヤーが救済）、verifier / reviewer=fable（判断が集中する場所）。「迷ったら inherit」の保守的デフォルトは維持
- bats テストを追加する（fable 解決・reserve 降格・interactive 非降格・後方互換）
- `plugins/longrun/.claude-plugin/plugin.json` のバージョン更新

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `longrun-model-allocation`: tier 語彙を 3 値から 4 値（haiku / sonnet / fable / inherit）に拡張。表ヘッダ・対応表・exec の消費要件を更新し、reserve 降格の要件を追加
- `longrun-plan-skill`: Synthesis のモデル割り当て推奨ヒューリスティクスを4象限準拠に更新（判断集中点 → fable、builder 出発点 → sonnet）

## Impact

- `plugins/longrun/references/model-tiers.md` — fable 行 + reserve 降格ルール
- `plugins/longrun/scripts/resolve-model-allocation.mjs` — KNOWN_TIERS / tierMap / reserve 降格
- `plugins/longrun/templates/plan-template.md` — 語彙・表ヘッダ・サンプル行
- `plugins/longrun/skills/longrun-plan/SKILL.md` — Step 5c ヒューリスティクス
- `plugins/longrun/commands/exec.md` — モデル割り当ての消費の記述
- `plugins/longrun/tests/model-allocation.bats` + fixtures — テスト追加
- `plugins/longrun/.claude-plugin/plugin.json` — バージョン
- 前提: dev-workflow-execution-strategy（archived 2026-07-21）が定義した `FABLE_BUDGET_MODE` を参照する
