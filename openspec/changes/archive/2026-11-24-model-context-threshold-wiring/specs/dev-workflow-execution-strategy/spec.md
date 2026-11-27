## MODIFIED Requirements

### Requirement: サブエージェントのコンテキスト上限と手渡し
`plugins/dev-workflow/scripts/subagent-context.sh` は、対象のトランスクリプトの最後の assistant レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、1 行 JSON（`agent` / `file` / `context_tokens` / `calls` / `cap` / `over_cap`）を出力しなければならない（SHALL）。対象の指定は次の 2 通りとする（SHALL）: `--file <path>` はそのファイルを直接測る（`agent` はファイル名から導く）。`<agent-name>` は `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}/*/*/subagents/` 内の `agent-<id>.meta.json` の `name` が指定名と完全一致する場合、対応する実在の `agent-<id>.jsonl` を候補に加え、従来の名前 glob（`agent-*<name>-*.jsonl` と `agent-*<name>.jsonl`）による候補と統合して重複を除かなければならない（SHALL）。同名が複数あれば最初のレコードの `cwd` が現在のディレクトリと一致するものを優先し、その中でログの更新時刻が新しいものを選び、一致するものが無ければ全候補で最新のログを選ばなければならない（SHALL）。metadata が無い・`name` が一致しない・壊れている場合も従来のファイル名探索にフォールバックし、候補が無ければ `transcript not found` を含む JSON を出力して exit 1 としなければならない（SHALL）。上限は計測に採用した assistant レコードの `message.model` を使って共通処理から解決した `context_cap` とし、`--cap` > `DEV_WORKFLOW_CONTEXT_CAP` > モデル別既定値 / fallback（初期値 150000）の順に適用しなければならない（SHALL）。モデル入力・上書き・診断の契約は dev-workflow-token-thresholds の文脈計測の要件に従う（MUST）。上限超なら exit 2、上限以内なら exit 0、トランスクリプトが無い・usage が無い・読めないとき、または共通処理を解決できないときは `error` を持つ 1 行 JSON と exit 1 にし、exit 1 は作業を止めない（fail-open。SHALL）。fallback・再検証と解決失敗の理由は stderr に出し、stdout の 1 行 JSON を保つ（MUST）。develop の本体は W / G を SendMessage で再開する前に毎回これを実行し、exit 2 なら再開せず、前回の return（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）と記録先を渡して新しい W / G を spawn しなければならない（MUST。モデルは変えない）。W は工程の終わりに必ず return し、手渡しで起こされた W は前任の return と記録先・ファイルの現状から再出発して前任の埋めた決定を再発明してはならない（MUST NOT）。昇格トリップワイヤーの一覧（`templates/escalation-tripwires.md`）は【コンテキスト上限 → 手渡し】を 4 として含み、rate-limit 実エラーの reactive 降格を 5 とする（SHALL）。

守備範囲: 名前探索で扱う入力は、Claude Code が生成するローカルの metadata（`agent-<id>.meta.json`）とトランスクリプト（JSONL）である。防ぐのは、metadata の `name` の部分一致による誤採用、候補を統合せず cwd 一致優先・ログの更新時刻順を適用しないことによる誤選択、metadata の破損による探索停止である。metadata の `name` が指定名と不一致でも、従来のファイル名 glob に一致するログは候補として採用してよい。未知の入力による穴をすべて塞ぐことは、この要件の完了条件にしない（MUST NOT）。探索先は 1 か所で、別の設定フォルダの下の会話記録は探さない（そのセッションの W は `transcript not found` の exit 1 になる）。

#### Scenario: 上限超のサブエージェントは exit 2
- **WHEN** トランスクリプトの最後の assistant usage の合算が `DEV_WORKFLOW_CONTEXT_CAP` を超える
- **THEN** `over_cap: true` の JSON を出力して exit 2 で終わる

#### Scenario: 上限超なら再開せず手渡す
- **WHEN** 本体が W を SendMessage で再開しようとして `subagent-context.sh` が exit 2 を返す
- **THEN** 本体は SendMessage を送らず、前回の return と記録先を渡して新しい W を同じモデルで spawn する

#### Scenario: トランスクリプトが無くても作業は止まらない
- **WHEN** `subagent-context.sh` が対象のトランスクリプトを見つけられない
- **THEN** `error` を含む JSON を出力して exit 1 で終わり、本体は従来どおり再開してよい（上限判定が効かないだけ）

#### Scenario: --file で直接測る
- **WHEN** `subagent-context.sh --file <トランスクリプトのパス>` を実行する
- **THEN** 名前 glob を使わずにそのファイルを測り、上限超なら exit 2・上限以内なら exit 0・読めなければ exit 1 を返す

#### Scenario: 名前指定の既存の挙動は変わらない
- **WHEN** `subagent-context.sh <agent-name>` を従来どおり実行する
- **THEN** 出力する JSON のフィールドと exit code は `--file` 追加の前後で変わらない

#### Scenario: ファイル名に名前が無くても metadata の名前で見つかる
- **GIVEN** `agent-a123.jsonl` に上限内の assistant usage があり、隣の `agent-a123.meta.json` の `name` が `W-590` である
- **WHEN** `subagent-context.sh W-590` を実行する
- **THEN** `file` は `agent-a123.jsonl` を指し、その usage の計測値を出力して exit 0 で終わる

#### Scenario: 従来のファイル名だけでも見つかる
- **GIVEN** `agent-aW-590-abcd.jsonl` に上限内の assistant usage があり、metadata が無い
- **WHEN** `subagent-context.sh W-590` を実行する
- **THEN** そのログの計測値を出力して exit 0 で終わる

#### Scenario: 探索元が異なっても cwd 一致を優先する
- **GIVEN** metadata の `name` が `W-590` と一致する新しいログの cwd が別ディレクトリであり、従来のファイル名で一致する古いログの cwd が現在のディレクトリである
- **WHEN** `subagent-context.sh W-590` を実行する
- **THEN** cwd が一致する古いログが選ばれる

#### Scenario: 同じ cwd の同名ログでは最新を選ぶ
- **GIVEN** 異なるセッションに `name` が `W-590` と完全一致する metadata と対応ログがあり、両ログの cwd が現在のディレクトリである
- **WHEN** `subagent-context.sh W-590` を実行する
- **THEN** ログ自体の更新時刻が新しい方が選ばれる

#### Scenario: cwd 一致が無ければ同名ログの最新を選ぶ
- **GIVEN** 異なるセッションに `name` が `W-590` と完全一致する metadata と対応ログがあり、どのログの cwd も現在のディレクトリと一致しない
- **WHEN** `subagent-context.sh W-590` を実行する
- **THEN** ログ自体の更新時刻が新しい方が選ばれる

#### Scenario: metadata の欠落・不一致・破損はファイル名探索を妨げない
- **GIVEN** 従来のファイル名で見つかる上限内のログがあり、metadata が無い、`name` が別名、または壊れた JSON である
- **WHEN** 各ケースで `subagent-context.sh W-590` を実行する
- **THEN** 従来のファイル名のログを測り、exit 0 で終わる

#### Scenario: metadata でもファイル名でも候補が無ければ従来のエラーになる
- **GIVEN** metadata が無い、`name` が別名、壊れた JSON、または一致する metadata の対応ログが存在しない
- **AND** 従来のファイル名でも一致するログが無い
- **WHEN** 各ケースで `subagent-context.sh W-590` を実行する
- **THEN** `transcript not found` を含む JSON を出力して exit 1 で終わる

#### Scenario: metadata の名前は完全一致で判定する
- **GIVEN** ファイル名に `W-590` を含まないログの metadata の `name` が `W-590-extra` であり、他に候補が無い
- **WHEN** `subagent-context.sh W-590` を実行する
- **THEN** `transcript not found` を含む JSON を出力して exit 1 で終わる

#### Scenario: CLAUDE_CONFIG_DIR の下の会話記録を見つける
- **GIVEN** `CLAUDE_PROJECTS_DIR` が未設定で、`CLAUDE_CONFIG_DIR` が指す一時ディレクトリの `projects/*/*/subagents/` に `W-590` のトランスクリプトがあり、`HOME` の下には無い
- **WHEN** `subagent-context.sh W-590` を `--projects` なしで実行する
- **THEN** `file` はそのトランスクリプトを指し、その usage の計測値を出力して exit 0 で終わる

#### Scenario: CLAUDE_PROJECTS_DIR は CLAUDE_CONFIG_DIR より優先される
- **GIVEN** `CLAUDE_PROJECTS_DIR` と `CLAUDE_CONFIG_DIR` がどちらも設定され、それぞれの下に同名で usage の異なるトランスクリプトがある
- **WHEN** `subagent-context.sh <agent-name>` を `--projects` なしで実行する
- **THEN** `CLAUDE_PROJECTS_DIR` の下のトランスクリプトを測る

#### Scenario: どちらも未設定なら ~/.claude の下を探す
- **GIVEN** `CLAUDE_PROJECTS_DIR` と `CLAUDE_CONFIG_DIR` がどちらも未設定で、`$HOME/.claude/projects/*/*/subagents/` に対象のトランスクリプトがある
- **WHEN** `subagent-context.sh <agent-name>` を `--projects` なしで実行する
- **THEN** そのトランスクリプトを測る

### Requirement: 起動の途中でコンテキストを測る hook

`plugins/dev-workflow/hooks/hooks.json` は、PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）に途中計測の hook スクリプト（`${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh`）を登録しなければならない（MUST）。hook は stdin の payload から `hook_event_name` / `session_id` / `transcript_path` / `agent_id` / `tool_name` / `tool_input` を読む（SHALL）。

計測対象は payload の `transcript_path` そのものではなく、`transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<transcript_path の親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出しなければならない（MUST）。`transcript_path` は hook が発火したセッションのトランスクリプトを指し、サブエージェントの中で発火した場合も親セッションのものを指すためである。

導出したパスが存在しないときは `<transcript_path の親ディレクトリ>/<session_id>/subagents/` 以下を**深さ 3 段まで**（`subagents/` 直下を 1 段目と数える）`agent-<agent_id>.jsonl` で探してよい（MAY。入れ子のサブエージェント）。この探索は毎ツール呼び出しのコストになるため上限を設けなければならず（MUST）、走査したディレクトリエントリが 200 件を超えるか探索が 20ms を超えたら打ち切って何も出力せず exit 0 とする（SHALL）。

読み取りはファイル末尾の固定 256KB だけを対象とし、そこに現れる最後の `assistant` レコードの usage を合算する（MUST）。しきい値はこの計測レコードの `message.model` を使って共通処理から取得した `context_cap` / `context_hard_cap` とし、モデル入力・上書き・正数条件・診断は dev-workflow-token-thresholds の文脈計測の要件に従わなければならない（MUST）。この 256KB は環境変数で上書きできる形にしてはならない（MUST NOT。小さすぎる値を与えられると静かに fail-open して途中計測が全体で無効になるため。変更は仕様変更として扱う）。トランスクリプトが 5MB でも hook 1 回の実行時間は 100ms 未満でなければならない（MUST）。

`DEV_WORKFLOW_CONTEXT_TRIPWIRE` が `off` である・`python3` が無い・読み込んだ stdin が**メインスレッドからの呼び出しであることを JSON をパースせずに判定できる**のいずれかは、**python3 を起動する前に判定して** exit 0 しなければならない（MUST）。この hook は install 先の全ユーザーの全ツール呼び出しで走り、大多数がメインスレッドであるため、そこに python3 の起動コストを課してはならない（MUST NOT）。

パースせずに行うこの判定は、**JSON 意味論的に `agent_id` キーを持つ payload を早期 exit させてはならない**（MUST NOT）。JSON のキーは Unicode エスケープ（`\uXXXX`）でも書けるため、生文字列 `"agent_id"` の有無だけを見る判定では、同値な表記（`"\u0061gent_id"` など）の payload が無音で素通りする。判定は次の必要条件で行う（SHALL）: 生文字列 `"agent_id"` を含む、または 4 文字の並び `\u00` を含む payload は python3 に渡す。それ以外は早期 exit する。

この必要条件が成り立つ根拠は 2 つある。第一に、`\uXXXX` 以外の JSON 文字列エスケープが生む文字（`"` `\` `/` とバックスペース・改頁・改行・復帰・タブ）は `agent_id` を構成できないため、生表記でないキーは必ず `\uXXXX` を含む。第二に、`agent_id` の 8 文字はすべて U+005F〜U+0074 の範囲にあり、その `\uXXXX` 表記は上位 2 桁が必ず `00` になる（16 進の大文字小文字の揺れは下位 2 桁にしか現れない）。したがって前置は `\u00` に絞ってよい。

判定は必要条件であって十分条件ではなく、`agent_id` を持たない payload が python3 に渡ってよい（MAY）。その場合はパース後に `agent_id` フィールドが無いと判定され、何も出力せず exit 0 する。この向きの外し方が起きる頻度は payload の内容に依存する（PostToolUse の payload は `tool_response` を含むため、Read が読んだファイル内容・Bash の出力・Grep の結果にこの並びがあれば起動する。JSON シリアライザが `\b \f \n \r \t` 以外の制御文字を 4 桁 16 進で綴った出力も同じ）。判定を誤ってよいのはこの向き（余計に起動して無音で終わる）だけであり、逆向き（`agent_id` を持つ payload の早期 exit）は許されない（MUST NOT）。

次のいずれかに当たるときは何も出力せず exit 0 で終わらなければならない（MUST。fail-open）: 上の 3 つ ／ stdin が読めない・JSON でない ／ 導出したトランスクリプトが無い・usage が読めない ／ 探索の上限に達した。しきい値解決の失敗・解決値の正数条件違反は stdout 空・exit 0 とし、理由を stderr に出さなければならない（MUST）。閾値以内でも stdout は空・exit 0 とし、fallback・再検証が必要なら stderr に診断を出す（MUST）。共通処理の正常な fallback だけを理由に判定を無効にしてはならない（MUST NOT）。

#### Scenario: agent_id が無い呼び出しは python3 を起動せず無音

- **WHEN** `agent_id` を含まず、`\u00` も含まない PostToolUse payload を hook に渡す
- **THEN** python3 を起動せずに、何も出力せず exit 0 で終わる

#### Scenario: Unicode エスケープ表記の agent_id でも早期 exit しない

- **WHEN** `agent_id` キーを `"\u0061gent_id"` のように Unicode エスケープで書いた（`json.loads` すると `agent_id` になる）payload を、強制停止の閾値を超えたトランスクリプトを指す形で PreToolUse / `Bash` として渡す
- **THEN** 早期 exit せず、生表記の payload と同じ deny（`permissionDecision: "deny"`）を出す

#### Scenario: エスケープを含むだけの呼び出しは無音で終わる

- **WHEN** `agent_id` を持たないが `\u00` を含む（`tool_response` の中身など）PostToolUse payload を渡す
- **THEN** python3 は起動してよいが、何も出力せず exit 0 で終わる

#### Scenario: 上限内では無音

- **WHEN** 導出したトランスクリプトの最後の usage 合算が解決した `context_cap` 以内である
- **THEN** stdout は空・exit 0 で終わる。根拠に含まれる既知モデルなら stderr も空、fallback・再検証が必要なモデルなら stderr にだけ診断が出る

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
- **THEN** 実行時間が 100ms 未満で、stdout は閾値判定の結果だけであり、必要なモデル診断は stderr に出る

#### Scenario: 全解除できる

- **WHEN** `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` を設定して閾値超の payload を渡す
- **THEN** 何も出力せず exit 0 で終わる

### Requirement: 強制停止の閾値を超えたら PreToolUse が編集を拒否する

PreToolUse で計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP`（既定 220000）を超えていたら、hook は `Edit` / `Write` / `NotebookEdit` を拒否しなければならない（MUST）。読み取り系ツール（Read / Grep / Glob）を拒否してはならない（MUST NOT）。

`Bash` は**コマンド内容によらず拒否しなければならない**（MUST）。コマンド文字列を解析して一部の形だけを通す判定を置いてはならない（MUST NOT）。理由: 判定はこのプロセスの中でコマンド文字列をトークン化するが、実際に実行するのは別プロセスのシェル（zsh または bash）で、両者のトークン化は一致を保証できない。実際に、シェル側にだけ意味を持つ記法（zsh の ANSI-C クォート `$'…'`、シェルのブレース展開 `{a,b}` 等）を判定側が「危険でない 1 トークン」と誤認し、実行側では任意コマンドの引数に展開される迂回が 2 度にわたって実機で再現した（`git -c` の値読み飛ばし、および `git push $'--receive-pack=/tmp/x' origin main`）。受理する経路が 1 つでも残る限り、この種の迂回は形を変えて再発するため、`Bash` は内容を一切見ず全件拒否する構造に閉じる。

拒否は `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":...}}` を stdout に出して exit 0 とする（SHALL）。`permissionDecisionReason` は次をすべて含まなければならない（MUST）: 計測値と `DEV_WORKFLOW_CONTEXT_HARD_CAP` の値 ／ `Bash` はコマンド内容によらず一切通らないこと ／ payload の `cwd`（＝そのサブエージェントの作業ツリーのパス）／ 編集済みファイルの一覧と、その作業ツリーのパス（`cwd`）を return に書けという指示 ／ commit は本体が行うという指示（サブエージェント自身は commit できないため）／ **return の 1 行目は `工程中断:` にすること**（強制停止で止まった時点で予定していた作業が残っているため、常に中断とする）。`-C <path>` や `-c <k=v>` といった、通る形についての案内を含めてはならない（MUST NOT）— 通る形は存在しないため。

`DEV_WORKFLOW_CONTEXT_HARD_CAP` は `DEV_WORKFLOW_CONTEXT_CAP` より大きくなければならず、小さいか等しい場合は fail-open（stdout 空・exit 0）とする（MUST）。必要なモデル診断はこの場合も stderr に出さなければならない（MUST）。ここでの環境変数名は共通処理で解決した値を指し、モデル別既定値も同じ比較に使う。

#### Scenario: 強制停止の閾値超で Edit が拒否される

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP` を超える状態で `tool_name: "Edit"` の PreToolUse payload を渡す
- **THEN** `permissionDecision: deny` の JSON を出力し、理由に計測値と「commit は本体が行う」と `工程中断:` が含まれる

#### Scenario: Bash はどんな形でも拒否される

- **WHEN** 同じ状態で `tool_name: "Bash"` の PreToolUse payload を、`command` に次のいずれかを入れて渡す: 旧設計で許可していた形（`"git status"` / `"git -C /path/to/worktree commit -m x"` / `"git push -u origin br"`）、報告された迂回（`"git -c 'diff.external=sh -c \"touch /tmp/x\"' diff HEAD^ HEAD"`、zsh の ANSI-C クォートを使う `"git push $'--receive-pack=/tmp/x' origin main"`）、`$` を使わないブレース展開の変種（`"git push {--receive-pack=/tmp/x,origin} main"`）、複合コマンド（`"git status && rm -rf build"`）、空文字列・`command` キー欠落・非文字列
- **THEN** いずれも `permissionDecision: deny` の JSON を出力する（内容を判定してから通す経路が無いことを検査する）

#### Scenario: 拒否理由に cwd と本体が commit する旨が含まれる

- **WHEN** 同じ状態で `cwd: "/path/to/worktree"`・`tool_name: "Bash"`・`command: "git status"` の payload を渡す
- **THEN** 理由に `/path/to/worktree` と「commit は本体が行う」が含まれ、`-C` や `-c` の文言は含まれない

#### Scenario: 通知の閾値と強制停止の閾値の間では拒否しない

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_CAP` 超・`DEV_WORKFLOW_CONTEXT_HARD_CAP` 以内の状態で `tool_name: "Edit"` または `tool_name: "Bash"`（`command: "git status"`）の PreToolUse payload を渡す
- **THEN** どちらも stdout 空・exit 0 で終わる（編集も Bash も通る）。必要なモデル診断は stderr にだけ出る

#### Scenario: 閾値の大小が逆なら何もしない

- **WHEN** `DEV_WORKFLOW_CONTEXT_HARD_CAP` が `DEV_WORKFLOW_CONTEXT_CAP` 以下に設定されている
- **THEN** PreToolUse は stdout 空・exit 0 で終わる。必要なモデル診断は stderr にだけ出る
