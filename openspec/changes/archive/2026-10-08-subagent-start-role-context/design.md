## Context

- `scripts/session-tripwires.sh`（SessionStart）は、昇格トリップワイヤー節・Fable 残量モード・共有枠モード・「W を再開する前に `subagent-context.sh` で測る」案内を親セッションに注入する。`prompt-tripwires-refresh.sh` はプラグイン更新時にこのスクリプトを呼んで再注入する（生成ロジックを複製しない前例）
- サブエージェント自身のコンテキストは `scripts/context-tripwire.sh` が途中計測し、`DEV_WORKFLOW_CONTEXT_CAP` 超で通知、`DEV_WORKFLOW_CONTEXT_HARD_CAP` 超で編集系と Bash を拒否する。閾値の数値と環境変数名の文書上の正本は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」だけに置く決まりがある
- SubagentStart hook の入力は `agent_type`・`agent_id`・`session_id` などを持ち、matcher は `agent_type` に当たる。出力は `{"hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": "..."}}`
- dev-workflow のサブエージェント種別は `worker` / `reviewer` / `gate-runner` / `decider`。decider は読み取り専用で入力契約が厳密（呼び出し側が全部貼る）なので対象にしない

## Goals / Non-Goals

**Goals:**
- worker / reviewer / gate-runner が起動時から、自分の指示書が参照する運用値の現在値を知る
- 残量モードの導出式を 1 か所に保つ
- casting-arbiter が CLAUDE.md を読み込まない

**Non-Goals:**
- 昇格トリップワイヤー節の本文をサブエージェントに注入すること（worker の指示書 `worker/common.md` が要点と正本の場所を既に持つ。全文を足すと全起動のコンテキストが増える）
- decider・Explore・他プラグインのエージェントへの注入
- 閾値や導出式そのものの変更

## Decisions

### 1. 役ごとに渡す行を分ける

| 役 | Fable 残量モード | 共有枠モード | 途中計測の閾値 |
|---|---|---|---|
| worker | 渡す | 渡す | 渡す |
| gate-runner | 渡す | 渡す | 渡す |
| reviewer | 渡さない | 渡さない | 渡す |

理由: worker は昇格トリップワイヤーの return で上限（共有枠モード・Fable 残量モード）に触れ、gate-runner の指示書はモデルの優先順位を共有枠モード → 事前分類 → Fable 残量モードで書いている。reviewer はモデルを選ばず昇格も報告しないので、残量モードは判断に使わない。途中計測は 3 役すべてに効く（`context-tripwire.sh` は agent_id を持つ全サブエージェントを測る）。

代案: 3 役に同じ内容を渡す。却下理由は、reviewer は起動回数が多く、使わない行を毎回載せることになるため。

### 2. 閾値は「現在値＋正本への案内」として渡す

途中計測の行は、hook 実行時の環境変数から求めた実効値（未設定なら `context-tripwire.sh` と同じ既定値）と、全解除されているか（`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`）を出し、扱いの規則は decision-criteria の該当節を読むよう案内する。規則の言い換えは書かない。

理由: 数値と環境変数名を文書に置かない決まりは「次に閾値が変わったとき文書が取り残される」のを防ぐためで、実行時に env から求める値は取り残されない（`session-tripwires.sh` が既に `DEV_WORKFLOW_CONTEXT_CAP` を同じ形で出している）。既定値は `context-tripwire.sh` の既定と食い違わないよう bats で照合する。

### 3. 導出は session-tripwires.sh に出力範囲の切り替えを足して共有する

`session-tripwires.sh` は環境変数 `TRIPWIRES_SCOPE`（未設定なら従来どおり）を読み、`subagent-budget` のときは次だけを stdout に出す: Fable 残量モードと共有枠モードのブロック（見出し付き）。この範囲では usage-probe・メモリ索引の検知・トリップワイヤー節の抽出・「W を再開する前に測る」行（親向け）を行わず、テンプレートが無くても残量ブロックは出す。出力は JSON ではなく本文のテキストにして、包む JSON は呼び出し側が作る。

新規 `subagent-start-context.sh` は stdin の JSON から `agent_type` を読み、対象 3 役のときだけ、役に応じて「`TRIPWIRES_SCOPE=subagent-budget` で呼んだ出力」と「途中計測の行」を組み立て、`hookSpecificOutput` で返す。

代案 A: 導出式を新規スクリプトに複製する。却下（式が 2 か所になり、片方だけ直る事故の元。`prompt-tripwires-refresh.sh` が複製を避けた前例と揃える）。
代案 B: 導出を Python モジュールに切り出し両方から import する。却下（編集ファイルが増え、SessionStart の既存経路の書き換え幅が大きい。今回の目的には切り替え 1 つで足りる）。

### 4. サブエージェント向けでは usage-probe を走らせない

SubagentStart はサブエージェント起動のたびに走るので、ネットワークを伴う probe を毎回足さない。snapshot とセッション記録は親セッションの SessionStart で probe 済みのものがあり、導出はそれを読むだけにする。

### 5. agent_type の照合をスクリプト側でも行う

matcher が効かない経路（matcher の解釈差、手での実行、他の hook 設定からの流用）でも対象外に何も返さないよう、スクリプトが `^dev-workflow:(worker|reviewer|gate-runner)$` を自分でも照合する。受け入れ条件の「Explore には何も返さない」はこの照合で満たす。

### 6. fail-open

python3 が無い・入力が JSON でない・agent_type が無い・`session-tripwires.sh` が失敗した、のどれでも無出力・exit 0。残量ブロックが作れなくても途中計測の行は出す（行ごとに独立）。

### 7. casting-arbiter に omitClaudeMd: true

frontmatter に 1 行足すだけ。本文の入力契約は変えない。

## Risks / Trade-offs

- SubagentStart の `agent_type` にプラグインのエージェントが `dev-workflow:worker` の形で入る前提は、受け入れ条件の実機確認（`claude -p --plugin-dir plugins/dev-workflow` で worker を起動し、サブエージェントの transcript を grep する）で確かめる。違う形なら matcher とスクリプトの照合を実際の形に合わせる
- `omitClaudeMd` を知らない古い Claude Code では未知キーとして無視される見込み。`tests/injection-budget.bats` の frontmatter 書式検査（許可リスト方式）と `claude plugin validate` が通ることを実装段で確かめる
- 親の snapshot が古いと、サブエージェントに渡る残量モードも古い。親の SessionStart と同じ導出なので、親と食い違うことはない
