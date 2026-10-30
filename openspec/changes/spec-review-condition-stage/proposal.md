# Proposal

## Why

仕様レビュー（R1）の BLOCKER の判定にも、2 周目以降の直し方の判定にも、「指摘の条件がいつ成り立つか」を決める段が無い。そのため運用上起きない場面への指摘が BLOCKER のまま残り、直し方の判定が「どの直し方か」だけを問うて「選び直しが要る」になり、主に上がる。実例は flatmate #702 で、「同じ枠を別アカウントで使い回したあとの使用量の帰属」という指摘が主まで上がったが、主の運用では新しいアカウントは新しい枠を作るので、この場面は起きない。PR レビューの振り分け（`skills/pr-review-gate/stages/triage.md` の段 B）には同じ段が既にある。

## What Changes

- `references/roles/spec-reviewer.md` に、BLOCKER を残す前に指摘の条件がいつ成り立つかを決める段を足す。段 B と同じ分け方の表と、根拠の規則（エピックと記録先の本文・受け入れ条件・コード・本文の節 `## 条件の答え`）を R1 用に写す。R1 は読み取り専用のままで、捨てた指摘は結果コメントに、後で成り立つ指摘は NOTE に、決められない条件は BLOCKER に添えた問いとして返す
- `## 条件の答え` の行を、本体が R1 の依頼文に入れる
- `references/fix-check.md` に、仕様レビューの残った指摘の条件を直し方の判定の前に確かめる節を足す。成り立つ予定が無い指摘は判定に回さず捨てる。SKILL.md の 1 ループの (2) には短く書いてこの節を指す
- flatmate #702 の指摘を例に載せる
- unmanned で条件の問いを主に聞くときの引き継ぎの場面を `references/handover.md` に足し、`待ち理由` の値に `条件の問い` を足す
- PR のレビュー側（G の `needs-fix-check`）は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-spec-review`: R1 の BLOCKER の判定に条件の段を足す。「主に聞くのは 2 つだけ」の数え方を、方針の問いの数だと明記する
- `dev-workflow-develop`: 直し方の判定の前に条件を確かめる段を足す。「主に聞くのは 2 つだけ」の数え方を同じく明記する。引き継ぎの場面に仕様レビューの条件の問いを足す

## Impact

- 文書: `plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md`、`plugins/dev-workflow/skills/develop/references/fix-check.md`、`plugins/dev-workflow/skills/develop/references/handover.md`、`plugins/dev-workflow/skills/develop/SKILL.md`（(2) の該当行と、引き継ぎの場面を数える 1 行）
- 予算: SKILL.md は `tests/develop-startup-budget.txt` の予算ちょうどなので、増えた分だけ予算を動かし、理由を PR に書く
- テスト: `plugins/dev-workflow/tests/spec-decision-and-review.bats`、`plugins/dev-workflow/tests/develop-handover.bats`
- 記録: `plugins/dev-workflow/changes/1121.md`
- `triage.md`・`reviewer-brief.md`・`agents/decider.md` は変えない。新しいスクリプトは足さない
