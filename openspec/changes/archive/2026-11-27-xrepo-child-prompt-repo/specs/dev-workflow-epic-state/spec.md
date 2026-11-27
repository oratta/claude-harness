## MODIFIED Requirements

### Requirement: 別のリポジトリの子の起動の指示・環境変数・注意書き・返事の頭にはエピックのリポジトリを足す

`launch` は、記録の `repo` が記録の `epic` のリポジトリと違う子について、次の形にしなければならない（MUST）。エピックと同じリポジトリの子は今のまま変えない（MUST）。

- 子の最初の入力: `/develop <子の owner>/<repo>#<N> （エピック #<E> の子。エピックのリポジトリ <エピックの owner>/<repo>。親ワークツリー <親> から Orca で起動）`（例 `/develop genetta-inc/flatmate#892 （エピック #1810 の子。エピックのリポジトリ oratta/claude-harness。…`）。`<N>` は子のリポジトリの番号。子の番号にはリポジトリを付け、子が番号だけを見てエピックの側のリポジトリの issue を読みに行かないようにする（MUST。2026-11-26 に genetta-inc/flatmate#892 の子が oratta/claude-harness#892 を読みに行った）。エピックの番号は `#<E>` のまま書き、エピックのリポジトリは `エピックのリポジトリ <owner>/<repo>。` の句で名指しする（MUST。子のターン状態のフックの起動形の判定が、エピックの側は `（エピック #<E> の子。` とこの句だけを受けるため）。`owner-reply-check.sh` の `DISPATCH_ARGS` は、子の番号の前に `<owner>/<repo>` を付けたこの形も起動の指示として受け付ける（`dev-workflow-owner-reply-check` の要件「主の発言として数える行と数えない行」の条件 9）
- 子の起動コマンドの前置き: `EPIC_DISPATCH_PARENT_EPIC=<エピックの owner>/<repo>#<E>`（同じリポジトリの子は `<E>` だけ）。この前置きは `launch` だけでなく、子の端末を作るすべての経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）に付ける（MUST）。値は子の記録の `epic` と `repo` から決める（記録の `repo` がエピックのリポジトリと違えば `<owner>/<repo>#<E>`、同じなら `<E>`）。付けないと起動し直した子の `route` が `parent epic: #<E>` を出し、子が無関係の issue にコメントしてしまう
- 起動し直しの指示（`reply` の `--relaunch` と端末が 0 個のときの起動し直し、`notify-closed --relaunch`、`wait --resolve` の起動し直し）: 最初の入力と同じく、別のリポジトリの子では先頭を `/develop <子の owner>/<repo>#<N> （エピック #<E> の子。エピックのリポジトリ <エピックの owner>/<repo>。返事を受けて起動し直し）` にし、そのうしろに頭を付けた返事を続ける（MUST）。子のリポジトリと番号は記録の `repo` と `number`、エピックのリポジトリと番号は記録の `epic` から取る
- `--note` の注意書き: 子 issue（子のリポジトリ）に `gh issue comment <N> -R <子のリポジトリ> --body '親エピックからの注意書き: <エピックの owner>/<repo>#<E>\n\n<注意書き>'` で残す。失敗時の投稿し直しのコマンドも `-R` を含む。先頭の `親エピックからの注意書き:` は同じ

`reply`（`--as parent` / `--as owner`）と `notify-closed` と `wait --resolve` が子に送る返事の頭は、別のリポジトリの子では `親エピック #<E>（<エピックの owner>/<repo>）の判断（主の承認ではない）: ` と `主の返事（親エピック #<E>（<エピックの owner>/<repo>）経由）: ` にする（MUST。先頭の `親エピック #` / `主の返事（親エピック #` は変えない）。エピックへのコメント（`親の判断: 子 <o>/<r>#N 通した — ...` など）の子の呼び方は、要件「子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く」のとおり。

#### Scenario: 別のリポジトリの子の起動コマンドと指示
- **WHEN** origin が `oratta/claude-harness` の親のワークツリーで `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` が成功する
- **THEN** 子の端末のコマンドは `EPIC_DISPATCH_PARENT_EPIC=oratta/claude-harness#1122 ` で始まり、最初の入力は `/develop genetta-inc/flatmate#1615 （エピック #1122 の子。エピックのリポジトリ oratta/claude-harness。親ワークツリー ` で始まる

#### Scenario: 起動し直した別のリポジトリの子にもエピックのリポジトリを渡す
- **WHEN** 子 `genetta-inc/flatmate#1615` の記録（`epic` が `oratta/claude-harness#1122`、`repo` が `genetta-inc/flatmate`）がある状態で `epic-dispatch.sh reply --relaunch --as parent 1122 genetta-inc/flatmate#1615 続けてよい` を実行する
- **THEN** `orca terminal create --command` は `EPIC_DISPATCH_PARENT_EPIC=oratta/claude-harness#1122 ` で始まり、送る指示は `/develop genetta-inc/flatmate#1615 （エピック #1122 の子。エピックのリポジトリ oratta/claude-harness。返事を受けて起動し直し） 親エピック #1122（oratta/claude-harness）の判断（主の承認ではない）: 続けてよい` である

#### Scenario: 別のリポジトリの子の起動の指示は主の発言として数えられない
- **WHEN** 別のリポジトリの子の `launch` の指示と起動し直しの指示が `<command-args>` に入ったセッションの記録を `owner-reply-check.sh` に渡す
- **THEN** どちらも主の発言として数えられない（`owner-reply-check.bats` で確かめる）

#### Scenario: 別のリポジトリの子の新しい起動の指示は子のターン状態のフックで startup になる
- **WHEN** 記録の `repo` が `genetta-inc/flatmate`、`number` が 892、`epic` が `oratta/claude-harness#1810` の子の新しいセッションの初回入力が `/develop genetta-inc/flatmate#892 （エピック #1810 の子。エピックのリポジトリ oratta/claude-harness。返事を受けて起動し直し） 主の返事（親エピック #1810（oratta/claude-harness）経由）: ok`
- **THEN** `sender` は `startup` である（`epic-child-state.sh` は変えず、今の起動形の判定で通ることを `epic-child-state.bats` で確かめる）

#### Scenario: 別のリポジトリの子の注意書きは子のリポジトリに投稿する
- **WHEN** `--note 範囲を守る` を付けて同じ `launch` が成功する
- **THEN** `gh issue comment 1615 -R genetta-inc/flatmate --body` が呼ばれ、本文は `親エピックからの注意書き: oratta/claude-harness#1122` で始まる

#### Scenario: 別のリポジトリの子への返事の頭
- **WHEN** 子 `genetta-inc/flatmate#1615` の記録があり、`epic-dispatch.sh reply --as parent 1122 genetta-inc/flatmate#1615 続けてよい` が子の端末に届ける
- **THEN** 送る文は `親エピック #1122（oratta/claude-harness）の判断（主の承認ではない）: 続けてよい` である

#### Scenario: 同じリポジトリの子の書式は変わらない
- **WHEN** `epic-dispatch.sh launch --note 範囲を守る 1122 11`（子 11 がエピックと同じリポジトリ）を実行する
- **THEN** 起動コマンドは `EPIC_DISPATCH_PARENT_EPIC=1122 ` で始まり、最初の入力は `/develop #11 （エピック #1122 の子。親ワークツリー ` で始まり（この変更の前と同じ文字列）、注意書きは `gh issue comment 11 --body` で `親エピックからの注意書き: #1122` で始まる

#### Scenario: 同じリポジトリの子の起動し直しの指示は変わらない
- **WHEN** 子 11（エピックと同じリポジトリ）の記録がある状態で `epic-dispatch.sh reply --relaunch --as parent 1122 11 続けてよい` を実行する
- **THEN** 送る指示は `/develop #11 （エピック #1122 の子。返事を受けて起動し直し） 親エピック #1122 の判断（主の承認ではない）: 続けてよい` である（この変更の前と同じ文字列）
