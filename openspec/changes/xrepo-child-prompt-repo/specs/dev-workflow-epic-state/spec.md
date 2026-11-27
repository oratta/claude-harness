## MODIFIED Requirements

### Requirement: 別のリポジトリの子の起動の指示・環境変数・注意書き・返事の頭にはエピックのリポジトリを足す

`launch` は、記録の `repo` が記録の `epic` のリポジトリと違う子について、次の形にしなければならない（MUST）。エピックと同じリポジトリの子は今のまま変えない（MUST）。

- 子の最初の入力: `/develop <子の owner>/<repo>#<N> （エピック <エピックの owner>/<repo>#<E> の子。親ワークツリー <親> から Orca で起動）`（例 `/develop genetta-inc/flatmate#892 （エピック oratta/claude-harness#1810 の子。…`）。`<N>` は子のリポジトリの番号。子とエピックのどちらの番号にもリポジトリを付け、子が番号だけを見てエピックの側のリポジトリの issue を読みに行かないようにする（MUST。2026-11-26 に genetta-inc/flatmate#892 の子が oratta/claude-harness#892 を読みに行った）。`エピックのリポジトリ <owner>/<repo>。` の句は付けない（MUST NOT。番号に付けたリポジトリと重なり、どちらの側か取り違える元になるため）。`owner-reply-check.sh` の `DISPATCH_ARGS` と、子のターン状態のフックの起動形の判定は、この形を起動の指示として受け付ける（要件「入力の送り手は予約文と起動形と先頭の接頭辞で決める」と、`dev-workflow-owner-reply-check` の要件「主の発言として数える行と数えない行」の条件 9）
- 子の起動コマンドの前置き: `EPIC_DISPATCH_PARENT_EPIC=<エピックの owner>/<repo>#<E>`（同じリポジトリの子は `<E>` だけ）。この前置きは `launch` だけでなく、子の端末を作るすべての経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）に付ける（MUST）。値は子の記録の `epic` と `repo` から決める（記録の `repo` がエピックのリポジトリと違えば `<owner>/<repo>#<E>`、同じなら `<E>`）。付けないと起動し直した子の `route` が `parent epic: #<E>` を出し、子が無関係の issue にコメントしてしまう
- 起動し直しの指示（`reply` の `--relaunch` と端末が 0 個のときの起動し直し、`notify-closed --relaunch`、`wait --resolve` の起動し直し）: 最初の入力と同じく、別のリポジトリの子では先頭を `/develop <子の owner>/<repo>#<N> （エピック <エピックの owner>/<repo>#<E> の子。返事を受けて起動し直し）` にし、そのうしろに頭を付けた返事を続ける（MUST）。子のリポジトリは記録の `repo`、エピックのリポジトリと番号は記録の `epic` から取る
- `--note` の注意書き: 子 issue（子のリポジトリ）に `gh issue comment <N> -R <子のリポジトリ> --body '親エピックからの注意書き: <エピックの owner>/<repo>#<E>\n\n<注意書き>'` で残す。失敗時の投稿し直しのコマンドも `-R` を含む。先頭の `親エピックからの注意書き:` は同じ

`reply`（`--as parent` / `--as owner`）と `notify-closed` と `wait --resolve` が子に送る返事の頭は、別のリポジトリの子では `親エピック #<E>（<エピックの owner>/<repo>）の判断（主の承認ではない）: ` と `主の返事（親エピック #<E>（<エピックの owner>/<repo>）経由）: ` にする（MUST。先頭の `親エピック #` / `主の返事（親エピック #` は変えない）。エピックへのコメント（`親の判断: 子 <o>/<r>#N 通した — ...` など）の子の呼び方は、要件「子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く」のとおり。

#### Scenario: 別のリポジトリの子の起動コマンドと指示
- **WHEN** origin が `oratta/claude-harness` の親のワークツリーで `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` が成功する
- **THEN** 子の端末のコマンドは `EPIC_DISPATCH_PARENT_EPIC=oratta/claude-harness#1122 ` で始まり、最初の入力は `/develop genetta-inc/flatmate#1615 （エピック oratta/claude-harness#1122 の子。親ワークツリー ` で始まり、`エピックのリポジトリ` を含まない

#### Scenario: 起動し直した別のリポジトリの子にもエピックのリポジトリを渡す
- **WHEN** 子 `genetta-inc/flatmate#1615` の記録（`epic` が `oratta/claude-harness#1122`、`repo` が `genetta-inc/flatmate`）がある状態で `epic-dispatch.sh reply --relaunch --as parent 1122 genetta-inc/flatmate#1615 続けてよい` を実行する
- **THEN** `orca terminal create --command` は `EPIC_DISPATCH_PARENT_EPIC=oratta/claude-harness#1122 ` で始まり、送る指示は `/develop genetta-inc/flatmate#1615 （エピック oratta/claude-harness#1122 の子。返事を受けて起動し直し） 親エピック #1122（oratta/claude-harness）の判断（主の承認ではない）: 続けてよい` である

#### Scenario: 別のリポジトリの子の起動の指示は主の発言として数えられない
- **WHEN** 別のリポジトリの子の `launch` の指示と起動し直しの指示が `<command-args>` に入ったセッションの記録を `owner-reply-check.sh` に渡す
- **THEN** どちらも主の発言として数えられない（`owner-reply-check.bats` で確かめる）

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

### Requirement: 入力の送り手は予約文と起動形と先頭の接頭辞で決める

フックは予約文を先に除外し、記録の親子と一致する既存 launcher の起動形をそのセッションで初めて受けたら `startup`、それ以外で先頭が `親エピック #` / `主の返事（親エピック #` なら `parent`、残りを `owner` としなければならない（MUST）。対象外入力では分類結果を記録してはならない（MUST NOT）。起動形の子は `#N` または `owner/repo#N` とし、エピックは `エピック #E` または `エピック owner/repo#E` とし、明示された子 repo は記録側と双方小文字化して一致することを求める（MUST）。記録の表記は変えてはならない（MUST NOT）。起動形は先頭の子番号・親番号に加え、明示されたエピックの repo（`エピック owner/repo#E` の repo、無ければ `エピックのリポジトリ owner/repo。` の句の repo。この句はこの変更の前の launcher が書いた起動形のために受け付け続ける）と記録側を双方小文字化して照合し、省略時の同一 repo 判定も双方小文字化しなければならない（MUST）。一致する起動指示でだけ未登録または別 ID から登録・切替し、保存済みの世代を1増やす（初回は1）（MUST）。送り手は到着経路であり承認の権限を表さない。本文の途中の引用や子の自己申告から決めてはならない（MUST NOT）。

#### Scenario: 主が直接入力する
- **WHEN** 主が保存済み ID と同じ子のタブに `調査結果を教えて` と入力する
- **THEN** `sender` は `owner` である。同じ ID に同じ起動指示を再送した場合も `startup` とせず `owner` になる

#### Scenario: 親の判断と親経由の主の返事を同じ輸送経路にする
- **WHEN** 保存済み ID と同じセッションへの入力が `親エピック #1732 の判断（主の承認ではない）:` または `主の返事（親エピック #1732 経由）:` で始まる（別repoの括弧付き表記を含む）
- **THEN** `sender` は `parent` であり、主本人の承認かどうかの既存の検証は省かない

#### Scenario: 起動し直しの指示に埋め込まれた返事を分類する
- **WHEN** 新セッションの初回入力が記録の親子・エピックの repo と一致する launcher の `/develop #<子> （エピック #<親> の子。…）` の形であり、返事も埋め込まれている
- **THEN** `sender` は `startup` であり、新 ID と旧世代+1、`turn_state: null` を一度に保存する。別repoの起動形でも同じであり、旧 ID の入力・Stop は新 ID の記録を変えない

#### Scenario: 引用は送り手を変えない
- **WHEN** 対象の通常入力の途中に `親エピック #1732` の引用がある
- **THEN** その引用を理由に `parent` にせず `owner` と記録する

#### Scenario: 起動指示の番号や repo の不一致と引用では切り替えない
- **WHEN** 未登録または異なる ID から、子番号違い・親番号違い・エピックの repo 違い・別 repo の子で repo の記載省略・本文途中に引用した起動形のいずれかを受ける
- **THEN** 登録・切替せず記録全体を保つ。同じ repo の子は repo の記載省略を許し、別 repo でも正しい repo を明示した起動指示は登録・切替できる

#### Scenario: 一致する起動指示の形は認証に使わない
- **WHEN** 同じ worktree の別セッションに、記録の親子・repo と一致する起動指示を意図的に送り直す
- **THEN** その ID への切替を受理する。これは起動指示の輸送上の分類であり、主本人の承認や起動元の認証を証明しない

#### Scenario: 子とエピックにリポジトリを付けた起動形も起動指示として分類する
- **WHEN** 新セッションの初回入力が `/develop genetta-inc/flatmate#892 （エピック oratta/claude-harness#1810 の子。返事を受けて起動し直し） 主の返事（親エピック #1810（oratta/claude-harness）経由）: ok` で、記録の `repo` が `genetta-inc/flatmate`、`number` が 892、`epic` が `oratta/claude-harness#1810`
- **THEN** `sender` は `startup` である。`エピック other/repo#1810` のようにエピックの repo が記録と違えば登録・切替しない
