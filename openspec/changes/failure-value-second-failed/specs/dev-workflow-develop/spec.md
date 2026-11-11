## MODIFIED Requirements

### Requirement: 1 ループは W→R1→W→G の順で回る
SKILL.md は 1 issue（または 1 Draft PR）の 1 ループを次の順で規定しなければならない（MUST）: (0) 記録先の確定 →（軽い通し方の分岐: 本体は (1) の W を起こす前に記録先の本文（記録先が無い依頼では、上の「入口 0 は記録先を決める」の例外の順序どおり、Draft PR を作る前に本体が整理した受け入れ条件）から軽い通し方を当てるかを決め、当てるなら (1)〜(3) の W を起こさず、`references/decision-criteria.md` Step B の軽い通し方の小節の手順どおり、判断の記録・直す・`確かめ方:` のコマンドの実行・commit と push・Draft の PR・仕様宣言までを本体が行って (4) へ進む（SHALL）。迷ったら当てず (1) へ進む）→ (1) W が仕様化判断の記録・分割判定・openspec CLI による change の作成（`openspec new change` と artifact の直書き）まで行い return（仕様化しない判定なら (3) へ直行。文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）なら、W は仕様の差分 1 ファイルだけを書いて return し、本体は記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があることを確かめてから (2) を飛ばして (3) へ進む）→ (2) R1 が別コンテキストで仕様レビューし、結果を記録先にコメントして return（R1 を `subagent_type: dev-workflow:decider` で起こした場合は R1 が投稿できないため、本体が return を同じ書式で代理投稿する）。REQUEST_CHANGES なら W を SendMessage で再開して修正し R1 を再開して差分再レビュー（既定 2 周。2 周目以降の周の終わりに BLOCKER が残れば、下の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の直し方の判定を通し、「決まっている」で PR トークン上限の内側なら主に聞かず次の周を回し、そうでなければ `needs-approval`）→ **(3) W を再開して実装以降を回す。(3) は 2 段に分かれ、(3a) 実装（`tasks.md` を TDD で。直行なら TDD。文言合わせの通し方なら W が (1) の return に書いた作業項目を TDD で）・verify（`openspec validate --strict`）まで行って return、本体が計測し、W の return の `画面確認:` の行が `要る` なら画面確認役 V を起こしてから（下の「画面確認役 V は (3a) と (3b) の間に本体が必要時だけ起こす」Requirement）、(3b) `openspec archive`・PR を Draft のまま用意（無ければ Draft で作成）・仕様宣言まで行って return する（下の「W の (3) は 2 回の return に分かれる」Requirement）** → 文言合わせの通し方では、本体は G を起こす前に、記録先の最新の仕様化判断のコメントの `直す文:` の行が archive 済みの差分の要件名と一致することを確かめる（SHALL） → (4) G が pr-review-gate の手順 1〜5 を実行し `passed` / `failed` / `保留` / `needs-reviewer` / `needs-decider` / `needs-fix-check` / `review-incomplete` のいずれかを return。PR の Ready 化は G が手順 5 の合格処理で行い（Draft なら Ready にしてから `agent-review:passed` を付ける）、W は行ってはならない（MUST NOT）。

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
- **THEN** 本体が (1) の W を起こす前に軽い通し方を当てるかを決め、当てるなら (1)〜(3) の W を起こさず本体が直して (4) へ進むこと（unmanned では G を起こさず `agent-review:pending` を付けて終える）と、手順の正本が `references/decision-criteria.md` Step B であることが書かれている

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

