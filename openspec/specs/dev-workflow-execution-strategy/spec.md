# dev-workflow-execution-strategy Specification

## Purpose
TBD - created by archiving change dev-workflow-execution-strategy. Update Purpose after archive.
## Requirements
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

### Requirement: reserve モードでは自動実行が Fable を使わない
`FABLE_BUDGET_MODE=reserve` のとき、自動実行（unmanned モード・cron・loop 経由の無人セッション）は Fable をいかなる役割（W / R1 / G）でも使ってはならない（MUST NOT）。無人時の昇格ラダーは Opus を上限とし、Opus でも解決しない問題は needs-approval で人間に返す。interactive セッションでは conserve と同じ扱いとし、人間の Fable 利用は妨げない。

#### Scenario: reserve 中の unmanned 昇格
- **WHEN** `FABLE_BUDGET_MODE=reserve` の unmanned サイクルで失敗ループのトリップワイヤーを踏む
- **THEN** W は Opus までしか昇格せず、Opus でも2連続失敗が続く場合は記録先に needs-approval を付けて経緯をコメントしサイクルを終了する

#### Scenario: reserve 中の interactive は制限されない
- **WHEN** `FABLE_BUDGET_MODE=reserve` の interactive セッションでユーザーが作業する
- **THEN** 判定は conserve と同一に振る舞い、ユーザー自身の Fable 利用（/model 切替等）を妨げる指示を出さない

### Requirement: Step B 基準の重心移動
develop スキルの `references/decision-criteria.md` の仕様化要否（Step B）は、「設計判断・トレードオフを含むか（= 意図と決定の記録価値があるか)」を一次基準としなければならない（SHALL）。受け入れ条件が記録先（issue または Draft PR 本文）に明記された機械的な振る舞い変更は、記録先とテストを記録として spec 化を省略できる。テスト作成の必須性はいかなる判定でも緩めてはならない（MUST NOT）。unmanned モードの「迷ったら spec 化に倒す」は維持する。

#### Scenario: 機械的な振る舞い変更は spec を省略できる
- **WHEN** 受け入れ条件が記録先に明記され、設計判断（トレードオフの選択）を含まない振る舞い変更を interactive で判定する
- **THEN** spec 化を省略してコード直行し、テストは必ず先に書く

#### Scenario: unmanned は安全側を維持
- **WHEN** unmanned モードで spec 化要否の判断がつかない
- **THEN** spec 化する側に倒す

### Requirement: usage snapshot からの残量モード自動導出
`FABLE_BUDGET_MODE` が明示設定されていないとき、残量モードは usage snapshot（`fable_weekly_pct` / `fable_active` / 週次リセット時刻を含む）から自動導出されなければならない（SHALL）。導出ルールは develop スキルの `references/decision-criteria.md` に定義し、次の優先順位に従う: ① `fable_weekly_pct` が読めない/snapshot 無し → `conserve` ② `fable_weekly_pct > 90` → `exhausted` ③ `fable_weekly_pct <= 週経過%`（週次リセット時刻から算出）→ `abundant` ④ それ以外 → `conserve`。導出は「Fable の消費ペースが週の経過ペースを上回るか」のバーンレート比較であることを明記する。

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
`scripts/session-tripwires.sh` は usage snapshot の `weekly_all_pct`（全モデル共通の週次枠の消化率）から共有枠モード `SHARED_BUDGET_MODE` を導出し、Fable 残量モードと並べてセッション文脈に注入しなければならない（SHALL）。導出の優先順位: ① 明示 env `SHARED_BUDGET_MODE` ② `weekly_all_pct` が読めない / snapshot 無し → `ok` ③ `weekly_all_pct > 90` → `depleted` ④ `weekly_all_pct` が週経過%（週次リセット時刻から算出）より大きい → `throttled` ⑤ それ以外 → `ok`。効果は `references/decision-criteria.md` の表に置く（SHALL）: `ok` は制約なし、`throttled` は W / R1 / G の既定を Sonnet に落とし昇格上限 Opus・`abundant` の押し上げ無効、`depleted` は全役割 Sonnet 固定・昇格なし（事前分類に当たっても Fable / Opus を使わない）。Fable 残量モードと共有枠モードが食い違うときは共有枠モードの下限が勝たなければならない（MUST）。導出は Fable 残量モードの導出を変えてはならない（MUST NOT）。

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
`plugins/dev-workflow/scripts/subagent-context.sh <agent-name>` は、名前付きサブエージェントのトランスクリプト（`${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*<name>*.jsonl`。同名が複数あれば最初のレコードの `cwd` が現在のディレクトリと一致するものを優先し、次に更新時刻が新しいもの）の最後の assistant レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、1 行 JSON（`agent` / `file` / `context_tokens` / `calls` / `cap` / `over_cap`）を出力しなければならない（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）で、上限超なら exit 2、上限以内なら exit 0、トランスクリプトが無い・usage が無い・読めないときは exit 1 とし、exit 1 は作業を止めない（fail-open。SHALL）。

手渡し規則の本文（上限超過を検知したときに送ってよい SendMessage と送ってはならない SendMessage、手渡しを行ってよい条件、W / G の return の 1 行目の宣言、前任が動作中のまま交代させるときの手順）は、`plugins/dev-workflow/skills/develop/references/decision-criteria.md` の「コンテキスト上限（サブエージェントの手渡し）」節にだけ置かなければならない（MUST。以下この節を正本と呼ぶ）。正本は次の 4 点を規定しなければならない（SHALL）: ①上限超過（exit 2）を検知したときに送ってよい SendMessage と送ってはならない SendMessage、②手渡し（前回の return と記録先を渡して同じ役割の新しいエージェントを spawn すること）を行ってよい条件、③W / G の return の 1 行目の宣言書式と、どちらの宣言を選ぶかの義務、④前任が動作中のまま交代させる必要があるときの手順と、その待ち方。**この spec は①〜④の答えを再掲してはならない（MUST NOT）**。同じ規則の言い換えが 10 前後の面に散らばっていたことが、2026-09 に 3 周続けて書き換え漏れを出した原因であり、言い回しの多様性そのものを構造的に無くすことがこの要件の目的である。

W / G の return の 1 行目の書式リテラルは `工程完了: <工程名>` と `工程中断: <理由>` の 2 つとし、変更してはならない（MUST NOT）。この 2 つだけは、別エピックの子 issue がこの書式を前提に設計されているため spec が固定する（リテラルの固定であって規則の再掲ではない。どちらを選ぶか・何を伴うかの本文は正本にある）。

次の面は、手渡し規則について正本への参照だけを書かなければならず、条件・書式・手順を自分の言葉で言い換えてはならない（MUST NOT）: `plugins/dev-workflow/README.md`、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/skills/develop/references/roles/worker.md`、`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`、`plugins/dev-workflow/templates/escalation-tripwires.md`、`plugins/dev-workflow/scripts/session-tripwires.sh` が毎セッション注入する常駐ルール文、`plugins/dev-workflow/scripts/subagent-context.sh` のヘッダコメント、`openspec/specs/dev-workflow-execution-strategy/spec.md`、`openspec/specs/dev-workflow-develop/spec.md`。`plugins/dev-workflow/.claude-plugin/plugin.json` の `description` はこの制約の対象外とし、正本とのズレを許容する（SHALL。配布メタデータでエージェントが読まないため）。

`plugins/dev-workflow/tests/` のテストは、正本以外の面が手渡しに言及する箇所をすべて拾い、その箇所が正本への参照（`decision-criteria.md` というファイル名、または本要件が定義する「正本」の語）を含むことを要求する形（ホワイトリスト）で検査しなければならない（MUST）。禁じたい言い回しを列挙して探す形（ブラックリスト）を採ってはならない（MUST NOT。1 周目は新しい文言の有無だけを見て 6 箇所、2 周目・3 周目は 1 つの言い回しに限定した正規表現で見て 1 箇所と 6 箇所の取り残しをそれぞれ見逃した）。検査する面はテスト内に手で列挙した一覧ではなく、リポジトリの追跡ファイルからの機械的な列挙とし、除外は次の 2 種だけとする（SHALL）: ①歴史記録（`CHANGELOG.md` の過去項と、この change 以外の過去 change の archive）、②change の `proposal.md` と `tasks.md`（決定の理由と作業手順の記録であって、読んで従う規範ではないため）。

#### Scenario: 上限超のサブエージェントは exit 2
- **WHEN** トランスクリプトの最後の assistant usage の合算が `DEV_WORKFLOW_CONTEXT_CAP` を超える
- **THEN** `over_cap: true` の JSON を出力して exit 2 で終わる

#### Scenario: 手渡し規則の本文は正本にしかない
- **WHEN** 手渡しの許可条件・宣言の選び方・停止指示〜停止確認の手順を知りたい
- **THEN** その本文は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」にだけあり、同じ規則を述べる本文を持つ面は他に無い

#### Scenario: 参照だけの面は言い換えを持たない
- **WHEN** `README.md`・`SKILL.md`・`worker.md`・`gate-runner.md`・`escalation-tripwires.md`・`session-tripwires.sh` の注入文・`subagent-context.sh` のヘッダコメント・2 つの live spec のいずれかで手渡しに言及している箇所を読む
- **THEN** そこには正本への参照（どのファイルのどの節か）があり、手渡しの条件・宣言の書式の意味・停止確認の手順を自分の言葉で述べた文は無い

#### Scenario: 配布メタデータのズレは違反ではない
- **WHEN** `.claude-plugin/plugin.json` の `description` の要約が正本と食い違っている
- **THEN** それはこの要件の違反ではない（エージェントが読まない配布メタデータであるため）

#### Scenario: 宣言の書式リテラルは変えない
- **WHEN** W / G の return の 1 行目の書式を変更しようとする
- **THEN** `工程完了: <工程名>` と `工程中断: <理由>` の 2 つは変更しない（別エピックの子 issue がこの書式を前提にしているため）

#### Scenario: 参照を持たない言及はテストが落とす
- **WHEN** 正本以外の面に、正本への参照を含まないまま手渡しに言及する箇所が書かれた状態でテストを実行する
- **THEN** テストは落ち、その面のファイルと行を示す（その言い回しが既知かどうかに関係しない）

#### Scenario: テストは禁止語の列挙で判定しない
- **WHEN** テストの実装を読む
- **THEN** 判定は「手渡しに言及する箇所が正本への参照を含むか」であり、禁じたい言い回しの列挙ではない
- **AND** 検査する面は `git ls-files` からの機械的な列挙で、手で書いた面の一覧ではない（除外は歴史記録と change の `proposal.md` / `tasks.md` だけ）

#### Scenario: トランスクリプトが無くても作業は止まらない
- **WHEN** `subagent-context.sh` が対象のトランスクリプトを見つけられない
- **THEN** `error` を含む JSON を出力して exit 1 で終わり、本体は従来どおり再開してよい（上限判定が効かないだけ）
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

