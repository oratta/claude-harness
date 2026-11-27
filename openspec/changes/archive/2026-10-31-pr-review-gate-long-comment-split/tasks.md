# Tasks

## 1. 規則の本文

- [x] 1.1 `stages/triage.md` の `## 出口` の前に新しい節 `## コメント長の上限を超えるとき（三表と順 3 の一覧）` を足す。中身は親と部分の形（三表と順 3 の 2 種類）、`wc -c` で測ること、行の境界で切ること、部分を先に親を最後に `gh pr comment --body-file` で投稿して URL を受け取ること、復元の手順（`body="$(gh api repos/$R/issues/comments/<コメント ID> --jq .body)"` と `printf '%s\n' "$body" | tail -n +4 >> <table-file>` の 2 行）、`$(...)` が各部分の末尾の改行を落とし `printf '%s\n'` が行区切りを 1 個戻すので部分の間に行区切りが 1 個残ること、確かめる点（`部分 k/n:` が n 行そろい n 件取得できること・同じ PR・k/n・SHA）、読めないときの扱い（三表は `review-incomplete`、順 3 は照合をせず差し戻し 1 回）、復元のあとの照合は分けないときの経路のまま（grep の語は `review-hit-set.py`、場合分けの軸はスクリプトへ渡さず全域との集合一致）であること、1 行で収まらないときの止まり方。既存の文は書き換えない。確認: 2.1 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:203-205（`**直し方の判定の受領**` の次、`## 出口` の前）
- [x] 1.2 `stages/triage.md` の順 3 の書式の箇条の末尾に 1 項足し、一覧が 65,536 バイトを超えるときは 1.1 の節のとおり親と部分に分けると書く（順 3 の本文の「1 つの PR コメントに投稿」は変えない）。確認: 2.1 の bats が通る。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:51（「順 3」の箇条の最後の次）
- [x] 1.3 `worker/implement.md` の「G から一覧を求められた指摘」の段落の次に 1 段落足し、一覧が上限を超えるときの規則が `stages/triage.md` の 1.1 の節にあること、1 行で収まらなければ投稿も push もせず return することを書く（#1410 が同じ段落を直すので、段落そのものは変えない）。確認: 2.1 の bats が通る。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker/implement.md:34-36

## 2. テストと記録

- [x] 2.1 `plugins/dev-workflow/tests/pr-review-gate-long-comment.bats` を足す。文面の検査: 1.1 の節に 65,536・`wc -c`・親と部分の 1 行目の形・投稿の順・復元の 2 行・`review-incomplete`・差し戻し・場合分けの軸をスクリプトへ渡さないことがあること、1.2 と 1.3 の案内があること。動きの検査: 一時の git リポジトリの全行の表を行の境界で部分に分け、末尾に改行の付いた本文から復元の 2 行で表ファイルを作り、`review-hit-set.py --repo <repo> --head <HEAD>` が exit 0 を返すこと、補助表が部分の境界をまたいでも同じ結果になること、前の部分の最後の行と次の部分の最初の行が 1 行につながらないこと、検索コマンドの行と主表の見出しを保って主表のヒット行の一部を抜いた表ファイルで exit 1 と `missing:` を出すこと（部分の取得不足はスクリプトではなく G が親の数で検出するので、部分を丸ごと抜く入力はここで確かめない）。確認: `bats plugins/dev-workflow/tests/pr-review-gate-long-comment.bats` が全件通る。触る範囲: plugins/dev-workflow/tests/pr-review-gate-long-comment.bats（新規）
- [x] 2.2 変更の記録を書く。確認: `bats tests/plugin-release-convention.bats` が通る。触る範囲: plugins/dev-workflow/changes/1249.md（新規）
- [x] 2.3 既存の検査を通す。確認: `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats plugins/dev-workflow/tests/review-hit-set.bats` が全件通る。触る範囲: なし（検査のみ）

## Workflow follow-up

- archive と PR の作成は (3b) で行う
