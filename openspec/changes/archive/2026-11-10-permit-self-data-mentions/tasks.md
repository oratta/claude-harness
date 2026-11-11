# Tasks

## 1. 読み分けを git ガードに入れる

- [x] 1.1 `PERMIT_NAME` の近くに、読むか表示するだけのコマンドの一覧（`grep`・`egrep`・`fgrep`・`cat`・`head`・`tail`・`wc`・`ls`・`echo`）の定数を置き、`PERMIT_NAME` のコメント（「書き方を読み分けずに」）を決定 1 の規則に合わせて直す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:114-117（`SHELLS`・`PERMIT_NAME` の定義とコメント）
- [x] 1.2 子のコマンドに名前があるときだけ、字句読み（`run(lex(...))`）に先頭の語だけを集める受け手を渡して読み直し、すべての単純コマンドの先頭の語が一覧に入り、字句読みが返すバッククォートの中身も同じ規則を満たすときに限って `self_permit` を偽にする。`Unclosed`・`TooMuch` は真（止める側）。字句読みの関数（`join_words`〜`judge`）は変えない。`bats plugins/dev-workflow/tests/git-destructive-guard.bats` が 2.1〜2.3 のテストを含めて通ることで確かめる 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:765-787（`judge(command)` の呼び出しから早期 exit まで。`self_permit` の判定は 774-778）
- [x] 1.3 書き出しのコメント（返す値の説明の「子が git-guard-permit.sh を自分で呼んだら deny」）に、一覧のコマンドだけでできたコマンドは止めないことを 1 行で足す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:23-37
- [x] 1.4 コマンド文字列に `$'`・`((`・`$[`・`${` のどれかを含むときは例外をかけない（字句読みが bash と違う読み方をする構文。commit 後の自動セキュリティレビューの指摘）。bats に「permit: the read-only exception is not applied to ANSI-C quoting or arithmetic」を足す 触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh（`self_permit` の判定）、plugins/dev-workflow/tests/git-destructive-guard.bats

## 2. テスト

テストファイルは Write / Edit ツールで書く（子の Bash のコマンドに名前を入れない）。bats は `bats plugins/dev-workflow/tests/git-destructive-guard.bats` の形で打つ。

- [x] 2.1 「permit: a child calling the permit script is denied」の 3 つ目の並びから `cat /x/scripts/git-guard-permit.sh` を外し、spec の Scenario「一覧のコマンドに一覧に無いコマンドが混じれば拒否する」の 11 個のコマンドを `deny` になる並びとして足す（ヒアドキュメントの形は `$'...'` か printf で改行を入れる） 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:1748-1803
- [x] 2.2 新しいテスト「permit: a child mentioning the permit script name only in read-only commands is not stopped」を足す。spec の Scenario「読むか表示するだけのコマンドの中の名前は止めない」の 7 個のコマンドを `agent_id` `a1` で 2 回ずつ渡し、exit 0・出力が空・`$(GUARD_BASE)` が作られないことを確かめる（issue #1166 の受け入れ条件 1） 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:1803-1816（「permit: the main session is not stopped …」の前後）
- [x] 2.3 「store: with the permit script name it is counted and no record is written」のコマンドを `cat …` から実行の形（`bash /x/scripts/git-guard-permit.sh $TMPDIR/dev-workflow-git-guard/permits`）に差し替え、数えて記録を書かないことを確かめ続ける（`cat` の形は 1.2 のあと `permit-store` だけになり数えられなくなるため）。`cat` の形は新しいテスト「store: the permit script name only in read-only commands is denied as store only, not counted」として、deny・数えない・記録を作らない・2 回でも打ち切らない期待値で残す（R1 の SHOULD_FIX） 触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:1882-1891
- [x] 2.4 `bats plugins/dev-workflow/tests/git-destructive-guard.bats plugins/dev-workflow/tests/git-guard-base-write-guard.bats plugins/dev-workflow/tests/hook-python-invocation.bats plugins/dev-workflow/tests/rm-permission-guard.bats` を全件通す 触る範囲: 上の 4 ファイル

## 3. 変更の記録

- [x] 3.1 `plugins/dev-workflow/changes/1166.md` に、止めなくなった形（一覧のコマンドだけでできたコマンド）・止め続ける形・偽造の経路の検討の結論（新しい種類の経路は開かない）・`permit-self` を数え続ける理由・戻し方を書く（`changes/1166.md` が main に既にあれば PR 番号で作る） 触る範囲: plugins/dev-workflow/changes/1166.md（新規）、plugins/dev-workflow/changes/1155.md:1-20（書き方の手本）
