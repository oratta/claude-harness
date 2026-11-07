# Tasks

## 1. CI の fix からの復帰契約をテストと手順にする

- [x] 1.1 軽い通し方の passed 後の `ci-fail` と `conflict` の fix が、同じ worktree の新しい W の `段: spec` 起動・修正材料の受け渡し・同じ記録先への `通し方:` のない判断の再投稿・テスト作成・同じ PR・通常経路への復帰を要求する Bats ケースを足し、現行手順で失敗することを確認する。「する」なら artifact 一式と R1 の APPROVE を経ること、「しない」でもテストを省かないこと、本体が直接直さないことを対象にする。既存の最新判断選択の実行テストと併せて、古い `通し方: 軽い` に戻らないことも確認する。検証: `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats`（追加ケースの red を確認）。触る範囲: plugins/dev-workflow/tests/develop-trivial-light-path.bats:1-78、plugins/dev-workflow/tests/develop-trivial-light-path.bats:126-130
- [x] 1.2 decision-criteria.md の軽い通し方に CI 見張りの fix からの復帰の正本を追記し、SKILL.md の passed/fix から参照する。最新判断が軽いなら新しい W を `段: spec`、通常経路に既存 W がいるなら `段: implement` の再開／許可された手渡し、と区別する。通常経路では CI の fix だけを理由に仕様化判断を再投稿しない。通常へ戻った後の再 fix も既存 W の分岐になることをテストに加え、1.1 とともに green にする。既存文を圧縮して起動時予算へ収めず、超過した場合は該当行を追記で増えたバイト数まで上げる。検証: `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats tests/develop-startup-budget.bats`。触る範囲: plugins/dev-workflow/skills/develop/references/decision-criteria.md:30-58（軽い通し方）、plugins/dev-workflow/skills/develop/SKILL.md:155-162（passed/fix）、plugins/dev-workflow/tests/develop-trivial-light-path.bats:1-78、tests/develop-startup-budget.txt:1-3
- [x] 1.3 ci-watch.md「7. 直し方」の develop の W の説明から復帰の正本を参照し、W がまだいない場合も用意できる接続にする。共有 reference と SKILL.md が同じ担当・段の分岐を辿れ、どちらの修正 push 後も passed を外したまま同じ状態ファイルで `wait` → `next` を続け、`ready` 後に前提確認と重さ判定の新しい G へ進むことを Bats で確認する。共有手順のラベル操作・unrelated の返却・非 develop の実装者起動は維持する。検証: `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats plugins/dev-workflow/tests/ci-watch.bats plugins/dev-workflow/tests/ci-watch-entry.bats`。触る範囲: plugins/dev-workflow/references/ci-watch.md:15-15、plugins/dev-workflow/references/ci-watch.md:63-108、plugins/dev-workflow/tests/develop-trivial-light-path.bats:1-78、plugins/dev-workflow/tests/ci-watch.bats:434-455、plugins/dev-workflow/tests/ci-watch.bats:587-593
- [x] 1.4 issue #1589 の変更記録を追加し、軽い通し方と通常経路の差、および通常復帰後の再 fix の振る舞いを記す。検証: 記録の内容が本 change の delta と対応し、#1583 の説明文や #1590 の変更を含まないことを diff で確認する。触る範囲: plugins/dev-workflow/changes/1589.md（新規）

## 2. 復帰接続全体の verify

- [x] 2.1 関係テスト `bats plugins/dev-workflow/tests/develop-trivial-light-path.bats plugins/dev-workflow/tests/ci-watch.bats plugins/dev-workflow/tests/ci-watch-entry.bats plugins/dev-workflow/tests/develop-skill.bats tests/develop-startup-budget.bats` と `openspec validate develop-light-ci-fix-reentry --strict` が exit 0 で終わることを確認する。変更差分が issue #1589 の範囲だけで、commands/develop.md、#1583 の受け入れ条件、tests/injection-budget.txt を変えていないことを確認する。触る範囲: plugins/dev-workflow/tests/develop-trivial-light-path.bats:1-204、plugins/dev-workflow/tests/ci-watch.bats:434-455、plugins/dev-workflow/tests/ci-watch.bats:587-593、openspec/changes/develop-light-ci-fix-reentry/specs/dev-workflow-develop/spec.md（新規）

## Workflow follow-up

- R1 の APPROVE を記録先で確認してから実装工程へ進む。
- verify 後の finish 工程で archive し、`openspec/specs/dev-workflow-develop/spec.md:766-782` の要件に delta を反映する。他の要件や archive 済みの過去 change は書き換えない。
- finish 工程で PR を用意し、起動時予算を上げた場合は PR 本文に追記による増加分と理由、および https://github.com/oratta/claude-harness/issues/1586 を書く。merge／auto-merge は本 worker の担当外。
