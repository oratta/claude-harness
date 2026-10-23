## 1. 文面のテストを先に書く

- [ ] 1.1 `tests/develop-skill.bats` の PR トークン上限のテストに 1 件足す。中身: 節「PR トークン上限」の exit 2 に、エピックの子なら主に聞く前に親の権限に照らすこと・新上限は権限・`PR トークン上限: <権限>` に `決めた人:`・`権限:`・`停止の記録:` の行を添えること・照らし方の正本が `references/epic.md` にあること・サブエージェント方式では本体が見込みを記録先にコメントしてから照らすことが書かれている。既存の「続ける」の式（合計 ＋ 直前の上限）は残っていること。足したテストが今の main で落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:525-590（PR トークン上限のテストの並び）
- [ ] 1.2 `tests/epic-dispatch.bats` の skill のテストに足す。中身: `references/epic.md` に、`子の PR トークン権限: 60000000` の投稿と主への案内（「子 1 件 6,000 万トークンで回す。広げたければ声をかけて」）・主が広げたときの `主の発言:` の行・権限のコメントが無いエピックの再開・手順 8 の `PR トークン上限（` の振り分け・通す条件の (a)(b)・`親の判断: 子 #N 通した — PR トークン上限を親の権限` の行・照らす前に権限のコメントが無ければ既定値で投稿すること・主が広げて答えたら照らし直して `reply --as parent` を送ること・広げずに「続ける」なら `reply --as owner` で届けることが書かれている。`references/epic-child-stop.md` に、`止まった理由:` の頭の `PR トークン上限（合計` と見込みの 3 行（`終わるまでの見込み:`・`続けるべきか:`・`次に絞る範囲:`）と、親の権限の返事は主の事前承認の範囲の執行なので主に聞き直さないことが書かれている。今の main で落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3512-3560（手順 8 の skill のテストの並び）
- [ ] 1.3 基準ファイルのテストを直す。`grep -F 'トークン上限の引き上げ' | grep -F 'exit 2' | grep -qF '記録が作られない'` を外し、代わりに次の 2 つを確かめる。`トークン上限の引き上げ` の行に `親の権限` と `手順 8` があること。`親の返事だけではこの記録が作られない` の文が無いこと。9 つの条件の数（表の 10 行）は変えない。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3606-3630

## 2. 手順書

- [ ] 2.1 SKILL.md「PR トークン上限」の exit 2 に、エピックの子の分岐を足す。足す中身は次の 4 つ。
  - 別セッション方式の子は今までどおり止まって見込みを記録に書き、親が照らす（`references/epic-child-stop.md` を指す）
  - サブエージェント方式では、本体が見込みを子の記録先にコメントし、`references/epic.md` の条件で照らす
  - 「続ける」の項に「親の権限で続けるときは新上限 ＝ 権限、記録の 4 行の書式」を足す。親の返事を受けた子の本体も、この書式で書く
  - 既定の上限を変えない理由を 1 文で書く

  確認: 1.1 が通る。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:238-241
- [ ] 2.2 `references/epic.md` に、権限と、手順 8 の振り分けと専用の手順を書く。書く中身は次の 4 つ。
  - 「回し方」の `回し方:` コメントを残す段落に、権限のコメントの投稿と主への案内を足す。unmanned はコメントだけ。主が広げたときの投稿し直しと、親の判断で広げないことも書く
  - 手順 7（再開）に、権限のコメントが無ければ既定値で投稿して主に伝えることを足す
  - **PR トークン上限の子** の段落の頭（照らす前）にも、権限のコメントが無ければ既定値で投稿して主に伝えてから、その値で照らすことを書く。主に上げるのは、投稿者の条件を満たす権限のコメントの値が数字として読めないときだけ
  - 手順 8 の `PR のマージ待ち（` の振り分けの前に、`PR トークン上限（` の振り分けを足す
  - **マージ待ちの子** の段落のあとに、**PR トークン上限の子** の段落を足す。中身は、権限の読み方（最新・投稿者の条件）・(a)(b) の条件・読めないときは主に上げること・`reply --as parent` の返事の文・`親の判断:` の行・通さないときに権限の値と広げる選び方を添えること。主が権限を広げて答えたら、権限のコメントを `主の発言:` の行つきで投稿し直し、同じ止まりを (a)(b) に照らし直して、満たせば `reply --as parent` で新しい上限 ＝ 新しい権限を送ること。主が広げずに「続ける」とだけ答えたら、今までどおり `reply --as owner` で届け、子の本体は既存の式（合計 ＋ 直前の上限）で書くこと。サブエージェント方式の本体も同じ条件を使うことを書き、SKILL.md から指される正本にする

  確認: 1.2 の epic.md 分が通る。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:25（経路の決め方と `回し方:`）、plugins/dev-workflow/skills/develop/references/epic.md:54（手順 7）、plugins/dev-workflow/skills/develop/references/epic.md:55（手順 8）、plugins/dev-workflow/skills/develop/references/epic.md:59（マージ待ちの子のあと）
- [ ] 2.3 `references/epic-child-stop.md` に 2 つを足す。足す中身は次の 2 つ。
  - 「記録の形」の注意書きに、PR トークン上限で止まるときの `止まった理由:` の頭と、`前提:` の見込みの 3 行
  - 「親から届いた返事」に、`続ける。新しい上限 <権限>` の返事を受けたら次の計測より前に記録先へ `PR トークン上限:` の 4 行を投稿すること（書式の正本は SKILL.md「PR トークン上限」）。同じ段落の「親の判断は主の承認ではないので、聖域…の承認として扱わない（その件は改めて主に聞く）」の文のあとに、次の 1 文を足す: この返事は主が権限のコメント（`子の PR トークン権限:`）で先に承認した範囲の執行なので、聖域の承認にも基準の聖域の「課金」にも当たらず、主に聞き直さずに権限の URL を `権限:` の行に残して再開する

  確認: 1.2 の epic-child-stop.md 分が通る。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:14（親から届いた返事）、plugins/dev-workflow/skills/develop/references/epic-child-stop.md:29-33（記録の形の注意書き）
- [ ] 2.4 `references/parent-pass-criteria.md` を直す。直す中身は次の 2 つ。
  - 通す条件の 1 行目の中身に、PR トークン上限の止まりは判断のモデルでは通さず、起こされた親が `epic.md` 手順 8 で親の権限に照らすことを添える
  - 通らない例の先頭の理由を「判断のモデルには親の権限が渡らないので通さない。起こされた親が `epic.md` 手順 8 の専用の手順で権限に照らし、権限の内なら親が続けさせる」に直す

  `stop-judge.sh` は変えない。確認: 1.3 が通る。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:17、plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:46-48

## 3. 記録と確認

- [ ] 3.1 `plugins/dev-workflow/changes/1245.md` に変更の記録を書く。中身は次の 4 つで、版は上げない。
  - 何を・なぜ（主の決定のコメントの URL）
  - 権限の既定 60000000
  - 既定の上限を変えないこと
  - スクリプトを変えないこと

  `docs/public-private-split.md` の表は部品を足さないので変えない（確かめるだけ）。触る範囲: plugins/dev-workflow/changes/1245.md（新規）
- [ ] 3.2 触った部分のテストだけを手元で回す。確認: 次の 4 つが通る。全体のテストは CI に任せる。触る範囲: なし（確認だけ）
  - `bats plugins/dev-workflow/tests/develop-skill.bats -f 'token budget'`
  - `bats plugins/dev-workflow/tests/epic-dispatch.bats -f 'skill:|criteria:'`
  - `openspec validate epic-child-token-authority --type change --strict`
  - 公開版の禁止語の検査（`plugins/dev-workflow/scripts/forbidden-words-check.sh` を触ったファイルに）

## Workflow follow-up

- `openspec archive epic-child-token-authority` と PR（本文に `Closes #1245`）は (3b) で行う
