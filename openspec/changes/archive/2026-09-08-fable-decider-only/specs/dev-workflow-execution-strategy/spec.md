## MODIFIED Requirements

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

### Requirement: 残量モードによる閾値調整
役割のモデル選択は環境変数 `FABLE_BUDGET_MODE`（`abundant` / `conserve` / `reserve` / `exhausted`）を参照しなければならない（SHALL）。定義表は develop スキルの `references/decision-criteria.md` に置く（SHALL）。未設定時は usage snapshot からの自動導出結果を用い、snapshot も無ければ `conserve` として扱う。明示的に設定された `FABLE_BUDGET_MODE` は自動導出より優先されなければならない（SHALL）。モードが変えるのは役割（W / R1 / G）の昇格上限のみであり、1 ループの構造・トリップワイヤーは変えない。`abundant` はどの役割の既定モデルも押し上げてはならない（MUST NOT）。Fable が使えるのは決める役（`dev-workflow:decider` として spawn される役）だけであり、実行役（W）の上限はどのモードでも `opus` である（SHALL）。`exhausted` は Fable 週次枠を実質使い切った状態を表し、`reserve` と異なり interactive を含む全経路で Fable をいかなる役割でも使わず、決める役も `opus` に落とす。Fable 残量モードは Fable と Opus のあいだで役割を付け替える装置であり総量を絞る装置ではないため、総量の下限は共有枠モード（別 Requirement）が決める。

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
