## 1. テストを先に書く（落ちることを確かめる）

- [ ] 1.1 `epic-dispatch.bats` の記録の形のテストを 7 項目にする: 雛形の行で `止まった理由:` → `主に聞く理由:` → `前提:` → `推奨:` → `推奨の根拠:` → `受け入れるリスク:` → `再開に要る途中経過:` の順（行番号の昇順）、「7 つの項目」と「どの項目も省かない」、`主に聞く理由:` の行に 3 つの理由の語（主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作）、`主に聞く理由: なし（<子の側で進められない理由>）`、どれにも当たらなければ止まらずに進めること、`受け入れるリスク:` の説明に「頻度」と「確かめたのか見込みか」、`~/.claude/output-styles/readable.md` を指すこと。テスト名は ASCII のみ 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3159-3175（"skill: an epic child's stop record lists the six items in order"）
- [ ] 1.2 `epic-dispatch.bats` の「手順 8 が記録と同じ項目名を読む」テストを、置き直しのテストに替える: 手順 8 に `同じ項目名のまま` が無い、`止まった理由`・`主に聞く理由`・`前提`・`推奨の根拠`・`受け入れるリスク` の置き直し先（質問・主に聞く理由・いま困っていること・推奨と根拠・受け入れるリスク）が書かれている、項目名をそのまま主に渡さない、1 通で上げるのは 1 件。記録の節に「親の手順 8 が報告する語と同じにしてある」の文が無く、置き直すことが書かれている。あわせて `grep -n '同じ項目名のまま' SKILL.md` が 0 件であることをファイル全体で確かめる 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3186-3192（"skill: step 8 of the Orca route reads the same item names as the stop record"）
- [ ] 1.3 `epic-dispatch.bats` の resolve のテストで、`一致する `親の判断:` が無ければ、判断が無いものとして主に上げる` の検査を新しい文（判断が無いものとして扱う）に替え、親が主に上げる前に `parent-pass-criteria.md` に照らすこと・主に聞く理由の 3 つに当たらなければ `reply --as parent` で通しエピックに `親の判断: 子 #N 通した — <理由> <停止の記録の URL>` を残すこと・迷うときは主に上げることの検査を足す 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3209-3230（"skill: Orca route resolves stopped children in wait and escalates the rest in the readable order"。3220 行が置き換え対象）
- [ ] 1.4 `epic-dispatch.bats` の基準のファイルのテストに足す: 原則の文（主に聞く理由の 3 つに当たらない止まりは親が通す）、表の 9 行それぞれに確かめる理由の列がある（条件の行数 10 の検査は保つ）、通る例の 3 つ（実機テストのための試しの issue 作成・止まった子の起動し直し・Mac が空いてからの CI の再実行）、試しの issue が外部への公開・送信に当たらない旨、`主に聞く理由:` を鵜呑みにしないこと・`なし（` を通す側で読むこと・項目の無い記録はほかの項目から読むこと 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3246-3267（"criteria: the file states the nine conditions, the examples and the output form"）
- [ ] 1.5 `stop-judge.bats` の記録の例を 7 項目にし（`主に聞く理由: なし（hook に止められ子の側では読めない）` の形）、モデルの入力にその行がそのまま入ることを確かめる。新しいテストを 1 つ足し、`主に聞く理由:` の無い以前の形の記録でも exit 0 で 4 行を出し、各行がそのまま入力に入ることを確かめる 触る範囲: plugins/dev-workflow/tests/stop-judge.bats:35（setup の comments_11）、plugins/dev-workflow/tests/stop-judge.bats:114-130（"the model gets the epic, the child, …"）、plugins/dev-workflow/tests/stop-judge.bats:132 の前（新しいテスト）
- [ ] 1.6 `parent-merge.bats` の ci-watch の例のテストで、例の項目に `主に聞く理由:` を足し、その行に「決まりで主の承認が要る」があることを確かめる 触る範囲: plugins/dev-workflow/tests/parent-merge.bats:107-117（"ci-watch: an epic child with only human-merge records a merge-wait stop instead of asking the owner"）
- [ ] 1.7 1.1〜1.6 を回し、1.5 の以前の形のテスト以外が落ちることを確かめる（スクリプトは変えないので 1.5 の互換のテストは最初から通る）

## 2. 子の停止の記録の形（SKILL.md）

- [ ] 2.1 節「エピックの子が主の返事を待って止まるとき」の「記録」の項の「6 つの項目」を「7 つの項目」にする 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:352
- [ ] 2.2 「記録の形」の雛形と箇条書きを書き換える: 「6 つの項目」→「7 つの項目」、`止まった理由:` を「主にしてほしいこと（決めること 1 つ、または操作）」に絞る、2 番目に `主に聞く理由:` を足す（3 つの理由の語で始めて 1 文、決まりなら何を守るためかまで、`~/.claude/output-styles/readable.md` の節 3 を指す）、どれにも当たらなければ止まらずに進めて事後報告するのが決まりで `主に聞く理由: なし（<子の側で進められない理由>）` は子の側で進められないときだけと書く、`受け入れるリスク:` の説明に被害（戻せるか）・頻度（起きる条件）・根拠（確かめたのか見込みか）と分からないときの書き方を入れる。「項目名の `止まった理由` と `推奨` は、親の手順 8 が報告する語と同じにしてある」を消し、「親は記録の項目を正本の段に置き直して主に報告する（手順 8）。`止まった理由` は値の頭（`PR のマージ待ち（`）をマージ待ちの子の段落と `references/parent-merge-criteria.md` が読むので名前を変えない」に替える 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:359-373

## 3. 親の手順 8（SKILL.md）

- [ ] 3.1 手順 8 の「一致する `親の判断:` が無ければ、判断が無いものとして主に上げる」を「判断が無いものとして扱う」にする（取り違えを防ぐ理由の括弧は残す） 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:510（手順 8 の 2 文目）
- [ ] 3.2 手順 8 の「それ以外は主に上げて本文で報告する」の前に、親が主に上げる前に `references/parent-pass-criteria.md` に照らすこと、主に聞く理由の 3 つのどれにも当たらず基準のほかの条件も満たす止まりは `scripts/epic-dispatch.sh reply --as parent <エピック番号> <N> <返事>` で通し、送れたらエピックに `親の判断: 子 #N 通した — <理由> <停止の記録の URL>` を残すこと、迷うときは主に上げることを足す。対象は判断が「主に上げる」・判断できなかった・一致する判断が無い止まりで、`通すが送れなかった` の送り直しは今の文のまま 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:510
- [ ] 3.3 手順 8 の「子の停止の記録の `止まった理由`・`推奨` を同じ項目名のまま含め」を消し、記録の項目を正本の段に置き直す対応（`止まった理由:`→質問、`主に聞く理由:`→主に聞く理由、`前提:`→いま困っていること、`推奨:`・`推奨の根拠:`→推奨と根拠、`受け入れるリスク:`→受け入れるリスク）と、項目名をそのまま主に渡さず子の言葉を主の言葉に直すこと、主に上げる止まりが複数でも 1 通で 1 件にすることを書く。「エピックの目的と他の子との関係」と「子の停止の記録の URL を添え」は残す 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:510
- [ ] 3.4 「マージ待ちの子」の段落は変えない（マージは「決まりで主の承認が要る」に当たり、3.2 の照らし直しでは通らない）。`parent-merge.bats` の段落の検査が通ることだけ確かめる 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:514

## 4. 親が通してよい範囲の基準（parent-pass-criteria.md）

- [ ] 4.1 冒頭の説明のあとに原則の節を足す: 主に聞く理由の 3 つ（主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作。正本 `~/.claude/output-styles/readable.md` の節 3）に当たらない止まりは親が通す。下の 9 つの条件は、その止まりが 3 つのどれにも当たらないことを確かめる手順。判断は `stop-judge.sh` のモデルと、手順 8 で主に上げる前の親のセッションの両方が使う 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:1-5
- [ ] 4.2 通す条件の表に「確かめる理由」の列を足す（既存の規則が主に聞く止まりでない・聖域でない・戻せる → 決まりで主の承認が要る／推奨がある・範囲の内側・主の側の情報が要らない・配役表で主の観点が無い → 主の側にしか答えが無い／実機操作でない → 主の手でしかできない操作／繰り返していない → 同じ止まりを回し続けないための歯止め）。条件は 9 のまま。聖域でないの行に「作業中のリポジトリの中に試しの issue を作って閉じることは外部への公開・送信に当たらない」を添える 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:7-23
- [ ] 4.3 「子の `主に聞く理由:` の読み方」を足す: 書かれた理由が 3 つに当たるかを確かめ、そのまま通す理由・上げる理由にしない／`なし（…）` と 3 つに当たらない理由は通す側で読む／項目の無い記録（以前の形）はほかの項目から判断する／主に聞く理由が成り立つか迷うときは成り立つ側に倒す 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:23-25
- [ ] 4.4 通る例に 3 つ足す: 実機テストのための試しの issue 作成（作業中のリポジトリの中で閉じれば戻せる）／止まった子の起動し直し（親が `reply --relaunch` でできる）／Mac が空いてからの CI の再実行（待って打ち直すだけ） 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:27-35
- [ ] 4.5 守備範囲の節の「拾いたい誤り」に、主に聞く理由の無い止まりを主に上げることを足し、「止めない」に `主に聞く理由:` の無い以前の形の記録を足す 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:58-62

## 5. マージ待ちの記録の例（ci-watch.md）

- [ ] 5.1 「残りの 5 項目」を「残りの 6 項目」にし、例の先頭に `主に聞く理由:` 決まりで主の承認が要る（聖域のファイルに触れた PR は、人の判断を通してからマージすると決まっている）。親の判断で回せる仕組みがあるので、まず親に判断を求める、の形の例を足す 触る範囲: plugins/dev-workflow/references/ci-watch.md:79-84

## 6. 変更の記録と確認

- [ ] 6.1 変更の記録 `plugins/dev-workflow/changes/1183.md` を書く（何を変えたか・入れなかったもの・スクリプトを変えなかった理由） 触る範囲: plugins/dev-workflow/changes/1183.md（新規）
- [ ] 6.2 `bats plugins/dev-workflow/tests/stop-judge.bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/parent-merge.bats` が exit 0。続けて全テスト（`tests/injection-budget.bats` を含む）と lint を回す。常時注入の固定分は変えないので予算は動かさない
- [ ] 6.3 `openspec validate stop-record-ask-reason --type change --strict` が通る
- [ ] 6.4 実機確認: design.md「実機確認の進め方」どおり、`claude -p --plugin-dir <worktree>/plugins/dev-workflow` に 3 場面（rm の許可・CI が落ちた 2 件・初版の記録を配布の前提から外す件）の 7 項目の記録を渡して親の報告か通す判断を書かせ、主に上げた報告が正本の 6 段を満たし項目名を見出しにしていないこと、CI の再実行で足りる件は主に上げず `reply --as parent` の返事と `親の判断: 子 #N 通した` を出すことを確かめる。入力・出力の全文と判定を PR に貼るため scratchpad に残す
