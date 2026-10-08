## ADDED Requirements

### Requirement: PreModelSwitch hook でモデル切替のたびに再キャッシュの通知スクリプトを起動する

`plugins/dev-workflow/hooks/hooks.json` は `PreModelSwitch` のエントリを持ち、`"${CLAUDE_PLUGIN_ROOT}/scripts/model-switch-recache-notice.sh"` を `command` の hook として起動しなければならない (MUST)。エントリに `matcher` を付けてはならず (MUST NOT)（どの切替先でも走らせる）、`timeout` を指定してはならない (MUST NOT)（この event では時間切れが切替を止めるため、既定より短くしない）。スクリプトは実行権限を持たなければならない (MUST)。既存のエントリ（SessionStart・UserPromptSubmit・PreToolUse・PostToolUse・SubagentStart・SubagentStop）は変えてはならない (MUST NOT)。

#### Scenario: hooks.json に PreModelSwitch のエントリがある

- **WHEN** `plugins/dev-workflow/hooks/hooks.json` を JSON として読む
- **THEN** `hooks.PreModelSwitch` は 1 件のエントリを持ち、その `hooks` は `type` が `command` で `command` に `${CLAUDE_PLUGIN_ROOT}` と `scripts/model-switch-recache-notice.sh` を含む 1 件だけで、エントリにも hook にも `matcher` と `timeout` のキーが無い

#### Scenario: スクリプトが実行できる

- **WHEN** `plugins/dev-workflow/scripts/model-switch-recache-notice.sh` の権限を調べる
- **THEN** 実行権限が付いている

#### Scenario: 既存のエントリはそのまま残る

- **WHEN** `hooks.json` のイベント名の集合を調べる
- **THEN** `SessionStart`・`UserPromptSubmit`・`PreToolUse`・`PostToolUse`・`SubagentStart`・`SubagentStop`・`PreModelSwitch` の 7 つに完全一致する

### Requirement: 通知は systemMessage だけで返し、切替の可否に関わる項目を返さない

`model-switch-recache-notice.sh` は、通知を出すとき、標準出力に JSON オブジェクトを 1 つだけ書き、そのキーは `systemMessage` の 1 つだけでなければならない (MUST)。`decision`・`hookSpecificOutput`・`permissionDecision`・`continue` を返してはならない (MUST NOT)（切替を止めず、本体の確認画面を飛ばさない）。`systemMessage` は空でない文字列でなければならない (MUST)。文言は、本体の確認画面が前後どちらに出ても意味が通るように、確認や選択を求める表現を含んではならない (MUST NOT)（`systemMessage` が確認画面の前後どちらに表示されるかは未確認のため）。

#### Scenario: 公式ドキュメントの入力例に systemMessage だけを返す

- **WHEN** `{"session_id":"abc123","transcript_path":"/tmp/t.jsonl","cwd":"/tmp","hook_event_name":"PreModelSwitch","from_model":"claude-sonnet-5","to_model":"claude-opus-5","requested_model":"opus","source":"command","context_tokens":182340,"prompt_cache_warm":true,"cache_ttl":"5m","estimated_cache_write_usd":1.1396,"pricing":"catalog"}` を stdin に渡す
- **THEN** 終了コードは 0 で、標準出力は JSON として読めるオブジェクト 1 つであり、そのキーの集合は `systemMessage` だけで、`decision` も `hookSpecificOutput` も含まない

#### Scenario: source が picker でも sdk でも同じ形で返す

- **WHEN** 上の入力の `source` を `picker` に変えたものと `sdk` に変えたものをそれぞれ渡す
- **THEN** どちらも終了コード 0 で、標準出力のキーの集合は `systemMessage` だけである

#### Scenario: 文言が確認を求めない

- **WHEN** 上の入力を渡して得た `systemMessage` を読む
- **THEN** `?`・`？`・「続けますか」・「よろしいですか」のどれも含まない

### Requirement: 通知は読み直すトークン数と推定費用を示す

`systemMessage` は、入力の `context_tokens` が 0 より大きい有限の数値のとき、その値を整数に丸めて 3 桁区切りにした文字列を含まなければならない (MUST)。入力の `estimated_cache_write_usd` が 0 以上の有限の数値のとき、`$` に続けて小数 2 桁で表した金額を含まなければならない (MUST)。ただし 0 より大きく 0.01 未満のときは `$0.01 未満` と表す (MUST)。真偽値は数値とみなしてはならない (MUST NOT)。どちらか一方しか条件を満たさないときは、満たした方だけを含む通知を返さなければならない (MUST)。

`pricing` が `catalog` のときは「定価」、`configured` のときは「組織の設定単価」、`default` のときは「既定の単価」を含む注記を金額に添えなければならない (MUST)。それ以外の値・キー無しのときは注記を付けてはならない (MUST NOT)。`from_model` と `to_model` がどちらも空でない文字列のときは、制御文字を除いた両方の値を含めなければならない (MUST)。`prompt_cache_warm` が `true` のときは、今のモデルのキャッシュが有効で切り替えると使えなくなることを述べる文を含めなければならず (MUST)、`true` でないときはその文を含めてはならない (MUST NOT)。

#### Scenario: トークン数と推定費用の両方が出る

- **WHEN** `context_tokens` が `182340`、`estimated_cache_write_usd` が `1.1396`、`pricing` が `catalog`、`prompt_cache_warm` が `true`、`from_model` が `claude-sonnet-5`、`to_model` が `claude-opus-5` の入力を渡す
- **THEN** `systemMessage` は `182,340`・`$1.14`・`定価`・`claude-sonnet-5`・`claude-opus-5`・「使えなくなります」をすべて含む

#### Scenario: 推定費用が無ければトークン数だけ出す

- **WHEN** 上の入力から `estimated_cache_write_usd` のキーを除いたもの、`null` にしたもの、文字列 `"1.14"` にしたもの、`true` にしたものをそれぞれ渡す
- **THEN** どの `systemMessage` も `182,340` を含み、`$` を含まない

#### Scenario: トークン数が無ければ推定費用だけ出す

- **WHEN** 上の入力から `context_tokens` のキーを除いたものと、文字列 `"182340"` にしたものをそれぞれ渡す
- **THEN** どの `systemMessage` も `$1.14` を含み、「トークン」を含まない

#### Scenario: ごく小さい費用は $0.01 未満と出す

- **WHEN** `context_tokens` が `900`、`estimated_cache_write_usd` が `0.004` の入力を渡す
- **THEN** `systemMessage` は `900` と `$0.01 未満` を含む

#### Scenario: pricing の値ごとに注記が変わる

- **WHEN** `pricing` を `configured`・`default`・`something_else` にした入力と、`pricing` のキーを除いた入力をそれぞれ渡す
- **THEN** `systemMessage` はそれぞれ「組織の設定単価」を含む・「既定の単価」を含む・「定価」も「単価」も含まない・「定価」も「単価」も含まない

#### Scenario: prompt_cache_warm が無ければキャッシュの文を省いて残りを出す

- **WHEN** `prompt_cache_warm` のキーを除いた入力と、文字列 `"yes"` にした入力をそれぞれ渡す
- **THEN** どの `systemMessage` も `182,340` と `$1.14` を含み、「使えなくなります」を含まない

#### Scenario: モデル名が無ければ省く

- **WHEN** `from_model` のキーを除いた入力と、`to_model` を空文字列にした入力をそれぞれ渡す
- **THEN** どちらも `systemMessage` を返し、`182,340` を含み、`→` を含まない

#### Scenario: モデル名の制御文字は出さない

- **WHEN** `to_model` が ESC（U+001B）と改行を含む文字列の入力を渡す
- **THEN** `systemMessage` は U+0000〜U+001F と U+007F の文字を含まない

### Requirement: 伝えることが無い切替では何も出さない

`model-switch-recache-notice.sh` は、次のどれかに当たるとき、標準出力に何も書かず終了コード 0 で終えなければならない (MUST): `prompt_cache_warm` が `false`（捨てるキャッシュが無い）、`context_tokens` が `0`（読み直すものが無い）、トークン数も推定費用も条件を満たさない、トークン数が条件を満たさず推定費用が `0`、`hook_event_name` が `PreModelSwitch` でない（キー無しを含む）。

#### Scenario: キャッシュが冷えていれば出さない

- **WHEN** `prompt_cache_warm` が `false`、`context_tokens` が `182340`、`estimated_cache_write_usd` が `1.1396` の入力を渡す
- **THEN** 標準出力は空で、終了コードは 0 である

#### Scenario: 最初の応答の前は出さない

- **WHEN** `context_tokens` が `0`、`estimated_cache_write_usd` が `0`、`prompt_cache_warm` が `true` の入力を渡す
- **THEN** 標準出力は空で、終了コードは 0 である

#### Scenario: 数字が 1 つも無ければ出さない

- **WHEN** `context_tokens` と `estimated_cache_write_usd` のキーがどちらも無い入力と、`context_tokens` が `-5` で `estimated_cache_write_usd` が `-1` の入力をそれぞれ渡す
- **THEN** どちらも標準出力は空で、終了コードは 0 である

#### Scenario: 別のイベントの入力には出さない

- **WHEN** `hook_event_name` が `PostModelSwitch` の入力と、`hook_event_name` のキーを除いた入力をそれぞれ渡す
- **THEN** どちらも標準出力は空で、終了コードは 0 である

### Requirement: どの失敗でも切替を止めない

`model-switch-recache-notice.sh` は、どの入力・どの環境でも終了コード 0 で終えなければならず (MUST)、標準エラーに何も書いてはならない (MUST NOT)。stdin が空・JSON として読めない・トップレベルがオブジェクトでない・`python3` が PATH に無い、のどの場合も標準出力に何も書いてはならない (MUST NOT)。スクリプトはネットワークアクセスとファイルの読み書きをしてはならず (MUST NOT)、入力の `transcript_path` が指すファイルを開いてはならない (MUST NOT)。入力は環境変数や引数に載せず stdin のまま渡さなければならない (MUST)。

#### Scenario: 壊れた入力では無出力で exit 0

- **WHEN** 空の stdin、`not json`、`[1,2]`、`"text"`、`null` をそれぞれ渡す
- **THEN** どれも標準出力と標準エラーが空で、終了コードは 0 である

#### Scenario: python3 が無くても exit 0

- **WHEN** `python3` を含まない PATH（`bash` と基本コマンドだけ）で、公式ドキュメントの入力例を渡す
- **THEN** 標準出力は空で、終了コードは 0 である

#### Scenario: transcript_path が存在しなくても結果は変わらない

- **WHEN** `transcript_path` が存在しないパスの入力と、存在するファイルのパスの入力をそれぞれ渡す
- **THEN** 2 つの標準出力は完全に一致する

#### Scenario: スクリプトに外部通信とファイル操作のコマンドが無い

- **WHEN** `plugins/dev-workflow/scripts/model-switch-recache-notice.sh` を `curl`・`wget`・`urllib`・`http`・`socket`・`open(` で検索する（コメント行を除く）
- **THEN** 1 件も見つからない
