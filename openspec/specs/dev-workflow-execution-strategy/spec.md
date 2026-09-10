# dev-workflow-execution-strategy Specification

## Purpose
TBD - created by archiving change dev-workflow-execution-strategy. Update Purpose after archive.
## Requirements
### Requirement: 残量モードによる閾値調整
役割のモデル選択は環境変数 `FABLE_BUDGET_MODE`（`abundant` / `conserve` / `reserve` / `exhausted`）を参照しなければならない（SHALL）。定義表は develop スキルの `plugins/dev-workflow/skills/develop/references/decision-criteria.md` に置く（SHALL）。未設定時は usage snapshot からの自動導出結果を用い、snapshot も無ければ `conserve` として扱う。明示的に設定された `FABLE_BUDGET_MODE` は自動導出より優先されなければならない（SHALL）。モードが変えるのは役割（W / R1 / G）の昇格上限のみであり、1 ループの構造・トリップワイヤーは変えない。`abundant` はどの役割の既定モデルも押し上げてはならない（MUST NOT）。Fable が使えるのは決める役（`dev-workflow:decider` として spawn される役）だけであり、実行役（W）の上限はどのモードでも `opus` である（SHALL）。`exhausted` は Fable 週次枠を実質使い切った状態を表し、`reserve` と異なり interactive を含む全経路で Fable をいかなる役割でも使わず、決める役も `opus` に落とす。Fable 残量モードは Fable と Opus のあいだで役割を付け替える装置であり総量を絞る装置ではないため、総量の下限は共有枠モード（別 Requirement）が決める。

#### Scenario: 未設定かつ snapshot 無しは conserve
- **WHEN** `FABLE_BUDGET_MODE` が未設定で usage snapshot も存在しないまま役割のモデルを決める
- **THEN** conserve（役割表の既定どおり。W = Sonnet、R1 = Opus、G = Sonnet。Fable は決める役の種別で spawn されるときだけ）として判定する

#### Scenario: 明示 env は自動導出より優先
- **WHEN** `FABLE_BUDGET_MODE` が明示設定されており、かつ usage snapshot も存在する
- **THEN** 自動導出結果を無視して明示された値を用いる

#### Scenario: abundant は既定を上げない
- **WHEN** `FABLE_BUDGET_MODE=abundant` で役割のモデルを決める
- **THEN** W / R1 / G の既定は役割表のまま（Fable は決める役の種別だけ）。結果が変わらない機械的な大量仕事（fan-out ワーカー・機械的編集）も安いモデルのまま

#### Scenario: exhausted は全経路で Fable を使わない
- **WHEN** `FABLE_BUDGET_MODE=exhausted`（明示または自動導出）のセッションで役割・昇格を判定する
- **THEN** interactive / unmanned を問わず Fable をいかなる役割でも使わず、決める役も `subagent_type: dev-workflow:decider` のまま `model: opus` に切り替える（種別は変えない）

#### Scenario: ガードは残量モードを見ない
- **WHEN** `FABLE_BUDGET_MODE=exhausted` の環境で `dev-workflow:decider` に `model: "fable"` を渡す
- **THEN** ガードは許可する（残量による抑制は develop 側の役割選択が行い、ガードは種別だけを見る）

### Requirement: reserve モードでは自動実行が Fable を使わない
`FABLE_BUDGET_MODE=reserve` のとき、自動実行（unmanned モード・cron・loop 経由の無人セッション）は Fable をいかなる役割（W / R1 / G）でも使ってはならない（MUST NOT）。無人時の昇格ラダーは Opus を上限とし、Opus でも解決しない問題は needs-approval で人間に返す。interactive セッションでは conserve と同じ扱いとし、人間の Fable 利用は妨げない。

#### Scenario: reserve 中の unmanned 昇格
- **WHEN** `FABLE_BUDGET_MODE=reserve` の unmanned サイクルで失敗ループのトリップワイヤーを踏む
- **THEN** W は Opus までしか昇格せず、Opus でも2連続失敗が続く場合は記録先に needs-approval を付けて経緯をコメントしサイクルを終了する

#### Scenario: reserve 中の interactive は制限されない
- **WHEN** `FABLE_BUDGET_MODE=reserve` の interactive セッションでユーザーが作業する
- **THEN** 判定は conserve と同一に振る舞い、ユーザー自身の Fable 利用（/model 切替等）を妨げる指示を出さない

### Requirement: Step B 基準の重心移動
develop スキルの `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の仕様化要否（Step B）は、「設計判断・トレードオフを含むか（= 意図と決定の記録価値があるか)」を一次基準としなければならない（SHALL）。受け入れ条件が記録先（issue または Draft PR 本文）に明記された機械的な振る舞い変更は、記録先とテストを記録として spec 化を省略できる。テスト作成の必須性はいかなる判定でも緩めてはならない（MUST NOT）。unmanned モードの「迷ったら spec 化に倒す」は維持する。

#### Scenario: 機械的な振る舞い変更は spec を省略できる
- **WHEN** 受け入れ条件が記録先に明記され、設計判断（トレードオフの選択）を含まない振る舞い変更を interactive で判定する
- **THEN** spec 化を省略してコード直行し、テストは必ず先に書く

#### Scenario: unmanned は安全側を維持
- **WHEN** unmanned モードで spec 化要否の判断がつかない
- **THEN** spec 化する側に倒す

### Requirement: usage snapshot からの残量モード自動導出
`FABLE_BUDGET_MODE` が明示設定されていないとき、残量モードは usage snapshot（`fable_weekly_pct` / `fable_active` / 週次リセット時刻を含む）から自動導出されなければならない（SHALL）。導出ルールは develop スキルの `plugins/dev-workflow/skills/develop/references/decision-criteria.md` に定義し、次の優先順位に従う: ① `fable_weekly_pct` が読めない/snapshot 無し → `conserve` ② `fable_weekly_pct > 90` → `exhausted` ③ `fable_weekly_pct <= 週経過%`（週次リセット時刻から算出）→ `abundant` ④ それ以外 → `conserve`。導出は「Fable の消費ペースが週の経過ペースを上回るか」のバーンレート比較であることを明記する。

#### Scenario: 消費が週経過より遅ければ abundant
- **WHEN** snapshot の `fable_weekly_pct` が週経過% 以下で、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは abundant に導出される

#### Scenario: 消費が週経過を上回れば conserve
- **WHEN** snapshot の `fable_weekly_pct` が週経過% を超え、かつ 90 以下で、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは conserve に導出される

#### Scenario: 90% 超は exhausted
- **WHEN** snapshot の `fable_weekly_pct` が 90 を超え、`FABLE_BUDGET_MODE` が未設定
- **THEN** 残量モードは exhausted に導出される

### Requirement: 共有枠モードが役割の既定モデルの下限を決める
`scripts/session-tripwires.sh` は usage snapshot の `weekly_all_pct`（全モデル共通の週次枠の消化率）から共有枠モード `SHARED_BUDGET_MODE` を導出し、Fable 残量モードと並べてセッション文脈に注入しなければならない（SHALL）。導出の優先順位: ① 明示 env `SHARED_BUDGET_MODE` ② `weekly_all_pct` が読めない / snapshot 無し → `ok` ③ `weekly_all_pct > 90` → `depleted` ④ `weekly_all_pct` が週経過%（週次リセット時刻から算出）より大きい → `throttled` ⑤ それ以外 → `ok`。効果は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の表に置く（SHALL）: `ok` は制約なし、`throttled` は W / R1 / G の既定を Sonnet に落とし昇格上限 Opus・`abundant` の押し上げ無効、`depleted` は全役割 Sonnet 固定・昇格なし（事前分類に当たっても Fable / Opus を使わない）。Fable 残量モードと共有枠モードが食い違うときは共有枠モードの下限が勝たなければならない（MUST）。導出は Fable 残量モードの導出を変えてはならない（MUST NOT）。

#### Scenario: Fable が余っていても全モデル枠が速く減っていれば throttled
- **WHEN** snapshot の `fable_weekly_pct` が週経過% 以下（abundant）で、`weekly_all_pct` が週経過% より大きく 90 以下
- **THEN** `FABLE_BUDGET_MODE` は abundant、`SHARED_BUDGET_MODE` は throttled と注入され、役割の既定は Sonnet 起点になる

#### Scenario: 全モデル枠 90% 超は depleted
- **WHEN** snapshot の `weekly_all_pct` が 90 を超え、`SHARED_BUDGET_MODE` が未設定
- **THEN** 共有枠モードは depleted に導出される

#### Scenario: データが無ければ ok
- **WHEN** snapshot が無い、または `weekly_all_pct` が読めない
- **THEN** 共有枠モードは ok（制約なし）に導出され、Fable 残量モードの導出は従来どおり conserve に倒れる

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

### Requirement: model 未指定の Agent spawn は hook が拒否する
`hooks/hooks.json` は PreToolUse（matcher: `Agent`）に `scripts/agent-model-guard.sh` を登録しなければならない（MUST）。hook は stdin の payload（`tool_name` / `tool_input`）を読み、`tool_name` が `Agent` 以外なら何もしない。`tool_input.subagent_type` が `fork` なら `model` の有無にかかわらず共有枠モード（明示 env `SHARED_BUDGET_MODE`、無ければ usage snapshot の `weekly_all_pct` から導出。90 超は `depleted`、週経過% 超は `throttled`）が `ok` のときだけ許可し、それ以外は拒否する（MUST。fork は model パラメータを無視して親モデルで動くため）。

fork 以外で `model` が Fable（エイリアス `fable`、または `claude-fable-*` の完全 ID。大文字小文字と前後の空白を無視して判定する）を指す場合は、`subagent_type` が決める役の allowlist（`dev-workflow:decider`。将来増えたらスクリプト内の allowlist に足す）に載っているときだけ許可し、それ以外（`general-purpose` / `Explore` / `Plan` / 未指定 / 他のプラグイン種別）は拒否しなければならない（MUST）。拒否理由には決める役の種別名 `dev-workflow:decider` と、実行役の代替（`sonnet` / `opus`）と、規範（`rules/subagent-model-selection.md`）を含める（SHALL）。この判定はセッションの種類（対話 / 住人 / cron / loop）で変えてはならない（MUST NOT）。Fable 判定は残量（`FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` / usage snapshot）をいっさい参照してはならない（MUST NOT。ガードは「誰が Fable になりうるか」の構造上の上限を見る層で、「今 Fable を使ってよいか」の助言は従来どおり develop 側の残量モードが担う。ガードが snapshot を読むと判定が鮮度と fail-open に依存してしまう）。既存の `fork` 判定が `SHARED_BUDGET_MODE` を見ることと、全解除の `DEV_WORKFLOW_MODEL_GUARD=off` はこの制限の対象外で、従来どおり残す（SHALL）。

Fable 以外の `model` があれば許可し、定義側に model を持つエージェント種別（`plugin:agent` 形式・casting 系）も許可する。`subagent_type` が空・`general-purpose`・`Explore`・`Plan`・`claude`・`claude-code-guide`・`statusline-setup` で `model` が無ければ拒否する（MUST）。拒否は `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":...}}` を stdout に出して exit 0 とし、理由に規範（rules/subagent-model-selection.md）と選ぶべきティアを含める（SHALL）。`model` 未指定の拒否理由に列挙するティアは `haiku`（機械的）/ `sonnet`（通常実装・調査）/ `opus`（設計・レビュー）とし、`fable` は決める役の種別でだけ使えることを添える（SHALL）。payload は環境変数や引数に載せず stdin から読む（MUST。長い prompt で ARG_MAX を超えると hook が非 0 で落ちて素通りになるため）。stdin が読めない・python3 が無い・snapshot が読めないときは fail-open（exit 0・無出力）とし、`DEV_WORKFLOW_MODEL_GUARD=off` で全許可できる（SHALL）。

#### Scenario: model 無しの general-purpose は拒否される
- **WHEN** `{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}` を hook に渡す
- **THEN** `permissionDecision: deny` の JSON が出力され、理由に `subagent-model-selection` と `sonnet` が含まれる

#### Scenario: general-purpose への fable は拒否される
- **WHEN** `{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","model":"fable"}}` を hook に渡す
- **THEN** `permissionDecision: deny` の JSON が出力され、理由に `dev-workflow:decider` と `sonnet` / `opus` の代替が含まれる

#### Scenario: 完全 ID の Fable も同じ扱い
- **WHEN** `model` が `claude-fable-5-1` の `general-purpose` 呼び出しを渡す
- **THEN** エイリアス `fable` と同じく拒否される

#### Scenario: subagent_type 未指定・Explore・Plan・他プラグイン種別への fable も拒否される
- **WHEN** `subagent_type` を省いた、あるいは `Explore` / `Plan` / `casting:casting-arbiter` を指定した `model: "fable"` の呼び出しを渡す
- **THEN** いずれも拒否される

#### Scenario: 決める役の種別への fable は通る
- **WHEN** `{"tool_name":"Agent","tool_input":{"subagent_type":"dev-workflow:decider","model":"fable"}}` を渡す
- **THEN** 無出力・exit 0 で許可される

#### Scenario: 実行役のモデルは従来どおり通る
- **WHEN** `general-purpose` に `model` が `opus` / `sonnet` / `haiku` の呼び出しを渡す
- **THEN** いずれも無出力・exit 0 で許可される

#### Scenario: fork は共有枠モードで決まり model を渡しても変わらない
- **WHEN** `SHARED_BUDGET_MODE=depleted` で `{"tool_name":"Agent","tool_input":{"subagent_type":"fork","model":"sonnet"}}` を渡す
- **THEN** 拒否される。`SHARED_BUDGET_MODE` 未設定かつ snapshot 無しなら許可される

#### Scenario: 3MB の prompt でも判定される
- **WHEN** `prompt` が 3,000,000 文字の model 無し payload を stdin から渡す
- **THEN** exit 0 で拒否の JSON が出る（ARG_MAX で落ちない）

#### Scenario: 全解除は従来どおり効く
- **WHEN** `DEV_WORKFLOW_MODEL_GUARD=off` で `general-purpose` への `model: "fable"` を渡す
- **THEN** 無出力・exit 0 で許可される

#### Scenario: hooks.json に配線されている
- **WHEN** `hooks/hooks.json` を読む
- **THEN** `PreToolUse` に matcher `Agent`・command `${CLAUDE_PLUGIN_ROOT}/scripts/agent-model-guard.sh` のエントリがある

### Requirement: コンテキスト量の計測の式は 1 つに定める

サブエージェントのコンテキスト量は、対象のトランスクリプト（JSONL）に現れる**最後の `assistant` レコードの `usage`** から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を合算した値とする（MUST）。`plugins/dev-workflow/scripts/subagent-context.sh` と `plugins/dev-workflow/scripts/context-tripwire.sh` はこの同じ式で計測しなければならない（MUST）。

両者は**計測ロジックを共有ファイルに抽出してはならない**（MUST NOT）。`subagent-context.sh` は全行走査で本体の再開前チェックに使い、`context-tripwire.sh` は末尾固定バイトの読み取りで毎ツール呼び出しに使うため、実装上の制約が異なる。共有するのは式であって実装ではない。

#### Scenario: 2 本のスクリプトが同じトランスクリプトに同じ値を返す

- **WHEN** **末尾 256KB に最後の `assistant` usage が含まれる**トランスクリプトを、`subagent-context.sh --file <path>` と `context-tripwire.sh`（導出先が同じになる payload）の両方で測る
- **THEN** どちらも同じ `context_tokens` を計測結果として扱う（`context-tripwire.sh` は上限内だと無音なので、比較は `DEV_WORKFLOW_CONTEXT_CAP` を小さくして `additionalContext` 中の計測値を読む形で行う）

### Requirement: 起動の途中でコンテキストを測る hook

`plugins/dev-workflow/hooks/hooks.json` は、PostToolUse（全ツール）と PreToolUse（`Edit|Write|NotebookEdit|Bash`）に途中計測の hook スクリプト（`${CLAUDE_PLUGIN_ROOT}/scripts/context-tripwire.sh`）を登録しなければならない（MUST）。hook は stdin の payload から `hook_event_name` / `session_id` / `transcript_path` / `agent_id` / `tool_name` / `tool_input` を読む（SHALL）。

計測対象は payload の `transcript_path` そのものではなく、`transcript_path` の親ディレクトリ・`session_id`・`agent_id` から `<transcript_path の親ディレクトリ>/<session_id>/subagents/agent-<agent_id>.jsonl` として導出しなければならない（MUST）。`transcript_path` は hook が発火したセッションのトランスクリプトを指し、サブエージェントの中で発火した場合も親セッションのものを指すためである。

導出したパスが存在しないときは `<transcript_path の親ディレクトリ>/<session_id>/subagents/` 以下を**深さ 3 段まで**（`subagents/` 直下を 1 段目と数える）`agent-<agent_id>.jsonl` で探してよい（MAY。入れ子のサブエージェント）。この探索は毎ツール呼び出しのコストになるため上限を設けなければならず（MUST）、走査したディレクトリエントリが 200 件を超えるか探索が 20ms を超えたら打ち切って何も出力せず exit 0 とする（SHALL）。

読み取りはファイル末尾の固定 256KB だけを対象とし、そこに現れる最後の `assistant` レコードの usage を合算する（MUST）。この 256KB は環境変数で上書きできる形にしてはならない（MUST NOT。小さすぎる値を与えられると静かに fail-open して途中計測が全体で無効になるため。変更は仕様変更として扱う）。トランスクリプトが 5MB でも hook 1 回の実行時間は 100ms 未満でなければならない（MUST）。

`DEV_WORKFLOW_CONTEXT_TRIPWIRE` が `off` である・`python3` が無い・読み込んだ stdin が**メインスレッドからの呼び出しであることを JSON をパースせずに判定できる**のいずれかは、**python3 を起動する前に判定して** exit 0 しなければならない（MUST）。この hook は install 先の全ユーザーの全ツール呼び出しで走り、大多数がメインスレッドであるため、そこに python3 の起動コストを課してはならない（MUST NOT）。

パースせずに行うこの判定は、**JSON 意味論的に `agent_id` キーを持つ payload を早期 exit させてはならない**（MUST NOT）。JSON のキーは Unicode エスケープ（`\uXXXX`）でも書けるため、生文字列 `"agent_id"` の有無だけを見る判定では、同値な表記（`"\u0061gent_id"` など）の payload が無音で素通りする。判定は次の必要条件で行う（SHALL）: 生文字列 `"agent_id"` を含む、または 4 文字の並び `\u00` を含む payload は python3 に渡す。それ以外は早期 exit する。

この必要条件が成り立つ根拠は 2 つある。第一に、`\uXXXX` 以外の JSON 文字列エスケープが生む文字（`"` `\` `/` とバックスペース・改頁・改行・復帰・タブ）は `agent_id` を構成できないため、生表記でないキーは必ず `\uXXXX` を含む。第二に、`agent_id` の 8 文字はすべて U+005F〜U+0074 の範囲にあり、その `\uXXXX` 表記は上位 2 桁が必ず `00` になる（16 進の大文字小文字の揺れは下位 2 桁にしか現れない）。したがって前置は `\u00` に絞ってよい。

判定は必要条件であって十分条件ではなく、`agent_id` を持たない payload が python3 に渡ってよい（MAY）。その場合はパース後に `agent_id` フィールドが無いと判定され、何も出力せず exit 0 する。この向きの外し方が起きる頻度は payload の内容に依存する（PostToolUse の payload は `tool_response` を含むため、Read が読んだファイル内容・Bash の出力・Grep の結果にこの並びがあれば起動する。JSON シリアライザが `\b \f \n \r \t` 以外の制御文字を 4 桁 16 進で綴った出力も同じ）。判定を誤ってよいのはこの向き（余計に起動して無音で終わる）だけであり、逆向き（`agent_id` を持つ payload の早期 exit）は許されない（MUST NOT）。

次のいずれかに当たるときは何も出力せず exit 0 で終わらなければならない（MUST。fail-open）: 上の 3 つ ／ stdin が読めない・JSON でない ／ 導出したトランスクリプトが無い・usage が読めない ／ 探索の上限に達した ／ 閾値の環境変数が正の整数でない ／ 閾値以内。

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

`additionalContext` は次をすべて含まなければならない（MUST）: 計測値と `DEV_WORKFLOW_CONTEXT_CAP` の値 ／ 今の工程を締め、成果（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）を列挙して return せよという指示 ／ **return の 1 行目の書き分け**（そのとき進めていた tasks グループの項目がすべて済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:`）。この通知は役割で出し分けないため、`tasks.md` を持たない受け手にも届く。したがって「tasks グループ」の指すものを本文の中で一意にしなければならない（MUST）: **`tasks.md` が無い場合は本体から渡された作業項目、G は pr-review-gate の手順 1〜5 を 1 グループとみなす**。

役割（W / R1 / G / decider）による出し分けをしてはならない（MUST NOT。全サブエージェント一律）。出力は 1 回あたり数行に抑え、ツールの実行結果を書き換えてはならない（MUST NOT）。

#### Scenario: 上限超で締めの指示が additionalContext に出る

- **WHEN** 計測値が `DEV_WORKFLOW_CONTEXT_CAP` を超える状態で PostToolUse payload を渡す
- **THEN** stdout が JSON として解析でき、`hookSpecificOutput.hookEventName` が `PostToolUse`、`additionalContext` に締めて return せよという指示と計測値・上限が含まれ、exit 0 で終わる

#### Scenario: 通知は return の 1 行目の書き分けを含む

- **WHEN** 同じ payload で `additionalContext` を読む
- **THEN** tasks グループが全部済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:` を 1 行目にする旨と、`tasks.md` が無い場合に何を 1 グループとみなすか（本体から渡された作業項目、G は pr-review-gate の手順 1〜5）が含まれる

#### Scenario: 役割で出し分けない

- **WHEN** 同じ計測値で `agent_type` が異なる payload を渡す
- **THEN** どちらも同じ `additionalContext` が出る

### Requirement: 強制停止の閾値を超えたら PreToolUse が編集を拒否する

PreToolUse で計測値が `DEV_WORKFLOW_CONTEXT_HARD_CAP`（既定 220000）を超えていたら、hook は `Edit` / `Write` / `NotebookEdit` を拒否しなければならない（MUST）。読み取り系ツール（Read / Grep / Glob）を拒否してはならない（MUST NOT）。

`Bash` は**コマンド内容によらず拒否しなければならない**（MUST）。コマンド文字列を解析して一部の形だけを通す判定を置いてはならない（MUST NOT）。理由: 判定はこのプロセスの中でコマンド文字列をトークン化するが、実際に実行するのは別プロセスのシェル（zsh または bash）で、両者のトークン化は一致を保証できない。実際に、シェル側にだけ意味を持つ記法（zsh の ANSI-C クォート `$'…'`、シェルのブレース展開 `{a,b}` 等）を判定側が「危険でない 1 トークン」と誤認し、実行側では任意コマンドの引数に展開される迂回が 2 度にわたって実機で再現した（`git -c` の値読み飛ばし、および `git push $'--receive-pack=/tmp/x' origin main`）。受理する経路が 1 つでも残る限り、この種の迂回は形を変えて再発するため、`Bash` は内容を一切見ず全件拒否する構造に閉じる。

拒否は `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":...}}` を stdout に出して exit 0 とする（SHALL）。`permissionDecisionReason` は次をすべて含まなければならない（MUST）: 計測値と `DEV_WORKFLOW_CONTEXT_HARD_CAP` の値 ／ `Bash` はコマンド内容によらず一切通らないこと ／ payload の `cwd`（＝そのサブエージェントの作業ツリーのパス）／ 編集済みファイルの一覧と、その作業ツリーのパス（`cwd`）を return に書けという指示 ／ commit は本体が行うという指示（サブエージェント自身は commit できないため）／ **return の 1 行目は `工程中断:` にすること**（強制停止で止まった時点で予定していた作業が残っているため、常に中断とする）。`-C <path>` や `-c <k=v>` といった、通る形についての案内を含めてはならない（MUST NOT）— 通る形は存在しないため。

`DEV_WORKFLOW_CONTEXT_HARD_CAP` は `DEV_WORKFLOW_CONTEXT_CAP` より大きくなければならず、小さいか等しい場合は fail-open（何もしない）とする（MUST）。

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
- **THEN** どちらも何も出力せず exit 0 で終わる（編集も Bash も通る）

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

### Requirement: サブエージェントのコンテキスト量の母集団集計

`plugins/dev-workflow/scripts/subagent-context-audit.sh` は、直近 N 日（`--days`、既定 14）のサブエージェントのトランスクリプトを走査し、母集団の統計を 1 行 JSON で標準出力に出さなければならない（SHALL）。JSON は次のキーを含む（SHALL）: `count`（対象件数）/ `first_median` / `first_max`（初回コンテキストの中央値・最大）/ `last_median` / `last_max`（最終コンテキストの中央値・最大）/ `over_cap_pct`（最終コンテキストが上限を超えた件数の割合、0〜100）/ `cap` / `days` / `sources` / `generated_at`。

`sources` は隔離の有無で分けた統計であり、`isolated`（`isolation: "worktree"` で起こしたもの）と `non_isolated` のそれぞれが `count` / `first_median` / `last_median` / `over_cap_pct` を持たなければならない（MUST）。件数だけの内訳にしてはならない（MUST NOT。隔離の有無は役割と相関して母集団の性質が異なるため、構成比が動いただけの変化と固定分そのものの増加を読み手が後から切り分けられる必要がある）。傾向判断の主系列は全体の `first_median` とし、`sources` はその切り分けに使う。

集計の母数は 2 種類あり、一致しない場合がある。`sources.isolated.count` と `sources.non_isolated.count` の合計は全体の `count` と一致しなければならない（MUST。分類できない件も母集団から落とさず `non_isolated` に寄せるため）。一方で `last_median` / `last_max` / `over_cap_pct` は**最終コンテキストが見つかった件だけ**を母数とし（窓を上限まで広げても `usage` 付きレコードが見つからない件は最終側の集計から除くため）、その母数は全体の `count` 以下になる（SHALL）。

1 体のコンテキスト量の定義は `subagent-context.sh` と同一で、assistant レコードの `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` でなければならない（MUST）。初回はファイル先頭から最初に現れた `usage` 付き assistant レコード、最終は末尾から遡って最初に見つかる同レコードとする（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）を用いる（SHALL）。中央値は偶数件のとき中央 2 値の平均を四捨五入した整数とする（SHALL）。

走査対象は projects ディレクトリ（既定 `${CLAUDE_PROJECTS_DIR:-~/.claude/projects}`。`--projects DIR` で差し替えられる）配下の `*/*/subagents/agent-*.jsonl` の 1 経路に限らなければならない（MUST）。`isolation: "worktree"` で起こしたサブエージェントも同じ場所に置かれ、隔離によって変わるのはファイル名だけである（隔離ありは名前が載らず `agent-<agentId>.jsonl`、隔離なしは `agent-a<name>-<hash>.jsonl`）。したがってこの 1 経路で隔離エージェントも自然に含まれる。`subagents/` の外にあるトランスクリプト（メインセッション、および worktree の中から起動された入れ子の `claude` セッション。project ディレクトリ名が `*--claude-worktrees-agent-*` に一致するものを含む）は、サブエージェントではないので集計に含めてはならない（MUST NOT）。Workflow 経由で起こしたサブエージェント（`subagents/workflows/<wf-id>/agent-*.jsonl`）は `subagents/` の内側にあるが、固定深さのこの 1 経路に当たらないので母集団に含めない（MUST NOT）。

隔離の有無の分類は、同じディレクトリの `agent-<id>.meta.json` の `spawnedWithWorktree` が `true` かどうかで行う（SHALL）。meta.json が無い・読めない場合は `non_isolated` に数える（SHALL。ファイル名からの推定は行わない）。分類できないことを理由にその 1 件を全体の `count` から落としてはならない（MUST NOT）。

対象期間の判定はファイルの mtime で行う（SHALL。レコード内のタイムスタンプは見ない）。

トランスクリプトの全文を読んではならない（MUST NOT）。初回は最初の `usage` 付きレコードで読み取りを打ち切り、最終は末尾から固定サイズの窓（既定 256 KiB）を読んで見つからなければ上限（4 MiB）まで窓を倍加し、それでも見つからない 1 件は最終側の集計から除く（SHALL）。

集計結果は `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}` に 1 行 JSON で保存しなければならない（MUST）。キャッシュの mtime が `SUBAGENT_CONTEXT_AUDIT_TTL`（秒、既定 21600）以内なら、トランスクリプトを走査せずキャッシュの内容をそのまま出力する（SHALL）。`--refresh` は TTL を無視して再走査する（SHALL）。

この集計は観測専用であり、閾値に基づいてセッション・ツール・エージェントの実行を止めてはならない（MUST NOT。強制停止は別の仕組みが担う）。引数エラー以外はすべて exit 0 とし、トランスクリプトが 1 件も無い・projects ディレクトリが無い・`python3` が無い場合は `count` が 0 の結果を出して exit 0 で終わらなければならない（MUST。fail-open）。個々のレコードの JSON が壊れていても、その行を飛ばして他の件の集計を続けなければならない（MUST）。

#### Scenario: 直近 14 日の集計が 1 行 JSON で出る

- **WHEN** 対象期間内に名前付きサブエージェントのトランスクリプトが複数存在する状態で `subagent-context-audit.sh` を実行する
- **THEN** `count` / `first_median` / `first_max` / `last_median` / `last_max` / `over_cap_pct` / `cap` / `days` / `sources` / `generated_at` を含む 1 行 JSON が出力され、exit 0 になる

#### Scenario: worktree 隔離のエージェントが集計に含まれる

- **WHEN** `subagents/` に、隔離ありのトランスクリプト（`agent-<agentId>.jsonl` と `spawnedWithWorktree: true` を持つ meta.json）と隔離なしのトランスクリプト（`agent-a<name>-<hash>.jsonl`）が混在している
- **THEN** 両方とも `count` に含まれ、前者は `sources.isolated`、後者は `sources.non_isolated` の `count` / `first_median` / `last_median` / `over_cap_pct` に反映される

#### Scenario: サブエージェント以外のトランスクリプトは数えない

- **WHEN** project ディレクトリ名が `--claude-worktrees-agent-<hash>` で終わるディレクトリの直下に `<uuid>.jsonl`（worktree の中から起動された入れ子の `claude` セッション）がある
- **THEN** そのファイルは `count` にも `sources` のどちらにも含まれない

#### Scenario: meta.json が無くても集計は落ちない

- **WHEN** 対象トランスクリプトの隣に meta.json が無い、またはその中身が壊れている
- **THEN** そのファイルは全体の `count` に含まれたまま `sources.non_isolated` に数えられ、`sources.isolated.count` と `sources.non_isolated.count` の合計は全体の `count` と一致する

#### Scenario: 対象期間外のトランスクリプトは数えない

- **WHEN** mtime が `--days` の窓より古いトランスクリプトが projects ディレクトリにある
- **THEN** そのファイルは `count` にも `sources` のどちらの経路にも含まれない

#### Scenario: トランスクリプトが 1 件も無い環境

- **WHEN** projects ディレクトリが空、または存在しない状態で実行する
- **THEN** `count` が 0 の結果を出力して exit 0 で終わる（エラー終了しない）

#### Scenario: 一部のレコードが壊れていても集計が続く

- **WHEN** 対象トランスクリプトの一部に JSON として解釈できない行が混ざっている
- **THEN** その行は無視され、残りのレコードと他のファイルから統計が算出され、exit 0 になる

#### Scenario: 上限超の割合が出る

- **WHEN** 対象のうち最終コンテキストが `cap` を超えるものがある
- **THEN** `over_cap_pct` がその割合（0〜100）として出力される

#### Scenario: TTL 内はキャッシュを返す

- **WHEN** キャッシュファイルの mtime が `SUBAGENT_CONTEXT_AUDIT_TTL` 以内の状態で集計を実行する
- **THEN** トランスクリプトを走査せずキャッシュの内容をそのまま出力する。`--refresh` を付けた場合は TTL を無視して再走査し、キャッシュを更新する

### Requirement: 集計結果の永続化と監査手順の文書

サブエージェントのコンテキスト量の監査手順は `plugins/dev-workflow/docs/usage-audit.md` を正本としなければならない（SHALL）。この文書は次を含む（SHALL）: ① 集計スクリプト `subagent-context-audit.sh` の実行コマンド（`--days` / `--cap` / `--refresh` の使い方を含む）② 出力キーの意味（`first_median` / `last_median` / `over_cap_pct` / `sources` の隔離別統計）③ 何を見たら固定分が増えたと判断するか（全体の `first_median` の推移を主系列とし、動いたときは `sources` で母集団の構成変化と切り分ける）④ 集計結果が残るキャッシュファイルの場所。

この監査の出力先を SessionStart hook（`scripts/session-tripwires.sh`）の注入内容に足してはならない（MUST NOT）。SessionStart への注入は全セッション・全サブエージェントの起動時固定分を増やす側の変更であり、固定分の増加を止めるという目的に反するため、観測の経路はキャッシュファイルと文書にとどめる。既存の残量モード導出・共有枠モード導出・`subagent-context.sh` の要件は変更しない（MUST NOT）。

#### Scenario: 監査手順が文書からたどれる

- **WHEN** 固定分が増えていないかを確認したい人が `plugins/dev-workflow/docs/usage-audit.md` を読む
- **THEN** 実行コマンド・出力キーの意味・増加と判断する基準・キャッシュファイルの場所が揃っており、他のファイルを見ずに監査を 1 回回せる

#### Scenario: 集計結果が機械可読な形で残る

- **WHEN** 集計を 1 回実行したあとにキャッシュファイルを読む
- **THEN** 直近の集計結果が 1 行 JSON として残っており、そのまま別のツールに渡せる

#### Scenario: SessionStart の注入内容は増えない

- **WHEN** この change の実装後にセッションを開始する
- **THEN** `session-tripwires.sh` が注入する内容は従来どおりで、集計に由来する行は 1 行も増えていない

