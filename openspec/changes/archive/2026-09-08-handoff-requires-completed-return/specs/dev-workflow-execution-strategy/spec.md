## MODIFIED Requirements

### Requirement: サブエージェントのコンテキスト上限と手渡し
`plugins/dev-workflow/scripts/subagent-context.sh <agent-name>` は、名前付きサブエージェントのトランスクリプト（`${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/*/*/subagents/agent-*<name>*.jsonl`。同名が複数あれば最初のレコードの `cwd` が現在のディレクトリと一致するものを優先し、次に更新時刻が新しいもの）の最後の assistant レコードの usage から `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` を読み、1 行 JSON（`agent` / `file` / `context_tokens` / `calls` / `cap` / `over_cap`）を出力しなければならない（SHALL）。上限は `--cap` または `DEV_WORKFLOW_CONTEXT_CAP`（既定 150000）で、上限超なら exit 2、上限以内なら exit 0、トランスクリプトが無い・usage が無い・読めないときは exit 1 とし、exit 1 は作業を止めない（fail-open。SHALL）。

手渡し規則の本文（上限超過を検知したときに送ってよい SendMessage と送ってはならない SendMessage、手渡しを行ってよい条件、W / G の return の 1 行目の宣言、前任が動作中のまま交代させるときの手順）は、`plugins/dev-workflow/skills/develop/references/decision-criteria.md` の「コンテキスト上限（サブエージェントの手渡し）」節にだけ置かなければならない（MUST。以下この節を正本と呼ぶ）。正本は次の 4 点を規定しなければならない（SHALL）: ①上限超過（exit 2）を検知したときに送ってよい SendMessage と送ってはならない SendMessage、②手渡し（前回の return と記録先を渡して同じ役割の新しいエージェントを spawn すること）を行ってよい条件、③W / G の return の 1 行目の宣言書式と、どちらの宣言を選ぶかの義務、④前任が動作中のまま交代させる必要があるときの手順と、その待ち方。**この spec は①〜④の答えを再掲してはならない（MUST NOT）**。同じ規則の言い換えが 10 前後の面に散らばっていたことが、2026-09 に 3 周続けて書き換え漏れを出した原因であり、言い回しの多様性そのものを構造的に無くすことがこの要件の目的である。

W / G の return の 1 行目の書式リテラルは `工程完了: <工程名>` と `工程中断: <理由>` の 2 つとし、変更してはならない（MUST NOT）。この 2 つだけは、別エピックの子 issue がこの書式を前提に設計されているため spec が固定する（リテラルの固定であって規則の再掲ではない。どちらを選ぶか・何を伴うかの本文は正本にある）。

次の面は、手渡し規則について正本への参照だけを書かなければならず、条件・書式・手順を自分の言葉で言い換えてはならない（MUST NOT）: `plugins/dev-workflow/README.md`、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/skills/develop/references/roles/worker.md`、`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`、`plugins/dev-workflow/templates/escalation-tripwires.md`、`plugins/dev-workflow/scripts/session-tripwires.sh` が毎セッション注入する常駐ルール文、`plugins/dev-workflow/scripts/subagent-context.sh` のヘッダコメント、`openspec/specs/dev-workflow-execution-strategy/spec.md`、`openspec/specs/dev-workflow-develop/spec.md`。`plugins/dev-workflow/.claude-plugin/plugin.json` の `description` はこの制約の対象外とし、正本とのズレを許容する（SHALL。配布メタデータでエージェントが読まないため。検査からも除外する。後述の除外③）。

参照だけになった面には、正本を読むまで手渡さない旨のガード 1 行を置いてよい（MAY）。`plugins/dev-workflow/scripts/session-tripwires.sh` が注入する常駐ルール文については、このガード 1 行を置かなければならない（MUST）。この注入文はエージェントがファイルを開かずに受け取る唯一の面であり、純粋なポインタにすると「上限超過に気づいたが条件を知らないまま即興する」状態が生まれる（2026-09 の二重 spawn 事故の直接原因は即興だった）。ガードは規則の内容ではなく正本を読む義務を述べるものなので、言い換えの禁止には抵触しない（SHALL）。

「手渡しに言及する箇所」の判定は、次に列挙するトリガー語のいずれかを含むかで行う（SHALL）。トリガーは語彙に依存することを前提とし、取りこぼしより誤検出に倒す（再現率優先。SHALL。誤検出は当該の面に参照 1 行を足せば解消でき、副作用が無いため）:

- **語彙 A（手渡しに固有の語。リポジトリの追跡ファイル全体に適用する）**: `手渡` / `工程完了` / `工程中断` / `subagent-context` / `DEV_WORKFLOW_CONTEXT_CAP` / `コンテキスト上限`
- **語彙 B（他の文脈でも使う一般語。`plugins/dev-workflow/` 配下と `openspec/specs/dev-workflow-*/spec.md` にだけ適用する）**: `引き継` / `交代` / `後任` / `乗り換え` / `新しい W` / `新しい G` / `新規 spawn` / `再 spawn`

判定と参照の単位はファイルとする（SHALL）。参照はその面を読む者が正本に辿り着けることを保証するためのもので、同じファイルの箇所ごとに書かせると再掲の圧力が戻るため、段落単位では判定しない。正本への参照とは、`decision-criteria.md` というファイル名、または正本の節見出し `コンテキスト上限（サブエージェントの手渡し）` のいずれかの文字列をそのファイルが含むこととする（SHALL）。テストは落ちたファイルと、そのファイル内でトリガーに掛かった行を示さなければならない（MUST）。

語彙 A で発火した面は正本への参照を持たなければならず（MUST）、後述の除外表に載せてはならない（MUST NOT）。語彙 B だけで発火した面は、正本への参照を足すか、テスト内の除外表にその面がトリガー語をどの文脈で使っているかを述べた理由コメント 1 行を添えて載せるかのいずれかとする（SHALL）。除外表の各行は、その面が現に語彙 B のトリガー語を含むことを検査し、含まなくなった行があればテストを落とさなければならない（MUST。stale な除外を残さないため）。この除外表は、実装者が検査範囲を暗黙に狭めることを防ぐために可視化する仕掛けであり、語彙 A の面に使うことはできない。

検査する面はテスト内に手で列挙した一覧ではなく、リポジトリの追跡ファイル（`git ls-files`）からの機械的な列挙とし、除外は次の 3 種だけとする（SHALL）: ①歴史記録（`plugins/dev-workflow/CHANGELOG.md` 全体、この change 以外の過去 change の archive、`_longruns/`）、②change の `proposal.md` と `tasks.md`（決定の理由と作業手順の記録であって、読んで従う規範ではないため）、③`plugins/dev-workflow/.claude-plugin/plugin.json`（前段で正本とのズレを許容した配布メタデータ）。`CHANGELOG.md` は項単位ではなくファイル単位で除外する（リリース時点の記録であり、新しい項も過去項と同じく歴史記録であるため）。

`plugins/dev-workflow/tests/` 自身は検査対象に含める（SHALL）。ただし正本の中身を固定するテストが正本の断片を `grep` の引数として引用することは、この要件が禁じる「言い換え」に当たらない（SHALL）。テストは規則を述べて読ませる面ではなく、正本の本文が壊れていないことを機械的に検査する面であるため。

正本が①〜④のそれぞれを規定していることを検査するテストを、`plugins/dev-workflow/tests/` に維持しなければならない（MUST）。この spec は①〜④の答えを再掲しないので、正本の答えが逆に書き換わったときに落ちるのはこのテストだけである（`openspec validate` は索引としての充足しか見ない）。ホワイトリスト化の対象は参照面であって正本ではなく、正本の中身を固定するアサーションをホワイトリスト化に伴って落としてはならない（MUST NOT）。

#### Scenario: 上限超のサブエージェントは exit 2
- **WHEN** トランスクリプトの最後の assistant usage の合算が `DEV_WORKFLOW_CONTEXT_CAP` を超える
- **THEN** `over_cap: true` の JSON を出力して exit 2 で終わる

#### Scenario: 手渡し規則の本文は正本にしかない
- **WHEN** 追跡ファイルを走査し、手渡しの許可条件・宣言の選び方・停止指示〜停止確認の手順を自分の言葉で述べた本文を持つ面を数える
- **THEN** 該当するのは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の 1 面だけで、他の面は 0 件

#### Scenario: 参照だけの面は言い換えを持たない
- **WHEN** `README.md`・`SKILL.md`・`worker.md`・`gate-runner.md`・`escalation-tripwires.md`・`session-tripwires.sh` の注入文・`subagent-context.sh` のヘッダコメント・2 つの live spec のいずれかで手渡しに言及している箇所を読む
- **THEN** そこには正本への参照（どのファイルのどの節か）があり、手渡しの条件・宣言の書式の意味・停止確認の手順を自分の言葉で述べた文は無い

#### Scenario: 常駐ルール文は正本を読む義務を持つ
- **WHEN** `scripts/session-tripwires.sh` が毎セッション注入する常駐ルール文を読む
- **THEN** 正本への参照と、正本を読むまで手渡さない旨のガード 1 行があり、手渡しの条件・書式・手順を自分の言葉で述べた文は無い

#### Scenario: 配布メタデータのズレは違反ではない
- **WHEN** `.claude-plugin/plugin.json` の `description` の要約が正本と食い違っている
- **THEN** それはこの要件の違反ではなく、テストの検査対象にも入らない（エージェントが読まない配布メタデータであるため）

#### Scenario: 宣言の書式リテラルは変えない
- **WHEN** W / G の return の 1 行目の書式を変更しようとする
- **THEN** `工程完了: <工程名>` と `工程中断: <理由>` の 2 つは変更しない（別エピックの子 issue がこの書式を前提にしているため）

#### Scenario: 参照を持たない言及はテストが落とす
- **WHEN** 正本以外の面に、トリガー語を含みながら正本への参照を含まない状態でテストを実行する
- **THEN** テストは落ち、そのファイルとトリガーに掛かった行を示す（トリガー語に掛かった面である限り、その先の言い回しが既知かどうかに関係しない）

#### Scenario: 固有語を使わない言及も一般語のトリガーで拾う
- **WHEN** `plugins/dev-workflow/references/workflow-execution.md` のように、`手渡` の語を使わずに「乗り換え時の成果引き継ぎ」と述べている面を検査する
- **THEN** 語彙 B のトリガーで拾われ、正本への参照を足すか、理由コメント 1 行を添えて除外表に載せるかのどちらかが要求される
- **AND** 語彙 A で発火した面は除外表に載せることができない

#### Scenario: テストは禁止語の列挙で判定しない
- **WHEN** テストの実装を読む
- **THEN** 判定は「トリガー語に掛かった面が正本への参照を含むか」であり、禁じたい言い回しの列挙ではない
- **AND** 検査する面は `git ls-files` からの機械的な列挙で、手で書いた面の一覧ではない（除外は歴史記録・change の `proposal.md` / `tasks.md`・`plugin.json` の 3 種だけ）
- **AND** `plugins/dev-workflow/tests/` 自身も検査対象に入っている

#### Scenario: 正本の中身はテストが固定する
- **WHEN** 正本の「コンテキスト上限（サブエージェントの手渡し）」節が①〜④のどれかを答えなくなる、または答えが逆に書き換わった状態でテストを実行する
- **THEN** テストは落ちる（この spec は①〜④の答えを再掲しないため、規範の中身を担保するのはこのテストだけである）

#### Scenario: トランスクリプトが無くても作業は止まらない
- **WHEN** `subagent-context.sh` が対象のトランスクリプトを見つけられない
- **THEN** `error` を含む JSON を出力して exit 1 で終わり、本体は従来どおり再開してよい（上限判定が効かないだけ）
