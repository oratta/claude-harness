# Tasks

## 1. テストを先に書く

- [x] 1.1 `reply --as owner` で、端末 1 つ・`agentIdentity` null・題名がセッション名・画面の下端に Claude Code の入力枠（既存の screen のスタブの形）があれば `sent 11` になるテストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:4527-4680（reply の端末選択のスタブとテスト）、plugins/dev-workflow/tests/epic-dispatch.bats:295-310（`terminal read` のスタブ）
- [x] 1.2 同じ一覧で、画面の下端がシェルのプロンプト・画面を読めない（`terminal read` が失敗）ときは `failed 11 ambiguous-terminal` で、送信・作成・閉じるが呼ばれないテストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:4527-4680
- [x] 1.3 識別できない端末が 2 つのとき `terminal read` が呼ばれず `failed 11 ambiguous-terminal` になるテストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:4527-4680
- [x] 1.4 `notify-closed`（`stopped-seen`・`completed`）で同じ 1 端末に送られ、stdout に `ambiguous-terminal` が無いテストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:5072-5100（notify-closed のテスト）
- [x] 1.5 `keepalive` で同じ 1 端末が選ばれて画面の判定に進み（送信前の 2 回の観測を省かず）`sent` になるテストと、同じ 1 端末の画面の下端がシェルのプロンプトなら `skipped ambiguous-terminal` で送信が呼ばれないテストと、その段の画面の読み取りが失敗したら `failed observe` になるテストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:7880-7910（keepalive の orca スタブ）

- [x] 1.6 `epic-launch-orca.sh deliver` を直接呼び、識別できない 1 端末のときは `orca terminal read` が 1 回だけ呼ばれ、`agentIdentity` が `claude` の端末が 1 つのときと識別できない端末が 2 つのときは `orca terminal read` が呼ばれないことを、呼び出しの記録で確かめるテストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:6390-6430（`run part deliver /work/issue-5 …` の部品を直接呼ぶテスト）

## 2. 実装

- [x] 2.1 `keepalive_screen_reason` の Python に、入力枠が取れたかだけを返すモードを足す（取れれば `claude`、取れなければ `unknown`。観測の形が読めなければ `unreadable`。`source` が screen でない画面は、読めたが入力枠が取れないものとして `unknown`）。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:112-238（keepalive_screen_reason）
- [x] 2.2 端末一覧 JSON から選べず、端末がちょうど 1 つのときだけ画面を 1 回読み、2.1 のモードで `claude` ならそのハンドルを返す関数を足す。読み取りが失敗したか `unreadable` なら、入力枠が無いときと区別できる戻り値で返す（`keepalive` が `failed observe` を出すため）（`pick_session_term` 自体は一覧だけで決める今の形のまま残し、`shell_start` はそれを使い続ける）。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:97-108（pick_session_term）
- [x] 2.3 `cmd_deliver` と `cmd_keepalive` を 2.2 の関数に切り替える。`deliver` は入力枠が無いときも読み取りの失敗も `failed ambiguous-terminal`、`keepalive` は入力枠が無ければ `skipped ambiguous-terminal`、読み取りの失敗は `failed observe`。触る範囲: plugins/dev-workflow/scripts/epic-launch-orca.sh:243-253（cmd_keepalive）、plugins/dev-workflow/scripts/epic-launch-orca.sh:461-470（cmd_deliver）
- [x] 2.4 `epic-dispatch.sh` の reply の説明コメントの端末の決め方に 1 端末の画面の段を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:145-155

## 3. 確かめる

- [ ] 3.1 `scripts/test.sh plugins/dev-workflow/tests/epic-dispatch.bats` が exit 0
