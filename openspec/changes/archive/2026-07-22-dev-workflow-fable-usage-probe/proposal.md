## Why

`FABLE_BUDGET_MODE`（abundant / conserve / reserve）は現状ユーザーの手動宣言に依存し、env 未設定なら常に安全側の conserve に倒れる。だが実際の Fable 週次残量は Anthropic の OAuth usage API（`/api/oauth/usage`）から機械可読に取得できる（2026-07-22 実測: `limits[]` に `group:"weekly"` かつ `scope.model.display_name:"Fable"` のエントリがあり `percent` / `is_active` / `resets_at` を持つ）。これを使えば「Fable の消費ペースが週の経過ペースより速いか遅いか」で abundant / conserve を自動導出でき、手動宣言の陳腐化（宣言したまま状況が変わる）を解消できる。さらに枠を実質使い切った `exhausted` 状態を新設し、Fable をいかなる役割でも使わない＋rate-limit 実エラーへの reactive 降格を規定する。

## What Changes

- `plugins/dev-workflow/scripts/usage-probe.sh` を新設: `/api/oauth/usage` を叩き、`~/.claude/.usage-snapshot` に `fable_weekly_pct` / `fable_active` を含む JSON を書く。5 分キャッシュ（snapshot が新しければ再フェッチしない）。認証取得・通信・パースのいずれが失敗しても **fail-open**（exit 0・snapshot を書かない＝既存 snapshot を壊さない）
- `plugins/dev-workflow/scripts/session-tripwires.sh` を拡張: セッション開始時に probe を best-effort 実行し、snapshot から残量モードを **自動導出** して、導出モードと Fable 残量% を注入する additionalContext ブロックをトリップワイヤー節に前置する。明示 env `FABLE_BUDGET_MODE` があればそれを最優先（導出より優先）
- 導出ロジック: 明示 env > snapshot 無し/読めない→conserve 既定 > `fable_weekly_pct > 90`→exhausted > `fable_weekly_pct <= 週経過%`→abundant / それ以外→conserve
- `decision-criteria.md` 更新: 自動導出ルールと `exhausted` 状態を残量モード表に追記。abundant の委譲条件を「self-contained（クリーンなハンドオフ）」基準で精緻化
- `escalation-tripwires.md` 更新: exhausted では昇格上限を Opus に固定（全経路）。rate-limit 実エラーへの reactive 降格トリップワイヤーを追加
- bats テスト拡張（usage-probe の 5 分キャッシュ・fail-open・snapshot スキーマ、session-tripwires の導出と明示 env override）
- plugin.json v1.3.0、marketplace 同期

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-execution-strategy`: 残量モードに `exhausted` を追加し、`FABLE_BUDGET_MODE` を usage snapshot から自動導出する要件を新設。abundant の委譲は self-contained タスクに限定する要件を追加
- `dev-workflow-escalation-tripwires`: usage-probe と snapshot 契約（5 分キャッシュ・fail-open）、SessionStart での残量モード自動導出注入、exhausted 時の Opus 上限、rate-limit 実エラーへの reactive 降格を追加

## Impact

- `plugins/dev-workflow/scripts/usage-probe.sh`（新規）
- `plugins/dev-workflow/scripts/session-tripwires.sh` — probe 実行 + 残量モード導出注入を追加
- `plugins/dev-workflow/templates/escalation-tripwires.md` — exhausted 上限 + rate-limit reactive 降格
- `plugins/dev-workflow/skills/github-issue/references/decision-criteria.md` — 自動導出・exhausted・self-contained 委譲
- `plugins/dev-workflow/tests/tripwire-hook.bats` — usage-probe / 導出のテスト追加
- `plugins/dev-workflow/.claude-plugin/plugin.json`（v1.3.0）/ `.claude-plugin/marketplace.json`
