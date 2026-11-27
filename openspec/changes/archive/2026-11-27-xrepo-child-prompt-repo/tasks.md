# Tasks

## 1. テストを先に書く

- [x] 1.1 `xrepo=1` の launch の最初の入力が `/develop genetta-inc/flatmate#1615 （エピック #1122 の子。エピックのリポジトリ oratta/claude-harness。親ワークツリー ` で始まるよう、既存の assert を書き換える。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:6125-6145（launch の xrepo のテスト）
- [x] 1.2 `xrepo=1` の `reply --relaunch --as parent` の指示が `/develop genetta-inc/flatmate#1615 （エピック #1122 の子。エピックのリポジトリ oratta/claude-harness。返事を受けて起動し直し） 親エピック #1122（oratta/claude-harness）の判断（主の承認ではない）: 続けてよい` になるよう、既存の assert を書き換える。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:6195-6215（起動し直しの xrepo のテスト）
- [x] 1.3 `xrepo=0` の launch の最初の入力と `reply --relaunch` の指示が、この変更の前と同じ文字列であることを完全一致で確かめるテストを足す（既存にあれば完全一致の assert に強める）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（launch と reply の同じリポジトリのテストの近く）
- [x] 1.4 `owner-reply-check.sh` に、子の番号にリポジトリを付けた起動の指示（launch と起動し直しの 2 つ。どちらも原文 `許容` を `<command-args>` の末尾に含む）の行だけのログで exit 1 になるテストを足す。触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:259-285（`owner-reply #1059` の起動の指示のテストの近く）
- [x] 1.5 `epic-child-state.sh` は変えずに、`/develop genetta-inc/flatmate#892 （エピック #1810 の子。エピックのリポジトリ oratta/claude-harness。返事を受けて起動し直し） …` が `startup` になるテストと、句の repo が記録と違う（`エピックのリポジトリ other/repo。`）と登録・切替しないテストを足す（同じ確かめが既にあれば足さない）。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:54-62、plugins/dev-workflow/tests/epic-child-state.bats:685-700

## 2. 実装

- [x] 2.1 launch の `xrepo=1` の `prompt=` の子の番号を `$crepo#$num` にする（エピックの句は今のまま）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:940-941
- [x] 2.2 deliver_reply の `xrepo` の起動し直しの `prompt=` の子の番号を、記録の `repo` と `number` の `<repo>#<N>` にする（エピックの句は今のまま）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1056-1073
- [x] 2.3 `DISPATCH_ARGS` を `<command-args>\s*(?:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#\d+\s*（エピック #\d+ の子。` にし、冒頭の説明の 2 つの文字列に別のリポジトリの子の形を足す。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:31-37、plugins/dev-workflow/scripts/owner-reply-check.sh:150-152
- [x] 2.4 `epic-dispatch.sh` の usage・説明コメントに起動の指示の形が書かれていれば合わせる。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:140-160

## 3. 変更の記録

- [x] 3.1 #1831 の 3 つの change（orca-session-term-fallback・parent-merge-inputs-fence・xrepo-child-prompt-repo）の変更の記録を `plugins/dev-workflow/changes/1831.md` に書く（形は既存の `plugins/dev-workflow/changes/*.md` に合わせ、題名の行・何が変わったか・変えていないもの・受け入れること・戻し方を書く）。この change は 3 つのうち最後に実装するので、ここに置く。触る範囲: plugins/dev-workflow/changes/1831.md（新規）

## 4. 確かめる

- [x] 4.1 `scripts/test.sh plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/owner-reply-check.bats plugins/dev-workflow/tests/epic-child-state.bats` が exit 0
- [x] 4.2 `git diff --name-only origin/main...HEAD` に `plugins/dev-workflow/scripts/epic-child-state.sh` が無い（聖域パスに触っていない）
