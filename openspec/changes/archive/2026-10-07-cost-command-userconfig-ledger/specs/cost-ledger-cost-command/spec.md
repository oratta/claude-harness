## ADDED Requirements

### Requirement: `/cost` はプラグイン設定の台帳パスを使う
`/cost` のコマンド本文は、userConfig の `LEDGER_PATH` の設定値を、集計スクリプトの呼び出しに環境変数 `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` として渡 MUST す。コマンド本文の Bash 実行にはこの環境変数が自動では渡らない（実機で確認済み）ので、本文の `${user_config.LEDGER_PATH}` が読み込み時に置換されることを使う。台帳パスの解決と優先順位は `cost-ledger-persistence` の規則のままで、`/cost` 側に別の解決を持ってはなら MUST NOT ない。

台帳が未設定のときの案内は、`/config` でのプラグイン設定「台帳ファイルのパス」を先に示 SHALL し、従来の方法（`~/.claude/settings.json` の `env` の `COST_LEDGER_PATH`）は次に示す。

#### Scenario: プラグイン設定だけが設定されている
- **WHEN** `COST_LEDGER_PATH` を設定せず userConfig の `LEDGER_PATH` だけを設定して `/cost` を実行する
- **THEN** `/cost` は台帳から読み、会話ログを直接読む動きにならない

#### Scenario: コマンド本文が値を渡している
- **WHEN** `commands/cost.md` の集計呼び出しを調べる
- **THEN** `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` に `${user_config.LEDGER_PATH}` を渡す形になっている

#### Scenario: どちらも未設定
- **WHEN** プラグイン設定も `COST_LEDGER_PATH` も未設定で `/cost` を実行する
- **THEN** 会話ログを直接読んだ値が返り、台帳の置き場所を聞く案内は `/config` を先に示す
