## MODIFIED Requirements

### Requirement: 起動の途中でコンテキストを測る hook

`plugins/dev-workflow/hooks/hooks.json` は、PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）に途中計測の hook スクリプト（`${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh`）を登録しなければならない（MUST）。hook は stdin の payload から `hook_event_name` / `session_id` / `transcript_path` / `agent_id` / `tool_name` / `tool_input` を読む（SHALL）。

計測対象は payload の `transcript_path` そのものではなく、`transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<transcript_path の親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出しなければならない（MUST）。`transcript_path` は hook が発火したセッションのトランスクリプトを指し、サブエージェントの中で発火した場合も親セッションのものを指すためである。

導出したパスが存在しないときは `<transcript_path の親ディレクトリ>/<session_id>/subagents/` 以下を**深さ 3 段まで**（`subagents/` 直下を 1 段目と数える）`agent-<agent_id>.jsonl` で探してよい（MAY。入れ子のサブエージェント）。この探索は毎ツール呼び出しのコストになるため上限を設けなければならず（MUST）、走査したディレクトリエントリが 200 件を超えるか探索が 20ms を超えたら打ち切って何も出力せず exit 0 とする（SHALL）。

読み取りはファイル末尾の固定 256KB だけを対象とし、そこに現れる最後の `assistant` レコードの usage を合算する（MUST）。しきい値はこの計測レコードの `message.model` を使って共通処理から取得した `context_cap` / `context_hard_cap` とし、モデル入力・上書き・正数条件・診断は dev-workflow-token-thresholds の文脈計測の要件に従わなければならない（MUST）。この 256KB は環境変数で上書きできる形にしてはならない（MUST NOT。小さすぎる値を与えられると静かに fail-open して途中計測が全体で無効になるため。変更は仕様変更として扱う）。トランスクリプトが 5MB でも hook 1 回の実行時間は 100ms 未満でなければならない（MUST）。

`DEV_WORKFLOW_CONTEXT_TRIPWIRE` が `off` である・`python3` が無い・読み込んだ stdin が**メインスレッドからの呼び出しであることを JSON をパースせずに判定できる**のいずれかは、**python3 を起動する前に判定して** exit 0 しなければならない（MUST）。この hook は install 先の全ユーザーの全ツール呼び出しで走り、大多数がメインスレッドであるため、そこに python3 の起動コストを課してはならない（MUST NOT）。

パースせずに行うこの判定は、**JSON 意味論的に `agent_id` キーを持つ payload を早期 exit させてはならない**（MUST NOT）。JSON のキーは Unicode エスケープ（`\uXXXX`）でも書けるため、生文字列 `"agent_id"` の有無だけを見る判定では、同値な表記（`"\u0061gent_id"` など）の payload が無音で素通りする。判定は次の必要条件で行う（SHALL）: 生文字列 `"agent_id"` を含む、または 4 文字の並び `\u00` を含む payload は python3 に渡す。それ以外は早期 exit する。

この必要条件が成り立つ根拠は 2 つある。第一に、`\uXXXX` 以外の JSON 文字列エスケープが生む文字（`"` `\` `/` とバックスペース・改頁・改行・復帰・タブ）は `agent_id` を構成できないため、生表記でないキーは必ず `\uXXXX` を含む。第二に、`agent_id` の 8 文字はすべて U+005F〜U+0074 の範囲にあり、その `\uXXXX` 表記は上位 2 桁が必ず `00` になる（16 進の大文字小文字の揺れは下位 2 桁にしか現れない）。したがって前置は `\u00` に絞ってよい。

判定は必要条件であって十分条件ではなく、`agent_id` を持たない payload が python3 に渡ってよい（MAY）。その場合はパース後に `agent_id` フィールドが無いと判定され、何も出力せず exit 0 する。この向きの外し方が起きる頻度は payload の内容に依存する（PostToolUse の payload は `tool_response` を含むため、Read が読んだファイル内容・Bash の出力・Grep の結果にこの並びがあれば起動する。JSON シリアライザが `\b \f \n \r \t` 以外の制御文字を 4 桁 16 進で綴った出力も同じ）。判定を誤ってよいのはこの向き（余計に起動して無音で終わる）だけであり、逆向き（`agent_id` を持つ payload の早期 exit）は許されない（MUST NOT）。

次のいずれかに当たるときは何も出力せず exit 0 で終わらなければならない（MUST。fail-open）: 上の 3 つ ／ stdin が読めない・JSON でない ／ 導出したトランスクリプトが無い・usage が読めない ／ 探索の上限に達した。しきい値解決の失敗（共通処理の API 欠損・呼出し時の通常例外を含む）・解決値の正数条件違反は stdout 空・exit 0 とし、理由を stderr に出さなければならない（MUST）。再検証通知が無い閾値以内は stdout 空・exit 0 とし、fallback・再検証が必要なら stderr に診断を出す（MUST）。再検証通知があるときは、閾値以内でも stderr の診断に加えて、診断だけの単一 JSON（`hookSpecificOutput` の `hookEventName` と `additionalContext` のみ）を stdout に出して exit 0 とし、本人への通知経路とする（MUST）。出力の形・文面・決定フィールドを付けない規則は dev-workflow-token-thresholds の文脈計測の診断の要件に従う。共通処理の正常な fallback だけを理由に判定を無効にしてはならない（MUST NOT）。

守備範囲は、同梱表・共通処理の結果と payload・ログを入力元とし、閾値以内の無音を理由に再検証の必要が本人に届かない誤りと、診断だけでツールを止める誤りを拾う。通知の到達は出力検査と公式の配送規則を根拠とし、実機観測や入力の穴の完全封鎖を完了条件にしない。通してよい入力の例は、根拠に含まれる既知モデルで閾値以内の呼出し（stdout も stderr も空で通す）と、`agent_id` を持たないが `\u00` を含む payload（python3 を起動したうえで無音で通す）である。

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
- **THEN** 根拠に含まれる既知モデルなら stdout も stderr も空・exit 0 で終わる。fallback・再検証が必要なモデルなら stderr に診断が出ると同時に、stdout は `additionalContext` だけの再検証通知 JSON（拒否・締めの決定フィールドなし）になり、exit 0 で終わる

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
- **THEN** 実行時間が 100ms 未満で、stdout は閾値判定の結果と必要な再検証通知だけであり、必要なモデル診断は stderr にも出る

#### Scenario: 全解除できる

- **WHEN** `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` を設定して閾値超の payload を渡す
- **THEN** 何も出力せず exit 0 で終わる

### Requirement: 上限超は PostToolUse の additionalContext で締めを通知する

PostToolUse で計測値が `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）を超えていたら、hook は `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"…"}}` を stdout に出して exit 0 で終わらなければならない（MUST）。素の文字列を stdout に出して exit 0 とする形にしてはならない（MUST NOT）— PostToolUse の exit 0 の stdout はトランスクリプト表示（ctrl+o）にしか出ずモデルには届かないため、その形では通知が永久に無音になる。

`additionalContext` は次をすべて含まなければならない（MUST）: 計測値と `DEV_WORKFLOW_CONTEXT_CAP` の値 ／ 今の工程を締め、成果（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）を列挙して return せよという指示 ／ **return の 1 行目の書き分け**（そのとき進めていた tasks グループの項目がすべて済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:`）。この通知は役割で出し分けないため、`tasks.md` を持たない受け手にも届く。したがって「tasks グループ」の指すものを本文の中で一意にしなければならない（MUST）: **`tasks.md` が無い場合は本体から渡された作業項目、G は pr-review-gate の手順 1〜5 を 1 グループとみなす**。

利用する文脈指標の再検証通知がある場合は、この `additionalContext` の既存本文を変えずに保ち、別段落で再検証通知を追記してよい（MAY。本文の保持は MUST）。再検証通知の文面・出力規則は dev-workflow-token-thresholds の文脈計測の診断の要件に従う。

役割（W / R1 / G / decider）による出し分けをしてはならない（MUST NOT。全サブエージェント一律）。出力は 1 回あたり数行（再検証通知の段落を除く）に抑え、ツールの実行結果を書き換えてはならない（MUST NOT）。

守備範囲は、締め通知の本文・書式を入力元の計測値と上限から作る誤りと、再検証通知の追記で既存の締め指示が消える誤りを拾う。追記の文面の細部や入力の穴の完全封鎖は完了条件にしない。通してよい入力の例は、cap 以下の PostToolUse（締め通知は出さない。再検証通知だけは付きうる）と、`agent_type` の違う payload（同じ本文を出す）である。

#### Scenario: 上限超で締めの指示が additionalContext に出る

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_CAP` を超える状態で PostToolUse payload を渡す
- **THEN** stdout が JSON として解析でき、`hookSpecificOutput.hookEventName` が `PostToolUse`、`additionalContext` に締めて return せよという指示と計測値・上限が含まれ、exit 0 で終わる

#### Scenario: 通知は return の 1 行目の書き分けを含む

- **WHEN** 同じ payload で `additionalContext` を読む
- **THEN** tasks グループが全部済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:` を 1 行目にする旨と、`tasks.md` が無い場合に何を 1 グループとみなすか（本体から渡された作業項目、G は pr-review-gate の手順 1〜5）が含まれる

#### Scenario: 再検証通知は既存の締め通知を消さず別段落で足される

- **WHEN** 再検証通知が出る未知モデルで、計測値が `DEV_WORKFLOW_CONTEXT_CAP` を超える PostToolUse payload を渡し、出力を解析する
- **THEN** `additionalContext` は再検証通知が無い場合の本文をそのまま含み、そのあとの別段落に再検証通知を持つ。単一 JSON・exit 0

#### Scenario: 役割で出し分けない

- **WHEN** 同じ計測値で `agent_type` が異なる payload を渡す
- **THEN** どちらも同じ `additionalContext` が出る

### Requirement: 強制停止の閾値を超えたら PreToolUse が編集を拒否する

PreToolUse で計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP`（既定 220000）を超えていたら、hook は `Edit` / `Write` / `NotebookEdit` を拒否しなければならない（MUST）。読み取り系ツール（Read / Grep / Glob）を拒否してはならない（MUST NOT）。

`Bash` は**コマンド内容によらず拒否しなければならない**（MUST）。コマンド文字列を解析して一部の形だけを通す判定を置いてはならない（MUST NOT）。理由: 判定はこのプロセスの中でコマンド文字列をトークン化するが、実際に実行するのは別プロセスのシェル（zsh または bash）で、両者のトークン化は一致を保証できない。実際に、シェル側にだけ意味を持つ記法（zsh の ANSI-C クォート `$'…'`、シェルのブレース展開 `{a,b}` 等）を判定側が「危険でない 1 トークン」と誤認し、実行側では任意コマンドの引数に展開される迂回が 2 度にわたって実機で再現した（`git -c` の値読み飛ばし、および `git push $'--receive-pack=/tmp/x' origin main`）。受理する経路が 1 つでも残る限り、この種の迂回は形を変えて再発するため、`Bash` は内容を一切見ず全件拒否する構造に閉じる。

拒否は `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":...}}` を stdout に出して exit 0 とする（SHALL）。`permissionDecisionReason` は次をすべて含まなければならない（MUST）: 計測値と `DEV_WORKFLOW_CONTEXT_HARD_CAP` の値 ／ `Bash` はコマンド内容によらず一切通らないこと ／ payload の `cwd`（＝そのサブエージェントの作業ツリーのパス）／ 編集済みファイルの一覧と、その作業ツリーのパス（`cwd`）を return に書けという指示 ／ commit は本体が行うという指示（サブエージェント自身は commit できないため）／ **return の 1 行目は `工程中断:` にすること**（強制停止で止まった時点で予定していた作業が残っているため、常に中断とする）。`-C <path>` や `-c <k=v>` といった、通る形についての案内を含めてはならない（MUST NOT）— 通る形は存在しないため。利用する文脈指標の再検証通知がある場合は、`permissionDecision` と `permissionDecisionReason` を変更せず、同じ `hookSpecificOutput` に再検証の `additionalContext` を追加してよい（MAY。既存の拒否の保持は MUST）。

`DEV_WORKFLOW_CONTEXT_HARD_CAP` は `DEV_WORKFLOW_CONTEXT_CAP` より大きくなければならず、小さいか等しい場合は PreToolUse で拒否しない（MUST）。この場合の stdout は、再検証通知が無ければ空、あれば診断だけの JSON とし、exit 0 とする。必要なモデル診断はこの場合も stderr に出さなければならない（MUST）。

守備範囲は、閾値と対象ツールの判定を入力元とする拒否・非拒否の境界の誤りを拾う。再検証通知は拒否の条件を変えず、診断だけで拒否・締めを起こさない。入力の穴の完全封鎖は完了条件にしない。通してよい入力の例は、Read・Grep・Glob、cap 超かつ hard 以内の Edit・Bash、`hard <= cap` の設定での全ツールで、いずれも拒否しない（再検証通知の JSON は付きうる）。ここでの環境変数名は共通処理で解決した値を指し、モデル別既定値も同じ比較に使う。

#### Scenario: 強制停止の閾値超で Edit が拒否される

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP` を超える状態で `tool_name: "Edit"` の PreToolUse payload を渡す
- **THEN** `permissionDecision: deny` の JSON を出力し、理由に計測値と「commit は本体が行う」と `工程中断:` が含まれる

#### Scenario: 再検証通知があっても拒否の本文は変わらない

- **WHEN** 再検証通知が出るモデルで、計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP` を超える `Edit` と `Bash` の PreToolUse payload を渡し、出力を解析する
- **THEN** `permissionDecision` は `deny`、`permissionDecisionReason` は再検証通知が無い場合と同じ本文で、同じ `hookSpecificOutput` に再検証の `additionalContext` が加わる。exit 0

#### Scenario: Bash はどんな形でも拒否される

- **WHEN** 同じ状態で `tool_name: "Bash"` の PreToolUse payload を、`command` に次のいずれかを入れて渡す: 旧設計で許可していた形（`"git status"` / `"git -C /path/to/worktree commit -m x"` / `"git push -u origin br"`）、報告された迂回（`"git -c 'diff.external=sh -c \"touch /tmp/x\"' diff HEAD^ HEAD"`、zsh の ANSI-C クォートを使う `"git push $'--receive-pack=/tmp/x' origin main"`）、`$` を使わないブレース展開の変種（`"git push {--receive-pack=/tmp/x,origin} main"`）、複合コマンド（`"git status && rm -rf build"`）、空文字列・`command` キー欠落・非文字列
- **THEN** いずれも `permissionDecision: deny` の JSON を出力する（内容を判定してから通す経路が無いことを検査する）

#### Scenario: 拒否理由に cwd と本体が commit する旨が含まれる

- **WHEN** 同じ状態で `cwd: "/path/to/worktree"`・`tool_name: "Bash"`・`command: "git status"` の payload を渡す
- **THEN** 理由に `/path/to/worktree` と「commit は本体が行う」が含まれ、`-C` や `-c` の文言は含まれない

#### Scenario: 通知の閾値と強制停止の閾値の間では拒否しない

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_CAP` 超・`DEV_WORKFLOW_CONTEXT_HARD_CAP` 以内の状態で `tool_name: "Edit"` または `tool_name: "Bash"`（`command: "git status"`）の PreToolUse payload を渡す
- **THEN** どちらも拒否されず exit 0 で終わる（編集も Bash も通る）。stdout は再検証通知が無ければ空、あれば `additionalContext` だけの診断 JSON（`permissionDecision` なし）。必要なモデル診断は stderr にも出る

#### Scenario: 閾値の大小が逆なら何もしない

- **WHEN** `DEV_WORKFLOW_CONTEXT_HARD_CAP` が `DEV_WORKFLOW_CONTEXT_CAP` 以下に設定されている
- **THEN** PreToolUse は拒否せず exit 0 で終わる。stdout は再検証通知が無ければ空、あれば診断だけの JSON。必要なモデル診断は stderr にも出る
