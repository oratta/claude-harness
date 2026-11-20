# Spec Delta

## MODIFIED Requirements

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
- **WHEN** SKILL.md の 1 ループと、そこから必読にした `plugins/dev-workflow/references/codex-develop.md` の起動・再開手順を読む
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

G の結果を受けた本体の状態別の詳しい手順は `skills/develop/references/gate-result.md` に置かなければならない（MUST）。SKILL.md の (4) は Status → 読むファイルの表でその手順へ接続し、結果を処理する前の必読を指示する（MUST）。工程の順と、G の Status・`次の段:` だけで次の段を決める原則は SKILL.md に残す（MUST）。

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
- **THEN** SKILL.md から必読にした `skills/develop/references/gate-result.md` は実装品質起因のときだけ原因分類に応じて、実行側なら `--failure executor` の `request` が返した model で実行役を上げるか、判断側なら `--failure first`（ゲートの 1 回目の failed）または `judgment`（そのゲートの 2 回目以降の failed。1 回目の原因が実行側だったときも含む）の `request` が返した model で決める役を `dev-workflow:decider` で立てるかの一方だけを行い、仕様が曖昧・レビュアーの誤検出・段 A だけ（昇格なし）ではモデルを上げず、段 A だけなら W を据え置きで再開し、実行役を最上位の格に上げず、G を再開して差分再レビューするよう指示している

#### Scenario: decider として起こした R1 の結果は本体が投稿する
- **WHEN** SKILL.md の (2) の記述を読む
- **THEN** R1 が `dev-workflow:decider` の場合は本体が return を同じ書式で記録先に代理投稿すると書かれている

#### Scenario: review-incomplete は reviewer を再起動しない
- **WHEN** G が補足後の残差を `review-incomplete` で return する
- **THEN** 本体は fresh reviewer を起動せず、`agent-review:pending` のまま残差を報告して工程を止める


### Requirement: 本体は role profile から executor を選ぶ
develop 本体は、Claude 既定の経路を含めて、新しい role を起動する直前に事前分類・設計判断・失敗の原因・自動実行かどうかを共通 resolver（`codex-develop.py request`）に渡し、canonical role の executor/account/model/effort を取得して、executor=claude なら Agent、executor=codex なら foreground request/run 経路を選ばなければならない（MUST）。resolver が `role: decider` を返したとき（事前分類に当たる R1 または G が要求したレビュアー）は、`subagent_type: dev-workflow:decider` として起動しなければならない（MUST）。本体は resolver の `requested_model`・`model`・`tier_reason` を要求 model・適用 model・変更理由として記録し、あわせて `tier`・`executed_tier`・`tier_cap` も dispatch 記録に残し、Agent には `model` を渡さなければならない（MUST）。`tier_reason` は `tier` の変化だけを表すので、`tier_cap` で値が変わった場合は `executed_tier` と `tier_cap` の記録で見分ける。新しい起動の `model` を文章の規則で計算し直してはならない（MUST NOT）。同じ Claude thread の再開前の上限確認は、同じ phase と、今回の再開に当たる格の入力（失敗ループの段なら、その段の `--failure` の値を含む）で `request` を呼び直し、返った `tier` と `model` を thread の格（起動時に記録した `tier`）と applied model（起動時に記録した `model`）と比べて行わなければならない（MUST）。呼び直しの結果は `tier` と `model` だけを読み、executor・account・構成の選び直しには使ってはならない（MUST NOT）。`tier` は構成によらないので、役の途中切り替えにはならない。executor の選択は transport と execution setting だけを変え、仕様化判断、工程順、独立レビュー、差戻し上限、verify、archive、PR gate の条件を変えてはならない（MUST NOT）。

役割解決の入力・選択規則・結果の監査記録・provider 分岐・同じ Claude role の再開と fresh thread の境界の説明は、`plugins/dev-workflow/references/codex-develop.md` の一つの正本へ集約しなければならない（MUST）。SKILL.md と `commands/develop.md` は、操作前にその正本を読む指示だけを置き、解決手順を再掲してはならない（MUST NOT）。同 reference 内でも同じ手順を繰り返さず、一つの本文へ参照でつなぐ（MUST）。

#### Scenario: 1 つの profile で executor が工程間に変わる
- **WHEN** spec-write=codex、spec-review=claude の profile で仕様化工程を進める
- **THEN** W は Codex foreground 経路、R1 は Claude Agent 経路で別 thread として動き、R1 の APPROVE が記録されるまで実装へ進まない

#### Scenario: 事前分類に当たる R1 またはレビュアーを起動する
- **WHEN** R1 または G が要求したレビュアーの対象がマージ条件・層間契約・課金/法務に触れる
- **THEN** 本体が `--pre-class` を渡した `request` が `role: decider` と構成の `decider` entry の executor/account を返し、本体は `subagent_type: dev-workflow:decider` として起動する

#### Scenario: executor 切替でも canonical role を維持する
- **WHEN** 同じ role の executor を profile で Claude から Codex または Codex から Claude へ変える
- **THEN** role の指示書、read-only/write 権限、return 契約、記録先、次工程の判定は変わらず、provider 固有の起動操作だけが変わる

#### Scenario: 通常モードでは要求 model をそのまま適用する
- **WHEN** decider の resolver 結果が `requested_model`=`fable` で、Fable と共有枠の残量モードがその model を制限しない
- **THEN** `model`=`fable`、`tier_reason`=`unchanged` で、本体はその `model` で Agent を起動する

#### Scenario: exhausted は Fable 要求を Opus に制限する
- **WHEN** decider を `FABLE_BUDGET_MODE=exhausted`、`SHARED_BUDGET_MODE=ok` で解決する
- **THEN** resolver は `requested_model`=`fable`、`model`=`opus`、`tier_reason`=`FABLE_BUDGET_MODE=exhausted` を返し、本体はその `model` で Agent を起動する

#### Scenario: depleted は中位を上限にし、最安の役はそのままにする
- **WHEN** Claude の decider を `SHARED_BUDGET_MODE=depleted` で解決する
- **THEN** resolver は `requested_model`=`fable`、`model`=`sonnet`、`tier_reason`=`SHARED_BUDGET_MODE=depleted` を返し、本体はその `model` で Agent を起動する

#### Scenario: 構成の上限で値が変わった起動を記録する
- **WHEN** `codex-economy` の phase `implement` の委譲を記録する
- **THEN** `tier_reason` は `unchanged` のままで、記録の `tier`=中位、`tier_cap`=最安、`executed_tier`=最安 から上限で下がったことが分かる


### Requirement: G の needs-decider を受けた本体の動き

`skills/develop/references/gate-result.md` は、SKILL.md の (4) の Status 表から必読にされ、G の return の分岐に `needs-decider`（pr-review-gate の仕分け表の順 6。同じ型の再発）の行を持たなければならない（MUST）。その行は次を規定する（MUST）: 本体は `subagent_type: dev-workflow:decider` を、残量モードの規定どおりのモデルで spawn する。入力は、`agents/decider.md` の入力契約の 4 項目に揃え、記録先（issue または Draft PR）の本文、判断に必要な関連コメント（`仕様化判断:` の記録・G の仕分けの PR コメント・順 3 の一覧表の PR コメントがあればそれ）、G の return に載った同じ型の指摘と前の周の指摘の原文（PR コメントの本文を貼る）、対象ファイルのパス、G の仕分け欄、W の直近の return とする。依頼は、マージ可否を問うときと同じ `agents/decider.md` の既存の「可否と根拠」の出力契約で出し（決める役が 3 点の契約で返す取り違えを防ぐため、行にその旨を書く）、問いを「この PR の中で、同じ型を全部列挙してから直すべきか（可）、切り出すべきか（否）」の 1 つにする。依頼文では、返答の 1 行目を `裁定: 可`・`裁定: 否`・`不足: <足りないもの>` のどれかちょうどにするよう指定し、本体はその 1 行目で分岐する（MUST。本文の読み取りで分岐しない）。本体は返ってきた可否を方式（`裁定: 可`＝全部列挙してから直す、`裁定: 否`＝切り出す）に読み替え、根拠とともに照合と振り分けの G を新しく起こして渡す。本体は裁定を記録先に投稿しない（記録は G が PR コメントに行う）。これは「`dev-workflow:decider` で起こした役割の return は本体が代理投稿する」一般則の例外であり、SKILL.md は一般則の記述にもこの例外を一言書かなければならない（MUST）。`agents/decider.md` の入力契約と出力契約は変えない（MUST NOT）。

決める役の返答の 1 行目が `不足:` なら、本体はそれを裁定として扱ってはならず、G に渡してはならない（MUST NOT）。本体は足りないものを補って、同じ問いで 1 回だけ依頼し直す（MUST）。依頼し直しても不足が返ったら、本体は「裁定なし（入力不足）」と足りなかったものを、照合と振り分けの G を新しく起こして渡す（MUST。G はそれを「切り出す」として順 5 の経路で主に聞く）。

#### Scenario: (4) に needs-decider の行がある

- **WHEN** develop の SKILL.md (4) の Status 表から `skills/develop/references/gate-result.md` の `needs-decider` の手順を読む
- **THEN** `needs-decider` の行があり、`dev-workflow:decider` をマージ可否と同じ「可否と根拠」の契約で起こすこと、入力（記録先の本文・関連コメント・同じ型の指摘と前の周の指摘・対象ファイル・仕分け欄・W の return）、返答の 1 行目を `裁定: 可`／`裁定: 否`／`不足:` のどれかに指定しその 1 行目で分岐すること、可否を方式に読み替えること、裁定を照合と振り分けの G を新しく起こして渡すこと、本体は裁定を代理投稿しないことが書かれており、代理投稿の一般則の記述にこの例外が書かれている

#### Scenario: 決める役が不足を返す

- **WHEN** 順 6 の依頼に対して、決める役の返答の 1 行目が `不足: <足りないもの>` である
- **THEN** 本体はそれを G に渡さず、足りないものを補って 1 回だけ依頼し直す。2 回目も不足なら「裁定なし（入力不足）」として照合と振り分けの G を新しく起こして渡す

#### Scenario: decider の契約を変えない

- **WHEN** この change の前後で `plugins/dev-workflow/agents/decider.md` を比べる
- **THEN** 差分が無い

### Requirement: adapter 経路の本体は Claude のレビュアーを区画ごとに起こす

develop の SKILL.md の (4) の Status 表から必読にした `skills/develop/references/gate-result.md` の `needs-reviewer` の手順は、phase `review` で選ばれた executor が claude で、G の payload の `区画:` に区画の一覧があるときは、区画ごとにレビュアーを 1 体ずつ並列に起こすことを書かなければならない（MUST）。各レビュアーの Agent の `description` は `Reviewer: 区画 <k>/<n> for PR #<N> (#<issue>)` の形にしなければならない（MUST。`subagent-context-audit.sh --by-role` が先頭トークン `Reviewer` でレビュアーに数えるため）。executor が codex のときは区画を使わず、差分全体を 1 つの request に渡さなければならない（MUST）。

本体は全区画の要約が揃ってから、照合と振り分けの G を 1 体だけ新しく起こし、全区画の要約を `区画 <k>/<n>` の見出しを付けてまとめて渡さなければならない（MUST）。区画ごとに G を起こしてはならない（MUST NOT）。

#### Scenario: claude の executor で区画がある

- **WHEN** G の `needs-reviewer` の payload に区画が 3 つあり、phase `review` の executor が claude である
- **THEN** 本体はレビュアーを 3 体並列に起こし、`description` は `Reviewer: 区画 1/3 for PR #N (#issue)` の形で、3 体の要約が揃ってから照合と振り分けの G を 1 体起こして全区画の要約を渡す

#### Scenario: codex の executor では区画を使わない

- **WHEN** G の `needs-reviewer` の payload に区画があり、phase `review` の executor が codex である
- **THEN** 本体は区画に分けず、差分全体を 1 つの request で Codex のレビュアーに渡す

### Requirement: 補足は一周目の区画の構成のまま、選び直した executor で残差だけを補う

一周目照合の補足要求（`needs-reviewer` の補足 payload）でも、本体は既存要件「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」のとおり phase `review` の投げ先を選び直す。SKILL.md の (4) から必読にした `skills/develop/references/gate-result.md` は、選び直しで executor が一周目と変わっても変わらなくても、補足を一周目の区画の構成（G が `レビュー三表:` のコメントと補足 payload に書いた `一周目の区画:`）のまま行うことを書かなければならない（MUST）。補足のときに区画を計算し直してはならず、差分全体のレビューを始めてはならない（MUST NOT）。一周目の三表の変更点 ID と finding ID はそのまま残し、補った項目にも一周目と同じ ID の付け方（区画があれば補足先の区画の `P<k>-`、区画が無ければ接頭辞なし）を使わなければならない（MUST）。既存の「元の三表を置き換えず、残差に挙げた不足した項目だけを補う」と「補足は PR 全体で 1 回まで（補足済み回数は PR で 1 つ）」は変えない（MUST）。

executor ごとの起こし方は次のとおりとしなければならない（MUST）:

- 一周目に区画があり、補足の executor が claude: 残差のある区画だけに補足のレビュアーを 1 体ずつ起こし、その区画の元の三表と残差を渡す。`description` は `Reviewer: 補足 区画 <k>/<n> for PR #<N> (#<issue>)` とする
- 一周目に区画があり、補足の executor が codex: 1 つの request に、残差のある区画ごとに区画の番号・その区画のファイル一覧・元の三表・残差を分けて載せ、区画ごとに `P<k>-` の ID で補わせる。差分全体のレビューは頼まない
- 一周目に区画が無く（一周目が Codex、または `区画: なし`）、補足の executor が claude: 補足のレビュアーを 1 体だけ起こし、1 組の元の三表と残差を渡して接頭辞の無い ID で補わせる。payload の `区画:` に区画の一覧があっても区画ごとに起こさない
- 一周目に区画が無く、補足の executor が codex: 今までどおり 1 つの request で補わせる

#### Scenario: 区画に分けた Claude の一周目のあと、補足で Codex が選ばれる

- **WHEN** 一周目は claude で 3 区画に分けてレビューし、G が区画 2 と区画 3 に残差を出して `一周目の区画: 3` の補足 payload を返し、補足の選び直しで executor が codex になる
- **THEN** 本体は 1 つの request に区画 2 と区画 3 の番号・ファイル一覧・元の三表・残差を分けて載せ、`P2-`・`P3-` の ID で不足分だけを補わせ、差分全体のレビューも区画 1 の補足も頼まない。補足済み回数は PR で 1 のまま

#### Scenario: 区画に分けなかった Codex の一周目のあと、補足で Claude が選ばれる

- **WHEN** 一周目は codex で差分全体を 1 体で見て（payload の `区画:` には 3 区画があった）、G が `一周目の区画: なし` の補足 payload を返し、補足の選び直しで executor が claude になる
- **THEN** 本体は補足のレビュアーを 1 体だけ起こし、1 組の元の三表と残差を渡して接頭辞の無い ID で不足分だけを補わせ、区画ごとに起こさず差分全体のレビューも始めない

### Requirement: G の needs-fix-check を受けた本体の動き

`skills/develop/references/gate-result.md` は、SKILL.md の (4) の Status 表から必読にされ、G の Status `needs-fix-check` を受けた本体の動きを書かなければならない（MUST）: 本体は「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の手順で決める役を起こして判定を受け取り、判定の記録を記録先に投稿し、判定（「決まっている」または「選び直しが要る」）と判定の記録の URL を渡して照合と振り分けの G を新しく起こす（MUST）。本体は判定を受けて自分で `agent-review:failed` を付けたり W を再開したりしてはならない（MUST NOT。ラベルの付け替えと W に戻す指摘の一覧は G が決める）。

#### Scenario: needs-fix-check で返った
- **WHEN** G が Status `needs-fix-check`・`次の段: 照合と振り分け` で return する
- **THEN** 本体は PR トークン上限を測ってから決める役を起こし、判定の記録を記録先に投稿し、判定とその URL を渡して照合と振り分けの G を新しく起こす

### Requirement: G の needs-carryover-judge を受けた本体の動き

`skills/develop/references/gate-result.md` は、SKILL.md の (4) の Status 表から必読にされ、G の Status `needs-carryover-judge` を受けた本体の動きを書かなければならない（MUST）: 本体は PR トークン上限を測ってから、pr-review-gate の `stages/carryover-judge.md` 手順 3-c の依頼の書き方で `subagent_type: dev-workflow:decider`・`model: opus` の判定役を起こし、判定の記録を PR に代理投稿し、判定と記録の URL を渡して合格処理の G を新しく起こさなければならない（MUST）。`SHARED_BUDGET_MODE=depleted` のときは判定役を起こさず、3-c の書式の `引き継ぎ判定: 判断できない` の記録を投稿して同じく合格処理の G を起こす（MUST）。本体は判定を受けて自分で宣言を投稿したり、ラベルを付けたり、主に聞いたりしてはならない（MUST NOT。引き継ぐか主に聞くかは合格処理の G が決める）。ただし、判定を受けて起こした合格処理の G が同じ前 HEAD・新しい HEAD・根拠ファイルの組で再び `needs-carryover-judge` を返したときは、判定役を起こし直してはならず（MUST NOT）、投稿した記録の URL を添えて主に聞かなければならない（MUST）。

#### Scenario: needs-carryover-judge で返った

- **WHEN** G が Status `needs-carryover-judge`・`次の段: 合格処理` で return する
- **THEN** 本体は PR トークン上限を測ってから `dev-workflow:decider`・`model: opus` の判定役を起こし、判定の記録を PR に投稿し、判定とその URL を渡して合格処理の G を新しく起こす

#### Scenario: 共有枠が depleted のとき

- **WHEN** G が `needs-carryover-judge` で返し、`SHARED_BUDGET_MODE=depleted` である
- **THEN** 本体は判定役を起こさず `引き継ぎ判定: 判断できない` の記録を投稿して合格処理の G を新しく起こし、G が手順 6 で主に聞く

#### Scenario: 判定のあとの G が同じ組で再び返した

- **WHEN** 本体が判定の記録を投稿して起こした合格処理の G が、同じ前 HEAD・新しい HEAD・根拠ファイルの組で再び `needs-carryover-judge` を返す
- **THEN** 本体は判定役を起こし直さず、投稿した記録の URL を添えて主に聞く

### Requirement: G の needs-no-point-check を受けた本体の動き

`skills/develop/references/gate-result.md` は、SKILL.md の (4) の Status 表から必読にされ、G の Status `needs-no-point-check` を受けた本体の動きを書かなければならない（MUST）: 本体は PR トークン上限を測ってから、`subagent_type: dev-workflow:decider`・`model: opus` の決める役を起こし、宣言の本文と PR の差分だけを渡して論点なしかを判定させ、dev-workflow-pr-review-gate の要件「論点なしの確認の記録を PR に残す」の形の記録を PR に投稿し、記録の URL を渡して合格処理の G を新しく起こさなければならない（MUST）。`SHARED_BUDGET_MODE=depleted` のときは決める役を起こさず、`論点なしの確認: 判断できない` の記録を投稿して同じく合格処理の G を起こす（MUST）。

#### Scenario: Status の一覧に needs-no-point-check がある

- **WHEN** SKILL.md の G の Status → 読むファイルの表と `references/roles/gate-runner.md` の段と Status の表を読む
- **THEN** どちらにも `needs-no-point-check` がある

#### Scenario: needs-no-point-check で返った

- **WHEN** G が Status `needs-no-point-check`・`次の段: 合格処理` で return する
- **THEN** 本体は PR トークン上限を測ってから `dev-workflow:decider`・`model: opus` の決める役を起こし、記録を PR に投稿し、記録の URL を渡して合格処理の G を新しく起こす

#### Scenario: 共有枠が depleted のとき

- **WHEN** G が `needs-no-point-check` で返し、`SHARED_BUDGET_MODE=depleted` である
- **THEN** 本体は決める役を起こさず `論点なしの確認: 判断できない` の記録を投稿して合格処理の G を新しく起こし、G が手順 6 で主に聞く

#### Scenario: 確認のあとの G が同じ宣言で再び返した

- **WHEN** 本体が記録を投稿して起こした合格処理の G が、同じ宣言の URL と同じ HEAD で再び `needs-no-point-check` を返す
- **THEN** 本体は決める役を起こし直さず、投稿した記録の URL を添えて主に聞く

### Requirement: 保留で止まるときは記録先に引き継ぎのコメントを 1 種類の書式で残す

本体は、`needs-approval` を付けて主の返事を待つすべての場面で、止まる前に記録先へ引き継ぎのコメントを投稿しなければならない（MUST）。場面は pr-review-gate の保留（リスク許容・動作確認・切り出しの確認）、`skills/develop/references/pr-token-budget.md`の exit 2、レビューの 2 周キャップ超え、仕様レビューの条件の問い（`条件の問い:` を主に聞くとき）の 4 つで、書式は場面によらず 1 種類とする（MUST）。場面ごとに別の書式を作ってはならない（MUST NOT）。

**投稿の順序**: 本体は、どの場面でも次の順で投稿する（MUST）。①主への依頼のコメントを投稿し、その URL を得る。依頼コメントの置き場は、対象の PR があれば PR、無ければ記録先とする（`stages/hold.md` 手順 6 は依頼を PR に投稿するので、記録先が issue でも PR のコメントの URL でよい。引き継ぎのコメント自体は常に記録先に投稿する）。G の保留では G が投稿した依頼コメントの URL を使い、G が投稿していなければ本体が依頼文を PR（無ければ記録先）のコメントとして投稿する。exit 2 と 2 周キャップ超えと条件の問いでは本体が問いを PR（無ければ記録先）のコメントに書く。②その URL を「主への依頼」に書いて引き継ぎのコメントを投稿する。③主に案内する。①より前に引き継ぎを投稿してはならない（MUST NOT。URL が無いため）。

コメントの 1 行目は正規表現 `^引き継ぎ: 主の返事待ち$` に完全一致させ（MUST。太字・全角コロン・末尾句点を付けない）、2 行目以降に次の項目を `項目名: 値` の形で 1 行ずつ書く（MUST）。

| 項目 | 中身 |
|---|---|
| 待ち理由 | `リスク許容` / `動作確認` / `切り出しの確認` / `PR トークン上限` / `2 周キャップ超え` / `条件の問い` のどれか |
| 主への依頼 | ①で得た依頼コメントの URL（PR のコメントでもよい） |
| 対象 | PR 番号（まだ無ければ `なし`）・HEAD の 40 桁 SHA・ブランチ・worktree のパス |
| ラベルの付け先 | `needs-approval` を付けた先。PR があれば `PR #N`、PR がまだ無ければ記録先（`issue #N`）。コメントの記録先とは別に書く |
| 実行モード | interactive / channel / unmanned |
| 実行先 | 実行先オプションと account-home の対応（明示したときだけ。無ければ `自動選択`）と、開始済みの phase ごとの選択結果（構成・executor・account・model）が書かれたコメントの URL。最初の phase の選択結果は develop 開始コメント（開始時の記録の規約は `plugins/dev-workflow/references/codex-develop.md`「起動と role 解決」）、以降の phase は dispatch 記録のコメントにある。両方書く（どちらも無ければ `なし`） |
| 次に起こす役割 | 返事のあとに最初に起こす役割と、渡す入力の在り処 |
| 周回 | 仕様レビューと G の周回の数・W の修正の周回の数 |
| 前任 W | 直近の return の 1 行目と要約または URL（W を起こしていなければ `なし`）と、手渡し可否（次の段落） |
| PR トークン上限 | 最新の値と、止まった時点の合計 |
| 回し方 | エピックの子のときだけ。それ以外は `なし` |

W の名前は書かない（新しいセッションでは SendMessage できないため）。同じ記録先で再び止まるときは新しいコメントを投稿し、読む側は最新の 1 件を正とする（MUST）。

**前任 W の手渡し可否**: 前任 W を後任へ手渡してよいのは、`references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」を満たすときだけである（MUST）。新しいセッションの本体は前任に停止を指示できないので、本体は引き継ぎを書く前に、前任 W の直近の return の 1 行目が `工程完了:` であることを確かめるか、前任が `工程中断:` なら前任に停止を指示して停止確認を受け取り、未コミット差分があれば本体が commit する（MUST。commit してから引き継ぎを書く）。いずれかを満たしたら「前任 W」の項目に `手渡し: 可（工程完了 | 停止確認済み）` と確認結果（編集ファイル・commit の SHA）を書く。どちらも満たせないとき（exit 2 で SendMessage を送れない・前任が停止確認を返さない）は `手渡し: 不可（<理由>）` と書く。W を起こしていなければ `手渡し: 不要` と書く。

interactive の本体は主への依頼に「返事は新しいセッションで `/develop <記録先>` と一緒に渡す。1 時間以内に返事ができるなら、このセッションで続けてもよい」という案内を含めなければならない（MUST）。channel の本体はこの案内を出さず、要件「channel モードの保留はチャンネルの返事で再開する」の案内を出す（MUST）。引き継ぎのコメントは、返事がいつ来るかを本体が知らないので、どのモードでも必ず残し、どちらで続けるかは主が決める（MUST）。

#### Scenario: pr-review-gate の保留で止まる

- **WHEN** interactive の G が保留で返り、本体が `needs-approval` のまま主に 1 アクションで依頼する
- **THEN** 本体は依頼コメントの投稿のあとに記録先へ `引き継ぎ: 主の返事待ち` のコメントを投稿し、待ち理由に `リスク許容`・`動作確認`・`切り出しの確認` のどれかを、ラベルの付け先に `PR #N` を書き、主への案内に `/develop <記録先>` を含める

#### Scenario: PR トークン上限の exit 2 で止まる

- **WHEN** 計測が exit 2 を返し、本体が spawn せずに主へ「続けるか、範囲外として閉じるか」を問う
- **THEN** 本体は問いを PR（無ければ記録先）のコメントに書いたあとで同じ書式の引き継ぎのコメントを残し、待ち理由は `PR トークン上限` とする。前任 W が `工程中断:` で停止指示を送れなければ `手渡し: 不可（PR トークン上限のため SendMessage できない）` と書く

#### Scenario: 2 周キャップ超え

- **WHEN** レビューの 2 周キャップを超えて本体が `needs-approval` を付けて主に依頼する
- **THEN** 本体は同じ書式の引き継ぎのコメントを残し、待ち理由は `2 周キャップ超え` とする

#### Scenario: 仕様レビューの条件の問いで止まる

- **WHEN** 本体が R1 の `条件の問い:` を主に聞くために `needs-approval` を付ける
- **THEN** 本体は条件の問いを PR（無ければ記録先）のコメントに書いたあとで同じ書式の引き継ぎのコメントを残し、待ち理由は `条件の問い`、主への依頼はそのコメントの URL、次に起こす役割は R1（当て直し）で、入力は残った BLOCKER を載せた結果コメントの URL とする

#### Scenario: 前任 W が工程中断のまま保留に入る

- **WHEN** 前任 W の直近の return が `工程中断:` で、本体が保留に入る
- **THEN** 本体は前任へ停止を指示して停止確認を受け取り、未コミット差分を commit してから引き継ぎを書き、`手渡し: 可（停止確認済み）` とする。停止確認が取れなければ `手渡し: 不可` と書く

#### Scenario: channel の保留でも引き継ぎを残す

- **WHEN** channel の本体が pr-review-gate の保留で止まる
- **THEN** 本体は同じ書式の引き継ぎのコメントを `実行モード: channel` で残し、主への案内に新しいセッションを開く案内を含めない

### Requirement: 空の return を受けたら報告を 1 回だけ求め、同じ指示で起こし直さない

本体は、W が `(Subagent completed but returned no output.)` だけを返したとき（`continue: false` による打ち切りで、拒否理由が親に届かない場合を含む）、その W に SendMessage で報告を 1 回だけ求めなければならない（MUST）。求める報告の項目は、打ちたかったコマンドの全文・対象のパス・その対象を自分で作ったか（作ったなら作ったコマンド）・なぜ要るか・拒否の記録のパスの 5 つとし（MUST。子への拒否理由が求める項目とそろえる）、何をしようとして何が拒否されたかを書かせる。本体は、報告の有無によらず `git -C <path> status --porcelain` で作業ツリーの未コミット差分を確かめ、残っていれば引き取らなければならない（MUST）。報告に破壊的 git 操作で打ち切られたとあるときは、同じ指示で W を起こし直してはならない（MUST NOT）。扱いは要件「破壊的 git 操作の拒否の報告を受けたら、条件を満たすときだけ許可を書いて再開し、それ以外はオーナーに上げる」に従い、許可を書けなかった場合は、打ち切られた操作と指示の見直しを主に上げなければならない（MUST）。ただし、許可を書くスクリプトが終了コード 3 で終わり、同じ要件の「形の理由で断られたときの打ち直し」の条件を満たすときは、主に上げずに打ち直しを指示する（その要件に従う）。許可を書いて同じ W を SendMessage で再開することと、打ち直しを指示して同じ W を再開することは、同じ指示での起こし直しに数えない。打ち直しのあとに W が空の return で返ったときは、その打ち直しについて報告を改めて 1 回だけ求めてよい（打ち直しの前に求めた 1 回とは別に数える）。1 回求めても報告が空のとき、または報告から打ち切りの原因が読み取れないときも、同じ指示で W を起こし直してはならず（MUST NOT）、空だったことと作業ツリーの状態を主に上げなければならない（MUST）。`skills/develop/references/worker-recovery.md` にこれらを書き、SKILL.md は W の空 return を受けたときに同ファイルを必ず読むよう指示しなければならない（MUST）。

この要件の対象は W だけである。R1・G・レビュアーなど再開しない役が空で返ったときの扱いは、この要件の範囲外とし、既存の要件（手渡しの許可条件、G が工程中断で返したときの扱い）に従う。

**守備範囲**: 判定する入力は、develop の本体が名前付きで起こした W の return 文字列である。W は名前付きで起こされるので SendMessage で再開できる（バックグラウンドと既定の起こし方の両方で報告を取り直せることは、実機確認で確かめる）。拾いたい誤りは、拒否の理由が届かない空の return を「作業が終わった」と読み違えること、および原因が分からないまま同じ指示で W を起こし直して同じ操作に再度当たることの 2 つである。通ってよい入力は、`(Subagent completed but returned no output.)` 以外の通常の return（`工程完了:` `工程中断:` で始まるもの）で、これには従来どおりの扱いを適用する。守らないものは、W が報告で嘘や誤りを書くこと（差分は報告に頼らず `git status` で確かめるに留める）、および空の return の原因が打ち切り以外であるすべての場合（原因が読めなければ主に上げる）である。穴が見つかるたびに判定を増やして塞ぎ切ることは完了条件にしない。

#### Scenario: 報告を 1 回だけ求める

- **WHEN** SKILL.md の必読指示から `skills/develop/references/worker-recovery.md` の `returned no output` を含む段落を読む
- **THEN** SendMessage で 1 回だけ報告を求める、と書かれており、`git -C <path> status --porcelain` で未コミット差分を確かめることも書かれている

#### Scenario: 打ち切られたら起こし直さない

- **WHEN** 同じ段落を読む
- **THEN** 報告に破壊的 git 操作で打ち切られたとあれば、同じ指示では起こし直さず、許可を書いて同じ W を再開することも、許可を書くスクリプトが終了コード 3 で終わり打ち直しの条件を満たすときに打ち直しを指示して同じ W を再開することもできない場合に限って主に上げる、と書かれている

#### Scenario: 打ち直しのあとの空の return には報告を改めて 1 回だけ求める

- **WHEN** `returned no output` を含む段落とその直後の打ち直しの段落を読む
- **THEN** 打ち直しを指示したあとに W が空で返ったら、その打ち直しについて報告を改めて 1 回だけ求めてよく、それも空なら空だったことと作業ツリーの状態を主に上げる、と書かれている

#### Scenario: 再報告が空でも起こし直さない

- **WHEN** 同じ段落を読む
- **THEN** 1 回求めても報告が空のとき（または原因が読み取れないとき）も、同じ指示では起こし直さず、空だったことと作業ツリーの状態を主に上げる、と書かれている

#### Scenario: 対象は W だけ

- **WHEN** 同じ段落を読む
- **THEN** 対象が W であり、再開しない役（R1・G・レビュアー）は既存の手順に従う、と書かれている

#### Scenario: 報告の項目を求める

- **WHEN** 同じ段落を読む
- **THEN** 報告に求める項目として「コマンドの全文」「対象のパス」「自分で作った」「なぜ」が書かれている

### Requirement: 破壊的 git 操作の拒否の報告を受けたら、条件を満たすときだけ許可を書いて再開し、それ以外はオーナーに上げる

本体は、名前付きで起こした W の報告（通常の return、または空の return への報告要求の返事）に、破壊的 git 操作を hook に拒否されたこと（拒否の記録のパスがある）が書かれているとき、次のとおり扱わなければならない（MUST）。`skills/develop/references/worker-recovery.md` の、要件「空の return を受けたら報告を 1 回だけ求め、同じ指示で起こし直さない」に対応する段落と、その直後の打ち直しの段落に、これらを書かなければならない（MUST）。SKILL.md は通常の return を含む拒否報告を受けたとき、許可や再開の前に同ファイルを必ず読むよう指示しなければならない（MUST）。

許可を書く条件: 次の 4 つをすべて満たすときだけ、本体の Bash で `${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-permit.sh <拒否の記録のパス> <理由>` を実行する（MUST。許可の仕組みは spec destructive-git-hook の要件のとおりで、この要件は作り直さない）。

1. 報告に 4 項目（打ちたかったコマンドの全文・対象のパス・その対象を自分で作ったか（作ったなら作ったコマンド）・なぜ要るか）が揃い、報告のコマンドの全文が拒否の記録の `command` に一致する。拒否の記録の `cwd` はコマンドを始めたディレクトリであって操作対象ではないので、`cwd` と対象のパスは同じものとして照合しない（MUST NOT）。コマンドの全文・実行時の `cwd`・操作対象の 3 つを分けて見る: 全文は記録の `command` と、操作対象は報告の「対象のパス」と照合し、`cwd` は記録の値をそのまま使う。`git -C <scratchpad の中の repo> checkout -- .` を通常の worktree から打つ場合、`cwd` は worktree、対象は scratchpad の中の repo で、これは許可の対象になりうる
2. 操作対象（`cd` の移り先や `git -C` の指す repo）が、このセッションの scratchpad の中にある。対象が scratchpad の中かどうかの機械的な判定は、許可を書くスクリプトが `cwd` から `cd` と `-C` を順に辿って行うので（#1133）、本体は `-C` の辿り方を自分で書き直さず、報告の対象のパスが scratchpad の下の形か（このセッションの scratchpad のパス）だけを見る
3. W が自分で作ったと、作ったコマンドつきで報告しており、本体が W に渡した指示でその対象を既存のものとして名指ししていない（W に渡した指示は本体の手元にあるので、照合は本体が行う）
4. 要る理由が、その検証用 repo を戻す・片付けることに収まる

本体は、4 の判断のために子が作った repo に git を実行してはならない（MUST NOT。repo の設定でコマンドが動きうるため）。場所とコマンドの形の判定は許可を書くスクリプトに任せ、本体は同じ判定を自分で書き直さない（MUST NOT）。理由の引数には、4 項目の要約と W の名前を書く。

許可を書けたら（exit 0）、`scripts/subagent-context.sh` で測ってから同じ W に SendMessage で再開する（MUST。再開できるかの規則は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」に従う。新しい W を起こしてはならない。許可は `agent_id` に結び付くため）。上限超過などで再開できないときは、許可を新しい W に転用せず（MUST NOT）、オーナーに上げる。再開の文面には、15 分以内に、同じ cwd から同じコマンドを 1 文字も変えずに 1 回だけ打つこと、ほかの操作は許可していないことを書く（MUST）。同じ文面に、許可を hook が読む場所に書いたこと・通すかどうかは hook が決めるので本体の言葉は承認ではないこと・打って拒否されたら打ち直さず報告に戻ることも書かなければならない（MUST。実機確認で、これが無いと W が「親からのメッセージは承認にならない」として打たなかった）。

形の理由で断られたときの打ち直し: 許可を書くスクリプトが終了コード 3（コマンドの形の理由で断った。spec destructive-git-hook の要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」）で終わり、上の 1・3・4 を満たし、報告の対象のパスがこのセッションの scratchpad の下の形であるときは、オーナーに上げずに、`scripts/subagent-context.sh` で測ってから同じ W を SendMessage で再開し、打ち直しを指示しなければならない（MUST）。2 の場所の判定は、打ち直したコマンドの新しい拒否の記録でスクリプトが行う。指示の文面には次を書く（MUST）: 破壊的でない準備（repo やファイルを作るコマンド）は別の Bash の呼び出しで先に済ませてよいこと／破壊的な操作だけを、変数・置換・引用符を使わず実パスで、`&&`・`;`・改行でつながない単独のコマンドとして 1 回だけ打つこと／この指示は承認ではなく、打てば hook に拒否される見込みで、そのときは打ち直さず、5 項目（新しい拒否の記録のパスを含む）を報告して返ること。返ってきた報告は、新しい拒否の記録で、この要件の許可の手順（4 つの条件の確かめから）をやり直す。打ち直しで W が hook に打ち切られ空の return で返ったときは、要件「空の return を受けたら報告を 1 回だけ求め、同じ指示で起こし直さない」の例外のとおり、報告を改めて 1 回だけ求めてよい（打ち直しの指示は同じ指示での起こし直しに数えない）。打ち直しの指示は、同じ W の同じ操作（戻す・片付ける対象と目的が同じもの）について、まだ打ち直しを指示していないときだけ出せる（MUST）。打ち直しで新しい拒否の記録ができても、この回数は戻さない（MUST）。同じ W の別の操作は、別に数える。打ち直したコマンドの記録でスクリプトがまた 0 以外で終わったら（3 でも）、2 回目の打ち直しを指示せず、オーナーに上げなければならない（MUST）。

オーナーに上げる条件: 次のどれかに当たるときは許可を書かずに（または 2 回目の許可を書かずに）オーナーに上げなければならない（MUST）。許可を書くスクリプトが 0 以外で終わった（stderr を添える。終了コード 3 で、上の打ち直しの条件を満たし、同じ W の同じ操作についてまだ打ち直しを指示していないときを除く）／同じ W を再開できない（コンテキスト上限超過など）／上の 4 つのどれかを満たさない（満たさなかった条件を添える）／許可を書いて再開した W が同じ拒否で再び返った／拒否を報告したのが再開しない役（R1・G・レビュアー。許可は子の `agent_id` に結び付き、再開しない役には使えないため）。上げる文面は、何を・どのパスに・なぜ、本体が確かめた事実、推奨を含める（MUST）。無人のセッションではチャンネルで承認を求める。承認されたらオーナーが自分で実行し、本体が代わりに実行してはならない（MUST NOT）。

**守備範囲**: 判定する入力は、W の報告の文字列と、本体が W に渡した指示と、許可を書くスクリプトの終了コードである。拾いたい誤りは、一時領域の外や子が作っていないものへの破壊的操作に親が許可を書くことと、許可を書けるのに毎回オーナーの画面待ちで止めることの 2 つである。守らないものは、W が報告で作ったと偽ること（消えるのは scratchpad の中に限られ、場所の判定が外への許可を書かせない）と、許可の期限（15 分）内に再開できず同じ拒否が再び来ること（オーナーに上がるだけで、守りは変わらない）である。穴が見つかるたびに条件を増やして塞ぎ切ることは完了条件にしない。

#### Scenario: 許可を書く条件が書かれている

- **WHEN** SKILL.md の必読指示から `skills/develop/references/worker-recovery.md` の `returned no output` を含む段落を読む
- **THEN** `git-guard-permit.sh` を実行して許可を書く条件として、scratchpad の中・自分で作った・戻す用事に収まることが書かれており、対象の repo に git を実行しないことも書かれている

#### Scenario: 通常の worktree から scratchpad の中の repo を -C で戻す操作も許可の対象になる

- **WHEN** 同じ段落を読む
- **THEN** 拒否の記録の `cwd` と操作対象のパスを同じものとして照合しない（コマンドの全文・実行時の `cwd`・操作対象を分けて見る）ことが書かれており、`git -C <scratchpad の中の repo> checkout -- .` を worktree から打った場合を許可の対象として扱うことが書かれている

#### Scenario: 許可を書いたら同じ W を再開する

- **WHEN** 同じ段落を読む
- **THEN** 許可を書けたら同じ W を SendMessage で再開すること（再開できるかは decision-criteria「コンテキスト上限（サブエージェントの手渡し）」に従い、できないときは新しい W に転用せずオーナーに上げること）、同じコマンドを 1 文字も変えず 1 回だけ打たせること、新しい W を起こさないことが書かれている

#### Scenario: オーナーに上げる条件が書かれている

- **WHEN** 同じ段落を読む
- **THEN** スクリプトが 0 以外で終わったとき（終了コード 3 で打ち直しの条件を満たし、同じ W の同じ操作についてまだ打ち直しを指示していないときを除く）・条件を満たさないとき・再開後に同じ拒否が再び来たとき・再開しない役が報告したときはオーナーに上げることが書かれており、承認されたらオーナーが自分で実行することも書かれている

#### Scenario: 形の理由で断られたら 1 回だけ打ち直しを指示する

- **WHEN** `skills/develop/references/worker-recovery.md` の、`returned no output` を含む段落とその直後の段落を読む
- **THEN** 許可を書くスクリプトが終了コード 3 で終わり、1・3・4 を満たし報告の対象のパスが scratchpad の下の形なら、オーナーに上げずに同じ W を再開して、準備を別の呼び出しで先に済ませ、破壊的な操作だけを実パスの単独のコマンドとして 1 回だけ打ち、拒否されたら打ち直さず報告に戻るよう指示することが書かれており、新しい拒否の記録で許可の手順をやり直すこと、打ち直しの指示は同じ W の同じ操作について 1 回までで新しい拒否の記録になっても回数を戻さないこと、打ち直したあとにスクリプトがまた 0 以外で終わったらオーナーに上げることも書かれている

#### Scenario: 実機で、まとめて打った後始末が打ち直しを経て人の確認なしに通る

- **WHEN** `claude -p --plugin-dir <worktree>/plugins/dev-workflow` の親が、子に、まず破壊的でない別の呼び出しで scratchpad の中に `repoA`（`a.txt` を commit したもの）を作らせ、そのあと追加の準備（`a.txt` を書き換える）と `git -C <scratchpad>/repoA checkout -- a.txt` を `&&` でまとめて打たせる（最初の拒否の時点で、対象は子が作ったもの）
- **THEN** hook が拒否し、親のスクリプトが終了コード 3 で終わり、親が打ち直しを指示し、子が単独のコマンドで打って拒否され、親が許可を書き、再開した子のコマンドが通って a.txt が戻る。人は確認画面を押さない

#### Scenario: 実機で、打ち直しても scratchpad の外なら許可を書かない

- **WHEN** 同じ親が、子に、まず破壊的でない別の呼び出しで scratchpad の外（作業ツリーの外の一時の場所）に検証用 repo `<外>/repoC`（`c.txt` を commit したもの）と、scratchpad の中にそれを指す symlink `<scratchpad>/linkC` を作らせ、そのあと追加の準備（`c.txt` を書き換える）と `git -C <scratchpad>/linkC checkout -- c.txt` を `&&` でまとめて打たせる（最初の拒否の時点で、repo もリンクも子が作ったもので、報告の対象のパスは scratchpad の下の形になる）
- **THEN** 親のスクリプトが 1 回目に終了コード 3 で終わって親が打ち直しを指示し、子が単独のコマンドで打ち直した記録ではスクリプトが終了コード 1（行き先が scratchpad の外）で終わり、親は 2 回目の打ち直しも許可も書かずオーナーに上げる文面を出し、c.txt は checkout で戻らず子が書き換えた内容のままで、permit-log に permit の行が無い。どちらの実機の Scenario でも、最初の報告で子が対象を作ったコマンドを示している

### Requirement: サブエージェント方式では親を兼ねる本体が権限に照らす
サブエージェント方式（unmanned・channel を含む）のエピックでは、親を兼ねる本体が、子の記録先の計測の exit 2 で主に聞く前に、見込みを子の記録先にコメントしなければならない（MUST）。そのうえで要件「親は PR トークン上限の止まりを権限に照らして続けさせる」の条件 (a)・(b) で照らし、満たせば要件「親の権限で続けた上限は子の本体が記録先に書く」の書式で投稿して続ける（MUST）。満たさなければ、exit 2 の手順で主に問う。手順は `skills/develop/references/pr-token-budget.md` に書き、SKILL.md は計測前に同ファイルを必ず読むよう指示する（MUST）。

#### Scenario: サブエージェント方式では本体が照らして書く
- **WHEN** サブエージェント方式のエピックで、子の記録先の計測が exit 2（合計 31000000 / 上限 30000000）になり、本体の見込みが合計 40000000、権限が 60000000
- **THEN** 本体は見込みを子の記録先にコメントし、主に聞かずに `PR トークン上限: 60000000`（`決めた人: エピック #<E> の本体（親の権限の内）`・`停止の記録: なし`）を投稿して続ける

### Requirement: CI fix の W を起動または再開する前に以前の手渡し可を無効にする

CI 用引き継ぎが最新の可である間に W を起動／再開するたびに（CI fix とゲート failed の直しを含む）、事前に許可条件を確認して依頼入力を保持し、同じ必要項目を持つ最新の引き継ぎを `手渡し: 不可（W を起動／再開するため、今回の工程完了または停止確認待ち）` として投稿し、投稿成功を確認してから起動／再開を指示しなければならない（MUST）。可へ戻せるのは、今回起動／再開した W の工程完了 return またはその W への停止指示に対する停止確認を受け取り、今回の成果と根拠で新しい引き継ぎを投稿するときだけである（MUST）。以前の完了／停止確認や push・idle だけで可へ戻してはならない（MUST NOT）。

develop/SKILL.md から必読にした `skills/develop/references/gate-result.md` の failed 後の W 起動／再開手順と handover.md を読む場面は、最新 CI 用引き継ぎが可なら同ファイル「起動／再開前の無効化と再許可」に従い、不可の投稿成功後だけ指示することへ接続しなければならない（MUST）。

#### Scenario: 通常経路の CI fix の W を起動または再開する
- **WHEN** 本体が既存 W を implement で再開する、または最新の手渡し可を確認して新しい W を implement で起動する
- **THEN** 本体は確認済みの成果と許可根拠を依頼入力として保持し、起動／再開を指示する前に、必要項目を継承した手渡し不可の新しい CI 用引き継ぎを PR へ投稿する。投稿成功を確認してから指示し、投稿できなければ起動／再開せず停止して同じ停止先へ報告する。以前の可を最新として残さない

#### Scenario: CI fix 後のゲート failed で W を再開する
- **WHEN** CI fix 完了後に手渡し可を記録し、ready 後のゲートが failed になってレビュー指摘の直しで W を再開し、その W が HEAD・作業ツリーを変更する前に本体が交代する
- **THEN** W の再開前に最新の可を不可として投稿し、投稿成功後だけ再開を指示する。交代後の本体が見張りの next から fix を受けても、最新の不可を読み、HEAD 一致・差分なしを根拠に二人目の W を起こさず同じ停止先へ報告する。今回の工程完了または停止確認を根拠とする新しい可が記録されるまで担当を交代させない

#### Scenario: 今回の W の停止確認で可へ更新する
- **WHEN** 今回起動／再開した W に停止を指示し、その W から編集・投稿内容を含む停止確認を受け取る
- **THEN** 今回の停止確認と成果・編集ファイル・commit SHA を記録した新しい手渡し可を投稿できる。未コミット差分があれば本体が commit してから記録し、今回の完了も停止確認も無ければ不可のままにする

#### Scenario: failed 後の本体手順から無効化を辿る
- **WHEN** 本体が develop/SKILL.md から必読にした `skills/develop/references/gate-result.md` の failed 後の W 起動／再開手順または handover.md を読む場面を読む
- **THEN** 最新 CI 用引き継ぎが可の場合は handover.md「起動／再開前の無効化と再許可」に従い不可を投稿し、投稿成功後だけ W に指示するという接続がある。投稿失敗なら W を起動／再開せず既存の停止先へ報告する

### Requirement: 本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する
SKILL.md の (4) の Status 表から必読にした `skills/develop/references/gate-result.md` は、adapter 経路で G から `needs-reviewer` を受けた本体の手順として、次の順序を書かなければならない（MUST）: `codex-develop.py request --phase review` で投げ先を選び直す（実行先オプションはその develop の開始時と同じ）→ 返った選択（構成・reason・Claude と最良 Codex の margin・各 `fetched_at`。欠測は `missing`）と解決した executor / model を記録先の dispatch 記録に投稿する → 投稿に成功してから、選ばれた投げ先でレビュアーを起動する → レビュー要約と、選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。

review phase の executor が `codex` のときは、本体は worker の結果 JSON にある `execution.model_resolution.requested` と `execution.model_resolution.resolved` も G に渡さなければならない（MUST）。G は `レビュー実行者:` 行の `<model>` を `<requested>→<resolved>` の形で記録しなければならない（MUST）。解決値が未観測のときは要求値や dispatch 時の model から補完してはならない（MUST NOT）。

渡し方は G の起動形で分けて書かなければならない（MUST）: Claude の G は SendMessage で再開して渡す（`gate-runner.md`「needs-reviewer の return」節と `skills/develop/references/gate-result.md` の既存規則）。Codex の G は新しい phase `gate` を開始してその入力に渡す（`codex-develop.md`「品質と transport 差分」の G の項）。

本体は選び直しと記録の前にレビュアーを起動してはならない（MUST NOT）。従来経路（`レビュー経路: 従来` または行が無い G）が `needs-reviewer` を返したときに呼び出し元がレビュアーを起こす手順（`gate-runner.md` の既存記述）は変えてはならない（MUST NOT）。

`pr-review-gate/stages/triage.md` と `pr-review-gate/stages/review-run.md` は、adapter 経路で要約を受け取った G の「レビュー実行者:」コメントの形 `レビュー実行者: <executor>/<model>（adapter 経路・<light|full>・dispatch 記録: <URL>）` を持たなければならない（MUST）。`<light|full>` には手順 2-0 の判定を書く。executor が `codex` なら `<model>` は `execution.model_resolution.requested` と `resolved` を使った `<requested>→<resolved>` とし、executor が `claude` なら従来の model 値を使う。`stages/triage.md` の「レビュー実行者:」の書き分けと、`stages/review-run.md` の書き分けおよび PR コメント雛形に、この 1 形を足し、2 つのファイルの間で食い違わないようにしなければならない（MUST）。

#### Scenario: claude-default が選ばれる
- **WHEN** adapter 経路（自動選択）で G が `needs-reviewer` を返し、`request --phase review` が構成 `claude-default`・executor `claude`・model `opus` を返す
- **THEN** 本体は構成・reason・両 provider の margin と `fetched_at` を記録先に投稿してから、Agent ツールで `opus` のレビュアーを起動し、Codex を呼ばない。要約を渡すとき `claude/opus` と dispatch 記録の URL も G に渡す

#### Scenario: Codex が選ばれる
- **WHEN** adapter 経路で `request --phase review` が executor `codex` の request を返し、worker の結果 JSON の `execution.model_resolution` が requested=`sol`、resolved=`gpt-6-sol` を返す
- **THEN** 本体は選択を記録先に投稿してから request を実行し、レビュー要約・dispatch 記録 URL とともに requested=`sol`、resolved=`gpt-6-sol` を G に渡す

#### Scenario: G がレビュー実行者を記録する
- **WHEN** adapter 経路の G が本体から Codex レビュー要約と requested=`sol`、resolved=`gpt-6-sol`、dispatch 記録の URL を受け取る
- **THEN** G は `レビュー実行者: codex/sol→gpt-6-sol（adapter 経路・<light|full>・dispatch 記録: <URL>）` の PR コメントを投稿し、その埋め方は `pr-review-gate/stages/review-run.md` にも説明される

#### Scenario: 回帰テスト
- **WHEN** `bash scripts/test.sh` を実行する
- **THEN** `gate-runner.md`・`SKILL.md` とその必読先・`codex-develop.md`・`pr-review-gate/stages/triage.md`・`pr-review-gate/stages/review-run.md` の上記文言を照合する bats を含めて exit 0 になる

### Requirement: 失敗の段は `--failure` で request に渡し、返った model を使う
SKILL.md「モデル」節は、失敗ループで起動・再開を扱う前に `plugins/dev-workflow/references/codex-develop.md` の「起動と role 解決」を必ず読むよう指示しなければならない（MUST）。対応する失敗ループの本文は同 reference の一つの正本へ集約し、SKILL.md には再掲してはならない（MUST NOT）。この必読参照先は、`request` の `--failure` の各値がどの失敗の段に当たるか（`first` = 1 回目の失敗、`executor` = 2 回目で実行側が原因、`judgment` = 2 回目で判断側が原因）を書かなければならない（MUST）。決める役と実行役の model は、その段の `--failure` を渡した `request` が返した値を使うと書かなければならず（MUST）、決める役の model を `templates/escalation-tripwires.md` の文面から読み取る指示を書いてはならない（MUST NOT。判断側・実行側の分類の定義を読む先として同テンプレートを指すことは許す）。実行側の昇格は「W を上位で再開」ではなく、格が上がって model が変わるなら新しい thread に手渡す、と書かなければならない（MUST。同 reference の失敗ループの本文が正本）。

#### Scenario: `--failure` の値と段の対応が書かれている
- **WHEN** SKILL.md「モデル」節と、そこから操作前の必読にした `plugins/dev-workflow/references/codex-develop.md` の失敗ループの本文を読む
- **THEN** SKILL.md に操作前の必読指示があり、参照先に `--failure first`・`--failure executor`・`--failure judgment` のそれぞれが、1 回目の失敗・2 回目の実行側・2 回目の判断側に当たると書かれている

#### Scenario: decider の model を文面から読まない
- **WHEN** SKILL.md「モデル」節と、そこから操作前の必読にした `plugins/dev-workflow/references/codex-develop.md` の失敗ループの本文を読む
- **THEN** SKILL.md と必読参照先には「decider の `model` の段は `templates/escalation-tripwires.md` を Read して従う」の形の文が無く、必読参照先に `request` が返した model を使うと書かれている

#### Scenario: 実行側の昇格は新しい thread
- **WHEN** SKILL.md「モデル」節と、そこから操作前の必読にした `plugins/dev-workflow/references/codex-develop.md` の失敗ループの本文を読む
- **THEN** 必読参照先に、実行側の昇格で model が変わるときは SendMessage で再開せず新しい thread に手渡すと書かれている

## ADDED Requirements

### Requirement: 起動時の先頭に本体の骨格と読み直しの指示を置く

SKILL.md は役割表、本体が自分でコードを書かない・レビューしない禁止事項（軽い通し方の既存例外を含む）、工程順と操作前の正本の読み直し指示を先頭 5,000 トークン以内に置かなければならない（MUST）。換算方法と対象範囲は PR 本文に再現可能なコマンドで示す（MUST）。自動要約後も、場面限定の正本を読む入口を残す（MUST）。

#### Scenario: 本体の骨格が先頭にある
- **WHEN** SKILL.md の先頭から役割表・禁止事項・工程概要・読み直し指示の末尾までを測る
- **THEN** PR に記載した換算で 5,000 以下となり、記録先→仕様化判断→R1→実装＋verify→必要時 V→archive＋Draft PR＋仕様宣言→G の順と、既存の例外への参照がある

### Requirement: 場面限定の本体手順は起きた場面で必読にする

SKILL.md は PR トークン上限・G の状態別分岐・W の空 return と破壊的 git 操作の許可の手順の中身を持たず、読む場面と読む先を残さなければならない（MUST）。spawn・再開・Codex 委譲の前は pr-token-budget.md、G の結果の処理前は Status 表の行き先、W の空 return または通常 return を含む拒否報告では再開・許可の前に worker-recovery.md を必ず読むよう指示する（MUST）。

#### Scenario: G の状態から本体の詳細へ進む
- **WHEN** 本体が G の Status を受け取る
- **THEN** SKILL.md の Status → 読むファイルの表から、次の段へ・passed・needs-reviewer・重複で降りた・review-incomplete・failed・保留・needs-fix-check・needs-carryover-judge・needs-no-point-check・needs-decider の対応先を読める。決める役の起動・代理投稿の例外・再要求の制約は到達先に保たれる

#### Scenario: 通常の return に拒否の報告がある
- **WHEN** W が工程完了または工程中断の return に破壊的 git 操作の拒否を報告する
- **THEN** 空 return のときと同じく、本体は worker-recovery.md を必ず読んでから許可や再開を扱う。移動によって許可条件・回数・権限は変わらない

#### Scenario: 単発の issue の開始では不要な詳細を読まない
- **WHEN** G の結果も拒否報告もまだ無い単発の issue を開始する
- **THEN** 起動時の三ファイルに状態分岐と拒否復旧の本文は無く、その場面の必読参照だけがある。spawn 前のトークン計測など、既に必要な場面では詳細の必読を省かない

### Requirement: 文言検査は手順書の移動に依存せず入口と予算を別に守る

手順の文言の bats は、develop 配下の手順書集合のどこかに規則があることを確かめ、移動だけで落ちてはならない（MUST NOT）。Codex 固有の規則は正本 codex-develop.md を対象に加える。入口から正本への必読参照、核心規則の先頭位置、役割解決本文の一元化は別に検査しなければならない（MUST）。起動時の三ファイルと切り出し先にはファイル別の実測バイト予算を置き、超過と実測の 1.1 倍を超える余白を拒否する（MUST）。

**守備範囲**: 入力元は、リポジトリの `plugins/dev-workflow/skills/develop/SKILL.md` と `skills/develop/references/**/*.md` の手順書集合（後者も同 plugin 配下）、Codex 固有の規則では `plugins/dev-workflow/references/codex-develop.md`、入口の `plugins/dev-workflow/commands/develop.md`、起動時の三ファイルと切り出し先の予算ファイル、およびそれらの使い捨て fixture である。拾う誤りは、検査対象の規則の欠落、入口の必読参照の欠落、核心規則の先頭 5,000 トークン範囲からの逸脱、役割解決本文の重複、バイト予算の超過と実測の 1.1 倍を超える余白である。内容・必読参照・先頭位置・一元化の検査を満たしたまま、場面限定の二つの段落を同じ字数・バイト数で別の手順書間で入れ替え、各ファイルの予算も変わらない場合は、読む場面に合わない配置になっても検査を通ることを許す（#1682 の OWNER の決定）。字数・バイト数が同じ入替えや、存在する文の意味・実エージェントの読解まで機械で保証し、範囲外の穴を全て塞ぎ切ることは完了条件にしない。

#### Scenario: 文を移すだけなら検査が通る
- **WHEN** 使い捨て fixture で必要な規則を develop の別の手順書へ移し、読む場面からの参照を保つ
- **THEN** 内容検査が通る。一方、規則を手順書集合から消した fixture は落ちる

#### Scenario: 内容だけ残して必読参照を消す
- **WHEN** 拒否復旧の手順を残したまま、SKILL.md の通常の拒否報告での必読指示を消す
- **THEN** 入口の構造検査が落ちる

#### Scenario: 起動時と条件付きの予算を守る
- **WHEN** 起動時の三ファイルまたは切り出した手順書の複製を予算より 1 byte 大きくする、または予算を実測の 1.1 倍より大きくする
- **THEN** 対応する予算検査が落ちる。commands/develop.md が SKILL.md と codex-develop.md を名指しする既存検査も維持される

#### Scenario: 同じ量の入替えによる配置の誤りは残りとして受け入れる
- **WHEN** 使い捨て fixture で、検査対象の規則・必読参照・先頭位置・役割解決の一元化を保ち、場面限定の段落を同じ字数・バイト数で手順書間で入れ替え、各ファイルの実測と予算を変えない
- **THEN** 文言・入口・先頭位置・一元化・予算の検査が通ることを許す。場面に合わない配置をこの入替えだけで検出することや、守備範囲外の穴を塞ぎ切ることは完了条件にしない

### Requirement: 切り出し後の読む量と段落の行き先を記録する

起動時に読む三ファイルの前後の字数を UTF-8 の wc -m 相当で PR 本文と親エピックのコメントに記録しなければならない（MUST）。PR 本文には移した段落ごとに、単発 issue のどの場面で読まずに済むか、必要な場面で何を必読として残したかを記録する（MUST）。減った量そのものを合否条件にしてはならない（MUST NOT）。例・経緯・既存正本と同文の段落を削除または参照化しても、既存の条件・権限・工程の順は変えてはならない（MUST NOT）。

#### Scenario: PR と親エピックに測定を残す
- **WHEN** 切り出し後の PR を用意する
- **THEN** 基準 HEAD と対象パス・測定コマンド・三ファイルの前後の字数・先頭位置の換算・段落別の行き先と読む場面が PR 本文にあり、字数の前後が親エピックにも記録される
