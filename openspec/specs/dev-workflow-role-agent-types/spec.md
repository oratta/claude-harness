# dev-workflow-role-agent-types Specification

## Purpose
TBD - created by archiving change role-scoped-agent-types. Update Purpose after archive.
## Requirements
### Requirement: 作業者の種別 dev-workflow:worker
dev-workflow プラグインは作業者のエージェント定義 `agents/worker.md` を配布しなければならない（MUST）。frontmatter は `name: worker`・`description`・`model: sonnet`・`tools: Read, Edit, Write, Bash, Grep, Glob, TaskStop` を持たなければならない（MUST。`TaskStop` は、背景で起こしたテストなどを総待ちの上限で打ち切るときに停止してから return するための道具で、`plugins/dev-workflow/references/subagent-waiting.md` が正当な出口として定め、`scripts/subagent-stop-guard.sh` が種別を問わず検査する）。`model` を省略したり `inherit` にしたりしてはならない（MUST NOT。`agent-model-guard.sh` はプラグインの種別の `model` 省略を許すので、定義に書かないと親セッションのモデルを継承する）。

`tools` に `mcp__` で始まる道具（ブラウザ・デザインツール・ドキュメント連携・ライブラリ文書検索）、`WebFetch`・`WebSearch`・`Skill`・`Agent`・`NotebookEdit` を含めてはならない（MUST NOT）。ただし、名前付き spawn で return を本体に返すために `SendMessage` が要ると実機で確かめた場合は、`SendMessage` だけを足してよい（MAY）。

本文は、作業の手順を `skills/develop/references/roles/worker/common.md` と、起動指示の `段:` の行が指す `skills/develop/references/roles/worker/<段>.md`（`spec` / `implement` / `finish`）から読むこと、起動指示に `段:` の行が無ければ手順のファイルを読まずに本体へ聞き返すこと、サブエージェントを起こさないこと、`/opsx:*` を呼ばず openspec CLI で進めること、画面での確認はせず (3a) の return の `画面確認:` の行で本体に伝えることを書かなければならない（MUST）。手順の本文を `worker/` のファイルから写してはならない（MUST NOT。同じ規則を 2 箇所に置くと片方が漏れる）。`段:` の行の値が `spec` / `implement` / `finish` のどれでもないときも、`段:` の行が無いときと同じに扱うことを書かなければならない（MUST）。

`段:` の行の有無の判定の守備範囲は次のとおりとする。入力は、本体が W に渡す起動指示・SendMessage による再開指示・手渡しの起動指示の本文である。拾いたい誤りは、本体が `段:` の行を書き忘れたときに、W が黙って索引や全部の段のファイルを読んだり、段を推測して読んだりすることである。次はこの判定を通ってしまい、この要件では止めない: `段:` の行はあるが値が指示した工程と食い違うこと（(3b) を指示して `段: implement` と書いた、など。W は指定された段のファイルを読んで動く）、古い版のエージェント定義がキャッシュに残った W が索引を通しで読むこと、判定を W の読解に任せているため W が行を見落とすこと。値の食い違いは、本体が develop の `SKILL.md` の対応に従って書くことで防ぎ、防ぎきれなかった分は、その工程の成果物を見る仕様レビュー（R1）と PR レビュー（G）に任せる。検査（bats）が確かめるのはエージェント定義の本文にこの指示が書かれていることだけで、W が実際に聞き返すかは確かめない。これらの穴を塞ぎ切ることは完了条件にしない。

#### Scenario: 定義が作業に要る道具だけを持つ
- **WHEN** `plugins/dev-workflow/agents/worker.md` の frontmatter を読む
- **THEN** `name: worker`・`model: sonnet`・`tools: Read, Edit, Write, Bash, Grep, Glob, TaskStop`（実機で要ると確かめた場合は加えて `SendMessage`）があり、`mcp__`・`WebFetch`・`WebSearch`・`Skill`・`Agent`・`NotebookEdit` は含まれない

#### Scenario: 本文が指示書を指し、手順を写さない
- **WHEN** `plugins/dev-workflow/agents/worker.md` の本文を読む
- **THEN** `skills/develop/references/roles/worker/common.md` と `段:` が指す段のファイルを読むこと・`段:` が無いか値が 3 つのどれでもなければ本体へ聞き返すこと・サブエージェントを起こさないこと・openspec CLI で進めること・`画面確認:` の行で伝えることが書かれている

### Requirement: ゲート実行者の種別 dev-workflow:gate-runner
dev-workflow プラグインはゲート実行者のエージェント定義 `agents/gate-runner.md` を配布しなければならない（MUST）。frontmatter は `name: gate-runner`・`description`・`model: sonnet`・`tools: Read, Bash, Grep, Glob, TaskStop` を持たなければならない（MUST。G は Codex を `run_in_background` で起こすので、総待ちの上限に達したときに Codex を停止してから return するために `TaskStop` が要る）。`model` を省略したり `inherit` にしたりしてはならない（MUST NOT）。

`tools` に `Edit`・`Write`・`NotebookEdit`・`mcp__` で始まる道具・`WebFetch`・`WebSearch`・`Skill`・`Agent` を含めてはならない（MUST NOT）。名前付き spawn で `SendMessage` が要ると実機で確かめた場合は、`SendMessage` だけを足してよい（MAY）。

本文は、手順を `skills/develop/references/roles/gate-runner.md` から読むこと、ファイルを編集しないこと、Codex の起動と `gh` の操作は Bash で行うこと、レビュアーを自分で起こさないことを書かなければならない（MUST）。手順の本文を gate-runner.md から写してはならない（MUST NOT）。

#### Scenario: 定義が照合に要る道具だけを持つ
- **WHEN** `plugins/dev-workflow/agents/gate-runner.md` の frontmatter を読む
- **THEN** `name: gate-runner`・`model: sonnet`・`tools: Read, Bash, Grep, Glob, TaskStop`（実機で要ると確かめた場合は加えて `SendMessage`）があり、`Edit`・`Write`・`NotebookEdit`・`mcp__`・`WebFetch`・`WebSearch`・`Skill`・`Agent` は含まれない

### Requirement: 新種別はプラグインが宣言し、description は短く保つ
`plugins/dev-workflow/.claude-plugin/plugin.json` の `agents` 配列は `./agents/worker.md`・`./agents/gate-runner.md`・`./agents/reviewer.md` を含まなければならない（MUST）。plugin.json の description と `.claude-plugin/marketplace.json` の dev-workflow の description は、新種別を含む内容に揃え、互いに一致していなければならない（MUST。`tests/marketplace-sync.bats` の一致検査）。

新種別の `description` は常時注入の予算の集計対象なので、それぞれ 1 文にしなければならない（MUST）。`tests/injection-budget.bats` が落ちる場合は、description を削ってから、それでも足りない分だけ `tests/injection-budget.txt` を動かし、PR 本文に何を削ろうとしてなぜその値にしたかを書かなければならない（MUST）。

#### Scenario: plugin.json が新種別を宣言する
- **WHEN** `plugins/dev-workflow/.claude-plugin/plugin.json` を読む
- **THEN** `agents` 配列に `./agents/decider.md`・`./agents/worker.md`・`./agents/gate-runner.md`・`./agents/reviewer.md` が含まれる

#### Scenario: 予算の検査が通る
- **WHEN** `./scripts/test.sh` を実行する
- **THEN** `tests/injection-budget.bats` と `tests/marketplace-sync.bats` を含めて exit 0 になる

### Requirement: 新種別は Fable で起こせない
`scripts/agent-model-guard.sh` は `DECIDER_TYPES` に新種別を足してはならない（MUST NOT）。`subagent_type` が `dev-workflow:worker`・`dev-workflow:gate-runner`・`dev-workflow:reviewer` のいずれかで `model: fable`（または `claude-fable-*`）の Agent 呼び出しは、今の判定のまま拒否されなければならない（MUST）。同じ種別で `model: sonnet` / `opus` の呼び出しと、`model` を省略した呼び出し（定義の `model` が使われる）は許可されなければならない（MUST）。この 3 つの挙動を `tests/agent-model-guard.bats` で固定しなければならない（MUST）。

この要件の守備範囲で入力として扱うのは、develop の本体（pr-review-gate を develop 以外で回すときはゲートを回す側）が書く Agent 呼び出しの `subagent_type` と `model` である。拾いたい誤りは、`dev-workflow:worker`・`dev-workflow:gate-runner`・`dev-workflow:reviewer` に `fable` または `claude-fable-*` を渡すことである。次は通ってよく、この要件では止めない: 同じ種別への `sonnet`・`opus` の指定、`model` の省略（定義の `model` が使われる）、`DEV_WORKFLOW_MODEL_GUARD=off` による緊急解除。定義ファイルの `model` を書き換えるなど、ガードの外にある迂回を塞ぎ切ることは、この要件の完了条件としない（定義ファイルの `model` は「作業者の種別」「ゲート実行者の種別」「レビュアーの種別」の要件と `tests/role-agent-types.bats` が別に固定する）。

#### Scenario: 作業者の種別に fable を渡すと拒否される
- **WHEN** `subagent_type: dev-workflow:worker`・`model: fable` の Agent 呼び出しをガードに通す
- **THEN** `permissionDecision` が `deny` になる

#### Scenario: ゲート実行者の種別に fable を渡すと拒否される
- **WHEN** `subagent_type: dev-workflow:gate-runner`・`model: claude-fable-5-1` の Agent 呼び出しをガードに通す
- **THEN** `permissionDecision` が `deny` になる

#### Scenario: レビュアーの種別に fable を渡すと拒否される
- **WHEN** `subagent_type: dev-workflow:reviewer`・`model: fable` の Agent 呼び出しをガードに通す
- **THEN** `permissionDecision` が `deny` になる

#### Scenario: sonnet・opus・省略は許可される
- **WHEN** `subagent_type: dev-workflow:worker` と `subagent_type: dev-workflow:reviewer` のそれぞれで `model: sonnet`、`model: opus`、`model` 省略の Agent 呼び出しをガードに通す
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

### Requirement: レビュアーの種別 dev-workflow:reviewer
dev-workflow プラグインは PR レビュアーのエージェント定義 `agents/reviewer.md` を配布しなければならない（MUST）。frontmatter は `name: reviewer`・`description`・`model: opus`・`tools: Read, Bash, Grep, Glob, TaskStop` を持たなければならない（MUST。`Bash` は差分の読み取り・`git grep` による照合表・テストと lint の再実行に、`TaskStop` は背景で起こしたテストを総待ちの上限で止めてから return するために要る）。`model` を省略したり `inherit` にしたりしてはならない（MUST NOT）。

`tools` に `Edit`・`Write`・`NotebookEdit`・`mcp__` で始まる道具・`WebFetch`・`WebSearch`・`Skill`・`Agent` を含めてはならない（MUST NOT）。名前付き spawn で `SendMessage` が要ると実機で確かめた場合は、`SendMessage` だけを足してよい（MAY）。

本文は、起動指示に貼られたレビュアー向け指示ブロックと `skills/pr-review-gate/stages/reviewer-brief.md` に従うこと、ファイルを編集しないこと、サブエージェントを起こさないこと、PR や issue にコメントを投稿せず三表と指摘を起こした側に返すことを書かなければならない（MUST）。手順の本文を reviewer-brief.md から写してはならない（MUST NOT）。

#### Scenario: 定義がレビューに要る道具だけを持つ
- **WHEN** `plugins/dev-workflow/agents/reviewer.md` の frontmatter を読む
- **THEN** `name: reviewer`・`model: opus`・`tools: Read, Bash, Grep, Glob, TaskStop`（実機で要ると確かめた場合は加えて `SendMessage`）があり、`Edit`・`Write`・`NotebookEdit`・`mcp__`・`WebFetch`・`WebSearch`・`Skill`・`Agent` は含まれない

#### Scenario: 本文が指示書を指し、手順を写さない
- **WHEN** `plugins/dev-workflow/agents/reviewer.md` の本文を読む
- **THEN** `skills/pr-review-gate/stages/reviewer-brief.md` を指し、ファイルを編集しないこと・サブエージェントを起こさないこと・コメントを投稿せず起こした側に返すことが書かれている

### Requirement: レビュアーの種別の効果を記録する
issue #650 の PR（`Closes #650` を本文に持つ PR）の本文の見出し `## 新種別の計測` に次を書かなければならない（MUST）。この要件は、#330 の change の PR を対象にした「新種別の効果を分けて記録する」とは別の要件で、対象の PR も記録する項目も違う。

1. 同じ Claude Code の版・`model: opus`・同じ指示文で `general-purpose` と `dev-workflow:reviewer` を 1 体ずつ起こしたときの、それぞれの最初の `message.usage` の `input_tokens`・`cache_creation_input_tokens`・`cache_read_input_tokens` を分けた値と、3 つの合計、版の番号
2. 1 の合計の差。両方の値と差を記録し、差の大きさは合否に使わない（issue #650 の受け入れ条件 1 を、本体の判断で記録の条件として読み替えた。#330 と同じ扱い）
3. 1 で起こした 2 体の `meta.json` の `agentType`（マージ前の版を `--plugin-dir` で読み込んだ定義が使われたことの裏付け）
4. `dev-workflow:reviewer` で起こしたレビュアー（change `reviewer-agent-type` の design.md「この PR のゲートでレビュアーを起こす手順」で起こしたもの）が、この PR のゲートで `stages/reviewer-brief.md` の三表（変更点の一覧・照合表・ハンク被覆）と指摘を返し、照合と振り分けの G が受け取ったことの記録（そのレビュアーの description と `meta.json` の `agentType`、G の照合結果の PR コメントの URL）。review phase の自動選択が codex を選び、加えて Claude レビュアーを起こせなかった場合は、受け入れ条件 2 を満たせなかったことと理由を書く

#### Scenario: PR 本文に計測の見出しがある
- **WHEN** issue #650 の PR の本文を読む
- **THEN** `## 新種別の計測` の見出しの下に、上の 1〜4 が数値・URL つきで書かれている

### Requirement: チーム機能が有効なら SessionStart で警告する

dev-workflow の SessionStart hook は、環境変数 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` が有効な値のとき、名前付き spawn が teammate になり種別の道具制限・本文が無視されることを警告しなければならない（SHALL）。未設定・空文字・`0`・`false`（大文字小文字を区別しない）のときは何も出力してはならない（SHALL NOT）。どの場合も exit 0 で、セッション開始を止めてはならない。

守備範囲: 入力は、Claude Code が hook に渡す環境変数 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` の値だけである。拾いたい誤りは、チーム機能が有効なまま develop を回すことである。警告せずに通す値は、未設定・空文字・`0`・`false`（大文字小文字は区別しない）である。判定の穴を塞ぎ切ることは完了条件にしない。たとえば `no` や前後に空白を含む値は有効扱いになって警告が出るが、見逃すより出しすぎる側に倒す方針なのでそれでよい。

#### Scenario: 値が 1 のとき警告が出る
- **WHEN** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` で `team-mode-warning.sh` を実行する
- **THEN** 標準出力に JSON が 1 件出て、`systemMessage` と `hookSpecificOutput.additionalContext` の両方に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` を名指しした警告が入り、exit 0 になる

#### Scenario: 未設定のとき何も出ない
- **WHEN** 環境変数を設定せずに実行する
- **THEN** 標準出力は空で exit 0 になる

#### Scenario: 0 のとき何も出ない
- **WHEN** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0` で実行する
- **THEN** 標準出力は空で exit 0 になる

#### Scenario: hook に登録されている
- **WHEN** `hooks/hooks.json` の SessionStart を読む
- **THEN** `team-mode-warning.sh` を呼ぶ command が `startup|clear|compact` の matcher で登録されている

