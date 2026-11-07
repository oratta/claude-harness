## MODIFIED Requirements

### Requirement: 本体はオーケストレータ専任でコードもレビューも書かない
SKILL.md は本体（メインセッション）の役割を「役割 W / R1 / G を model 明示で spawn し、return の要約と記録先（issue または Draft PR）のコメント・ラベルだけを見て次に誰を起こすかを決める」と規定しなければならない（MUST）。禁止事項として、本体が Edit でコードを書かないこと、本体がレビュー（仕様レビュー・PR レビュー）を代行しないことを明記しなければならない（MUST）。「本体が Edit でコードを書かない」の例外は軽い通し方（`dev-workflow-spec-review` の「些細な修正は軽い通し方で新しいテストと W の起動を省く」Requirement）だけであることを、同じ禁止事項の箇所に書かなければならない（MUST）。軽い通し方でも、本体がレビューを代行してはならない（MUST NOT）。並列可能な役割は並列に起こしてよい（MAY）。ただし、1 つの作業ディレクトリ（worktree）で同時に動く同一役割のサブエージェントは常に 1 人でなければならない（MUST）。並列に起こしてよいのは、別々の worktree を持つ役割（エピックの子どうし、独立した change の W どうし）に限る（SHALL）。複数 change に割れた場合の change ごとの W 並列も、change ごとに worktree を分けて起こすものとする（MUST）。

名前付き profile を使わない Claude 経路では、W は名前付きで spawn する（SHALL）。名前付き profile を使う場合は profile role ごとに thread と起動時の要求 tuple / 適用 model を記録する。canonical develop が同じ Claude role を再開する前には毎回、現在有効な残量モードの上限を確認し、既存 thread の適用 model が上限内である場合に限って SendMessage で再開しなければならない（MUST）。適用 model が現在の上限を超える場合は SendMessage で再開せず、既存の工程完了または停止確認の条件を満たしてから、要求 tuple を変更せず、上限内の適用 model で同じ role の fresh thread へ手渡しし、要求値・適用値・変更理由を記録しなければならない（MUST）。profile role が変わる場合、または executor=codex の場合も fresh thread に成果物と必要な要約を渡す（SHALL）。どの経路でも、別コンテキストを要する工程はすべて本体が起こし、W が孫を呼ぶ必要がある工程を設けてはならない（MUST NOT）。

#### Scenario: 禁止事項が明記されている
- **WHEN** SKILL.md の「本体の役割」節を読む
- **THEN** 本体が Edit でコードを書かないこと、レビューを代行しないこと、役割を model 明示で spawn することが書かれている

#### Scenario: Edit の禁止の例外は軽い通し方だけ
- **WHEN** SKILL.md の「本体の役割」節の禁止事項を読む
- **THEN** 「本体は Edit でコードを書かない」の箇所に、例外が軽い通し方だけであることと、その正本が `references/decision-criteria.md` Step B であることが書かれている

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
SKILL.md は 1 ループの最初の工程「入口 0」として記録先の決め方を規定しなければならない（MUST）: issue があれば（番号・URL・自然文マッチ）それを記録先にする。無ければ issue を切らず、W が worktree を用意された直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする。この Draft PR は仕様化判断を記録する**前**に存在していなければならない（MUST。記録先が無い状態で判定を先に進めない）。Draft PR を記録先にする場合、受け入れ条件は PR 本文（位置づけ・動作確認ポイント）に書かなければならず（MUST）、受け入れ条件自体を省いてはならない（MUST NOT）。記録先を PR にした場合、PR 本文に `Closes` / `Fixes` / `Refs #N` の issue 参照を書いてはならない（MUST NOT。書くと pr-review-gate の照合先がその issue に移る。エピックの子は子 issue が記録先なので `Closes #子` を書く）。仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（SHALL）。仕様宣言（`対象 HEAD:` 付き。書式の正本は pr-review-gate スキル手順 3-b）は記録先が issue か Draft PR かにかかわらず常に **PR コメント**に置き、記録先が issue のときに issue コメントへ置いてはならない（MUST NOT。pr-review-gate 手順 5 は PR のコメントで 3 見出しを照合し、`対象 HEAD:` 規約は PR の HEAD に紐づくため）。軽い通し方（`dev-workflow-spec-review` の「些細な修正は軽い通し方で新しいテストと W の起動を省く」Requirement）を当てる場合だけは例外で、記録先が無いときは本体が Draft PR を作る（SHALL）。そのときの順序は、本体が依頼から受け入れ条件を整理する → その受け入れ条件で軽い通し方を当てるかを決める → 当てるなら本体が空 commit・push・`gh pr create --draft` で Draft PR を開き受け入れ条件を本文に書く → 仕様化判断を Draft PR のコメントに記録する、の 1 通りとし（MUST）、当てないなら本体は Draft PR を作らずに W を起こし、W がこれまでどおり作る（SHALL）。SKILL.md は入口 0 にこの例外と順序を、正本（`references/decision-criteria.md` Step B）を指す形で書かなければならない（MUST）。SKILL.md はこの分離（記録先に置くもの＝仕様化判断・仕様レビュー結果、PR コメントに置くもの＝仕様宣言）を入口 0 に明記しなければならない（MUST）。issue を切るのは追跡・キュー・議論が要るとき（エピック／無人キュー／判断を残す議論）に限ることを明記する（SHALL）。

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
- **THEN** 記録先が無い依頼に軽い通し方を当てるときだけ本体が Draft PR を作ることと、受け入れ条件の整理 → 軽い通し方の判断 → Draft PR の作成 → 仕様化判断の記録の順序が、`references/decision-criteria.md` Step B を指して書かれている

### Requirement: 1 ループは W→R1→W→G の順で回る
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 →（軽い通し方の分岐: 本体は (1) の W を起こす前に記録先の本文（記録先が無い依頼では、上の「入口 0 は記録先を決める」の例外の順序どおり、Draft PR を作る前に本体が整理した受け入れ条件）から軽い通し方を当てるかを決め、当てるなら (1)〜(3) の W を起こさず、`references/decision-criteria.md` Step B の軽い通し方の小節の手順どおり、判断の記録・直す・`確かめ方:` のコマンドの実行・commit と push・Draft の PR・仕様宣言までを本体が行って (4) へ進む（SHALL）。迷ったら当てず (1) へ進む）→ (1) W が仕様化判断の記録・分割判定・openspec CLI による change の作成（`openspec new change` と artifact の直書き）まで行い return（仕様化しない判定なら (3) へ直行。文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）なら、W は仕様の差分 1 ファイルだけを書いて return し、本体は記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があることを確かめてから (2) を飛ばして (3) へ進む）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりに BLOCKER が残れば、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の直し方の判定を通し、「決まっている」で PR トークン上限の内側なら主に聞かず次の周を回し、そうでなければ `needs-approval`）→ **(3) W を再開して実装以降を回す。(3) は 2 段に分かれ、(3a) 実装（`tasks.md` を TDD で。直行なら TDD。文言合わせの通し方なら W が (1) の return に書いた作業項目を TDD で）・verify（`openspec validate --strict`）まで行って return、本体が計測し、W の return の `画面確認:` の行が `要る` なら画面確認役 V を起こしてから（下の「画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす」Requirement）、(3b) `openspec archive`・PR を Draft のまま用意（無ければ Draft で作成）・仕様宣言まで行って return する（下の「W の (3) は 2 回の return に分かれる」Requirement）** → 文言合わせの通し方では、本体は G を起こす前に、記録先の最新の仕様化判断のコメントの `直す文:` の行が archive 済みの差分の要件名と一致することを確かめる（SHALL） → (4) G が pr-review-gate の手順 1〜5 を実行し `passed` / `failed` / `保留` / `needs-reviewer` / `needs-decider` / `needs-fix-check` / `review-incomplete` のいずれかを return。PR の Ready 化は G が手順 5 の合格処理で行い（Draft なら Ready にしてから `agent-review:passed` を付ける）、W は行ってはならない（MUST NOT）。

G が `review-incomplete` を return したとき、本体は新しい reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止めなければならない（MUST）。`needs-reviewer` が一周目照合の補足要求である場合、本体は fresh reviewer に固定 HEAD・元の三表・残差・補足済み回数を渡し、同じレビューの不足分だけを補わせなければならず（MUST）、レビューを最初からやり直させてはならない（MUST NOT）。

failed のときは、G の原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出／段 A だけ（昇格なし））で戻し方を決めなければならない（MUST）。モデルを上げるのは**実装品質起因のときだけ**で、そのとき上げるのは**決める役と実行役のどちらか一方だけ**である（MUST）: 実行側が原因（指示どおり実装して結果が違う）なら実行役を `opus` に上げ、判断側が原因（指示を解釈できなかった・指示自体が外れていた）なら決める役を `subagent_type: dev-workflow:decider` で立てて修正方針を作らせ、実行役は据え置く。**W を `fable` で再開してはならない**（MUST NOT。実行役の上限は `opus`）。仕様が曖昧なら仕様修正で返し、レビュアーの誤検出なら反証で返す。どちらもモデルを上げてはならない（MUST NOT。pr-review-gate 手順 2-2 の基線をこの change は変えない）。段 A だけなら W を据え置きで再開する（MUST）。修正後は G を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりの扱いは pr-review-gate の収束ルールと、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement に従う）。保留なら `needs-approval` のまま本体がオーナーに 1 アクションで依頼する。

G が failed を `原因: 軽い通し方の条件外` で return したとき、本体は原因分類によるモデルの昇格を行ってはならず（MUST NOT）、W を `段: spec` で新しく起こし、起動指示に G の確認コメントの URL を書かなければならない（MUST）。W は `通し方:` の行の無い仕様化判断を投稿し直し、テストを書いて同じ PR に積む（SHALL）。そのあとの G は、failed の `次の段: 前提確認と重さ判定` のとおり前提確認と重さ判定の段から起こす（SHALL）。本体は、条件外と判定された記録先で `通し方: 軽い` の仕様化判断を投稿し直してはならない（MUST NOT）。

軽い通し方の PR（記録先の最新の仕様化判断のコメントに `通し方: 軽い` の行がある PR）で、軽い通し方の確認を条件内で通ったあとに G が修正を求める failed を return したとき（照合と振り分け・保留の解除のどちらの段からでも）、W はまだ起きていないので、本体は W を再開してはならず（MUST NOT）、本体が自分で直してもならない（MUST NOT）。本体は W を `段: spec` で新しく起こし、起動指示に failed の Gate Result と G の仕分けコメントの URL を書かなければならない（MUST）。W の model は上の原因分類の規則（実装品質起因のときだけ一方を上げる）で決める（SHALL）。W は `通し方:` の行の無い仕様化判断を投稿し直し（「する」か「しない」かは W が決め直す）、テストを書いて同じ PR に積む（SHALL）。W が起きた PR は以後通常の通し方として扱い、そのあとの G は failed の `次の段:` によらず前提確認と重さ判定の段から起こす（SHALL。判断の記録が変わったため）。

worktree は本体が用意する（SHALL）: 本体が既に対象専用の worktree にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。W は自分で worktree を切らない（MUST NOT。セットアップは worktree プラグインの hooks が担い、`.worktreeinclude` が無いときの `/wt-setup` は本体が行う）。**W / G を `isolation: "remote"` で起こしてはならない**（MUST NOT）。強制停止に当たったサブエージェントの未コミット差分は本体が確認して commit する設計（下の「強制停止で止まった作業ツリーは本体が引き取る」Requirement）だが、`remote` 隔離は本体から見えない環境で動くため、そこで強制停止に当たると作業がそのまま失われる。

`/opsx:*` のスラッシュコマンドは、本体や主が対話で change を作る場面の道具として SKILL.md に書いてよい（MAY）が、W が実行する工程として 1 ループに書いてはならない（MUST NOT。W の種別 `dev-workflow:worker` は `Skill` を持たない）。

#### Scenario: ループの順序が書かれている
- **WHEN** SKILL.md の 1 ループの記述を読む
- **THEN** 0〜4 の工程が W→R1→W→G の順で並び、(1) の W の工程に `openspec new change` があり、仕様化しない判定は (3) へ直行し、R1 と G にそれぞれ既定 2 周と、2 周目以降の周の終わりに直し方の判定を通す続行がある

#### Scenario: 軽い通し方は W を起こさず (4) へ進む
- **WHEN** SKILL.md の 1 ループの (0) と (1) の間を読む
- **THEN** 本体が (1) の W を起こす前に軽い通し方を当てるかを決め、当てるなら (1)〜(3) の W を起こさず本体が直して (4) の G へ進むことと、手順の正本が `references/decision-criteria.md` Step B であることが書かれている

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
- **THEN** SKILL.md は実装品質起因のときだけ原因分類に応じて実行役を `opus` に上げるか決める役を `dev-workflow:decider` で立てるかの一方だけを行い、仕様が曖昧・レビュアーの誤検出・段 A だけ（昇格なし）ではモデルを上げず、段 A だけなら W を据え置きで再開し、W を `fable` にはせず、G を再開して差分再レビューするよう指示している

#### Scenario: decider として起こした R1 の結果は本体が投稿する
- **WHEN** SKILL.md の (2) の記述を読む
- **THEN** R1 が `dev-workflow:decider` の場合は本体が return を同じ書式で記録先に代理投稿すると書かれている

#### Scenario: review-incomplete は reviewer を再起動しない
- **WHEN** G が補足後の残差を `review-incomplete` で return する
- **THEN** 本体は fresh reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止める

### Requirement: G は段ごとに新しく起こし、SendMessage で再開しない

`plugins/dev-workflow/skills/develop/SKILL.md` の (4) は、G を段ごとに新しく spawn することを規定しなければならない（MUST）。1 体の G は次の 4 つの段のうち 1 つだけを担当する（MUST）。

| 段 | 本体が起こす時点 | G が読むファイル（`skills/pr-review-gate/` から） | 返しうる Status |
|---|---|---|---|
| 前提確認と重さ判定 | ゲートの開始、W の修正後の再レビュー（failed の `次の段: 前提確認と重さ判定`）、保留の解除が `次の段: 前提確認と重さ判定` を返したとき、CI の見張りで `ready` になったあとの取り直し | `stages/prepare.md`（W の修正後の再レビューのときは加えて `stages/triage.md` の収束ルールの節と「W の修正後の再レビュー」の入力） | `needs-reviewer` / failed（軽い通し方の条件外） / 保留 / `重複で降りた` |
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定・直し方の判定を受け取ったとき、戻した指摘が順 3 だけの修正のあと（failed の `次の段: 照合と振り分け`） | `stages/triage.md` | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `needs-fix-check` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき、保留の解除が `次の段: 合格処理` を返したとき、引き継ぎの判定を受け取ったとき（合格処理の G が `needs-carryover-judge` を返したあと） | `declarations.md` と `stages/pass.md`（前の HEAD の許容があるとき・保留を返すとき・`needs-carryover-judge` を返すときは加えて `stages/hold.md`） | passed / 保留 / `needs-carryover-judge` |
| 保留の解除 | 主の回答が届いたとき | `stages/hold.md`（切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage.md` の置き場所の段落・候補探し・段 C の節） | 復帰手順の表どおりに `次の段へ`（`次の段:` は合格処理か前提確認と重さ判定） / failed / needs-decider / 保留 |

本体は G の起動指示に `段: <段の名前>` の 1 行を書かなければならない（MUST）。`skills/develop/SKILL.md` の (4)（`(4) G を` で始まる行から、その行を含むコードブロックの閉じ ``` の行まで）と `skills/develop/references/roles/gate-runner.md` は、`SendMessage` の語と `G を再開` の文字列を持ってはならない（MUST NOT）。SKILL.md の (4) の「G の起動・再開・手渡しの指示」「G を再開か手渡しで起こして」も段ごとの起動の言い方に書き換える（MUST）。G への SendMessage は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の停止の指示だけに残し、その規則は decision-criteria.md にだけ書く（MUST）。`gate-runner.md` の「時点ごとに読むファイル」の表は、上の段の表に揃えなければならない（MUST）。

保留の解除の G は、復帰手順の表が別の段の作業に進むと示したとき、その作業を自分で行ってはならず（MUST NOT）、Status `次の段へ` と `次の段:` で返さなければならない（MUST）。許容したとき・切り出して残りが無いときは `次の段: 合格処理`、許容せず代替案で手順 2 からやり直すときは `agent-review:failed` に付け替えて failed（`次の段: 前提確認と重さ判定`）で返す（MUST）。`次の段へ` の `次の段: 前提確認と重さ判定` は、W の修正が要らないときだけに使う。

W の修正後の再レビューで起こされた前提確認と重さ判定の G は、前の周の指摘を仕分けコメントから読み、`stages/triage.md` の収束ルールどおり差分限定か全体レビューかを自分で判定し、全体レビューにしたときは 2 つの行数を PR コメントに記録しなければならない（MUST）。

保留の解除のあとで起こされた合格処理の G（前の Gate Result が `段: 保留の解除`）は、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば、宣言を出し直してはならず（MUST NOT）、手順 5 の真正性確認から入らなければならない（MUST）。そのコメントが無ければ（切り出しの確認を解除した場合）、`declarations.md` の手順 3 から入らなければならない（MUST）。照合と振り分けのあとの合格処理は、前の Gate Result の `段: 照合と振り分け` で見分ける（MUST。`次の段: 合格処理` は保留の解除の Gate Result にもあるため入口の判別に使わない）。許容済みの PR で HEAD が動いていたときの許容の引き継ぎ（手順 3-c）は、合格処理の G が宣言の前に `stages/hold.md` を読んで試す（MUST）。引き継ぎの判定を受けて起こされた合格処理の G（前の Gate Result が `段: 合格処理`・Status `needs-carryover-judge`）は、`declarations.md` の手順 3 から入り直し、3-c で PR の判定の記録を読まなければならない（MUST）。

この要件は、develop の本体がレビュアーを起こす adapter 経路（起動指示が `レビュー経路: adapter`）に掛かる。従来経路の G はレビューを自分の起動の中で起こすので、手順 1〜5 と保留までを 1 体で続けてよい（MAY）。そのときの Gate Result は `段: 一括（従来経路）`、`次の段: なし` と書く（MUST）。

#### Scenario: SendMessage による G の再開の記述が無い

- **WHEN** `plugins/dev-workflow/tests/` の develop の役割の bats が `skills/develop/SKILL.md` の (4) と `gate-runner.md` を検査する
- **THEN** 段ごとに新しい G を起こす記述と `段:` の行の指示があり、SKILL.md の (4) の範囲と gate-runner.md の全体に `SendMessage` と `G を再開` の文字列が無い

#### Scenario: 従来経路の G

- **WHEN** develop の本体以外の呼び出し元が `レビュー経路: 従来` で G を起こす
- **THEN** G は手順 1〜5 と保留までを 1 体で続けてよく、Gate Result に `段: 一括（従来経路）` と `次の段: なし` を書く

#### Scenario: 代替案への作り直し

- **WHEN** 主が許容せず、代替案で手順 2 からやり直すと答える
- **THEN** 保留の解除の G は `agent-review:failed` に付け替えて failed（`次の段: 前提確認と重さ判定`）で返し、次の前提確認と重さ判定の G は W の修正後の再レビューとして `周回:` を 1 増やす

#### Scenario: 保留の解除のあとの合格処理

- **WHEN** 保留の解除の G が主の許容を受けて `次の段へ`・`次の段: 合格処理` で返し、本体が合格処理の G を起こす
- **THEN** 合格処理の G は前の Gate Result の `段: 保留の解除` を見て、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば宣言を出し直さず手順 5 の真正性確認から入る

#### Scenario: 切り出しの確認を解除したあとの合格処理

- **WHEN** 照合と振り分けの G が切り出すかを主に聞く保留を返し、主が「切り出す」と答えて保留の解除の G が `次の段: 合格処理` で返す
- **THEN** 今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントが無いので、合格処理の G は `declarations.md` の手順 3 から入る

#### Scenario: 保留の解除の G が切り出しの確認の回答で追加に読むもの

- **WHEN** `gate-runner.md` の「時点ごとに読むファイル」の表の保留の解除の行を読む
- **THEN** 切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage.md` の置き場所の段落・候補探し・段 C の節を読むことが書かれている

#### Scenario: CI の見張りのあとの取り直し

- **WHEN** CI の見張りが `ready` になり、本体がゲートを取り直す
- **THEN** 本体は前提確認と重さ判定の G を新しく起こし、前の G を再開しない

#### Scenario: 段の表に needs-fix-check がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 照合と振り分けの行の起こす時点に「直し方の判定を受け取ったとき」があり、返しうる Status に `needs-fix-check` がある

#### Scenario: 段の表に needs-carryover-judge がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 合格処理の行の起こす時点に「引き継ぎの判定を受け取ったとき」があり、返しうる Status に `needs-carryover-judge` がある

#### Scenario: 段の表の前提確認と重さ判定に failed がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 前提確認と重さ判定の行の返しうる Status に failed があり、それが軽い通し方の条件外のときに返るものだと分かる

#### Scenario: 引き継ぎの判定のあとの合格処理

- **WHEN** 合格処理の G が `needs-carryover-judge` で返し、本体が判定の記録を投稿して合格処理の G を新しく起こす
- **THEN** 新しい合格処理の G は前の Gate Result の `段: 合格処理`・Status `needs-carryover-judge` を見て `declarations.md` の手順 3 から入り直し、3-c で判定の記録を読む
