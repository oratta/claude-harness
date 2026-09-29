## MODIFIED Requirements

### Requirement: 作業者の種別 dev-workflow:worker
dev-workflow プラグインは作業者のエージェント定義 `agents/worker.md` を配布しなければならない（MUST）。frontmatter は `name: worker`・`description`・`model: sonnet`・`tools: Read, Edit, Write, Bash, Grep, Glob, TaskStop` を持たなければならない（MUST。`TaskStop` は、背景で起こしたテストなどを総待ちの上限で打ち切るときに停止してから return するための道具で、`plugins/dev-workflow/references/subagent-waiting.md` が正当な出口として定め、`scripts/subagent-stop-guard.sh` が種別を問わず検査する）。`model` を省略したり `inherit` にしたりしてはならない（MUST NOT。`agent-model-guard.sh` はプラグインの種別の `model` 省略を許すので、定義に書かないと親セッションのモデルを継承する）。

`tools` に `mcp__` で始まる道具（ブラウザ・デザインツール・ドキュメント連携・ライブラリ文書検索）、`WebFetch`・`WebSearch`・`Skill`・`Agent`・`NotebookEdit` を含めてはならない（MUST NOT）。ただし、名前付き spawn で return を本体に返すために `SendMessage` が要ると実機で確かめた場合は、`SendMessage` だけを足してよい（MAY）。

本文は、作業の手順を `skills/develop/references/roles/worker/common.md` と、起動指示の `段:` の行が指す `skills/develop/references/roles/worker/<段>.md`（`spec` / `implement` / `finish`）から読むこと、起動指示に `段:` の行が無ければ手順のファイルを読まずに本体へ聞き返すこと、サブエージェントを起こさないこと、`/opsx:*` を呼ばず openspec CLI で進めること、画面での確認はせず (3a) の return の `画面確認:` の行で本体に伝えることを書かなければならない（MUST）。手順の本文を `worker/` のファイルから写してはならない（MUST NOT。同じ規則を 2 箇所に置くと片方が漏れる）。

#### Scenario: 定義が作業に要る道具だけを持つ
- **WHEN** `plugins/dev-workflow/agents/worker.md` の frontmatter を読む
- **THEN** `name: worker`・`model: sonnet`・`tools: Read, Edit, Write, Bash, Grep, Glob, TaskStop`（実機で要ると確かめた場合は加えて `SendMessage`）があり、`mcp__`・`WebFetch`・`WebSearch`・`Skill`・`Agent`・`NotebookEdit` は含まれない

#### Scenario: 本文が指示書を指し、手順を写さない
- **WHEN** `plugins/dev-workflow/agents/worker.md` の本文を読む
- **THEN** `skills/develop/references/roles/worker/common.md` と `段:` が指す段のファイルを読むこと・`段:` が無ければ本体へ聞き返すこと・サブエージェントを起こさないこと・openspec CLI で進めること・`画面確認:` の行で伝えることが書かれている
