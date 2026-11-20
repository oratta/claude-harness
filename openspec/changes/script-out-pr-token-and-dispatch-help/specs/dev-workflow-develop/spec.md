## ADDED Requirements

### Requirement: epic-dispatch.sh は --help で出力語の意味を出す
`plugins/dev-workflow/scripts/epic-dispatch.sh` は、第 1 引数が `--help` か `-h` のとき、stdout にサブコマンドの書式と出力語の意味を出して exit 0 で終わらなければならない（MUST）。対象は全サブコマンド（`route`・`launch`・`reply`・`notify-closed`・`wait`・`mark`・`reap`・`pending-owner`・`dismiss`・`told`・`child-log`・`adopt`・`clear`・`max-parallel`）で、各サブコマンドの終了コード、`child-log` の列、`max-parallel` の既定値の決め方、子の起動コマンドの組み立て（`EPIC_DISPATCH_CLAUDE_CMD`・`EPIC_DISPATCH_MODEL` と既定）も出す。

#### Scenario: --help は出力語の意味を出して exit 0 で終わる
- **WHEN** `epic-dispatch.sh --help` を `gh`・`orca`・`git` を PATH に置かない環境で呼ぶ
- **THEN** stdout に全サブコマンドの書式と、次の節の語頭の一覧の全語の意味が出て、exit 0 で、状態の記録の置き場は作られない

### Requirement: --help は副作用を持たず既存の使い方を変えない
`--help` の処理は状態の記録の検査（`es_check_env`）と `epic-state.sh` の関数の呼び出しより前に置き、`gh`・`orca`・`git` を呼ばず状態の記録を読み書きしない（MUST NOT）。既存の使い方（stderr・exit 1）と各サブコマンドの出力語・終了コードは変えてはならない（MUST NOT）。


#### Scenario: 既存の使い方は変わらない
- **WHEN** 知らないサブコマンドか引数なしで呼ぶ
- **THEN** stderr に使い方が出て exit 1 で、stdout は空である

### Requirement: --help は出力語の固定リストの全語を説明する
`--help` は、stdout の結果行の語頭（理由・番号が続くものは語頭だけ。理由の語は各サブコマンドの下に書く）の次の固定リストの全語を説明しなければならない（MUST）: `nested`・`orca`・`tmux`・`subagent`（route）、`launched`・`skipped`・`failed`・`deferred`（launch）、`sent`・`relaunched`（reply）、`notified`・`unrecorded`（notify-closed）、`closed`・`done`・`stopped`・`error`・`expired`・`timeout`・`keepalive`（wait）、`marked`（mark）、`reaped`・`gone`・`kept`・`unreadable`（reap・child-log）、`pending`（pending-owner）、`dismissed`（dismiss）、`told`（told）、`adopted`・`none`（adopt・clear）、`cleared`（clear）。

#### Scenario: 固定リストの語はすべて --help に載る
- **WHEN** 固定リストの各語を `epic-dispatch.sh --help` の stdout から探す
- **THEN** すべての語が見つかる

### Requirement: 固定リストは機械抽出と突き合わせて検査する
テストは、(1) 固定リストの全語が `--help` の出力に現れること、(2) `epic-dispatch.sh` の中の `echo "<語> $n`・`echo "<語> $*`・`echo "<語> $epic` の形で（`>&2` を伴わない行から）機械抽出した語頭がすべて固定リストに含まれること、を検査する（MUST）。エラーメッセージ（stderr）と、`wait` の `error gh`・`error workspaces` の 2 語目は抽出の対象に含めず、`--help` の本文の言い回しも検査しない。


#### Scenario: 実装が出す結果行の語頭は固定リストに含まれる
- **WHEN** `epic-dispatch.sh` の `echo "<語> $n` 形の stdout 行から語頭を機械抽出する
- **THEN** 抽出した語頭はすべて固定リストにある（足りなければ固定リストと `--help` に語を足す）

### Requirement: epic-loop.md は出力語の定義文を持たず、動作指示と分類表を持つ
`skills/develop/references/epic-loop.md` は、`epic-dispatch.sh` の出力語の意味を定義する文（例: `launched <N>` の括弧書きの「最初の指示を子の入力欄に送り、ターンの開始まで確かめた」、`skipped` の「既存 worktree があれば二重起動しない」、`wait` の `closed`・`stopped`・`unrecorded` の意味）。`wait` が `done` を推定する条件は定義文ではなく動作指示なので、この要件では消さないを持たず、`epic-dispatch.sh --help` への参照と、出力語ごとの「止まって主に報告する／進む」の分類表を持たなければならない（MUST）。
#### Scenario: 定義文は消え、分類表と --help への参照がある
- **WHEN** `references/epic-loop.md` を読む
- **THEN** `epic-dispatch.sh --help` への参照があり、出力語ごとに「止まって主に報告する」か「進む」の行がある表があり、`launched <N>`（…確かめた）の定義の括弧書きは無い

### Requirement: epic-loop.md は出力語を受けた動作指示を残す
`skills/develop/references/epic-loop.md` は、出力語を受けて本体がすることを定める動作指示を残さなければならない（MUST）。残すもの: `kept <N> <理由>` の確かめ方と消し方、`not-done` は待ちを続けること、`reaped`・`gone` を片付け待ちから外すこと、`done`・`closed` で起こされたときの手順、`deferred` の意味と後回しの子の扱い、同時上限の既定値の式と設定方法、`wait` が完了を推定する条件（手順 2 の 1 文）、手順 3・4 の推定 `done` と `skipped <N> not-stopped` の扱い、`child-log` を状態表の前に読む指示、idleCompaction を切る指示。既存の要件「Orca 経路の片付け」「同時に動く子の上限」「後回しの子の通常進行」「回し方の手順は推定した done も子の付けた done と同じに片付ける」はこれらを要求していて定義文を要求していないので、本文と Scenario は変わらず成り立つ。

#### Scenario: 動作指示は残る
- **WHEN** 既存の Scenario「Orca 経路に片付けの手順が書かれている」「片付けた子と消えた子は片付け待ちから外れる」「epic-loop.md に既定値の式と設定方法が書かれている」「回し方に推定の扱いが書かれている」と、`epic-dispatch.bats` の検査「Orca route steps 2-4 describe the inferred done and reap it like the child's done」を、編集後の `epic-loop.md` にかける
- **THEN** すべて偽にならない（既存の bats がそのまま通る）
