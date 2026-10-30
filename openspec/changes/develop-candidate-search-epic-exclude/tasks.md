## 1. テスト

- [x] 1.1 `develop-skill.bats` に、SKILL.md の候補探しの項が `--exclude` へのエピック番号・`(15 件で打ち切り。ほかにも一致あり)`・`--epic <エピック番号> --children-only`・パスごとに 1 回を超えないこと・`triage.md` への参照を持つことを検査するテストを足す（pr-review-gate-skill.bats:788-795 の書き方に揃える）。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:932-945

## 2. 文言の直し

- [x] 2.1 SKILL.md の `（打ち切りの再実行だけ例外、下の 2 つ目）` の「下の 2 つ目」は何も指していない（項が分かれていない）ので、指す内容を書いた文に直す（例: 「（出力が打ち切られたパスの再実行だけ例外。この項の後半）」ではなく、例外の中身を括弧内で言う）。spec と文を揃える直しになるなら、SKILL.md と spec を同じ commit で直す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:71、openspec/specs/dev-workflow-develop/spec.md:2026

## 3. 検証・archive

- [x] 3.1 `bats plugins/dev-workflow/tests/develop-skill.bats` と `tests/injection-budget.bats` を通す。触る範囲: なし（実行のみ）
- [ ] 3.2 archive は `openspec archive develop-candidate-search-epic-exclude --skip-specs` で行う（spec 本文は commit 47617a69 で変更済みなので、delta の適用で二重に当てない）
