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

### Requirement: コンテキスト量の計測の式は 1 つに定める

サブエージェントのコンテキスト量は、対象のトランスクリプト（JSONL）に現れる**最後の `assistant` レコードの `usage`** から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を合算した値とする（MUST）。`plugins/dev-workflow/scripts/subagent-context.sh` と `plugins/dev-workflow/scripts/context-tripwire.sh` はこの同じ式で計測しなければならない（MUST）。

両者は**計測ロジックを共有ファイルに抽出してはならない**（MUST NOT）。`subagent-context.sh` は全行走査で本体の再開前チェックに使い、`context-tripwire.sh` は末尾固定バイトの読み取りで毎ツール呼び出しに使うため、実装上の制約が異なる。共有するのは式であって実装ではない。

#### Scenario: 2 本のスクリプトが同じトランスクリプトに同じ値を返す

- **WHEN** 同じトランスクリプトを `subagent-context.sh --file <path>` と `context-tripwire.sh`（導出先が同じになる payload）の両方で測る
- **THEN** どちらも同じ `context_tokens` を計測結果として扱う

### Requirement: 起動の途中でコンテキストを測る hook

`plugins/dev-workflow/hooks/hooks.json` は、PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）に途中計測の hook スクリプト（`${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh`）を登録しなければならない（MUST）。hook は stdin の payload から `hook_event_name` / `session_id` / `transcript_path` / `agent_id` / `tool_name` / `tool_input` を読む（SHALL）。

計測対象は payload の `transcript_path` そのものではなく、`transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<transcript_path の親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出しなければならない（MUST）。`transcript_path` は hook が発火したセッションのトランスクリプトを指し、サブエージェントの中で発火した場合も親セッションのものを指すためである。

導出したパスが存在しないときは `<transcript_path の親ディレクトリ>/<session_id>/subagents/` 以下を**深さ 3 段まで**（`subagents/` 直下を 1 段目と数える）`agent-<agent_id>.jsonl` で探してよい（MAY。入れ子のサブエージェント）。この探索は毎ツール呼び出しのコストになるため上限を設けなければならず（MUST）、走査したディレクトリエントリが 200 件を超えるか探索が 20ms を超えたら打ち切って何も出力せず exit 0 とする（SHALL）。

読み取りはファイル末尾の固定 256KB だけを対象とし、そこに現れる最後の `assistant` レコードの usage を合算する（MUST）。この 256KB は環境変数で上書きできる形にしてはならない（MUST NOT。小さすぎる値を与えられると静かに fail-open して途中計測が全体で無効になるため。変更は仕様変更として扱う）。トランスクリプトが 5MB でも hook 1 回の実行時間は 100ms 未満でなければならない（MUST）。

`DEV_WORKFLOW_CONTEXT_TRIPWIRE` が `off` である・`python3` が無い・読み込んだ stdin が文字列 `"agent_id"` を含まない（メインスレッドからの呼び出し）のいずれかは、**python3 を起動する前に判定して** exit 0 しなければならない（MUST）。この hook は install 先の全ユーザーの全ツール呼び出しで走り、大多数がメインスレッドであるため、そこに python3 の起動コストを課してはならない（MUST NOT）。

次のいずれかに当たるときは何も出力せず exit 0 で終わらなければならない（MUST。fail-open）: 上の 3 つ ／ stdin が読めない・JSON でない ／ 導出したトランスクリプトが無い・usage が読めない ／ 探索の上限に達した ／ 閾値の環境変数が正の整数でない ／ 閾値以内。

#### Scenario: agent_id が無い呼び出しは python3 を起動せず無音

- **WHEN** `agent_id` を含まない PostToolUse payload を hook に渡す
- **THEN** python3 を起動せずに、何も出力せず exit 0 で終わる

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

#### Scenario: 全解除できる

- **WHEN** `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` を設定して閾値超の payload を渡す
- **THEN** 何も出力せず exit 0 で終わる

### Requirement: 上限超は PostToolUse の additionalContext で締めを通知する

PostToolUse で計測値が `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）を超えていたら、hook は `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"…"}}` を stdout に出して exit 0 で終わらなければならない（MUST）。素の文字列を stdout に出して exit 0 とする形にしてはならない（MUST NOT）— PostToolUse の exit 0 の stdout はトランスクリプト表示（ctrl+o）にしか出ずモデルには届かないため、その形では通知が永久に無音になる。

`additionalContext` は次をすべて含まなければならない（MUST）: 計測値と `DEV_WORKFLOW_CONTEXT_CAP` の値 ／ 今の工程を締め、成果（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）を列挙して return せよという指示 ／ **return の 1 行目の書き分け**（そのとき進めていた tasks グループの項目がすべて済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:`）。

役割（W / R1 / G / decider）による出し分けをしてはならない（MUST NOT。全サブエージェント一律）。出力は 1 回あたり数行に抑え、ツールの実行結果を書き換えてはならない（MUST NOT）。

#### Scenario: 上限超で締めの指示が additionalContext に出る

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_CAP` を超える状態で PostToolUse payload を渡す
- **THEN** stdout が JSON として解析でき、`hookSpecificOutput.hookEventName` が `PostToolUse`、`additionalContext` に締めて return せよという指示と計測値・上限が含まれ、exit 0 で終わる

#### Scenario: 通知は return の 1 行目の書き分けを含む

- **WHEN** 同じ payload で `additionalContext` を読む
- **THEN** tasks グループが全部済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:` を 1 行目にする旨が含まれる

#### Scenario: 役割で出し分けない

- **WHEN** 同じ計測値で `agent_type` が異なる payload を渡す
- **THEN** どちらも同じ `additionalContext` が出る

### Requirement: 強制停止の閾値を超えたら PreToolUse が編集を拒否する

PreToolUse で計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP`（既定 220000）を超えていたら、hook は `Edit` / `Write` / `NotebookEdit` を拒否しなければならない（MUST）。読み取り系ツール（Read / Grep / Glob）を拒否してはならない（MUST NOT）。

`Bash` の許可判定は、**先頭トークンが `git` であり、`-C <path>` / `-c <k=v>` を読み飛ばした次のトークンが `status` / `diff` / `add` / `commit` / `push` のいずれか**であるときだけ許可とする（MUST）。`git` のグローバルオプションを読み飛ばすことは必須で（MUST）、worktree 作業では `git -C <worktree のパス> commit` を常用するため、素朴な先頭一致では commit できず「commit して return できる状態を残す」という強制停止の目的が達成できない。それ以外（先頭トークンが `git` でない、サブコマンドが許可リストに無い、またはパイプ・`&&`・`;`・サブシェル・コマンド置換 `$(…)` を含んで先頭コマンドを判定できない複合コマンド）は拒否する（MUST）。

拒否は `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":...}}` を stdout に出して exit 0 とする（SHALL）。`permissionDecisionReason` は次をすべて含まなければならない（MUST）: 計測値と `DEV_WORKFLOW_CONTEXT_HARD_CAP` の値 ／ commit して return せよという指示 ／ **return の 1 行目は `工程中断:` にすること**（強制停止で止まった時点で予定していた作業が残っているため、常に中断とする） ／ コマンド置換を含む Bash を拒否した場合は**回避手段**（「commit メッセージは `-m` を複数回に分けて 1 行ずつ渡せ。`$(…)` は拒否される」）。回避手段を書かない拒否理由は、Claude が次の手を取れず目的を達成できないため許されない（MUST NOT）。

`DEV_WORKFLOW_CONTEXT_HARD_CAP` は `DEV_WORKFLOW_CONTEXT_CAP` より大きくなければならず、小さいか等しい場合は fail-open（何もしない）とする（MUST）。

#### Scenario: 強制停止の閾値超で Edit が拒否される

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP` を超える状態で `tool_name: "Edit"` の PreToolUse payload を渡す
- **THEN** `permissionDecision: deny` の JSON を出力し、理由に計測値と「commit して return」と `工程中断:` が含まれる

#### Scenario: worktree 作業の git -C commit は通る

- **WHEN** 同じ状態で `tool_name: "Bash"`・`command: "git -C /path/to/worktree commit -m x"` の payload を渡す
- **THEN** 何も出力せず exit 0 で終わる（許可）

#### Scenario: コマンド置換は拒否され、理由に回避手段が付く

- **WHEN** 同じ状態で `command: "git commit -m \"$(printf 'x')\""` の payload を渡す
- **THEN** `permissionDecision: deny` の JSON を出力し、理由に「`-m` を複数回に分けて 1 行ずつ渡せ」が含まれる

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

実セッションでの確認（小さい閾値を与えてサブエージェントを起こし、通知・拒否が出ることをトランスクリプトで見る）は、**worktree 隔離されていないセッションから実行しなければならない**（MUST）。隔離エージェントからは `claude` の起動そのものがガードに拒否されるためである。確認の証拠には、観測した `agent_id` の実値と実ファイル名の対を含めなければならない（MUST）。

#### Scenario: 名前を含まないファイル名でも測れる

- **WHEN** `agent-a<16 桁 hex>.jsonl` という名前のトランスクリプトを対象に、その `agent_id` を含む payload を渡す
- **THEN** 名前 glob を使わずに対象を特定し、閾値超なら通知・拒否が出る

#### Scenario: 実地確認の証拠に agent_id とファイル名の対が含まれる

- **WHEN** 実セッションでの確認の証拠を読む
- **THEN** payload で観測した `agent_id` の実値と、それに対応するトランスクリプトの実ファイル名が対で記録されている
