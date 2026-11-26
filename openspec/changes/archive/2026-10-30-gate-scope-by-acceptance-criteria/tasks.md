# Tasks

## 1. triage.md の振り分けを受け入れ条件で決める

- [x] 1.1 振り分け表の段 A の行と段 A の節を delta spec の文に書き換え（受け入れ条件の範囲は順 2 と同じ）、新しい部品・機能の提案は行数によらず範囲外と書く。手順 2-2 の「段 A だけで戻した failed」の理由を「止めない指摘」に直す。bats の #985 の段 A のテストを新しい文に直し、受け入れ条件に要らない指摘が段 A に当たらないこと・範囲外の文があることを検査するテストを足す（`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が通る）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:69（振り分け表）、plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:78（段 A の節）、plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:148（手順 2-2）、plugins/dev-workflow/tests/pr-review-gate-skill.bats:662-673
- [x] 1.2 仕分け表の順 4 の行と順 4 の節を、根拠が例外 3 種の指摘に限る形に書き換え、例外 3 種に当たるかは根拠欄の書き方によらず G が決めると書く。「今直す 3 条件」の語と 30 行の閾値は残す。行 4 と順 4 の節が例外 3 種を含むことを検査するテストを足す（同じ bats が通る）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:28（仕分け表）、plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:59（順 4 の節）、plugins/dev-workflow/tests/pr-review-gate-skill.bats:807、plugins/dev-workflow/tests/pr-review-gate-skill.bats:847-858
- [x] 1.3 振り分けの記録と return の仕分け欄に、段 A の要る受け入れ条件の ID か delta spec の要件名、または例外 3 種のどれかと、順 4 の例外 3 種のどれかを足す。W の記録の文字列「受け入れ条件の外・その場で直した・直し方 N 行」は変えない（`bats plugins/dev-workflow/tests/develop-roles.bats` と同じ bats が通る）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:117（振り分けの記録）、plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:174（return の仕分け欄）

## 2. reviewer-brief.md で受け入れ条件と印を渡す

- [x] 2.1 入口に、起こす側が受け入れ条件の全文を依頼文に入れることを書く。指示ブロックの固定書式に `受け入れ条件の要否` の欄を足し、値の定義、`要らない` の指摘も省かないこと、新しい部品・機能の提案は `要らない` にすることを書く。根拠の行を「引用、または例外 3 種のどれか。引用できる指摘でも例外 3 種に当たれば併記する」にする。読み替え表に行を足す。triage.md の段 A の節に、印は参考で判定は G の照合であること、印が無ければ G が決めることを書く。これらを検査するテストを足す（同じ bats が通る）。README の固定書式の列挙に欄を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:9（入口）、plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:41-42（固定書式）、plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:63（読み替え表）、plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:78（段 A の節）、plugins/dev-workflow/README.md:26、plugins/dev-workflow/tests/pr-review-gate-skill.bats（新しいテスト）

## 3. 仕上げ

- [x] 3.1 変更の記録を書く。`grep -n "段 A" plugins/dev-workflow/skills/pr-review-gate/stages/triage.md` を実行し、`grep -nE '触れたファイルの中に収まる|変えたファイルの中で直せる|受け入れ条件の外でも' plugins/dev-workflow/skills/pr-review-gate/stages/triage.md` が 0 件で古い定義が残っていないこと、`grep -n '30 行' plugins/dev-workflow/skills/pr-review-gate/stages/triage.md` が順 4 の節だけに出ることを確かめ、`openspec validate gate-scope-by-acceptance-criteria --type change --strict` と `bats tests/` を通す。触る範囲: plugins/dev-workflow/changes/1389.md（新規）

## Workflow follow-up

- archive と PR の作成は (3b) で行う
- 開いている PR #1436（#580）と重なるので、PR 本文にその旨を書く
