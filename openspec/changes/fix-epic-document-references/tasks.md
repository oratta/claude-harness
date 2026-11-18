# Tasks

実装前提: R1 の APPROVE と本体の再開指示を確認する。本体は7ファイルの規模超過、および移動先 `epic-keepalive-watch.md:9` の残件の扱いを判断する。後者を含める決定があれば、OWNER の範囲指定と artifact を更新してから着手する。行番号は dispatch HEAD 時点の案内であり、編集前に読み直す。

## 1. 指定箇所の参照整合と回帰テスト

- [ ] 1.1 親の時間分類・報告形式・マージ待ちを正本のファイル名と節/段落名へ合わせ、各参照先の実在と対象位置から旧表現が消えたことを確かめる回帰テストを追加する。新テストには識別用の `1693` を名前に含め、`bats plugins/dev-workflow/tests/epic-dispatch.bats --filter 1693` が0、対象ファイル限定の `git grep -n -E '60 分|上の \*\*マージ待ちの子\*\*' -- plugins/dev-workflow/skills/develop/references/epic-loop.md` と `git grep -n -E '上の書き分けの規定|下の \*\*マージ待ちの子\*\*' -- plugins/dev-workflow/skills/develop/references/epic-stop.md` が1（該当0件）であることを確認する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:26-26、plugins/dev-workflow/skills/develop/references/epic-loop.md:61-61、plugins/dev-workflow/skills/develop/references/epic-loop.md:71-71、plugins/dev-workflow/skills/develop/references/epic-stop.md:7-7、plugins/dev-workflow/tests/epic-dispatch.bats:3724-3742（近傍へ回帰テスト追加）
- [ ] 1.2 サブエージェント方式の旧表の説明を復元し、入口の共通規則で両方式を具体名にする。1.1の回帰テストに利用条件・本体の片付け・両方式の具体名の検査を追加し、同一 repo 制約と W の隔離 worktree の規定が保持されることを確かめる。`bats plugins/dev-workflow/tests/epic-dispatch.bats --filter 1693` が0、`git grep -n -F '両経路に共通' -- plugins/dev-workflow/skills/develop/references/epic.md` が1であることを確認する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-subagent.md:3-5、plugins/dev-workflow/skills/develop/references/epic.md:47-50、plugins/dev-workflow/tests/epic-dispatch.bats:3724-3742（1.1の回帰テスト）
- [ ] 1.3 2つのテストの所在説明コメントと公開版分類 docs の現行参照を合わせる。docs が epic-loop.md「部品ごとの欄」を指し、参照先が実在することを1.1の回帰テストへ追加する。`bats plugins/dev-workflow/tests/epic-dispatch.bats --filter 1693` が0、対象コメントに旧い所在が無く、docs の189行以降の履歴表と公開版分類の値に差分が無いことを `git diff` で確認する。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3-4、plugins/dev-workflow/tests/epic-dispatch.bats:508-509、plugins/dev-workflow/tests/epic-dispatch.bats:5187-5190、plugins/dev-workflow/tests/epic-dispatch.bats:5718-5718（要件名の引用は保持して所在説明だけ直す）、plugins/dev-workflow/tests/epic-dispatch.bats:3724-3742（1.1の回帰テスト）、plugins/dev-workflow/tests/parent-merge.bats:30-31、docs/public-private-split.md:182-182

## 2. 統合確認

- [ ] 2.1 `bats tests/develop-epic-scene-budget.bats`・`./scripts/test.sh`・`./scripts/lint.sh`・`openspec validate fix-epic-document-references --type change --strict` がすべて0であることを確認する。全11場面の実測と予算を記録し、超過があれば指定した対象文の簡潔化で収める。収まらなければ超過場面・実測・予算と差分を本体へ返す。予算値・固定集合・範囲外の規則は変更しない。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:26-26、plugins/dev-workflow/skills/develop/references/epic-loop.md:61-61、plugins/dev-workflow/skills/develop/references/epic-loop.md:71-71、plugins/dev-workflow/skills/develop/references/epic-stop.md:7-7、plugins/dev-workflow/skills/develop/references/epic-subagent.md:3-5、plugins/dev-workflow/skills/develop/references/epic.md:47-50

## Workflow follow-up

- 実装後、通常の変更記録を残す。触る範囲: plugins/dev-workflow/changes/1693.md（新規）
- 本体へ検証結果と移動済み残件の扱いを返す。判断未了なら #1693 の全受け入れ完了と宣言しない。
- 本体の後続工程で verify・archive・PR・仕様宣言を行う。この spec 工程では実装・archive・マージを行わない。
