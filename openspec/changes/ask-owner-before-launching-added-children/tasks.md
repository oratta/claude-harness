# Tasks

実装開始の前提は issue #1647 の仕様化判断と、この change に対する R1 の APPROVE。行番号は仕様化時点の案内であり、編集前に該当範囲を読み直す。

## 1. 文書

- [x] 1.1 `epic.md` の「共通」に、範囲外の問題の項目の直後へ項目を足す。内容は、起動してよい子（回し始めの子と主が承認した子）、途中で足された子は起票と紐付けまでで止めて起動前に主へ 1 問で聞くこと、承認はその時点で挙がっていた子にだけ効くこと。受け入れ条件 (a) を満たす。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:47-51（共通の項目）
- [x] 1.2 `epic-loop.md` の状態表の段落の `未起動（<理由>）` の例に `未起動（主の判断待ち）` を足す。既存の文字列 `未起動（<理由>）` は残す。受け入れ条件 (b) を満たす。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:41（状態表の段落）
- [x] 1.3 変更の記録を書く（版は上げない）。触る範囲: plugins/dev-workflow/changes/1647.md（新規）

## 2. テスト

- [x] 2.1 `epic.md` に 1.1 の 3 点（起動前に主へ 1 問・足された子は起動しない・承認の範囲）と、`epic-loop.md` に `未起動（主の判断待ち）` があることを grep で検査するテストを足す。`TMPDIR=$(mktemp -d) bats plugins/dev-workflow/tests/develop-skill.bats` と `epic-dispatch.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/develop-skill.bats:557-564（#1646 のテストの隣）

## 3. 統合検証

- [x] 3.1 `openspec validate ask-owner-before-launching-added-children --type change --strict`、`TMPDIR=$(mktemp -d) bats plugins/dev-workflow/tests/injection-budget.bats`（常時注入の予算が動いていないこと）、`git diff --check` が exit 0。reviewer-brief.md に差分が無いこと。触る範囲: openspec/changes/ask-owner-before-launching-added-children/
