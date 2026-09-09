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
`plugins/dev-workflow/scripts/subagent-context.sh <agent-name>` は、名前付きサブエージェントのトランスクリプト（`${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*<name>*.jsonl`。同名が複数あれば最初のレコードの `cwd` が現在のディレクトリと一致するものを優先し、次に更新時刻が新しいもの）の最後の assistant レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、1 行 JSON（`agent` / `file` / `context_tokens` / `calls` / `cap` / `over_cap`）を出力しなければならない（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）で、上限超なら exit 2、上限以内なら exit 0、トランスクリプトが無い・usage が無い・読めないときは exit 1 とし、exit 1 は作業を止めない（fail-open。SHALL）。

手渡し規則の本文（上限超過を検知したときに送ってよい SendMessage と送ってはならない SendMessage、手渡しを行ってよい条件、W / G の return の 1 行目の宣言、前任が動作中のまま交代させるときの手順）は、`plugins/dev-workflow/skills/develop/references/decision-criteria.md` の「コンテキスト上限（サブエージェントの手渡し）」節にだけ置かなければならない（MUST。以下この節を正本と呼ぶ）。正本は次の 4 点を規定しなければならない（SHALL）: ①上限超過（exit 2）を検知したときに送ってよい SendMessage と送ってはならない SendMessage、②手渡し（前回の return と記録先を渡して同じ役割の新しいエージェントを spawn すること）を行ってよい条件、③W / G の return の 1 行目の宣言書式と、どちらの宣言を選ぶかの義務（固定された 2 つの書式のどちらにも当てはまらない return をどう扱うかを含む）、④前任が動作中のまま交代させる必要があるときの手順と、その待ち方。**この spec は①〜④の答えを再掲してはならない（MUST NOT）**。同じ規則の言い換えが 10 前後の面に散らばっていたことが、2026-09 に 3 周続けて書き換え漏れを出した原因であり、言い回しの多様性そのものを構造的に無くすことがこの要件の目的である。

W / G の return の 1 行目の書式リテラルは `工程完了: <工程名>` と `工程中断: <理由>` の 2 つとし、変更してはならない（MUST NOT）。この 2 つだけは、別エピックの子 issue がこの書式を前提に設計されているため spec が固定する（リテラルの固定であって規則の再掲ではない。どちらを選ぶか・何を伴うかの本文は正本にある）。

次の面は、手渡し規則について正本への参照だけを書かなければならず、条件・書式・手順を自分の言葉で言い換えてはならない（MUST NOT）: `plugins/dev-workflow/README.md`、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/skills/develop/references/roles/worker.md`、`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`、`plugins/dev-workflow/templates/escalation-tripwires.md`、`plugins/dev-workflow/scripts/session-tripwires.sh` が毎セッション注入する常駐ルール文、`plugins/dev-workflow/scripts/subagent-context.sh` のヘッダコメント、`openspec/specs/dev-workflow-execution-strategy/spec.md`、`openspec/specs/dev-workflow-develop/spec.md`。`plugins/dev-workflow/.claude-plugin/plugin.json` の `description` はこの制約の対象外とし、正本とのズレを許容する（SHALL。配布メタデータでエージェントが読まないため）。

参照だけになった面には、正本を読むまで手渡さない旨のガード 1 行を置いてよい（MAY）。`plugins/dev-workflow/scripts/session-tripwires.sh` が注入する常駐ルール文については、このガード 1 行を置かなければならない（MUST）。この注入文はエージェントがファイルを開かずに受け取る唯一の面であり、純粋なポインタにすると「上限超過に気づいたが条件を知らないまま即興する」状態が生まれる（2026-09 の二重 spawn 事故の直接原因は即興だった）。ガードは規則の内容ではなく正本を読む義務を述べるものなので、言い換えの禁止には抵触しない（SHALL）。

本文が正本 1 箇所にしかないことは規約であり、機械検査の対象外とする（SHALL）。前段の MUST NOT を破った再掲を捕まえるのは仕様レビューである。規則の言い換えを機械で検出する検査は 2026-09 に作りかけて外した: 語彙を増やせば別の言い回しで抜け、除外を書けばそこが穴になり、緑が「違反が無い」のか「検査が何も見ていない」のか区別できない形に 7 周続けて落ちた。原理的に完全にはできない検査であり、成立するかごと follow-up https://github.com/oratta/claude-harness/issues/265 に切り出した。

正本が①〜④のそれぞれを規定していることを検査するテストを、`plugins/dev-workflow/tests/` に維持しなければならない（MUST）。検査は話題語の有無ではなく、規範の**極性**（何が禁じられ何が許され、どちらの宣言を選ぶのか、どちらが先か）を固定しなければならない（MUST。語の有無だけを見ると、①の「送らない」を「送ってよい」に、③の「未完了なら `工程完了:` を宣言してはならない」を `工程完了:` と `工程中断:` を入れ替えた形に、④の「停止確認を受け取ってから spawn」を逆順に書き換えても全テストが緑になる。実測: 5 通りの反転すべてが 13/13 緑だった。PR #253 の Codex レビュー）。このテストが `grep` の引数として正本の断片を引用することは、前段の MUST NOT が禁じる「言い換え」に当たらない（SHALL。テストは規則を述べて読ませる面ではなく、正本の本文が壊れていないことを機械的に検査する面であるため）。この spec は①〜④の答えを再掲しないので、正本の答えが逆に書き換わったときに落ちるのはこのテストだけである（`openspec validate` は索引としての充足しか見ない）。正本の中身を固定するこのアサーションは、他の検査を外すときも一緒に落としてはならない（MUST NOT）。

#### Scenario: 上限超のサブエージェントは exit 2
- **WHEN** トランスクリプトの最後の assistant usage の合算が `DEV_WORKFLOW_CONTEXT_CAP` を超える
- **THEN** `over_cap: true` の JSON を出力して exit 2 で終わる

#### Scenario: 参照だけの面は言い換えを持たない
- **WHEN** `README.md`・`SKILL.md`・`worker.md`・`gate-runner.md`・`escalation-tripwires.md`・`session-tripwires.sh` の注入文・`subagent-context.sh` のヘッダコメント・2 つの live spec のいずれかで手渡しに言及している箇所を読む
- **THEN** そこには正本への参照（どのファイルのどの節か）があり、手渡しの条件・宣言の書式の意味・停止確認の手順を自分の言葉で述べた文は無い

#### Scenario: 常駐ルール文は正本を読む義務を持つ
- **WHEN** `scripts/session-tripwires.sh` が毎セッション注入する常駐ルール文を読む
- **THEN** 正本への参照と、正本を読むまで手渡さない旨のガード 1 行があり、手渡しの条件・書式・手順を自分の言葉で述べた文は無い

#### Scenario: 配布メタデータのズレは違反ではない
- **WHEN** `.claude-plugin/plugin.json` の `description` の要約が正本と食い違っている
- **THEN** それはこの要件の違反ではない（エージェントが読まない配布メタデータであるため）

#### Scenario: 宣言の書式リテラルは変えない
- **WHEN** W / G の return の 1 行目の書式を変更しようとする
- **THEN** `工程完了: <工程名>` と `工程中断: <理由>` の 2 つは変更しない（別エピックの子 issue がこの書式を前提にしているため）

#### Scenario: 書式に当てはまらない return の扱いも正本が決める
- **WHEN** W / G の return の 1 行目が、固定された 2 つの書式のどちらにも当てはまらない
- **THEN** その扱いは正本が規定しており、この spec も他の面もその答えを書かない（本体が内容から読み替える余地を残さない）

#### Scenario: 正本の中身はテストが固定する
- **WHEN** 正本の「コンテキスト上限（サブエージェントの手渡し）」節が①〜④のどれかを答えなくなる、または答えが逆に書き換わった状態でテストを実行する
- **THEN** テストは落ちる（この spec は①〜④の答えを再掲しないため、規範の中身を担保するのはこのテストだけである）
- **AND** 書き換えが語の入れ替えだけ（①の「送らない」→「送ってよい」、③の `工程完了:` と `工程中断:` の入れ替え、④の停止確認と spawn の順序の逆転）でもテストは落ちる

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
