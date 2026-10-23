## 1. 子の停止の手順書と検査

- [x] 1.1 手順書の検査に assert を足し、直す前の手順書で落ちることを確かめる（`skipped <N> no-workspace` と `skipped <N> not-linked` が同じ行にある／`marked` なら何もしない。`skipped` で始まる、の肯定／`marked` か `skipped` なら何もしない、の否定に `|| return 1`）。確認: `bats -f "an epic child records its stop before marking it" plugins/dev-workflow/tests/epic-dispatch.bats` が直す前は exit 1　触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3444-3462（test「skill: an epic child records its stop before marking it, in both waiting orders」）
- [x] 1.2 `mark stopped` の出力が `marked` なら何もしない、`skipped` で始まるか `failed` なら主への質問に「親に止まったことが伝わっていない」と 1 行添える、に直す。確認: 1.1 の bats が exit 0、`tests/bats-assertion-guard.bats` が exit 0　触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:13-13

## 2. 変更の記録

- [x] 2.1 変更の記録を書く。確認: `bats tests/plugin-release-convention.bats` が exit 0　触る範囲: plugins/dev-workflow/changes/1247.md（新規）
- [ ] 2.2 変更の記録の「openspec の CLI が無い環境で作業したため、change を通さず spec を直接直した」の項を、change `epic-child-stop-skipped-not-conveyed` を通して spec を直した形に書き直す。確認: `grep -n '直接直した' plugins/dev-workflow/changes/1247.md` が 0 件、`bats tests/plugin-release-convention.bats` が exit 0　触る範囲: plugins/dev-workflow/changes/1247.md:6-6

## Workflow follow-up

- archive で `openspec/specs/dev-workflow-develop/spec.md` の要件「エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する」に差分を入れる（`openspec archive epic-child-stop-skipped-not-conveyed --yes`）
