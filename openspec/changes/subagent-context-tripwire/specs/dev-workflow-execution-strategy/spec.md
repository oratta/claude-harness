## MODIFIED Requirements

### Requirement: サブエージェントのコンテキスト上限と手渡し
`plugins/dev-workflow/scripts/subagent-context.sh` は、対象のトランスクリプトの最後の assistant レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、1 行 JSON（`agent` / `file` / `context_tokens` / `calls` / `cap` / `over_cap`）を出力しなければならない（SHALL）。対象の指定は次の 2 通りとする（SHALL）: `--file <path>` はそのファイルを直接測る（`agent` はファイル名から導く）。`<agent-name>` は名前付きサブエージェントのトランスクリプト（`${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*<name>*.jsonl`。同名が複数あれば最初のレコードの `cwd` が現在のディレクトリと一致するものを優先し、次に更新時刻が新しいもの）を名前 glob で探す fallback 経路とし、`isolation: "worktree"` で起こしたサブエージェントはファイル名に名前を含まないため見つからないことがある（SHALL。この取りこぼしは途中計測 hook が補う）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）で、上限超なら exit 2、上限以内なら exit 0、トランスクリプトが無い・usage が無い・読めないときは exit 1 とし、exit 1 は作業を止めない（fail-open。SHALL）。develop の本体は W / G を SendMessage で再開する前に毎回これを実行し、exit 2 なら再開せず、前回の return（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）と記録先を渡して新しい W / G を spawn しなければならない（MUST。モデルは変えない）。W は工程の終わりに必ず return し、手渡しで起こされた W は前任の return と記録先・ファイルの現状から再出発して前任の埋めた決定を再発明してはならない（MUST NOT）。昇格トリップワイヤーの一覧（`templates/escalation-tripwires.md`）は【コンテキスト上限 → 手渡し】を 4 として含み、rate-limit 実エラーの reactive 降格を 5 とする（SHALL）。

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

## ADDED Requirements

### Requirement: 起動の途中でコンテキストを測る hook

`plugins/dev-workflow/hooks/hooks.json` は、PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）に途中計測の hook スクリプト（`${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh`）を登録しなければならない（MUST）。hook は stdin の payload から `hook_event_name` / `session_id` / `transcript_path` / `agent_id` / `tool_name` / `tool_input` を読む（SHALL）。

計測対象は payload の `transcript_path` そのものではなく、`transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<transcript_path の親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出しなければならない（MUST）。`transcript_path` は hook が発火したセッションのトランスクリプトを指し、サブエージェントの中で発火した場合も親セッションのものを指すためである。導出したパスが存在しないときは `<transcript_path の親ディレクトリ>/<session_id>/subagents/` 以下を再帰的に `agent-<agent_id>.jsonl` で 1 段だけ探してよい（MAY。入れ子のサブエージェント）。

読み取りはファイル末尾の固定バイト（最大 256KB）だけを対象とし、そこに現れる最後の `assistant` レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を合算する（MUST）。トランスクリプトが 5MB でも hook 1 回の実行時間は 100ms 未満でなければならない（MUST）。

次のいずれかに当たるときは何も出力せず exit 0 で終わらなければならない（MUST。fail-open）: 環境変数 `DEV_WORKFLOW_CONTEXT_TRIPWIRE` が `off` ／ `python3` が無い ／ stdin が読めない・JSON でない ／ `agent_id` が無い（メインスレッドからの呼び出し） ／ 導出したトランスクリプトが無い・usage が読めない ／ 閾値の環境変数が正の整数でない ／ 閾値以内。

#### Scenario: agent_id が無い呼び出しは無音

- **WHEN** `agent_id` を含まない PostToolUse payload を hook に渡す
- **THEN** 何も出力せず exit 0 で終わる

#### Scenario: 上限内では無音

- **WHEN** 導出したトランスクリプトの最後の usage 合算が `DEV_WORKFLOW_CONTEXT_CAP` 以内である
- **THEN** 何も出力せず exit 0 で終わる

#### Scenario: 測れないときは止めない

- **WHEN** 導出したトランスクリプトが存在しない、または usage を持つ assistant レコードが末尾に無い
- **THEN** 何も出力せず exit 0 で終わる

#### Scenario: 全解除できる

- **WHEN** `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` を設定して閾値超の payload を渡す
- **THEN** 何も出力せず exit 0 で終わる

### Requirement: 上限超は PostToolUse で締めを通知する

PostToolUse で計測値が `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）を超えていたら、hook は Claude に見える形で「今の工程を締め、成果（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）を列挙して return せよ」という指示と、計測値・上限を出力しなければならない（MUST）。役割（W / R1 / G / decider）による出し分けをしてはならない（MUST NOT。全サブエージェント一律）。出力は 1 回あたり数行に抑え、ツールの実行結果を書き換えてはならない（MUST NOT）。

#### Scenario: 上限超で締めの指示が出る

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_CAP` を超える状態で PostToolUse payload を渡す
- **THEN** 締めて return せよという指示と計測値・上限を含む出力を返し、exit 0 で終わる

#### Scenario: 役割で出し分けない

- **WHEN** 同じ計測値で `agent_type` が異なる payload を渡す
- **THEN** どちらも同じ指示が出る

### Requirement: 強制停止の閾値を超えたら PreToolUse が編集を拒否する

PreToolUse で計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP`（既定 220000）を超えていたら、hook は `Edit` / `Write` / `NotebookEdit` を拒否しなければならない（MUST）。`Bash` は先頭コマンドが `git status` / `git diff` / `git add` / `git commit` / `git push` のいずれかであるときだけ許可し、それ以外（先頭コマンドが一致しない、またはパイプ・`&&`・サブシェル等で先頭コマンドを判定できない複合コマンド）は拒否する（MUST）。読み取り系ツール（Read / Grep / Glob）を拒否してはならない（MUST NOT）。拒否は `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":...}}` を stdout に出して exit 0 とし、理由に計測値・強制停止の閾値・「commit して return せよ」を含めなければならない（SHALL）。`DEV_WORKFLOW_CONTEXT_HARD_CAP` は `DEV_WORKFLOW_CONTEXT_CAP` より大きくなければならず、小さいか等しい場合は fail-open（何もしない）とする（MUST）。

#### Scenario: 強制停止の閾値超で Edit が拒否される

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP` を超える状態で `tool_name: "Edit"` の PreToolUse payload を渡す
- **THEN** `permissionDecision: deny` の JSON を出力し、理由に計測値と「commit して return」が含まれる

#### Scenario: git commit は通る

- **WHEN** 同じ状態で `tool_name: "Bash"`・`command: "git commit -m x"` の payload を渡す
- **THEN** 何も出力せず exit 0 で終わる（許可）

#### Scenario: 判定できない Bash は拒否側に倒す

- **WHEN** 同じ状態で `command: "git status && rm -rf build"` の payload を渡す
- **THEN** `permissionDecision: deny` の JSON を出力する

#### Scenario: 通知の閾値と強制停止の閾値の間では拒否しない

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_CAP` 超・`DEV_WORKFLOW_CONTEXT_HARD_CAP` 以内の状態で `tool_name: "Edit"` の PreToolUse payload を渡す
- **THEN** 何も出力せず exit 0 で終わる（編集は通る）

#### Scenario: 閾値の大小が逆なら何もしない

- **WHEN** `DEV_WORKFLOW_CONTEXT_HARD_CAP` が `DEV_WORKFLOW_CONTEXT_CAP` 以下に設定されている
- **THEN** PreToolUse は何も出力せず exit 0 で終わる

### Requirement: worktree 隔離のサブエージェントでも途中計測が効く

`isolation: "worktree"` で起こした名前付きサブエージェントのトランスクリプトは、非隔離のものと同じ `<projects>/<slug>/<親セッション ID>/subagents/` に置かれ、ファイル名だけが名前を含まない（`agent-<agentId>.jsonl`）。途中計測 hook は名前ではなく `agent_id` で対象を決めるため、隔離の有無で挙動が変わってはならない（MUST NOT）。

#### Scenario: 名前を含まないファイル名でも測れる

- **WHEN** `agent-a<16 桁 hex>.jsonl` という名前のトランスクリプトを対象に、その `agent_id` を含む payload を渡す
- **THEN** 名前 glob を使わずに対象を特定し、閾値超なら通知・拒否が出る
