## 1. テストを先に書く（TDD）

- [ ] 1.1 `plugins/dev-workflow/tests/review-hit-set.bats` に、`--head` 付きの照合のケースを足す: 「該当しない」行を書き換えて補助表に載せた→exit 0、補助表なし→`unmatched:` と exit 1、混在する組で「該当しない」側だけ書き換え「直した」側を直し忘れ→`not-removed:` と exit 1、補助表が「直した」行を指す→契約違反 exit 1、扱いの欄が 2 値以外→契約違反 exit 1、「直した」を全部直して HEAD の残存が「該当しない」だけ→exit 0、既存の「直したはずが残った」→`unmatched:` と exit 1
- [ ] 1.2 同 bats に、補助表を含む一覧を `--head` 無しで照合すると補助表を無視して現行どおり exit 0 になるケースを足す
- [ ] 1.3 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` の順 3 の書式テストに、補助表の見出し `### 書き換えた該当しない行`・列 `| ファイル | 行（修正前 SHA） | 修正後の本文 |`・2 段目で補助表の修正後の本文を使う規則・混在する組の削除行の必要数に補助表の件数を足す規則の存在確認を足す
- [ ] 1.4 worker.md の順 3 の段落に、書き換えた「該当しない」行を補助表に載せる記述があり、補助表の列を再掲していないことを確かめるテストを足す（`develop-roles.bats` か既存の worker.md テストの置き場）
- [ ] 1.5 追加したテストが現状で落ちることを確かめる

## 2. 実装

- [ ] 2.1 `plugins/dev-workflow/scripts/review-hit-set.py` に `--head <rev>` を足す: 主表の扱いの 2 値検査、補助表 `### 書き換えた該当しない行` の解析（本文列は主表と同じ escape / fence 規則）と主表の「該当しない」行への同定検査、HEAD での検索と `(ファイル, 本文)` の件数照合、混在する組の `git diff <修正前 SHA> <HEAD> -- <ファイル>` の削除行の検査。`--head` 無しの経路は変えない
- [ ] 2.2 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` 手順 2-1 の順 3 の節に、補助表の書式、主表の本文列は修正前の本文であること、2 段目の本文の選び方、混在する組の削除行の必要数、差分の種類（補助表の不正な行）を足し、2 段目を `review-hit-set.py --head <HEAD>` で回すことを書く
- [ ] 2.3 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の順 3 の段落に、書き換えた「該当しない」行を補助表に載せること（主表の本文は修正前のまま）を足す。列は再掲しない
- [ ] 2.4 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の順 3 の照合の記述に、2 段目で `review-hit-set.py --head <HEAD>` を使うことへの参照を足す（規則の正本は SKILL.md）
- [ ] 2.5 `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを上げ、`plugins/dev-workflow/CHANGELOG.md` に追記する

## 3. 検証

- [ ] 3.1 `bats plugins/dev-workflow/tests/review-hit-set.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が通る
- [ ] 3.2 `openspec validate review-inventory-rewritten-row --strict` が通る
- [ ] 3.3 `scripts/test.sh` 全件が通る（常時注入の予算テストを含む）
