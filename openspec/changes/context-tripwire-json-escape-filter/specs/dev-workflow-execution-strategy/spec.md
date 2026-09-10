# dev-workflow-execution-strategy（delta）

## MODIFIED Requirements

### Requirement: 起動の途中でコンテキストを測る hook

`plugins/dev-workflow/hooks/hooks.json` は、PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）に途中計測の hook スクリプト（`${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh`）を登録しなければならない（MUST）。hook は stdin の payload から `hook_event_name` / `session_id` / `transcript_path` / `agent_id` / `tool_name` / `tool_input` を読む（SHALL）。

計測対象は payload の `transcript_path` そのものではなく、`transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<transcript_path の親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出しなければならない（MUST）。`transcript_path` は hook が発火したセッションのトランスクリプトを指し、サブエージェントの中で発火した場合も親セッションのものを指すためである。

導出したパスが存在しないときは `<transcript_path の親ディレクトリ>/<session_id>/subagents/` 以下を**深さ 3 段まで**（`subagents/` 直下を 1 段目と数える）`agent-<agent_id>.jsonl` で探してよい（MAY。入れ子のサブエージェント）。この探索は毎ツール呼び出しのコストになるため上限を設けなければならず（MUST）、走査したディレクトリエントリが 200 件を超えるか探索が 20ms を超えたら打ち切って何も出力せず exit 0 とする（SHALL）。

読み取りはファイル末尾の固定 256KB だけを対象とし、そこに現れる最後の `assistant` レコードの usage を合算する（MUST）。この 256KB は環境変数で上書きできる形にしてはならない（MUST NOT。小さすぎる値を与えられると静かに fail-open して途中計測が全体で無効になるため。変更は仕様変更として扱う）。トランスクリプトが 5MB でも hook 1 回の実行時間は 100ms 未満でなければならない（MUST）。

`DEV_WORKFLOW_CONTEXT_TRIPWIRE` が `off` である・`python3` が無い・読み込んだ stdin が**メインスレッドからの呼び出しであることを JSON をパースせずに判定できる**のいずれかは、**python3 を起動する前に判定して** exit 0 しなければならない（MUST）。この hook は install 先の全ユーザーの全ツール呼び出しで走り、大多数がメインスレッドであるため、そこに python3 の起動コストを課してはならない（MUST NOT）。

パースせずに行うこの判定は、**JSON 意味論的に `agent_id` キーを持つ payload を早期 exit させてはならない**（MUST NOT）。JSON のキーは Unicode エスケープ（`\uXXXX`）でも書けるため、生文字列 `"agent_id"` の有無だけを見る判定では、同値な表記（`"\u0061gent_id"` など）の payload が無音で素通りする。判定は次の必要条件で行う（SHALL）: 生文字列 `"agent_id"` を含む、または 2 文字の並び `\u` を含む payload は python3 に渡す。それ以外は早期 exit する。`\uXXXX` 以外の JSON 文字列エスケープが生む文字（`"` `\` `/` とバックスペース・改頁・改行・復帰・タブ）は `agent_id` を構成できないため、生表記でないキーは必ず `\u` を含むことがこの条件の根拠である。

判定は必要条件であって十分条件ではなく、`agent_id` を持たない payload が python3 に渡ってよい（MAY）。その場合はパース後に `agent_id` フィールドが無いと判定され、何も出力せず exit 0 する。

次のいずれかに当たるときは何も出力せず exit 0 で終わらなければならない（MUST。fail-open）: 上の 3 つ ／ stdin が読めない・JSON でない ／ 導出したトランスクリプトが無い・usage が読めない ／ 探索の上限に達した ／ 閾値の環境変数が正の整数でない ／ 閾値以内。

#### Scenario: agent_id が無い呼び出しは python3 を起動せず無音

- **WHEN** `agent_id` を含まず、`\u` も含まない PostToolUse payload を hook に渡す
- **THEN** python3 を起動せずに、何も出力せず exit 0 で終わる

#### Scenario: Unicode エスケープ表記の agent_id でも早期 exit しない

- **WHEN** `agent_id` キーを `"\u0061gent_id"` のように Unicode エスケープで書いた（`json.loads` すると `agent_id` になる）payload を、強制停止の閾値を超えたトランスクリプトを指す形で PreToolUse / `Bash` として渡す
- **THEN** 早期 exit せず、生表記の payload と同じ deny（`permissionDecision: "deny"`）を出す

#### Scenario: 上限内では無音

- **WHEN** 導出したトランスクリプトの最後の usage 合算が `DEV_WORKFLOW_CONTEXT_CAP` 以内である
- **THEN** 何も出力せず exit 0 で終わる

#### Scenario: 測れないときは止めない

- **WHEN** 導出したトランスクリプトが存在しない、または usage を持つ assistant レコードが末尾に無い
- **THEN** 何も出力せず exit 0 で終わる

#### Scenario: 入れ子のサブエージェントは深さ 3 段まで探す

- **WHEN** `<session_id>/subagents/` の 2 段目のサブディレクトリに `agent-<agent_id>.jsonl` が置かれている payload を渡す
- **THEN** そのファイルを計測対象として特定する

#### Scenario: 探索の上限に達したら打ち切る

- **WHEN** `<session_id>/subagents/` 以下に 200 件を超えるエントリがあり、目的のファイルが見つからない
- **THEN** 探索を打ち切り、何も出力せず exit 0 で終わる

#### Scenario: 5MB のトランスクリプトでも 100ms 未満

- **WHEN** 5MB のトランスクリプトを対象に hook を 1 回実行する
- **THEN** 実行時間が 100ms 未満で、出力は閾値判定の結果だけである
