## 1. 判定を直す（区切りが && だけなら cd が成功した場合の基準だけ）

- [ ] 1.1 `check_rm` で、`cd` を含み、コマンドに `;` も改行も無いときは、削除先を解決する基準を `cd` の移り先だけにする（`;` か改行が 1 つでもあれば今の 2 つの基準のまま）。区切りの判別は git 用の判定の規則 1 と同じく、コマンド文字列に `[;\n]` があるかで見る。確かめ方: 1.2 と 1.3 の bats が通り、既存の `rm-permission-guard.bats` が全件通る。触る範囲: plugins/dev-workflow/scripts/git-guard-scratchpad.py:533-593（`check_rm`。基準の一覧 `bases` を作る 547-566 と、削除先ごとに基準を回す 576-591）
- [ ] 1.2 判定を直接かける bats を足す。`cwd` が scratchpad の外（`$OUT`）で `cd $SP/tbl && rm -f x/*`・`cd $SP/tbl && rm -f x/a && rm -f x/b` は満たし、`cd $SP/tbl; rm -f x/*`・`cd $SP/tbl` と `rm -f x/*` を改行でつないだもの・`cd $SP/tbl && rm -f x/a; rm -f x/b` は満たさない。既存のテスト「cd that may fail is checked against the cwd too」は残す。確かめ方: `bats plugins/dev-workflow/tests/rm-permission-guard.bats` で新しいテストが通る。触る範囲: plugins/dev-workflow/tests/rm-permission-guard.bats:476-482（既存の cd 失敗のテストの直後に足す）
- [ ] 1.3 hook と許可を書くスクリプトを通す bats を足す。`cwd` が `$OUT` の子 `a1` で `cd $SP/tbl && rm -f x/*` は、`deny_then_permit` が通り、同じ payload の 2 回目の `call` が `allow` になり、`$SP/tbl/x` の中身はこの時点では消えていない（判定は rm を実行しない）。`cd $SP/tbl; rm -f x/*` は deny のあと `$PERMIT` が 0 でない終了コードで終わり、`permits_empty` を満たす。確かめ方: `bats plugins/dev-workflow/tests/rm-permission-guard.bats` で新しいテストが通る。触る範囲: plugins/dev-workflow/tests/rm-permission-guard.bats:395-415（「git-guard-permit.sh」の節の末尾に足す。許可を書くスクリプトの名前を Bash のコマンドに書かず、bats の中の `$PERMIT` を使う）
- [ ] 1.4 プラグインのテスト全体が落ちないことを確かめる。確かめ方: `bats plugins/dev-workflow/tests/rm-permission-guard.bats plugins/dev-workflow/tests/git-destructive-guard.bats plugins/dev-workflow/tests/hook-python-invocation.bats` が全件通る（ファイル名だけで指定する）。触る範囲: なし（実行だけ）

## 2. 記録と実機確認

- [ ] 2.1 変更の記録を書く（何が変わったか・変えていないもの・受け入れること・戻し方）。確かめ方: ファイルがあり、`&&` だけの形と `;`・改行が混じる形の扱いの違いが書かれている。触る範囲: plugins/dev-workflow/changes/1159.md（新規）
- [ ] 2.2 実機確認: `claude -p --plugin-dir <worktree>` で、作業ディレクトリが一時領域の外の子が `cd <一時領域> && rm -f x/*` を打ち、拒否 → 親が許可 → 再開で通って消えることを確かめ、使った Claude Code の版とコマンドとあわせて PR に記録する（PR は finish の段で作るので、結果は return に書いて引き継ぐ）。確かめ方: 子の拒否の message、許可を書いた出力、再開後にファイルが消えたことが記録にある。触る範囲: なし（実機の操作だけ）

## Workflow follow-up

- archive・PR 作成・仕様宣言は finish の段で行う。PR 本文には実機確認の結果を書き、`Closes #1159` を入れる。hook は聖域なので、マージには主の承認が要る
- PR を出す前に origin/main を取り込み、兄弟の子 #1166・#1173 の open PR と差分が重ならないかを確かめる
