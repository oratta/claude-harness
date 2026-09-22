## 1. テストを先に書く（TDD）

- [ ] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に、仕分け表の 6 順（止める判定・受け入れ条件の中・一覧の一致・今直す 3 条件・主に聞く・決める役の裁定）が SKILL.md 手順 2-1 の「マージを止めるかの判定（全周共通）」より後に、この順番で現れることの検査を足す
- [ ] 1.2 同 bats に、`grep -c '一覧の一致\|集合が.*一致'` が SKILL.md で 1 以上、`grep -n '30 行'` のヒットが手順 2-0 と順 4（直し方の上限・累計の上限）にあり、30 以外の行数の閾値が順 4 に無いこと、レビュアー向け指示ブロックの「新規の指摘を出さない」文に例外 3 種の但し書きがあること、順 6 の決める役の裁定が PR ごとに 1 回までと書かれていることの検査を足す
- [ ] 1.3 同 bats の既存検査を新しい文面に書き換える: 395 行目付近（`続けるか、範囲外として閉じるか` を要求）→ その文面が無く、順 5・6 を参照していること。415 行目付近と 515〜518 行目付近（「決める役.*関与しない」）→ 決める役が順 6 の方式だけを裁定し、止めるかの判定は G が行うこと。426〜428 行目付近（手順 6 の「2周目キャップ」行の「続ける」「範囲外として閉じる」）→「切り出しの確認」行の「切り出す」「この PR で直す」。530〜533 行目付近 → 「主が切り出すと答えて follow-up issue に切ったもの以外が 0 件」（SKILL.md と spec の両方。spec 側は `openspec/changes/pr-review-gate-triage-table/` があればその delta spec を、無ければ archive 後の `openspec/specs/dev-workflow-pr-review-gate/spec.md` を読むようにし、archive の前後どちらでも通るようにする）
- [ ] 1.4 `plugins/dev-workflow/tests/develop-roles.bats` に、gate-runner.md の保留欄に順 5 の 4 点（何が起きるか・見積もり・固定費・推奨）があること、Status に `needs-decider` があること、仕分け欄が全周で当てた順を書くこと、`grep -n '続けるか、範囲外として閉じるか'` が gate-runner.md で 0 件であること、worker.md で `grep -c '検索コマンド'` が 1 以上で順 4 の記録（「受け入れ条件の外・その場で直した・直し方 N 行」）があることの検査を足す。既存の「2周目キャップ」「範囲外として閉じる」を要求する検査は新しい文面に書き換える
- [ ] 1.5 追加・書き換えた検査が現行ファイルで落ちることを確認する（`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats`）

## 2. SKILL.md を書き換える

- [ ] 2.1 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` 手順 2-1「マージを止めるかの判定（全周共通）」の直後に、仕分け表（順 1〜6）と、順 3（一覧の一致で閉じる。検索コマンドと全ヒットの表、G の集合照合、差し戻し 1 回、照合はレビューの周に数えない）・順 4（今直す 3 条件。手順 2-0 の 30 行を参照）・順 5（4 点・その周で聞く・`needs-approval`）・順 6（`needs-decider`・方式の裁定・PR ごとに 1 回まで）の中身を置く。2 周目の終わりには順 2〜4 を使わないこと、同じ周に順 5 と順 2〜4 が混ざったら保留を先にすることも書く
- [ ] 2.2 手順 2-1 のレビュアー向け指示ブロックの「新規の指摘を出さない」に、例外 3 種は差分限定の周でも出してよい但し書きを足す。「止める指摘が残ったら、周によって変わるのは動き方だけ」の段落を仕分け表への参照に書き換える
- [ ] 2.3 収束ルール節の「2周目の終わりにやること」3.（1 択の質問）を順 5・6 への参照に置き換え、「決める役（`dev-workflow:decider`）はキャップの判定に関与しない」段落を「決める役は順 6 の方式だけを裁定し、止めるかの判定は G」に書き換える。収束ルールの 3 周目の開き方（主の回答または決める役の裁定のときだけ）と、再レビュー差分限定の例外（例外 3 種の新規指摘）を足す
- [ ] 2.4 手順 5 の合格条件の除外を「主が切り出すと答えて follow-up issue に切ったもの」にし、「2周目キャップ」行への参照を「切り出しの確認」行にする
- [ ] 2.5 手順 6 の見出しと保留表の「2周目キャップ」行を「切り出しの確認」行（回答: 切り出す／この PR で直す）に置き換える。「主に承認を求めてよい4分類」の表の 1 行目を、順 5 の「この欠陥を残して切り出すか」（推奨と見積もり付き）に更新する
- [ ] 2.6 `grep -rn '続けるか、範囲外として閉じるか\|範囲外として閉じ\|2周目キャップ' plugins/dev-workflow`（tests と CHANGELOG を除く）がヒット 0 件であることを確認する

## 3. G と W の指示書を揃える

- [ ] 3.1 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の `## Gate Result` に Status `needs-decider` を足し、仕分け欄を「指摘を受け取ったすべての周で、指摘ごとに当てた順（順 4 は記録の文面）と PR コメント URL」にし、`### 保留のとき` の 2 周目キャップ行を「切り出しの確認: 順 5 の 4 点」に置き換える。`needs-decider` のときに本体へ渡すもの（同じ型の指摘と前の周の指摘、裁定を返す先）を書く
- [ ] 3.2 同ファイルの `## 再開` の「W の修正後の再レビュー」の 3 周目の条件を主の回答または決める役の裁定に、「レビュアーの要約受領」の分岐を仕分け表への参照に、「保留の解除」を切り出しの確認への回答（切り出す／この PR で直す）に書き換え、決める役の裁定を受け取ったときの再開の行を足す
- [ ] 3.3 `plugins/dev-workflow/skills/develop/references/roles/worker.md` に、順 3 で W が PR コメントに投稿する表（検索コマンド、全ヒットごとの「直した／該当しない理由」）と、投稿してから push する順序を足す（書式の正本は SKILL.md 順 3 と書いて参照する）。(3a) の return に書くことに、順 4 で直したときの「受け入れ条件の外・その場で直した・直し方 N 行」の記録を足す

## 4. 検証と版

- [ ] 4.1 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats` が exit 0
- [ ] 4.2 issue #354 の受け入れ条件の grep（`続けるか、範囲外として閉じるか` が 0 件、`一覧の一致\|集合が.*一致` が SKILL.md で 1 以上、`検索コマンド` が worker.md で 1 以上、`30 行` の閾値）を実行し、結果を記録する
- [ ] 4.3 `origin/main` の `plugins/dev-workflow/.claude-plugin/plugin.json` の version を確認してから、`plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow の version を 1 つ上げ、`plugins/dev-workflow/CHANGELOG.md` に項目を足す
- [ ] 4.4 `bash scripts/test.sh` が exit 0（`tests/injection-budget.bats` を含む。常時注入の予算に触れていないことも確認する）
- [ ] 4.5 `openspec validate pr-review-gate-triage-table --strict` と `openspec validate --specs --strict` が exit 0

## 5. PR とゲート（(3b) 以降）

- [ ] 5.1 PR 本文に `Closes #354` を書く
- [ ] 5.2 この PR 自身のゲートで、指摘が届いたときに G が仕分け表のどの順に当てたかを PR コメントに記録する（`gh api repos/oratta/claude-harness/issues/<PR>/comments --jq '.[].body' | grep -c '仕分け'` が 1 以上）
