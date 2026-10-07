## ADDED Requirements

### Requirement: チーム機能が有効なら SessionStart で警告する

dev-workflow の SessionStart hook は、環境変数 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` が有効な値のとき、名前付き spawn が teammate になり種別の道具制限・本文が無視されることを警告しなければならない（SHALL）。未設定・空文字・`0`・`false`（大文字小文字を区別しない）のときは何も出力してはならない（SHALL NOT）。どの場合も exit 0 で、セッション開始を止めてはならない。

守備範囲: 入力は、Claude Code が hook に渡す環境変数 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` の値だけである。拾いたい誤りは、チーム機能が有効なまま develop を回すことである。警告せずに通す値は、未設定・空文字・`0`・`false`（大文字小文字は区別しない）である。判定の穴を塞ぎ切ることは完了条件にしない。たとえば `no` や前後に空白を含む値は有効扱いになって警告が出るが、見逃すより出しすぎる側に倒す方針なのでそれでよい。

#### Scenario: 値が 1 のとき警告が出る
- **WHEN** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` で `team-mode-warning.sh` を実行する
- **THEN** 標準出力に JSON が 1 件出て、`systemMessage` と `hookSpecificOutput.additionalContext` の両方に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` を名指しした警告が入り、exit 0 になる

#### Scenario: 未設定のとき何も出ない
- **WHEN** 環境変数を設定せずに実行する
- **THEN** 標準出力は空で exit 0 になる

#### Scenario: 0 のとき何も出ない
- **WHEN** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0` で実行する
- **THEN** 標準出力は空で exit 0 になる

#### Scenario: hook に登録されている
- **WHEN** `hooks/hooks.json` の SessionStart を読む
- **THEN** `team-mode-warning.sh` を呼ぶ command が `startup|clear|compact` の matcher で登録されている
