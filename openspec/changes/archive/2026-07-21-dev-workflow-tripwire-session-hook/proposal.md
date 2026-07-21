## Why

issue #26 で導入した昇格トリップワイヤーは、interactive 層（スキルを踏まない普段の solo 作業）ではグローバルルールへの手動コピーが必要だった。プラグインのスキル・テンプレートは呼ばれた時にしか文脈に載らないためだが、手動コピーはスナップショットになりテンプレート更新に追従しない。プラグインが配布できる SessionStart hook で常駐注入すれば、プラグイン更新だけで全セッションに効く（PR #29 マージ後のユーザー決定）。

## What Changes

- `plugins/dev-workflow/hooks/hooks.json` を新設し、SessionStart（matcher: startup|clear|compact）で注入スクリプトを起動する
- `plugins/dev-workflow/scripts/session-tripwires.sh` を新設: `templates/escalation-tripwires.md` の「## 昇格トリップワイヤー」節を抽出し `{"additionalContext": ...}` JSON で stdout に出力する（single source of truth 維持。テンプレート欠損時は fail-soft で無出力・exit 0）
- テンプレートの導入手順を更新: interactive 層は hook の自動注入が既定になり、手動コピーはプラグイン未導入環境向けのオプションに降格
- bats テスト新設（dev-workflow 初のテストスイート）
- plugin.json v1.2.0、marketplace 同期

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-escalation-tripwires`: 配布・導入要件を「SessionStart hook による常駐注入が既定」に変更し、hook の要件（JSON 形式・抽出元・fail-soft・matcher）を追加

## Impact

- `plugins/dev-workflow/hooks/hooks.json`（新規）/ `plugins/dev-workflow/scripts/session-tripwires.sh`（新規）
- `plugins/dev-workflow/templates/escalation-tripwires.md` — 導入手順コメントの更新
- `plugins/dev-workflow/tests/tripwire-hook.bats`（新規）
- `plugins/dev-workflow/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json`
