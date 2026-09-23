## 1. テストを先に書く（TDD）

- [x] 1.1 `plugins/dev-workflow/tests/review-hit-set.bats` に、`--head` 付きの照合のケースを足す: 「該当しない」行を書き換えて補助表に載せた→exit 0、補助表なし→`unmatched:` と exit 1、混在する組で「該当しない」側だけ書き換え「直した」側を直し忘れ→`not-removed:` と exit 1、補助表が「直した」行を指す→契約違反 exit 1、補助表の `(ファイル, 行（修正前 SHA）)` の重複→契約違反 exit 1、補助表の修正後の本文が主表の本文と等しい→契約違反 exit 1、扱いの欄が 2 値以外→契約違反 exit 1、「直した」を全部直して HEAD の残存が「該当しない」だけ→exit 0、既存の「直したはずが残った」→`unmatched:` と exit 1。`not-removed:` と `unmatched:` は同時に出うるので、`not-removed:` を期待するケースで `unmatched:` の不在は assert しない
- [x] 1.2 同 bats に、補助表を含む一覧を `--head` 無しで照合すると補助表を無視して現行どおり exit 0 になるケースを足す
- [x] 1.3 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` の順 3 の書式テストに、補助表の見出し `### 書き換えた該当しない行`・列 `| ファイル | 行（修正前 SHA） | 修正後の本文 |`・2 段目で補助表の修正後の本文を使う規則・混在する組の削除行の必要数に補助表の件数を足す規則の存在確認を足す
- [x] 1.4 worker.md の順 3 の段落に、書き換えた「該当しない」行を補助表に載せる記述があり、補助表の列を再掲していないことを確かめるテストを `plugins/dev-workflow/tests/develop-roles.bats` に足す。同じ bats に、gate-runner.md の順 3 の照合の記述が `review-hit-set.py` を `--head` と fetch 後の HEAD の 40 桁 SHA 付きで実行することと SKILL.md の順 3 を正本として参照することを確かめるテストも足す
- [x] 1.5 追加したテストが現状で落ちることを確かめる

## 2. 実装

- [x] 2.1 `plugins/dev-workflow/scripts/review-hit-set.py` に `--head <rev>` を足す: 主表の扱いの 2 値検査、補助表 `### 書き換えた該当しない行` の解析（本文列は主表と同じ escape / fence 規則）と主表の「該当しない」行への同定検査、HEAD での検索と `(ファイル, 本文)` の件数照合、混在する組の `git diff <修正前 SHA> <HEAD> -- <ファイル>` の削除行の検査。`--head` 無しの経路は変えない
- [x] 2.2 `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` 手順 2-1 の順 3 の節に、補助表の書式、主表の本文列は修正前の本文であること、2 段目の本文の選び方、混在する組の削除行の必要数、差分の種類（補助表の不正な行）を足し、2 段目を `review-hit-set.py --head <HEAD>` で回すこと（G が渡すのは W の push を取り込んだあとの HEAD の 40 桁フル SHA）を書く。あわせて手順 2-1 の共通一覧契約の段落（154 行目付近）の「順 3 固有の修正後 HEAD に対する本文・件数・削除行の第 2 段は別に維持する」を、第 2 段が `--head` 付きの同じスクリプトで回ることを指すように直す
- [x] 2.3 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の順 3 の段落に、書き換えた「該当しない」行を補助表に載せること（主表の本文は修正前のまま）を足す。列は再掲しない
- [x] 2.4 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の順 3 の照合の記述に、2 段目で `review-hit-set.py --head <HEAD>` を使うことへの参照を、渡す値が fetch 後の HEAD の 40 桁 SHA であることとあわせて足す（規則の正本は SKILL.md）
- [ ] 2.5 PR 本文に、MODIFIED「一覧の一致で閉じる（順 3）」で検索コマンドの形を `-- <パス>` から `-- .` に直したのは既存の共通全ヒット一覧契約との食い違いを揃えただけで、振る舞いの追加ではないことを書く
- [x] 2.6 `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを上げ、`plugins/dev-workflow/CHANGELOG.md` に追記する

## 3. 検証

- [ ] 3.1 `bats plugins/dev-workflow/tests/review-hit-set.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が通る
- [ ] 3.2 `openspec validate review-inventory-rewritten-row --strict` が通る
- [ ] 3.3 `scripts/test.sh` 全件が通る（常時注入の予算テストを含む）
