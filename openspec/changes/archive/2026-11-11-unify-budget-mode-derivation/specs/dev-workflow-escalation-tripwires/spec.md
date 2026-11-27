## MODIFIED Requirements

### Requirement: SessionStart で残量モードを自動導出注入
`scripts/session-tripwires.sh` は SessionStart 時に usage-probe を best-effort 実行し、active スロットの実効値（`usage-session-records` capability の「記録と snapshot から実効値を求める」。active スロットは `usage-account-registry` の active スロットの判定規則で起動環境から求める）から導出した残量モードと Fable 残量% を additionalContext に含めなければならない（SHALL）。snapshot のトップレベルのミラーを導出に使ってはならない（MUST NOT）。導出の式と優先順位（明示 env > データ無し > 90% 超 > 週経過との比較）は変えず、式は `scripts/usage_view.py` の 1 か所にだけ置く（SHALL）。`session-tripwires.sh` は閾値の比較も明示 env の優先も自分で行わず、モード・出どころ（明示 env / 既定（usage データなし）/ 自動導出）・表示する値を `usage_view.py` から得なければならない（MUST）。`usage_view.py` は `CLAUDE_PLUGIN_ROOT` ではなく `session-tripwires.sh` 自身のディレクトリから読み込む。各モードの効果の文は `skills/develop/references/decision-criteria.md` の残量モード表・共有枠モード表と `model-tier-resolution` の要件「残量モードを格に適用する」に一致させる（SHALL）。導出モードのブロックはトリップワイヤー節と併せて注入する。明示 env `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` があるときはそれを優先し、導出値ではなく明示値を提示する（未知の値もその値のまま提示し、効果の文は安全側の扱いを示す）。例外として、`usage_view.py` を読み込めないとき（ファイルが無い・壊れている）は明示 env も読まず、`conserve` / `ok` を出どころ `既定（usage_view.py を読めない）` として提示し、hook を止めない（SHALL）。明示 env の優先の判定も式の一部で、`session-tripwires.sh` に写しを残さないためである。probe やパースが失敗しても、トリップワイヤー注入自体は従来どおり行われなければならない（SHALL）(probe 失敗が hook 全体を壊さない)。

**守備範囲（残量モードの導出）**: ①入力の出どころは、明示 env（`FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE`）と、`usage_view.py` が求める active スロットの実効値（`usage-session-records` の規則でセッション記録と snapshot から求めた値）だけである。snapshot やセッション記録を直接読む経路を足さない。②拾いたい誤りは、式が 2 か所にあって注入されるモードと `codex-develop.py request` が格に当てるモードがずれること、別スロットや snapshot のトップレベルのミラーの値でモードを決めること、欠測を 0% と読んで `abundant` / `ok` に倒すことである。③通してよい入力: 未知の明示値（提示はその値のまま、正規化後のモードは `conserve` / `throttled`）、空白だけの明示値（未設定と同じ）、Fable の欠測（明示 env が無く、active スロットの実効値の `fable_weekly_pct` が求まらなければ `conserve`。値があっても週経過が求まらなければ `abundant` にしない）、共有枠の欠測（明示 env が無く、セッション記録と snapshot の双方から週次の実効値が求まらなければ `ok`）、`usage_view.py` を読み込めない場合（明示 env も読まず `conserve` / `ok`）。値の妥当性（数値か・0..100 か・リセットを跨いだか）の検査は `usage-session-records` の規則に任せ、ここで重ねない。④この導出で入力の穴が見つかるたびに塞ぎ切ることを、この要件の完了条件にしない。

`scripts/agent-model-guard.sh` の fork 拒否判定で使う共有枠モードも、active スロットの実効値から同じ式で導出しなければならない（SHALL）。

#### Scenario: 導出モードと残量% を注入する
- **WHEN** active スロットの実効値が求まる状態で SessionStart スクリプトを実行する
- **THEN** additionalContext に導出された残量モードと Fable 残量%（100 − 実効値の `fable_weekly_pct`）が含まれる

#### Scenario: 明示 env が導出を上書きする
- **WHEN** `FABLE_BUDGET_MODE` を明示設定して SessionStart スクリプトを実行する
- **THEN** additionalContext は導出値ではなく明示された値を現在モードとして提示する

#### Scenario: probe 失敗でもトリップワイヤーは載る
- **WHEN** snapshot もセッション記録も無い / probe が失敗する状態で SessionStart スクリプトを実行する
- **THEN** 昇格トリップワイヤー節は従来どおり注入され、残量モードは conserve 既定として提示される

#### Scenario: 使用量 API が 429 を返し続けても共有枠モードはセッション記録から導出する
- **WHEN** snapshot が無く、active スロットの鍵のセッション記録に週次 95% がある状態で SessionStart スクリプトを実行する
- **THEN** additionalContext の共有枠モードは `depleted`（自動導出）になる

#### Scenario: 古い snapshot の Fable 値はリセット時刻で読む
- **WHEN** 2 日前に取得した snapshot の active スロットが Fable 95%・リセット時刻が現在より前である状態で SessionStart スクリプトを実行する
- **THEN** Fable を 0% として導出し、`exhausted` にならない

#### Scenario: 導出を usage_view.py から得る
- **WHEN** モードを固定値で返す偽の `usage_view.py` を置いた scripts ディレクトリから `session-tripwires.sh` を実行する
- **THEN** additionalContext の残量モードと共有枠モードは偽物が返した値になる

#### Scenario: depleted の効果の文は最安を上げない
- **WHEN** `SHARED_BUDGET_MODE=depleted` で `session-tripwires.sh` を実行する
- **THEN** `depleted` の効果の文は、最安の役（explore と summarize）はそのままで、それ以外の役は中位（sonnet）が上限・昇格なしと読め、「全役割 sonnet 固定」の語を含まない

#### Scenario: throttled の効果の文は最安を上げない
- **WHEN** `SHARED_BUDGET_MODE=throttled` で `session-tripwires.sh` を実行する
- **THEN** `throttled` の効果の文は、上げていない役の既定を中位に落とし上限を上位とし、最安の役はそのままと読める

#### Scenario: 未知の明示値は提示とモードが分かれる
- **WHEN** `FABLE_BUDGET_MODE=foo`、`SHARED_BUDGET_MODE=bar` で `session-tripwires.sh` を実行する
- **THEN** additionalContext は `foo`（明示 env）と `bar`（明示 env）を提示し、効果の文はそれぞれ conserve 相当・throttled 相当で扱う旨を示す。同じ env の `budget_modes` は `conserve` と `throttled` を返す

#### Scenario: usage_view.py を読み込めなければ明示 env も読まずに既定を出す
- **WHEN** `usage_view.py` の無い（または import で例外を出す）scripts ディレクトリから、`FABLE_BUDGET_MODE=exhausted`、`SHARED_BUDGET_MODE=depleted` を設定して `session-tripwires.sh` を実行する
- **THEN** exit code 0 で、additionalContext は `conserve` と `ok` を出どころ `既定（usage_view.py を読めない）` として提示し、昇格トリップワイヤー節は従来どおり注入される

#### Scenario: fork の共有枠判定もセッション記録を使う
- **WHEN** snapshot が無く、active スロットの鍵のセッション記録に週次 95% がある状態で、`SHARED_BUDGET_MODE` 未設定のまま `subagent_type: fork` の Agent 呼び出しを agent-model-guard に渡す
- **THEN** guard は共有枠モード `depleted` として fork を拒否する

### Requirement: SubagentStart hook が dev-workflow の役に運用情報を注入する

dev-workflow プラグインは `hooks/hooks.json` に SubagentStart のエントリを持ち、matcher `^dev-workflow:(worker|reviewer|gate-runner)$` で `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-start-context.sh` を起動しなければならない（SHALL）。

スクリプトは stdin の hook 入力の `agent_type` を自分でも照合し、`dev-workflow:worker` / `dev-workflow:reviewer` / `dev-workflow:gate-runner` のどれでもなければ何も出力せず exit 0 で終わらなければならない（MUST）。対象のときは `{"hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": "<本文>"}}` を stdout に出す（SHALL）。本文は役ごとに次の行を含む:

- worker と gate-runner: Fable 残量モードと共有枠モード（現在値・出どころ・効果）、途中計測の閾値の現在値
- reviewer: 途中計測の閾値の現在値だけ（Fable 残量モードと共有枠モードを含めてはならない（MUST NOT））

残量モードの導出は `scripts/session-tripwires.sh` を通して `scripts/usage_view.py` の 1 か所の式で行い、式を別の場所に複製してはならない（MUST NOT）。導出の守備範囲は要件「SessionStart で残量モードを自動導出注入」の段落に従う。`session-tripwires.sh` は環境変数 `TRIPWIRES_SCOPE=subagent-budget` のとき残量モードのブロックだけを本文のテキストで出し、その範囲では usage-probe を実行しない（SHALL）。`subagent-budget` のときの出力範囲は、`## Fable 残量モード（自動導出）` の見出しから共有枠モードの効果の行までで、親向けの「W を SendMessage で再開する前に `subagent-context.sh` で測る」行・メモリ索引の検知行・昇格トリップワイヤー節を含めてはならない（MUST NOT）。この範囲はテンプレートが無くても出す（SHALL）。`TRIPWIRES_SCOPE` が未設定、または `subagent-budget` 以外の値のときの `session-tripwires.sh` の出力は従来と変えない（SHALL）。

途中計測の行は、hook 実行時の `DEV_WORKFLOW_CONTEXT_CAP` / `DEV_WORKFLOW_CONTEXT_HARD_CAP` の実効値（未設定なら `scripts/context-tripwire.sh` と同じ既定値）と、`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` で全解除されているかを示し、扱いの規則は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」を読むよう案内する（SHALL）。規則の言い換えを本文に書いてはならない（MUST NOT）。

照合の守備範囲は、matcher が効かない・手で実行された・別の設定から流用された経路で対象外の役に返さないことまでとする。Agent Teams の teammate 化で `agent_type` が変わる経路、将来の命名変更、SubagentStart hook がそもそも発火しない経路は守らない。実機で `agent_type` が違う形で届くと判明したら照合と matcher をその形に合わせ、それ以外の穴を塞ぎ切ることは完了条件にしない。

python3 が無い・入力が JSON でない・`agent_type` が無い・残量ブロックの生成が失敗した、のどの場合もサブエージェントの起動を止めてはならず、exit 0 で終わらなければならない（MUST）。残量ブロックが作れなくても途中計測の行は出す。

#### Scenario: worker の入力に運用情報を返す
- **WHEN** `{"hook_event_name":"SubagentStart","agent_type":"dev-workflow:worker"}` を stdin に渡してスクリプトを実行する
- **THEN** stdout は valid JSON で、`hookSpecificOutput.hookEventName` が `SubagentStart`、`hookSpecificOutput.additionalContext` に `FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE`・途中計測の閾値の値・`decision-criteria.md` への案内が含まれる

#### Scenario: Explore の入力には何も返さない
- **WHEN** `{"hook_event_name":"SubagentStart","agent_type":"Explore"}` を stdin に渡してスクリプトを実行する
- **THEN** exit code 0 で stdout は空である

#### Scenario: decider と他プラグインのエージェントにも何も返さない
- **WHEN** `agent_type` が `dev-workflow:decider` または `casting:casting-arbiter` の入力を渡してスクリプトを実行する
- **THEN** exit code 0 で stdout は空である

#### Scenario: reviewer には残量モードを渡さない
- **WHEN** `agent_type` が `dev-workflow:reviewer` の入力を渡してスクリプトを実行する
- **THEN** `additionalContext` に途中計測の閾値の値が含まれ、`FABLE_BUDGET_MODE` と `SHARED_BUDGET_MODE` は含まれない

#### Scenario: 明示 env の残量モードがそのまま届く
- **WHEN** `FABLE_BUDGET_MODE=reserve` と `SHARED_BUDGET_MODE=throttled` を設定し、`agent_type` が `dev-workflow:gate-runner` の入力を渡してスクリプトを実行する
- **THEN** `additionalContext` は Fable 残量モード `reserve`（明示 env）と共有枠モード `throttled`（明示 env）を提示する

#### Scenario: 閾値の env 上書きと既定値
- **WHEN** `DEV_WORKFLOW_CONTEXT_CAP=90000` を設定して worker の入力を渡す／未設定で渡す
- **THEN** 前者の本文は 90000 を、後者は `context-tripwire.sh` の既定値と同じ値を提示する

#### Scenario: 壊れた入力でも起動を止めない
- **WHEN** JSON でない文字列、または `agent_type` の無い JSON を stdin に渡してスクリプトを実行する
- **THEN** exit code 0 で stdout は空である

#### Scenario: subagent-budget はテンプレートが無くても残量ブロックだけを出す
- **WHEN** テンプレートの無いディレクトリを `CLAUDE_PLUGIN_ROOT` にし（`scripts/` だけは実物を指す構成で）、`TRIPWIRES_SCOPE=subagent-budget` で `session-tripwires.sh` を実行する
- **THEN** stdout は `## Fable 残量モード` で始まる本文テキストで、`subagent-context.sh` を含まず、usage-probe の実行痕（probe の状態ファイル・snapshot の書き込み）が残らない

#### Scenario: SessionStart の出力は変わらない
- **WHEN** `TRIPWIRES_SCOPE` を設定せずに `session-tripwires.sh` を実行する
- **THEN** 出力は従来どおり `additionalContext` に昇格トリップワイヤー節と残量モードのブロックを含む JSON である

#### Scenario: hooks.json の SubagentStart エントリ
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` をパースする
- **THEN** SubagentStart エントリが存在し、matcher が `^dev-workflow:(worker|reviewer|gate-runner)$`、command が `${CLAUDE_PLUGIN_ROOT}` 経由で `scripts/subagent-start-context.sh` を指している

