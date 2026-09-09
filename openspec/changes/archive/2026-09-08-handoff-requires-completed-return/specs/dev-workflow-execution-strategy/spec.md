## MODIFIED Requirements

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
