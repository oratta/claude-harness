# spec-review-coverage-criterion — 仕様レビュー R1 に「守備範囲の明記」の観点を足す

## Why

PR #268 では、frontmatter の書式検査（awk の近似パーサ）に対してレビューが 6 周続き、約 1.2 億トークンを使った（#281）。仕様に「何から守り、何は守らないか」が書かれていなかったため、制御文字・NUL・不正な引用符の指摘をゲート実行者が「守備範囲の外」と判定する根拠が無く、毎周レビュアーの深刻度ラベルをそのまま受け入れた。守備範囲の段落は 6 周目に事後で足された（`openspec/specs/injection-budget-gate/spec.md` の「この書式検査の守備範囲は…」）。

pr-review-gate の仕分け手順はすでに「受け入れ条件または仕様の守備範囲のどの文に違反するか」を引用させる（`openspec/specs/dev-workflow-pr-review-gate/spec.md`）。引用元になる守備範囲の文を、仕様を書く段階で必ず用意させる入口が無いので、同じ形の仕様を書くたびに再発する。仕様レビュー（R1）で差し戻せば、実装に入る前に守備範囲が揃う。

親: エピック #257。方針: #281 の PR-B。#281 の PR-A（pr-review-gate の収束ルールの適用手順）とは独立で、順序依存は無い。

## What Changes

- 仕様レビュアー R1 の観点を 5 つから 6 つに増やし、6 つ目に「守備範囲の明記」を置く
- 対象は**入力を検査・判定する要件**（検査・lint・ゲート・パーサ・バリデータのように、入力を受け取って通す／落とす／分類する振る舞いを定める要件）に限る。入力の検査を含まない仕様には要求しない
- 対象の要件に「何から守り、何は守らないか」の段落が無ければ、R1 はその欠落を BLOCKER とし、`REQUEST_CHANGES` で差し戻す
- 適用範囲はレビュー対象の change が追加・改定する要件だけ。既存 `openspec/specs/` への遡及適用はしない
- `develop-roles.bats` に 6 観点目の退行検査を足す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-spec-review`: 要件「仕様レビューの観点は既存 spec との整合と受け入れ条件の一意性を含む」を MODIFIED。観点を 6 つにし、守備範囲の対象・欠落時の差し戻し・遡及しない範囲を要件化する

## Impact

- **スキル文書**: `plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md`（「レビュー観点（5 つ。すべて検査する）」を 6 つに）
- **テスト**: `plugins/dev-workflow/tests/develop-roles.bats`（R1 の観点を固定しているテストに 6 観点目を足す）
- **配布**: `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョン bump（2.13.24 → 2.13.25）、`plugins/dev-workflow/CHANGELOG.md`
- **常時注入の予算**: `tests/injection-budget.bats` が数えるのは frontmatter の `description:` 行だけで、spec-reviewer.md 本文の追記は予算に当たらない
- **前提環境**: dev-workflow プラグインの develop スキル（R1 を spawn する本体）と openspec。新たな CLI・権限は要らない
