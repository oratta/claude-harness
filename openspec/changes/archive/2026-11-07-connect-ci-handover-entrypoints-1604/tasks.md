# Tasks

実装前に記録先の通常の仕様化判断と R1 APPROVE を確認する。#1604 の範囲に限定し、#1596 / #1602 / #1549 の変更は行わない。行番号は仕様作成時点の案内であり、編集前に該当範囲を読む。

## 1. 通常経路の CI 引き継ぎの接続と退行検査

- [x] 1.1 ci-watch.md の開始手順から 7 冒頭の CI 用引き継ぎへの参照を追加する。関係 Bats に開始節を切り出す検査を追加し、7 に既存記述があるだけでは合格しないことを確かめる。`bats plugins/dev-workflow/tests/develop-trivial-light-path.bats` が exit 0。触る範囲: plugins/dev-workflow/references/ci-watch.md:18-35、plugins/dev-workflow/tests/develop-trivial-light-path.bats:165-178
- [x] 1.2 develop/SKILL.md の failed 後の W 起動／再開と handover.md を読む場面に、最新 CI 用引き継ぎが可なら同ファイル「起動／再開前の無効化と再許可」に従って不可を投稿し、投稿成功後だけ指示する参照を追記する。関係 Bats は failed 分岐と読む場面を個別に切り出し、正本だけに文言が残っていても入口の欠落を検出する。既存の投稿失敗時の停止・同じ HEAD で二人目を起こさない検査を維持し、`bats plugins/dev-workflow/tests/develop-trivial-light-path.bats` が exit 0。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:185-189、plugins/dev-workflow/skills/develop/SKILL.md:283-290、plugins/dev-workflow/tests/develop-trivial-light-path.bats:202-219、plugins/dev-workflow/tests/develop-trivial-light-path.bats:392-406
- [x] 1.3 handover.md の「修正後の待ちへ戻る前」に、今回の W が無関係と判断して push せず工程完了を返した後の `next --unrelated` 前も含むことを明記する。関係 Bats で今回の工程完了に基づく可の更新が next 前に必要であることと、以前の完了／停止確認・push・idle・オーナーの続行指示だけでは可へ戻さない規則の維持を検査する。`bats plugins/dev-workflow/tests/develop-trivial-light-path.bats` が exit 0。触る範囲: plugins/dev-workflow/skills/develop/references/handover.md:57-83、plugins/dev-workflow/tests/develop-trivial-light-path.bats:169-178、plugins/dev-workflow/tests/develop-trivial-light-path.bats:215-219
- [x] 1.4 SKILL.md の追記による増加バイト数を仕様段の baseline 86910 bytes と比べる。tests/develop-startup-budget.txt の予算超過時は当該行を今回の増加バイト数分だけ上げる。近くの既存文の圧縮や重複整理は行わない。`bats tests/develop-startup-budget.bats` が exit 0。触る範囲: tests/develop-startup-budget.txt:1-3、plugins/dev-workflow/skills/develop/SKILL.md:185-189、plugins/dev-workflow/skills/develop/SKILL.md:283-290
- [x] 1.5 F1/F3/F4 の接続変更と守備範囲を plugins/dev-workflow/changes/1604.md に記録し、上記三つの接続を説明していることを確認する。触る範囲: plugins/dev-workflow/changes/1604.md（新規）

## 2. 接続全体の検証

- [x] 2.1 `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats plugins/dev-workflow/tests/develop-handover.bats plugins/dev-workflow/tests/ci-watch.bats tests/develop-startup-budget.bats`、`openspec validate connect-ci-handover-entrypoints-1604 --type change --strict`、`git diff --check` がすべて exit 0。実エージェントの起動は不要。触る範囲: plugins/dev-workflow/tests/develop-trivial-light-path.bats:165-240、plugins/dev-workflow/tests/develop-trivial-light-path.bats:392-406、plugins/dev-workflow/tests/develop-handover.bats:1-175、plugins/dev-workflow/tests/ci-watch.bats:425-460、tests/develop-startup-budget.bats:1-233、openspec/changes/connect-ci-handover-entrypoints-1604/specs/dev-workflow-develop/spec.md（新規）

## Workflow follow-up

- 仕様段では artifact 作成まで。実装は R1 APPROVE と本体の再開指示後に行う。
- finish 工程で既存 develop 要件二つへ delta を同期して archive し、PR を作る。触る範囲: openspec/specs/dev-workflow-develop/spec.md:5123-5153、openspec/changes/connect-ci-handover-entrypoints-1604/（archive 元）
- PR 本文には `Closes #1604` を書く。起動時予算を上げた場合は増加理由と https://github.com/oratta/claude-harness/issues/1586 を書く。merge や auto-merge はしない。
