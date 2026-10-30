## 1. 手順の文言

- [ ] 1.1 `stages/triage.md` の段 C の表の直後（`3 列目が other の候補…` の段落の前）に、子の行で足す前に作業中かを確かめる段落を足す。判定の 2 材料と gh の 2 回の呼び出し、作業中なら足さず新しい子 issue（同じエピックの子・作業中の子の番号を本文に書く）、主に聞かない、スクリプトは作らない、を書く。親の取得の段落と表の行は書き換えない。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:102-112（段 C の表の直後）
- [ ] 1.2 同ファイルの「主が切り出すと答えた止める指摘の置き場所」の段落に、既存 issue に足すときは段 C の確認を通る旨を 1 句足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:120

## 2. 仕様と検査

- [ ] 2.1 `tests/pr-review-gate-skill.bats` に、段 C に作業中の確認と新しい子 issue への切り出しが書かれていることの検査を足す。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats（末尾に追加）
- [ ] 2.2 変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1498.md（新規）
- [ ] 2.3 `bats tests/` と `openspec validate stage-c-child-in-progress-check --type change --strict` を通す
