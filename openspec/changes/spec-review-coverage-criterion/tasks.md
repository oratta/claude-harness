## 1. 退行検査を先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/develop-roles.bats` に、spec-reviewer.md の「レビュー観点」節（`section "$REVIEWER" 'レビュー観点'`）に `守備範囲`・入力を検査・判定する要件への限定・`REQUEST_CHANGES` の 3 つがあることを確かめるテストを足す
- [ ] 1.2 同じ節に、既存 spec へ遡及しない（change の追加・改定する要件に限る）記述があることを確かめるテストを足す
- [ ] 1.3 既存テスト「reviewer: five review criteria …」の名前と内容を 6 観点に合わせる
- [ ] 1.4 `scripts/test.sh develop-roles` を実行し、1.1・1.2 が fail することを確認する

## 2. spec-reviewer.md を直す（Green）

- [ ] 2.1 見出し「レビュー観点（5 つ。すべて検査する）」を 6 つに変え、6 番目に「守備範囲の明記」を足す（対象の定義と例、「何から守るか」「何は守らないか」の両方、欠落は BLOCKER として `REQUEST_CHANGES`、入力の検査を含まない要件には求めない、遡及しない、手本として `openspec/specs/injection-budget-gate/spec.md` の守備範囲の段落を指す）
- [ ] 2.2 spec-reviewer.md 内で「5 観点」「5 つ」を指している他の箇所があれば 6 に揃える（`grep -n '5 つ\|5 観点' plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md` で確認）
- [ ] 2.3 リポジトリ内で R1 の観点数を「5」と書いている他の文書を `grep -rn '5 観点\|観点（5' plugins/ docs/` で探し、あれば揃える
- [ ] 2.4 `scripts/test.sh develop-roles` が pass することを確認する

## 3. 配布まわり

- [ ] 3.1 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を 2.13.24 → 2.13.25 に上げる
- [ ] 3.2 `plugins/dev-workflow/CHANGELOG.md` に 2.13.25 の項を足す（R1 に守備範囲の観点を追加、#287）

## 4. 検証

- [ ] 4.1 `scripts/test.sh` 全件を実行し pass を確認する
- [ ] 4.2 `openspec validate spec-review-coverage-criterion --strict` が通ることを確認する
