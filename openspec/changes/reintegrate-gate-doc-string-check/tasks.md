行番号は origin/main（a09ef0c9）の版の値。pr-review-gate のパスは `plugins/dev-workflow/skills/pr-review-gate/` を G と略す。

## 1. main の取り込み

- [x] 1.1 `git merge origin/main` し、衝突は次の方針で解消する: marketplace.json・plugin.json・rules/git-commit-policy.md・pr-review-gate の SKILL.md・dev-workflow README・pr-review-gate-skill.bats・openspec/specs は main 版、`.claude/casting/precedents.md` は両方の行を残す。衝突せず自動で混ざったファイルも `git diff origin/main --stat` で確かめ、旧設計の差分は archive の 08-21 の change を除いて main に揃える。rebase・force push・bare な stash はしない。確認: `git diff origin/main --stat` に残るのが openspec の change 2 つ（08-21 の archive とこの change）と判例の追記だけ。触る範囲: .claude-plugin/marketplace.json、.claude/casting/precedents.md、openspec/specs/dev-workflow-pr-review-gate/spec.md、plugins/dev-workflow/.claude-plugin/plugin.json

## 2. ゲートの手順とテスト

- [x] 2.1 先に bats を書く（`SKILL.md` の節の必須条件と `git grep -n` の例・4-2 の 4 種・`git grep -n`・0 件の記録・4 見出し・段 A・取り直しの行・周回を足さない）。実装前に落ちることを確認する。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:670-771（段 A の固定文言）、plugins/dev-workflow/tests/pr-review-gate-spec-declaration.bats:56-60（3 見出し）
- [x] 2.2 `stages/pass.md` に 4-1・4-2 を書き（4-1 の本文は変えない）、手順 5 を 4 見出しにし、G の節に説明の食い違いの failed の return の書式を足す。確認: 2.1 の該当テストが通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:17-64（手順 4）、:90-101（見出しの実測）、:193-235（G の節）
- [x] 2.3 振り分けの段 A と 2 周目の終わりに説明の食い違いを足す。確認: 2.1 の段 A のテストが通る。触る範囲: G/stages/triage-nonblocking.md:5-18、G/stages/triage-convergence.md:31、G/stages/triage.md:21、:59（仕分け欄）
- [x] 2.4 取り直しの行がある failed は周回を足さないと書き、light で免除しない工程に 4-2 を足す。確認: 2.1 の該当テストと develop の bats が通る。触る範囲: G/stages/prepare.md:72 付近（light で省かない工程）、:106-107（再レビューの入力）、plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:55

## 3. 列挙の更新と記録

- [x] 3.1 `SKILL.md` に節 `## ドキュメント文字列の整合確認（合格の必須条件）` を行の追加だけで足し（③に含むこと・対象 4 種・`git grep -n -- '<変えたシンボル名>'` のインラインの例・詳細は `stages/pass.md` の 4-2。③の行と `description` は変えない）、README 2 本・commit-and-pr-operations.md・develop の SKILL.md の「3 見出し」の言及を揃える。確認: `git diff origin/main -- plugins/dev-workflow/skills/pr-review-gate/SKILL.md` に削除行が無く、`bats plugins/dev-workflow/tests/pr-review-gate-index.bats` と develop の起動時の字数予算のテストが通る。触る範囲: G/SKILL.md:15-17（節を足す位置。`## 段の表` の前）、plugins/dev-workflow/README.md:25-26、plugins/dev-workflow/templates/auto-merge/README.md:9、plugins/dev-workflow/references/commit-and-pr-operations.md:16、plugins/dev-workflow/skills/develop/SKILL.md:94
- [x] 3.2 `plugins/dev-workflow/changes/166.md` を書く（版は上げない）。確認: ファイルがあり plugin.json に差分が無い。触る範囲: plugins/dev-workflow/changes/166.md（新規）
- [x] 3.3 固定テストと予算を合わせる: 本文保持の fixture は変えた段落だけ更新し、読む量の予算は実測以上・実測の 1.1 倍以下にする。確認: `bats tests/gate-contract-preservation.bats tests/gate-reading-budget.bats` が通る。触る範囲: tests/fixtures/gate-contracts/prose.json、tests/fixtures/gate-contracts/blocks.json、tests/gate-reading-budget.txt

## 4. 全体の確認

- [ ] 4.1 `bash scripts/test.sh` と `openspec validate reintegrate-gate-doc-string-check --type change --strict` が通り、design.md の表のとおり受け入れ条件 3 つを確かめる（`SKILL.md` は追加のみ。ほかのファイルの削除行の一覧は PR に載せる）。触る範囲: openspec/changes/reintegrate-gate-doc-string-check/tasks.md
