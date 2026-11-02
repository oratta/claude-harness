## ADDED Requirements

### Requirement: SubagentStart hook が dev-workflow の役に運用情報を注入する

dev-workflow プラグインは `hooks/hooks.json` に SubagentStart のエントリを持ち、matcher `^dev-workflow:(worker|reviewer|gate-runner)$` で `${CLAUDE_PLUGIN_ROOT}/scripts/subagent-start-context.sh` を起動しなければならない（SHALL）。

スクリプトは stdin の hook 入力の `agent_type` を自分でも照合し、`dev-workflow:worker` / `dev-workflow:reviewer` / `dev-workflow:gate-runner` のどれでもなければ何も出力せず exit 0 で終わらなければならない（MUST）。対象のときは `{"hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": "<本文>"}}` を stdout に出す（SHALL）。本文は役ごとに次の行を含む:

- worker と gate-runner: Fable 残量モードと共有枠モード（現在値・出どころ・効果）、途中計測の閾値の現在値
- reviewer: 途中計測の閾値の現在値だけ（Fable 残量モードと共有枠モードを含めてはならない（MUST NOT））

残量モードの導出は `scripts/session-tripwires.sh` と同じ式・同じ優先順位で行い、式を別の場所に複製してはならない（MUST NOT）。`session-tripwires.sh` は環境変数 `TRIPWIRES_SCOPE=subagent-budget` のとき残量モードのブロックだけを本文のテキストで出し、その範囲では usage-probe を実行しない（SHALL）。`subagent-budget` のときの出力範囲は、`## Fable 残量モード（自動導出）` の見出しから共有枠モードの効果の行までで、親向けの「W を SendMessage で再開する前に `subagent-context.sh` で測る」行・メモリ索引の検知行・昇格トリップワイヤー節を含めてはならない（MUST NOT）。この範囲はテンプレートが無くても出す（SHALL）。`TRIPWIRES_SCOPE` が未設定、または `subagent-budget` 以外の値のときの `session-tripwires.sh` の出力は従来と変えない（SHALL）。

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

## MODIFIED Requirements

### Requirement: SessionStart hook がトリップワイヤーを常駐注入する
dev-workflow プラグインは `hooks/hooks.json` を配布し、SessionStart イベント（matcher: `startup|clear|compact`）で注入スクリプトを起動しなければならない（SHALL）。コマンドパスは `${CLAUDE_PLUGIN_ROOT}` を使用する。スクリプトは `templates/escalation-tripwires.md` の「## 昇格トリップワイヤー」節を抽出し、`{"additionalContext": "<節の本文>"}` の JSON を stdout に出力する（single source of truth: 本文の複製を hook 側に持たない）。`TRIPWIRES_SCOPE` が未設定のとき、テンプレートが見つからない・節が抽出できない場合は無出力・exit 0 で終了しなければならない（MUST NOT block session start）。`TRIPWIRES_SCOPE=subagent-budget` のときの出力は要件「SubagentStart hook が dev-workflow の役に運用情報を注入する」が定める。

#### Scenario: 注入 JSON が節を含む
- **WHEN** `CLAUDE_PLUGIN_ROOT` をプラグインルートに設定してスクリプトを実行する
- **THEN** stdout は valid JSON で、`additionalContext` に「昇格トリップワイヤー」「規模超過」「失敗ループ」「仕様の発明」を含む

#### Scenario: テンプレート欠損時は fail-soft
- **WHEN** `TRIPWIRES_SCOPE` 未設定で、`CLAUDE_PLUGIN_ROOT` をテンプレートの無いディレクトリに設定してスクリプトを実行する
- **THEN** exit code 0 で出力は空である

#### Scenario: hooks.json の構造
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` をパースする
- **THEN** SessionStart エントリが存在し、matcher が `startup|clear|compact`、command が `${CLAUDE_PLUGIN_ROOT}` 経由でスクリプトを指している
