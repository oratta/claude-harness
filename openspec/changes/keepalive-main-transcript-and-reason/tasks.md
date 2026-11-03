## 1. 本体の会話ログの選び方

- [ ] 1.1 bats を先に書く（TDD）: 置き場に cli の本体・sdk-py・古い cli があっても声かけが送られる／本体のログが無ければ送らない／ログが複数あっても `decide_relaunch` が閾値で 1 を返す。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats`（`keepalive` と `wait` の既存ケース近辺、末尾に追加）
- [ ] 1.2 選び方の共有関数を足し、`keepalive_candidate` の `len(files) != 1` と `decide_relaunch` の本数判定を置き換える。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1065-1070`（`transcript_dir` の隣）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1133-1145`（`decide_relaunch`）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1390-1394`（`keepalive_candidate`）

## 2. 結果を記録に残す

- [ ] 2.1 bats: 理由ごとの `keepalive` の中身（`no-transcript`・`expired`・`answered`・`skipped dialog` ほか）、同じ結果で書き直さない、`wait` の stdout と exit code が変わらない。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats`
- [ ] 2.2 `keepalive_candidate` が拒否理由を stdout に出し、`keepalive_child` が早期 return と起動部品の結果を含めて `keepalive` に書く。`epic-state.sh` の検査に `keepalive` が文字列であることを足し、冒頭のコメントの項目一覧を直す。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1327-1403`（`keepalive_candidate`）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1431-1470`（`keepalive_child`）、`plugins/dev-workflow/scripts/epic-state.sh:5-9,84-91`

## 3. 仕上げ

- [ ] 3.1 既存の bats（epic-dispatch・epic-launch-tmux・develop-skill）が通ることを確かめる。`openspec validate keepalive-main-transcript-and-reason --type change --strict` を通す
