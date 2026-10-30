# Tasks

## 1. 切り出しのあとの段 A（受け入れ条件 1）

- [x] 1.1 hold.md の復帰表の切り出しの確認の行を「ほかに止める指摘も、1 周目の段 A に当たる未解決の指摘も無ければ手順3以降へ」にし、1 周目の段 A に当たる未解決の指摘が残っていれば `agent-review:failed` で W に戻すと足す。未処理の順 6 を先に見る並びは保つ。確認: 下の 1.3 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:109
- [x] 1.2 hold.md の「保留の解除」の「切り出して残りが無いとき」の語を残し、括弧で中身（ほかに止める指摘も、1 周目の段 A に当たる未解決の指摘も無いとき）を添える。1 周目の段 A に当たる未解決の指摘が残るときは failed（`次の段: 前提確認と重さ判定`）で返すと足す。あわせて読み先（1 周目かは前の段の Gate Result の `周回:`、段 A の有無は仕分けの PR コメントの「段 A・この PR で直す」の印、印が無ければ段 A は無いものとして判定をやり直さない）と、failed の欄（`stages/triage.md` の「failed のとき」、残りが段 A だけなら原因分類は「段 A だけ（昇格なし）」、順 2〜4 も残れば手順 2-2 の表どおり）を書く。確認: 下の 1.3 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:160
- [x] 1.3 hold.md の保留の return に、1 周目の段 A に当たる指摘が混ざっていれば仕分けの PR コメントと仕分け欄に「段 A・この PR で直す」と印を付けると足す（1.2 が読む印を残すため）。確認: 下の 1.4 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:144
- [x] 1.4 hold.md の 3 か所の文を確かめる bats を足す。確認: `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が通り、1.1〜1.3 の文を外すと落ちる。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:721（段 A の @test 群の末尾）

## 2. 順 3 と段 A の混在（受け入れ条件 2）

- [x] 2.1 triage.md の順 3 の段落の文を「順 2・順 4 または段 A の指摘が同じ failed に含まれていれば」にする。確認: 下の 2.3 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:57
- [x] 2.2 triage.md の failed の `次の段:` の括弧を「順 2・4 または段 A が混ざる場合と、段 A だけで戻した場合を含む」にし、同じ箇条の第 2 文「順 3 と順 2・4 が同じ failed に混ざったとき」にも段 A を足す。確認: 下の 2.3 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:196
- [x] 2.3 triage.md の 2 か所の文を確かめる bats を足す。確認: `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が通り、2.1・2.2 の文を外すと落ちる。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:721（段 A の @test 群の末尾）

## 3. 変更の記録

- [x] 3.1 変更の記録を足す。確認: `plugins/dev-workflow/changes/1015.md` があり、変えた動きと変えていない動き（2 周目以降の段 A・順 6 の処理順・gate-runner.md）を書いている。触る範囲: plugins/dev-workflow/changes/1015.md（新規）

## Workflow follow-up

- 着手時と push 前に origin/main と開いた PR（#1436・#1456・#1286・#1410）を確かめ、hold.md・triage.md の対象の文が移っていれば移動先で直す
- archive で spec に反映する
