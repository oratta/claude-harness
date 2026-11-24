## MODIFIED Requirements

### Requirement: コンテキスト上限の規則の本文は、本体向けを decision-criteria.md に、W と G の宣言を return-declaration.md に置く

コンテキスト計測の規則の本文は、読み手で 2 つのファイルに分けて置かなければならない（MUST）。

- 本体が読む部分——2 経路（本体が再開前に測る／起動の途中で hook が測る）・閾値の環境変数（`DEV_WORKFLOW_CONTEXT_CAP`＝通知、`DEV_WORKFLOW_CONTEXT_HARD_CAP`＝強制停止、`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`＝全解除）と停止確認の終端の環境変数・再開前チェックの測り方・上限超のときの扱い・手渡しの許可・どちらの書式にも一致しない return の扱い・前任が動作中に交代させる場合・停止確認と終端・途中計測の仕組みと fail-open——は、`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の節に置く（MUST）
- W と G が return を書くときに読む部分——return の 1 行目の宣言（`工程完了: <工程名>` / `工程中断: <理由>`）の書式と選び方、通知を受けたときと強制停止に当たったときの W と G の振る舞い、途中停止したときの 1 行目、G が強制停止に当たったとき——は、`references/return-declaration.md` に置く（MUST）。既存計測経路の閾値の数値・環境変数名・停止動作の説明は `decision-criteria.md` の表に置く（MUST）。共通部品のモデル別既定値と根拠は `plugins/dev-workflow/references/token-thresholds.json` に置き、`scripts/token_thresholds.py` と `references/token-thresholds.md` には利用契約として環境変数名を置いてよい（MAY）。利用手順に数値の表を複製してはならず、`return-declaration.md` に閾値の数値と環境変数名を書いてはならない（MUST NOT）

`return-declaration.md` へ移すとき、宣言義務の箇条（`工程完了: <工程名>` と `工程中断: <理由>` の 2 つの書式の行と、成果一覧を書いていてもバックグラウンドコマンドが完了していなければ `工程完了:` を宣言しないという但し書きの段落）は一字一句変えてはならない（MUST NOT）。それ以外の移す文（通知を受けたら・強制停止に当たったら・途中停止したときの 1 行目・G が強制停止に当たったとき）は、次の 3 種類の置き換えだけをしてよく（MAY）、規則の中身（何をするか・何をしないか・1 行目をどちらにするか）を変えてはならない（MUST NOT）: ①環境変数名（`DEV_WORKFLOW_CONTEXT_CAP` / `DEV_WORKFLOW_CONTEXT_HARD_CAP`）と「上の表の」を、「通知」「強制停止」の語と `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の表への参照に置き換える ②移す前のファイルの中を指す参照（「上の『手渡しの許可』」など）を、`decision-criteria.md` の節名と項目名を付けた参照に置き換える ③規則に混ざった経緯（issue 番号・実測値）を削る。置き換えた箇所はすべて、置き換える前と後の文を対にして PR 本文に載せなければならない（MUST）。

`decision-criteria.md` の節の冒頭は、W と G の宣言の書式が `return-declaration.md` にあることを 1 行で指さなければならない（MUST）。

`decision-criteria.md` の同節は「数値と環境変数名はこの節にだけ置く」という配置規則を、上記の共通部品の表・解決処理・利用手順を許容する文に改めなければならない（MUST）。同節から表と利用手順へリンクし、未配線期間は同節の表が実際に動く既存経路の説明、JSON 表が後続の配線で利用するモデル別既定値と根拠であること、および共通処理が既存 3 スクリプト（`subagent-context.sh`・`context-tripwire.sh`・`pr-token-budget.sh`）へ未配線であることを明記しなければならない（MUST）。この配置変更で既存の閾値の数値・停止動作・手渡し権限・fail-open を変えてはならない（MUST NOT）。

W と G の指示書（`references/roles/worker/common.md`・`references/roles/gate-runner.md`）は、return を書く前に `return-declaration.md` を読むよう指さなければならず（MUST）、`decision-criteria.md` を読むよう指してはならない（MUST NOT）。W の段のファイル（`references/roles/worker/spec.md`・`implement.md`・`finish.md`）と `agents/worker.md`・`agents/gate-runner.md` も `decision-criteria.md` を読むよう指してはならない（MUST NOT）。

`references/roles/worker/common.md`・`skills/develop/SKILL.md`・`references/roles/gate-runner.md`・`templates/escalation-tripwires.md`・`plugins/dev-workflow/README.md` は、上の 2 つのファイルへの**ポインタと、その役割固有の動作だけ**を書かなければならない（MUST）。ポインタを書くのは `worker/common.md` であり、索引 `references/roles/worker.md`・`references/roles/worker/` の他 3 本（`spec.md`・`implement.md`・`finish.md`）・`references/pre-classification.md` はポインタを持たなくてよい（この 5 本には再掲の禁止だけを掛ける）。上のどのファイルも、閾値の数値・環境変数名・通知や強制停止の振る舞いを言い換えて再掲してはならない（MUST NOT）。同じ規則を複数のファイルに言い換えて置くと、次に閾値や振る舞いが変わったときにどれかが取り残されるためである（`README.md` を対象に含めるのは、プラグインの概観であっても閾値の数値を書けば取り残される対象になるため。実際に着手時点の `README.md` には `150K tokens` の再掲があった）。

#### Scenario: 規則の本文が decision-criteria.md にある

- **WHEN** `references/decision-criteria.md` のコンテキスト上限の節を読む
- **THEN** 2 経路・3 つの環境変数・再開前チェック・手渡しの許可・停止確認と終端が、そこだけで完結して書かれており、W と G の宣言の書式が `return-declaration.md` にあることが 1 行で指されている

#### Scenario: W と G の宣言が return-declaration.md にある

- **WHEN** `references/return-declaration.md` を読む
- **THEN** return の 1 行目の 2 つの書式と選び方・通知時と強制停止時の振る舞い・途中停止したときの 1 行目が書かれており、閾値の数値と環境変数名は無い

#### Scenario: 宣言の書式は分ける前と一字一句同じ

- **WHEN** 分ける前の `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」節の宣言義務の箇条（`工程完了:` と `工程中断:` の 2 つの書式とその但し書き）と、`return-declaration.md` の同じ箇条を比べる
- **THEN** 文が一字一句同じである

#### Scenario: W と G は decision-criteria.md を読まない

- **WHEN** `agents/worker.md`・`references/roles/worker/` の 4 本・`agents/gate-runner.md`・`references/roles/gate-runner.md` から、読む指示を grep で拾う
- **THEN** `decision-criteria.md` を読む指示が無く、`return-declaration.md` を読む指示が `worker/common.md` と `gate-runner.md` にある

#### Scenario: 他の面はポインタだけ

- **WHEN** `SKILL.md` / `references/roles/worker/common.md` / `references/roles/gate-runner.md` / `templates/escalation-tripwires.md` / `README.md` を読む
- **THEN** `references/decision-criteria.md`「コンテキスト上限」か `references/return-declaration.md` への参照があり、閾値の数値や環境変数名の再掲が無い

#### Scenario: ポインタを持たない面は再掲だけを禁じる

- **WHEN** 索引 `references/roles/worker.md` / `references/roles/worker/` の `spec.md`・`implement.md`・`finish.md` / `references/pre-classification.md` を読む
- **THEN** 閾値の数値や環境変数名の再掲が無い（参照は求めない）

#### Scenario: 共通部品の表と利用契約を配置できる

- **WHEN** モデル別しきい値の共通部品と利用手順を追加する
- **THEN** JSON 表にモデル別既定値と根拠、共通の解決処理と利用手順に入力の環境変数名を置ける。利用手順に数値の表を複製せず、return-declaration.md と他の面への再掲禁止を維持する

#### Scenario: 未配線期間の既存経路と新しい表を区別できる

- **WHEN** 共通処理を既存 3 スクリプトへ配線する前に decision-criteria.md のコンテキスト上限の節を読む
- **THEN** 同節の配置規則は共通部品を許容し、表と利用手順へのリンクがある。同節の表が実際に動く既存経路の説明、JSON 表が後続の配線で利用するモデル別既定値と根拠であること、未配線であることが明記され、既存の数値・停止動作・手渡し権限・fail-open は変わらない
