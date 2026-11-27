# Tasks

## 1. テストを先に書く

- [ ] 1.1 `xrepo=1` の launch の最初の入力が `/develop genetta-inc/flatmate#1615 （エピック oratta/claude-harness#1122 の子。親ワークツリー ` で始まり、`エピックのリポジトリ` を含まないよう、既存の assert を書き換える。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:6125-6145（launch の xrepo のテスト）
- [ ] 1.2 `xrepo=1` の `reply --relaunch --as parent` の指示が `/develop genetta-inc/flatmate#1615 （エピック oratta/claude-harness#1122 の子。返事を受けて起動し直し） 親エピック #1122（oratta/claude-harness）の判断（主の承認ではない）: 続けてよい` になるよう、既存の assert を書き換える。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:6195-6215（起動し直しの xrepo のテスト）
- [ ] 1.3 `xrepo=0` の launch の最初の入力と `reply --relaunch` の指示が、この変更の前と同じ文字列であることを完全一致で確かめるテストを足す（既存にあれば完全一致の assert に強める）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（launch と reply の同じリポジトリのテストの近く）
- [ ] 1.4 `owner-reply-check.sh` に、リポジトリ付きの起動の指示（launch と起動し直しの 2 つ）を含む行だけのログで exit 1 になるテストを足す。触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:265-285（起動の指示のテストの近く）
- [ ] 1.5 `epic-child-state.sh` の起動形に、`/develop o/r#2 （エピック parent/repo#1 の子。返事を受けて起動し直し） …` が `startup` になるテストと、`エピック other/repo#1` が登録・切替しないテストを足す。触る範囲: plugins/dev-workflow/tests/epic-child-state.bats:54-62、plugins/dev-workflow/tests/epic-child-state.bats:685-700

## 2. 実装

- [ ] 2.1 launch の `xrepo=1` の `prompt=` を新しい形にする。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:940-941
- [ ] 2.2 deliver_reply の `xrepo` の起動し直しの `prompt=` を新しい形にする（子の repo は記録の `repo`、エピックは記録の `epic`）。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1056-1073
- [ ] 2.3 `DISPATCH_ARGS` を広げ、冒頭の説明の 2 つの文字列に別のリポジトリの子の形を足す。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:31-37、plugins/dev-workflow/scripts/owner-reply-check.sh:150-152
- [ ] 2.4 `startup()` の正規表現でエピックの側の `<repo>#` を受け、エピックの repo を「エピック側の repo → 句 → 子と同じ repo」の順で決める。触る範囲: plugins/dev-workflow/scripts/epic-child-state.sh:119-128
- [ ] 2.5 `epic-dispatch.sh` の usage・説明コメントに起動の指示の形が書かれていれば合わせる。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:140-160

## 3. 確かめる

- [ ] 3.1 `scripts/test.sh plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/owner-reply-check.bats plugins/dev-workflow/tests/epic-child-state.bats` が exit 0
