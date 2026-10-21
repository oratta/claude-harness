## 1. テストを先に書く（落ちることを確かめる）

- [ ] 1.1 新しい bats `tests/owner-question-style.bats` を作る。確かめること:
  - readable.md の節 3 に、6 段の語（質問・主に聞く理由・いま困っていること・推奨と根拠・受け入れるリスク・答え方）がこの順で出る
  - 主に聞く理由の 3 つ、「どれにも当たらなければ聞かずに進め、事後報告する」、リスクの 3 要素（被害・頻度・分からないときの調べ方）、1 通 1 件、番号を主語にしない、1 行目の書き分け（質問／`主がすること: なし`）、主の質問への答えが書き分けの対象外であること、例が 1 つある
  - readable.md の `casting` を含む行に「入っていれば」がある（`tests/public-private-split.bats` の capability-registry の検査と同じ形）。readable.md の節 3 に「主」と「聖域」の言い換え（`主（` と `聖域（` の形）がある
  - readable.md と communication-style.md に、`目的 → いま取り組んでいる場所` と `これを飲めるならAで進める` が無い
  - communication-style.md の 3 番目に、6 段の順、主に聞く理由の 3 つ（主の側にしか答えが無い・決まりで主の承認が要る・主の手でしかできない操作）、「理由が無ければ聞かない」がある。`casting` に触れるならその行に「入っていれば」がある
  - spec `owner-question-style` の参照先の各ファイルに、`目的 → いま取り組んでいる場所`・`決めてほしいこと・推奨・受け入れるリスク`・`「飲めるか」を 1 問だけ` が無く、`readable.md` か `communication-style` への参照があり、`readable.md` を指す箇所はどれも `~/.claude/output-styles/readable.md` の形である（`output-styles/readable.md` の直前が `~/.claude/` でない箇所が無い）
  - `plugins/` と `rules/` に `主がすること: このチャンネルで`・`主がすること: PR #`・`主がすること: 親のタブで`・`主がすること: 子のタブで`・`主がすること: <どの画面` が無い（`changes/` を除く）。develop `SKILL.md` に「`主がすること:` の規定」の言い方が無い
  - テスト名は ASCII のみにする

  触る範囲: tests/owner-question-style.bats（新規）
- [ ] 1.2 文言を固定している既存の bats を、新しい文言で同じことを確かめる形に直す
  - `epic-dispatch.bats`: 1 行目の決まりのテストを、正本の書き分けの参照・`主がすること: なし`・待ちに入る通知が直前の問いを繰り返すこと・親のタブと子のタブの答え方の行を確かめる形にする。手順 8 の旧 5 段の語の検査は、正本の参照を確かめる形にする。`notify-closed` の `failed` の報告の行（3954 行付近）も合わせる
  - `develop-channel-mode.bats`: channel の主への発言の 3 つの 1 行目の検査を、正本の書き分けの参照・`主がすること: なし`・答え方の行（このチャンネル／PR #<N> とフル URL）・チャンネル以外の画面を書かないことの検査にする
  - `develop-handover.bats`: 依頼の出し直しの全文の検査を、正本の型とリンクの全文を書くことの検査にする
  - `always-on-injection-scope.bats`: communication-style.md の目印 `これを飲めるならAで進める` を新しい文の目印に替える。`読み手の側にしかない情報` と `他の資料を見に行かないと判断できない書き方はしない` は残す前提で、目印も残す

  触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2995-3014（主がすることを 1 行目に書くテスト）、plugins/dev-workflow/tests/epic-dispatch.bats:3189-3206（手順 8 の説明の順。旧 5 段の検査は 3203）、plugins/dev-workflow/tests/epic-dispatch.bats:3950-3956（notify-closed の failed の報告の行は 3954）、plugins/dev-workflow/tests/develop-channel-mode.bats:128-137（channel statements のテスト）、plugins/dev-workflow/tests/develop-handover.bats:127-131（resend のテスト）、tests/always-on-injection-scope.bats:30-40（markers の communication-style の行）
- [ ] 1.3 1.1 と 1.2 の bats を回し、落ちることを確かめる

## 2. 正本と短い版

- [ ] 2.1 `output-styles/readable.md` の節 3 を、spec `owner-question-style` の要件どおりに書き直す
  - 見出しを書き直す（「背景から書いて」をやめる）
  - 旧 5 段・「結論はA…」の段落を消す
  - 6 段・3 つの理由・リスクの 3 要素・ほかの決まり・1 行目の書き分け（主の質問への答えは対象外と 1 文）・返信前チェックへの条件つきの一言（「観点の配役（`casting:casting`）が入っていれば、判定の詳細と主に上げる前の相談の手順はその返信前チェックに従う。入っていなければ 3 つの理由だけで判定する」）を置く
  - 例は issue #1176 の例を、6 段がそれぞれ 1 文で見える短い形（目安 600〜700 バイト）に書き直して置く。リスクの段は被害・頻度と見込みかの別・戻せるかを残す
  - 「主」と「聖域」に初出で一言の言い換えを添える
  - 配る候補の 6 ファイルの制約を守る（固有名・オーナーの環境のパスを書かない。例も同じ）
  - 節 4「結論から書く」が質問を先に置く型と食い違わないよう、1 文で関係を書く
  - frontmatter の description の「判断依頼は背景から」を新しい型の言い方に直す
  - 末尾の「短い版」の段落は残す

  触る範囲: output-styles/readable.md:1-5（frontmatter）、output-styles/readable.md:39-61（節 3 と節 4）
- [ ] 2.2 `rules/communication-style.md` の 3 番目を正本の要点で書き直す（6 段の順、主に聞く理由の 3 つと理由が無ければ聞かない、リスクは被害と頻度、1 通 1 件、1 行目の書き分け、例と詳細は正本）。`読み手の側にしかない情報` と `他の資料を見に行かないと判断できない書き方はしない` の文は残す。1 文を短くして増分を抑える。プラグインに触れるなら「入っていれば」の条件つきにする。正本は既存どおり `~/.claude/output-styles/readable.md` で指す

  触る範囲: rules/communication-style.md:10
- [ ] 2.3 `rules/README.md` の communication-style の行の説明（「判断依頼は背景から推奨まで」）を新しい型の言い方に直す（issue の参照先一覧の外だが、本体の了承済み）

  触る範囲: rules/README.md:38

## 3. 参照先を正本の参照に置き換える

- [ ] 3.1 develop `SKILL.md` の保留の引き継ぎの節
  - 依頼の出し直しの「依頼の全文（決めてほしいこと・推奨・受け入れるリスク・リンク）」を、「正本の型の全文とリンク」に置き換える
  - 主への案内と channel の主への案内の文を、依頼の答え方の行に書く中身として位置づける
  - 新しいセッションでの再開の手順 3 の「1 行目は `主がすること: このチャンネルで <何を返す>`」を、1 行目は質問・最後の答え方の行にこのチャンネルで返すことを書く形（channel の主への発言の参照）に置き換える

  触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:305（依頼の出し直し）、plugins/dev-workflow/skills/develop/SKILL.md:329-331（主への案内・channel の主への案内）、plugins/dev-workflow/skills/develop/SKILL.md:341（新しいセッションでの再開の手順 3）
- [ ] 3.2 develop `SKILL.md` の channel の節
  - channel の聞き方の「質問の文面は `rules/communication-style.md` の判断の求め方に従う」を、正本の参照（`~/.claude/output-styles/readable.md` の節 3）にそろえる
  - channel の主への発言の 1 行目の 3 つの形を、正本の書き分けの参照に置き換える。答え方の行に書くこと（このチャンネルで何を返すか／PR #<N> に何を書くかと PR のフル URL）とチャンネル以外の画面を書かないことだけを残す

  触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:421-427（channel の聞き方）、plugins/dev-workflow/skills/develop/SKILL.md:449-459（channel の主への発言）
- [ ] 3.3 develop `SKILL.md` の Orca 経路の導入部・手順 2・手順 8
  - 導入部の 1 行目の決まりを正本の書き分けの参照（`~/.claude/output-styles/readable.md` の節 3）に置き換える。導入部の名前を「`主がすること:` の規定」と呼ばない言い方（例: 「上の 1 行目と最後の行の規定」）にする
  - 手順 2〜6 の「主に出す発言の 1 行目は上の `主がすること:` の規定に従う」（手順 2 の後回しの子の報告と待ちに入る通知、手順 3〜6 の各 1 か所）を、新しい導入部の規定の参照に置き換える
  - サブエージェント方式の別のリポジトリの子の報告の「1 行目は `主がすること:` の規定に従う」を、正本の書き分けの直接の参照に置き換える（Orca 経路の導入部の対象ではないため）
  - 手順 2 の「待ちに入る通知の 1 行目にもその報告の `主がすること:` を繰り返す」を、直前の問いの質問と答え方を繰り返す形にする
  - 手順 8 は、報告の順のかっこ書き（旧 5 段）を正本の参照に置き換える。親経由のリスク許容の 1 行目の決まり、子のタブの連絡の 1 行目の決まり、`reply` の `failed` の 1 行目の決まりを、答え方の行の決まりに置き換える
  - 手順 8 の「`止まった理由`・`推奨` を同じ項目名のまま含め」は後続の change に残して触らない

  触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:491（Orca 経路の導入部）、plugins/dev-workflow/skills/develop/SKILL.md:494（手順 2。該当は 2 か所）、plugins/dev-workflow/skills/develop/SKILL.md:495-498（手順 3〜6）、plugins/dev-workflow/skills/develop/SKILL.md:500（手順 8）、plugins/dev-workflow/skills/develop/SKILL.md:534（サブエージェント方式の別のリポジトリの子）
- [ ] 3.4 pr-review-gate `stages/hold.md`
  - 手順 6 の 3 で、主への確認依頼の文面は正本の型に従うと一言足す
  - 切り出しの確認の return の 4 点は記録の項目として残し、主に出す質問は正本の型で書くと添える
  - 「主に承認を求めてよい4分類」の節に、各分類が正本の主に聞く理由の 3 つのどれに当たるかを書く（design.md の対応表）
  - 「やらないこと」の「推奨を出し、残リスクの許容だけを問う」を正本の参照に置き換える

  触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:61（手順 6 の 3）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:79-92（主に承認を求めてよい4分類・やらないこと）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:104（切り出しの確認）
- [ ] 3.5 pr-review-gate `stages/pass.md` の動作確認の依頼は、3 点セットを PR の記録の項目として残す。主に出す依頼の文面は正本の型で書き、主に聞く理由は「主の手でしかできない操作」、手順は答え方に入ると添える

  触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:32-39（自力検証が不能なときの 3 点セット）
- [ ] 3.6 `references/ci-watch.md` のオーナーにマージを頼む 2 か所（見送りラベルがあるとき・自動マージの workflow が無いとき）に、頼む文面は正本の型（主に聞く理由は人が押すと決まっているマージ）と添える。停止の記録の例（`推奨:` などの 5 項目）は後続の change に残して触らない

  触る範囲: plugins/dev-workflow/references/ci-watch.md:78-85（見送りラベルがあるとき）、plugins/dev-workflow/references/ci-watch.md:87（自動マージの workflow が無いとき）
- [ ] 3.7 one-off 系の「主に『飲めるか』を 1 問だけ聞く」を、「残りの却下理由を書き、主に 1 問だけ聞く（文面は正本の型）」に置き換える

  触る範囲: rules/one-off-no-script.md:5、plugins/dev-workflow/references/one-off-operations.md:14
- [ ] 3.8 casting
  - `SKILL.md` の返信前チェックの節に、主に上げると決まった論点は正本の主に聞く理由の 3 つのどれかに当たること（担い手が主の観点と、手順 4 の判断基準の範囲外・policy 不在・読み取り不能→主の側にしか答えが無い／聖域→決まり／権限の借用→主の手でしかできない操作）と、文面は正本の型で書くことを足す
  - `rules/perspective-casting.md` に、主に上げる文面は communication-style の 3 番目の型（正本は `~/.claude/output-styles/readable.md` の節 3）で書くと一言足す（目印の語句は変えない）

  触る範囲: plugins/casting/skills/casting/SKILL.md:56-76（返信前チェックの5手順と論点が来たときの判定）、rules/perspective-casting.md:3-13

## 4. 予算・記録・検証

- [ ] 4.1 1.1・1.2 の bats と、`plugins/dev-workflow/tests/` と `tests/` の全 bats を回して通す。`tests/public-private-split.bats`（配る候補の 6 ファイルの検索語と条件つきの書き方）と `tests/always-on-injection-scope.bats` が通ることを個別に確かめる
- [ ] 4.2 予算ファイルを動かさずに、常時注入を実測する（例は 2.1 の短い形のまま）。`tests/injection-budget.bats` が通れば、予算ファイルは動かさずに次へ進む。超えるときだけ、`tests/injection-budget.txt` を実測 + 約 5%（`recommended_budget` と同じ計算）に上げ、PR 本文に書く理由（何が増えたか・なぜ削らないか・短い例でも超えたこと）を控え、PR は主がマージすると本体に返す。上げた場合は下振れの側の判定（予算が実測の 1.1 倍以下）も通ることを確かめる

  触る範囲: tests/injection-budget.txt:1（超えるときだけ）
- [ ] 4.3 変更の記録を書く

  触る範囲: plugins/dev-workflow/changes/1176.md（新規）、plugins/casting/changes/1176.md（新規）
- [ ] 4.4 `openspec validate owner-question-canonical-style --type change --strict` を通す
