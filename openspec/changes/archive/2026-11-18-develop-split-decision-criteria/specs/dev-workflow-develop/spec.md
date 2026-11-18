## RENAMED Requirements

- FROM: `### Requirement: コンテキスト上限の規則の本文は decision-criteria.md 1 箇所に置く`
- TO: `### Requirement: コンテキスト上限の規則の本文は、本体向けを decision-criteria.md に、W と G の宣言を return-declaration.md に置く`

## MODIFIED Requirements

### Requirement: コンテキスト上限の規則の本文は、本体向けを decision-criteria.md に、W と G の宣言を return-declaration.md に置く

コンテキスト計測の規則の本文は、読み手で 2 つのファイルに分けて置かなければならない（MUST）。

- 本体が読む部分——2 経路（本体が再開前に測る／起動の途中で hook が測る）・閾値の環境変数（`DEV_WORKFLOW_CONTEXT_CAP`＝通知、`DEV_WORKFLOW_CONTEXT_HARD_CAP`＝強制停止、`DEV_WORKFLOW_CONTEXT_TRIPWIRE=off`＝全解除）と停止確認の終端の環境変数・再開前チェックの測り方・上限超のときの扱い・手渡しの許可・どちらの書式にも一致しない return の扱い・前任が動作中に交代させる場合・停止確認と終端・途中計測の仕組みと fail-open——は、`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の節に置く（MUST）
- W と G が return を書くときに読む部分——return の 1 行目の宣言（`工程完了: <工程名>` / `工程中断: <理由>`）の書式と選び方、通知を受けたときと強制停止に当たったときの W と G の振る舞い、途中停止したときの 1 行目、G が強制停止に当たったとき——は、`references/return-declaration.md` に置く（MUST）。閾値の数値と環境変数名は `decision-criteria.md` の表にだけ置き、`return-declaration.md` に書いてはならない（MUST NOT）

`return-declaration.md` へ移すとき、宣言義務の箇条（`工程完了: <工程名>` と `工程中断: <理由>` の 2 つの書式の行と、成果一覧を書いていてもバックグラウンドコマンドが完了していなければ `工程完了:` を宣言しないという但し書きの段落）は一字一句変えてはならない（MUST NOT）。それ以外の移す文（通知を受けたら・強制停止に当たったら・途中停止したときの 1 行目・G が強制停止に当たったとき）は、次の 3 種類の置き換えだけをしてよく（MAY）、規則の中身（何をするか・何をしないか・1 行目をどちらにするか）を変えてはならない（MUST NOT）: ①環境変数名（`DEV_WORKFLOW_CONTEXT_CAP` / `DEV_WORKFLOW_CONTEXT_HARD_CAP`）と「上の表の」を、「通知」「強制停止」の語と `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の表への参照に置き換える ②移す前のファイルの中を指す参照（「上の『手渡しの許可』」など）を、`decision-criteria.md` の節名と項目名を付けた参照に置き換える ③規則に混ざった経緯（issue 番号・実測値）を削る。置き換えた箇所はすべて、置き換える前と後の文を対にして PR 本文に載せなければならない（MUST）。

`decision-criteria.md` の節の冒頭は、W と G の宣言の書式が `return-declaration.md` にあることを 1 行で指さなければならない（MUST）。

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

### Requirement: 本体はオーケストレータ専任でコードもレビューも書かない
SKILL.md は本体（メインセッション）の役割を「役割 W / R1 / G を model 明示で spawn し、return の要約と記録先（issue または Draft PR）のコメント・ラベルだけを見て次に誰を起こすかを決める」と規定しなければならない（MUST）。禁止事項として、本体が Edit でコードを書かないこと、本体がレビュー（仕様レビュー・PR レビュー）を代行しないことを明記しなければならない（MUST）。「本体が Edit でコードを書かない」の例外は軽い通し方（`dev-workflow-spec-review` の「些細な修正は軽い通し方で新しいテストと W の起動を省く」Requirement）だけであることを、同じ禁止事項の箇所に書かなければならない（MUST）。軽い通し方でも、本体がレビューを代行してはならない（MUST NOT）。並列可能な役割は並列に起こしてよい（MAY）。ただし、1 つの作業ディレクトリ（worktree）で同時に動く同一役割のサブエージェントは常に 1 人でなければならない（MUST）。並列に起こしてよいのは、別々の worktree を持つ役割（エピックの子どうし、独立した change の W どうし）に限る（SHALL）。複数 change に割れた場合の change ごとの W 並列も、change ごとに worktree を分けて起こすものとする（MUST）。

名前付き profile を使わない Claude 経路では、W は名前付きで spawn する（SHALL）。名前付き profile を使う場合は profile role ごとに thread と起動時の要求 tuple / 適用 model を記録する。canonical develop が同じ Claude role を再開する前には毎回、現在有効な残量モードの上限を確認し、既存 thread の適用 model が上限内である場合に限って SendMessage で再開しなければならない（MUST）。適用 model が現在の上限を超える場合は SendMessage で再開せず、既存の工程完了または停止確認の条件を満たしてから、要求 tuple を変更せず、上限内の適用 model で同じ role の fresh thread へ手渡しし、要求値・適用値・変更理由を記録しなければならない（MUST）。profile role が変わる場合、または executor=codex の場合も fresh thread に成果物と必要な要約を渡す（SHALL）。どの経路でも、別コンテキストを要する工程はすべて本体が起こし、W が孫を呼ぶ必要がある工程を設けてはならない（MUST NOT）。

#### Scenario: 禁止事項が明記されている
- **WHEN** SKILL.md の「本体の役割」節を読む
- **THEN** 本体が Edit でコードを書かないこと、レビューを代行しないこと、役割を model 明示で spawn することが書かれている

#### Scenario: Edit の禁止の例外は軽い通し方だけ
- **WHEN** SKILL.md の「本体の役割」節の禁止事項を読む
- **THEN** 「本体は Edit でコードを書かない」の箇所に、例外が軽い通し方だけであることと、その正本が `references/light-path.md` であることが書かれている

#### Scenario: W の再開は profile role と executor に従う
- **WHEN** SKILL.md の 1 ループと profile 経路の記述を読む
- **THEN** profile 無しと同じ profile role の Claude W は再開前に現在の上限を確認し、適用 model が上限内のときだけ名前付き thread を SendMessage で再開すること、上限超過・profile role の変更・Codex W の場合は fresh thread に成果物と必要な要約を渡すこと、W が孫を呼ぶ工程が無いことが書かれている

#### Scenario: 再開前に exhausted へ変わった
- **GIVEN** requested model=`fable`、applied model=`fable` で起動した同じ Claude role の名前付き thread がある
- **WHEN** 再開前に `FABLE_BUDGET_MODE=exhausted` へ変わり、共有枠は depleted でない
- **THEN** SendMessage で再開せず、工程完了または停止確認後に requested model=`fable` を保持した fresh thread へ applied model=`opus` で手渡しし、変更理由=`FABLE_BUDGET_MODE=exhausted` を記録する

#### Scenario: 再開前に depleted へ変わった
- **GIVEN** requested model=`fable`、applied model=`fable` で起動した同じ Claude role の名前付き thread がある
- **WHEN** 再開前に `SHARED_BUDGET_MODE=depleted` へ変わる
- **THEN** SendMessage で再開せず、工程完了または停止確認後に requested model=`fable` を保持した fresh thread へ applied model=`sonnet` で手渡しし、変更理由=`SHARED_BUDGET_MODE=depleted` を記録する

#### Scenario: 同一 worktree に同一役割を二重に spawn しない
- **WHEN** ある worktree で W が稼働中である（手渡し待ち・停止指示待ちを含む）
- **THEN** 本体はその worktree に対して別の W をもう 1 人 spawn しない（手渡し・再開のいずれであっても。いつ手渡してよいかは `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本）

#### Scenario: 別 worktree の並列はこの制約の対象外
- **GIVEN** エピックの子どうし、または独立した change の W どうしが、それぞれ別の worktree で動いている
- **THEN** 本体はこれらを並列に起こしてよく、同一 worktree 制約には抵触しない

### Requirement: 入口 0 は記録先を決める
SKILL.md は 1 ループの最初の工程「入口 0」として記録先の決め方を規定しなければならない（MUST）: issue があれば（番号・URL・自然文マッチ）それを記録先にする。無ければ issue を切らず、W が worktree を用意された直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする。この Draft PR は仕様化判断を記録する**前**に存在していなければならない（MUST。記録先が無い状態で判定を先に進めない）。Draft PR を記録先にする場合、受け入れ条件は PR 本文（位置づけ・動作確認ポイント）に書かなければならず（MUST）、受け入れ条件自体を省いてはならない（MUST NOT）。記録先を PR にした場合、PR 本文に `Closes` / `Fixes` / `Refs #N` の issue 参照を書いてはならない（MUST NOT。書くと pr-review-gate の照合先がその issue に移る。エピックの子は子 issue が記録先なので `Closes #子` を書く）。仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（SHALL）。仕様宣言（`対象 HEAD:` 付き。書式の正本は pr-review-gate スキル手順 3-b）は記録先が issue か Draft PR かにかかわらず常に **PR コメント**に置き、記録先が issue のときに issue コメントへ置いてはならない（MUST NOT。pr-review-gate 手順 5 は PR のコメントで 3 見出しを照合し、`対象 HEAD:` 規約は PR の HEAD に紐づくため）。軽い通し方（`dev-workflow-spec-review` の「些細な修正は軽い通し方で新しいテストと W の起動を省く」Requirement）を当てる場合だけは例外で、記録先が無いときは本体が Draft PR を作る（SHALL）。そのときの順序は、本体が依頼から受け入れ条件を整理する → その受け入れ条件で軽い通し方を当てるかを決める → 当てるなら本体が空 commit・push・`gh pr create --draft` で Draft PR を開き受け入れ条件を本文に書く → 仕様化判断を Draft PR のコメントに記録する、の 1 通りとし（MUST）、当てないなら本体は Draft PR を作らずに W を起こし、W がこれまでどおり作る（SHALL）。SKILL.md は入口 0 にこの例外と順序を、正本（`references/light-path.md`）を指す形で書かなければならない（MUST）。SKILL.md はこの分離（記録先に置くもの＝仕様化判断・仕様レビュー結果、PR コメントに置くもの＝仕様宣言）を入口 0 に明記しなければならない（MUST）。issue を切るのは追跡・キュー・議論が要るとき（エピック／無人キュー／判断を残す議論）に限ることを明記する（SHALL）。

#### Scenario: issue が無い依頼は Draft PR が記録先になる
- **WHEN** 会話で依頼された変更に対応する issue が無い
- **THEN** SKILL.md は issue を切らず、worktree 直後に空 commit → push → `gh pr create --draft` で Draft PR を開いてから仕様化判断を記録し、受け入れ条件を PR 本文に書き、PR 本文に issue 参照を書かないよう指示している

#### Scenario: issue を切る条件が限定されている
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** issue を切る条件がエピック・無人キュー・判断を残す議論の 3 つに限定されている

#### Scenario: 仕様宣言の投稿先は記録先と分離されている
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** 仕様化判断・仕様レビュー結果は記録先のコメントに置くと書かれ、仕様宣言は記録先が issue でも PR コメントに置くと書かれており、記録先のコメントに置くものの列挙に仕様宣言が含まれていない

#### Scenario: 軽い通し方では記録先の Draft PR を本体が作る
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** 記録先が無い依頼に軽い通し方を当てるときだけ本体が Draft PR を作ることと、受け入れ条件の整理 → 軽い通し方の判断 → Draft PR の作成 → 仕様化判断の記録の順序が、`references/light-path.md` を指して書かれている

### Requirement: 1 ループは W→R1→W→G の順で回る
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 →（軽い通し方の分岐: 本体は (1) の W を起こす前に記録先の本文（記録先が無い依頼では、上の「入口 0 は記録先を決める」の例外の順序どおり、Draft PR を作る前に本体が整理した受け入れ条件）から軽い通し方を当てるかを決め、当てるなら (1)〜(3) の W を起こさず、`references/light-path.md` の軽い通し方の手順どおり、判断の記録・直す・`確かめ方:` のコマンドの実行・commit と push・Draft の PR・仕様宣言までを本体が行って (4) へ進む（SHALL）。迷ったら当てず (1) へ進む）→ (1) W が仕様化判断の記録・分割判定・openspec CLI による change の作成（`openspec new change` と artifact の直書き）まで行い return（仕様化しない判定なら (3) へ直行。文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）なら、W は仕様の差分 1 ファイルだけを書いて return し、本体は記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があることを確かめてから (2) を飛ばして (3) へ進む）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりに BLOCKER が残れば、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の直し方の判定を通し、「決まっている」で PR トークン上限の内側なら主に聞かず次の周を回し、そうでなければ `needs-approval`）→ **(3) W を再開して実装以降を回す。(3) は 2 段に分かれ、(3a) 実装（`tasks.md` を TDD で。直行なら TDD。文言合わせの通し方なら W が (1) の return に書いた作業項目を TDD で）・verify（`openspec validate --strict`）まで行って return、本体が計測し、W の return の `画面確認:` の行が `要る` なら画面確認役 V を起こしてから（下の「画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす」Requirement）、(3b) `openspec archive`・PR を Draft のまま用意（無ければ Draft で作成）・仕様宣言まで行って return する（下の「W の (3) は 2 回の return に分かれる」Requirement）** → 文言合わせの通し方では、本体は G を起こす前に、記録先の最新の仕様化判断のコメントの `直す文:` の行が archive 済みの差分の要件名と一致することを確かめる（SHALL） → (4) G が pr-review-gate の手順 1〜5 を実行し `passed` / `failed` / `保留` / `needs-reviewer` / `needs-decider` / `needs-fix-check` / `review-incomplete` のいずれかを return。PR の Ready 化は G が手順 5 の合格処理で行い（Draft なら Ready にしてから `agent-review:passed` を付ける）、W は行ってはならない（MUST NOT）。

G が `review-incomplete` を return したとき、本体は新しい reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止めなければならない（MUST）。`needs-reviewer` が一周目照合の補足要求である場合、本体は fresh reviewer に固定 HEAD・元の三表・残差・補足済み回数を渡し、同じレビューの不足分だけを補わせなければならず（MUST）、レビューを最初からやり直させてはならない（MUST NOT）。

failed のときは、G の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出／段 A だけ（昇格なし））で戻し方を決めなければならない（MUST）。モデルを上げるのは**実装品質起因のときだけ**で、そのとき上げるのは**決める役と実行役のどちらか一方だけ**である（MUST）: 実行側が原因（指示どおり実装して結果が違う）なら `codex-develop.py request --phase implement --failure executor` を呼んで実行役を上げ、判断側が原因（指示を解釈できなかった・指示自体が外れていた）なら `request --phase decider --failure first|judgment` を呼んで決める役を `subagent_type: dev-workflow:decider` で立てて修正方針を作らせ、実行役は据え置く（SHALL）。判断側の `--failure` の値は、そのゲートの 1 回目の failed なら `first`、そのゲートの 2 回目以降の failed（1 回目の原因が実行側だったときも含む）なら `judgment` とする（SHALL）。どちらの場合も本体は `request` が返した `model` を使い、返った `model` と違う `model` を独自に指定してはならず（MUST NOT）、`model` が W の applied model と変わるときは SendMessage で再開せず新しい thread に手渡す（SHALL）。**実行役を最上位の格に上げてはならない**（MUST NOT。実行役の格の上限は上位で、Claude では `opus`）。仕様が曖昧なら仕様修正で返し、レビュアーの誤検出なら反証で返す。どちらもモデルを上げてはならない（MUST NOT。pr-review-gate 手順 2-2 の基線をこの change は変えない）。段 A だけなら W を据え置きで再開する（MUST）。修正後は G を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりの扱いは pr-review-gate の収束ルールと、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement に従う）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

G が failed を `原因: 軽い通し方の条件外` で return したとき、本体は原因分類によるモデルの昇格を行ってはならず（MUST NOT）、W を `段: spec` で新しく起こし、起動指示に G の確認コメントの URL を書かなければならない（MUST）。W は `通し方:` の行の無い仕様化判断を投稿し直し、テストを書いて同じ PR に積む（SHALL）。この failed はレビューの周に数えず、前の Gate Result を渡さずゲートの開始として起こし、`周回: 1` の全体レビューにする（W の修正後の再レビューとして扱わない）（SHALL）。本体は、条件外と判定された記録先で `通し方: 軽い` の仕様化判断を投稿し直してはならない（MUST NOT）。

軽い通し方の PR（記録先の最新の仕様化判断のコメントに `通し方: 軽い` の行がある PR）で、軽い通し方の確認を条件内で通ったあとに G が修正を求める failed を return したとき（照合と振り分け・保留の解除のどちらの段からでも）、W はまだ起きていないので、本体は W を再開してはならず（MUST NOT）、本体が自分で直してもならない（MUST NOT）。本体は W を `段: spec` で新しく起こし、起動指示に failed の Gate Result と G の仕分けコメントの URL を書かなければならない（MUST）。W の model は上の原因分類の規則（実装品質起因のときだけ一方を上げる）で決める（SHALL）。W は `通し方:` の行の無い仕様化判断を投稿し直し（「する」か「しない」かは W が決め直す）、テストを書いて同じ PR に積む（SHALL）。W が起きた PR は以後通常の通し方として扱い、そのあとの G は failed の `次の段:` によらず前提確認と重さ判定の段から起こす（SHALL。判断の記録が変わったため）。

軽い通し方では本体は直す前に対象専用の worktree（1 issue = 1 worktree）に入り、無ければ `/wt-setup` で作る（SHALL）。途中離脱と G の failed からの戻り経路の W も同じ worktree で起こす（SHALL）。

worktree は本体が用意する（SHALL）: 本体が既に対象専用の worktree にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。W は自分で worktree を切らない（MUST NOT。セットアップは worktree プラグインの hooks が担い、`.worktreeinclude` が無いときの `/wt-setup` は本体が行う）。**W / G を `isolation: "remote"` で起こしてはならない**（MUST NOT）。強制停止に当たったサブエージェントの未コミット差分は本体が確認して commit する設計（下の「強制停止で止まった作業ツリーは本体が引き取る」Requirement）だが、`remote` 隔離は本体から見えない環境で動くため、そこで強制停止に当たると作業がそのまま失われる。

`/opsx:*` のスラッシュコマンドは、本体や主が対話で change を作る場面の道具として SKILL.md に書いてよい（MAY）が、W が実行する工程として 1 ループに書いてはならない（MUST NOT。W の種別 `dev-workflow:worker` は `Skill` を持たない）。

この要件の failed 分岐の守備範囲で入力として扱うのは、G の `failed` の return に書かれた原因分類と、本体が `request` を呼んで得る返り値（`model`・`tier`）である。拾いたい誤りは、`request` が返した model を使わずにモデル名を直接指定すること、実行役を最上位の格に上げること、決める役と実行役を同時に上げること、判断側の `--failure` の値をゲートの何回目の failed かと食い違えて渡すことである。一方、G が原因分類そのもの（実行側か判断側か）を誤ることはこの契約では検出せず、許容する。`request` が上限を適用して低い格の model を返したときは、その model を使うことも許容する。穴が見つかるたびに塞ぎ切ること（任意の不正入力や将来の executor への対応を際限なく足すこと）は、この要件の完了条件にしない。

#### Scenario: ループの順序が書かれている
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** 0〜4 の工程が W→R1→W→G の順で並び、(1) の W の工程に `openspec new change` があり、仕様化しない判定は (3) へ直行し、R1 と G にそれぞれ既定 2 周と、2 周目以降の周の終わりに直し方の判定を通す続行がある

#### Scenario: 軽い通し方は W を起こさず (4) へ進む
- **WHEN** SKILL.md の 1 ループの (0) と (1) の間を読む
- **THEN** 本体が (1) の W を起こす前に軽い通し方を当てるかを決め、当てるなら (1)〜(3) の W を起こさず本体が直して (4) へ進むこと（unmanned では G を起こさず `agent-review:pending` を付けて終える）と、手順の正本が `references/light-path.md` であることが書かれている

#### Scenario: 軽い通し方の条件外の failed は W を段 spec で起こす
- **WHEN** G が failed を `原因: 軽い通し方の条件外` で return する
- **THEN** 本体はモデルを上げず、W を `段: spec` で新しく起こして起動指示に G の確認コメントの URL を書き、W は `通し方:` の行の無い仕様化判断を投稿し直してテストを書く

#### Scenario: 軽い通し方の PR で通常のレビューが修正を求めた
- **GIVEN** 軽い通し方の PR が軽い通し方の確認を `条件内` で通り、W はまだ起きていない
- **WHEN** 照合と振り分けの G が修正を求める failed（`次の段: 照合と振り分け` を含む）を return する
- **THEN** 本体は W を再開せず自分でも直さず、W を `段: spec` で新しく起こして failed の Gate Result と仕分けコメントの URL を渡し、W は `通し方:` の行の無い仕様化判断を投稿し直してテストを書き、そのあとの G は前提確認と重さ判定の段から起こす

#### Scenario: 文言合わせの通し方は (2) を飛ばす
- **WHEN** SKILL.md の 1 ループの (1) と (2) を読む
- **THEN** 文言合わせの通し方では W が仕様の差分 1 ファイルだけを書いて return し、本体が記録先の仕様化判断のコメントの `通し方: 文言合わせ` の行を確かめて R1 を起こさずに (3) へ進むことが書かれ、その行が無ければ (2) の R1 を通すことが書かれている

#### Scenario: 文言合わせの通し方では G を起こす前に本体が直す文の行を確かめる
- **WHEN** SKILL.md の 1 ループの (4) を読む
- **THEN** 文言合わせの通し方では、本体が G を起こす前に、記録先の最新の仕様化判断のコメントの `直す文:` の行が archive 済みの差分の要件名と一致することを確かめると書かれている

#### Scenario: (3) は 2 段に分かれて書かれている
- **WHEN** SKILL.md の 1 ループの (3) を読む
- **THEN** (3a) と (3b) が別々の return として並び、(3a) に TDD の実装と `openspec validate --strict` が、(3b) に `openspec archive`・PR・仕様宣言が入り、(3a) と (3b) の間に V を起こす分岐がある

#### Scenario: 1 ループに W が /opsx を実行する工程が無い
- **WHEN** SKILL.md の 1 ループの節を読む
- **THEN** `/opsx:ff`・`/opsx:apply`・`/opsx:verify`・`/opsx:archive` の文字列が無い

#### Scenario: (3b) は PR を Draft のまま G に渡す
- **WHEN** SKILL.md の 1 ループの (3b) と `references/roles/worker/finish.md` の (3b) を読む
- **THEN** PR を Draft のまま用意する（issue が記録先なら `gh pr create --draft`）と書かれ、W が PR を Ready に切り替える記述が無く、Ready 化は G が pr-review-gate 手順 5 で行うと書かれている

#### Scenario: W / G は remote 隔離で起こさない
- **WHEN** SKILL.md の spawn の記述を読む
- **THEN** W / G を `isolation: "remote"` で起こしてはならないと書かれている

#### Scenario: G の failed は片方だけ上げて W の再開に戻る
- **WHEN** G が failed を return する
- **THEN** SKILL.md は実装品質起因のときだけ原因分類に応じて、実行側なら `--failure executor` の `request` が返した model で実行役を上げるか、判断側なら `--failure first`（ゲートの 1 回目の failed）または `judgment`（そのゲートの 2 回目以降の failed。1 回目の原因が実行側だったときも含む）の `request` が返した model で決める役を `dev-workflow:decider` で立てるかの一方だけを行い、仕様が曖昧・レビュアーの誤検出・段 A だけ（昇格なし）ではモデルを上げず、段 A だけなら W を据え置きで再開し、実行役を最上位の格に上げず、G を再開して差分再レビューするよう指示している

#### Scenario: decider として起こした R1 の結果は本体が投稿する
- **WHEN** SKILL.md の (2) の記述を読む
- **THEN** R1 が `dev-workflow:decider` の場合は本体が return を同じ書式で記録先に代理投稿すると書かれている

#### Scenario: review-incomplete は reviewer を再起動しない
- **WHEN** G が補足後の残差を `review-incomplete` で return する
- **THEN** 本体は fresh reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止める

### Requirement: G が passed を返したら本体が CI を見張る
`skills/develop/SKILL.md` の (4) は、G が `passed` を return したあと、本体が `plugins/dev-workflow/references/ci-watch.md` の手順で CI の見張りを始めることを書かなければならない（MUST）。G の `passed` の return に `issue で承認済み:` の行があれば、本体は見張りを始める前に、主へその行（宣言コメントの URL・当たった分類・引用した issue の文）を 1 回伝えなければならない（MUST。pr-review-gate 手順 5 の事後報告。auto-merge 配備リポではマージまで主との会話が起きないため、本体の手順に置かないと報告が起きない）。見張りの一手が `fix` のときは、本体が W に直させる（MUST）。担当と段の分岐は `references/light-path.md` の「CI 見張りの fix からの戻し方」に定め、SKILL.md の passed 分岐と共有 reference の直し方から参照できなければならない（MUST）。軽い通し方（記録先の最新の仕様化判断に `通し方: 軽い` の行がある PR）では、本体が同じ worktree に W を `段: spec` で新しく起こし、PR・記録先・`fix` の観測（`ci-fail` または `conflict` と失敗したチェック・run などの修正材料）を渡す（SHALL）。起動指示には `plugins/dev-workflow/references/ci-watch.md`「7. 直し方」に従うこと（最初の push の前に手順 3 の passed 解除・Draft 化・pending 付与）と、`ci-fail` の関係確認を仕様化判断の再投稿より先に行うことを含める（SHALL）。存在しない W の再開や本体による直接修正をしてはならない（MUST NOT）。新しい W は、`ci-fail` では仕様化判断の手順に入る前に共有手順「7. 直し方」手順 2 の失敗ログと PR 差分の関係確認を行い、同文書「5. `--unrelated` を渡す基準」で差分と無関係と判断できた場合は、仕様化判断を投稿し直さず、artifact 作成・修正・push をせずにチェック名と根拠を本体へ返さなければならない（MUST）。この場合は最新の `通し方: 軽い` の判断を保持し、passed 解除・Draft 化・pending 付与にも進まず、本体が同じ PR・同じ状態ファイルで既存の `next --unrelated <チェック名> --after-fix` を 1 回だけ実行してその一手に従う（SHALL）。関係がある場合、または無関係と判断できない場合は、この確認のあと、実装前に同じ記録先へ `通し方:` の行の無い仕様化判断を投稿し直す（SHALL。「する」か「しない」かは W が決め直す）。`conflict` はこの無関係返却の対象とせず、従来どおり判断を投稿し直す（SHALL）。修正に進む場合、以後は通常の通し方で、仕様化するなら artifact 一式と R1 の APPROVE を経て実装し、どちらの判断でもテストを書き、修正を同じ PR に積む（SHALL）。同じ記録先へ `通し方: 軽い` を投稿し直してはならない（MUST NOT）。通常経路で既存 W がある場合（軽い通し方から既に通常へ戻った PR を含む）は、W を `段: implement` で再開し、再開か手渡しかは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」に従う（SHALL）。この場合は CI 見張りの `fix` だけを理由に `段: spec` へ戻したり仕様化判断を投稿し直したりしない（SHALL）。軽い通し方から戻した W の仕様化途中の push では見張りに戻らず、通常経路の (1) → R1（仕様化する場合）→ (3a) → (3b) を進め、(3b) の return を受けてから `wait` → `next` に戻る（SHALL）。通常経路の既存 W が push したら本体が passed を外したまま同じ状態ファイルで `wait` → `next` を続け（CI のやり直し・再度の直しもここで処理する）、`ready` になってから前提確認と重さ判定の G を新しく起こしてゲートを取り直させ、G が再び `passed` を返したら見張りの続き（reference の「`ready` を受けたあと」）に進むこと、合格するまでマージ待ち・マージ依頼に進まないことを書く（MUST）。見張りの中身は reference を参照し、SKILL.md に言い換えて再掲してはならない（MUST NOT）。

**復帰判定の守備範囲**: 入力は CI 見張りが返した `fix` の観測（`ci-fail` / `conflict`、チェック・run など）、記録先（issue または Draft PR）の最新の仕様化判断、本体が把握している W の有無と再開・手渡しの可否である。この判定は、存在しない W の再開、本体による直接修正、軽い判断を残したままの implement 起動、古い判断に基づく通常復帰後の spec 再起動を拾うために、担当・起動段・判断記録の接続を定める。CI 失敗と PR 差分の因果関係まで保証するものではなく、見張りが `fix` と判定した失敗を W がログ確認後に差分と無関係と判断し、修正・push せず本体へ返し、共有手順の `next --unrelated <チェック名> --after-fix` に進むことを許す。軽い通し方から起きた新しい W では、この関係確認は通常判断の再投稿より前に行い、無関係と判明した失敗では最新判断だけを通常化してはならない（MUST NOT）。完了条件は上記の接続を手順と関係テストで確認することであり、観測や W の判断に残る穴をすべて塞ぎ切ることを完了条件にしてはならない（MUST NOT）。

G の指示書 `skills/develop/references/roles/gate-runner.md` は、G が CI の見張りを始めずに `passed` を return することを書かなければならない（MUST）。unmanned モードは (4) を回さないので、この見張りの対象外とする。

#### Scenario: (4) の passed のあとに本体が見張る
- **WHEN** `skills/develop/SKILL.md` の (4) を読む
- **THEN** `passed` を受けた本体が `references/ci-watch.md` の手順で見張りを始めること、`fix` なら W に直させ、軽い通し方から戻した W は (3b) の return 後、通常経路の既存 W は push のあと passed を外したまま `wait` → `next` を続けて `ready` になってから G にゲートを取り直させることが書かれている

#### Scenario: G は見張りを始めない
- **WHEN** `skills/develop/references/roles/gate-runner.md` を読む
- **THEN** G が CI の見張りを始めずに `passed` を return することが書かれている

#### Scenario: issue で承認済みの passed は見張りの前に主へ伝える
- **WHEN** `skills/develop/SKILL.md` の (4) の passed の行を読む
- **THEN** return に `issue で承認済み:` の行があれば、CI の見張りを始める前に主へその行（宣言 URL・分類・引用）を 1 回伝えることが書かれている

#### Scenario: 軽い通し方の passed 後に CI 失敗の fix を受ける
- **WHEN** W 未起動で、記録先の最新の仕様化判断に `通し方: 軽い` の行がある PR に対して、CI 見張りが `ci-fail` による `fix` を返す
- **THEN** 本体は同じ worktree に新しい W を `段: spec` で起こし、PR・記録先・失敗したチェックと run を含む観測を渡す。本体は自分で直さず、W は仕様化判断の手順に入る前に共有手順で失敗ログと PR 差分の関係を確かめる。関係がある、または無関係と判断できない場合は、確認のあと実装前に `通し方:` の無い仕様化判断を同じ記録先へ投稿し直す

#### Scenario: 軽い通し方の passed 後に競合の fix を受ける
- **WHEN** 同じ軽い通し方の PR に対して、CI 見張りが `conflict` による `fix` を返す
- **THEN** CI 失敗の場合と同じく、新しい W が `段: spec` から通常経路への判断を記録し直す。競合だけを理由に本体修正や `段: implement` の新規起動に短絡しない

#### Scenario: 新しい W が仕様化すると判断する
- **WHEN** 軽い通し方の fix から起きた W が `仕様化判断: する` を投稿し直す
- **THEN** `通し方:` の行は付けず、artifact 一式を作り R1 の APPROVE 後にテストと修正を同じ PR に積む

#### Scenario: 新しい W が仕様化しないと判断する
- **WHEN** 軽い通し方の fix から起きた W が `仕様化判断: しない` を投稿し直す
- **THEN** `通し方:` の行は付けず、通常経路の実装工程でテストと修正を同じ PR に積む。過去の軽い判断は履歴に残っても最新の判断としては使わない

#### Scenario: 通常経路の既存 W が CI の fix を直す
- **WHEN** 最新の仕様化判断が軽い通し方ではなく、通常経路の既存 W がいる PR に CI 見張りが `fix` を返す
- **THEN** 本体は既存 W を `段: implement` で再開する。手渡しは正本の許可条件を満たすときだけ行い、CI の fix だけを理由に spec 段や仕様化判断の投稿をやり直さない

#### Scenario: 通常経路へ戻した後にもう一度 fix を受ける
- **WHEN** 軽い通し方から通常へ戻した PR で、W の修正 push 後に CI 見張りが再び `fix` を返す
- **THEN** 最新の仕様化判断には `通し方: 軽い` が無いので、既存 W の `段: implement` の再開／許可された手渡しを使い、新しい spec 段の W を重ねて起こさない

#### Scenario: 軽い通し方から戻した W の仕様化途中の push では見張りを再開しない
- **WHEN** 軽い通し方の fix から起きた W が仕様化の段で push し、R1 の APPROVE と (3b) の return がまだない
- **THEN** 起動指示で渡した「7. 直し方」の手順 3 により最初の push 前に passed 解除・Draft 化・pending 付与を済ませる。本体は見張りの wait / next に戻らず、R1 の APPROVE を経て (3a) → (3b) を進める

#### Scenario: 両経路とも同じ見張りの続きからゲートを取り直す
- **WHEN** 新しく起きた W が CI 見張りの fix を直して (3b) の return を返す、または通常経路の既存 W が修正を同じ PR に push する
- **THEN** 本体は passed を外したまま同じ状態ファイルの `wait` → `next` を続け、`ready` になってから前提確認と重さ判定の G を新しく起こす。合格するまでマージ待ち・マージ依頼に進まない

#### Scenario: 新しい W が失敗を差分と無関係と判断したら軽い判断を保持する
- **WHEN** 最新判断が `通し方: 軽い` の PR の `ci-fail` による fix から起きた新しい spec 段 W が、判断再投稿前のログと差分の確認で、共有手順の無関係の 2 条件を満たすと判断する
- **THEN** W は仕様化判断の再投稿・artifact 作成・修正・push をせず、チェック名と根拠を本体へ返す。最新判断は軽いままで、passed 解除・Draft 化・pending 付与に進まない。本体は同じ PR・同じ状態ファイルで `next --unrelated <チェック名> --after-fix` を 1 回だけ実行し、その一手に従う

#### Scenario: 判断不能なら関係確認のあと通常復帰する
- **WHEN** 同じ新しい W がログと PR 差分を確かめても、共有手順の無関係の 2 条件を両方満たすとは判断できない
- **THEN** 無関係として返さず、確認のあと `通し方:` の行の無い仕様化判断を投稿し直す。「する」なら artifact 一式と R1 の APPROVE を経て実装し、どちらの判断でもテストと修正を同じ PR に積む

#### Scenario: spec 段の一般手順より先に CI 失敗の関係を確認する
- **WHEN** 軽い通し方の CI fix から新しい W を起こす指示と `roles/worker/spec.md` を読む
- **THEN** light-path.md の復帰手順へ接続し、`ci-fail` の関係確認を仕様化判断の投稿より先に行い、無関係なら判断記録の手順へ入らず返すことが一意に定まる

### Requirement: 通常判断で W を把握しない本体は許可された手渡しで implement 担当を用意する

最新の仕様化判断が通常経路で、本体が既存 W を把握しない場合、light-path.md の CI fix 分岐は、handover.md の CI 用手順へ渡さなければならない（MUST）。本体は最新の引き継ぎの対象一致、必要情報、手渡し許可の根拠を確認できた場合だけ、新しい W を `段: implement` で起こす（MUST）。既存判断と必要な R1 APPROVE を維持し、fix だけを理由に spec へ戻したり仕様化判断を再投稿したりしない（MUST NOT）。ci-watch.md 9 の再起動と 2 の指示による再開の fix にも同じ分岐を適用する（SHALL）。

#### Scenario: 起動し直した本体が通常経路の CI 失敗を受ける
- **WHEN** ci-watch.md 9 から `ci-fail` の fix に進む本体が W を把握せず、PR コメント全ページから得た最新の CI 用引き継ぎに必要情報と手渡し可の根拠があり、PR・HEAD・ブランチ・worktree が現在の対象と一致している
- **THEN** 本体は記録先の最新判断を取り直し、通常経路であることを確かめる。引き継ぎの実行モード・実行先・周回・上限を継承し、起動前に最新の可を不可として投稿したあと、新しい W に `段: implement`、前任 return、PR・記録先、失敗したチェック・run を含む fix の観測、ci-watch.md 7 の直し方を渡す。W は git status / git diff で現状を確認し、必要な R1 APPROVE を確認してから実装する

#### Scenario: オーナーの指示で再開した本体が競合を直す
- **WHEN** ci-watch.md 2 の手順で中断済みの `conflict` の fix に戻り、W 不明だが同じ対象の必要情報と手渡し可の根拠が揃っている
- **THEN** 本体は同じ implement の手渡しを使い、既に数えられた fixes を増やさずに直しを依頼する。存在しない W の再開や本体の直接修正はしない

#### Scenario: 既存 W がある通常経路と軽い経路を維持する
- **WHEN** 最新判断が通常経路で既存 W を把握している、または最新判断に `通し方: 軽い` がある
- **THEN** 前者は既存の許可条件に従う implement 再開／手渡しとし、起動／再開前の不可の投稿も行う。後者は同じ worktree の新しい spec 段の W を使う。過去の軽い判断や古い CI 引き継ぎで分岐を変えない。軽い経路から通常復帰後の再 fix にも最新判断を使う

### Requirement: 途中停止したときの return の 1 行目

途中計測で工程を締めるとき、W / G が return の 1 行目に書く申告（#253 の規約）は次のとおりでなければならない（MUST）。

- **強制停止**（`DEV_WORKFLOW_CONTEXT_HARD_CAP` 超でツールを拒否された）で止まった場合は、成果を書いていても必ず `工程中断:` とする（MUST）。拒否された時点で予定していた作業が残っているため。
- **通知**（`DEV_WORKFLOW_CONTEXT_CAP` 超）を受けて締める場合は、そのとき進めていた tasks グループの項目がすべて完了していれば `工程完了:`、1 つでも残っていれば `工程中断:` とする（MUST）。

この区別が要るのは、`工程完了:` が手渡しの条件として使われており、手渡し先の W / G が未コミット差分と残作業を先に確認しなければならないのは中断のときだけだからである。判定は「そのとき進めていた tasks グループの項目がすべて済んでいるか」だけで行い、他の材料を要求してはならない（MUST NOT）。

途中計測の通知は役割で出し分けないため、`tasks.md` を持たない受け手（仕様化しない依頼の W、pr-review-gate の手順を回す G）にも同じ文言が届く。したがって「tasks グループ」が何を指すかを次のとおり定めなければならない（MUST）: `tasks.md` があればそのとき進めていた章のグループ、無ければ本体から渡された作業項目、G は pr-review-gate の手順 1〜5 を 1 グループとみなす。

この判定の守備範囲は次のとおりとする。①入力の出どころは、W / G が書く return の 1 行目と、そのとき進めていた tasks グループ（上の定めで決まる単位）の項目が済んでいるかの W / G 自身の申告である。本体はこの 1 行目だけで手渡しの可否を決め、`tasks.md` のチェック欄や差分と突き合わせない。②拾いたい誤りは、強制停止で止まったのに `工程完了:` と書くこと、通知を受けて締めたときに項目が残っているのに `工程完了:` と書くこと、1 行目を 2 つの書式のどちらにも一致させないことである（一致しない 1 行目は本体が `工程中断:` として扱うので手渡しは起きない）。③次はこの判定を通ることを許す: 済んでいない項目を済んだと申告した `工程完了:`（手渡し先は前任の return と記録先とファイルの現状から再出発し、未コミット差分を確かめる）。`tasks.md` のチェックを付け忘れたまま項目が済んでいる `工程完了:`。④ここに挙げた以外の通り方は見つけるたびに条件を足し、穴を塞ぎ切ることを完了条件にしない。

#### Scenario: 強制停止は常に工程中断

- **WHEN** `references/return-declaration.md` を読む
- **THEN** 強制停止で止まった場合は成果があっても `工程中断:` にする、と書かれている

#### Scenario: 通知は tasks の残りで決める

- **WHEN** 同じファイルを読む
- **THEN** 通知を受けて締める場合は、そのとき進めていた tasks グループが全部済んでいれば `工程完了:`、1 つでも残っていれば `工程中断:` にする、と書かれており、`tasks.md` が無い場合に何を 1 グループとみなすかも書かれている

### Requirement: W の return は読んだコードの要点を持つ

`references/roles/worker/common.md` は、W の return の成果一覧（この欄は W の場合のみ必須で、G の return の契約は変えない。工程の終わりの return、途中で締めた return、昇格トリップワイヤーで止まったときの return のいずれも）に「読んだコードの要点」欄を含めることを書かなければならない（MUST）。欄の書式は 1 行 1 件の `<リポジトリ相対パス>:<開始行>-<終了行> — <そこから分かったこと>` とし、上限を 20 行とし、超えるときは次の工程で読む必要が高いものを残すと書かなければならない（MUST）。

`worker/common.md` の「コンテキスト上限と手渡し」の節は、手渡しで起こされた W に向けて、前任の要点は読む場所の案内であり、編集する前には該当範囲を自分で読んで確かめることを書かなければならない（MUST）。要点を判断の根拠として読み替えてよいと書いてはならない（MUST NOT）。

`references/return-declaration.md` が成果一覧を列挙する箇所（`工程完了:` の説明と、通知を受けたときの振る舞い）は W / G 共通の定義なので、「読んだコードの要点」を「W の場合のみ必須」という条件付きで含まなければならない（MUST）。G に必須と読める無条件の追記をしてはならない（MUST NOT。G は段ごとに新しく起こされ、`工程中断:` の return を同じ段の新しい G に渡す既存の経路はこの欄を前提にしないため）。書式（1 行の形・上限行数）は `worker/common.md` を正本とし、`return-declaration.md` に再掲してはならない（MUST NOT。上限を変えたときに片方が取り残されるため）。

#### Scenario: worker/common.md の手渡しの節に欄と書式がある
- **WHEN** `references/roles/worker/common.md` の「コンテキスト上限と手渡し」の節を読む
- **THEN** 成果一覧に「読んだコードの要点」があり、W の場合のみ必須であること、1 行 1 件の `ファイル:行の範囲 — 分かったこと` の形と上限 20 行が書かれている

#### Scenario: 後任は要点を案内として扱う
- **WHEN** `references/roles/worker/common.md` の「コンテキスト上限と手渡し」の節の、手渡しで起こされたときの箇条を読む
- **THEN** 前任の要点は読む場所の案内であり、編集前に該当範囲を自分で読んで確かめると書かれている

#### Scenario: (3a) とトリップワイヤーの return にも欄がある
- **WHEN** `references/roles/worker/implement.md` の「(3a) の return に書くこと」と `references/roles/worker/common.md` の「昇格トリップワイヤー」の節を読む
- **THEN** どちらにも「読んだコードの要点」を書くことが含まれている

#### Scenario: 手渡しの入力の定義に欄の名前がある
- **WHEN** `references/return-declaration.md` を読む
- **THEN** 成果一覧を列挙する 2 箇所がどちらも「読んだコードの要点」を「W の場合のみ必須」の条件付きで含み、書式は `worker/common.md` を参照していて、上限行数の数値は書かれていない

### Requirement: W の指示書は索引・共通・段のファイルに分かれている

`plugins/dev-workflow/skills/develop/references/roles/worker.md` は索引でなければならない（MUST）。索引は、段の表（段の名前 `spec` / `implement` / `finish`・日本語名・担う工程・読むファイル）だけを持ち、手順の本文・コードブロック（```）・旧 worker.md の節から移し先への対応表を持ってはならない（MUST NOT）。

W の手順の本文は `skills/develop/references/roles/worker/` の次の 4 本に置かなければならない（MUST）:

- `common.md`（全段で読む）: 本体が渡すもの（`段:` の行を含む）・W がしないこと・実装に入る前の確認（仕様化判断の記録前に実装へ進まないこと・仕様化した場合に R1 の APPROVE を確認してから実装に入ること・仕様レビュー結果の書式）・昇格トリップワイヤー・コンテキスト上限と手渡し（「(3) をこれより細かく切らない」の箇条を除く）
- `spec.md`（仕様づくり。(1) と R1 の差し戻しの修正）: 記録先の用意（Draft PR を記録先にする場合）・仕様化判断と記録・分割判定・仕様化する場合
- `implement.md`（実装と検証。(3a) と、G の failed や CI の見張りの `fix` を受けた修正）: (3a) 実装＋verify
- `finish.md`（仕上げ。(3b)）: (3b) archive＋PR＋仕様宣言

どの段でも要る規則（W がしないこと・実装に入る前の確認・昇格トリップワイヤー・コンテキスト上限と手渡し）は `common.md` に置き、それを使う全部の段から読める位置になければならない（MUST。1 つの段のファイルにだけ置いて、他の段で効かなくしてはならない）。節の置き場所は、その節を使う段と読み手（W か本体か）で決める（MUST）。W が段ごとに読むファイルの合計の予算は「W が段ごとに読むファイルの合計に予算を置く」の要件が定める。`worker/` の 4 本・索引・`references/pre-classification.md` の `## ` 見出しは、このうち 1 ファイルにだけなければならない（MUST。同じ節を 2 か所に書かない）。移すときに手順の中身（規則・書式・コマンド・閾値）を変えてはならない（MUST NOT）。段をまたぐ参照はファイル名と節名で書き、中身を言い換えて再掲してはならない（MUST NOT）。

「(3) をこれより細かく切らない」の箇条（手渡しの固定分と、実装の途中で交代させたときに後任が Red のテストから再出発する理由）は、develop の `SKILL.md` の (3) に置かなければならない（MUST）。SKILL.md はこれを理由の正本として持ち、索引 `references/roles/worker.md` や `references/roles/worker/` の指示書を理由の正本として指してはならない（MUST NOT）。

この要件の回帰テスト（`plugins/dev-workflow/tests/develop-worker-stages.bats`）の守備範囲は次のとおりとする。入力は索引 `references/roles/worker.md`・`worker/` の 4 本・`references/pre-classification.md` のファイルの中身で、拾うのは、索引の中のコードブロック・段の表が指すファイルの不在・昇格トリップワイヤーの節が `common.md` に無いこと・同じ `## ` 見出し行が 2 ファイル以上にあること、である。次はテストを通ってしまい、この要件の回帰テストでは止めない: 見出しを変えて同じ節を別のファイルに書いたもの、見出し以外の本文で規則を言い換えて再掲したもの、移すときに規則・書式・コマンド・閾値の文言を変えたもの、索引がコードブロックを使わずに旧 worker.md の節から移し先への対応表を持つもの、W が段のファイル以外（`references/return-declaration.md`・`references/spec-decision.md` など）を読む分。これらは PR レビューで見る。この穴をテストで塞ぎ切ることは完了条件にしない。

#### Scenario: 索引が中身を持たない

- **WHEN** `references/roles/worker.md` を読む
- **THEN** コードブロックが無く、段の表の `spec` / `implement` / `finish` の各行がそれぞれ `worker/spec.md` / `worker/implement.md` / `worker/finish.md` の 1 つだけを指し、そのファイルと `worker/common.md` が実在する

#### Scenario: どの段でも要る規則が全段から読める

- **WHEN** `worker/common.md` の見出しを読む
- **THEN** 「W がしないこと」「実装に入る前の確認」「昇格トリップワイヤー」「コンテキスト上限と手渡し」の節があり、段のファイル（`spec.md` / `implement.md` / `finish.md`）にはこれらの見出しが無い

#### Scenario: 実装の段から起こされた W も承認の確認を読む

- **WHEN** 手渡しや Codex の新しい phase で `段: implement` の W が起こされ、`worker/common.md` と `worker/implement.md` だけを読む
- **THEN** 仕様化判断の記録前に実装へ進まないことと、仕様化した場合に R1 の APPROVE のコメントを確認してから実装に入ることが読める

### Requirement: 事前分類表は W が読まないファイルに置く

重要実装の事前分類（聖域パス・マージ権限・層間契約・課金/法務の表と、W の上限・読んで判断する役の種別・残量モードの優先の説明）は、`plugins/dev-workflow/skills/develop/references/pre-classification.md` に置かなければならない（MUST）。このファイルが事前分類の正本であり、`worker/` の 4 本と索引に表を再掲してはならない（MUST NOT）。

事前分類を参照する次の箇所は `references/pre-classification.md` を指さなければならず（MUST）、事前分類について索引 `references/roles/worker.md` や `references/roles/worker/` の指示書を指してはならない（MUST NOT）: develop の `SKILL.md` の (1) の spawn の行と「モデル」の役割表・`references/roles/spec-reviewer.md`・`references/decision-criteria.md` の残量モードと共有枠モードの優先順位の表・pr-review-gate の `stages/triage.md`・`plugins/dev-workflow/references/model-tiers.md`・`plugins/dev-workflow/README.md`。

#### Scenario: 表が 1 か所にある

- **WHEN** `references/pre-classification.md` と `worker/` の 4 本と索引を読む
- **THEN** 事前分類表の 4 行は `pre-classification.md` にだけある

#### Scenario: 参照元が新しい置き場所を指す

- **WHEN** 上に挙げた参照元の、事前分類に触れる行を読む
- **THEN** どれも `pre-classification.md` を指し、事前分類について `roles/worker.md` や `roles/worker/` の指示書を指す行が無い

### Requirement: Codex の W の phase には共通と段のファイルを正本として渡す

`plugins/dev-workflow/scripts/codex-develop.py` は、Codex の W の phase に次の正本を付けなければならない（MUST）: `spec` は `skills/develop/references/roles/worker/common.md` と `worker/spec.md`、`implement` と `finish` は `worker/common.md` とそれぞれ `worker/implement.md`・`worker/finish.md`、`explore` と `summarize` は `worker/common.md` だけ。どの phase にも `skills/develop/references/decision-criteria.md` の代わりに `skills/develop/references/return-declaration.md` を付け（MUST）、`spec` にはさらに `skills/develop/references/spec-decision.md` を付ける（MUST）。`decision-criteria.md` を付けてはならない（MUST NOT。分けたあとは本体だけが使う規則のファイルのため）。索引 `roles/worker.md` を正本として付けてはならない（MUST NOT）。

#### Scenario: phase ごとの正本

- **WHEN** `codex-develop.py request` で `spec` / `implement` / `finish` / `explore` / `summarize` の依頼を作り、prompt の `CANONICAL SOURCE` 行を読む
- **THEN** 上の組み合わせのファイルが付き、`skills/develop/references/roles/worker.md` は付いていない

### Requirement: channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない

channel の本体は AskUserQuestion を呼んではならない（MUST NOT）。主に聞くときは、依頼の届いたチャンネル（依頼の発言の開きタグの `chat_id`）にチャンネルの返信ツールで質問を送り、そのターンを終えなければならない（MUST）。依頼がチャンネルから届いていないときは、そのセッションの運用が決める主への連絡先に送り、連絡先が分からなければ記録先に質問をコメントして `needs-approval` を付けて止まる（MUST）。記録に残す問い（保留の依頼・2 周キャップ超え・PR トークン上限・仕様レビューの条件の問い）は先に PR か記録先のコメントに書き、チャンネルの質問にそのコメントのフル URL を添える（MUST）。

`skills/develop/references/channel.md` の「channel の聞き方」は、develop と develop から読む文書の「interactive は AskUserQuestion で聞く」を、channel ではこの聞き方に読むと 1 か所に書き、対象の文書（`skills/develop/references/spec-decision.md`・`skills/develop/references/epic-child-stop.md`・`skills/develop/references/fix-check.md`・`skills/develop/references/roles/spec-reviewer.md`・`skills/develop/references/roles/worker/common.md`・`skills/develop/references/roles/worker/spec.md`・`templates/escalation-tripwires.md`・`commands/develop.md`・`commands/work-issue.md`・`commands/synced-skills-slim.md`・`skills/issueify/SKILL.md`）を、`plugins/dev-workflow/` からの相対パスの 1 つの形で挙げなければならない（MUST）。`plugins/dev-workflow/` 配下（`tests/` と `changes/` を除く。`changes/` は変更の記録で、手順として読まれない）で `AskUserQuestion` を含むファイルは、SKILL.md と `skills/develop/references/channel.md` と、手順として読まれない hook の 2 ファイル（`hooks/hooks.json` と `scripts/unattended-ask-guard.sh`。spec `unattended-ask-hook`）を除いてすべて、`plugins/dev-workflow/` からの相対パスがそのまま（バッククォートで囲んだ形で）この列挙に載っていなければならず（MUST）、bats で確かめる（SHALL。読み替えを 1 か所に書く方式は、列挙が漏れると漏れた文書の本体の手順が AskUserQuestion に流れるため）。`commands/develop.md` は、引数の分岐 ②⑤ の候補の提示と issueify フォールバックの承認が channel ではチャンネルでの質問になることを、その場にも書かなければならない（MUST。入口の分岐で主に聞く場面なので、channel.md の読み替えの規則の例外としてその場にも書く）。

この要件の守備範囲は、channel で本体が AskUserQuestion に流れる経路を develop の文面から無くすことである。拾いたい誤りは、develop の手順のどこかが channel の本体に AskUserQuestion を呼ばせること。develop 以外のスキル（wt-clean など）が AskUserQuestion を呼ぶことと、本体が文面に反して呼ぶことを機械的に止めることは、この要件の範囲に入れない（無人の印 `DEV_WORKFLOW_UNATTENDED` のあるセッションでは spec `unattended-ask-hook` の hook が止める。印が無く、チャンネルの依頼だけで channel になったセッションは、この要件の文面の規則だけが止める）。穴が見つかるたびに検査を足して塞ぎ切ることを、この要件の完了条件にしない（MUST NOT）。

#### Scenario: 2 周キャップ超えで選び直しが要る

- **WHEN** channel の本体で、仕様レビューの直し方の判定が「選び直しが要る」になる
- **THEN** 本体は記録先に `needs-approval` を付けて経緯をコメントし、そのコメントの URL を添えた質問を依頼の届いたチャンネルに送ってターンを終え、AskUserQuestion を呼ばない

#### Scenario: 引数なしの /develop をチャンネルで頼まれた

- **WHEN** channel の本体が `commands/develop.md` の分岐 ⑤（引数なし）を処理する
- **THEN** 開いている issue の一覧と 2 つの選択肢をチャンネルに送ってターンを終え、AskUserQuestion を呼ばない

#### Scenario: AskUserQuestion の経路が残っていない

- **WHEN** SKILL.md と `commands/develop.md` で `AskUserQuestion` を含む行を読む
- **THEN** その行か、`references/channel.md` の読み替えの規則によって、channel では AskUserQuestion を呼ばないことが読み取れる

#### Scenario: AskUserQuestion に触れるファイルが列挙から漏れていない

- **WHEN** bats が `plugins/dev-workflow/` 配下（`tests/` と `changes/` を除く）で `AskUserQuestion` を含むファイルを集める
- **THEN** SKILL.md と `skills/develop/references/channel.md` と `hooks/hooks.json` と `scripts/unattended-ask-guard.sh` 以外のすべてのファイルの `plugins/dev-workflow/` からの相対パスが、バッククォートで囲んだ形で `references/channel.md` の読み替えの対象の列挙に載っている

### Requirement: unmanned の W は質問を直接送らず本体へ返す
unmanned で仕様の発明が 2 回に達した、または change の割り方が判断できないほど曖昧なとき、W は Discord（MCP・CLI とも）へ直接送信してはならない（MUST NOT）。W は質問文・理由を return に含め、記録先に `needs-approval` を付けて経緯をコメントし、作業を止めて本体へ return しなければならない（MUST）。`worker/` 配下と `agents/worker.md` の Discord の記述は、W は送らず本体が送る否定文脈に限る（MUST）。worker の tools に Discord の道具を追加してはならない（MUST NOT）。

**守備範囲**: 静的検査の入力元は、対象指示書（`worker/` 配下・`references/spec-decision.md`・`SKILL.md` の実行モードの説明）と agent 定義（`agents/worker.md`）である。拾う誤りは、W による Discord 直接送信指示の再混入と、質問文・理由・needs-approval・経緯コメント・return などの return 契約の欠落とする。Discord 記述の分類では、例えば「W は Discord に送信せず、質問文を本体に返す」は直接送信指示として検出せず、検査を通る入力として許す（return 契約の充足は別途確認する）。自然文のあらゆる言い換えによるすり抜けを塞ぎ切ることは完了条件にしない。指定の grep 結果の全行確認を併用し、実際の Discord の配送成功はこの静的検査の対象にしない。

#### Scenario: 仕様の発明が 2 回に達した
- **WHEN** unmanned の W が記録先に無い仕様上の決定を埋めた回数が 2 回に達する
- **THEN** W は埋めた決定の一覧・質問文・理由を return に含め、記録先に `needs-approval` を付けて経緯をコメントし、作業を止めて本体へ返す。Discord へは直接送信しない

#### Scenario: change の割り方を判断できない
- **WHEN** unmanned の W が分割判定で割り方が判断できないほど曖昧だと判定する
- **THEN** W は子 issue を作らず、質問文・理由を return に含め、記録先に `needs-approval` を付けて経緯をコメントし、needs-approval と本体へ返す。Discord へは直接送信しない

#### Scenario: 直接送信を求める指示が無い
- **WHEN** `grep -rn -i discord plugins/dev-workflow/skills/develop/references/roles/worker/ plugins/dev-workflow/agents/worker.md` の全ヒットを確認する
- **THEN** W が MCP・CLI で直接送信する指示が 0 件であり、ヒットがあれば W は送らず本体が送る否定文脈だけである

#### Scenario: worker の tools を拡張しない
- **WHEN** `plugins/dev-workflow/agents/worker.md` の tools を確認する
- **THEN** `Read, Edit, Write, Bash, Grep, Glob, TaskStop` のままで、Discord の道具を追加していない

#### Scenario: 分割判定の正本も同じ送信主体を指す
- **WHEN** `references/spec-decision.md` の「割り方が判断できないほど曖昧な場合」の unmanned の説明を読む
- **THEN** W の質問文・理由の return と needs-approval・経緯コメント、および本体の代理送信の責務分担と整合し、W に直接送信を要求していない

### Requirement: 役割のモデルは事前分類と残量モードで決める
SKILL.md は役割ごとの格を次のとおり規定しなければならない（MUST。格の語と決め方は `model-tier-resolution` が定め、括弧内の名前は Claude での値）。「モデル」節は規則の説明と `codex-develop.py request` への参照とし、構成名を使った経路ごとのモデル名の書き分けを書いてはならない（MUST NOT）。本体は `request` が返した `model` を使い、新しい起動の `model` を文章の規則で計算し直してはならない（MUST NOT）。W は既定 中位（`sonnet`）、記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含むか、実行側が原因の失敗ループでの昇格か、事前分類（聖域パス・マージ権限・層間契約・課金/法務）に当たれば 上位（`opus`）。**W を `fable` で spawn してはならない**（MUST NOT。実行役の上限は `opus` で、強制層は `scripts/agent-model-guard.sh`）。R1 は既定 上位（`opus`）、仕様がマージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する（聖域パスだけでは上げない）。G は既定 中位（`sonnet`）で上げない（G の仕事は照合・ラベル操作で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う）。G が要求するレビュアーは既定 上位（`opus`）、対象がマージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。従来経路では G の `needs-reviewer` が示す推奨 model に従い、adapter 経路では phase `review` の `request` が返した `model`（残量上限を適用済み）を使い、G の推奨 model は参考値として扱わなければならない（MUST）。役割の格は残量モード（`FABLE_BUDGET_MODE`）と共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）の上限に従わなければならない（MUST。新しい起動への適用は `request` が行う）。2 つのモードの値ごとの効果は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の残量モードと共有枠モードの表 1 か所で定める（その表では、`abundant` はどの役割の既定も上げず、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 上限で `haiku` はそのままで、Fable 残量モードと食い違えば共有枠モードが勝つ。これは SKILL.md が書く中身ではない）。SKILL.md の「モデル」節は 2 つのモードの名前（`FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE`）と、効果がその表にあることだけを書かなければならない（MUST。値ごとの効果を再掲してはならない。同じ規則を 2 か所に書くと、直すときに片方が漏れて食い違うため）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した）は、失敗の原因が判断側か実行側かで決める役と実行役のどちらか一方だけを上げるラダー（正本は `templates/escalation-tripwires.md`）として残す（SHALL）。本体は W / G を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測らなければならない（MUST）。上限超過（exit 2）を検知したあとの扱い（送ってはならない SendMessage・手渡しを行ってよい条件・前任が動作中のまま交代させるときの手順）について、SKILL.md は本文を書かず、`plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」への参照だけを置かなければならない（MUST。return の 1 行目にどちらの宣言を置くかの正本は `plugins/dev-workflow/skills/develop/references/return-declaration.md` で、SKILL.md はその本文も書かない。正本の位置・参照だけにする面の一覧・テストの形は `dev-workflow-execution-strategy` が規定する）。

この要件の守備範囲で入力として扱うのは、G の起動・再開指示にある `レビュー経路:`、G の `needs-reviewer` が示す推奨 model、phase `review` の `request` が返す `model` である。防ぐ誤りは、経路ごとの決定元を取り違えること、`request` が返した model を G の推奨 model で上書きすること、新しい起動の `model` を本体が文章の規則で計算し直すことである。一方、`request` が `sonnet` を返して G が `opus` を推奨していても、`request` の値を採用することは許容する。任意の不正な経路・model・残量モード入力を検出して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W の既定が 中位（`sonnet`）で上限が 上位（`opus`）、R1 の既定が 上位（`opus`）、G の既定が 中位（`sonnet`）、事前分類（聖域パス・マージ権限・層間契約・課金/法務）で W は `opus` 止まり、R1 とレビュアーの fable は `dev-workflow:decider` 経由と書かれている
- **AND** `FABLE_BUDGET_MODE` と `SHARED_BUDGET_MODE` の効果は `references/decision-criteria.md` の表を見るよう書かれており、引き継ぎの判定役の行を除き `abundant`・`reserve`・`exhausted`・`throttled`・`depleted` の値ごとの効果を述べた文は無い（判定役は `request` を通らない役なので、depleted のときは起こさないことをその行に書く）

#### Scenario: レビュアーの model 決定元を経路で分ける
- **WHEN** SKILL.md の「G が要求するレビュアー」の行を読む
- **THEN** 従来経路では G の推奨 model に従い、adapter 経路では `request` が返した `model` を使って推奨 model は参考値とする、と書かれている

#### Scenario: 経路ごとのモデル名の書き分けが無い
- **WHEN** `awk '/^## モデル/{f=1;next} /^## /{f=0} f' plugins/dev-workflow/skills/develop/SKILL.md | grep -cE 'claude-write-codex-review|codex-standard'` を実行する
- **THEN** 0 を返す

#### Scenario: 失敗ループでは片方だけ上げる
- **WHEN** SKILL.md の失敗ループの記述を読む
- **THEN** 決める役と実行役のどちらを上げるかを失敗の原因分類で決め、両方同時に上げないこと、実行役の上限が `opus` であることが書かれている

#### Scenario: 再開前にコンテキスト量を測る
- **WHEN** SKILL.md の「1 ループ」節を読む
- **THEN** W / G を SendMessage で再開する前に `subagent-context.sh` で測ること、G の再開も同じであること、上限超過のあとの扱いは `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本であることが参照として書かれている
- **AND** そこに手渡しの条件・宣言の選び方・停止確認の手順を言い換えた文は無い

### Requirement: W の (3) は 2 回の return に分かれる
本体がサブエージェントのコンテキスト量を測れるのは、W を SendMessage で再開する直前（＝ W が return した直後）だけである。したがって return の区切りの数がそのまま計測点の数になる。W の実装以降の工程 (3) は、次の 2 つの return に分けなければならない（MUST）。

- **(3a) 実装＋verify**: 実装（仕様化した場合は `tasks.md` を上から TDD で。直行なら TDD）と verify（仕様化した場合は `openspec validate <change> --strict` と `tasks.md` のチェックボックスが全部 `[x]` であることの確認）までを行い、`工程完了: 実装＋verify` を 1 行目にして return する
- **(3b) archive＋PR＋仕様宣言**: `openspec archive <change>`（仕様化した場合）・PR を Draft のまま用意すること（記録先が Draft PR ならそのまま使い、issue が記録先なら `gh pr create --draft` で作る。Ready には切り替えない）・仕様宣言を PR コメントに書くことを行い、`工程完了: archive＋PR＋仕様宣言` を 1 行目にして return する

境界は archive の手前に置き、verify は (3a) 側に含めなければならない（MUST）。verify の失敗は実装への巻き戻しであり、実装と verify を別の担い手に割ると手渡し直後に巻き戻しが起きるためである。

**(3) をこれより細かく（`tasks.md` の項目単位・「実装／verify／archive／PR／仕様宣言」の 5 段など）分割してはならない（MUST NOT）。** 手渡しが 1 回起きるたびに、後任は指示書と正本の節を読み直し、記録先を取り直し、`git status` / `git diff` でファイルの現状を確認する固定分を払う。この固定分は工程の大きさに依存しないため、区切りを増やすほど 1 区切りあたりの実質作業比が下がる。また区切りが実装の途中に落ちると、後任は Red のまま止まったテストから再出発することになり、前任の設計意図を再発明する危険が最も高い地点で交代する。

`references/roles/worker/implement.md` と `references/roles/worker/finish.md` は (3a) と (3b) それぞれの return に何を書くかを列挙しなければならない（MUST）。(3a) は openspec CLI 経路（`tasks.md` を TDD で実装＋`openspec validate --strict`）・コード直行（TDD）のどちらの入口でも実装後に検査を実行するため、**`worker/implement.md` は「全経路共通の大原則」に、対象リポジトリの PR・push で起動する `.github/workflows/*.yml` / `*.yaml` のジョブの `run:` ステップを読み、検査コマンド（lint・test・ビルド等）と環境セットアップ（依存インストール等）を判別し、拾った検査コマンドを種類ごとに次のとおり扱わなければならない（MUST）という指示を置かなければならない（MUST。経路それぞれに重複して書かない）**: lint・型検査などの静的検査は手元で実行する（ツールがファイルを引数に取れるなら変えたファイルに当て、取れないなら CI と同じ形で実行する）。テストの全体実行（テストランナーをファイルで絞らずに起動するもの）は手元で実行してはならず（MUST NOT）、変えたファイルに関係するテストだけを実行し、全体は CI に任せる。ビルドは手元で実行せず CI に任せる。関係するテストは、この変更で足した・変えたテストのファイル、テストのファイルのうち変えたファイルのパスかファイル名を含むもの（`git grep -l` 等で探す）、テストランナーが変えたファイルから関係するテストを選ぶ機能を持つならその結果、CI の見張りの `fix`（`references/ci-watch.md` 7）で直すときは落ちた run のログ（`gh run view <run> --log-failed`）に出たテストのファイル、の和集合とし、テストランナーにファイルを渡して実行する。例: `auto-merge.yml` や `revert-pr.yml` のように `pull_request` / `push` 以外のイベントで起動する運用系ワークフローは対象に含めない（MUST NOT）。コマンド名をこのリポジトリ固有の値（`scripts/test.sh` など）に固定してはならない（MUST NOT。develop は複数リポジトリで使われ、CI の構成はリポジトリごとに異なるため）。PR・push で起動してテストの全体実行をするジョブが無い（workflow ファイルが存在しない、テストのジョブが無い、または `run:` から検査コマンドを判別できない）ときは、全体のテストを CI に任せられないので、手元で全体を実行しなければならず（MUST）、慣例コマンド（`scripts/test.sh` 等）へのフォールバックを許容する（MAY）。Draft では CI を走らせないリポジトリは、Ready にした時点で CI が走るので CI に任せられる側に数える。手元にツールが無く実行できない検査（apt でプリインストールされた `shellcheck` 等）は「未導入」として実行結果と区別しなければならず、未導入を合格として扱ってはならない（MUST NOT）。**(3a) の return には、収集した検査コマンドの一覧・手元で実行した検査コマンド（関係するテスト・静的検査）と exit code（未導入の検査があれば未導入と明記）・関係するテストを探したコマンド・手元で実行せず CI に任せた検査とその CI のジョブ名、および `openspec validate --strict` の exit code（仕様化した場合。直行した場合は「仕様化しないため verify なし」）と、画面確認の要否の行（「W の (3a) の return は画面確認の要否を 1 行で書く」Requirement）を含めなければならない（MUST）**。(3b) の担い手は pr-review-gate 手順 5 が照合する動作確認の証拠を書く必要があり、手渡しが起きた場合その証拠は前任の return からしか得られない（後任は前任の履歴を読めない）ためである。`openspec validate --strict` の exit code が無いと、(3b) の担い手は verify を通ったことを確認できないまま archive に進むことになる。CI 由来の検査コマンドをすべて return に含め、静的検査を手元で実行することで、G がゲートを合格にしたあとに CI の一部（このリポジトリでは shellcheck）が落ち、W・レビュー・G をもう 1 周回す再発を防ぐ。テストの全体実行を手元で行わないのは、CI が同じ中身を分けて短時間で回し、ゲート合格後の CI の見張り（`references/ci-watch.md`）が落ちた CI を直しに回すためで、手元で全体を回すと実装・仕上げ・指摘の修正のたびに全体の所要（claude-harness では約 40 分）を待つことになる（#1211）。

この要件の守備範囲で入力として扱うのは、対象リポジトリの PR・push で起動する `.github/workflows/*.yml` / `*.yaml` のジョブの `run:` ステップと、変えたファイルの一覧である。拾いたい誤りは、CI が流す静的検査を W が取りこぼすこと（PR #489 の shellcheck）と、変えたファイルを名前で参照するテストの失敗をゲートより後まで持ち越すことである。変えたファイルを別のスクリプト経由で間接的に読むテストを関係するテストとして拾えないことは、この要件では止めない（CI とゲート合格後の CI の見張りが拾う）。次は通ってよく、この要件では止めない: `matrix` / `services` / `env` / `if:` 条件により CI の実行環境と手元の実行結果が食い違うこと、CI ランナー固有の環境に依存する検査、環境セットアップの `run:` ステップを検査コマンドと誤って実行すること。取りこぼしが見つかるたびに塞ぎ切ることは、この要件の完了条件としない。CI が実際に落ちるかどうかは、G が pr-review-gate 手順 4 で対象 HEAD の CI の結果を証拠として見ることに加え、ゲート合格後の CI の見張り（`references/ci-watch.md`）が拾う。auto-merge を配備したリポジトリでは必須チェックが緑になるまでマージされない。

`skills/develop/SKILL.md` は、(3a) の return を受けてから (3b) を指示する SendMessage を送るまでのあいだに、本体が `scripts/subagent-context.sh <W の名前>` を実行してコンテキスト量を測ることを書かなければならない（MUST）。上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」、return の 1 行目の宣言は `references/return-declaration.md` が正本である（再掲の禁止は既存の Requirement「コンテキスト上限の規則の本文は、本体向けを decision-criteria.md に、W と G の宣言を return-declaration.md に置く」が規定しており、ここでは重ねて規定しない）。

本体は次に指示する工程を、**自分が (3a) を指示したか (3b) を指示したかで決めなければならない**（MUST）。工程名の文字列照合で決めてはならない（MUST NOT）。

#### Scenario: worker/implement.md と worker/finish.md が (3a) / (3b) の return 内容を列挙している
- **WHEN** `references/roles/worker/implement.md` と `references/roles/worker/finish.md` を読む
- **THEN** (3a) と (3b) がそれぞれ別の見出し（または別の箇条）として立っており、(3a) に `openspec validate` があり `/opsx:` が無く、(3a) が CI workflow 定義から検査コマンドを収集して種類ごとに扱う義務と、return に収集した検査コマンド一覧・手元で実行した検査コマンドと exit code（未導入の検査は未導入と明記）・関係するテストを探したコマンド・CI に任せた検査とその CI のジョブ名・`openspec validate --strict` の exit code・`画面確認:` の行を含める義務が書かれ、(3b) に `openspec archive` があり `/opsx:` が無く、(3b) の return に PR 番号と仕様宣言のコメント URL を含める義務が書かれている

#### Scenario: CI の定義から検査コマンドを収集する指示が全経路共通の節にある
- **WHEN** `references/roles/worker/implement.md` の「全経路共通の大原則」の節を読む
- **THEN** PR・push で起動する `.github/workflows/*.yml` / `*.yaml` の `run:` から検査コマンドを拾うこと（`auto-merge.yml` 等の運用系ワークフローは対象外）、コマンド名をリポジトリ固有の値に固定しないこと、静的検査は手元で実行しテストの全体実行とビルドは手元で実行せず CI に任せること、関係するテストの選び方（足した・変えたテスト、変えたファイルのパスかファイル名を含むテスト、テストランナーの選ぶ機能）、PR・push で全体のテストを回すジョブが無いときは手元で全体を実行し慣例コマンドへのフォールバックが許容されること、ツール未導入は「未導入」として合格と区別することが書かれており、この指示が (3a)「コード直行する場合」手順 5 だけでなく openspec CLI 経路にも及ぶ 1 箇所にまとまっている

#### Scenario: CI が全体のテストを回すリポジトリでは手元で全体を回さない
- **WHEN** PR・push で起動する workflow にテストの全体実行をするジョブがあるリポジトリで、W が (3a) の検査を行う
- **THEN** W はテストランナーをファイルで絞らずに起動せず、関係するテストのファイルをテストランナーに渡して実行し、return にテストの全体実行を CI に任せたこととその CI のジョブ名を書く

#### Scenario: CI が全体のテストを回さないリポジトリでは手元で全体を回す
- **WHEN** PR・push で起動する workflow が無い、またはテストのジョブが無いリポジトリで、W が (3a) の検査を行う
- **THEN** W は手元でテストの全体を実行し（慣例コマンドへのフォールバックを含む）、その exit code を return に書く

#### Scenario: 守備範囲が明記されている
- **WHEN** `references/roles/worker/implement.md` の全経路共通の大原則の節、CI 検査コマンドの収集を指示する段落を読む
- **THEN** 入力の出どころ（PR・push で起動する workflow の `run:` ステップと変えたファイルの一覧）、拾いたい誤り（CI の静的検査の取りこぼし。PR #489 の shellcheck）、間接的に読むテストを拾えないことは CI と CI の見張りが拾う旨、通ってよい入力（`matrix` / `services` / `env` / `if:` 条件による CI と手元の再現差、ランナー依存の検査、環境セットアップの `run:` ステップの誤実行）、取りこぼしを塞ぎ切ることを完了条件にしない旨（最後の防波堤は合格後の CI の見張り）が書かれている

#### Scenario: 旧世代の W が (3) を通しで返してきても (3b) を再指示しない
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** 本体は次に指示する工程を自分が指示した工程で決めると書かれており、工程名の文字列照合では決めないことが書かれている
- **AND** (3a) の return に PR 番号と仕様宣言のコメント URL が揃っているかどうかで (3b) を飛ばす分岐は書かれていない

#### Scenario: worker/common.md の工程名が 3 つになっている
- **WHEN** `references/roles/worker/common.md` のコンテキスト上限と手渡しの節を読む
- **THEN** W が return する工程の単位が「(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言」の 3 つとして列挙されている

#### Scenario: SKILL.md が (3a) と (3b) のあいだの計測を指示している
- **WHEN** `skills/develop/SKILL.md` の 1 ループの (3) を読む
- **THEN** (3a) の return のあと (3b) を指示する前に `scripts/subagent-context.sh` で測ると書かれており、上限超のときの扱いは `decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」を正本として参照している

#### Scenario: タスク単位のさらなる分割は禁止されている
- **WHEN** `skills/develop/SKILL.md` の (3) を読む
- **THEN** (3) を (3a)/(3b) より細かく切らないことと、その理由（手渡しごとに払う固定分と、実装の途中で切ると後任が Red のまま止まったテストから再出発すること）が書かれている

## ADDED Requirements

### Requirement: W が段ごとに読むファイルの合計に予算を置く

W が段ごとに読むファイルの合計の大きさに予算を置き、超えたら検査が落ちなければならない（MUST）。予算は `tests/develop-worker-stage-budget.txt`（1 行 1 段: `<段> <バイト数>`）に置き、検査は `tests/develop-worker-stage-budget.bats` が行う（MUST）。守備範囲は「W の段ごとに読むファイルの一覧を手順書の名指しと突き合わせる」の段落に従う。検査は段ごとに固定した読むファイルの一覧で合計を測る（MUST。一覧は下のシナリオ「段ごとに測るファイル」のとおり。パスは `plugins/dev-workflow/skills/develop/references/` から、`agents/` と `skills/` で始まるものは `plugins/dev-workflow/` から）。

#### Scenario: 段ごとに測るファイル

- **WHEN** `develop-worker-stage-budget.bats` が各段の合計を測る
- **THEN** spec の段は `agents/worker.md`・`roles/worker/common.md`・`roles/worker/spec.md`・`spec-decision.md`・`return-declaration.md` を足す
- **AND** implement の段は `agents/worker.md`・`roles/worker/common.md`・`roles/worker/implement.md`・`return-declaration.md` を足す
- **AND** finish の段は `agents/worker.md`・`roles/worker/common.md`・`roles/worker/finish.md`・`skills/pr-review-gate/declarations.md`・`return-declaration.md` を足す

#### Scenario: 段の合計が予算を超える

- **WHEN** `worker/common.md` に文を足して、spec の段の合計が予算を超える
- **THEN** `develop-worker-stage-budget.bats` が、段の名前・実測・予算を出して落ちる

### Requirement: W の段ごとの予算はバイト数で上下両方向に判定する

W の段ごとの予算の単位はバイト数（`wc -c`）としなければならない（MUST。字数はロケールで値が変わり、CI と手元でずれるため）。判定は上下両方向で、実測が予算を超えたら落ち、予算が実測の 1.1 倍を超えても落ちなければならない（MUST。減らした変更に予算の引き下げを求め、削った分が次の増加の余地として残らないようにするため）。G の段ごとの予算はこの要件の対象外とする。守備範囲は「W の段ごとに読むファイルの一覧を手順書の名指しと突き合わせる」の段落に従う。

#### Scenario: 予算が実測から離れすぎる

- **WHEN** 予算が実測の 1.1 倍を超えている
- **THEN** 検査が落ち、予算の引き下げを求める

### Requirement: W の段ごとに読むファイルの一覧を手順書の名指しと突き合わせる

一覧が手順書とずれないよう、`worker/common.md` が `return-declaration.md` を、`worker/spec.md` が `spec-decision.md` を、`worker/finish.md` が `skills/pr-review-gate/declarations.md` を名指ししていることを検査しなければならない（MUST）。

**守備範囲**（この要件と「W が段ごとに読むファイルの合計に予算を置く」「W の段ごとの予算はバイト数で上下両方向に判定する」の 3 要件に共通で当てる）: 入力は一覧のファイルの中身と予算ファイル。拾う誤りは、合計が予算を超えて増えることと、手順書が新しいファイルを読ませ始めたのに一覧を直さないことのうち名指しの検査で分かるもの。同じ大きさでの中身の入れ替えと、一覧に無いファイルを読ませる指示の追加は通る（エピック #1682 で主が受け入れた残り。仕様レビューと PR レビューが見る）。穴を塞ぎ切ることを完了条件にしない。

#### Scenario: 手順書が名指しをやめる

- **WHEN** `worker/spec.md` から `spec-decision.md` を名指しする文を消す
- **THEN** `develop-worker-stage-budget.bats` が、名指しが見つからないファイルの名前を出して落ちる

### Requirement: 軽い通し方と CI 修正からの戻し方は light-path.md に置き、CI 修正担当の引き継ぎの手順は handover.md に寄せる

本体が読む（CI 見張りの fix からの戻し方は CI fix から起きた W も読む）軽い通し方（当てる条件・本体の手順・途中で外れたとき・G の failed からの戻し方・CI 見張りの fix からの戻し方・守備範囲）は `skills/develop/references/light-path.md` に置かなければならない（MUST）。W が `段: spec` で読むファイル（`references/spec-decision.md`）に軽い通し方の手順を置いてはならない（MUST NOT）。

CI 見張りの fix からの戻し方のうち、通常判断で W を把握しない本体が引き継ぎを読む手順と、W を起動・再開する前に最新の可を不可として投稿し、工程完了か停止確認のあとで可へ戻す手順は、`references/handover.md`「CI 見張りの修正担当の引き継ぎ」を正本とし、`light-path.md` は分岐と節名への参照だけを書かなければならない（MUST）。`light-path.md` にこの 2 つの手順を言い換えて再掲してはならない（MUST NOT）。

#### Scenario: 引き継ぎの手順は handover.md だけにある

- **WHEN** `light-path.md` の「CI 見張りの fix からの戻し方」を読む
- **THEN** 通常判断で W を把握しない本体の分岐と、起動・再開前の無効化と再許可は、`handover.md` の節名への参照で書かれている

#### Scenario: W の段 spec のファイルに軽い通し方の手順が無い

- **WHEN** `spec-decision.md` を読む
- **THEN** 軽い通し方の本体の手順が無く、`light-path.md` への参照がある
