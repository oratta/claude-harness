## 1. 本体の会話ログの選び方

- [ ] 1.1 bats を先に書く（TDD）: 本体のログが無く過去の cli だけ残る・最終活動が同時刻・`stop_uuid` が空（本体欠落＋過去 cli 1 本でも送らない。`wait --resolve` の起動し直しは決められないのでそのまま送る）・本体以外にだけ 1 時間の書き込みがある、の各ケース。置き場に cli の本体・sdk-py・古い cli があっても声かけが送られる／本体のログが無ければ送らない／ログが複数あっても `decide_relaunch` が閾値で 1 を返す。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats`（`keepalive` と `wait` の既存ケース近辺、末尾に追加）
- [ ] 1.2 選び方の共有関数（引数は置き場と `stop_uuid`）を足し、`cache_ttl_of` に選んだログを受ける任意の引数を足して声かけの判定だけがそれを渡し、`keepalive_candidate` の `len(files) != 1` と `decide_relaunch` の本数判定を置き換える。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1065-1070`（`transcript_dir` の隣）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1133-1145`（`decide_relaunch`）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1390-1394`（`keepalive_candidate`）

- [ ] 1.3 既存 spec との整合: `openspec/specs/dev-workflow-develop/spec.md` の「wait --resolve は通す返事を送る前に起動し直すかを表で決める」の「ちょうど 1 本」と 2 本なら `sent` の Scenario、`tests/epic-dispatch.bats` の同じ前提のケース（トランスクリプトが 2 本あれば送る）を、今回の選び方（過去の cli だけ・同時刻なら送る／sdk-py が混ざっても本体で判定）に直す。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats`（`wait --resolve` の起動し直しのケース。grep で `relaunch` の 2 本のケースを探す）、`openspec/changes/keepalive-main-transcript-and-reason/specs/dev-workflow-develop/spec.md`

## 2. 結果を記録に残す

- [ ] 2.1 bats: 理由ごとの `keepalive` の中身（`no-transcript`・`cache-future`・`expired`・`answered`・`skipped dialog` ほか）、同じ結果で書き直さない、`wait` の stdout と exit code が変わらない。触る範囲: `plugins/dev-workflow/tests/epic-dispatch.bats`
- [ ] 2.2 `keepalive_candidate` が拒否理由を stdout に出し、`keepalive_child` が早期 return と起動部品の結果を含めて `keepalive` に書く。`epic-state.sh` の検査に `keepalive` が文字列であることを足し、冒頭のコメントの項目一覧を直す。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1327-1403`（`keepalive_candidate`）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1431-1470`（`keepalive_child`）、`plugins/dev-workflow/scripts/epic-state.sh:5-9,84-91`

## 3. 仕上げ

- [ ] 3.1 既存の bats（epic-dispatch・epic-launch-tmux・develop-skill）が通ることを確かめる。`openspec validate keepalive-main-transcript-and-reason --type change --strict` を通す
