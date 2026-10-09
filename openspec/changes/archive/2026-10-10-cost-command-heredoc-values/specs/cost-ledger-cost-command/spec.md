## MODIFIED Requirements

### Requirement: `/cost` はプラグイン設定の台帳パスを使う
`/cost` のコマンド本文は、userConfig の `LEDGER_PATH` の設定値を、集計スクリプトの呼び出しに環境変数 `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` として渡 MUST す。コマンド本文の Bash 実行にはこの環境変数が自動では渡らない（実機で確認済み）ので、本文の `${user_config.LEDGER_PATH}` が読み込み時に置換されることを使う。置換された値（台帳のパスと、後述のプラグインのルート）は、引用した here-document でシェル変数に読み込んでから使い、シェルの構文として解釈されては MUST NOT ない（`'`・空白・`$`・バッククォート・`"` を含む値が文字どおりに扱われる）。台帳パスの解決と優先順位は `cost-ledger-persistence` の規則のままで、`/cost` 側に別の解決を持ってはなら MUST NOT ない。

集計スクリプトの探索は、コマンド本文の置換で絶対パスになる作業中のプラグインのルートを先頭の候補にし MUST、インストール済みのコピーは後ろの候補にとどめる（Bash の実行環境にはプラグインのルートの環境変数が渡らないので、環境変数の形で先頭に置くと、版の違う旧コピーが選ばれる）。

台帳が未設定のときの案内は、`/config` でのプラグイン設定「台帳ファイルのパス」を先に示 SHALL し、従来の方法（`~/.claude/settings.json` の `env` の `COST_LEDGER_PATH`）は次に示す。

#### Scenario: プラグイン設定だけが設定されている
- **WHEN** `COST_LEDGER_PATH` を設定せず userConfig の `LEDGER_PATH` だけを設定して `/cost` を実行する
- **THEN** `/cost` は台帳から読み、会話ログを直接読む動きにならない

#### Scenario: コマンド本文が値を渡している
- **WHEN** `commands/cost.md` の集計呼び出しを調べる
- **THEN** `${user_config.LEDGER_PATH}` を引用した here-document で読み込んだ変数の値が `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` として渡される形になっており、値をシングルクォートや二重引用符で包んで直接置く形ではない

#### Scenario: `'` を含む台帳パス
- **WHEN** 台帳パスが `/x/'b'/ledger.jsonl` のように `'` を偶数個含む値に置換された `commands/cost.md` の集計呼び出しを実行する
- **THEN** 集計スクリプトは `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` として設定どおりのパスを受け取り、別のパスの台帳は作られない

#### Scenario: 特殊文字を含むプラグインのルート
- **WHEN** プラグインのルートが空白・`$(...)`・バッククォート・`"` を含む値に置換された `commands/cost.md` の探索を実行する
- **THEN** 先頭の候補はそのパスのまま使われ、値の一部がコマンドとして実行されない

#### Scenario: どちらも未設定
- **WHEN** プラグイン設定も `COST_LEDGER_PATH` も未設定で `/cost` を実行する
- **THEN** 会話ログを直接読んだ値が返り、台帳の置き場所を聞く案内は `/config` を先に示す
