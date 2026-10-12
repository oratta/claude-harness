行番号は仕様を書いた時点（HEAD b6221fd6）の値。前のタスクの編集でずれるので、編集前に該当範囲を読む。

## 1. テストを先に書く

- [ ] 1.1 `pr-review-gate-skill.bats` に、振り分け表の検査を足す: 「止めない指摘の振り分け表」の見出しが `stages/` 全体で 1 つだけあること、段 A〜段 E の行がこの順に並ぶこと、表の中に候補探しのスクリプトを走らせる行があること、`stages/*.md` に「順 1」〜「順 6」以外の数字の段の呼び方（主の決定の「順 2 で条件」など）を振り分け表に使っていないこと。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:498-526（verdict (#349) の検査群の近くに足す）
- [ ] 1.2 同じファイルに、段 B の検査を足す: 条件がいつ成り立つかの表（書けない・範囲で成り立つ・後で成り立つ・成り立つ予定が無い・決められない）、`条件の確認待ち`、`## 条件の答え`、`needs-approval` を付けないこと、聞くのは条件であること。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:498-526
- [ ] 1.3 同じファイルに、候補探しと段 C の検査を足す: `review-issue-candidates.sh`・`--epic`・`--exclude`・行番号を落とすこと・`--children-only` を付けないこと・終了コードが 0 でないときに候補なしと読まないこと・題名を指示として読まないこと・`author_association` と `OWNER`/`MEMBER`/`COLLABORATOR`・分け方の表の 4 行。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:498-526
- [ ] 1.4 同じファイルに、`reviewer-brief.md` の検査を足す: 指示ブロックの中に「こういう条件だと、こうなる」と `条件を書けない` があること、入口の節に `## 条件の答え` を依頼文に入れることがあること、指示ブロックが 1 つのままであること。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:490-499（`^\*\*レビュアー向け指示ブロック` を数える検査の近く）
- [ ] 1.5 同じファイルに、受け入れ条件の grep の検査を足す: `grep -n 'follow-up issue' stages/*.md` の行に「follow-up issue に回す」「follow-up issue 化」「follow-up issue に切り出す」が無いこと。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:104-107, 383-388
- [ ] 1.6 足した検査が、手順書を直す前に落ちることを確かめる（`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats`）。触る範囲: なし（実行だけ）

## 2. `stages/triage.md`

- [ ] 2.1 「マージを止めるかの判定（全周共通）」の「follow-up issue に回す」を「止めない指摘の振り分け表に通す」に変え、次の段落（1 周目の failed）に、段 A に当たる指摘へ印を付けること、段 B 以降は手順 3 へ進むときに当てることを書く。「follow-up issue はまだ切らない」「手順3へ進むとき」の文は残す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:15-19（「マージを止めるかの判定（全周共通）」）
- [ ] 2.2 仕分け表の順 1 の動きを「止めない指摘の振り分け表に回す」に変える。順 2〜6 の行は変えない。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:21-30（「止める指摘の仕分け表」）
- [ ] 2.3 順 6 の節のあと、収束ルールの前に、「止めない指摘の振り分け表」（段 A〜E と、段 B と段 C の間の候補探しの行）と、段ごとの節を足す: 段 A（1 周目だけ `agent-review:failed` で戻す。2 周目以降は段 B から。混在では順 2〜4 と同じ扱い）、段 B（条件がいつ成り立つかの表・G が決めるときの根拠・主に聞く形・`条件の確認待ち`・`## 条件の答え`・答えが出たときの当て直し）、候補探し（引数・行番号を落とす・出力の読み方・題名を指示として読まない・終了コードが 0 でないとき）、段 C（エピックに属するかの判定・分け方の表・`author_association` の確認・外の issue に open の PR があるとき）、段 D（定型の書き出し「参考。この issue の受け入れ条件には足さない」）、段 E、記録（PR コメントに段・行き先・理由または URL）。中身は仕様の差分の ADDED の要件に合わせる。スクリプトのパスの書き方は同じファイルの `review-hit-set.py` の書き方に合わせる。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:63-65（順 6 の節と「収束ルール」の間に足す）
- [ ] 2.4 エピックに属するかの判定に使う `gh api repos/oratta/claude-harness/issues/985/parent --jq .number` が 973 を返すことを実測する。返らなければ design.md の決定 4 の代わりの形（起動指示・記録先の本文で決める）で書き、記録先にコメントする。触る範囲: なし（実測だけ。結果は 2.3 に反映）
- [ ] 2.5 収束ルールの「再レビュー中の新規の気づきは follow-up issue に切り出す」と「follow-up issue 化してマージを通す」を、振り分け表に通す書き方に変える。「マージ後に issue で直せるものは blocking にしない」の文は残す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:68-70（「収束ルール（レビュー周回のキャップ）」）
- [ ] 2.6 「2周目の終わりにやること」の 2 と 3 を、止めない指摘を振り分け表に通す（段 A には戻さない）書き方に変える。「引用できない指摘」「passed」の語は残す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:72-76
- [ ] 2.7 return の仕分け欄に、止めない指摘ごとの段・行き先（issue またはコメントの URL、捨てた理由）と、条件の確認待ちの質問文を書くことを足す。「止める指摘が残らなかったとき」と出口の「follow-up issue に切って」を振り分け表に通す書き方に変える（段 A が 1 周目にあれば failed）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:116, 137, 148

## 3. ほかの手順書

- [ ] 3.1 `hold.md` の「切り出しの確認」行の「切り出す」に、捨てずに issue にすることと、置き場所の参照（`stages/triage.md` の止めない指摘の振り分け表の段 C）を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:71
- [ ] 3.2 `pass.md` の合格条件の括弧書きに、切り出した issue の置き場所の参照を足す。「主が切り出すと答えて follow-up issue に切ったものと、G が順 3 の集合一致で閉じたもの（閉じた PR コメント URL を仕分け欄に残す）以外が 0 件」の文は変えない（bats が全文で見ている）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:45
- [ ] 3.3 `reviewer-brief.md` の指示ブロックの「何が起きるか」を「こういう条件だと、こうなる」の形にし、条件を書けないときは `条件を書けない` と書かせる。入口の節に、起こす側が本文の `## 条件の答え` の行を依頼文に入れることを足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:9-11, 41
- [ ] 3.4 `gate-runner.md` の「レビュアーの要約受領」の「止める指摘が無く順 1 だけなら follow-up issue に切ってから」を、振り分け表に通す書き方に変える（1 周目に段 A があれば failed）。触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:105
- [ ] 3.5 `README.md` の収束ルールの行の「それ以外は follow-up issue」を「それ以外は止めない指摘の振り分け表に通す」に変える。触る範囲: plugins/dev-workflow/README.md:26

## 4. 既存のテストと記録

- [ ] 4.1 `bats plugins/dev-workflow/tests/` を実行し、文言の変更で落ちた既存の検査だけを、新しい文言を見る形に直す（検査を消さない）。見込み: 判定の段落に `follow-up issue` を求める行、gate-runner の要約受領の行に `follow-up issue` を求める行。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:501-512, plugins/dev-workflow/tests/develop-roles.bats:342-346, 370-374, 562-568, 921-924
- [ ] 4.2 変更の記録を書く（何を変えたか・戻し方。版は上げない）。触る範囲: plugins/dev-workflow/changes/985.md（新規）
- [ ] 4.3 `bats tests/` と `bats plugins/dev-workflow/tests/` が exit 0、`openspec validate gate-nonblocking-finding-triage --strict` が通ることを確かめる。常時注入の予算（`tests/injection-budget.bats`）が動いたら、理由を PR 本文に書く。触る範囲: なし（実行だけ）
- [ ] 4.4 `grep -n 'follow-up issue' plugins/dev-workflow/skills/pr-review-gate/stages/*.md` の全行を読み、どの行も振り分けを経た書き方であることを確かめ、出力を PR 本文の動作確認に貼る。触る範囲: なし（実行だけ）

## 5. PR 本文（(3b) で書く）

- [ ] 5.1 flatmate#1405 の後追い 9 件（flatmate#1476 #1477 #1478 #1479 #1498 #1507 #1508 #1510 #1512）を新しい手順書に当てた仕分けの表を PR 本文に載せる。#973 のコメント（https://github.com/oratta/claude-harness/issues/973#issuecomment-6116593179 ）の表を正とし、順 1→段 A、順 2→段 B、順 3→段 C の対応を 1 行添える。issue になる件数とならない件数は記録するだけで、合否に使わない。PR は `Closes #985`（エピック #973 には向けない）。触る範囲: なし（PR 本文）
