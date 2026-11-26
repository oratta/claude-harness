## 1. SKILL.md

- [x] 1.1 手順 3 の `kept <N> <理由>` の扱いを、確かめ方と消したとき・残したときの 1 行の書式に変える。「オーナーの判断に残し、手で消し直さない」を外す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:431（Orca 経路の手順 3）
- [x] 1.2 手順 2 の片付け待ちの子の定義に、本体が確かめて消した子を除くことを足す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:430（手順 2）
- [x] 1.3 手順 4・7 の「3 と同じに扱う」が新しい扱いと整合することを確かめる（文言は直さない見込み）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:432、435

## 2. テスト

- [x] 2.1 「skill: Orca route watches for done marks and reaps marked children」の `手で消し直さない` の行を新しい文言に直し、確かめ方と 2 つの書式を grep で確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2321-2330

## 3. 記録

- [x] 3.1 変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1095.md（新規）
