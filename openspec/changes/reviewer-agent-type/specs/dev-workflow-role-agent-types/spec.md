## ADDED Requirements

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
2. 1 の合計の差。`dev-workflow:reviewer` の合計が `general-purpose` より 20,000 以上少ないことを合格の条件とする（SHALL。issue #650 の受け入れ条件 1）
3. 1 で起こした 2 体の `meta.json` の `agentType`（マージ前の版を `--plugin-dir` で読み込んだ定義が使われたことの裏付け）
4. `dev-workflow:reviewer` で起こしたレビュアー（change `reviewer-agent-type` の design.md「この PR のゲートでレビュアーを起こす手順」で起こしたもの）が、この PR のゲートで `stages/reviewer-brief.md` の三表（変更点の一覧・照合表・ハンク被覆）と指摘を返し、照合と振り分けの G が受け取ったことの記録（そのレビュアーの description と `meta.json` の `agentType`、G の照合結果の PR コメントの URL）。review phase の自動選択が codex を選び、加えて Claude レビュアーを起こせなかった場合は、受け入れ条件 2 を満たせなかったことと理由を書く

#### Scenario: PR 本文に計測の見出しがある
- **WHEN** issue #650 の PR の本文を読む
- **THEN** `## 新種別の計測` の見出しの下に、上の 1〜4 が数値・URL つきで書かれ、2 の差が 20,000 以上である

## MODIFIED Requirements

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
