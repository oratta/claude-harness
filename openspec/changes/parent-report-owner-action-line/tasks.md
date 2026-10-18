## 1. SKILL.md

- [ ] 1.1 Orca 経路の導入段落のあとに、親の報告の 1 行目の規定（`主がすること:` の書式、対象の報告の一覧、子の完了報告との書き分け）を 1 段落で足す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:425-427（「回し方」の Orca 経路の導入段落と手順 1 の間）
- [ ] 1.2 手順 8 に、親経由のリスク許容の依頼は 1 行目に親のタブと「直後に別の発言を挟まない」を書くことを足す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:434（手順 8 の「それ以外は主に上げて本文で報告する」の文）
- [ ] 1.3 手順 4・5・6 の「ユーザーに報告」に 1.1 の参照を足す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:430-432

## 2. テスト

- [ ] 2.1 `run_section` の Orca 経路に `主がすること:` の規定があり、手順 8 の行に親のタブと「別の発言を挟まない」があることを検査する bats を足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2286-2296（子の完了報告のテストの直後）
- [ ] 2.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats tests/injection-budget.bats` が通ることを確かめる

## 3. 記録

- [ ] 3.1 変更の記録を plugins/dev-workflow/changes/1089.md に書く（plugins/dev-workflow/changes/1036.md を例にする）
