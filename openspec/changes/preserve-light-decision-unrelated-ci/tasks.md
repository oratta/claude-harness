# Tasks

## 1. 関係確認を判断再投稿より先に置く

- [ ] 1.1 develop-trivial-light-path.bats に、軽い通し方の `ci-fail` から起きた新しい spec 段 W の関係確認が通常判断の再投稿より先であること、無関係なら判断再投稿・artifact 作成・修正・push をせず返して最新の軽い判断を保持すること、本体が既存の `next --unrelated <チェック名> --after-fix` を使うことを検査する関係テストを足す。起動指示・decision-criteria・ci-watch・worker/spec の接続と、無関係時には手順 3 のラベル操作にも進まないことを対象にする。検証: `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats` で追加ケースの red を確認する（単なる語句の存在だけでなく、関係確認を投稿前に要求する節と、無関係時に投稿を止める分岐を確かめる）。触る範囲: plugins/dev-workflow/tests/develop-trivial-light-path.bats:1-12、plugins/dev-workflow/tests/develop-trivial-light-path.bats:62-134
- [ ] 1.2 decision-criteria.md の「CI 見張りの fix からの戻し方」で、起動指示と新しい W の動きに判断再投稿前の関係確認を定め、無関係なら最新判断を保持して既存の返却経路へ進むようにする。関係がある／無関係と判断できない場合は確認後に通常判断を投稿し、「する」なら artifact 一式と R1 の APPROVE、どちらでもテストを経る従来契約を残す。競合時の通常復帰、通常経路の既存 W の implement 再開、通常復帰後の再 fix、仕様化途中の push 前の保護と (3b) return 後の見張り再開を維持する回帰ケースも 1.1 のテストへ加える。検証: 同 Bats の該当分岐が green となり、既存ケースも通ること。触る範囲: plugins/dev-workflow/skills/develop/references/decision-criteria.md:58-65、plugins/dev-workflow/tests/develop-trivial-light-path.bats:62-134
- [ ] 1.3 worker/spec.md の仕様化判断節に入る前へ CI fix からの先行確認の入口を足し、無関係なら判断記録の一般手順へ進まず返すことを正本への参照で定める。ci-watch.md「7. 直し方」手順 2 もこの順序へ接続する。無関係の判断基準は共有手順「5」の既存の 2 条件を使い、非 develop の実装者や既存 W の経路は維持する。検証: 1.1 の接続ケースを green にし、`bats plugins/dev-workflow/tests/develop-trivial-light-path.bats plugins/dev-workflow/tests/ci-watch.bats plugins/dev-workflow/tests/ci-watch-entry.bats` が exit 0 となること。既存の ci-watch.bats の after-fix 実行ケースで同じ HEAD の rerun・fixes 保持を確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker/spec.md:29-45、plugins/dev-workflow/references/ci-watch.md:99-108、plugins/dev-workflow/tests/develop-trivial-light-path.bats:62-134
- [ ] 1.4 issue #1596 の変更記録に、判断投稿前の関係確認、無関係時の軽い判断の保持、既存の通常復帰と R1 の維持を記す。検証: `git diff --check` と diff の読み合わせで delta と対応し、他の子 issue の範囲・重複整理を含まないこと。触る範囲: plugins/dev-workflow/changes/1596.md（新規）

## 2. 復帰接続全体の verify

- [ ] 2.1 `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats plugins/dev-workflow/tests/ci-watch.bats plugins/dev-workflow/tests/ci-watch-entry.bats tests/develop-startup-budget.bats` と `openspec validate preserve-light-decision-unrelated-ci --type change --strict` を実行し exit 0 を確認する。差分を確認して、既存の R1・通常復帰・同じ状態ファイルと回数上限が維持され、#1583・#1590・#1597、起動時予算対象の 3 ファイル、過去の archive 済み artifact に変更がないことを確認する。テスト・仕様の追加は前グループで済ませ、ここでは接続全体を確かめる。触る範囲: plugins/dev-workflow/tests/develop-trivial-light-path.bats:62-134、plugins/dev-workflow/tests/ci-watch.bats:305-323、openspec/changes/preserve-light-decision-unrelated-ci/specs/dev-workflow-develop/spec.md:1-64

## Workflow follow-up

- R1 の APPROVE を記録先 issue #1596 で確認してから実装へ進む。今工程は artifact のみを commit・push し、実装や archive は行わない。
- verify 後の finish 工程で delta を archive し、`openspec/specs/dev-workflow-develop/spec.md:766-815` の該当要件へ反映する。過去の archive 済み change や他の要件は書き換えない。
- 起動時予算対象の 3 ファイルの変更は予定しない。必要になって超過した場合は OWNER の指示どおり既存文を圧縮せず、追記による増加分まで該当予算を上げ、finish の PR 本文に理由と https://github.com/oratta/claude-harness/issues/1586 を書く。
