## MODIFIED Requirements

### Requirement: サブエージェントのコンテキスト上限と手渡し
`plugins/dev-workflow/scripts/subagent-context.sh <agent-name>` は、名前付きサブエージェントのトランスクリプト（`${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*<name>*.jsonl`。同名が複数あれば最初のレコードの `cwd` が現在のディレクトリと一致するものを優先し、次に更新時刻が新しいもの）の最後の assistant レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、1 行 JSON（`agent` / `file` / `context_tokens` / `calls` / `cap` / `over_cap`）を出力しなければならない（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）で、上限超なら exit 2、上限以内なら exit 0、トランスクリプトが無い・usage が無い・読めないときは exit 1 とし、exit 1 は作業を止めない（fail-open。SHALL）。

**手渡してよいのは、前任が工程を終えて return したときだけである（MUST）。** コンテキスト上限超過（`subagent-context.sh` の exit 2）は単独では手渡しの十分条件にならず、「次に再開するときは手渡しに切り替える」という条件にすぎない。develop の本体は W / G を SendMessage で再開する前に毎回これを実行し、exit 2 かつ前任が return 済みのときにだけ再開せず、前回の return（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）と記録先を渡して新しい W / G を spawn しなければならない（MUST。モデルは変えない）。

前任がバックグラウンドのコマンド（テスト・ビルド等）の完了を待って idle になっている状態は、工程の終わりではない（MUST NOT 相当。手渡しの契機として扱ってはならない）。そのコマンドが終われば前任は再び動き出す。本体は return の内容が成果一覧（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）になっているか、「完了を待っています」「通知を待ちます」のような途中経過だけかで、工程の終わりかどうかを見分けなければならない（MUST）。

前任がまだ動いている状態でコンテキスト上限超過が判明し、それでも交代させる必要がある場合は、本体は先に前任へ停止を指示し（自分で元に戻そうとしないこと＝破壊的 git 操作をしないことを含める）、停止確認（何を編集したか・何を投稿したかの報告）を受け取ってから手渡し先を spawn しなければならない（MUST）。停止確認を受け取る前に手渡し先を spawn してはならない（MUST NOT）。

1 つの作業ディレクトリで同時に動く同一役割のサブエージェントは常に 1 人である（SHALL）。これは並列に回してよい単位（エピックの子どうし、独立した change の W どうし）が別々の worktree を持つこととは矛盾しない。

W は工程の終わりに必ず return し、手渡しで起こされた W は前任の return と記録先・ファイルの現状から再出発して前任の埋めた決定を再発明してはならない（MUST NOT）。昇格トリップワイヤーの一覧（`templates/escalation-tripwires.md`）は【コンテキスト上限 → 手渡し】を 4 として含み、rate-limit 実エラーの reactive 降格を 5 とする（SHALL）。

#### Scenario: コンテキスト上限超過で手渡す
- **WHEN** 本体が W を SendMessage で再開しようとして `subagent-context.sh` が exit 2 を返す
- **AND** 前任 W の直近の return が成果一覧（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）になっている
- **THEN** 本体は再開せず、前回の return と記録先を渡して新しい W を spawn する

#### Scenario: コンテキスト上限超過だが前任がまだ idle なだけ
- **WHEN** 本体が `subagent-context.sh` で exit 2 を検知した時点で、前任 W の直近の応答がバックグラウンドコマンドの完了通知待ちの途中経過（成果一覧になっていない）
- **THEN** 本体はその場で手渡し先を spawn しない
- **AND** 交代させる必要があるなら、先に前任へ停止を指示し、停止確認（編集・投稿した内容の報告）を受け取ってから手渡し先を spawn する

#### Scenario: 同一作業ディレクトリに同一役割が並ばない
- **GIVEN** ある worktree で W が稼働中である
- **THEN** 本体はその worktree に対して別の W をもう 1 人 spawn しない（手渡し・再開のいずれであっても、前任が停止確認を返すまで新しい W を同じ worktree に置かない）
- **AND** 別々の worktree を持つ並列 W（エピックの子どうし・独立した change どうし）はこの制約の対象外である

#### Scenario: `subagent-context.sh` が対象のトランスクリプトを見つけられない
- **WHEN** `subagent-context.sh` が対象のトランスクリプトを見つけられない
- **THEN** exit 1（fail-open）を返し、作業は止まらない
