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
- **THEN** 既存の 6 つのイベント名（`SessionStart`・`UserPromptSubmit`・`PreToolUse`・`PostToolUse`・`SubagentStart`・`SubagentStop`）がすべて残り、`PreModelSwitch` がある

### Requirement: 通知は systemMessage だけで返し、切替の可否に関わる項目を返さない

`model-switch-recache-notice.sh` は、通知を出すとき、標準出力に JSON オブジェクトを 1 つだけ書き、そのキーは `systemMessage` の 1 つだけでなければならない (MUST)。`decision`・`hookSpecificOutput`・`permissionDecision`・`continue` を返してはならない (MUST NOT)（切替を止めず、本体の確認画面を飛ばさない）。`systemMessage` は空でない文字列でなければならない (MUST)。文言は、本体の確認画面が前後どちらに出ても意味が通るように、確認や選択を求める表現を含んではならない (MUST NOT)（Claude Code 2.1.294 の実機では `systemMessage` は確認画面を承認したあとに表示されたが、この順序はドキュメントに書かれておらず、版によって変わりうるため）。

この spec の Scenario で「基準の入力」と書いたものは、公式ドキュメントの入力例にあたる次の JSON を指す。各 Scenario は、WHEN に書いた項目だけを基準の入力から変え、ほかの項目は変えない。

```json
{"session_id":"abc123","transcript_path":"/tmp/t.jsonl","cwd":"/tmp","hook_event_name":"PreModelSwitch","from_model":"claude-sonnet-5","to_model":"claude-opus-5","requested_model":"opus","source":"command","context_tokens":182340,"prompt_cache_warm":true,"cache_ttl":"5m","estimated_cache_write_usd":1.1396,"pricing":"catalog"}
```

対象の定義（この spec の、入力を見て通知を出す／出さない・何を載せるかを決める要件すべてに共通）: ①想定する入力の出どころは、Claude Code 本体が PreModelSwitch hook に渡す stdin の JSON である（形の根拠は公式ドキュメント https://code.claude.com/docs/en/hooks の PreModelSwitch input）。悪意のある入力を作る第三者は想定しない。②拾いたい誤りは、この hook が原因で切替が止まること（exit 2・時間切れ・`decision` の出力）、本体の確認画面を飛ばす項目（`permissionDecision`）を返すこと、伝える数字が無いのに通知を出すこと、ドキュメントと違う型の値で例外になり標準エラーや 0 以外の終了コードが出ること、モデル名に含まれた制御文字が画面にそのまま出ることである。③通ることを許す入力は次のとおり: `context_tokens` が小数なら整数に丸めて出す／トークン数と金額の上限は見ない（桁が大きくてもそのまま出す）／`estimated_cache_write_usd` が `0` でもトークン数が条件を満たせば `$0.00` と出す／`pricing` と金額の整合は見ない／`from_model` と `to_model` が同じ値でも出す／モデル名の長さは切らない／`source`・`cache_ttl`・`requested_model`・`session_id`・`cwd` は見ない／`prompt_cache_warm` が真偽値でなければ「分からない」として扱い、通知は出す。④入力の形の穴が見つかるたびに塞ぎ切ることを、この spec の要件の完了条件にしない。

#### Scenario: 公式ドキュメントの入力例に systemMessage だけを返す

- **WHEN** 基準の入力を stdin に渡す
- **THEN** 終了コードは 0 で、標準出力は JSON として読めるオブジェクト 1 つであり、そのキーの集合は `systemMessage` だけで、`decision` も `hookSpecificOutput` も含まない

#### Scenario: source が picker でも sdk でも同じ形で返す

- **WHEN** 基準の入力の `source` を `picker` に変えたものと `sdk` に変えたものをそれぞれ渡す
- **THEN** どちらも終了コード 0 で、標準出力のキーの集合は `systemMessage` だけである

#### Scenario: 文言が確認を求めない

- **WHEN** 基準の入力を渡して得た `systemMessage` を読む
- **THEN** `?`・`？`・「続けますか」・「よろしいですか」のどれも含まない

### Requirement: 通知は読み直すトークン数と推定費用を示す

`systemMessage` は、入力の `context_tokens` が 0 より大きい有限の数値のとき、その値を整数に丸めて 3 桁区切りにした文字列を含まなければならない (MUST)。入力の `estimated_cache_write_usd` が 0 以上の有限の数値のとき、`$` に続けて小数 2 桁で表した金額を含まなければならない (MUST)。ただし 0 より大きく 0.01 未満のときは `$0.01 未満` と表す (MUST)。真偽値は数値とみなしてはならない (MUST NOT)。Requirement「伝えることが無い切替では何も出さない」の条件に当たらない入力で、どちらか一方しか条件を満たさないときは、満たした方だけを含む通知を返さなければならない (MUST)。出さない条件はこの要件より先に効く（たとえば `context_tokens` が `0` なら、推定費用が条件を満たしていても何も出さない）。

`pricing` が `catalog` のときは「定価」、`configured` のときは「組織の設定単価」、`default` のときは「既定の単価」を含む注記を金額に添えなければならない (MUST)。それ以外の値・キー無しのときは注記を付けてはならない (MUST NOT)。`from_model` と `to_model` がどちらも空でない文字列のときは、制御文字を除いた両方の値を含めなければならない (MUST)。`prompt_cache_warm` が `true` のときは、切替前のモデルのキャッシュが切り替えると使えなくなることを述べる文を含めなければならず (MUST)。この文は、切替の前後どちらに表示されても正しい言い方にし、「今のモデル」「まだ有効」のように表示の時点に依存する表現を含んではならない (MUST NOT)、`true` でないときはその文を含めてはならない (MUST NOT)。

#### Scenario: トークン数と推定費用の両方が出る

- **WHEN** 基準の入力（`context_tokens` が `182340`、`estimated_cache_write_usd` が `1.1396`、`pricing` が `catalog`、`prompt_cache_warm` が `true`、`from_model` が `claude-sonnet-5`、`to_model` が `claude-opus-5`）を渡す
- **THEN** `systemMessage` は `182,340`・`$1.14`・`定価`・`claude-sonnet-5`・`claude-opus-5`・「切替前のモデルのキャッシュ」・「使えなくなります」をすべて含み、「今のモデル」と「まだ有効」を含まない

#### Scenario: 推定費用が無ければトークン数だけ出す

- **WHEN** 基準の入力から `estimated_cache_write_usd` のキーを除いたもの、`null` にしたもの、文字列 `"1.14"` にしたもの、`true` にしたものをそれぞれ渡す
- **THEN** どの `systemMessage` も `182,340` を含み、`$` を含まない

#### Scenario: トークン数が無ければ推定費用だけ出す

- **WHEN** 基準の入力から `context_tokens` のキーを除いたものと、文字列 `"182340"` にしたものをそれぞれ渡す
- **THEN** どの `systemMessage` も `$1.14` を含み、「トークン」を含まない

#### Scenario: ごく小さい費用は $0.01 未満と出す

- **WHEN** 基準の入力の `context_tokens` を `900`、`estimated_cache_write_usd` を `0.004` に変えて渡す
- **THEN** `systemMessage` は `900` と `$0.01 未満` を含む

#### Scenario: pricing の値ごとに注記が変わる

- **WHEN** 基準の入力の `pricing` を `configured`・`default`・`something_else` に変えたものと、`pricing` のキーを除いたものをそれぞれ渡す
- **THEN** `systemMessage` はそれぞれ「組織の設定単価」を含む・「既定の単価」を含む・「定価」も「単価」も含まない・「定価」も「単価」も含まない

#### Scenario: prompt_cache_warm が無ければキャッシュの文を省いて残りを出す

- **WHEN** 基準の入力から `prompt_cache_warm` のキーを除いたものと、文字列 `"yes"` に変えたものをそれぞれ渡す
- **THEN** どの `systemMessage` も `182,340` と `$1.14` を含み、「使えなくなります」を含まない

#### Scenario: モデル名が無ければ省く

- **WHEN** 基準の入力から `from_model` のキーを除いたものと、`to_model` を空文字列に変えたものをそれぞれ渡す
- **THEN** どちらも `systemMessage` を返し、`182,340` を含み、`→` を含まない

#### Scenario: モデル名の制御文字は出さない

- **WHEN** 基準の入力の `to_model` を、ESC（U+001B）と改行を含む文字列に変えて渡す
- **THEN** 標準出力を JSON として読んで得た `systemMessage` の文字列は、U+0000〜U+001F と U+007F の文字を含まず、`182,340` を含む

### Requirement: 伝えることが無い切替では何も出さない

`model-switch-recache-notice.sh` は、次のどれかに当たるとき、標準出力に何も書かず終了コード 0 で終えなければならない (MUST): `prompt_cache_warm` が `false`（捨てるキャッシュが無い）、`context_tokens` が `0`（読み直すものが無い）、トークン数も推定費用も条件を満たさない、トークン数が条件を満たさず推定費用が `0`、`hook_event_name` が `PreModelSwitch` でない（キー無しを含む）。

#### Scenario: キャッシュが冷えていれば出さない

- **WHEN** 基準の入力の `prompt_cache_warm` を `false` に変えて渡す（`context_tokens` は `182340`、`estimated_cache_write_usd` は `1.1396` のまま）
- **THEN** 標準出力は空で、終了コードは 0 である

#### Scenario: 最初の応答の前は出さない

- **WHEN** 基準の入力の `context_tokens` を `0` に変えたものと、`context_tokens` を `0`・`estimated_cache_write_usd` を `0` に変えたものをそれぞれ渡す（`prompt_cache_warm` は `true` のまま）
- **THEN** どちらも標準出力は空で、終了コードは 0 である

#### Scenario: 数字が 1 つも無ければ出さない

- **WHEN** 基準の入力から `context_tokens` と `estimated_cache_write_usd` のキーを両方除いたもの、`context_tokens` を `-5`・`estimated_cache_write_usd` を `-1` に変えたもの、`context_tokens` のキーを除き `estimated_cache_write_usd` を `0` に変えたものをそれぞれ渡す
- **THEN** どれも標準出力は空で、終了コードは 0 である

#### Scenario: 別のイベントの入力には出さない

- **WHEN** 基準の入力の `hook_event_name` を `PostModelSwitch` に変えたものと、`hook_event_name` のキーを除いたものをそれぞれ渡す
- **THEN** どちらも標準出力は空で、終了コードは 0 である

### Requirement: どの失敗でも切替を止めない

`model-switch-recache-notice.sh` は、どの入力・どの環境でも終了コード 0 で終えなければならず (MUST)、標準エラーに何も書いてはならない (MUST NOT)。stdin が空・JSON として読めない・トップレベルがオブジェクトでない・`python3` が PATH に無い、のどの場合も標準出力に何も書いてはならない (MUST NOT)。スクリプトはネットワークアクセスとファイルの読み書きをしてはならず (MUST NOT)、入力の `transcript_path` が指すファイルを開いてはならない (MUST NOT)。入力は環境変数や引数に載せず stdin のまま渡さなければならない (MUST)。

#### Scenario: 壊れた入力では無出力で exit 0

- **WHEN** 空の stdin、`not json`、`[1,2]`、`"text"`、`null` をそれぞれ渡す
- **THEN** どれも標準出力と標準エラーが空で、終了コードは 0 である

#### Scenario: python3 が無くても exit 0

- **WHEN** `python3` を含まない PATH（`bash` と基本コマンドだけ）で、基準の入力を渡す
- **THEN** 標準出力と標準エラーは空で、終了コードは 0 である

#### Scenario: transcript_path が存在しなくても結果は変わらない

- **WHEN** 基準の入力の `transcript_path` を、存在しないパスに変えたものと、存在するファイルのパスに変えたものをそれぞれ渡す
- **THEN** 2 つの標準出力は完全に一致し、どちらも `systemMessage` を返す

#### Scenario: スクリプトに外部通信とファイル操作のコマンドが無い

- **WHEN** `plugins/dev-workflow/scripts/model-switch-recache-notice.sh` から、空白を除いた先頭が `#` の行（コメント行）を除き、残りを `curl`・`wget`・`urllib`・`http`・`socket`・`open(` で検索する
- **THEN** 1 件も見つからない
