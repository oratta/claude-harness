## MODIFIED Requirements

### Requirement: サブエージェントのコンテキスト上限と手渡し
`plugins/dev-workflow/scripts/subagent-context.sh` は、対象のトランスクリプトの最後の assistant レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、1 行 JSON（`agent` / `file` / `context_tokens` / `calls` / `cap` / `over_cap`）を出力しなければならない（SHALL）。対象の指定は次の 2 通りとする（SHALL）: `--file <path>` はそのファイルを直接測る（`agent` はファイル名から導く）。`<agent-name>` は `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}/*/*/subagents/` 内の `agent-<id>.meta.json` の `name` が指定名と完全一致する場合、対応する実在の `agent-<id>.jsonl` を候補に加え、従来の名前 glob（`agent-*<name>-*.jsonl` と `agent-*<name>.jsonl`）による候補と統合して重複を除かなければならない（SHALL）。同名が複数あれば最初のレコードの `cwd` が現在のディレクトリと一致するものを優先し、その中でログの更新時刻が新しいものを選び、一致するものが無ければ全候補で最新のログを選ばなければならない（SHALL）。metadata が無い・`name` が一致しない・壊れている場合も従来のファイル名探索にフォールバックし、候補が無ければ `transcript not found` を含む JSON を出力して exit 1 としなければならない（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）で、上限超なら exit 2、上限以内なら exit 0、トランスクリプトが無い・usage が無い・読めないときは exit 1 とし、exit 1 は作業を止めない（fail-open。SHALL）。develop の本体は W / G を SendMessage で再開する前に毎回これを実行し、exit 2 なら再開せず、前回の return（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）と記録先を渡して新しい W / G を spawn しなければならない（MUST。モデルは変えない）。W は工程の終わりに必ず return し、手渡しで起こされた W は前任の return と記録先・ファイルの現状から再出発して前任の埋めた決定を再発明してはならない（MUST NOT）。昇格トリップワイヤーの一覧（`templates/escalation-tripwires.md`）は【コンテキスト上限 → 手渡し】を 4 として含み、rate-limit 実エラーの reactive 降格を 5 とする（SHALL）。

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
