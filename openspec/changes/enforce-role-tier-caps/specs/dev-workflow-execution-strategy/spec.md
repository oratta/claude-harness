## MODIFIED Requirements

### Requirement: model 未指定の Agent spawn は hook が拒否する
`hooks/hooks.json` は PreToolUse（matcher: `Agent`）に `scripts/agent-model-guard.sh` を登録しなければならない（MUST）。hook は stdin の payload（`tool_name` / `tool_input`）を読み、`tool_name` が `Agent` 以外なら何もしない。`tool_input.subagent_type` が `fork` なら `model` の有無にかかわらず共有枠モード（明示 env `SHARED_BUDGET_MODE`、無ければ `scripts/usage_view.py` が求める active スロットの全体週次枠の実効値 `weekly_all_pct` から導出。実効値はセッション記録と usage snapshot を突き合わせた値で、規則の正本は usage-session-records の「記録と snapshot から実効値を求める」。90 超は `depleted`、週経過% 超は `throttled`）が `ok` のときだけ許可し、それ以外は拒否する（MUST。fork は model パラメータを無視して親モデルで動くため）。

fork 以外で `model` が Fable（エイリアス `fable`、または `claude-fable-*` の完全 ID。大文字小文字と前後の空白を無視して判定する）を指す場合は、`subagent_type` が決める役の allowlist（`dev-workflow:decider`。将来増えたらスクリプト内の allowlist に足す）に載っているときだけ許可し、それ以外（`general-purpose` / `Explore` / `Plan` / 未指定 / 他のプラグイン種別）は拒否しなければならない（MUST）。拒否理由には決める役の種別名 `dev-workflow:decider` と、実行役の代替（`sonnet` / `opus`）と、規範（`rules/subagent-model-selection.md`）を含める（SHALL）。この判定はセッションの種類（対話 / 住人 / cron / loop）で変えてはならない（MUST NOT）。Fable 判定は残量（`FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` / セッション記録 / usage snapshot）をいっさい参照してはならない（MUST NOT。ガードは「誰が Fable になりうるか」の構造上の上限を見る層で、「今 Fable を使ってよいか」の助言は従来どおり develop 側の残量モードが担う。ガードが snapshot を読むと判定が鮮度と fail-open に依存してしまう）。既存の `fork` 判定が `SHARED_BUDGET_MODE` を見ることと、全解除の `DEV_WORKFLOW_MODEL_GUARD=off` はこの制限の対象外で、従来どおり残す（SHALL）。

Fable 以外の `model` は、要件「実行役の種別は対応表の上限を超える格で起こせない」で拒否されない限り許可し、定義側に model を持つエージェント種別（`plugin:agent` 形式・casting 系）も許可する。`subagent_type` が空・`general-purpose`・`Explore`・`Plan`・`claude`・`claude-code-guide`・`statusline-setup` で `model` が無ければ拒否する（MUST）。拒否は `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":...}}` を stdout に出して exit 0 とし、理由に規範（rules/subagent-model-selection.md）と選ぶべきティアを含める（SHALL）。`model` 未指定の拒否理由に列挙するティアは `haiku`（機械的）/ `sonnet`（通常実装・調査）/ `opus`（設計・レビュー）とし、`fable` は決める役の種別でだけ使えることを添える（SHALL）。payload は環境変数や引数に載せず stdin から読む（MUST。長い prompt で ARG_MAX を超えると hook が非 0 で落ちて素通りになるため）。python3 が無い・stdin が JSON として読めない（空の stdin を含む）・payload がオブジェクトでないときは fail-open（exit 0・無出力）とする（SHALL）。`tool_input` は、真とみなされるオブジェクト以外の値（空でない配列・空でない文字列・0 以外の数値・`true`）のときだけ fail-open（exit 0・無出力）とし、無い・`null`・空配列・空文字列・`0`・`false` のときは空のオブジェクトとして扱って `model` 未指定の判定へ進む（`subagent_type` も空になるので拒否される）（SHALL）。`subagent_type` が文字列でないときは空として扱い、`model` が文字列でないときは `model` 無しとして扱う（SHALL）。`fork` の共有枠判定では、`SHARED_BUDGET_MODE` が未設定で、セッション記録と snapshot のどちらからも active スロットの全体週次枠の値が求まらないとき、共有枠モードを `ok` とみなして許可する（SHALL。fail-open）。この fail-open は `fork` の共有枠判定に限り、`fork` 以外の判定（model 未指定・Fable）はセッション記録も snapshot も読まないので、snapshot が読めなくても結果は変わらない（SHALL）。`DEV_WORKFLOW_MODEL_GUARD=off` で全許可できる（SHALL）。

守備範囲: この要件が受け取る入力は次の 4 つに限る。1 つ目は、Claude Code が PreToolUse で hook の stdin に渡す Agent 呼び出しの payload（`tool_name` と、`tool_input` の `subagent_type` / `model`）で、`subagent_type` と `model` はエージェント（本体やサブエージェント）が書く値である。2 つ目は、利用者が自分で設定する環境変数 `DEV_WORKFLOW_MODEL_GUARD` と `SHARED_BUDGET_MODE` である。3 つ目は、`subagent_type` が `fork` で `SHARED_BUDGET_MODE` が未設定のときだけ `scripts/usage_view.py` を通じて読む、アカウント一覧（`accounts.json`）・active スロットのセッション記録（`.usage-sessions/<鍵>.json`。ステータスラインが書く）・usage snapshot（使用量の取得処理が書く）である。この 3 つ目の置き場所・active スロットの選び方・判定に使う現在時刻は、環境変数（`CLAUDE_CONFIG_DIR` / `CLAUDE_ACCOUNTS_FILE` / `USAGE_SESSIONS_DIR` / `USAGE_SNAPSHOT` / `CLAUDE_SECURESTORAGE_CONFIG_DIR` / `USAGE_PROBE_NOW`）で差し替わる。`fork` 以外の判定は 3 つ目を読まない。4 つ目は、`subagent_type` が `dev-workflow:worker` か `dev-workflow:gate-runner` のときだけ読む、リポジトリ同梱の `plugins/dev-workflow/references/model-tier-map.json` である（置き場所は guard 自身の場所から決まり、環境変数で差し替わらない）。拾いたい誤りは、`model` を省いた `general-purpose` / `Explore` / `Plan` などの呼び出しが親セッションのモデルを継承すること、決める役の種別以外が `model: "fable"`（または `claude-fable-*`）で起こされること、共有枠モードが `ok` でないときに `fork` が起こされること、実行役の種別が対応表の上限を超える格のモデルで起こされることの 4 つである。次の入力は通ることを許す: `general-purpose` に `model: "opus"` / `"sonnet"` / `"haiku"` を付けた呼び出し（実行役の通常の形）／Fable を指さない `model` の文字列は、実行役の種別で対応表の上限を超える場合を除き、実在するモデル名かどうかを確かめずに通す（例: 綴りを誤った `model: "fabel"`、`model: "opus-typo"`）／`model` が文字列でない payload は `model` 無しとして扱う（`subagent_type` が文字列でないときは空として扱うので、`model` が無ければ拒否される）／上に列挙していない `subagent_type`（`plugin:agent` 形式、casting 系、将来増える組み込みの種別。列挙との照合は大文字小文字を区別するので `explore` も含む）は、定義側に model があるかを確かめずに `model` 無しで通す／python3 が無い・stdin が JSON として読めない・payload がオブジェクトでないとき、および `tool_input` が真とみなされるオブジェクト以外の値（空でない配列・空でない文字列・0 以外の数値・`true`）のときは判定せずに通す（fail-open）。`tool_input` が無い・`null`・空配列・空文字列・`0`・`false` のときは通さず、空のオブジェクトとして `model` 未指定の判定へ進むので拒否される／`fork` は、`SHARED_BUDGET_MODE` が未設定で、セッション記録と snapshot のどちらからも active スロットの全体週次枠の値が求まらない（どちらも無い・読めない・値が範囲外など）ときは `ok` とみなして通す（fail-open）。snapshot だけが読めないときはセッション記録の値で判定する。`fork` 以外の判定はこの fail-open の対象外で、snapshot が読めなくても model 未指定の呼び出しと決める役以外の Fable は拒否する／`DEV_WORKFLOW_MODEL_GUARD=off` のときはすべて通す。これらの穴を見つかるたびに塞ぎ切ることは、この要件の完了条件にしない。

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
- **THEN** 拒否される。`SHARED_BUDGET_MODE` 未設定で、セッション記録も snapshot も無ければ許可される

#### Scenario: snapshot が無くてもセッション記録から fork を止める
- **WHEN** `SHARED_BUDGET_MODE` 未設定・snapshot 無しで、active スロットのセッション記録の `weekly_all_pct` が 95（リセット前）のまま `{"tool_name":"Agent","tool_input":{"subagent_type":"fork"}}` を渡す
- **THEN** 拒否され、理由に `depleted` が含まれる

#### Scenario: snapshot もセッション記録も無くても model 無しは拒否される
- **WHEN** snapshot もセッション記録も無い状態で `{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}` を渡す
- **THEN** `permissionDecision: deny` の JSON が出力される（fail-open にならない）

#### Scenario: 3MB の prompt でも判定される
- **WHEN** `prompt` が 3,000,000 文字の model 無し payload を stdin から渡す
- **THEN** exit 0 で拒否の JSON が出る（ARG_MAX で落ちない）

#### Scenario: 全解除は従来どおり効く
- **WHEN** `DEV_WORKFLOW_MODEL_GUARD=off` で `general-purpose` への `model: "fable"` を渡す
- **THEN** 無出力・exit 0 で許可される

#### Scenario: hooks.json に配線されている
- **WHEN** `hooks/hooks.json` を読む
- **THEN** `PreToolUse` に matcher `Agent` のエントリがあり、その command は `${CLAUDE_PLUGIN_ROOT}/scripts/agent-model-guard.sh` を二重引用符で囲んだ文字列（`"${CLAUDE_PLUGIN_ROOT}/scripts/agent-model-guard.sh"`）である

## ADDED Requirements

### Requirement: 実行役の種別は対応表の上限を超える格で起こせない

`scripts/agent-model-guard.sh` は、`subagent_type` が `dev-workflow:worker`（役 spec-write・implement）または `dev-workflow:gate-runner`（役 implement）で `model` があるとき、`plugins/dev-workflow/references/model-tier-map.json` の claude の列で `model` を格に戻し（照合の規則は `model-tier-resolution` の要件「上限の判定を Claude と Codex で共有する」）、その格が `role_caps` にあるその種別の役の上限（役が複数なら、そのうちいちばん低い上限）を超えるなら拒否しなければならない（MUST）。種別と役の対応は guard の中に置き、環境変数で足せる形にしてはならない（MUST NOT）。守備範囲は `model-tier-resolution` の要件「上限の判定の守備範囲」に従う。

#### Scenario: ゲート実行者の種別の完全 ID は拒否される

- **WHEN** `subagent_type: dev-workflow:gate-runner`・`model: claude-fable-5-1` の Agent 呼び出しをガードに通す
- **THEN** `permissionDecision` が `deny` になる

#### Scenario: 上限以下の格は通る

- **WHEN** `subagent_type: dev-workflow:worker` で `model: haiku`・`sonnet`・`opus` の呼び出しをそれぞれガードに通す
- **THEN** どれも無出力・終了コード 0 で通る

### Requirement: 上限の拒否理由は役と格を名指す

前の要件で拒否するとき、拒否理由は役・要求された格・その役の上限の格を含み、続けて決める役の種別名 `dev-workflow:decider`・実行役の代替（`sonnet` / `opus`）・規範（`rules/subagent-model-selection.md`）を含めなければならない（MUST）。

#### Scenario: 作業者の種別に最上位の格を付ける

- **WHEN** `subagent_type: dev-workflow:worker`・`model: fable` の Agent 呼び出しをガードに通す
- **THEN** `permissionDecision` が `deny` になり、理由に `spec-write`・`implement`・`最上位`・`上位`・`dev-workflow:decider` を含む

### Requirement: 上限の判定の対象外

上限の判定は、格に戻せない `model` と、`model` の省略（定義の `model` が使われる）を拒否してはならない（MUST NOT）。`dev-workflow:worker`・`dev-workflow:gate-runner` 以外の種別（`dev-workflow:reviewer`・`dev-workflow:decider`・`general-purpose` など）は上限の判定の対象外とし、従来の判定だけを受ける（SHALL）。`DEV_WORKFLOW_MODEL_GUARD=off` は上限の判定も解除する（SHALL）。

#### Scenario: 格に戻せない名前と省略は通る

- **WHEN** `subagent_type: dev-workflow:worker` で `model: fabel` の呼び出しと、`model` を省いた呼び出しをガードに通す
- **THEN** どちらも無出力・終了コード 0 で通る

### Requirement: 表が読めないときは Fable 判定に任せる

対応表が読めない・JSON として壊れている・claude の列か `role_caps` が欠けているとき、guard は上限の判定を飛ばし、要件「model 未指定の Agent spawn は hook が拒否する」の Fable 判定に任せなければならない（MUST。決める役以外の Fable は表が壊れていても拒否される）。

#### Scenario: 表が壊れていても Fable は止まる

- **WHEN** guard と表の一時コピーで表を壊し、`subagent_type: dev-workflow:worker`・`model: fable` の呼び出しをコピーの guard に通す
- **THEN** `permissionDecision` が `deny` になる

#### Scenario: 表が壊れていれば opus は通る

- **WHEN** 同じ壊れた表のコピーで、`subagent_type: dev-workflow:worker`・`model: opus` の呼び出しをコピーの guard に通す
- **THEN** 無出力・終了コード 0 で通る
