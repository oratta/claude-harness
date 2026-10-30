# Tasks

## 1. 切り出しのあとの段 A（受け入れ条件 1）

- [ ] 1.1 hold.md の復帰表の切り出しの確認の行を「ほかに止める指摘も、1 周目の段 A に当たる未解決の指摘も無ければ手順3以降へ」にし、1 周目の段 A に当たる未解決の指摘が残っていれば `agent-review:failed` で W に戻すと足す。未処理の順 6 を先に見る並びは保つ。確認: 下の 1.3 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:109
- [ ] 1.2 hold.md の「保留の解除」の「切り出して残りが無いとき」を同じ条件の語に書き換え、1 周目の段 A に当たる未解決の指摘が残るときは failed（`次の段: 前提確認と重さ判定`）で返すと足す。確認: 下の 1.3 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:160
- [ ] 1.3 hold.md の 2 か所の文を確かめる bats を足す。確認: `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が通り、1.1・1.2 の文を外すと落ちる。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:721（段 A の @test 群の末尾）

## 2. 順 3 と段 A の混在（受け入れ条件 2）

- [ ] 2.1 triage.md の順 3 の段落の文を「順 2・順 4 または段 A の指摘が同じ failed に含まれていれば」にする。確認: 下の 2.3 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:57
- [ ] 2.2 triage.md の failed の `次の段:` の括弧を「順 2・4 または段 A が混ざる場合と、段 A だけで戻した場合を含む」にし、同じ箇条の第 2 文「順 3 と順 2・4 が同じ failed に混ざったとき」にも段 A を足す。確認: 下の 2.3 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:196
- [ ] 2.3 triage.md の 2 か所の文を確かめる bats を足す。確認: `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が通り、2.1・2.2 の文を外すと落ちる。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:721（段 A の @test 群の末尾）

## 3. 変更の記録

- [ ] 3.1 変更の記録を足す。確認: `plugins/dev-workflow/changes/1015.md` があり、変えた動きと変えていない動き（2 周目以降の段 A・順 6 の処理順・gate-runner.md）を書いている。触る範囲: plugins/dev-workflow/changes/1015.md（新規）

## Workflow follow-up

- 着手時と push 前に origin/main と開いた PR（#1436・#1456・#1286・#1410）を確かめ、hold.md・triage.md の対象の文が移っていれば移動先で直す
- archive で spec に反映する
