## Why

frontmatter 全体を半角 2 つ分字下げした skill ファイルは、書式検査を通り、`description` の集計が 0 バイトになる（issue #282、#258 の追補）。字下げした frontmatter は YAML ではトップレベルの `description` と読まれ、Claude Code 本体も skill として登録する。常時注入される固定分が予算に見えないまま増える経路になる。

## What Changes

- `check_frontmatter_shape_z` が `^  description:` の行を一律で違反にする
- 負例テストを足す（修正前に赤、修正後に緑）
- `injection-budget-gate` の「frontmatter は限定した書式だけを受理する」に条件とシナリオを足す

## Impact

`tests/injection-budget.bats`・`openspec/specs/injection-budget-gate/spec.md`。測定対象の既存ファイルに字下げした description は無く、予算値は変わらない。
