## 1. 基準の文面

- [x] 1.1 `parent-pass-criteria.md` に、表を使わない文章の節「CI の見張りのやり直しの上限で止まった子」を足す（対象の定義・通す場合・返事・主に上げる場合・「繰り返していない」との関係と同じ件の定義・守備範囲）。条件表は 9 条件のまま。通る例に上限で止まった子への追加のやり直し 1 回を足す。他リポジトリの org 名・issue 番号は書かない 触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:27-46（「迷ったとき」の段落のうしろに節を足し、「例」の通る例に 1 行足す）

## 2. テスト

- [x] 2.1 節の記述（対象の 2 経路・修正回数の上限が対象外・3 つの追加条件・1 回だけの返事と見張りへの復帰・`job-timeout` は主に上げる・同じ件の定義・「繰り返していない」との関係）と、表の行数が 10 のままであることを確かめる 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3611-3650（テスト「criteria: the file states the nine conditions, the examples and the output form」の近く）
