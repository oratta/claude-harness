## Why

チーム機能（環境変数 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`）が有効なままだと、名前付きで起こした担当がチームの一員（teammate）として起動し、`subagent_type` の定義（道具の制限・本文）が無視される。develop は W / G を名前付きで起こすため、道具を絞った種別（#330）が効かない。2026-08-20 以降の名前付き担当 1,906 件がこの状態だった。設定が戻ったり別の PC で有効だったりしても気づけないので、develop を回す前に警告する。

## What Changes

- dev-workflow の SessionStart hook に、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` が有効な値のとき警告を出す処理を足す（新規 `scripts/team-mode-warning.sh`、`hooks/hooks.json` の SessionStart に登録）
- 未設定・空・`0`・`false` のときは何も出さない
- テスト `tests/team-mode-warning.bats` を足す
- 変更の記録 `plugins/dev-workflow/changes/591.md`

## Capabilities

### Modified Capabilities

- `dev-workflow-role-agent-types`: 種別の道具制限が効く前提（チーム機能が無効）を、SessionStart hook が検知して警告する要件を足す

## Impact

- `plugins/dev-workflow/scripts/team-mode-warning.sh`（新規）、`plugins/dev-workflow/hooks/hooks.json`
- 常時注入の固定分は増やさない（有効なときだけ出力する。`tests/injection-budget.bats` の予算は動かさない）
