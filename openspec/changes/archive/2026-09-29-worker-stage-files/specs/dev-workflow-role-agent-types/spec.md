## MODIFIED Requirements

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
