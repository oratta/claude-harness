## MODIFIED Requirements

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
