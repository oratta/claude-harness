## ADDED Requirements

### Requirement: 作業者の種別 dev-workflow:worker
dev-workflow プラグインは作業者のエージェント定義 `agents/worker.md` を配布しなければならない（MUST）。frontmatter は `name: worker`・`description`・`model: sonnet`・`tools: Read, Edit, Write, Bash, Grep, Glob, TaskStop` を持たなければならない（MUST。`TaskStop` は、背景で起こしたテストなどを総待ちの上限で打ち切るときに停止してから return するための道具で、`plugins/dev-workflow/references/subagent-waiting.md` が正当な出口として定め、`scripts/subagent-stop-guard.sh` が種別を問わず検査する）。`model` を省略したり `inherit` にしたりしてはならない（MUST NOT。`agent-model-guard.sh` はプラグインの種別の `model` 省略を許すので、定義に書かないと親セッションのモデルを継承する）。

`tools` に `mcp__` で始まる道具（ブラウザ・デザインツール・ドキュメント連携・ライブラリ文書検索）、`WebFetch`・`WebSearch`・`Skill`・`Agent`・`NotebookEdit` を含めてはならない（MUST NOT）。ただし、名前付き spawn で return を本体に返すために `SendMessage` が要ると実機で確かめた場合は、`SendMessage` だけを足してよい（MAY）。

本文は、作業の手順を `skills/develop/references/roles/worker.md` から読むこと、サブエージェントを起こさないこと、`/opsx:*` を呼ばず openspec CLI で進めること、画面での確認はせず (3a) の return の `画面確認:` の行で本体に伝えることを書かなければならない（MUST）。手順の本文を worker.md から写してはならない（MUST NOT。同じ規則を 2 箇所に置くと片方が漏れる）。

#### Scenario: 定義が作業に要る道具だけを持つ
- **WHEN** `plugins/dev-workflow/agents/worker.md` の frontmatter を読む
- **THEN** `name: worker`・`model: sonnet`・`tools: Read, Edit, Write, Bash, Grep, Glob, TaskStop`（実機で要ると確かめた場合は加えて `SendMessage`）があり、`mcp__`・`WebFetch`・`WebSearch`・`Skill`・`Agent`・`NotebookEdit` は含まれない

#### Scenario: 本文が指示書を指し、手順を写さない
- **WHEN** `plugins/dev-workflow/agents/worker.md` の本文を読む
- **THEN** `skills/develop/references/roles/worker.md` を読むこと・サブエージェントを起こさないこと・openspec CLI で進めること・`画面確認:` の行で伝えることが書かれている

### Requirement: ゲート実行者の種別 dev-workflow:gate-runner
dev-workflow プラグインはゲート実行者のエージェント定義 `agents/gate-runner.md` を配布しなければならない（MUST）。frontmatter は `name: gate-runner`・`description`・`model: sonnet`・`tools: Read, Bash, Grep, Glob, TaskStop` を持たなければならない（MUST。G は Codex を `run_in_background` で起こすので、総待ちの上限に達したときに Codex を停止してから return するために `TaskStop` が要る）。`model` を省略したり `inherit` にしたりしてはならない（MUST NOT）。

`tools` に `Edit`・`Write`・`NotebookEdit`・`mcp__` で始まる道具・`WebFetch`・`WebSearch`・`Skill`・`Agent` を含めてはならない（MUST NOT）。名前付き spawn で `SendMessage` が要ると実機で確かめた場合は、`SendMessage` だけを足してよい（MAY）。

本文は、手順を `skills/develop/references/roles/gate-runner.md` から読むこと、ファイルを編集しないこと、Codex の起動と `gh` の操作は Bash で行うこと、レビュアーを自分で起こさないことを書かなければならない（MUST）。手順の本文を gate-runner.md から写してはならない（MUST NOT）。

#### Scenario: 定義が照合に要る道具だけを持つ
- **WHEN** `plugins/dev-workflow/agents/gate-runner.md` の frontmatter を読む
- **THEN** `name: gate-runner`・`model: sonnet`・`tools: Read, Bash, Grep, Glob, TaskStop`（実機で要ると確かめた場合は加えて `SendMessage`）があり、`Edit`・`Write`・`NotebookEdit`・`mcp__`・`WebFetch`・`WebSearch`・`Skill`・`Agent` は含まれない

### Requirement: 新種別はプラグインが宣言し、description は短く保つ
`plugins/dev-workflow/.claude-plugin/plugin.json` の `agents` 配列は `./agents/worker.md` と `./agents/gate-runner.md` を含まなければならない（MUST）。plugin.json の description と `.claude-plugin/marketplace.json` の dev-workflow の description は、新種別を含む内容に揃え、互いに一致していなければならない（MUST。`tests/marketplace-sync.bats` の一致検査）。

新種別の `description` は常時注入の予算の集計対象なので、それぞれ 1 文にしなければならない（MUST）。`tests/injection-budget.bats` が落ちる場合は、description を削ってから、それでも足りない分だけ `tests/injection-budget.txt` を動かし、PR 本文に何を削ろうとしてなぜその値にしたかを書かなければならない（MUST）。

#### Scenario: plugin.json が新種別を宣言する
- **WHEN** `plugins/dev-workflow/.claude-plugin/plugin.json` を読む
- **THEN** `agents` 配列に `./agents/decider.md`・`./agents/worker.md`・`./agents/gate-runner.md` が含まれる

#### Scenario: 予算の検査が通る
- **WHEN** `./scripts/test.sh` を実行する
- **THEN** `tests/injection-budget.bats` と `tests/marketplace-sync.bats` を含めて exit 0 になる

### Requirement: 新種別は Fable で起こせない
`scripts/agent-model-guard.sh` は `DECIDER_TYPES` に新種別を足してはならない（MUST NOT）。`subagent_type` が `dev-workflow:worker` または `dev-workflow:gate-runner` で `model: fable`（または `claude-fable-*`）の Agent 呼び出しは、今の判定のまま拒否されなければならない（MUST）。同じ種別で `model: sonnet` / `opus` の呼び出しと、`model` を省略した呼び出し（定義の `model: sonnet` が使われる）は許可されなければならない（MUST）。この 3 つの挙動を `tests/agent-model-guard.bats` で固定しなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、develop の本体が書く Agent 呼び出しの `subagent_type` と `model` である。拾いたい誤りは、`dev-workflow:worker` と `dev-workflow:gate-runner` に `fable` または `claude-fable-*` を渡すことである。次は通ってよく、この要件では止めない: 同じ種別への `sonnet`・`opus` の指定、`model` の省略（定義の `model: sonnet` が使われる）、`DEV_WORKFLOW_MODEL_GUARD=off` による緊急解除。定義ファイルの `model` を書き換えるなど、ガードの外にある迂回を塞ぎ切ることは、この要件の完了条件としない（定義ファイルの `model: sonnet` は「作業者の種別」「ゲート実行者の種別」の要件と `tests/role-agent-types.bats` が別に固定する）。

#### Scenario: 作業者の種別に fable を渡すと拒否される
- **WHEN** `subagent_type: dev-workflow:worker`・`model: fable` の Agent 呼び出しをガードに通す
- **THEN** `permissionDecision` が `deny` になる

#### Scenario: ゲート実行者の種別に fable を渡すと拒否される
- **WHEN** `subagent_type: dev-workflow:gate-runner`・`model: claude-fable-5-1` の Agent 呼び出しをガードに通す
- **THEN** `permissionDecision` が `deny` になる

#### Scenario: sonnet・opus・省略は許可される
- **WHEN** `subagent_type: dev-workflow:worker` で `model: sonnet`、`model: opus`、`model` 省略の Agent 呼び出しをそれぞれガードに通す
- **THEN** どれも拒否の出力を出さずに exit 0 で終わる

### Requirement: 新種別の効果を分けて記録する
新種別の効果は合否の閾値で決め打ちせず、次をすべて記録しなければならない（MUST）。1〜3 はこの change の PR 本文の見出し `## 新種別の計測` に書く（SHALL）。4・5 はこの change の PR の中では測れない。この change の W は (3b) で 4・5 の集計を扱う follow-up issue を作り、PR 本文に未計測であることと、その follow-up issue の URL と、測る記録先の決め方（マージ後に新種別で最初に develop を 1 本通した記録先）を書かなければならない（MUST）。4・5 を集計して follow-up issue にコメントする担い手は、マージ後に新種別で最初に develop を 1 本通した本体とし、その記録先の PR がマージされたあとに行う（SHALL）。

1. 最初の `message.usage` の `input_tokens`・`cache_creation_input_tokens`・`cache_read_input_tokens` を合計せず分けた値
2. 同じ Claude Code の版・同じモデル・同じ指示文で、`general-purpose` と `dev-workflow:worker`、`general-purpose` と `dev-workflow:gate-runner` を起こして並べた値（版の番号も書く）
3. issue #330 本文の 2026-09-20 の実測（W / G の初回 43,208〜50,577）と、2 の新種別の値の比較
4. 新種別で develop を 1 本通したときの、全エージェント合計の `cache_creation_input_tokens` と `cache_read_input_tokens`
5. 4 の 1 本での、上限による強制停止の回数と手渡しの回数（分けて書く）

画面確認役を 1 回以上起こせた場合は、その起動の最初の usage も同じ 3 つに分けて記録する（SHALL）。

#### Scenario: PR 本文に計測の見出しがある
- **WHEN** この change の PR 本文を読む
- **THEN** `## 新種別の計測` の見出しの下に、上の 1〜3 が数値つきで書かれ、4・5 は未計測であることと、follow-up issue の URL と、測る記録先の決め方が書かれている
