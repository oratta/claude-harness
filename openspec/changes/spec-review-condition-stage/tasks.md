# Tasks

## 1. R1 の条件の段

- [ ] 1.1 `tests/spec-decision-and-review.bats` に、「条件がいつ成り立つか」の語・5 行の表・根拠の規則・`条件の問い:`・`捨てた指摘:`・flatmate #702 の例・`stages/triage.md` の段 B への参照・文書そのものの欠陥の扱いを検査するテストを足し、落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/spec-decision-and-review.bats:115-130
- [ ] 1.2 `spec-reviewer.md` に節を足し、「レビュアーへの入力」に `## 条件の答え` の行を、「出力書式」に BLOCKER の条件の書き方を、「結果を記録先に記録する」に `捨てた指摘:` の行を、「判定基準」と「往復の上限」に段と当て直しへの参照を足し、「往復の上限」の主に聞く 2 つの文に「この 2 つは方針の問いの数で、条件の問いは数えない」の 1 文を足す。1.1 のテストが通ることで確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md:36-41、plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md:52-65、plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md:71-78、plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md:84-87

## 2. 直し方の判定の前の段

- [ ] 2.1 同じ bats に、fix-check.md の節「残った指摘の条件を確かめる」の見出しが 1 か所にあること・通す 2 つの時点・当て直しを周に数えないこと・「判定に回さず捨てる」・`needs-fix-check` に当てないこと・「主に聞くのは 2 つだけ」が方針の問いの数と書かれていること・NOTE の後で成り立つ指摘の 1 文・unmanned の引き継ぎと再開で答えを足して当て直すこと、SKILL.md の (2) が節を指すことと `## 条件の答え` を依頼文に入れることを検査するテストを足し、落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/spec-decision-and-review.bats:115-130
- [ ] 2.2 `fix-check.md` の冒頭の読むときの文を直し、節「残った指摘の条件を確かめる」（「NOTE の後で成り立つ指摘は本体が行き先を決める」要件の 1 文を含む）を足し、既存の節の規則に 1 文足す。2.1 のテストのうち fix-check.md の分が通ることで確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/fix-check.md:3-9
- [ ] 2.3 `SKILL.md` の (2) の該当行と、引き継ぎの場面を数える 1 行（「引き継ぎを書く 3 つの場面」）だけを直し、`tests/develop-startup-budget.txt` の SKILL.md の値を実測に合わせて動かす。2.1 のテストと `scripts/test.sh develop-skill`・`bats tests/develop-startup-budget.bats` が通ることで確かめる。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:113-120、plugins/dev-workflow/skills/develop/SKILL.md:274、tests/develop-startup-budget.txt:1
- [ ] 2.4 `plugins/dev-workflow/tests/develop-handover.bats` の場面のテストに「仕様レビューの条件の問い」と `待ち理由` の値 `条件の問い` の検査を足して落ちることを確かめ、`references/handover.md` の読むときの文・場面の文・投稿の順序・`待ち理由` の行を直して通す。`scripts/test.sh develop-handover` が exit 0 であることで確かめる。触る範囲: plugins/dev-workflow/tests/develop-handover.bats:39-45、plugins/dev-workflow/skills/develop/references/handover.md:3、plugins/dev-workflow/skills/develop/references/handover.md:7-9、plugins/dev-workflow/skills/develop/references/handover.md:19

## 3. 記録と全体の確認

- [ ] 3.1 `plugins/dev-workflow/changes/1121.md` を書く。何を変えたか・戻し方・SKILL.md の予算を動かした理由・PR レビュー側に当てない理由を書き、ファイルがあることで確かめる。触る範囲: plugins/dev-workflow/changes/1121.md（新規）
- [ ] 3.2 `scripts/test.sh spec-decision-and-review`・`scripts/test.sh develop-roles`・`scripts/test.sh develop-skill`・`scripts/test.sh develop-handover`・`openspec validate spec-review-condition-stage --type change --strict` を流し、すべて exit 0 であることを確かめる。触る範囲: なし（確認のみ）

## Workflow follow-up

- archive と PR の作成は (3b) で行う
