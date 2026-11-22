## MODIFIED Requirements

### Requirement: Stop のエントリで主への発言の番号の検査を起動する

`plugins/dev-workflow/hooks/hooks.json` は `hooks.Stop` に 1 件のエントリを持ち、そのエントリの 1 件の hook は `type` が `command` で `"${CLAUDE_PLUGIN_ROOT}/scripts/epic-child-state.sh"` を `timeout` 30 秒で起動しなければならない（MUST）。エントリに `timeout` を付けてはならず、エントリにも hook にも `matcher` を付けてはならない（MUST NOT）。`epic-child-state.sh` は Stop の入力を `owner-message-number-check.sh` に同じ入力のまま 1 回渡して番号検査を呼ばなければならない（MUST）。既存の他のイベントのエントリは変えてはならない（MUST NOT）。`owner-message-number-check.sh` は実行権限を持ち、python3 を起動するときは `python3 -I` で起動しなければならない（MUST）。

#### Scenario: hooks.json に Stop のエントリがある
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` を JSON として読む
- **THEN** `hooks.Stop` は 1 件のエントリを持ち、そのエントリの 1 件の hook は `type` が `command` で、`command` に `${CLAUDE_PLUGIN_ROOT}` と `scripts/epic-child-state.sh` を含み、hook の `timeout` は 30 で、エントリには `timeout` のキーが無く、エントリにも hook にも `matcher` のキーが無い

#### Scenario: 共通入口が同じ入力で番号検査を 1 回呼ぶ
- **WHEN** Stop の入力を `epic-child-state.sh` に渡す
- **THEN** `owner-message-number-check.sh` に同じ入力が 1 回だけ渡される

#### Scenario: スクリプトが実行できる
- **WHEN** `plugins/dev-workflow/scripts/owner-message-number-check.sh` の権限を調べる
- **THEN** 実行権限が付いている
