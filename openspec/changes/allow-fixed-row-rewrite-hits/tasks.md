# Tasks

## 1. 順 3 の契約・照合・回帰テストを揃える

- [ ] 1.1 triage の補助表の参照先を「直した」にも広げ、HEAD では補助表に載った修正後本文だけを 1 件分許す説明を加える。worker の記録手順も揃え、主表の修正前本文・補助表の見出しと列・既存の「該当しない」行の義務を保つ。検証: delta spec の順 3 と W の要件と突き合わせ、`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats` が exit 0。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:45-59、plugins/dev-workflow/skills/develop/references/roles/worker/implement.md:34-34
- [x] 1.2 補助表パーサーで「直した」への参照を許可し、HEAD 照合の allowed に補助表に載った「直した」の修正後本文を各 1 件だけ足す。混在組の required は現行式を保ち、二重計上しない。検証: 1.3 の成功・不一致・混在組のテストと既存の契約違反テストが pass。触る範囲: plugins/dev-workflow/scripts/review-hit-set.py:146-183（parse_rewritten）、plugins/dev-workflow/scripts/review-hit-set.py:206-235（second_stage）
- [x] 1.3 「直した」の修正後本文を補助表に載せて exit 0・unmatched 無しになるテスト、未記載で旧本文が残って exit 1・unmatched になるテストを明示する。未記載の新本文、記載した本文との不一致、同じ修正後本文の超過ヒット、両側を補助表に載せた混在組の exit 0 も追加する。旧 #377 の「直したへの参照は契約違反」を成功期待に更新し、#406 の複数違反テストは主表にない参照先を使う。重複・本文不変・違反蓄積・違反時の第 2 段抑止・見出しの案内・--head 無しの回帰を保つ。検証: `bats plugins/dev-workflow/tests/review-hit-set.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/review-hit-set.bats:137-310、plugins/dev-workflow/tests/review-hit-set.bats:338-370
- [x] 1.4 issue #549 の変更記録を書き、修正後も検索語を含む「直した」行を補助表で対応させられることと未記載の直し忘れは従来どおり検出することを記す。検証: 変更記録が存在し、version ファイルの差分が無い。触る範囲: plugins/dev-workflow/changes/549.md（新規）

## 2. 統合確認

- [ ] 2.1 `bats plugins/dev-workflow/tests/review-hit-set.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats` を実行して全件 pass（exit 0）を記録し、`openspec validate allow-fixed-row-rewrite-hits --type change --strict` と `git diff --check` も exit 0 になることを確認する。触る範囲: plugins/dev-workflow/tests/review-hit-set.bats:1-412、plugins/dev-workflow/tests/pr-review-gate-skill.bats:1-1966、plugins/dev-workflow/tests/develop-roles.bats:1-1138（いずれも実行・確認）

## Workflow follow-up

- R1 の APPROVE が issue #549 に記録されるまで実装へ進まない。
- 実装＋verify の return 後、coordinator が指示する finish 工程で change を archive し、main spec の 3 要件へ delta を反映する。触る範囲: openspec/specs/dev-workflow-pr-review-gate/spec.md:612-685、openspec/specs/dev-workflow-pr-review-gate/spec.md:751-769、openspec/specs/dev-workflow-pr-review-gate/spec.md:926-1006
