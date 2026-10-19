## 1. 実装

- [ ] 1.1 cmd_reap の `orca terminal close` を、失敗したら terminal list を stderr に流し・待ち・1 回だけ閉じ直す形にし、再失敗で `kept <N> close-failed` と主がする操作を stderr に出す。冒頭コメントの reap の説明も直す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:94-110、plugins/dev-workflow/scripts/epic-dispatch.sh:848
- [ ] 1.2 bats: スタブの `terminal close` を呼び出し回数ごとに終了コードを変えられるようにし、「1 回目失敗・2 回目成功で `reaped 11`」「2 回とも失敗で `kept 11 close-failed` と stderr の主がする操作・close 2 回・rm 0 回」を追加。既存の close-failed テストを新しい挙動に合わせる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:73-75、plugins/dev-workflow/tests/epic-dispatch.bats:1936-1944
- [ ] 1.3 SKILL.md 手順 3 の `kept <N> <理由>` の扱いに、`close-failed` のときは stderr の主がする操作をエピックへの 1 行に含める旨を足す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:431
